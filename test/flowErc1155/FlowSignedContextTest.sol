// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "forge-std/Test.sol";
import {Flow, FlowTransferV1} from "../../src/concrete/basic/Flow.sol";
import {
    SignedContextV1,
    EvaluableConfigV3,
    EvaluableV2
} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {IInterpreterV2, IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterV2.sol";

contract FlowTest is Test {
    function testValidateMultipleSignedContexts(
        bytes memory data,
        IInterpreterV2 interpreter,
        IInterpreterStoreV2 store,
        address expression,
        uint256[] memory callerContext,
        SignedContextV1[] memory signedContexts,
        uint256 fuzzedKeyAlice
    ) public {
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        // Create a new Flow contract instance
        Flow flow = new Flow();

        // Decode the data to initialize the contract
        EvaluableConfigV3[] memory flowConfig = abi.decode(data, (EvaluableConfigV3[]));

        // Initialization
        vm.prank(alice);
        flow.initialize(data);

        // Create an evaluable object
        EvaluableV2 memory evaluable = EvaluableV2({interpreter: interpreter, store: store, expression: expression});

        // Call the flow function with fuzzed data
        FlowTransferV1 memory flowTransfer = flow.flow(evaluable, callerContext, signedContexts);
    }
}
