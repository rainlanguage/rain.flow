// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {
    IFlowV5, FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer
} from "src/interface/unstable/IFlowV5.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";

contract FlowPreviewTest is FlowBasicTest {
    address internal immutable iTokenA;
    address internal immutable iTokenB;

    constructor() {
        vm.pauseGasMetering();
        iTokenA = address(uint160(uint256(keccak256("tokenA.test"))));
        vm.etch(address(iTokenA), REVERTING_MOCK_BYTECODE);

        iTokenB = address(uint160(uint256(keccak256("tokenB.test"))));
        vm.etch(address(iTokenB), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     * using multi-element arrays.
     */
    function testFlowBasePreviewDefinedFlowIOForERC1155MultiElementArrays(
        address alice,
        uint256 erc1155OutTokenIdA,
        uint256 erc1155OutAmmountA,
        uint256 erc1155InTokenIdB,
        uint256 erc1155InAmmountB
    ) external {
        vm.assume(sentinel != erc1155OutTokenIdA);
        vm.assume(sentinel != erc1155OutAmmountA);
        vm.assume(sentinel != erc1155InTokenIdB);
        vm.assume(sentinel != erc1155InAmmountB);
        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](4);

        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iTokenA),
            from: address(flow),
            to: alice,
            id: erc1155OutTokenIdA,
            amount: erc1155OutAmmountA
        });

        erc1155Transfers[1] = ERC1155Transfer({
            token: address(iTokenB),
            from: address(flow),
            to: alice,
            id: erc1155InTokenIdB,
            amount: erc1155InAmmountB
        });

        erc1155Transfers[2] = ERC1155Transfer({
            token: address(iTokenA),
            from: alice,
            to: address(flow),
            id: erc1155OutTokenIdA,
            amount: erc1155OutAmmountA
        });

        erc1155Transfers[3] = ERC1155Transfer({
            token: address(iTokenB),
            from: alice,
            to: address(flow),
            id: erc1155InTokenIdB,
            amount: erc1155InAmmountB
        });

        uint256[] memory stack =
            generateTokenTransferStack(erc1155Transfers, new ERC721Transfer[](0), new ERC20Transfer[](0));

        FlowTransferV1 memory flowTransfer =
            FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers);

        assertEq(
            keccak256(abi.encode(flowTransfer)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     * using multi-element arrays.
     */
    function testFlowBasePreviewDefinedFlowIOForERC721MultiElementArrays(
        address alice,
        uint256 erc721TokenIdA,
        uint256 erc721TokenIdB
    ) external {
        vm.assume(sentinel != erc721TokenIdA);
        vm.assume(sentinel != erc721TokenIdB);

        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](4);
        erc721Transfers[0] = ERC721Transfer({token: iTokenA, from: address(flow), to: alice, id: erc721TokenIdA});
        erc721Transfers[1] = ERC721Transfer({token: iTokenB, from: address(flow), to: alice, id: erc721TokenIdB});
        erc721Transfers[2] = ERC721Transfer({token: iTokenA, from: alice, to: address(flow), id: erc721TokenIdA});
        erc721Transfers[3] = ERC721Transfer({token: iTokenB, from: alice, to: address(flow), id: erc721TokenIdB});

        uint256[] memory stack =
            generateTokenTransferStack(new ERC1155Transfer[](0), erc721Transfers, new ERC20Transfer[](0));

        FlowTransferV1 memory flowTransfer =
            FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0));

        assertEq(
            keccak256(abi.encode(flowTransfer)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     * using multi-element arrays.
     */
    function testFlowBasePreviewDefinedFlowIOForERC20MultiElementArrays(
        address alice,
        uint256 erc20AmmountA,
        uint256 erc20AmmountB
    ) external {
        vm.assume(sentinel != erc20AmmountA);
        vm.assume(sentinel != erc20AmmountB);

        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](4);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(flow), to: alice, amount: erc20AmmountA});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenB), from: address(flow), to: alice, amount: erc20AmmountB});
        erc20Transfers[2] =
            ERC20Transfer({token: address(iTokenA), from: alice, to: address(flow), amount: erc20AmmountA});
        erc20Transfers[3] =
            ERC20Transfer({token: address(iTokenB), from: alice, to: address(flow), amount: erc20AmmountB});

        uint256[] memory stack =
            generateTokenTransferStack(new ERC1155Transfer[](0), new ERC721Transfer[](0), erc20Transfers);

        FlowTransferV1 memory flowTransfer =
            FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0));

        assertEq(
            keccak256(abi.encode(flowTransfer)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     * using single-element arrays.
     */
    function testFlowBasePreviewDefinedFlowIOForERC1155SingleElementArrays(
        address alice,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmmount,
        uint256 erc1155InTokenId,
        uint256 erc1155InAmmount
    ) external {
        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmmount);
        vm.assume(sentinel != erc1155InTokenId);
        vm.assume(sentinel != erc1155InAmmount);
        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
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
            token: address(iTokenA),
            from: alice,
            to: address(flow),
            id: erc1155InTokenId,
            amount: erc1155InAmmount
        });

        uint256[] memory stack =
            generateTokenTransferStack(erc1155Transfers, new ERC721Transfer[](0), new ERC20Transfer[](0));

        FlowTransferV1 memory flowTransfer =
            FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers);

        assertEq(
            keccak256(abi.encode(flowTransfer)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     * using single-element arrays.
     */
    function testFlowBasePreviewDefinedFlowIOForERC721SingleElementArrays(
        address alice,
        uint256 erc721TokenInId,
        uint256 erc721TokenOutId
    ) external {
        vm.assume(sentinel != erc721TokenInId);
        vm.assume(sentinel != erc721TokenOutId);

        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
        erc721Transfers[0] = ERC721Transfer({token: iTokenA, from: address(flow), to: alice, id: erc721TokenOutId});
        erc721Transfers[1] = ERC721Transfer({token: iTokenA, from: alice, to: address(flow), id: erc721TokenInId});

        uint256[] memory stack =
            generateTokenTransferStack(new ERC1155Transfer[](0), erc721Transfers, new ERC20Transfer[](0));

        FlowTransferV1 memory flowTransfer =
            FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0));

        assertEq(
            keccak256(abi.encode(flowTransfer)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     * using single-element arrays.
     */
    function testFlowBasePreviewDefinedFlowIOForERC20SingleElementArrays(
        address alice,
        uint256 erc20AmmountIn,
        uint256 erc20AmmountOut
    ) external {
        vm.assume(sentinel != erc20AmmountIn);
        vm.assume(sentinel != erc20AmmountOut);

        vm.label(alice, "alice");

        (IFlowV5 flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(flow), to: alice, amount: erc20AmmountOut});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenA), from: alice, to: address(flow), amount: erc20AmmountIn});

        uint256[] memory stack =
            generateTokenTransferStack(new ERC1155Transfer[](0), new ERC721Transfer[](0), erc20Transfers);

        FlowTransferV1 memory flowTransfer =
            FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0));

        assertEq(
            keccak256(abi.encode(flowTransfer)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of an empty Flow IO.
     */
    function testFlowBasePreviewEmptyFlowIO() public {
        (IFlowV5 flow,) = deployFlow();

        uint256[] memory stack =
            generateTokenTransferStack(new ERC1155Transfer[](0), new ERC721Transfer[](0), new ERC20Transfer[](0));

        FlowTransferV1 memory flowTransfer =
            FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0));

        assertEq(
            keccak256(abi.encode(flowTransfer)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }
}