// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {FlowERC20ConfigV2} from "src/interface/unstable/IFlowERC20V5.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowERC20Test} from "test/abstract/FlowERC20Test.sol";

contract FlowConstructionInitializeTest is FlowERC20Test {
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
