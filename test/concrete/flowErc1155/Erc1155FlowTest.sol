// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {FlowERC1155Test} from "test/abstract/FlowERC1155Test.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {MissingSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS} from "src/abstract/FlowCommon.sol";
import {
    IFlowERC1155V5,
    FLOW_ERC1155_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC1155_HANDLE_TRANSFER_MAX_OUTPUTS
} from "../../../src/interface/unstable/IFlowERC1155V5.sol";


contract Erc1155FlowTest is FlowERC1155Test {
    using LibEvaluable for EvaluableV2;
    using SignContextLib for Vm;
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];
    using Address for address;

    /**
     * @notice Tests the support for the transferPreflight hook.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155SupportsTransferPreflightHook(address alice, uint128 amount, uint256 id) external {
        vm.assume(alice != address(0));
        vm.assume(amount != 0);

        (IFlowERC1155V5 flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
        assumeEtchable(alice, address(flow));

        // Mint tokens to Alice
        {
            (uint256[] memory stack,) = mintFlowStack(alice, amount, id, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        uint256[] memory ids = new uint256[](1);
        ids[0] = id;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        uint256[][] memory context = LibContextWrapper.buildAndSetContext(
            LibUint256Matrix.matrixFrom(
                LibUint256Array.arrayFrom(
                    uint256(uint160(alice)), uint256(uint160(alice)), uint256(uint160(address(flow)))
                ),
                ids,
                amounts
            ),
            new SignedContextV1[](0),
            address(alice),
            address(flow)
        );

        {
            interpreterEval2ExpectCall(
                address(flow),
                LibEncodedDispatch.encode2(
                    address(uint160(uint256(keccak256("configExpression")))),
                    FLOW_ERC1155_HANDLE_TRANSFER_ENTRYPOINT,
                    FLOW_ERC1155_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                context
            );

            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));

            vm.startPrank(alice);
            IERC1155(address(flow)).safeTransferFrom(alice, address(flow), id, amount, "");
            vm.stopPrank();
        }

        {
            interpreterEval2RevertCall(
                address(flow),
                LibEncodedDispatch.encode2(
                    address(uint160(uint256(keccak256("configExpression")))),
                    FLOW_ERC1155_HANDLE_TRANSFER_ENTRYPOINT,
                    FLOW_ERC1155_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                context
            );

            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));

            vm.expectRevert("REVERT_EVAL2_CALL");
            vm.startPrank(alice);
            IERC1155(address(flow)).safeTransferFrom(alice, address(flow), id, amount, "");
            vm.stopPrank();
        }
    }

    /// Tests the flow between ERC721 and ERC1155 on the good path.
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155FlowERC721ToERC1155(
        address alice,
        uint256 erc721InTokenId,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) external {
        vm.assume(address(0) != alice);
        vm.label(alice, "Alice");

        (IFlowERC1155V5 flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155FlowERC20ToERC20(uint256 erc20InAmount, uint256 erc20OutAmount, uint256 fuzzedKeyAlice)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (IFlowERC1155V5 flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155FlowERC721ToERC721(
        uint256 fuzzedKeyAlice,
        uint256 erc721InTokenId,
        uint256 erc721OutTokenId
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (IFlowERC1155V5 flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155FlowERC1155ToERC1155(address alice, uint256 erc1155TokenId, uint256 erc1155Amount)
        external
    {
        vm.assume(alice != address(0));

        (IFlowERC1155V5 flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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

        {
            vm.startPrank(alice);
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();
        }
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155FlowERC20ToERC721(uint256 fuzzedKeyAlice, uint256 erc20InAmount, uint256 erc721OutTokenId)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (IFlowERC1155V5 flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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

    /// Should utilize context in CAN_TRANSFER entrypoint
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155UtilizeContextInCanTransferEntrypoint(
        address alice,
        uint256 amount,
        uint256 id,
        uint256[] memory writeToStore
    ) external {
        vm.assume(alice != address(0));
        vm.assume(amount != 0);
        vm.assume(writeToStore.length != 0);

        (IFlowERC1155V5 flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintFlowStack(alice, amount, id, transferEmpty());
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
            IERC1155(address(flow)).safeTransferFrom(alice, address(flow), id, amount, "");
            vm.stopPrank();
        }
    }

    /**
     * @notice Tests minting and burning tokens per flow in exchange for another token (e.g., ERC20).
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155MintAndBurnTokensPerFlowForERC20Exchange(
        uint256 erc20OutAmount,
        uint256 erc20InAmount,
        uint256 tokenId,
        uint256 mintAndBurn,
        address alice
    ) external {
        vm.assume(address(0) != alice);

        (IFlowERC1155V5 flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
        assumeEtchable(alice, address(flow));

        // Stack mint
        {
            (uint256[] memory stack,) = mintFlowStack(
                alice, mintAndBurn, tokenId, transfersERC20toERC20(alice, address(flow), erc20InAmount, erc20OutAmount)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();
            assertEq(IERC1155(address(flow)).balanceOf(alice, tokenId), mintAndBurn);
        }

        // Stack burn
        {
            (uint256[] memory stack,) = burnFlowStack(
                alice, mintAndBurn, tokenId, transfersERC20toERC20(alice, address(flow), erc20OutAmount, erc20InAmount)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();

            assertEq(IERC1155(address(flow)).balanceOf(alice, tokenId), 0 ether);
        }
    }

    /// Should not flow if number of sentinels is less than MIN_FLOW_SENTINELS
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155MinFlowSentinel(address alice) external {
        vm.assume(alice != address(0));

        (IFlowERC1155V5 flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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
    function testFlowErc1155HaltIfEnsureRequirementNotMet(string memory uri) external {
        (IFlowERC1155V5 flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);

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
