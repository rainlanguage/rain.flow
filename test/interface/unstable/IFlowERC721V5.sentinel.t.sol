// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test} from "forge-std/Test.sol";

import {IFlowERC721V5, RAIN_FLOW_SENTINEL} from "src/interface/unstable/IFlowERC721V5.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";

contract IFlowERC721V5Test is Test {
    function testSentinelValue() external {
        assertEq(
            0xfea74d0c9bf4a3c28f0dd0674db22a3d7f8bf259c56af19f4ac1e735b156974f, Sentinel.unwrap(RAIN_FLOW_SENTINEL)
        );
    }
}
