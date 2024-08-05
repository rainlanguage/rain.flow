// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {FlowERC1155} from "../../src/concrete/erc1155/FlowERC1155.sol";
import {IFlowERC1155V5, FlowERC1155ConfigV3, FlowERC1155IOV1} from "../../src/interface/unstable/IFlowERC1155V5.sol";
import {LibFlow} from "../../src/lib/LibFlow.sol";
import {
    EvaluableV2,
    SignedContextV1,
    EvaluableConfigV3
} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {IInterpreterV2} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {InterpreterMockTest} from "../abstract/InterpreterMockTest.sol";
import {FlowERC1155Test} from "../abstract/FlowERC1155Test.sol";

contract FlowSignedContextTest is FlowERC1155Test {
    function testValidateMultipleSignedContexts(string memory uri, bytes memory context0, bytes memory context1)
        public
    {
        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);

        address alice = vm.addr(1);
        address bob = vm.addr(2);

        vm.startPrank(alice);
        bytes32 hash = keccak256(context0);
        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(1, hash);
        address signer = ecrecover(hash, v0, r0, s0);
        // Convert the signature components to uint256[]
        uint256[] memory signatureAlice = new uint256[](3);
        signatureAlice[0] = uint256(r0);
        signatureAlice[1] = uint256(s0);
        signatureAlice[2] = uint256(v0);

        SignedContextV1[] memory signedContexts = new SignedContextV1[](2);
        signedContexts[0] = SignedContextV1(alice, signatureAlice, context0);

        signedContexts[1] = SignedContextV1(alice, signatureAlice, context1);
        erc1155Flow.flow(evaluable, signatureAlice, signedContexts);
    }
}
