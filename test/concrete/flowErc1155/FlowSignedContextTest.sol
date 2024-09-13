// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {FlowERC1155} from "../../../src/concrete/erc1155/FlowERC1155.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {
    IFlowERC1155V5, ERC1155SupplyChange, FlowERC1155IOV1
} from "../../../src/interface/unstable/IFlowERC1155V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {InvalidSignature} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {FlowERC1155Test} from "../../abstract/FlowERC1155Test.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";

contract FlowSignedContextTest is FlowUtilsAbstractTest, FlowERC1155Test {
    using SignContextLib for Vm;

    /// Should validate multiple signed contexts
    function testValidateMultipleSignedContexts(
        string memory uri,
        uint256 id,
        uint256 amount,
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
        {
            address alice = vm.addr(aliceKey);
            signedContexts[0] = vm.signContext(aliceKey, aliceKey, context0);
            signedContexts[1] = vm.signContext(aliceKey, aliceKey, context1);

            ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](1);
            mints[0] = ERC1155SupplyChange({account: alice, id: id, amount: amount});

            ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
            burns[0] = ERC1155SupplyChange({account: alice, id: id, amount: amount});

            uint256[] memory stack = generateFlowStack(
                FlowERC1155IOV1(
                    mints,
                    burns,
                    FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }
        erc1155Flow.flow(evaluable, new uint256[](0), signedContexts);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContexts1 = new SignedContextV1[](2);
        signedContexts1[0] = vm.signContext(aliceKey, aliceKey, context0);
        signedContexts1[1] = vm.signContext(aliceKey, bobKey, context1);

        uint256[] memory stack1 = generateFlowStack(
            FlowERC1155IOV1(
                new ERC1155SupplyChange[](0),
                new ERC1155SupplyChange[](0),
                FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
            )
        );
        interpreterEval2MockCall(stack1, new uint256[](0));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 1));
        erc1155Flow.flow(evaluable, new uint256[](0), signedContexts1);
    }

    /// Should validate a signed context
    function testValidateSignedContexts(
        string memory uri,
        uint256[] memory context0,
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 id,
        uint256 amount
    ) public {
        vm.assume(fuzzedKeyBob != fuzzedKeyAlice);
        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);

        // Ensure the fuzzed key is within the valid range for secp256k1
        uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
        uint256 bobKey = (fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1;

        SignedContextV1[] memory signedContext = new SignedContextV1[](1);
        signedContext[0] = vm.signContext(aliceKey, aliceKey, context0);
        {
            address alice = vm.addr(aliceKey);
            ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](1);
            mints[0] = ERC1155SupplyChange({account: alice, id: id, amount: amount});

            ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
            burns[0] = ERC1155SupplyChange({account: alice, id: id, amount: amount});

            uint256[] memory stack = generateFlowStack(
                FlowERC1155IOV1(
                    mints,
                    burns,
                    FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        erc1155Flow.flow(evaluable, new uint256[](0), signedContext);

        // With bad signature in second signed context
        SignedContextV1[] memory signedContext1 = new SignedContextV1[](1);
        signedContext1[0] = vm.signContext(aliceKey, bobKey, context0);

        uint256[] memory stack1 = generateFlowStack(
            FlowERC1155IOV1(
                new ERC1155SupplyChange[](0),
                new ERC1155SupplyChange[](0),
                FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
            )
        );
        interpreterEval2MockCall(stack1, new uint256[](0));

        vm.expectRevert(abi.encodeWithSelector(InvalidSignature.selector, 0));
        erc1155Flow.flow(evaluable, new uint256[](0), signedContext1);
    }
}
