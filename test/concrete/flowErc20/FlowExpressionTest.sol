// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {
    IFlowV5, FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer
} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {ContextBuilder} from "test/lib/ContextBuilder.sol";
import {FlowERC20Test} from "../../abstract/FlowERC20Test.sol";

contract FlowExpressionTest is FlowERC20Test {
    using SignContextLib for Vm;
    using LibUint256Matrix for uint256[];

    /**
     * @dev Tests that the addresses of expressions emitted in the event
     *      match the addresses provided by the deployer.
     */
    function testFlowERC20ShouldDeployExpression(address[] memory expressions, string memory name, string memory symbol)
        public
    {
        uint256 length = bound(expressions.length, 1, 10);
        assembly ("memory-safe") {
            mstore(expressions, length)
        }

        uint256[][] memory constants = new uint256[][](expressions.length);

        (, EvaluableV2[] memory evaluables) = deployFlowERC20(expressions, constants, name, symbol);

        for (uint256 i = 0; i < evaluables.length; i++) {
            assertEq(evaluables[i].expression, expressions[i]);
        }
    }
}