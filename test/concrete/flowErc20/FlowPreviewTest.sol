// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {IFlowERC20V5, ERC20SupplyChange, FlowERC20IOV1} from "../../../src/interface/unstable/IFlowERC20V5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {FlowERC20Test} from "test/abstract/FlowERC20Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract FlowPreviewTest is FlowERC20Test {
    using LibEvaluable for EvaluableV2;

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using multi-element arrays.
     */
    function testFlowERC20PreviewDefinedFlowIOForERC1155MultiElementArrays(
        string memory name,
        string memory symbol,
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

        (IFlowERC20V5 flow,) = deployFlowERC20(name, symbol);
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

        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: alice, amount: 20 ether});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: alice, amount: 10 ether});

        FlowERC20IOV1 memory flowERC20IO = FlowERC20IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers)
        );

        uint256[] memory stack = generateFlowStack(flowERC20IO);

        assertEq(
            keccak256(abi.encode(flowERC20IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     *      using multi-element arrays.
     */
    function testFlowERC20PreviewDefinedFlowIOForERC721MultiElementArrays(
        string memory name,
        string memory symbol,
        address alice,
        uint256 erc721TokenIdA,
        uint256 erc721TokenIdB
    ) external {
        vm.assume(sentinel != erc721TokenIdA);
        vm.assume(sentinel != erc721TokenIdB);

        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20(name, symbol);
        assumeEtchable(alice, address(flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](4);
        erc721Transfers[0] = ERC721Transfer({token: iTokenA, from: address(flow), to: alice, id: erc721TokenIdA});
        erc721Transfers[1] = ERC721Transfer({token: iTokenB, from: address(flow), to: alice, id: erc721TokenIdB});
        erc721Transfers[2] = ERC721Transfer({token: iTokenA, from: alice, to: address(flow), id: erc721TokenIdA});
        erc721Transfers[3] = ERC721Transfer({token: iTokenB, from: alice, to: address(flow), id: erc721TokenIdB});

        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: alice, amount: 20 ether});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: alice, amount: 10 ether});

        FlowERC20IOV1 memory flowERC20IO = FlowERC20IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC20IO);

        assertEq(
            keccak256(abi.encode(flowERC20IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }
}
