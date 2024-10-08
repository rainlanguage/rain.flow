// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {FlowERC1155} from "../../../src/concrete/erc1155/FlowERC1155.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {IFlowERC1155V5} from "../../../src/interface/unstable/IFlowERC1155V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {InvalidSignature} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {FlowERC1155Test} from "../../abstract/FlowERC1155Test.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";

contract FlowSignedContextTest is FlowUtilsAbstractTest, FlowERC1155Test {
    using SignContextLib for Vm;

    /// Should validate multiple signed contexts
    function testValidateMultipleSignedContexts(
        string memory uri,
        uint256[] memory context0,
        uint256[] memory context1,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);
        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;

        SignedContextV1[] memory signedContexts = new SignedContextV1[](2);
        signedContexts[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts[1] = vm.signContext(aliceKey, aliceKey, context1);

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(vm.addr(aliceKey), 20 ether, 10 ether, 5, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
        }
        erc1155Flow.flow(evaluable, new uint256[](0), signedContexts);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts1[1] = vm.signContext(aliceKey, bobKey, context1);

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 1));
        erc1155Flow.flow(evaluable, new uint256[](0), signedContexts1);
    }

    /// Should validate a signed context
    function testValidateSignedContexts(
        string memory uri,
        uint256[] memory context0,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);

        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;

        SignedContextV1[] memory signedContext = new SignedContextV1[](1);
        signedContext[0] = vm.signContext(aliceKey, aliceKey, context0);

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(vm.addr(aliceKey), 20 ether, 10 ether, 5, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        erc1155Flow.flow(evaluable, new uint256[](0), signedContext);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContext1 = new SignedContextV1[](1);
        signedContext1[0] = vm.signContext(aliceKey, bobKey, context0);

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 0));
        erc1155Flow.flow(evaluable, new uint256[](0), signedContext1);
    }
}
