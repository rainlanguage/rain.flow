// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {IERC1155Upgradeable as IERC1155} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/IERC1155Upgradeable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {IInterpreterV2, DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {
    IFlowERC1155V5,
    ERC1155SupplyChange,
    FlowERC1155IOV1,
    FLOW_ERC1155_HANDLE_TRANSFER_ENTRYPOINT,
    FLOW_ERC1155_HANDLE_TRANSFER_MAX_OUTPUTS
} from "../../../src/interface/unstable/IFlowERC1155V5.sol";
import {FlowERC1155Test} from "test/abstract/FlowERC1155Test.sol";
import {IFlowERC1155V5} from "../../../src/interface/unstable/IFlowERC1155V5.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {MissingSentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";

contract Erc1155FlowTest is FlowERC1155Test {
    using LibEvaluable for EvaluableV2;
    using SignContextLib for Vm;
    using LibUint256Matrix for uint256[];
    using Address for address;

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
    function testFlowERC1155FlowERC20ToERC20(
        uint256 erc1155OutAmount,
        uint256 erc20InAmount,
        string memory uri,
        uint256 fuzzedKeyAlice,
        uint256 id
    ) external {
        vm.assume(sentinel != erc1155OutAmount);
        vm.assume(sentinel != erc20InAmount);
        vm.assume(sentinel != id);

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);
        assumeEtchable(alice, address(erc1155Flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(erc1155Flow), to: alice, amount: erc1155OutAmount});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenB), from: alice, to: address(erc1155Flow), amount: erc20InAmount});

        vm.startPrank(alice);

        vm.mockCall(address(iTokenA), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(address(iTokenA), abi.encodeWithSelector(IERC20.transfer.selector, alice, erc1155OutAmount));

        vm.mockCall(address(iTokenB), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(
            address(iTokenB), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, erc1155Flow, erc20InAmount)
        );

        ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](1);
        mints[0] = ERC1155SupplyChange({account: alice, id: id, amount: erc20InAmount});

        ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
        burns[0] = ERC1155SupplyChange({account: alice, id: id, amount: 0 ether});

        uint256[] memory stack = generateFlowStack(
            FlowERC1155IOV1(
                mints, burns, FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
            )
        );

        interpreterEval2MockCall(stack, new uint256[](0));

        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, new uint256[](0));
        signedContexts1[1] = vm.signContext(aliceKey, aliceKey, new uint256[](0));

        erc1155Flow.flow(evaluable, new uint256[](0), signedContexts1);
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155FlowERC721ToERC721(
        uint256 fuzzedKeyAlice,
        uint256 erc721OutTokenId,
        uint256 erc721InTokenId,
        string memory uri,
        uint256 amount
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        vm.assume(sentinel != erc721OutTokenId);
        vm.assume(sentinel != erc721InTokenId);
        vm.assume(sentinel != amount);

        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);
        assumeEtchable(alice, address(erc1155Flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
        erc721Transfers[0] =
            ERC721Transfer({token: address(iTokenA), from: address(erc1155Flow), to: alice, id: erc721OutTokenId});
        erc721Transfers[1] =
            ERC721Transfer({token: address(iTokenB), from: alice, to: address(erc1155Flow), id: erc721InTokenId});

        vm.mockCall(iTokenA, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), erc1155Flow, alice, erc721OutTokenId
            )
        );

        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), alice, erc1155Flow, erc721InTokenId
            )
        );
        ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](1);
        mints[0] = ERC1155SupplyChange({account: alice, id: erc721InTokenId, amount: amount});

        ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
        burns[0] = ERC1155SupplyChange({account: alice, id: erc721InTokenId, amount: 0 ether});

        uint256[] memory stack = generateFlowStack(
            FlowERC1155IOV1(
                mints, burns, FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0))
            )
        );
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        erc1155Flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155FlowERC1155ToERC1155(
        uint256 fuzzedKeyAlice,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155InTokenId,
        uint256 erc1155InAmount,
        string memory uri
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmount);
        vm.assume(sentinel != erc1155InTokenId);
        vm.assume(sentinel != erc1155InAmount);
        vm.label(alice, "alice");

        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);
        assumeEtchable(alice, address(erc1155Flow));

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);
        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iTokenA),
            from: address(erc1155Flow),
            to: alice,
            id: erc1155OutTokenId,
            amount: erc1155OutAmount
        });

        erc1155Transfers[1] = ERC1155Transfer({
            token: address(iTokenB),
            from: alice,
            to: address(erc1155Flow),
            id: erc1155InTokenId,
            amount: erc1155InAmount
        });

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, erc1155Flow, alice, erc1155OutTokenId, erc1155OutAmount, ""
            )
        );

        vm.mockCall(iTokenB, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, alice, erc1155Flow, erc1155InTokenId, erc1155InAmount, ""
            )
        );

        ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](1);
        mints[0] = ERC1155SupplyChange({account: alice, id: erc1155InTokenId, amount: erc1155InAmount});

        ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
        burns[0] = ERC1155SupplyChange({account: alice, id: erc1155InTokenId, amount: 0 ether});

        uint256[] memory stack = generateFlowStack(
            FlowERC1155IOV1(
                mints, burns, FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers)
            )
        );
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        erc1155Flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155FlowERC20ToERC721(
        uint256 fuzzedKeyAlice,
        uint256 erc20InAmount,
        uint256 erc721OutTokenId,
        string memory uri
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        vm.assume(sentinel != erc20InAmount);
        vm.assume(sentinel != erc721OutTokenId);

        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);
        assumeEtchable(alice, address(erc1155Flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: alice, to: address(erc1155Flow), amount: erc20InAmount});

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] =
            ERC721Transfer({token: iTokenB, from: address(erc1155Flow), to: alice, id: erc721OutTokenId});

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector, alice, erc1155Flow, erc20InAmount));

        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), erc1155Flow, alice, erc721OutTokenId
            )
        );
        ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](1);
        mints[0] = ERC1155SupplyChange({account: alice, id: erc721OutTokenId, amount: erc20InAmount});

        ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
        burns[0] = ERC1155SupplyChange({account: alice, id: erc721OutTokenId, amount: 0 ether});

        uint256[] memory stack = generateFlowStack(
            FlowERC1155IOV1(
                new ERC1155SupplyChange[](0),
                new ERC1155SupplyChange[](0),
                FlowTransferV1(erc20Transfers, erc721Transfers, new ERC1155Transfer[](0))
            )
        );

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        erc1155Flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// Should utilize context in CAN_TRANSFER entrypoint
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155UtilizeContextInCanTransferEntrypoint(
        address alice,
        uint256 amount,
        address expressionA,
        address expressionB,
        uint256[] memory writeToStore,
        string memory uri,
        uint256 id
    ) external {
        vm.assume(alice != address(0));
        vm.assume(sentinel != amount);
        vm.assume(sentinel != id);
        vm.assume(expressionA != expressionB);
        vm.assume(writeToStore.length != 0);
        vm.assume(!alice.isContract());

        address[] memory expressions = new address[](1);
        expressions[0] = expressionA;

        (IFlowERC1155V5 flowErc1155, EvaluableV2[] memory evaluables) =
            deployIFlowERC1155V5(expressions, expressionB, new uint256[][](1), uri);
        assumeEtchable(alice, address(flowErc1155));

        {
            ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](1);
            mints[0] = ERC1155SupplyChange({account: alice, id: id, amount: amount});

            ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
            burns[0] = ERC1155SupplyChange({account: alice, id: id, amount: 0 ether});

            uint256[] memory stack = generateFlowStack(
                FlowERC1155IOV1(
                    mints,
                    burns,
                    FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
            flowErc1155.flow(evaluables[0], new uint256[](0), new SignedContextV1[](0));
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
            IERC1155(address(flowErc1155)).safeTransferFrom(alice, address(flowErc1155), id, amount, "");
            vm.stopPrank();
        }
    }

    /// Should mint and burn tokens per flow in exchange for another token (e.g. ERC20).
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155MintAndBurnTokensPerFlowForERC20Exchange(
        uint256 erc20OutAmount,
        uint256 erc20InAmount,
        uint256 tokenId,
        address alice,
        string memory uri
    ) external {
        vm.assume(sentinel != erc20OutAmount);
        vm.assume(sentinel != erc20InAmount);
        vm.assume(sentinel != tokenId);
        vm.assume(address(0) != alice);
        vm.assume(erc20InAmount > erc20OutAmount);
        vm.assume(!alice.isContract());

        (IFlowERC1155V5 flowErc1155, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);
        assumeEtchable(alice, address(flowErc1155));

        {
            vm.mockCall(address(iTokenA), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
            vm.mockCall(address(iTokenB), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

            vm.expectCall(
                address(iTokenA),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, flowErc1155, erc20InAmount),
                2
            );
            vm.expectCall(address(iTokenB), abi.encodeWithSelector(IERC20.transfer.selector, alice, erc20OutAmount), 2);
        }

        // Stack mint
        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);

            erc20Transfers[0] =
                ERC20Transfer({token: address(iTokenA), from: alice, to: address(flowErc1155), amount: erc20InAmount});

            erc20Transfers[1] =
                ERC20Transfer({token: address(iTokenB), from: address(flowErc1155), to: alice, amount: erc20OutAmount});

            ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](1);
            mints[0] = ERC1155SupplyChange({account: alice, id: tokenId, amount: erc20InAmount});

            uint256[] memory stack = generateFlowStack(
                FlowERC1155IOV1(
                    mints,
                    new ERC1155SupplyChange[](0),
                    FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            flowErc1155.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();

            assertEq(IERC1155(address(flowErc1155)).balanceOf(alice, tokenId), erc20InAmount);
        }

        // Stack burn
        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);

            erc20Transfers[0] =
                ERC20Transfer({token: address(iTokenA), from: alice, to: address(flowErc1155), amount: erc20InAmount});

            erc20Transfers[1] =
                ERC20Transfer({token: address(iTokenB), from: address(flowErc1155), to: alice, amount: erc20OutAmount});

            ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
            burns[0] = ERC1155SupplyChange({account: alice, id: tokenId, amount: erc20OutAmount});

            uint256[] memory stack = generateFlowStack(
                FlowERC1155IOV1(
                    new ERC1155SupplyChange[](0),
                    burns,
                    FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            flowErc1155.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();

            assertEq(IERC1155(address(flowErc1155)).balanceOf(alice, tokenId), erc20InAmount - erc20OutAmount);
        }
    }

    /// Should not flow if number of sentinels is less than MIN_FLOW_SENTINELS
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155MinFlowSentinel(address alice, uint128 amount, address expressionA, string memory uri)
        external
    {
        vm.assume(alice != address(0));

        address[] memory expressions = new address[](1);
        expressions[0] = expressionA;

        (IFlowERC1155V5 flowInvalid, EvaluableV2[] memory evaluablesInvalid) =
            deployIFlowERC1155V5(expressions, expressionA, new uint256[][](1), uri);
        assumeEtchable(alice, address(flowInvalid));

        // Check that flow with invalid number of sentinels fails
        {
            uint256[] memory stackInvalid = generateFlowStack(
                FlowERC1155IOV1(
                    new ERC1155SupplyChange[](0),
                    new ERC1155SupplyChange[](0),
                    FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );

            // Change stack sentinel
            stackInvalid[0] = 0;
            interpreterEval2MockCall(stackInvalid, new uint256[](0));
        }

        uint256[][] memory contextInvalid = LibContextWrapper.buildAndSetContext(
            LibUint256Array.arrayFrom(uint256(uint160(address(alice))), uint256(uint160(address(flowInvalid))), amount)
                .matrixFrom(),
            new SignedContextV1[](0),
            address(alice),
            address(flowInvalid)
        );

        interpreterEval2RevertCall(
            address(flowInvalid),
            LibEncodedDispatch.encode2(
                expressionA, FLOW_ERC1155_HANDLE_TRANSFER_ENTRYPOINT, FLOW_ERC1155_HANDLE_TRANSFER_MAX_OUTPUTS
            ),
            contextInvalid
        );

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(MissingSentinel.selector, sentinel));
        flowInvalid.flow(evaluablesInvalid[0], new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }
}
