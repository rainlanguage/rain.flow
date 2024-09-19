// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {FlowTest} from "test/abstract/FlowTest.sol";
import {Flow} from "src/concrete/basic/Flow.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";

abstract contract FlowBasicTest is FlowTest {
    function buildConfig(address, EvaluableConfigV3[] memory flowConfig)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encode(flowConfig);
    }

    function deployFlowImplementation() internal override returns (address flow) {
        flow = address(new Flow());
    }
}
