// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {FlowERC721Test} from "test/abstract/FlowERC721Test.sol";

import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {
    IFlowERC721V5,
    ERC721SupplyChange,
    FlowERC721IOV1,
    FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS
} from "../../../src/interface/unstable/IFlowERC721V5.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

contract Erc721FlowTest is FlowERC721Test {
    using LibEvaluable for EvaluableV2;
    using SignContextLib for Vm;
    using LibUint256Matrix for uint256[];
    using LibStackGeneration for uint256;
    using Address for address;

    /**
     * @notice Tests the support for the transferPreflight hook.
     */
    function testFlowERC721SupportsTransferPreflightHook(
        address alice,
        uint256 tokenIdA,
        uint256 tokenIdB,
        address expressionA,
        address expressionB
    ) external {
        vm.assume(alice != address(0));
        vm.assume(sentinel != tokenIdA);
        vm.assume(sentinel != tokenIdB);
        vm.assume(tokenIdA != tokenIdB);
        vm.assume(expressionA != expressionB);
        vm.assume(!alice.isContract());

        address[] memory expressions = new address[](1);
        expressions[0] = expressionA;

        (address flow, EvaluableV2[] memory evaluables) =
            deployFlow({expressions: expressions, configExpression: expressionB, constants: new uint256[][](1)});
        assumeEtchable(alice, flow);

        {
            ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](2);
            mints[0] = ERC721SupplyChange({account: alice, id: tokenIdA});
            mints[1] = ERC721SupplyChange({account: alice, id: tokenIdB});

            uint256[] memory stack =
                sentinel.generateFlowStack(FlowERC721IOV1(mints, new ERC721SupplyChange[](0), transferEmpty()));
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            uint256[][] memory contextTransferA = LibContextWrapper.buildAndSetContext(
                LibUint256Array.arrayFrom(uint256(uint160(address(alice))), uint256(uint160(flow)), tokenIdA)
                    .matrixFrom(),
                new SignedContextV1[](0),
                address(alice),
                flow
            );

            // Expect call token transfer
            interpreterEval2ExpectCall(
                flow,
                LibEncodedDispatch.encode2(
                    expressionB, FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT, FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                contextTransferA
            );

            abstractFlowCall(flow, evaluables[0], new uint256[](0), new SignedContextV1[](0));

            vm.startPrank(alice);
            IERC721(flow).transferFrom({from: alice, to: flow, tokenId: tokenIdA});
            vm.stopPrank();
        }

        {
            uint256[][] memory contextTransferB = LibContextWrapper.buildAndSetContext(
                LibUint256Array.arrayFrom(uint256(uint160(address(alice))), uint256(uint160(flow)), tokenIdB)
                    .matrixFrom(),
                new SignedContextV1[](0),
                address(alice),
                flow
            );

            interpreterEval2RevertCall(
                flow,
                LibEncodedDispatch.encode2(
                    expressionB, FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT, FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                contextTransferB
            );

            vm.startPrank(alice);
            vm.expectRevert("REVERT_EVAL2_CALL");
            IERC721(flow).transferFrom({from: alice, to: flow, tokenId: tokenIdB});
            vm.stopPrank();
        }
    }

    function testFlowERC721FlowERC20ToERC721(uint256 fuzzedKeyAlice, uint256 erc20InAmount, uint256 erc721OutTokenId)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);
        {
            uint256[] memory stack = sentinel.generateFlowStack(
                FlowERC721IOV1(
                    new ERC721SupplyChange[](0),
                    new ERC721SupplyChange[](0),
                    transferERC20ToERC721(alice, flow, erc20InAmount, erc721OutTokenId)
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }
        {
            vm.startPrank(alice);
            abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();
        }
    }

    function testFlowERC721lowERC1155ToERC1155(
        address alice,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmount
    ) external {
        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);
        {
            uint256[] memory stack = sentinel.generateFlowStack(
                FlowERC721IOV1(
                    new ERC721SupplyChange[](0),
                    new ERC721SupplyChange[](0),
                    transferERC1155ToERC1155(
                        alice, flow, erc1155BInTokenId, erc1155BInAmount, erc1155OutTokenId, erc1155OutAmount
                    )
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }
        {
            vm.startPrank(alice);
            abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();
        }
    }

    function testFlowERC721lowERC20ToERC20(uint256 erc20OutAmmount, uint256 erc20BInAmmount, uint256 fuzzedKeyAlice)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);

        {
            uint256[] memory stack = sentinel.generateFlowStack(
                FlowERC721IOV1(
                    new ERC721SupplyChange[](0),
                    new ERC721SupplyChange[](0),
                    transfersERC20toERC20(alice, flow, erc20BInAmmount, erc20OutAmmount)
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();
        }
    }

    function testFlowERC721FlowERC721ToERC721(uint256 fuzzedKeyAlice, uint256 erc721OutTokenId, uint256 erc721InTokenId)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);

        {
            uint256[] memory stack = sentinel.generateFlowStack(
                FlowERC721IOV1(
                    new ERC721SupplyChange[](0),
                    new ERC721SupplyChange[](0),
                    transferERC721ToERC721(alice, flow, erc721InTokenId, erc721OutTokenId)
                )
            );

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();
        }
    }
}
