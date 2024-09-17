// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";

import {FlowERC1155ConfigV3} from "src/interface/unstable/IFlowERC1155V5.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {FlowERC1155Test} from "test/abstract/FlowERC1155Test.sol";

contract FlowConstructionInitializeTest is FlowERC1155Test {
    function testFlowConstructionInitializeERC1155(
        address expression,
        bytes memory bytecode,
        uint256[] memory constants,
        string memory uri
    ) external {
        expressionDeployerDeployExpression2MockCall(expression, bytes(hex"0007"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(iDeployer, bytecode, constants);

        FlowERC1155ConfigV3 memory flowERC1155ConfigV3 =
            FlowERC1155ConfigV3(uri, EvaluableConfigV3(iDeployer, bytecode, constants), flowConfig);

        vm.recordLogs();
        iCloneErc1155Factory.clone(address(iFlowErc1155Implementation), abi.encode(flowERC1155ConfigV3));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature =
            keccak256("Initialize(address,(string,(address,bytes,uint256[]),(address,bytes,uint256[])[]))");

        Vm.Log memory concreteEvent = findEvent(logs, eventSignature);
        (address sender, FlowERC1155ConfigV3 memory config) =
            abi.decode(concreteEvent.data, (address, FlowERC1155ConfigV3));

        assertEq(sender, address(iCloneErc1155Factory), "wrong sender in Initialize event");
        assertEq(keccak256(abi.encode(flowERC1155ConfigV3)), keccak256(abi.encode(config)), "wrong compare Structs");
    }
}
