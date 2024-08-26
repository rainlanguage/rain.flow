// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {
    IFlowV5, FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer
} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {FLOW_MAX_OUTPUTS, FLOW_ENTRYPOINT} from "src/abstract/FlowCommon.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {ContextBuilder} from "test/lib/ContextBuilder.sol";

contract FlowContextTest is FlowBasicTest {
    /**
     * @dev Tests context handling during interpreter call, ensuring proper input and output management.
     */
    function testFlowBasicInterpreterContextInputOutputManagement(address alice, uint256[] memory callerContext)
        public
    {
        SignedContextV1[] memory signedContext = new SignedContextV1[](0);
        vm.label(alice, "Alice");
        vm.startPrank(alice);

        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();
        assumeEtchable(alice, address(flow));
        bytes memory flowBytecode = address(flow).code;

        // Temporarily replace Flow contract's bytecode with ContextBuilder's bytecode
        vm.etch(address(flow), type(ContextBuilder).runtimeCode);

        uint256[][] memory context = ContextBuilder(address(flow)).buildContext(alice, callerContext, signedContext);

        // Restore the original bytecode of the Flow contract
        vm.etch(address(flow), flowBytecode);

        {
            uint256[] memory stack = generateFlowStack(
                FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
            );

            interpreterEval2MockCall(stack, new uint256[](0));

            interpreterEval2ExpectCall(
                address(flow),
                LibEncodedDispatch.encode2(evaluable.expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
                context
            );
        }

        flow.flow(evaluable, callerContext, signedContext);
        vm.stopPrank();
    }
}
