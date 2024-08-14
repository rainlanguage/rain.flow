// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {
    FlowUtilsAbstractTest,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    ERC20SupplyChange
} from "test/abstract/FlowUtilsAbstractTest.sol";
import {IFlowERC20V5} from "../../../src/interface/unstable/IFlowERC20V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {InvalidSignature} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {FlowERC20Test} from "../../abstract/FlowERC20Test.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";

contract FlowSignedContextTest is FlowUtilsAbstractTest, FlowERC20Test {
    using SignContextLib for Vm;

    /// Should validate multiple signed contexts
    function testFlowERC20ValidateMultipleSignedContexts(
        string memory name,
        string memory symbol,
        uint256[] memory context0,
        uint256[] memory context1,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob
    ) public {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);
        (IFlowERC20V5 erc20Flow, EvaluableV2 memory evaluable) = deployFlowERC20(name, symbol);

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;

        SignedContextV1[] memory signedContexts = new SignedContextV1[](2);

        signedContexts[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts[1] = vm.signContext(aliceKey, aliceKey, context1);

        uint256[] memory stack = generateFlowERC20Stack(
            new ERC1155Transfer[](0),
            new ERC721Transfer[](0),
            new ERC20Transfer[](0),
            new ERC20SupplyChange[](0),
            new ERC20SupplyChange[](0)
        );
        interpreterEval2MockCall(stack, new uint256[](0));
        erc20Flow.flow(evaluable, new uint256[](0), signedContexts);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts1[1] = vm.signContext(aliceKey, bobKey, context1);

        uint256[] memory stack1 = generateFlowERC20Stack(
            new ERC1155Transfer[](0),
            new ERC721Transfer[](0),
            new ERC20Transfer[](0),
            new ERC20SupplyChange[](0),
            new ERC20SupplyChange[](0)
        );
        interpreterEval2MockCall(stack1, new uint256[](0));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 1));
        erc20Flow.flow(evaluable, new uint256[](0), signedContexts1);
    }
}
