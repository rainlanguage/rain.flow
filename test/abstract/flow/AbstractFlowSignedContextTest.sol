// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {IFlowERC20V5, ERC20SupplyChange, FlowERC20IOV1} from "../../../src/interface/unstable/IFlowERC20V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {InvalidSignature} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {FlowBasicTest} from "../../abstract/FlowBasicTest.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

abstract contract AbstractFlowSignedContextTest is FlowBasicTest {
    using SignContextLib for Vm;
    using LibStackGeneration for uint256;
    /// Should validate multiple signed contexts

    function absTestFlowValidateMultipleSignedContexts(
        uint256[] memory context0,
        uint256[] memory context1,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) internal {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);
        (address flow, EvaluableV2 memory evaluable) = deployFlow();

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;

        SignedContextV1[] memory signedContexts = new SignedContextV1[](2);

        signedContexts[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts[1] = vm.signContext(aliceKey, aliceKey, context1);
        (uint256[] memory stack,) = emptyFlowStack();
        interpreterEval2MockCall(stack, new uint256[](0));
        abstractFlowCall(flow, evaluable, new uint256[](0), signedContexts);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts1[1] = vm.signContext(aliceKey, bobKey, context1);

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 1));
        abstractFlowCall(flow, evaluable, new uint256[](0), signedContexts1);
    }

    /// Should validate a signed context
    function absTestFlowERC20ValidateSignedContexts(
        uint256[] memory context0,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) internal {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);
        (address flow, EvaluableV2 memory evaluable) = deployFlow();

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;

        SignedContextV1[] memory signedContext = new SignedContextV1[](1);
        signedContext[0] = vm.signContext(aliceKey, aliceKey, context0);

        (uint256[] memory stack,) = emptyFlowStack();
        interpreterEval2MockCall(stack, new uint256[](0));

        abstractFlowCall(flow, evaluable, new uint256[](0), signedContext);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContext1 = new SignedContextV1[](1);
        signedContext1[0] = vm.signContext(aliceKey, bobKey, context0);
        interpreterEval2MockCall(stack, new uint256[](0));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 0));
        abstractFlowCall(flow, evaluable, new uint256[](0), signedContext1);
    }
}
