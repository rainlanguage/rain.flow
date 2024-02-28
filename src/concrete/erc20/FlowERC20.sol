// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ERC20Upgradeable as ERC20} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {
    IFlowERC20V5,
    FlowERC20IOV1,
    FlowERC20ConfigV2,
    ERC20SupplyChange,
    SignedContextV1,
    FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC20_HANDLE_TRANSFER_MIN_OUTPUTS,
    FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS,
    RAIN_FLOW_SENTINEL,
    FLOW_ERC20_MIN_FLOW_SENTINELS
} from "../../interface/unstable/IFlowERC20V5.sol";
import {LibBytecode} from "rain.interpreter.interface/lib/bytecode/LibBytecode.sol";
import {EncodedDispatch, LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {Sentinel, LibStackSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {LibFlow} from "../../lib/LibFlow.sol";
import {FlowCommon} from "../../abstract/FlowCommon.sol";
import {
    SourceIndexV2,
    IInterpreterV2,
    DEFAULT_STATE_NAMESPACE
} from "rain.interpreter.interface/interface/unstable/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/unstable/IInterpreterStoreV2.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {LibNamespace, StateNamespace} from "rain.interpreter.interface/lib/ns/LibNamespace.sol";
import {UnsupportedHandleTransferInputs, InsufficientHandleTransferOutputs} from "../../error/ErrFlow.sol";

/// @title FlowERC20
/// See `IFlowERC20V5` for documentation.
contract FlowERC20 is ICloneableV2, IFlowERC20V5, FlowCommon, ERC20 {
    using LibStackSentinel for Pointer;
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];
    using LibNamespace for StateNamespace;

    /// @dev True if we need to eval `handleTransfer` on every transfer. For many
    /// tokens this will be false, so we don't want to invoke the external
    /// interpreter call just to cause a noop.
    bool private sEvalHandleTransfer;

    /// @dev The evaluable that will be used to evaluate `handleTransfer` on
    /// every transfer. This is only set if `sEvalHandleTransfer` is true.
    EvaluableV2 internal sEvaluable =
        EvaluableV2(IInterpreterV2(address(0)), IInterpreterStoreV2(address(0)), address(0));

    /// Overloaded typed initialize function MUST revert with this error.
    /// As per `ICloneableV2` interface.
    function initialize(FlowERC20ConfigV2 memory) external pure {
        revert InitializeSignatureFn();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        FlowERC20ConfigV2 memory flowERC20Config = abi.decode(data, (FlowERC20ConfigV2));
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
            (IInterpreterV2 interpreter, IInterpreterStoreV2 store, address expression, bytes memory io) =
            flowERC20Config.evaluableConfig.deployer.deployExpression2(
                flowERC20Config.evaluableConfig.bytecode, flowERC20Config.evaluableConfig.constants
            );

            {
                uint256 handleTransferInputs;
                uint256 handleTransferOutputs;
                assembly ("memory-safe") {
                    let ioWord := mload(add(io, 0x20))
                    handleTransferInputs := byte(0, ioWord)
                    handleTransferOutputs := byte(1, ioWord)
                }

                if (handleTransferInputs != 0) {
                    revert UnsupportedHandleTransferInputs();
                }

                if (handleTransferOutputs < FLOW_ERC20_HANDLE_TRANSFER_MIN_OUTPUTS) {
                    revert InsufficientHandleTransferOutputs();
                }
            }

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
                    DEFAULT_STATE_NAMESPACE.qualifyNamespace(address(this)),
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
