pragma solidity =0.8.19;

import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

contract AbstractPreviewTest is FlowBasicTest {
    using LibEvaluable for EvaluableV2;
    using LibStackGeneration for uint256;
    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using multi-element arrays.
     */

    function flowPreviewDefinedFlowIOForERC1155MultiElementArrays(
        address alice,
        uint256 erc1155Amount,
        uint256 erc1155TokenId
    ) internal {
        vm.label(alice, "alice");

        (address flow,) = deployFlowWithConfig();
        assumeEtchable(alice, flow);
        {
            (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                multiTransferERC1155(alice, flow, erc1155TokenId, erc1155Amount, erc1155TokenId, erc1155Amount)
            );
            assertEq(transferHash, abstractStackToFlowCall(flow, stack), "wrong compare Structs");
        }
    }
}
