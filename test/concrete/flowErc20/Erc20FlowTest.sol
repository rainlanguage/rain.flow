// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {
    IFlowERC20V5,
    FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS
} from "../../../src/interface/unstable/IFlowERC20V5.sol";
import {FlowERC20Test} from "test/abstract/FlowERC20Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {MissingSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS} from "src/abstract/FlowCommon.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";

contract Erc20FlowTest is FlowERC20Test {
    using LibEvaluable for EvaluableV2;
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];
    using SignContextLib for Vm;
    using LibContextWrapper for uint256[][];

    /**
     * @notice Tests the support for the transferPreflight hook.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20SupportsTransferPreflightHook(address alice, uint128 amount) external {
        vm.assume(alice != address(0));

        (IFlowERC20V5 flow, EvaluableV2 memory evaluable) = deployFlowERC20("Flow ERC20", "F20");
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintFlowStack(alice, amount, 0, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        uint256[][] memory context = LibContextWrapper.buildAndSetContext(
            LibUint256Array.arrayFrom(uint256(uint160(address(alice))), uint256(uint160(address(flow))), amount)
                .matrixFrom(),
            new SignedContextV1[](0),
            address(alice),
            address(flow)
        );

        {
            interpreterEval2ExpectCall(
                address(flow),
                LibEncodedDispatch.encode2(
                    address(uint160(uint256(keccak256("configExpression")))),
                    FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT,
                    FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                context
            );

            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));

            vm.startPrank(alice);
            IERC20(address(flow)).transfer(address(flow), amount);
            vm.stopPrank();
        }

        {
            interpreterEval2RevertCall(
                address(flow),
                LibEncodedDispatch.encode2(
                    address(uint160(uint256(keccak256("configExpression")))),
                    FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT,
                    FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                context
            );

            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));

            vm.startPrank(alice);
            vm.expectRevert("REVERT_EVAL2_CALL");
            IERC20(address(flow)).transfer(address(flow), amount);
            vm.stopPrank();
        }
    }

    /**
     * @notice Tests minting and burning tokens per flow in exchange for another token (e.g., ERC20).
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20MintAndBurnTokensPerFlowForERC20Exchange(
        uint256 erc20OutAmount,
        uint256 erc20InAmount,
        uint256 mintAndBurn,
        address alice
    ) external {
        vm.assume(address(0) != alice);

        (IFlowERC20V5 flow, EvaluableV2 memory evaluable) = deployFlowERC20("Flow ERC20", "F20");
        assumeEtchable(alice, address(flow));

        // Stack mint
        {
            (uint256[] memory stack,) = mintFlowStack(
                alice, mintAndBurn, 0, transfersERC20toERC20(alice, address(flow), erc20InAmount, erc20OutAmount)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();

            assertEq(IERC20(address(flow)).balanceOf(alice), mintAndBurn);
        }

        // Stack burn
        {
            (uint256[] memory stack,) = burnFlowStack(
                alice, mintAndBurn, 0, transfersERC20toERC20(alice, address(flow), erc20OutAmount, erc20InAmount)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();

            assertEq(IERC20(address(flow)).balanceOf(alice), 0 ether);
        }
    }

    /**
     * @notice Tests the flow between ERC721 and ERC1155 on the good path.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20FlowERC721ToERC1155(
        address alice,
        uint256 erc721InTokenId,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) external {
        vm.assume(address(0) != alice);
        vm.label(alice, "Alice");

        (IFlowERC20V5 flow, EvaluableV2 memory evaluable) = deployFlowERC20("FlowERC20", "F20");
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                transferERC721ToERC1155(alice, address(flow), erc721InTokenId, erc1155OutAmount, erc1155OutTokenId)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();
        }
    }

    /**
     * @notice Tests the flow between ERC20 and ERC721 on the good path.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20FlowERC20ToERC721(uint256 fuzzedKeyAlice, uint256 erc20InAmount, uint256 erc721OutTokenId)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (IFlowERC20V5 flow, EvaluableV2 memory evaluable) = deployFlowERC20("FlowERC20", "F20");
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                transferERC20ToERC721(alice, address(flow), erc20InAmount, erc721OutTokenId)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /**
     * @notice Tests the flow between ERC1155 and ERC1155 on the good path.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20FlowERC1155ToERC1155(address alice, uint256 erc1155Amount, uint256 erc1155TokenId) external {
        vm.assume(alice != address(0));

        (IFlowERC20V5 flow, EvaluableV2 memory evaluable) = deployFlowERC20("FlowERC20", "F20");
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                transferERC1155ToERC1155(
                    alice, address(flow), erc1155TokenId, erc1155Amount, erc1155TokenId, erc1155Amount
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /**
     * @notice Tests the flow between ERC721 and ERC721 on the good path.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20FlowERC721ToERC721(uint256 fuzzedKeyAlice, uint256 erc721OutTokenId, uint256 erc721InTokenId)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (IFlowERC20V5 flow, EvaluableV2 memory evaluable) = deployFlowERC20("FlowERC20", "F20");
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                transferERC721ToERC721(alice, address(flow), erc721InTokenId, erc721OutTokenId)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /**
     * @notice Tests the flow between ERC20 and ERC20 on the good path.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20FlowERC20ToERC20(uint256 erc20OutAmount, uint256 erc20InAmount, address alice) external {
        vm.assume(alice != address(0));

        (IFlowERC20V5 flow, EvaluableV2 memory evaluable) = deployFlowERC20("FlowERC20", "F20");
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice, 20 ether, 10 ether, 5, transfersERC20toERC20(alice, address(flow), erc20InAmount, erc20OutAmount)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /**
     * @notice Tests the utilization of context in the CAN_TRANSFER entrypoint.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20UtilizeContextInCanTransferEntrypoint(
        address alice,
        uint256 amount,
        uint256[] memory writeToStore
    ) external {
        vm.assume(alice != address(0));
        vm.assume(writeToStore.length != 0);

        (IFlowERC20V5 flow, EvaluableV2 memory evaluable) = deployFlowERC20("FlowERC20", "F20");
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintFlowStack(alice, amount, 0, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
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
            IERC20(address(flow)).transfer(address(flow), amount);
            vm.stopPrank();
        }
    }

    /**
     * @notice Tests the flow fails if number of sentinels is less than MIN_FLOW_SENTINEL.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20MinFlowSentinel(address alice) external {
        vm.assume(alice != address(0));

        (IFlowERC20V5 flow, EvaluableV2 memory evaluable) = deployFlowERC20("FlowERC20", "F20");
        assumeEtchable(alice, address(flow));

        // Check that flow with invalid number of sentinels fails
        {
            (uint256[] memory stackInvalid,) = mintFlowStack(alice, 10 ether, 5, transferEmpty());
            stackInvalid[0] = 0;
            interpreterEval2MockCall(stackInvalid, new uint256[](0));
        }

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(MissingSentinel.selector, sentinel));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /**
     * @notice Tests that the flow halts if it does not meet the 'ensure' requirement.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowErc20HaltIfEnsureRequirementNotMet() external {
        (IFlowERC20V5 flow, EvaluableV2 memory evaluable) = deployFlowERC20("Flow ERC20", "F20");
        assumeEtchable(address(0), address(flow));

        (uint256[] memory stack,) = mintAndBurnFlowStack(address(this), 20 ether, 10 ether, 5, transferEmpty());
        interpreterEval2MockCall(stack, new uint256[](0));

        uint256[][] memory context = LibContextWrapper.buildAndSetContext(
            new uint256[](0), new SignedContextV1[](0), address(this), address(flow)
        );

        interpreterEval2RevertCall(
            address(flow), LibEncodedDispatch.encode2(evaluable.expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS), context
        );

        vm.expectRevert("REVERT_EVAL2_CALL");
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
    }
}
