// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
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
        uint256 fuzzedKeyAlice
    ) public {
        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

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
            to: address(erc1155Flow), // Contract address
            token: address(erc20In),
            amount: 10
        });

        // Second ERC20 transfer
        erc20Transfers[1] = ERC20Transfer({
            from: address(erc1155Flow), // Contract address
            to: alice,
            token: address(erc20Out),
            amount: 20
        });
        FlowTransferV1 memory flowTransfer =
            FlowTransferV1({erc20: erc20Transfers, erc721: new ERC721Transfer[](0), erc1155: new ERC1155Transfer[](0)});

        deal(address(erc20In), alice, 1e18);
        deal(address(erc20Out), alice, 1e18);

        vm.startPrank(address(alice));

        // Fund Alice and the contract with necessary tokens
        erc20In.transfer(alice, flowTransfer.erc20[0].amount);
        //emit log_named_uint("Alice ERC20In Balance1", erc20In.balanceOf(alice));

        erc20Out.transfer(address(erc1155Flow), flowTransfer.erc20[1].amount);

        // Approve ERC20 transfers
        erc20In.approve(address(erc1155Flow), flowTransfer.erc20[0].amount);
        SignedContextV1[] memory signedContexts = new SignedContextV1[](2);
        signedContexts[0] = signContext(aliceKey, context0);
        signedContexts[1] = signContext(aliceKey, context1);

        uint256[] memory stack1 = generateFlowERC1155Stack(
            new ERC1155Transfer[](0),
            new ERC721Transfer[](0),
            new ERC20Transfer[](0),
            new ERC1155SupplyChange[](0),
            new ERC1155SupplyChange[](0)
        );
        interpreterEval2MockCall(stack1, new uint256[](0));

        // Perform the first flow with id 1234
        uint256[] memory flowId1234 = new uint256[](1);
        flowId1234[0] = 1234;
        erc1155Flow.flow(evaluable, flowId1234, signedContexts);

        // Perform another flow with a different id 5678
        uint256[] memory flowId5678 = new uint256[](1);
        flowId5678[0] = 5678;
        erc1155Flow.flow(evaluable, flowId5678, signedContexts);

        // Attempt to perform the flow again with id 1234, should revert
        vm.expectRevert();
        erc1155Flow.flow(evaluable, flowId1234, signedContexts);
    }
}
