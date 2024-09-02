// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {FlowERC721Test} from "test/abstract/FlowERC721Test.sol";
import {IFlowERC721V5, ERC721SupplyChange, FlowERC721IOV1} from "../../../src/interface/unstable/IFlowERC721V5.sol";

contract FlowPreviewTest is FlowERC721Test {
    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using multi-element arrays.
     */
    function testFlowERC721PreviewDefinedFlowIOForERC1155MultiElementArrays(
        string memory symbol,
        string memory baseURI,
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

        (IFlowERC721V5 flow,) = deployFlowERC721({name: symbol, symbol: symbol, baseURI: baseURI});

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

        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](2);
        mints[0] = ERC721SupplyChange({account: alice, id: 1});
        mints[1] = ERC721SupplyChange({account: alice, id: 2});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: 2});

        FlowERC721IOV1 memory flowERC721IO = FlowERC721IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers)
        );

        uint256[] memory stack = generateFlowStack(flowERC721IO);

        assertEq(
            keccak256(abi.encode(flowERC721IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     *      using multi-element arrays.
     */
    function testFlowERC721PreviewDefinedFlowIOForERC721MultiElementArrays(
        string memory symbol,
        string memory baseURI,
        address alice,
        uint256 erc721TokenIdA,
        uint256 erc721TokenIdB
    ) external {
        vm.assume(sentinel != erc721TokenIdA);
        vm.assume(sentinel != erc721TokenIdB);

        vm.label(alice, "alice");

        (IFlowERC721V5 flow,) = deployFlowERC721({name: symbol, symbol: symbol, baseURI: baseURI});
        assumeEtchable(alice, address(flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](4);
        erc721Transfers[0] = ERC721Transfer({token: iTokenA, from: address(flow), to: alice, id: erc721TokenIdA});
        erc721Transfers[1] = ERC721Transfer({token: iTokenB, from: address(flow), to: alice, id: erc721TokenIdB});
        erc721Transfers[2] = ERC721Transfer({token: iTokenA, from: alice, to: address(flow), id: erc721TokenIdA});
        erc721Transfers[3] = ERC721Transfer({token: iTokenB, from: alice, to: address(flow), id: erc721TokenIdB});

        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](2);
        mints[0] = ERC721SupplyChange({account: alice, id: 1});
        mints[1] = ERC721SupplyChange({account: alice, id: 2});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: 2});

        FlowERC721IOV1 memory flowERC721IO = FlowERC721IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC721IO);

        assertEq(
            keccak256(abi.encode(flowERC721IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }
}
