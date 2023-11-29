// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/src/interface/ICloneableV2.sol";
import {
    FlowCommon,
    DeployerDiscoverableMetaV3ConstructionConfig,
    LibContext,
    EvaluableConfigV3,
    EvaluableV2
} from "../abstract/FlowCommon.sol";
import {IFlowV5, MIN_FLOW_SENTINELS, FlowTransferV1} from "../interface/unstable/IFlowV5.sol";
import {LibFlow} from "../lib/LibFlow.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {Pointer} from "rain.solmem/lib/LibPointer.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {SignedContextV1} from "rain.interpreter/src/interface/IInterpreterCallerV2.sol";

/// @dev The hash of the meta data expected to be passed to `FlowCommon`'s
/// constructor.
bytes32 constant CALLER_META_HASH = bytes32(0x95de68a447a477b8fab10701f1265b3e85a98b24710b3e40e6a96aa6d76263bc);

/// @title Flow
/// See `IFlowV4` docs.
contract Flow is ICloneableV2, IFlowV5, FlowCommon {
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];

    /// Forwards to `FlowCommon` constructor.
    constructor(DeployerDiscoverableMetaV3ConstructionConfig memory config) FlowCommon(CALLER_META_HASH, config) {}

    /// Overloaded typed initialize function MUST revert with this error.
    /// As per `ICloneableV2` interface.
    function initialize(EvaluableConfigV3[] memory) external pure {
        revert InitializeSignatureFn();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        EvaluableConfigV3[] memory flowConfig = abi.decode(data, (EvaluableConfigV3[]));
        emit Initialize(msg.sender, flowConfig);

        flowCommonInit(flowConfig, MIN_FLOW_SENTINELS);
        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc IFlowV5
    function stackToFlow(uint256[] memory stack) external pure virtual override returns (FlowTransferV1 memory) {
        return LibFlow.stackToFlow(stack.dataPointer(), stack.endPointer());
    }

    /// @inheritdoc IFlowV5
    function flow(EvaluableV2 memory evaluable, uint256[] memory callerContext, SignedContextV1[] memory signedContexts)
        external
        virtual
        nonReentrant
        returns (FlowTransferV1 memory)
    {
        (Pointer stackBottom, Pointer stackTop, uint256[] memory kvs) =
            _flowStack(evaluable, callerContext, signedContexts);
        FlowTransferV1 memory flowTransfer = LibFlow.stackToFlow(stackBottom, stackTop);
        LibFlow.flow(flowTransfer, evaluable.store, kvs);
        return flowTransfer;
    }
}
