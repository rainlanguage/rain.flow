// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {IFlowERC20V5, ERC20SupplyChange, FlowERC20IOV1} from "../../../src/interface/unstable/IFlowERC20V5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {FlowERC20Test} from "test/abstract/FlowERC20Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

contract FlowPreviewTest is FlowERC20Test {
    using LibEvaluable for EvaluableV2;
    using LibStackGeneration for uint256;
    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using multi-element arrays.
     */

    function testFlowERC20PreviewDefinedFlowIOForERC1155MultiElementArrays(
        address alice,
        uint256 erc1155OutTokenIdA,
        uint256 erc1155OutAmountA,
        uint256 erc1155InTokenIdB,
        uint256 erc1155InAmountB
    ) external {
        vm.label(alice, "alice");

        (address flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice,
            20 ether,
            10 ether,
            multiTransferERC1155(
                alice, flow, erc1155InTokenIdB, erc1155InAmountB, erc1155OutTokenIdA, erc1155OutAmountA
            )
        );

        assertEq(transferHash, abstractStackToFlowCall(flow, stack), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     *      using multi-element arrays.
     */
    function testFlowERC20PreviewDefinedFlowIOForERC721MultiElementArrays(
        address alice,
        uint256 erc721TokenIdA,
        uint256 erc721TokenIdB
    ) external {
        vm.label(alice, "alice");

        (address flow,) = deployFlow();
        assumeEtchable(alice, flow);

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice, 20 ether, 10 ether, multiTransferERC721(alice, flow, erc721TokenIdA, erc721TokenIdB)
        );

        assertEq(transferHash, abstractStackToFlowCall(flow, stack), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     *      using multi-element arrays.
     */
    function testFlowERC20PreviewDefinedFlowIOForERC20MultiElementArrays(
        address alice,
        uint256 erc20AmountA,
        uint256 erc20AmountB
    ) external {
        vm.label(alice, "alice");

        (address flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice, 20 ether, 10 ether, multiTransfersERC20(alice, flow, erc20AmountA, erc20AmountB)
        );

        assertEq(transferHash, abstractStackToFlowCall(flow, stack), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using single-element arrays.
     */
    function testFlowERC20PreviewDefinedFlowIOForERC1155SingleElementArrays(
        address alice,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155InTokenId,
        uint256 erc1155InAmount
    ) external {
        vm.label(alice, "alice");

        (address flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice,
            20 ether,
            10 ether,
            onlyTransferERC1155ToERC1155(
                alice, flow, erc1155InTokenId, erc1155InAmount, erc1155OutTokenId, erc1155OutAmount
            )
        );

        assertEq(transferHash, abstractStackToFlowCall(flow, stack), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     *      using single-element arrays.
     */
    function testFlowERC20PreviewDefinedFlowIOForERC721SingleElementArrays(
        address alice,
        uint256 erc721TokenInId,
        uint256 erc721TokenOutId
    ) external {
        vm.label(alice, "alice");

        (address flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice, 20 ether, 10 ether, onlyTransferERC721ToERC721(alice, flow, erc721TokenInId, erc721TokenOutId)
        );

        assertEq(transferHash, abstractStackToFlowCall(flow, stack), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     *      using single-element arrays.
     */
    function testFlowERC20PreviewDefinedFlowIOForERC20SingleElementArrays(
        address alice,
        uint256 erc20AmountIn,
        uint256 erc20AmountOut
    ) external {
        vm.label(alice, "alice");

        (address flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice, 20 ether, 10 ether, onlyTransfersERC20toERC20(alice, flow, erc20AmountIn, erc20AmountOut)
        );

        assertEq(transferHash, abstractStackToFlowCall(flow, stack), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of an empty Flow IO.
     */
    function testFlowERC20PreviewEmptyFlowIO(address alice) public {
        (address flow,) = deployFlow();
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) =
            mintAndBurnFlowStack(alice, 20 ether, 10 ether, transferEmpty());

        assertEq(transferHash, abstractStackToFlowCall(flow, stack), "wrong compare Structs");
    }
}
