// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";

import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {
    IFlowV5, FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer
} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {InvalidSignature} from "rain.interpreter.interface/lib/caller/LibContext.sol";

contract FlowSignedContextTest is FlowBasicTest {
    using SignContextLib for Vm;

    /// Should validate multiple signed contexts
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasicValidateMultipleSignedContexts(
        uint256[] memory context0,
        uint256[] memory context1,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);
        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;

        SignedContextV1[] memory signedContexts = new SignedContextV1[](2);

        signedContexts[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts[1] = vm.signContext(aliceKey, aliceKey, context1);

        uint256[] memory stack =
            generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0)));

        interpreterEval2MockCall(stack, new uint256[](0));
        flow.flow(evaluable, new uint256[](0), signedContexts);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts1[1] = vm.signContext(aliceKey, bobKey, context1);

        uint256[] memory stack1 =
            generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0)));
        interpreterEval2MockCall(stack1, new uint256[](0));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 1));
        flow.flow(evaluable, new uint256[](0), signedContexts1);
    }

    /// Should validate a signed context
    /// forge-config: default.fuzz.runs = 100
    function testFlowBasicValidateSignedContexts(
        uint256[] memory context0,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);
        (IFlowV5 flow, EvaluableV2 memory evaluable) = deployFlow();

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;

        SignedContextV1[] memory signedContext = new SignedContextV1[](1);
        signedContext[0] = vm.signContext(aliceKey, aliceKey, context0);

        uint256[] memory stack =
            generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0)));
        interpreterEval2MockCall(stack, new uint256[](0));
        flow.flow(evaluable, new uint256[](0), signedContext);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContext1 = new SignedContextV1[](1);
        signedContext1[0] = vm.signContext(aliceKey, bobKey, context0);

        uint256[] memory stack1 =
            generateFlowStack(FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0)));
        interpreterEval2MockCall(stack1, new uint256[](0));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 0));
        flow.flow(evaluable, new uint256[](0), signedContext1);
    }
}
