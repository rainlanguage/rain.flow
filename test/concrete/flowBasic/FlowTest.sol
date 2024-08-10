// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {IFlowV5, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {EvaluableConfigV3, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";

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
}
