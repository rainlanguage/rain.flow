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
    function testValidateMultipleSignedContexts(string memory uri) public {
        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);
    }
}
