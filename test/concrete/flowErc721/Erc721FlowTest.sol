// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";
import {FlowERC721Test} from "test/abstract/FlowERC721Test.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {
    IFlowERC721V5,
    FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS
} from "../../../src/interface/unstable/IFlowERC721V5.sol";
import {BurnerNotOwner} from "src/interface/deprecated/v4/IFlowERC721V4.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {MissingSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS} from "src/abstract/FlowCommon.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";

contract Erc721FlowTest is FlowERC721Test {
    using LibEvaluable for EvaluableV2;
    using SignContextLib for Vm;
    using LibUint256Matrix for uint256[];
    using Address for address;

    /**
     * @notice Tests the support for the transferPreflight hook.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721SupportsTransferPreflightHook(address alice, uint256 tokenIdA, uint256 tokenIdB) external {
        vm.assume(alice != address(0));
        vm.assume(tokenIdA != tokenIdB);

        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) = deployFlowERC721({name: "", symbol: "", baseURI: ""});
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintFlowStack(alice, 0, tokenIdA, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
            IFlowERC721V5(flow).flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        }

        {
            uint256[][] memory contextTransferA = LibContextWrapper.buildAndSetContext(
                LibUint256Array.arrayFrom(uint256(uint160(address(alice))), uint256(uint160(address(flow))), tokenIdA)
                    .matrixFrom(),
                new SignedContextV1[](0),
                address(alice),
                address(flow)
            );

            // Expect call token transfer
            interpreterEval2ExpectCall(
                address(flow),
                LibEncodedDispatch.encode2(
                    address(uint160(uint256(keccak256("configExpression")))),
                    FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT,
                    FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                contextTransferA
            );

            vm.startPrank(alice);
            IERC721(address(flow)).transferFrom({from: alice, to: address(flow), tokenId: tokenIdA});
            vm.stopPrank();
        }

        {
            (uint256[] memory stack,) = mintFlowStack(alice, 0, tokenIdB, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
            IFlowERC721V5(flow).flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        }

        {
            uint256[][] memory contextTransferB = LibContextWrapper.buildAndSetContext(
                LibUint256Array.arrayFrom(uint256(uint160(address(alice))), uint256(uint160(address(flow))), tokenIdB)
                    .matrixFrom(),
                new SignedContextV1[](0),
                address(alice),
                address(flow)
            );

            interpreterEval2RevertCall(
                address(flow),
                LibEncodedDispatch.encode2(
                    address(uint160(uint256(keccak256("configExpression")))),
                    FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT,
                    FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                contextTransferB
            );

            vm.startPrank(alice);
            vm.expectRevert("REVERT_EVAL2_CALL");
            IERC721(address(flow)).transferFrom({from: alice, to: address(flow), tokenId: tokenIdB});
            vm.stopPrank();
        }
    }

    /**
     * @notice Tests minting and burning tokens per flow in exchange for another token (e.g., ERC20).
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721MintAndBurnTokensPerFlowForERC20Exchange(
        uint256 erc20OutAmount,
        uint256 erc20InAmount,
        uint256 tokenId,
        address alice
    ) external {
        vm.assume(address(0) != alice);

        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) =
            deployFlowERC721({name: "FlowERC721", symbol: "F721", baseURI: "https://www.rainprotocol.xyz/nft/"});
        assumeEtchable(alice, address(flow));

        // Stack mint
        {
            (uint256[] memory stack,) = mintFlowStack(
                alice, 0, tokenId, transfersERC20toERC20(alice, address(flow), erc20InAmount, erc20OutAmount)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();

            assertEq(IERC721(address(flow)).balanceOf(alice), 1);
            assertEq(alice, IERC721(address(flow)).ownerOf(tokenId));
        }

        // Stack burn
        {
            (uint256[] memory stack,) = burnFlowStack(
                alice, 0, tokenId, transfersERC20toERC20(alice, address(flow), erc20OutAmount, erc20InAmount)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();

            assertEq(IERC721(address(flow)).balanceOf(alice), 0);
        }
    }

    /**
     * @notice Tests the flow between ERC721 and ERC1155 on the good path.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721FlowERC721ToERC1155(
        address alice,
        uint256 erc721InTokenId,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) external {
        vm.assume(address(0) != alice);
        vm.label(alice, "Alice");

        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) =
            deployFlowERC721("FlowERC721", "F721", "https://www.rainprotocol.xyz/nft/");
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

    function testFlowERC721FlowERC20ToERC721(uint256 fuzzedKeyAlice, uint256 erc20InAmount, uint256 erc721OutTokenId)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);
        vm.assume(alice != address(0));

        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) =
            deployFlowERC721("FlowERC721", "F721", "https://www.rainprotocol.xyz/nft/");
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

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721lowERC1155ToERC1155(address alice, uint256 erc1155Amount, uint256 erc1155TokenId) external {
        vm.assume(alice != address(0));

        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) =
            deployFlowERC721("FlowERC721", "F721", "https://www.rainprotocol.xyz/nft/");
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

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721lowERC20ToERC20(uint256 erc20OutAmount, uint256 erc20InAmount, address alice) external {
        vm.assume(alice != address(0));

        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) =
            deployFlowERC721("FlowERC721", "F721", "https://www.rainprotocol.xyz/nft/");
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
    function testFlowERC721FlowERC721ToERC721(uint256 fuzzedKeyAlice, uint256 erc721OutTokenId, uint256 erc721InTokenId)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) =
            deployFlowERC721("FlowERC721", "F721", "https://www.rainprotocol.xyz/nft/");
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
     * @notice Tests failure when the token burner is not the owner.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721FailWhenTokenBurnerIsNotOwner(address alice, address bob, uint256 tokenId) public {
        vm.assume(alice != address(0));
        vm.assume(bob != address(0));

        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) =
            deployFlowERC721({name: "FlowERC721", symbol: "F721", baseURI: "https://www.rainprotocol.xyz/nft/"});
        assumeEtchable(alice, address(flow));

        // Stack mint
        {
            (uint256[] memory stack,) = mintFlowStack(alice, 0, tokenId, transferEmpty());

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        assertEq(IERC721(address(flow)).balanceOf(alice), 1);
        assertEq(alice, IERC721(address(flow)).ownerOf(tokenId));

        // Stack burn
        {
            (uint256[] memory stack,) = burnFlowStack(bob, 0, tokenId, transferEmpty());

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.expectRevert(abi.encodeWithSelector(BurnerNotOwner.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
    }

    /// Should utilize context in HANDLE_TRANSFER entrypoint
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721UtilizeContextInHandleTransferEntrypoint(
        address alice,
        uint256[] memory writeToStore,
        uint256 tokenId
    ) external {
        vm.assume(alice != address(0));
        vm.assume(writeToStore.length != 0);

        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) =
            deployFlowERC721({name: "FlowERC721", symbol: "F721", baseURI: "https://www.rainprotocol.xyz/nft/"});
        assumeEtchable(alice, address(flow));

        {
            (uint256[] memory stack,) = mintFlowStack(alice, 0, tokenId, transferEmpty());
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
            IERC721(address(flow)).transferFrom({from: alice, to: address(flow), tokenId: tokenId});
            vm.stopPrank();
        }
    }

    /// Should not flow if number of sentinels is less than MIN_FLOW_SENTINELS
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721MinFlowSentinel(address alice) external {
        vm.assume(alice != address(0));

        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) =
            deployFlowERC721({name: "FlowERC721", symbol: "F721", baseURI: "https://www.rainprotocol.xyz/nft/"});

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
    function testFlowErc721HaltIfEnsureRequirementNotMet() external {
        (IFlowERC721V5 flow, EvaluableV2 memory evaluable) =
            deployFlowERC721("FlowERC721", "F721", "https://www.rainprotocol.xyz/nft/");

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
