// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {AbstractFlowTimeTest} from "test/abstract/flow/AbstractFlowTimeTest.sol";

contract FlowTimeTest is AbstractFlowTimeTest {
    function testFlowBasicFlowTime(uint256[] memory writeToStore) public {
        absTestFlowTime(writeToStore);
    }
}
