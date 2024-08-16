// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    ERC1155SupplyChange
} from "test/abstract/FlowUtilsAbstractTest.sol";
import {FlowERC721Test} from "test/abstract/FlowERC721Test.sol";
import {IFlowERC721V5} from "../../../src/interface/unstable/IFlowERC721V5.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {IERC1155Upgradeable as IERC1155} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/IERC1155Upgradeable.sol";

contract Erc721FlowTest is FlowERC721Test, FlowBasicTest {
    using LibEvaluable for EvaluableV2;
    using SignContextLib for Vm;

    address internal immutable iTokenA;
    address internal immutable iTokenB;

    constructor() {
        vm.pauseGasMetering();
        iTokenA = address(uint160(uint256(keccak256("tokenA.test"))));
        vm.etch(address(iTokenA), REVERTING_MOCK_BYTECODE);

        iTokenB = address(uint160(uint256(keccak256("tokenB.test"))));
        vm.etch(address(iTokenB), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    function testFlowERC721FlowERC20ToERC721(
        uint256 fuzzedKeyAlice,
        uint256 erc20InAmount,
        uint256 erc721OutTokenId,
        string memory flow,
        string memory baseURI
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        vm.assume(sentinel != erc20InAmount);
        vm.assume(sentinel != erc721OutTokenId);

        (IFlowERC721V5 erc721Flow, EvaluableV2 memory evaluable) =
            deployFlowERC721({name: flow, symbol: flow, baseURI: baseURI});
        assumeEtchable(alice, address(erc721Flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: alice, to: address(erc721Flow), amount: erc20InAmount});

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] =
            ERC721Transfer({token: iTokenB, from: address(erc721Flow), to: alice, id: erc721OutTokenId});

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector, alice, erc721Flow, erc20InAmount));

        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), erc721Flow, alice, erc721OutTokenId
            )
        );

        uint256[] memory stack = generateFlowERC1155Stack(
            new ERC1155Transfer[](0),
            erc721Transfers,
            erc20Transfers,
            new ERC1155SupplyChange[](0),
            new ERC1155SupplyChange[](0)
        );
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        erc721Flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }
}
