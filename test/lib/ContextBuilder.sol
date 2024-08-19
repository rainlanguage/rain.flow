// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibContext} from "rain.interpreter.interface/lib/caller/LibContext.sol";
import {IInterpreterCallerV2} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";

/**
 * @title ContextBuilder
 * @dev Constructs and emits a structured context array for use in interpreter-based smart contracts.
 * Used in testing to generate and verify context data sent to interpreter.
 */
contract ContextBuilder is IInterpreterCallerV2 {
    using LibUint256Matrix for uint256[];

    function buildContext(address caller, uint256[] memory callerContext, SignedContextV1[] memory signedContext)
        public
        returns (uint256[][] memory context)
    {
        context = LibContext.build(callerContext.matrixFrom(), signedContext);
        emit Context(caller, context);
    }
}
