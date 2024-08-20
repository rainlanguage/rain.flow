// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";

import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {IFlowERC721V5} from "src/interface/unstable/IFlowERC721V5.sol";
import {FlowERC721, FlowERC721ConfigV2} from "src/concrete/erc721/FlowERC721.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE} from "./TestConstants.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";

abstract contract FlowERC721Test is FlowBasicTest {
    CloneFactory internal immutable iCloneErc721Factory;
    IFlowERC721V5 internal immutable iFlowERC721Implementation;
    IExpressionDeployerV3 internal immutable iDeployerForEvalHandleTransfer;

    constructor() {
        vm.pauseGasMetering();
        iCloneErc721Factory = new CloneFactory();
        iFlowERC721Implementation = new FlowERC721();
        iDeployerForEvalHandleTransfer =
            IExpressionDeployerV3(address(uint160(uint256(keccak256("deployer.for.evalhandle.transfer.rain.test")))));
        vm.etch(address(iInterpreter), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    function deployFlowERC721(string memory name, string memory symbol, string memory baseURI)
        internal
        returns (IFlowERC721V5 flowErc721, EvaluableV2 memory evaluable)
    {
        expressionDeployerDeployExpression2MockCall(address(0), bytes(hex"0006"));
        // Create the evaluableConfig
        EvaluableConfigV3 memory evaluableConfig =
            EvaluableConfigV3(iDeployer, STUB_EXPRESSION_BYTECODE, new uint256[](0));
        // Create the flowConfig array with one entry
        EvaluableConfigV3[] memory flowConfigArray = new EvaluableConfigV3[](1);
        flowConfigArray[0] = evaluableConfig;
        // Initialize the FlowERC721Config struct
        FlowERC721ConfigV2 memory flowErc721Config =
            FlowERC721ConfigV2(name, symbol, baseURI, evaluableConfig, flowConfigArray);
        vm.recordLogs();
        flowErc721 =
            IFlowERC721V5(iCloneErc721Factory.clone(address(iFlowERC721Implementation), abi.encode(flowErc721Config)));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory concreteEvent = findEvent(logs, keccak256("FlowInitialized(address,(address,address,address))"));
        (, evaluable) = abi.decode(concreteEvent.data, (address, EvaluableV2));
    }
}
