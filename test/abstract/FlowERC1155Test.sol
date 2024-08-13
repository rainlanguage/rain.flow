// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {IFlowERC1155V5, FlowERC1155ConfigV3} from "src/interface/unstable/IFlowERC1155V5.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE} from "./TestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {FlowERC1155} from "../../src/concrete/erc1155/FlowERC1155.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";

abstract contract FlowERC1155Test is FlowUtilsAbstractTest, InterpreterMockTest {
    CloneFactory internal immutable iCloneErc1155Factory;
    IFlowERC1155V5 internal immutable iFlowErc1155Implementation;

    constructor() {
        vm.pauseGasMetering();
        iCloneErc1155Factory = new CloneFactory();
        iFlowErc1155Implementation = new FlowERC1155();
        vm.resumeGasMetering();
    }

    function deployIFlowERC1155V5(string memory uri)
        internal
        returns (IFlowERC1155V5 flowErc1155, EvaluableV2 memory evaluable)
    {
        expressionDeployerDeployExpression2MockCall(address(0), bytes(hex"0006"));
        // Create the evaluableConfig
        EvaluableConfigV3 memory evaluableConfig =
            EvaluableConfigV3(iDeployer, STUB_EXPRESSION_BYTECODE, new uint256[](0));
        // Create the flowConfig array with one entry
        EvaluableConfigV3[] memory flowConfigArray = new EvaluableConfigV3[](1);
        flowConfigArray[0] = evaluableConfig;
        // Initialize the FlowERC1155ConfigV3 struct
        FlowERC1155ConfigV3 memory flowErc1155Config = FlowERC1155ConfigV3(uri, evaluableConfig, flowConfigArray);
        vm.recordLogs();
        flowErc1155 = IFlowERC1155V5(
            iCloneErc1155Factory.clone(address(iFlowErc1155Implementation), abi.encode(flowErc1155Config))
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory concreteEvent = findEvent(logs, keccak256("FlowInitialized(address,(address,address,address))"));
        (, evaluable) = abi.decode(concreteEvent.data, (address, EvaluableV2));
    }
}
