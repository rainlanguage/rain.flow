// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Test, Vm} from "forge-std/Test.sol";

import {FlowTransferV1, RAIN_FLOW_SENTINEL} from "src/interface/unstable/IFlowV5.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {FlowERC1155IOV1} from "src/interface/unstable/IFlowERC1155V5.sol";
import {FlowERC721IOV1} from "src/interface/unstable/IFlowERC721V5.sol";
import {FlowERC20IOV1} from "src/interface/unstable/IFlowERC20V5.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";

abstract contract FlowUtilsAbstractTest is Test {
    using LibStackGeneration for uint256;
    using LibLogHelper for Vm.Log[];

    uint256 internal immutable sentinel;

    constructor() {
        vm.pauseGasMetering();
        sentinel = Sentinel.unwrap(RAIN_FLOW_SENTINEL);
        vm.resumeGasMetering();
    }

    // A temporary solution for a smooth transition to using libraries.
    function generateFlowStack(FlowTransferV1 memory flowTransfer) internal view returns (uint256[] memory stack) {
        stack = sentinel.generateFlowStack(flowTransfer);
    }

    // A temporary solution for a smooth transition to using libraries.
    function generateFlowStack(FlowERC1155IOV1 memory flowERC1155IO) internal view returns (uint256[] memory stack) {
        stack = sentinel.generateFlowStack(flowERC1155IO);
    }

    // A temporary solution for a smooth transition to using libraries.
    function generateFlowStack(FlowERC721IOV1 memory flowERC721IO) internal view returns (uint256[] memory stack) {
        stack = sentinel.generateFlowStack(flowERC721IO);
    }

    // A temporary solution for a smooth transition to using libraries.
    function generateFlowStack(FlowERC20IOV1 memory flowERC20IO) internal view returns (uint256[] memory stack) {
        stack = sentinel.generateFlowStack(flowERC20IO);
    }

    // A temporary solution for a smooth transition to using libraries.
    function findEvent(Vm.Log[] memory logs, bytes32 eventSignature) internal pure returns (Vm.Log memory) {
        return logs.findEvent(eventSignature);
    }
    
    // A temporary solution for a smooth transition to using libraries.
    function findEvents(Vm.Log[] memory logs, bytes32 eventSignature)
        internal
        pure
        returns (Vm.Log[] memory foundLogs)
    {
        foundLogs = logs.findEvents(eventSignature);
    }
}
