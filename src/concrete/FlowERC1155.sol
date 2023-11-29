// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ERC1155Upgradeable as ERC1155} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";

import {LibEncodedDispatch, EncodedDispatch} from "rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";
import {Sentinel, LibStackSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {
    IFlowERC1155V5,
    FlowERC1155IOV1,
    SignedContextV1,
    FlowERC1155ConfigV3,
    ERC1155SupplyChange,
    RAIN_FLOW_SENTINEL,
    FLOW_ERC1155_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC1155_HANDLE_TRANSFER_MAX_OUTPUTS,
    FLOW_ERC1155_HANDLE_TRANSFER_MIN_OUTPUTS,
    FLOW_ERC1155_MIN_FLOW_SENTINELS
} from "../interface/unstable/IFlowERC1155V5.sol";
import {LibBytecode} from "lib/rain.interpreter/src/lib/bytecode/LibBytecode.sol";
import {IInterpreterStoreV1} from "rain.interpreter/src/interface/IInterpreterStoreV1.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibFlow} from "../lib/LibFlow.sol";
import {
    FlowCommon,
    DeployerDiscoverableMetaV3ConstructionConfig,
    ERC1155Receiver,
    IInterpreterV2,
    EvaluableConfigV3,
    EvaluableV2,
    LibNamespace,
    SourceIndexV2,
    DEFAULT_STATE_NAMESPACE
} from "../abstract/FlowCommon.sol";
import {LibContext} from "rain.interpreter/src/lib/caller/LibContext.sol";

/// @dev The hash of the meta data expected by the `FlowCommon` constructor.
bytes32 constant CALLER_META_HASH = bytes32(0xb69058fd37042da816bb4afc024e65ef5b83c3dca5997f13acf94df6ce758dca);

/// @title FlowERC1155
/// See `IFlowERC1155V4` for documentation.
contract FlowERC1155 is ICloneableV2, IFlowERC1155V5, FlowCommon, ERC1155 {
    using LibStackSentinel for Pointer;
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];

    /// True if the evaluable needs to be called on every transfer.
    //solhint-disable-next-line private-vars-leading-underscore
    bool private sEvalHandleTransfer;

    /// The `Evaluable` that handles transfers.
    //solhint-disable-next-line private-vars-leading-underscore
    EvaluableV2 internal sEvaluable;

    /// Forwards the `FlowCommon` constructor.
    constructor(DeployerDiscoverableMetaV3ConstructionConfig memory config) FlowCommon(CALLER_META_HASH, config) {}

    /// Overloaded typed initialize function MUST revert with this error.
    /// As per `ICloneableV2` interface.
    function initialize(FlowERC1155ConfigV3 memory) external pure {
        revert InitializeSignatureFn();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        FlowERC1155ConfigV3 memory flowERC1155Config = abi.decode(data, (FlowERC1155ConfigV3));
        emit Initialize(msg.sender, flowERC1155Config);
        __ERC1155_init(flowERC1155Config.uri);

        // Set state before external calls here.
        bool evalHandleTransfer = LibBytecode.sourceCount(flowERC1155Config.evaluableConfig.bytecode) > 0
            && LibBytecode.sourceOpsCount(
                flowERC1155Config.evaluableConfig.bytecode, SourceIndexV2.unwrap(FLOW_ERC1155_HANDLE_TRANSFER_ENTRYPOINT)
            ) > 0;
        sEvalHandleTransfer = evalHandleTransfer;

        flowCommonInit(flowERC1155Config.flowConfig, FLOW_ERC1155_MIN_FLOW_SENTINELS);

        if (evalHandleTransfer) {
            (IInterpreterV2 interpreter, IInterpreterStoreV1 store, address expression, bytes memory io) =
            flowERC1155Config.evaluableConfig.deployer.deployExpression2(
                flowERC1155Config.evaluableConfig.bytecode, flowERC1155Config.evaluableConfig.constants
            );
            // There's no way to set this before the external call because the
            // output of the `deployExpression` call is the input to `Evaluable`.
            // Even if we could set it before the external call, we wouldn't want
            // to because the evaluable should not be registered before the
            // integrity checks are complete.
            // The deployer MUST be a trusted contract anyway.
            // slither-disable-next-line reentrancy-benign
            sEvaluable = EvaluableV2(interpreter, store, expression);
        }

        return ICLONEABLE_V2_SUCCESS;
    }

    /// Needed here to fix Open Zeppelin implementing `supportsInterface` on
    /// multiple base contracts.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @inheritdoc ERC1155
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        unchecked {
            super._afterTokenTransfer(operator, from, to, ids, amounts, data);
            // Mint and burn access MUST be handled by flow.
            // HANDLE_TRANSFER will only restrict subsequent transfers.
            if (sEvalHandleTransfer && !(from == address(0) || to == address(0))) {
                EvaluableV2 memory evaluable = sEvaluable;
                uint256[][] memory context;
                {
                    context = LibContext.build(
                        // The transfer params are caller context because the caller
                        // is triggering the transfer.
                        LibUint256Matrix.matrixFrom(
                            LibUint256Array.arrayFrom(
                                uint256(uint160(operator)), uint256(uint160(from)), uint256(uint160(to))
                            ),
                            ids,
                            amounts
                        ),
                        new SignedContextV1[](0)
                    );
                }

                (uint256[] memory stack, uint256[] memory kvs) = evaluable.interpreter.eval2(
                    evaluable.store,
                    LibNamespace.qualifyNamespace(DEFAULT_STATE_NAMESPACE, address(this)),
                    LibEncodedDispatch.encode2(
                        evaluable.expression,
                        FLOW_ERC1155_HANDLE_TRANSFER_ENTRYPOINT,
                        FLOW_ERC1155_HANDLE_TRANSFER_MAX_OUTPUTS
                    ),
                    context,
                    new uint256[](0)
                );
                (stack);
                if (kvs.length > 0) {
                    evaluable.store.set(DEFAULT_STATE_NAMESPACE, kvs);
                }
            }
        }
    }

    /// @inheritdoc IFlowERC1155V5
    function stackToFlow(uint256[] memory stack)
        external
        pure
        override
        returns (FlowERC1155IOV1 memory flowERC1155IO)
    {
        return _stackToFlow(stack.dataPointer(), stack.endPointer());
    }

    /// @inheritdoc IFlowERC1155V5
    function flow(EvaluableV2 memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        external
        virtual
        returns (FlowERC1155IOV1 memory)
    {
        return _flow(evaluable, callerContext, signedContexts);
    }

    /// Wraps the standard `LibFlow.stackToFlow` function with the addition of
    /// consuming the mint/burn sentinels from the stack and returning them in
    /// the `FlowERC1155IOV1`.
    /// @param stackBottom The bottom of the stack.
    /// @param stackTop The top of the stack.
    /// @return flowERC1155IO The `FlowERC1155IOV1` representation of the stack.
    function _stackToFlow(Pointer stackBottom, Pointer stackTop) internal pure returns (FlowERC1155IOV1 memory) {
        ERC1155SupplyChange[] memory mints;
        ERC1155SupplyChange[] memory burns;
        Pointer tuplesPointer;

        // mints
        // https://github.com/crytic/slither/issues/2126
        //slither-disable-next-line unused-return
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 3);
        assembly ("memory-safe") {
            mints := tuplesPointer
        }
        // burns
        // https://github.com/crytic/slither/issues/2126
        //slither-disable-next-line unused-return
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 3);
        assembly ("memory-safe") {
            burns := tuplesPointer
        }
        return FlowERC1155IOV1(mints, burns, LibFlow.stackToFlow(stackBottom, stackTop));
    }

    /// Wraps the standard `LibFlow.flow` function to handle minting and burning
    /// of the flow contract itself. This involves consuming the mint/burn
    /// sentinels from the stack and minting/burning the tokens accordingly, then
    /// calling `LibFlow.flow` to handle the rest of the flow.
    function _flow(
        EvaluableV2 memory evaluable,
        uint256[] memory callerContext,
        SignedContextV1[] memory signedContexts
    ) internal virtual nonReentrant returns (FlowERC1155IOV1 memory) {
        unchecked {
            (Pointer stackBottom, Pointer stackTop, uint256[] memory kvs) =
                _flowStack(evaluable, callerContext, signedContexts);
            FlowERC1155IOV1 memory flowERC1155IO = _stackToFlow(stackBottom, stackTop);
            for (uint256 i = 0; i < flowERC1155IO.mints.length; i++) {
                // @todo support data somehow.
                _mint(flowERC1155IO.mints[i].account, flowERC1155IO.mints[i].id, flowERC1155IO.mints[i].amount, "");
            }
            for (uint256 i = 0; i < flowERC1155IO.burns.length; i++) {
                _burn(flowERC1155IO.burns[i].account, flowERC1155IO.burns[i].id, flowERC1155IO.burns[i].amount);
            }
            LibFlow.flow(flowERC1155IO.flow, evaluable.store, kvs);
            return flowERC1155IO;
        }
    }
}
