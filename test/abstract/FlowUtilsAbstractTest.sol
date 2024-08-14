// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Test, Vm} from "forge-std/Test.sol";
import {ERC20Transfer, ERC721Transfer, ERC1155Transfer, RAIN_FLOW_SENTINEL} from "src/interface/unstable/IFlowV5.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {ERC1155SupplyChange} from "src/interface/unstable/IFlowERC1155V5.sol";
import {ERC721SupplyChange} from "src/interface/unstable/IFlowERC721V5.sol";
import {ERC20SupplyChange} from "src/interface/unstable/IFlowERC20V5.sol";

abstract contract FlowUtilsAbstractTest is Test {
    uint256 internal immutable sentinel;

    constructor() {
        vm.pauseGasMetering();
        sentinel = Sentinel.unwrap(RAIN_FLOW_SENTINEL);
        vm.resumeGasMetering();
    }

    function generateTokenTransferStack(
        ERC1155Transfer[] memory erc1155Transfers,
        ERC721Transfer[] memory erc721Transfers,
        ERC20Transfer[] memory erc20Transfers
    ) internal view returns (uint256[] memory stack) {
        uint256 totalItems =
            1 + (erc1155Transfers.length * 5) + 1 + (erc721Transfers.length * 4) + 1 + (erc20Transfers.length * 4);
        stack = new uint256[](totalItems);
        uint256 index = 0;

        stack[index++] = sentinel;
        for (uint256 i = 0; i < erc1155Transfers.length; i++) {
            stack[index++] = uint256(uint160(erc1155Transfers[i].token));
            stack[index++] = uint256(uint160(erc1155Transfers[i].from));
            stack[index++] = uint256(uint160(erc1155Transfers[i].to));
            stack[index++] = erc1155Transfers[i].id;
            stack[index++] = erc1155Transfers[i].amount;
        }

        stack[index++] = sentinel;
        for (uint256 i = 0; i < erc721Transfers.length; i++) {
            stack[index++] = uint256(uint160(erc721Transfers[i].token));
            stack[index++] = uint256(uint160(erc721Transfers[i].from));
            stack[index++] = uint256(uint160(erc721Transfers[i].to));
            stack[index++] = erc721Transfers[i].id;
        }

        stack[index++] = sentinel;
        for (uint256 i = 0; i < erc20Transfers.length; i++) {
            stack[index++] = uint256(uint160(erc20Transfers[i].token));
            stack[index++] = uint256(uint160(erc20Transfers[i].from));
            stack[index++] = uint256(uint160(erc20Transfers[i].to));
            stack[index++] = erc20Transfers[i].amount;
        }

        return stack;
    }

    function generateFlowERC1155Stack(
        ERC1155Transfer[] memory erc1155Transfers,
        ERC721Transfer[] memory erc721Transfers,
        ERC20Transfer[] memory erc20Transfers,
        ERC1155SupplyChange[] memory erc1155Burns,
        ERC1155SupplyChange[] memory erc1155Mints
    ) internal view returns (uint256[] memory stack) {
        uint256[] memory transfersStack = generateTokenTransferStack(erc1155Transfers, erc721Transfers, erc20Transfers);
        uint256 totalItems = transfersStack.length + 1 + (erc1155Burns.length * 3) + 1 + (erc1155Mints.length * 3);

        stack = new uint256[](totalItems);
        uint256 index = 0;
        uint256 separator = Sentinel.unwrap(RAIN_FLOW_SENTINEL);

        for (uint256 i = 0; i < transfersStack.length; i++) {
            stack[index++] = transfersStack[i];
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < erc1155Burns.length; i++) {
            stack[index++] = uint256(uint160(erc1155Burns[i].account));
            stack[index++] = erc1155Burns[i].id;
            stack[index++] = erc1155Burns[i].amount;
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < erc1155Mints.length; i++) {
            stack[index++] = uint256(uint160(erc1155Mints[i].account));
            stack[index++] = erc1155Mints[i].id;
            stack[index++] = erc1155Mints[i].amount;
        }
    }

    function generateFlowERC721Stack(
        ERC1155Transfer[] memory erc1155Transfers,
        ERC721Transfer[] memory erc721Transfers,
        ERC20Transfer[] memory erc20Transfers,
        ERC721SupplyChange[] memory erc721Burns,
        ERC721SupplyChange[] memory erc721Mints
    ) internal view returns (uint256[] memory stack) {
        uint256[] memory transfersStack = generateTokenTransferStack(erc1155Transfers, erc721Transfers, erc20Transfers);
        uint256 totalItems = transfersStack.length + 1 + (erc721Burns.length * 2) + 1 + (erc721Mints.length * 2);

        stack = new uint256[](totalItems);
        uint256 index = 0;
        uint256 separator = Sentinel.unwrap(RAIN_FLOW_SENTINEL);

        for (uint256 i = 0; i < transfersStack.length; i++) {
            stack[index++] = transfersStack[i];
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < erc721Burns.length; i++) {
            stack[index++] = uint256(uint160(erc721Burns[i].account));
            stack[index++] = erc721Burns[i].id;
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < erc721Mints.length; i++) {
            stack[index++] = uint256(uint160(erc721Mints[i].account));
            stack[index++] = erc721Mints[i].id;
        }
    }

    function generateFlowERC20Stack(
        ERC1155Transfer[] memory erc1155Transfers,
        ERC721Transfer[] memory erc721Transfers,
        ERC20Transfer[] memory erc20Transfers,
        ERC20SupplyChange[] memory erc20Burns,
        ERC20SupplyChange[] memory erc20Mints
    ) internal view returns (uint256[] memory stack) {
        uint256[] memory transfersStack = generateTokenTransferStack(erc1155Transfers, erc721Transfers, erc20Transfers);
        uint256 totalItems = transfersStack.length + 1 + (erc20Mints.length * 2) + 1 + (erc20Mints.length * 2);

        stack = new uint256[](totalItems);
        uint256 index = 0;
        uint256 separator = Sentinel.unwrap(RAIN_FLOW_SENTINEL);

        for (uint256 i = 0; i < transfersStack.length; i++) {
            stack[index++] = transfersStack[i];
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < erc20Burns.length; i++) {
            stack[index++] = uint256(uint160(erc20Burns[i].account));
            stack[index++] = erc20Burns[i].amount;
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < erc20Mints.length; i++) {
            stack[index++] = uint256(uint160(erc20Mints[i].account));
            stack[index++] = erc20Mints[i].amount;
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
