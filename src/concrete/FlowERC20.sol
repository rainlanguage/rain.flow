// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ERC20Upgradeable as ERC20} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {
    IFlowERC20V5,
    FlowERC20IOV1,
    FlowERC20ConfigV3,
    ERC20SupplyChange,
    SignedContextV1,
    FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC20_HANDLE_TRANSFER_MIN_OUTPUTS,
    FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS,
    RAIN_FLOW_SENTINEL,
    FLOW_ERC20_MIN_FLOW_SENTINELS
} from "../interface/unstable/IFlowERC20V5.sol";
import {LibBytecode} from "lib/rain.interpreter/src/lib/bytecode/LibBytecode.sol";
import {EncodedDispatch, LibEncodedDispatch} from "rain.interpreter/src/lib/caller/LibEncodedDispatch.sol";
import {Sentinel, LibStackSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {LibFlow} from "../lib/LibFlow.sol";
import {
    FlowCommon,
    DeployerDiscoverableMetaV3,
    DeployerDiscoverableMetaV3ConstructionConfig,
    IInterpreterV2,
    EvaluableV2,
    LibNamespace
} from "../abstract/FlowCommon.sol";
import {SourceIndexV2, DEFAULT_STATE_NAMESPACE} from "rain.interpreter/src/interface/unstable/IInterpreterV2.sol";
import {IInterpreterStoreV1} from "rain.interpreter/src/interface/IInterpreterStoreV1.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibContext} from "rain.interpreter/src/lib/caller/LibContext.sol";

/// @dev The hash of the meta data expected to be passed to `FlowCommon`'s
/// constructor.
bytes32 constant CALLER_META_HASH = bytes32(0x3caa0161e803e38f9f150053a28756bdfd306b5d6180476273ab69d741b2d6a3);

/// @title FlowERC20
/// See `IFlowERC20V4` for documentation.
contract FlowERC20 is ICloneableV2, IFlowERC20V5, FlowCommon, ERC20 {
    using LibStackSentinel for Pointer;
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];

    /// @dev True if we need to eval `handleTransfer` on every transfer. For many
    /// tokens this will be false, so we don't want to invoke the external
    /// interpreter call just to cause a noop.
    //solhint-disable-next-line private-vars-leading-underscore
    bool private sEvalHandleTransfer;

    /// @dev The evaluable that will be used to evaluate `handleTransfer` on
    /// every transfer. This is only set if `sEvalHandleTransfer` is true.
    //solhint-disable-next-line private-vars-leading-underscore
    EvaluableV2 internal sEvaluable;

    /// Forwards the `FlowCommon` constructor arguments to the `FlowCommon`.
    constructor(DeployerDiscoverableMetaV3ConstructionConfig memory config) FlowCommon(CALLER_META_HASH, config) {}

    /// Overloaded typed initialize function MUST revert with this error.
    /// As per `ICloneableV2` interface.
    function initialize(FlowERC20ConfigV3 memory) external pure {
        revert InitializeSignatureFn();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        FlowERC20ConfigV3 memory flowERC20Config = abi.decode(data, (FlowERC20ConfigV3));
        emit Initialize(msg.sender, flowERC20Config);
        __ERC20_init(flowERC20Config.name, flowERC20Config.symbol);

        // Set state before external calls here.
        bool evalHandleTransfer = LibBytecode.sourceCount(flowERC20Config.evaluableConfig.bytecode) > 0
            && LibBytecode.sourceOpsCount(
                flowERC20Config.evaluableConfig.bytecode, SourceIndexV2.unwrap(FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT)
            ) > 0;
        sEvalHandleTransfer = evalHandleTransfer;

        flowCommonInit(flowERC20Config.flowConfig, FLOW_ERC20_MIN_FLOW_SENTINELS);

        if (evalHandleTransfer) {
            (IInterpreterV2 interpreter, IInterpreterStoreV1 store, address expression, bytes memory io) =
            flowERC20Config.evaluableConfig.deployer.deployExpression2(
                flowERC20Config.evaluableConfig.bytecode, flowERC20Config.evaluableConfig.constants
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

    /// @inheritdoc IFlowERC20V5
    function stackToFlow(uint256[] memory stack) external pure virtual override returns (FlowERC20IOV1 memory) {
        return _stackToFlow(stack.dataPointer(), stack.endPointer());
    }

    /// @inheritdoc IFlowERC20V5
    function flow(EvaluableV2 memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        external
        virtual
        returns (FlowERC20IOV1 memory)
    {
        return _flow(evaluable, callerContext, signedContexts);
    }

    /// Exposes the Open Zeppelin `_afterTokenTransfer` hook as an evaluable
    /// entrypoint so that the deployer of the token can use it to implement
    /// custom transfer logic. The stack is ignored, so if the expression author
    /// wants to prevent some kind of transfer, they can just revert within the
    /// expression evaluation.
    /// @inheritdoc ERC20
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        unchecked {
            super._afterTokenTransfer(from, to, amount);

            // Mint and burn access MUST be handled by flow.
            // HANDLE_TRANSFER will only restrict subsequent transfers.
            if (sEvalHandleTransfer && !(from == address(0) || to == address(0))) {
                EvaluableV2 memory evaluable = sEvaluable;
                (uint256[] memory stack, uint256[] memory kvs) = evaluable.interpreter.eval2(
                    evaluable.store,
                    LibNamespace.qualifyNamespace(DEFAULT_STATE_NAMESPACE, address(this)),
                    LibEncodedDispatch.encode2(
                        evaluable.expression,
                        FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT,
                        FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS
                    ),
                    LibContext.build(
                        // The transfer params are caller context because the caller
                        // is triggering the transfer.
                        LibUint256Array.arrayFrom(uint256(uint160(from)), uint256(uint160(to)), amount).matrixFrom(),
                        new SignedContextV1[](0)
                    ),
                    new uint256[](0)
                );
                (stack);
                if (kvs.length > 0) {
                    evaluable.store.set(DEFAULT_STATE_NAMESPACE, kvs);
                }
            }
        }
    }

    /// Wraps the standard `LibFlow.stackToFlow` with the additional logic to
    /// convert the stack to a `FlowERC20IOV1` struct. This involves consuming
    /// the mints and burns from the stack as additional sentinel separated
    /// tuples. The mints are consumed first, then the burns, then the remaining
    /// stack is converted to a flow as normal.
    /// @param stackBottom The bottom of the stack.
    /// @param stackTop The top of the stack.
    /// @return flowERC20IO The resulting `FlowERC20IOV1` struct.
    function _stackToFlow(Pointer stackBottom, Pointer stackTop) internal pure virtual returns (FlowERC20IOV1 memory) {
        ERC20SupplyChange[] memory mints;
        ERC20SupplyChange[] memory burns;
        Pointer tuplesPointer;

        // mints
        // https://github.com/crytic/slither/issues/2126
        //slither-disable-next-line unused-return
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 2);
        assembly ("memory-safe") {
            mints := tuplesPointer
        }
        // burns
        // https://github.com/crytic/slither/issues/2126
        //slither-disable-next-line unused-return
        (stackTop, tuplesPointer) = stackBottom.consumeSentinelTuples(stackTop, RAIN_FLOW_SENTINEL, 2);
        assembly ("memory-safe") {
            burns := tuplesPointer
        }

        return FlowERC20IOV1(mints, burns, LibFlow.stackToFlow(stackBottom, stackTop));
    }

    /// Wraps the standard `LibFlow.flow` with the additional logic to handle
    /// the mints and burns from the `FlowERC20IOV1` struct. The mints are
    /// processed first, then the burns, then the remaining flow is processed
    /// as normal.
    function _flow(
        EvaluableV2 memory evaluable,
        uint256[] memory callerContext,
        SignedContextV1[] memory signedContexts
    ) internal virtual nonReentrant returns (FlowERC20IOV1 memory) {
        unchecked {
            (Pointer stackBottom, Pointer stackTop, uint256[] memory kvs) =
                _flowStack(evaluable, callerContext, signedContexts);
            FlowERC20IOV1 memory flowERC20IO = _stackToFlow(stackBottom, stackTop);
            for (uint256 i = 0; i < flowERC20IO.mints.length; ++i) {
                _mint(flowERC20IO.mints[i].account, flowERC20IO.mints[i].amount);
            }
            for (uint256 i = 0; i < flowERC20IO.burns.length; ++i) {
                _burn(flowERC20IO.burns[i].account, flowERC20IO.burns[i].amount);
            }
            LibFlow.flow(flowERC20IO.flow, evaluable.store, kvs);
            return flowERC20IO;
        }
    }
}
