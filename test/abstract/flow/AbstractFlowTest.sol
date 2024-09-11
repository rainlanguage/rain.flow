// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";

contract AbstractFlowTest is FlowBasicTest {
    /**
     * @notice Tests the flow between ERC721 and ERC1155 on the good path.
     */
    function flowERC20FlowERC721ToERC1155(
        address alice,
        uint256 erc721InTokenId,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) internal {
        vm.assume(address(0) != alice);
        vm.label(alice, "Alice");

        (address flow, EvaluableV2 memory evaluable) = deployFlowWithConfig();
        assumeEtchable(alice, flow);

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                transferRC721ToERC1155(alice, flow, erc721InTokenId, erc1155OutAmount, erc1155OutTokenId)
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        {
            vm.startPrank(alice);
            abstractFlowCall(flow, evaluable, new uint256[](0), new SignedContextV1[](0));
            vm.stopPrank();
        }
    }
}
