// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowERC721Test} from "../../abstract/FlowERC721Test.sol";

contract FlowTimeTest is FlowERC721Test {
    function testFlowERC721FlowTime(uint256[] memory writeToStore) public {
        absTestFlowTime(writeToStore);
    }
}
