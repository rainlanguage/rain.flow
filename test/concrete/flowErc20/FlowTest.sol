// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {
    IFlowERC20V5,
    ERC20SupplyChange,
    FlowERC20IOV1,
    FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS
} from "../../../src/interface/unstable/IFlowERC20V5.sol";
import {FlowERC20Test} from "test/abstract/FlowERC20Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

contract Erc20FlowTest is FlowERC20Test {
    using LibEvaluable for EvaluableV2;
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];
    using SignContextLib for Vm;
    using LibContextWrapper for uint256[][];
    using LibStackGeneration for uint256;
    /**
     * @notice Tests the support for the transferPreflight hook.
     */

    function testFlowERC20SupportsTransferPreflightHook(
        address alice,
        uint128 amount,
        address expressionA,
        address expressionB
    ) external {
        vm.assume(alice != address(0));
        vm.assume(sentinel != amount);
        vm.assume(expressionA != expressionB);

        address[] memory expressions = new address[](1);
        expressions[0] = expressionA;

        (address flow, EvaluableV2[] memory evaluables) = deployFlow(expressions, expressionB, new uint256[][](1));
        assumeEtchable(alice, flow);
        (uint256[] memory stack,) = mintAndBurnFlowStack(alice, amount, 0 ether, transferEmpty());
        interpreterEval2MockCall(stack, new uint256[](0));

        uint256[][] memory context = LibContextWrapper.buildAndSetContext(
            LibUint256Array.arrayFrom(uint256(uint160(address(alice))), uint256(uint160(flow)), amount).matrixFrom(),
            new SignedContextV1[](0),
            address(alice),
            flow
        );

        {
            interpreterEval2ExpectCall(
                flow,
                LibEncodedDispatch.encode2(
                    expressionB, FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT, FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                context
            );

            abstractFlowCall(flow, evaluables[0], new uint256[](0), new SignedContextV1[](0));

            vm.startPrank(alice);
            IERC20(flow).transfer(flow, amount);
            vm.stopPrank();
        }

        {
            interpreterEval2RevertCall(
                flow,
                LibEncodedDispatch.encode2(
                    expressionB, FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT, FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                context
            );

            abstractFlowCall(flow, evaluables[0], new uint256[](0), new SignedContextV1[](0));

            vm.startPrank(alice);
            vm.expectRevert("REVERT_EVAL2_CALL");
            IERC20(flow).transfer(flow, amount);
            vm.stopPrank();
        }
    }

    /**
     * @notice Tests minting and burning tokens per flow in exchange for another token (e.g., ERC20).
     */
    function testFlowERC20MintAndBurnTokensPerFlowForERC20Exchange(
        uint256 erc20OutAmount,
        uint256 erc20InAmount,
        uint256 mintAndBurn,
        address alice
    ) external {
        vm.assume(sentinel != mintAndBurn);
        vm.assume(address(0) != alice);

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);

        // Stack mint
        {
            (uint256[] memory mstack,) = mintAndBurnFlowStack(
                alice, mintAndBurn, 0 ether, transfersERC20toERC20(alice, flow, erc20InAmount, erc20OutAmount)
            );

            interpreterEval2MockCall(mstack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();

            assertEq(IERC20(flow).balanceOf(alice), mintAndBurn);
        }

        // Stack burn
        {
            (uint256[] memory bstack,) = mintAndBurnFlowStack(
                alice, 0 ether, mintAndBurn, transfersERC20toERC20(alice, flow, erc20InAmount, erc20OutAmount)
            );

            interpreterEval2MockCall(bstack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();

            assertEq(IERC20(flow).balanceOf(alice), 0 ether);
        }
    }

    /**
     * @notice Tests the flow between ERC721 and ERC1155 on the good path.
     */
    function testFlowERC20FlowERC721ToERC1155(
        address alice,
        uint256 erc721InTokenId,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) external {
        vm.assume(address(0) != alice);
        vm.label(alice, "Alice");

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                transferRC721ToERC1155(alice, flow, erc721InTokenId, erc1155OutAmount, erc1155OutTokenId)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC20FlowERC20ToERC721(uint256 fuzzedKeyAlice, uint256 erc20InAmount, uint256 erc721OutTokenId)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);

        (uint256[] memory stack,) = emptyFlowStack(transferERC20ToERC721(alice, flow, erc20InAmount, erc721OutTokenId));

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC20FlowERC1155ToERC1155(
        uint256 fuzzedKeyAlice,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmount
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);

        (uint256[] memory stack,) = emptyFlowStack(
            transferERC1155ToERC1155(
                alice, flow, erc1155BInTokenId, erc1155BInAmount, erc1155OutTokenId, erc1155OutAmount
            )
        );

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC20FlowERC721ToERC721(uint256 fuzzedKeyAlice, uint256 erc721OutTokenId, uint256 erc721BInTokenId)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);

        (uint256[] memory stack,) =
            emptyFlowStack(transferERC721ToERC721(alice, flow, erc721BInTokenId, erc721OutTokenId));
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC20FlowERC20ToERC20(uint256 erc20OutAmount, uint256 erc20InAmount, uint256 fuzzedKeyAlice)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);
        (uint256[] memory stack,) = emptyFlowStack(transfersERC20toERC20(alice, flow, erc20InAmount, erc20OutAmount));
        interpreterEval2MockCall(stack, new uint256[](0));

        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, new uint256[](0));
        signedContexts1[1] = vm.signContext(aliceKey, aliceKey, new uint256[](0));

        vm.startPrank(alice);
        abstractFlowCall(flow, evaluable, new uint256[](0), signedContexts1);
        vm.stopPrank();
    }

    /**
     * @notice Tests the utilization of context in the CAN_TRANSFER entrypoint.
     */
    function testFlowERC20UtilizeContextInCanTransferEntrypoint(
        address alice,
        uint256 amount,
        address expressionA,
        address expressionB,
        uint256[] memory writeToStore
    ) external {
        vm.assume(alice != address(0));
        vm.assume(sentinel != amount);
        vm.assume(expressionA != expressionB);
        vm.assume(writeToStore.length != 0);

        address[] memory expressions = new address[](1);
        expressions[0] = expressionA;

        (address flow, EvaluableV2[] memory evaluables) = deployFlow(expressions, expressionB, new uint256[][](1));
        assumeEtchable(alice, flow);

        {
            (uint256[] memory stack,) = mintFlowStack(alice, amount, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
            abstractFlowCall(flow, evaluables[0], new uint256[](0), new SignedContextV1[](0));
        }

        {
            interpreterEval2MockCall(new uint256[](0), writeToStore);
            vm.mockCall(address(iStore), abi.encodeWithSelector(IInterpreterStoreV2.set.selector), "");

            vm.expectCall(
                address(iStore),
                abi.encodeWithSelector(IInterpreterStoreV2.set.selector, DEFAULT_STATE_NAMESPACE, writeToStore)
            );
        }

        {
            vm.startPrank(alice);
            IERC20(flow).transfer(flow, amount);
            vm.stopPrank();
        }
    }
}
