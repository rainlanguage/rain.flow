// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Test, Vm} from "forge-std/Test.sol";

import {FlowTransferV1, RAIN_FLOW_SENTINEL} from "src/interface/unstable/IFlowV5.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {FlowERC1155IOV1} from "src/interface/unstable/IFlowERC1155V5.sol";
import {FlowERC721IOV1} from "src/interface/unstable/IFlowERC721V5.sol";
import {FlowERC20IOV1} from "src/interface/unstable/IFlowERC20V5.sol";

abstract contract FlowUtilsAbstractTest is Test {
    uint256 internal immutable sentinel;

    constructor() {
        vm.pauseGasMetering();
        sentinel = Sentinel.unwrap(RAIN_FLOW_SENTINEL);
        vm.resumeGasMetering();
    }

    function generateFlowStack(FlowTransferV1 memory flowTransfer) internal view returns (uint256[] memory stack) {
        uint256 totalItems = 1 + (flowTransfer.erc1155.length * 5) + 1 + (flowTransfer.erc721.length * 4) + 1
            + (flowTransfer.erc20.length * 4);
        stack = new uint256[](totalItems);
        uint256 index = 0;

        stack[index++] = sentinel;
        for (uint256 i = 0; i < flowTransfer.erc1155.length; i++) {
            stack[index++] = uint256(uint160(flowTransfer.erc1155[i].token));
            stack[index++] = uint256(uint160(flowTransfer.erc1155[i].from));
            stack[index++] = uint256(uint160(flowTransfer.erc1155[i].to));
            stack[index++] = flowTransfer.erc1155[i].id;
            stack[index++] = flowTransfer.erc1155[i].amount;
        }

        stack[index++] = sentinel;
        for (uint256 i = 0; i < flowTransfer.erc721.length; i++) {
            stack[index++] = uint256(uint160(flowTransfer.erc721[i].token));
            stack[index++] = uint256(uint160(flowTransfer.erc721[i].from));
            stack[index++] = uint256(uint160(flowTransfer.erc721[i].to));
            stack[index++] = flowTransfer.erc721[i].id;
        }

        stack[index++] = sentinel;
        for (uint256 i = 0; i < flowTransfer.erc20.length; i++) {
            stack[index++] = uint256(uint160(flowTransfer.erc20[i].token));
            stack[index++] = uint256(uint160(flowTransfer.erc20[i].from));
            stack[index++] = uint256(uint160(flowTransfer.erc20[i].to));
            stack[index++] = flowTransfer.erc20[i].amount;
        }

        return stack;
    }

    function generateFlowStack(FlowERC1155IOV1 memory flowERC1155IO) internal view returns (uint256[] memory stack) {
        uint256[] memory transfersStack = generateFlowStack(flowERC1155IO.flow);
        uint256 totalItems =
            transfersStack.length + 1 + (flowERC1155IO.burns.length * 3) + 1 + (flowERC1155IO.mints.length * 3);

        stack = new uint256[](totalItems);
        uint256 index = 0;
        uint256 separator = Sentinel.unwrap(RAIN_FLOW_SENTINEL);

        for (uint256 i = 0; i < transfersStack.length; i++) {
            stack[index++] = transfersStack[i];
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < flowERC1155IO.burns.length; i++) {
            stack[index++] = uint256(uint160(flowERC1155IO.burns[i].account));
            stack[index++] = flowERC1155IO.burns[i].id;
            stack[index++] = flowERC1155IO.burns[i].amount;
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < flowERC1155IO.mints.length; i++) {
            stack[index++] = uint256(uint160(flowERC1155IO.mints[i].account));
            stack[index++] = flowERC1155IO.mints[i].id;
            stack[index++] = flowERC1155IO.mints[i].amount;
        }
    }

    function generateFlowStack(FlowERC721IOV1 memory flowERC721IO) internal view returns (uint256[] memory stack) {
        uint256[] memory transfersStack = generateFlowStack(flowERC721IO.flow);
        uint256 totalItems =
            transfersStack.length + 1 + (flowERC721IO.burns.length * 2) + 1 + (flowERC721IO.mints.length * 2);

        stack = new uint256[](totalItems);
        uint256 index = 0;
        uint256 separator = Sentinel.unwrap(RAIN_FLOW_SENTINEL);

        for (uint256 i = 0; i < transfersStack.length; i++) {
            stack[index++] = transfersStack[i];
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < flowERC721IO.burns.length; i++) {
            stack[index++] = uint256(uint160(flowERC721IO.burns[i].account));
            stack[index++] = flowERC721IO.burns[i].id;
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < flowERC721IO.mints.length; i++) {
            stack[index++] = uint256(uint160(flowERC721IO.mints[i].account));
            stack[index++] = flowERC721IO.mints[i].id;
        }
    }

    function generateFlowStack(FlowERC20IOV1 memory flowERC20IO) internal view returns (uint256[] memory stack) {
        uint256[] memory transfersStack = generateFlowStack(flowERC20IO.flow);
        uint256 totalItems =
            transfersStack.length + 1 + (flowERC20IO.mints.length * 2) + 1 + (flowERC20IO.mints.length * 2);

        stack = new uint256[](totalItems);
        uint256 index = 0;
        uint256 separator = Sentinel.unwrap(RAIN_FLOW_SENTINEL);

        for (uint256 i = 0; i < transfersStack.length; i++) {
            stack[index++] = transfersStack[i];
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < flowERC20IO.burns.length; i++) {
            stack[index++] = uint256(uint160(flowERC20IO.burns[i].account));
            stack[index++] = flowERC20IO.burns[i].amount;
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < flowERC20IO.mints.length; i++) {
            stack[index++] = uint256(uint160(flowERC20IO.mints[i].account));
            stack[index++] = flowERC20IO.mints[i].amount;
        }
    }

    function findEvent(Vm.Log[] memory logs, bytes32 eventSignature) internal pure returns (Vm.Log memory) {
        Vm.Log[] memory foundLogs = findEvents(logs, eventSignature);
        require(foundLogs.length >= 1, "Event not found!");
        return (foundLogs[0]);
    }

    function findEvents(Vm.Log[] memory logs, bytes32 eventSignature)
        internal
        pure
        returns (Vm.Log[] memory foundLogs)
    {
        foundLogs = new Vm.Log[](logs.length);
        uint256 foundCount = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                foundLogs[foundCount] = logs[i];
                foundCount++;
            }
        }

        assembly ("memory-safe") {
            mstore(foundLogs, foundCount)
        }
    }
}
