// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {FlowERC1155} from "../../../src/concrete/erc1155/FlowERC1155.sol";
import {
    FlowUtilsAbstractTest,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    ERC1155SupplyChange
} from "test/abstract/FlowUtilsAbstractTest.sol";
import {IFlowERC1155V5} from "../../../src/interface/unstable/IFlowERC1155V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowERC1155Test} from "../../abstract/FlowERC1155Test.sol";
import {SignContextAbstractTest} from "../../abstract/SignContextAbstractTest.sol";

contract FlowSignedContextTest is SignContextAbstractTest, FlowUtilsAbstractTest, FlowERC1155Test {
    function testValidateMultipleSignedContexts(string memory uri, uint256[] memory context0, uint256[] memory context1)
        public
    {
        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);
        address alice = vm.addr(1);
        address bob = vm.addr(2);

        SignedContextV1[] memory signedContexts = new SignedContextV1[](2);
        signedContexts[0] = signContext(1, context0);
        signedContexts[1] = signContext(1, context1);

        uint256[] memory stack = generateFlowERC1155Stack(
            new ERC1155Transfer[](0),
            new ERC721Transfer[](0),
            new ERC20Transfer[](0),
            new ERC1155SupplyChange[](0),
            new ERC1155SupplyChange[](0)
        );
        interpreterEval2MockCall(stack, new uint256[](0));
        erc1155Flow.flow(evaluable, new uint256[](0), signedContexts);
    }
}
