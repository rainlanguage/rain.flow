// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {
    IFlowV5, FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer
} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {EvaluableConfigV3, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {
    UnsupportedERC20Flow,
    UnsupportedERC721Flow,
    UnsupportedERC1155Flow,
    UnregisteredFlow
} from "src/error/ErrFlow.sol";

import {FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS} from "src/abstract/FlowCommon.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";

contract FlowTest is FlowBasicTest {
    using LibEvaluable for EvaluableV2;

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721ToERC1155(
        address alice,
        uint256 erc721InTokenId,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) external {
        vm.assume(address(0) != alice);
        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
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
    function testFlowERC20ToERC721(address bob, uint256 erc20InAmount, uint256 erc721OutTokenId) external {
        vm.assume(sentinel != erc20InAmount);
        vm.assume(sentinel != erc721OutTokenId);
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(bob, address(flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: bob, to: address(flow), amount: erc20InAmount});

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] = ERC721Transfer({token: iTokenB, from: address(flow), to: bob, id: erc721OutTokenId});

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector, bob, flow, erc20InAmount));

        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), flow, bob, erc721OutTokenId
            )
        );

        uint256[] memory stack =
            generateFlowStack(FlowTransferV1(erc20Transfers, erc721Transfers, new ERC1155Transfer[](0)));
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(bob);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155ToERC1155(
        address alice,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155InTokenId,
        uint256 erc1155InAmount
    ) external {
        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmount);
        vm.assume(sentinel != erc1155InTokenId);
        vm.assume(sentinel != erc1155InAmount);
        vm.label(alice, "alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);
        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iTokenA),
            from: address(flow),
            to: alice,
            id: erc1155OutTokenId,
            amount: erc1155OutAmount
        });

        erc1155Transfers[1] = ERC1155Transfer({
            token: address(iTokenB),
            from: alice,
            to: address(flow),
            id: erc1155InTokenId,
            amount: erc1155InAmount
        });

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, flow, alice, erc1155OutTokenId, erc1155OutAmount, ""
            )
        );

        vm.mockCall(iTokenB, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, alice, flow, erc1155InTokenId, erc1155InAmount, ""
            )
        );

        uint256[] memory stack =
            generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers));

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721ToERC721(address bob, uint256 erc721OutTokenId, uint256 erc721InTokenId) external {
        vm.assume(sentinel != erc721OutTokenId);
        vm.assume(sentinel != erc721InTokenId);
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(bob, address(flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
        erc721Transfers[0] =
            ERC721Transfer({token: address(iTokenA), from: address(flow), to: bob, id: erc721OutTokenId});
        erc721Transfers[1] =
            ERC721Transfer({token: address(iTokenB), from: bob, to: address(flow), id: erc721InTokenId});

        vm.mockCall(iTokenA, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), flow, bob, erc721OutTokenId
            )
        );

        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), bob, flow, erc721InTokenId
            )
        );

        uint256[] memory stack =
            generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0)));

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(bob);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20ToERC20(address alise, uint256 erc20OutAmount, uint256 erc20InAmount) external {
        vm.assume(sentinel != erc20OutAmount);
        vm.assume(sentinel != erc20InAmount);
        vm.label(alise, "Alise");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alise, address(flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(flow), to: alise, amount: erc20OutAmount});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenB), from: alise, to: address(flow), amount: erc20InAmount});

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(iTokenA, abi.encodeWithSelector(IERC20.transfer.selector, alise, erc20OutAmount));

        vm.mockCall(iTokenB, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(iTokenB, abi.encodeWithSelector(IERC20.transferFrom.selector, alise, flow, erc20InAmount));

        uint256[] memory stack =
            generateFlowStack(FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0)));

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alise);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowShouldErrorIfERC20FlowFromIsOtherThanSourceContractOrMsgSender(
        address alise,
        address bob,
        uint256 erc20Amount
    ) external {
        vm.assume(sentinel != erc20Amount);
        vm.assume(bob != alise);
        vm.label(alise, "Alise");
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alise, address(flow));
        assumeEtchable(bob, address(flow));

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
            erc20Transfers[0] =
                ERC20Transfer({token: address(iTokenA), from: bob, to: address(flow), amount: erc20Amount});
            erc20Transfers[1] =
                ERC20Transfer({token: address(iTokenB), from: address(flow), to: alise, amount: erc20Amount});

            uint256[] memory stack =
                generateFlowStack(FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0)));

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alise);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedERC20Flow.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
            erc20Transfers[0] =
                ERC20Transfer({token: address(iTokenA), from: alise, to: address(flow), amount: erc20Amount});
            erc20Transfers[1] = ERC20Transfer({token: address(iTokenB), from: bob, to: alise, amount: erc20Amount});
            vm.mockCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));

            uint256[] memory stack =
                generateFlowStack(FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0)));

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alise);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedERC20Flow.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowShouldErrorIfERC721FlowFromIsOtherThanSourceContractOrMsgSender(
        address alise,
        address bob,
        uint256 erc721TokenId
    ) external {
        vm.assume(sentinel != erc721TokenId);
        vm.assume(bob != alise);

        vm.label(alise, "Alise");
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alise, address(flow));
        assumeEtchable(bob, address(flow));

        {
            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
            erc721Transfers[0] =
                ERC721Transfer({token: address(iTokenA), from: bob, to: address(flow), id: erc721TokenId});
            erc721Transfers[1] =
                ERC721Transfer({token: address(iTokenB), from: address(flow), to: alise, id: erc721TokenId});

            uint256[] memory stack =
                generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0)));

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alise);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedERC721Flow.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testFlowShouldErrorIfERC1155FlowFromIsOtherThanSourceContractOrMsgSender(
        address alise,
        address bob,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155InTokenId,
        uint256 erc1155InAmount
    ) external {
        vm.assume(bob != alise);
        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmount);
        vm.assume(sentinel != erc1155InTokenId);
        vm.assume(sentinel != erc1155InAmount);
        vm.label(alise, "Alise");
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        assumeEtchable(alise, address(flow));
        assumeEtchable(bob, address(flow));

        {
            ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);
            erc1155Transfers[0] = ERC1155Transfer({
                token: address(iTokenA),
                from: bob,
                to: address(flow),
                id: erc1155OutTokenId,
                amount: erc1155OutAmount
            });

            erc1155Transfers[1] = ERC1155Transfer({
                token: address(iTokenB),
                from: address(flow),
                to: alise,
                id: erc1155InTokenId,
                amount: erc1155InAmount
            });

            uint256[] memory stack =
                generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers));

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alise);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedERC1155Flow.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /// forge-config: default.fuzz.runs = 100
    function testShouldErrorIfFlowBeingEvaluatedIsUnregistered(address alise, address expressionA, address expressionB)
        external
    {
        vm.assume(alise != address(0));
        vm.assume(expressionA != expressionB);
        assumeEtchable(alise);

        vm.label(alise, "Alise");

        address[] memory expressionsA = new address[](1);
        expressionsA[0] = expressionA;

        (, EvaluableV2[] memory evaluables) = deployFlow(expressionsA, new uint256[][](1));

        address[] memory expressionsB = new address[](1);
        expressionsB[0] = expressionB;

        (IFlowV5 flowB,) = deployFlow(expressionsB, new uint256[][](1));
        vm.startPrank(alise);
        vm.expectRevert(abi.encodeWithSelector(UnregisteredFlow.selector, evaluables[0].hash()));
        flowB.flow(evaluables[0], new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    /**
     * @notice Tests that the flow halts if it does not meet the 'ensure' requirement.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowHaltIfEnsureRequirementNotMet() external {
        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
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
