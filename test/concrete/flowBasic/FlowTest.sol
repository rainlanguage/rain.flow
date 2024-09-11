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

contract FlowTest is FlowBasicTest {
    using LibEvaluable for EvaluableV2;

    function testFlowERC721ToERC1155(
        address alice,
        uint256 erc721InTokenId,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmmount
    ) external {
        vm.assume(sentinel != erc721InTokenId);
        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmmount);

        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        assumeEtchable(alice, address(flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] =
            ERC721Transfer({token: address(iTokenA), from: alice, to: address(flow), id: erc721InTokenId});

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](1);
        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iTokenB),
            from: address(flow),
            to: alice,
            id: erc1155OutTokenId,
            amount: erc1155OutAmmount
        });

        vm.mockCall(iTokenB, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, flow, alice, erc1155OutTokenId, erc1155OutAmmount, ""
            )
        );

        vm.mockCall(iTokenA, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), alice, flow, erc721InTokenId
            )
        );

        uint256[] memory stack =
            generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, erc1155Transfers));
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

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

    function testFlowERC1155ToERC1155(
        address alice,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmmount,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmmount
    ) external {
        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmmount);
        vm.assume(sentinel != erc1155BInTokenId);
        vm.assume(sentinel != erc1155BInAmmount);
        vm.label(alice, "alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);
        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iTokenA),
            from: address(flow),
            to: alice,
            id: erc1155OutTokenId,
            amount: erc1155OutAmmount
        });

        erc1155Transfers[1] = ERC1155Transfer({
            token: address(iTokenB),
            from: alice,
            to: address(flow),
            id: erc1155BInTokenId,
            amount: erc1155BInAmmount
        });

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, flow, alice, erc1155OutTokenId, erc1155OutAmmount, ""
            )
        );

        vm.mockCall(iTokenB, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, alice, flow, erc1155BInTokenId, erc1155BInAmmount, ""
            )
        );

        uint256[] memory stack =
            generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers));

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC721ToERC721(address bob, uint256 erc721OutTokenId, uint256 erc721BInTokenId) external {
        vm.assume(sentinel != erc721OutTokenId);
        vm.assume(sentinel != erc721BInTokenId);
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(bob, address(flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
        erc721Transfers[0] =
            ERC721Transfer({token: address(iTokenA), from: address(flow), to: bob, id: erc721OutTokenId});
        erc721Transfers[1] =
            ERC721Transfer({token: address(iTokenB), from: bob, to: address(flow), id: erc721BInTokenId});

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
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), bob, flow, erc721BInTokenId
            )
        );

        uint256[] memory stack =
            generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0)));

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(bob);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC20ToERC20(address alise, uint256 erc20OutAmmount, uint256 erc20BInAmmount) external {
        vm.assume(sentinel != erc20OutAmmount);
        vm.assume(sentinel != erc20BInAmmount);
        vm.label(alise, "Alise");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alise, address(flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(flow), to: alise, amount: erc20OutAmmount});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenB), from: alise, to: address(flow), amount: erc20BInAmmount});

        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(iTokenA, abi.encodeWithSelector(IERC20.transfer.selector, alise, erc20OutAmmount));

        vm.mockCall(iTokenB, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(iTokenB, abi.encodeWithSelector(IERC20.transferFrom.selector, alise, flow, erc20BInAmmount));

        uint256[] memory stack =
            generateFlowStack(FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0)));

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alise);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowShouldErrorIfERC20FlowFromIsOtherThanSourceContractOrMsgSender(
        address alise,
        address bob,
        uint256 erc20Ammount
    ) external {
        vm.assume(sentinel != erc20Ammount);
        vm.assume(bob != alise);
        vm.label(alise, "Alise");
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alise, address(flow));
        assumeEtchable(bob, address(flow));

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
            erc20Transfers[0] =
                ERC20Transfer({token: address(iTokenA), from: bob, to: address(flow), amount: erc20Ammount});
            erc20Transfers[1] =
                ERC20Transfer({token: address(iTokenB), from: address(flow), to: alise, amount: erc20Ammount});

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
                ERC20Transfer({token: address(iTokenA), from: alise, to: address(flow), amount: erc20Ammount});
            erc20Transfers[1] = ERC20Transfer({token: address(iTokenB), from: bob, to: alise, amount: erc20Ammount});
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

    function testFlowShouldErrorIfERC1155FlowFromIsOtherThanSourceContractOrMsgSender(
        address alise,
        address bob,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmmount,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmmount
    ) external {
        vm.assume(bob != alise);
        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmmount);
        vm.assume(sentinel != erc1155BInTokenId);
        vm.assume(sentinel != erc1155BInAmmount);
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
                amount: erc1155OutAmmount
            });

            erc1155Transfers[1] = ERC1155Transfer({
                token: address(iTokenB),
                from: address(flow),
                to: alise,
                id: erc1155BInTokenId,
                amount: erc1155BInAmmount
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

        (address flowB,) = deployFlow(expressionsB, new uint256[][](1));
        vm.startPrank(alise);
        vm.expectRevert(abi.encodeWithSelector(UnregisteredFlow.selector, evaluables[0].hash()));
        IFlowV5(flowB).flow(evaluables[0], new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }
}
