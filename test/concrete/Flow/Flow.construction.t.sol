// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Test, Vm, console2} from "forge-std/Test.sol";

import {FlowMockRealTest} from "test/util/abstract/FlowMockRealTest.sol";
import {IFlowV5} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {STUB_EXPRESSION_BYTECODE} from "test/util/lib/LibTestConstants.sol";
import {Flow} from "src/concrete/basic/Flow.sol";

contract FlowConstructionTest is FlowMockRealTest {
    IFlowV5 internal flowImplementation;

    function testInitializeOnTheGoodPath() external {
        vm.mockCall(
            address(iDeployer),
            abi.encodeWithSelector(IExpressionDeployerV3.deployExpression2.selector),
            abi.encode(iInterpreter, iStore, address(0), hex"0007") // 1 in, 1 out
        );

        bytes memory bytecode = STUB_EXPRESSION_BYTECODE;
        uint256[] memory constants = new uint256[](1);
        constants[0] = 2;

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(iDeployer, bytecode, constants);

        flowImplementation = new Flow();

        vm.recordLogs();
        iCloneableFactoryV2.clone(address(flowImplementation), abi.encode(flowConfig));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("Initialize(address,(address,bytes,uint256[])[])");

        Vm.Log memory concreteEvent = findEvent(logs, eventSignature);
        (address sender, EvaluableConfigV3[] memory config) =
            abi.decode(concreteEvent.data, (address, EvaluableConfigV3[]));

        assertEq(sender, address(iCloneableFactoryV2), "wrong sender in Initialize event");
        assertEq(keccak256(abi.encode(flowConfig)), keccak256(abi.encode(config)), "wrong sender in Initialize event");
    }
}
