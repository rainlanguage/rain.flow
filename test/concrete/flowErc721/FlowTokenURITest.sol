// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";
import {FlowERC721Test} from "test/abstract/FlowERC721Test.sol";
import {IERC721Metadata} from "openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {
    IFlowERC721V5,
    FLOW_ERC721_TOKEN_URI_ENTRYPOINT,
    FLOW_ERC721_TOKEN_URI_MAX_OUTPUTS
} from "src/interface/unstable/IFlowERC721V5.sol";

import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract Erc721TokenURITest is FlowERC721Test {
    using LibEvaluable for EvaluableV2;
    using LibContextWrapper for uint256[][];
    using LibUint256Matrix for uint256[];
    using Strings for uint256;

    /**
     * @dev Tests the generation of tokenURI based on the expression result.
     */
    function testGenerateTokenURIBasedOnExpressionResult(address alice, uint256 tokenId) external {
        vm.assume(alice != address(0));
        vm.assume(tokenId > 0);

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, flow);

        {
            (uint256[] memory stack,) = mintFlowStack(alice, 0, tokenId, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
            IFlowERC721V5(flow).flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        }

        {
            uint256[] memory stack = new uint256[](1);
            stack[0] = tokenId;
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        uint256[][] memory context = LibContextWrapper.buildAndSetContext(
            LibUint256Array.arrayFrom(tokenId).matrixFrom(), new SignedContextV1[](0), alice, flow
        );

        {
            // Expect call token URI
            interpreterEval2ExpectCall(
                flow,
                LibEncodedDispatch.encode2(
                    address(uint160(uint256(keccak256("configExpression")))),
                    FLOW_ERC721_TOKEN_URI_ENTRYPOINT,
                    FLOW_ERC721_TOKEN_URI_MAX_OUTPUTS
                ),
                context
            );

            vm.startPrank(alice);
            assertEq(
                string.concat(baseURI, tokenId.toString()),
                IERC721Metadata(flow).tokenURI(tokenId),
                "Unexpected token URI mismatch"
            );
            vm.stopPrank();
        }

        {
            interpreterEval2RevertCall(
                flow,
                LibEncodedDispatch.encode2(
                    address(uint160(uint256(keccak256("configExpression")))),
                    FLOW_ERC721_TOKEN_URI_ENTRYPOINT,
                    FLOW_ERC721_TOKEN_URI_MAX_OUTPUTS
                ),
                context
            );

            vm.startPrank(alice);
            vm.expectRevert("REVERT_EVAL2_CALL");
            IERC721Metadata(flow).tokenURI(tokenId);
            vm.stopPrank();
        }
    }
}
