// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

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

contract Erc20FlowTest is FlowERC20Test {
    using LibEvaluable for EvaluableV2;
    using LibUint256Matrix for uint256[];
    using LibUint256Array for uint256[];
    using SignContextLib for Vm;
    using LibContextWrapper for uint256[][];

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

        (IFlowERC20V5 flow, EvaluableV2[] memory evaluables) =
            deployFlowERC20(expressions, expressionB, new uint256[][](1), "Flow ERC20", "F20");
        assumeEtchable(alice, address(flow));

        {
            ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
            mints[0] = ERC20SupplyChange({account: alice, amount: amount});

            ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
            burns[0] = ERC20SupplyChange({account: alice, amount: 0 ether});

            uint256[] memory stack = generateFlowStack(
                FlowERC20IOV1(
                    mints,
                    burns,
                    FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );
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
                    expressionB, FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT, FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                context
            );

            flow.flow(evaluables[0], new uint256[](0), new SignedContextV1[](0));

            vm.startPrank(alice);
            IERC20(address(flow)).transfer(address(flow), amount);
            vm.stopPrank();
        }

        {
            interpreterEval2RevertCall(
                address(flow),
                LibEncodedDispatch.encode2(
                    expressionB, FLOW_ERC20_HANDLE_TRANSFER_ENTRYPOINT, FLOW_ERC20_HANDLE_TRANSFER_MAX_OUTPUTS
                ),
                context
            );

            flow.flow(evaluables[0], new uint256[](0), new SignedContextV1[](0));

            vm.startPrank(alice);
            vm.expectRevert("REVERT_EVAL2_CALL");
            IERC20(address(flow)).transfer(address(flow), amount);
            vm.stopPrank();
        }
    }

    function testFlowERC20FlowERC20ToERC721(
        uint256 fuzzedKeyAlice,
        uint256 erc20InAmount,
        uint256 erc721OutTokenId,
        string memory name,
        string memory symbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        vm.assume(sentinel != erc20InAmount);
        vm.assume(sentinel != erc721OutTokenId);

        (IFlowERC20V5 erc20Flow, EvaluableV2 memory evaluable) = deployFlowERC20(name, symbol);
        assumeEtchable(alice, address(erc20Flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: alice, to: address(erc20Flow), amount: erc20InAmount});

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] = ERC721Transfer({token: iTokenB, from: address(erc20Flow), to: alice, id: erc721OutTokenId});

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector, alice, erc20Flow, erc20InAmount));

        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), erc20Flow, alice, erc721OutTokenId
            )
        );

        uint256[] memory stack = generateFlowStack(
            FlowERC20IOV1(
                new ERC20SupplyChange[](0),
                new ERC20SupplyChange[](0),
                FlowTransferV1(erc20Transfers, erc721Transfers, new ERC1155Transfer[](0))
            )
        );
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        erc20Flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC20FlowERC1155ToERC1155(
        uint256 fuzzedKeyAlice,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmmount,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmmount,
        string memory flow
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmmount);
        vm.assume(sentinel != erc1155BInTokenId);
        vm.assume(sentinel != erc1155BInAmmount);

        (IFlowERC20V5 erc20Flow, EvaluableV2 memory evaluable) = deployFlowERC20({name: flow, symbol: flow});
        assumeEtchable(alice, address(erc20Flow));

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);
        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iTokenA),
            from: address(erc20Flow),
            to: alice,
            id: erc1155OutTokenId,
            amount: erc1155OutAmmount
        });

        erc1155Transfers[1] = ERC1155Transfer({
            token: address(iTokenB),
            from: alice,
            to: address(erc20Flow),
            id: erc1155BInTokenId,
            amount: erc1155BInAmmount
        });

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, erc20Flow, alice, erc1155OutTokenId, erc1155OutAmmount, ""
            )
        );

        vm.mockCall(iTokenB, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, alice, erc20Flow, erc1155BInTokenId, erc1155BInAmmount, ""
            )
        );

        uint256[] memory stack = generateFlowStack(
            FlowERC20IOV1(
                new ERC20SupplyChange[](0),
                new ERC20SupplyChange[](0),
                FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers)
            )
        );

        interpreterEval2MockCall(stack, new uint256[](0));
        vm.startPrank(alice);
        erc20Flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC20FlowERC721ToERC721(
        uint256 fuzzedKeyAlice,
        uint256 erc721OutTokenId,
        uint256 erc721BInTokenId,
        string memory name,
        string memory symbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        vm.assume(sentinel != erc721OutTokenId);
        vm.assume(sentinel != erc721BInTokenId);

        (IFlowERC20V5 erc20Flow, EvaluableV2 memory evaluable) = deployFlowERC20(name, symbol);
        assumeEtchable(alice, address(erc20Flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
        erc721Transfers[0] =
            ERC721Transfer({token: address(iTokenA), from: address(erc20Flow), to: alice, id: erc721OutTokenId});
        erc721Transfers[1] =
            ERC721Transfer({token: address(iTokenB), from: alice, to: address(erc20Flow), id: erc721BInTokenId});

        vm.mockCall(iTokenA, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), erc20Flow, alice, erc721OutTokenId
            )
        );

        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), alice, erc20Flow, erc721BInTokenId
            )
        );

        uint256[] memory stack = generateFlowStack(
            FlowERC20IOV1(
                new ERC20SupplyChange[](0),
                new ERC20SupplyChange[](0),
                FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0))
            )
        );

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        erc20Flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC20FlowERC20ToERC20(
        uint256 erc20OutAmmount,
        uint256 erc20BInAmmount,
        string memory name,
        string memory symbol,
        uint256 fuzzedKeyAlice
    ) external {
        vm.assume(sentinel != erc20OutAmmount);
        vm.assume(sentinel != erc20BInAmmount);

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        (IFlowERC20V5 erc20Flow, EvaluableV2 memory evaluable) = deployFlowERC20(name, symbol);
        assumeEtchable(alice, address(erc20Flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(erc20Flow), to: alice, amount: erc20OutAmmount});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenB), from: alice, to: address(erc20Flow), amount: erc20BInAmmount});

        vm.startPrank(alice);

        vm.mockCall(address(iTokenA), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(address(iTokenA), abi.encodeWithSelector(IERC20.transfer.selector, alice, erc20OutAmmount));

        vm.mockCall(address(iTokenB), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(
            address(iTokenB), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, erc20Flow, erc20BInAmmount)
        );

        uint256[] memory stack = generateFlowStack(
            FlowERC20IOV1(
                new ERC20SupplyChange[](0),
                new ERC20SupplyChange[](0),
                FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
            )
        );
        interpreterEval2MockCall(stack, new uint256[](0));

        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, new uint256[](0));
        signedContexts1[1] = vm.signContext(aliceKey, aliceKey, new uint256[](0));

        erc20Flow.flow(evaluable, new uint256[](0), signedContexts1);
        vm.stopPrank();
    }
}
