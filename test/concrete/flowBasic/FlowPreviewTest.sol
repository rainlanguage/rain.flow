// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {AbstractPreviewTest} from "test/abstract/flow/AbstractPreviewTest.sol";
import {
    IFlowV5, FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer
} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";

contract FlowPreviewTest is AbstractPreviewTest {
    using LibEvaluable for EvaluableV2;

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     * using multi-element arrays.
     */
    function testFlowBasePreviewDefinedFlowIOForERC1155MultiElementArrays(
        address alice,
        uint256 erc1155Amount,
        uint256 erc1155TokenId
    ) external {
        flowPreviewDefinedFlowIOForERC1155MultiElementArrays(alice, erc1155Amount, erc1155TokenId);
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
        flowPreviewDefinedFlowIOForERC721MultiElementArrays(alice, erc721TokenIdA, erc721TokenIdB);
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     * using multi-element arrays.
     */
    function testFlowBasePreviewDefinedFlowIOForERC20MultiElementArrays(
        address alice,
        uint256 erc20AmountA,
        uint256 erc20AmountB
    ) external {
        flowPreviewDefinedFlowIOForERC20MultiElementArrays(alice, erc20AmountA, erc20AmountB);
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     * using single-element arrays.
     */
    function testFlowBasePreviewDefinedFlowIOForERC1155SingleElementArrays(
        address alice,
        uint256 erc1155TokenId,
        uint256 erc1155Amount
    ) external {
        flowPreviewDefinedFlowIOForERC1155SingleElementArrays(alice, erc1155Amount, erc1155TokenId);
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
        flowPreviewDefinedFlowIOForERC721SingleElementArrays(alice, erc721TokenInId, erc721TokenOutId);
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     * using single-element arrays.
     */
    function testFlowBasePreviewDefinedFlowIOForERC20SingleElementArrays(
        address alice,
        uint256 erc20AmountIn,
        uint256 erc20AmountOut
    ) external {
        flowPreviewDefinedFlowIOForERC20SingleElementArrays(alice, erc20AmountIn, erc20AmountOut);
    }

    /**
     * @dev Tests the preview of an empty Flow IO.
     */
    function testFlowBasePreviewEmptyFlowIO() public {
        (IFlowV5 flow,) = deployFlow();

        FlowTransferV1 memory flowTransfer =
            FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0));
        uint256[] memory stack = generateFlowStack(flowTransfer);
        assertEq(
            keccak256(abi.encode(flowTransfer)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }
}
