// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {IFlowERC20V5} from "src/interface/unstable/IFlowERC20V5.sol";
import {FlowERC20} from "src/concrete/erc20/FlowERC20.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";

contract FlowERC20Test is InterpreterMockTest, FlowUtilsAbstractTest {
    CloneFactory internal immutable iCloneFactory;
    IFlowERC20V5 internal immutable iFlowERC20Implementation;

    constructor() {
        vm.pauseGasMetering();
        iCloneFactory = new CloneFactory();
        iFlowERC20Implementation = new FlowERC20();
        vm.resumeGasMetering();
    }
}
