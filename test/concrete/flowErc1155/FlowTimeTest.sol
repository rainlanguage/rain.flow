// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {FlowERC1155} from "../../../src/concrete/erc1155/FlowERC1155.sol";
import {
    FlowUtilsAbstractTest,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    ERC1155SupplyChange
} from "test/abstract/FlowUtilsAbstractTest.sol";
import {IFlowERC1155V5} from "../../../src/interface/unstable/IFlowERC1155V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {InvalidSignature} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {FlowERC1155Test} from "../../abstract/FlowERC1155Test.sol";
import {SignContextAbstractTest} from "../../abstract/SignContextAbstractTest.sol";
import {MockERC20} from "../../../lib/rain.factory/lib/rain.interpreter.interface/lib/forge-std/src/mocks/MockERC20.sol";
import {FlowTransferV1} from "../../../src/interface/deprecated/v3/IFlowV3.sol";
import {ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";

contract FlowTimeTest is SignContextAbstractTest, FlowUtilsAbstractTest, FlowERC1155Test {
    /// Should validate multiple signed contexts
    function testFlowTime(
        string memory uri,
        uint256[] memory context0,
        uint256[] memory context1,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);
        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);
        address bob = vm.addr(bobKey);

        MockERC20 erc20In = new MockERC20();
        erc20In.initialize("InToken", "TKNI", 18);
        vm.label(address(erc20In), "asdf");

        MockERC20 erc20Out = new MockERC20();
        erc20Out.initialize("OutToken", "TKNO", 18);
        vm.label(address(erc20In), "asdf1");
        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        // First ERC20 transfer
        erc20Transfers[0] = ERC20Transfer({
            from: alice,
            to: address(this), // Contract address
            token: address(erc20In),
            amount: 100
        });

        // Second ERC20 transfer
        erc20Transfers[1] = ERC20Transfer({
            from: address(this), // Contract address
            to: alice,
            token: address(erc20Out),
            amount: 10
        });

        // Initialize the main struct
        FlowTransferV1 memory flowTransfer =
            FlowTransferV1({erc20: erc20Transfers, erc721: new ERC721Transfer[](0), erc1155: new ERC1155Transfer[](0)});
    }
}
