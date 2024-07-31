// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Test, Vm} from "forge-std/Test.sol";

struct ERC1155Transfer {
    address token;
    address from;
    address to;
    uint256 id;
    uint256 amount;
}

struct ERC721Transfer {
    address token;
    address from;
    address to;
    uint256 id;
}

struct ERC20Transfer {
    address token;
    address from;
    address to;
    uint256 amount;
}

abstract contract FlowUtilsAbstractTest is Test {
    function generateTokenTransferStack(
        ERC1155Transfer[] memory erc1155Transfers,
        ERC721Transfer[] memory erc721Transfers,
        ERC20Transfer[] memory erc20Transfers
    ) public pure returns (uint256[] memory stack) {
        uint256 totalItems =
            1 + (erc1155Transfers.length * 5) + 1 + (erc721Transfers.length * 4) + 1 + (erc20Transfers.length * 4);
        stack = new uint256[](totalItems);
        uint256 index = 0;

        uint256 separator = 115183058774379759847873638693462432260838474092724525396123647190314935293775;

        stack[index++] = separator;
        for (uint256 i = 0; i < erc1155Transfers.length; i++) {
            stack[index++] = uint256(uint160(erc1155Transfers[i].token));
            stack[index++] = uint256(uint160(erc1155Transfers[i].from));
            stack[index++] = uint256(uint160(erc1155Transfers[i].to));
            stack[index++] = erc1155Transfers[i].id;
            stack[index++] = erc1155Transfers[i].amount;
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < erc721Transfers.length; i++) {
            stack[index++] = uint256(uint160(erc721Transfers[i].token));
            stack[index++] = uint256(uint160(erc721Transfers[i].from));
            stack[index++] = uint256(uint160(erc721Transfers[i].to));
            stack[index++] = erc721Transfers[i].id;
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < erc20Transfers.length; i++) {
            stack[index++] = uint256(uint160(erc20Transfers[i].token));
            stack[index++] = uint256(uint160(erc20Transfers[i].from));
            stack[index++] = uint256(uint160(erc20Transfers[i].to));
            stack[index++] = erc20Transfers[i].amount;
        }

        return stack;
    }

    function findEvent(Vm.Log[] memory logs, bytes32 eventSignature) internal pure returns (Vm.Log memory) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                return logs[i];
            }
        }
        revert("Event not found!");
    }
}
