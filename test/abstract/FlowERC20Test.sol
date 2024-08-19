// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {IFlowERC20V5, FlowERC20ConfigV2} from "src/interface/unstable/IFlowERC20V5.sol";
import {FlowERC20} from "src/concrete/erc20/FlowERC20.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE} from "./TestConstants.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";

contract FlowERC20Test is FlowUtilsAbstractTest, InterpreterMockTest {
    CloneFactory internal immutable iCloneErc20Factory;
    IFlowERC20V5 internal immutable iFlowERC20Implementation;
    address internal immutable iTokenA;
    address internal immutable iTokenB;

    constructor() {
        vm.pauseGasMetering();
        iCloneErc20Factory = new CloneFactory();
        iFlowERC20Implementation = new FlowERC20();
        iTokenA = address(uint160(uint256(keccak256("tokenA.test"))));
        vm.etch(address(iTokenA), REVERTING_MOCK_BYTECODE);

        iTokenB = address(uint160(uint256(keccak256("tokenB.test"))));
        vm.etch(address(iTokenB), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    function deployFlowERC20(string memory name, string memory symbol)
        internal
        returns (IFlowERC20V5 flowErc20, EvaluableV2 memory evaluable)
    {
        expressionDeployerDeployExpression2MockCall(address(0), bytes(hex"0006"));
        // Create the evaluableConfig
        EvaluableConfigV3 memory evaluableConfig =
            EvaluableConfigV3(iDeployer, STUB_EXPRESSION_BYTECODE, new uint256[](0));
        // Create the flowConfig array with one entry
        EvaluableConfigV3[] memory flowConfigArray = new EvaluableConfigV3[](1);
        flowConfigArray[0] = evaluableConfig;
        // Initialize the FlowERC20Config struct
        FlowERC20ConfigV2 memory flowErc20Config = FlowERC20ConfigV2(name, symbol, evaluableConfig, flowConfigArray);
        vm.recordLogs();
        flowErc20 =
            IFlowERC20V5(iCloneErc20Factory.clone(address(iFlowERC20Implementation), abi.encode(flowErc20Config)));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory concreteEvent = findEvent(logs, keccak256("FlowInitialized(address,(address,address,address))"));
        (, evaluable) = abi.decode(concreteEvent.data, (address, EvaluableV2));
    }
}
