// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {IFlowV5} from "src/interface/unstable/IFlowV5.sol";
import {Flow} from "src/concrete/basic/Flow.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE} from "./TestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";

abstract contract FlowBasicTest is FlowUtilsAbstractTest, InterpreterMockTest {
    CloneFactory internal immutable iCloneFactory;
    IFlowV5 internal immutable iFlowImplementation;

    constructor() {
        vm.pauseGasMetering();
        iCloneFactory = new CloneFactory();
        iFlowImplementation = new Flow();
        vm.resumeGasMetering();
    }

    function deployFlow() internal returns (IFlowV5 flow, EvaluableV2 memory evaluable) {
            (flow, evaluable) = deployFlow(address(0));
    }


    function deployFlow(address expression) internal returns (IFlowV5 flow, EvaluableV2 memory evaluable) {
        expressionDeployerDeployExpression2MockCall(expression, bytes(hex"0006"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(iDeployer, STUB_EXPRESSION_BYTECODE, new uint256[](0));
        vm.recordLogs();
        flow = IFlowV5(iCloneFactory.clone(address(iFlowImplementation), abi.encode(flowConfig)));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory concreteEvent = findEvent(logs, keccak256("FlowInitialized(address,(address,address,address))"));
        (, evaluable) = abi.decode(concreteEvent.data, (address, EvaluableV2));
    }
}
