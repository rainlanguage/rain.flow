// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";

import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {FlowERC20ConfigV2, IFlowERC20V5} from "src/interface/unstable/IFlowERC20V5.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowERC20} from "src/concrete/erc20/FlowERC20.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";

contract FlowErc20ConstructionInitializeTest is InterpreterMockTest, FlowUtilsAbstractTest {
    CloneFactory internal immutable iCloneFactory;
    IFlowERC20V5 internal immutable iFlowERC20Implementation;

    constructor() {
        vm.pauseGasMetering();
        iCloneFactory = new CloneFactory();
        iFlowERC20Implementation = new FlowERC20();
        vm.resumeGasMetering();
    }

    function testFlowConstructionInitialize(address expression, bytes memory bytecode, uint256[] memory constants)
        external
    {
        expressionDeployerDeployExpression2MockCall(expression, bytes(hex"0007"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(iDeployer, bytecode, constants);

        FlowERC20ConfigV2 memory flowERC20ConfigV2 =
            FlowERC20ConfigV2("Flow ERC20", "F20", EvaluableConfigV3(iDeployer, bytecode, constants), flowConfig);

        vm.recordLogs();
        iCloneFactory.clone(address(iFlowERC20Implementation), abi.encode(flowERC20ConfigV2));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature =
            keccak256("Initialize(address,(string,string,(address,bytes,uint256[]),(address,bytes,uint256[])[]))");

        Vm.Log memory concreteEvent = findEvent(logs, eventSignature);
        (address sender, FlowERC20ConfigV2 memory config) = abi.decode(concreteEvent.data, (address, FlowERC20ConfigV2));

        assertEq(sender, address(iCloneFactory), "wrong sender in Initialize event");
        assertEq(keccak256(abi.encode(flowERC20ConfigV2)), keccak256(abi.encode(config)), "wrong compare Structs");
    }
}
