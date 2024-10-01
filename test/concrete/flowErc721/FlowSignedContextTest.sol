// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {IFlowERC721V5, ERC721SupplyChange, FlowERC721IOV1} from "../../../src/interface/unstable/IFlowERC721V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {InvalidSignature} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {FlowERC721Test} from "../../abstract/FlowERC721Test.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";

contract FlowSignedContextTest is FlowERC721Test {
    using SignContextLib for Vm;

    /// Should validate multiple signed contexts
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721ValidateMultipleSignedContexts(
        string memory name,
        string memory symbol,
        string memory baseURI,
        uint256[] memory context0,
        uint256[] memory context1,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 id
    ) public {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);
        vm.assume(sentinel != id);
        (IFlowERC721V5 erc721Flow, EvaluableV2 memory evaluable) =
            deployFlowERC721({name: name, symbol: symbol, baseURI: baseURI});

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);
        assumeEtchable(alice, address(erc721Flow));

        SignedContextV1[] memory signedContexts = new SignedContextV1[](2);

        signedContexts[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts[1] = vm.signContext(aliceKey, aliceKey, context1);

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(alice, 20 ether, 10 ether, 5, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        erc721Flow.flow(evaluable, new uint256[](0), signedContexts);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts1[1] = vm.signContext(aliceKey, bobKey, context1);

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 1));
        erc721Flow.flow(evaluable, new uint256[](0), signedContexts1);
    }

    /// Should validate a signed context
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721ValidateSignedContexts(
        string memory name,
        string memory symbol,
        string memory baseURI,
        uint256[] memory context0,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 id
    ) public {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);
        vm.assume(sentinel != id);
        (IFlowERC721V5 erc721Flow, EvaluableV2 memory evaluable) =
            deployFlowERC721({name: name, symbol: symbol, baseURI: baseURI});

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;
        address alice = vm.addr(aliceKey);

        assumeEtchable(alice, address(erc721Flow));

        SignedContextV1[] memory signedContext = new SignedContextV1[](1);
        signedContext[0] = vm.signContext(aliceKey, aliceKey, context0);
        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(alice, 20 ether, 10 ether, 5, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        erc721Flow.flow(evaluable, new uint256[](0), signedContext);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContext1 = new SignedContextV1[](1);
        signedContext1[0] = vm.signContext(aliceKey, bobKey, context0);

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 0));
        erc721Flow.flow(evaluable, new uint256[](0), signedContext1);
    }
}
