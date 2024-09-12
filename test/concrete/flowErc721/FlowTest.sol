// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
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
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

contract Erc721FlowTest is FlowERC721Test {
    using LibEvaluable for EvaluableV2;
    using SignContextLib for Vm;
    using LibUint256Matrix for uint256[];
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

        (IFlowERC721V5 flow, EvaluableV2[] memory evaluables) = deployFlowERC721({
            expressions: expressions,
            configExpression: expressionB,
            constants: new uint256[][](1),
            name: "FlowERC721",
            symbol: "F721",
            baseURI: "https://www.rainprotocol.xyz/nft/"
        });
        assumeEtchable(alice, address(flow));

        {
            ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](2);
            mints[0] = ERC721SupplyChange({account: alice, id: tokenIdA});
            mints[1] = ERC721SupplyChange({account: alice, id: tokenIdB});

            uint256[] memory stack = generateFlowStack(
                FlowERC721IOV1(
                    mints,
                    new ERC721SupplyChange[](0),
                    FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
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
                    expressionB, FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT, FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                contextTransferA
            );

            flow.flow(evaluables[0], new uint256[](0), new SignedContextV1[](0));

            vm.startPrank(alice);
            IERC721(address(flow)).transferFrom({from: alice, to: address(flow), tokenId: tokenIdA});
            vm.stopPrank();
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
                    expressionB, FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT, FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                contextTransferB
            );

            vm.startPrank(alice);
            vm.expectRevert("REVERT_EVAL2_CALL");
            IERC721(address(flow)).transferFrom({from: alice, to: address(flow), tokenId: tokenIdB});
            vm.stopPrank();
        }
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
        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](1);
        mints[0] = ERC721SupplyChange({account: alice, id: erc721OutTokenId});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: erc721OutTokenId});

        uint256[] memory stack = generateFlowStack(
            FlowERC721IOV1(mints, burns, FlowTransferV1(erc20Transfers, erc721Transfers, new ERC1155Transfer[](0)))
        );
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        erc721Flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC721lowERC1155ToERC1155(
        uint256 fuzzedKeyAlice,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmount,
        string memory baseURI
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmount);
        vm.assume(sentinel != erc1155BInTokenId);
        vm.assume(sentinel != erc1155BInAmount);
        vm.assume(alice != address(0));

        (IFlowERC721V5 erc721Flow, EvaluableV2 memory evaluable) =
            deployFlowERC721({name: "FlowErc721", symbol: "FErc721", baseURI: baseURI});
        assumeEtchable(alice, address(erc721Flow));

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);
        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iTokenA),
            from: address(erc721Flow),
            to: alice,
            id: erc1155OutTokenId,
            amount: erc1155OutAmount
        });

        erc1155Transfers[1] = ERC1155Transfer({
            token: address(iTokenB),
            from: alice,
            to: address(erc721Flow),
            id: erc1155BInTokenId,
            amount: erc1155BInAmount
        });

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, erc721Flow, alice, erc1155OutTokenId, erc1155OutAmount, ""
            )
        );

        vm.mockCall(iTokenB, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, alice, erc721Flow, erc1155BInTokenId, erc1155BInAmount, ""
            )
        );
        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](1);
        mints[0] = ERC721SupplyChange({account: alice, id: erc1155OutTokenId});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: erc1155OutTokenId});

        uint256[] memory stack = generateFlowStack(
            FlowERC721IOV1(
                mints, burns, FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers)
            )
        );
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        erc721Flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC721lowERC20ToERC20(
        uint256 erc20OutAmount,
        uint256 erc20BInAmount,
        uint256 fuzzedKeyAlice,
        string memory baseURI,
        uint256 id
    ) external {
        vm.assume(sentinel != erc20OutAmount);
        vm.assume(sentinel != erc20BInAmount);
        vm.assume(sentinel != id);

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (IFlowERC721V5 erc721Flow, EvaluableV2 memory evaluable) =
            deployFlowERC721({name: "FlowErc721", symbol: "FErc721", baseURI: baseURI});
        assumeEtchable(alice, address(erc721Flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(erc721Flow), to: alice, amount: erc20OutAmount});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenB), from: alice, to: address(erc721Flow), amount: erc20BInAmount});

        vm.startPrank(alice);

        vm.mockCall(address(iTokenA), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(address(iTokenA), abi.encodeWithSelector(IERC20.transfer.selector, alice, erc20OutAmount));

        vm.mockCall(address(iTokenB), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(
            address(iTokenB), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, erc721Flow, erc20BInAmount)
        );
        {
            ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](1);
            mints[0] = ERC721SupplyChange({account: alice, id: id});

            ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
            burns[0] = ERC721SupplyChange({account: alice, id: id});

            uint256[] memory stack = generateFlowStack(
                FlowERC721IOV1(
                    mints, burns, FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );

            interpreterEval2MockCall(stack, new uint256[](0));
        }
        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, new uint256[](0));
        signedContexts1[1] = vm.signContext(aliceKey, aliceKey, new uint256[](0));

        erc721Flow.flow(evaluable, new uint256[](0), signedContexts1);
        vm.stopPrank();
    }

    function testFlowERC721FlowERC721ToERC721(
        uint256 fuzzedKeyAlice,
        uint256 erc721OutTokenId,
        uint256 erc721BInTokenId,
        string memory baseURI,
        uint256 id
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        vm.assume(sentinel != erc721OutTokenId);
        vm.assume(sentinel != erc721BInTokenId);

        (IFlowERC721V5 erc721Flow, EvaluableV2 memory evaluable) =
            deployFlowERC721({name: "FlowErc721", symbol: "FErc721", baseURI: baseURI});
        assumeEtchable(alice, address(erc721Flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
        erc721Transfers[0] =
            ERC721Transfer({token: address(iTokenA), from: address(erc721Flow), to: alice, id: erc721OutTokenId});
        erc721Transfers[1] =
            ERC721Transfer({token: address(iTokenB), from: alice, to: address(erc721Flow), id: erc721BInTokenId});

        vm.mockCall(iTokenA, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), erc721Flow, alice, erc721OutTokenId
            )
        );

        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), alice, erc721Flow, erc721BInTokenId
            )
        );
        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](1);
        mints[0] = ERC721SupplyChange({account: alice, id: id});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: id});

        uint256[] memory stack = generateFlowStack(
            FlowERC721IOV1(
                mints, burns, FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0))
            )
        );

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        erc721Flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// Should utilize context in HANDLE_TRANSFER entrypoint
    function testFlowERC721UtilizeContextInHandleTransferEntrypoint(
        address alice,
        address expressionA,
        address expressionB,
        uint256[] memory writeToStore,
        string memory baseURI,
        uint256 tokenId
    ) external {
        vm.assume(alice != address(0));
        vm.assume(expressionA != expressionB);
        vm.assume(writeToStore.length != 0);

        address[] memory expressions = new address[](1);
        expressions[0] = expressionA;

        (IFlowERC721V5 flowErc721, EvaluableV2[] memory evaluables) =
            deployFlowERC721(expressions, expressionB, new uint256[][](1), "FlowErc721", "FErc721", baseURI);
        assumeEtchable(alice, address(flowErc721));

        {
            ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](1);
            mints[0] = ERC721SupplyChange({account: alice, id: tokenId});

            uint256[] memory stack = generateFlowStack(
                FlowERC721IOV1(
                    mints,
                    new ERC721SupplyChange[](0),
                    FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
            flowErc721.flow(evaluables[0], new uint256[](0), new SignedContextV1[](0));
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
            IERC721(address(flowErc721)).transferFrom({from: alice, to: address(flowErc721), tokenId: tokenId});
            vm.stopPrank();
        }
    }
}
