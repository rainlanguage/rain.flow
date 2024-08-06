// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Test, Vm} from "forge-std/Test.sol";
import {ERC20Transfer, ERC721Transfer, ERC1155Transfer, RAIN_FLOW_SENTINEL} from "src/interface/unstable/IFlowV5.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {ERC1155SupplyChange} from "src/interface/unstable/IFlowERC1155V5.sol";

abstract contract FlowUtilsAbstractTest is Test {
    function generateTokenTransferStack(
        ERC1155Transfer[] memory erc1155Transfers,
        ERC721Transfer[] memory erc721Transfers,
        ERC20Transfer[] memory erc20Transfers,
        ERC1155SupplyChange[] memory mints,
        ERC1155SupplyChange[] memory burns
    ) internal pure returns (uint256[] memory stack) {
        uint256 totalItems = 1 + (erc1155Transfers.length * 5) + 1 + (erc721Transfers.length * 4) + 1
            + (erc20Transfers.length * 4) + 1 + (mints.length * 3) + 1 + (burns.length * 3);
        stack = new uint256[](totalItems);
        uint256 index = 0;

        uint256 separator = Sentinel.unwrap(RAIN_FLOW_SENTINEL);

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

        stack[index++] = separator;
        for (uint256 i = 0; i < mints.length; i++) {
            stack[index++] = uint256(uint160(mints[i].account));
            stack[index++] = uint256(uint160(mints[i].id));
            stack[index++] = mints[i].amount;
        }

        stack[index++] = separator;
        for (uint256 i = 0; i < burns.length; i++) {
            stack[index++] = uint256(uint160(burns[i].account));
            stack[index++] = uint256(uint160(burns[i].id));
            stack[index++] = burns[i].amount;
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
