// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {IFlowV5, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {EvaluableConfigV3, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {UnsupportedERC20Flow} from "src/error/ErrFlow.sol";

contract FlowTest is FlowBasicTest {
    address internal immutable iERC721;
    address internal immutable iERC1155;
    address internal immutable iIERC20;

    constructor() {
        vm.pauseGasMetering();
        iERC721 = address(uint160(uint256(keccak256("erc721.test"))));
        vm.etch(address(iERC721), REVERTING_MOCK_BYTECODE);

        iERC1155 = address(uint160(uint256(keccak256("erc1155.test"))));
        vm.etch(address(iERC1155), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();

        iIERC20 = address(uint160(uint256(keccak256("erc20.test"))));
        vm.etch(address(iIERC20), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    function testFlowERC721ToERC1155(
        address alice,
        uint256 erc721InTokenId,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmmount
    ) external {
        vm.assume(alice != address(0));
        vm.assume(sentinel != uint256(uint160(alice)));
        vm.assume(sentinel != erc721InTokenId);
        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmmount);

        vm.label(alice, "Alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] =
            ERC721Transfer({token: address(iERC721), from: alice, to: address(flow), id: erc721InTokenId});

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](1);
        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iERC1155),
            from: address(flow),
            to: alice,
            id: erc1155OutTokenId,
            amount: erc1155OutAmmount
        });

        vm.mockCall(iERC1155, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), abi.encode());
        vm.expectCall(
            iERC1155,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, flow, alice, erc1155OutTokenId, erc1155OutAmmount, ""
            )
        );

        vm.mockCall(
            iERC721,
            abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))),
            abi.encode()
        );
        vm.expectCall(
            iERC721,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), alice, flow, erc721InTokenId
            )
        );

        uint256[] memory stack = generateTokenTransferStack(erc1155Transfers, erc721Transfers, new ERC20Transfer[](0));

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC20ToERC721(address bob, uint256 erc20InAmount, uint256 erc721OutTokenId) external {
        vm.assume(bob != address(0));
        vm.assume(sentinel != uint256(uint160(bob)));
        vm.assume(sentinel != erc20InAmount);
        vm.assume(sentinel != erc721OutTokenId);
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iIERC20), from: bob, to: address(flow), amount: erc20InAmount});

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] = ERC721Transfer({token: iERC721, from: address(flow), to: bob, id: erc721OutTokenId});

        vm.mockCall(iIERC20, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(iIERC20, abi.encodeWithSelector(IERC20.transferFrom.selector, bob, flow, erc20InAmount));

        vm.mockCall(
            iERC721,
            abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))),
            abi.encode()
        );
        vm.expectCall(
            iERC721,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), flow, bob, erc721OutTokenId
            )
        );

        uint256[] memory stack = generateTokenTransferStack(new ERC1155Transfer[](0), erc721Transfers, erc20Transfers);

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
        vm.assume(alice != address(0));
        vm.assume(sentinel != uint256(uint160(alice)));
        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmmount);
        vm.assume(sentinel != erc1155BInTokenId);
        vm.assume(sentinel != erc1155BInAmmount);
        vm.label(alice, "alice");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        address iERC1155B = address(uint160(uint256(keccak256("erc1155B.test"))));
        vm.etch(address(iERC1155B), REVERTING_MOCK_BYTECODE);

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);
        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iERC1155),
            from: address(flow),
            to: alice,
            id: erc1155OutTokenId,
            amount: erc1155OutAmmount
        });

        erc1155Transfers[1] = ERC1155Transfer({
            token: address(iERC1155B),
            from: alice,
            to: address(flow),
            id: erc1155BInTokenId,
            amount: erc1155BInAmmount
        });

        vm.mockCall(iERC1155, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), abi.encode());
        vm.expectCall(
            iERC1155,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, flow, alice, erc1155OutTokenId, erc1155OutAmmount, ""
            )
        );

        vm.mockCall(iERC1155B, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), abi.encode());
        vm.expectCall(
            iERC1155B,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, alice, flow, erc1155BInTokenId, erc1155BInAmmount, ""
            )
        );

        uint256[] memory stack =
            generateTokenTransferStack(erc1155Transfers, new ERC721Transfer[](0), new ERC20Transfer[](0));

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(alice);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC721ToERC721(address bob, uint256 erc721OutTokenId, uint256 erc721BInTokenId) external {
        vm.assume(bob != address(0));
        vm.assume(sentinel != uint256(uint160(bob)));
        vm.assume(sentinel != erc721OutTokenId);
        vm.assume(sentinel != erc721BInTokenId);
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        address iERC721B = address(uint160(uint256(keccak256("erc721B.test"))));
        vm.etch(address(iERC721B), REVERTING_MOCK_BYTECODE);

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
        erc721Transfers[0] =
            ERC721Transfer({token: address(iERC721), from: address(flow), to: bob, id: erc721OutTokenId});
        erc721Transfers[1] =
            ERC721Transfer({token: address(iERC721B), from: bob, to: address(flow), id: erc721BInTokenId});

        vm.mockCall(
            iERC721,
            abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))),
            abi.encode()
        );
        vm.expectCall(
            iERC721,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), flow, bob, erc721OutTokenId
            )
        );

        vm.mockCall(
            iERC721B,
            abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))),
            abi.encode()
        );
        vm.expectCall(
            iERC721B,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), bob, flow, erc721BInTokenId
            )
        );

        uint256[] memory stack =
            generateTokenTransferStack(new ERC1155Transfer[](0), erc721Transfers, new ERC20Transfer[](0));

        interpreterEval2MockCall(stack, new uint256[](0));

        vm.startPrank(bob);
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }

    function testFlowERC20ToERC20(address alise, uint256 erc20OutAmmount, uint256 erc20BInAmmount) external {
        vm.assume(alise != address(0));
        vm.assume(sentinel != uint256(uint160(alise)));
        vm.assume(sentinel != erc20OutAmmount);
        vm.assume(sentinel != erc20BInAmmount);
        vm.label(alise, "Alise");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        address iIERC20B = address(uint160(uint256(keccak256("erc20B.test"))));
        vm.etch(address(iIERC20B), REVERTING_MOCK_BYTECODE);

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iIERC20), from: address(flow), to: alise, amount: erc20OutAmmount});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iIERC20B), from: alise, to: address(flow), amount: erc20BInAmmount});

        vm.mockCall(iIERC20, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(iIERC20, abi.encodeWithSelector(IERC20.transfer.selector, alise, erc20OutAmmount));

        vm.mockCall(iIERC20B, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(iIERC20B, abi.encodeWithSelector(IERC20.transferFrom.selector, alise, flow, erc20BInAmmount));

        uint256[] memory stack =
            generateTokenTransferStack(new ERC1155Transfer[](0), new ERC721Transfer[](0), erc20Transfers);

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
        vm.assume(alise != address(0));
        vm.assume(sentinel != uint256(uint160(alise)));
        vm.assume(bob != address(0));
        vm.assume(sentinel != uint256(uint160(bob)));
        vm.assume(sentinel != erc20Ammount);
        vm.assume(bob != alise);
        vm.label(alise, "Alise");
        vm.label(bob, "Bob");

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        address iIERC20B = address(uint160(uint256(keccak256("erc20B.test"))));
        vm.etch(address(iIERC20B), REVERTING_MOCK_BYTECODE);

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
            erc20Transfers[0] =
                ERC20Transfer({token: address(iIERC20), from: bob, to: address(flow), amount: erc20Ammount});
            erc20Transfers[1] =
                ERC20Transfer({token: address(iIERC20B), from: address(flow), to: alise, amount: erc20Ammount});

            uint256[] memory stack =
                generateTokenTransferStack(new ERC1155Transfer[](0), new ERC721Transfer[](0), erc20Transfers);

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alise);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedERC20Flow.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
            erc20Transfers[0] =
                ERC20Transfer({token: address(iIERC20), from: alise, to: address(flow), amount: erc20Ammount});
            erc20Transfers[1] = ERC20Transfer({token: address(iIERC20B), from: bob, to: alise, amount: erc20Ammount});
            vm.mockCall(iIERC20, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));

            uint256[] memory stack =
                generateTokenTransferStack(new ERC1155Transfer[](0), new ERC721Transfer[](0), erc20Transfers);

            interpreterEval2MockCall(stack, new uint256[](0));
        }

        vm.startPrank(alise);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedERC20Flow.selector));
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        vm.stopPrank();
    }
}
