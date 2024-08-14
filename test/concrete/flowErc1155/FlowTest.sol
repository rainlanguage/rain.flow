// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Test, Vm} from "forge-std/Test.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {
    FlowUtilsAbstractTest,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    ERC1155SupplyChange
} from "test/abstract/FlowUtilsAbstractTest.sol";
import {FlowERC1155Test} from "test/abstract/FlowERC1155Test.sol";
import {IFlowERC1155V5} from "../../../src/interface/unstable/IFlowERC1155V5.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";

contract Erc1155FlowTest is FlowUtilsAbstractTest, FlowERC1155Test, FlowBasicTest {
    using LibEvaluable for EvaluableV2;
    using SignContextLib for Vm;

    IERC20 internal immutable iTokenA;
    IERC20 internal immutable iTokenB;

    constructor() {
        vm.pauseGasMetering();
        iTokenA = IERC20(address(uint160(uint256(keccak256("tokenA.test")))));
        vm.etch(address(iTokenA), REVERTING_MOCK_BYTECODE);

        iTokenB = IERC20(address(uint160(uint256(keccak256("tokenB.test")))));
        vm.etch(address(iTokenB), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    function testFlowERC1155FlowERC20ToERC20(
        uint256 erc20OutAmmount,
        uint256 erc20BInAmmount,
        string memory uri,
        uint256 fuzzedKeyAlice
    ) external {
        vm.assume(sentinel != erc20OutAmmount);
        vm.assume(sentinel != erc20BInAmmount);

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);
        vm.label(alice, "Alice");

        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);
        assumeEtchable(alice, address(erc1155Flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(erc1155Flow), to: alice, amount: erc20OutAmmount});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenB), from: alice, to: address(erc1155Flow), amount: erc20BInAmmount});

        vm.startPrank(alice);

        vm.mockCall(address(iTokenA), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(address(iTokenA), abi.encodeWithSelector(IERC20.transfer.selector, alice, erc20OutAmmount));

        vm.mockCall(address(iTokenB), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(
            address(iTokenB), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, erc1155Flow, erc20BInAmmount)
        );

        uint256[] memory stack = generateFlowERC1155Stack(
            new ERC1155Transfer[](0),
            new ERC721Transfer[](0),
            erc20Transfers,
            new ERC1155SupplyChange[](0),
            new ERC1155SupplyChange[](0)
        );
        interpreterEval2MockCall(stack, new uint256[](0));

        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, new uint256[](0));
        signedContexts1[1] = vm.signContext(aliceKey, aliceKey, new uint256[](0));

        erc1155Flow.flow(evaluable, new uint256[](0), signedContexts1);
        vm.stopPrank();
    }
}
