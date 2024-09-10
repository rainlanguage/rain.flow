// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowERC20Test} from "../../abstract/FlowERC20Test.sol";

contract FlowTimeTest is FlowERC20Test {
    function testFlowERC20FlowTime(uint256[] memory writeToStore) public {
        absTestFlowTime(writeToStore);
    }
}
