// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";

import {FlowERC721ConfigV2} from "src/interface/unstable/IFlowERC721V5.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {FlowERC721Test} from "test/abstract/FlowERC721Test.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";

contract FlowConstructionInitializeTest is FlowERC721Test {
    using LibLogHelper for Vm.Log[];
    using LibUint256Matrix for uint256[];

    function testFlowConstructionInitializeERC721(
        address expression,
        bytes memory bytecode,
        uint256[] memory constants,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) external {
        expressionDeployerDeployExpression2MockCall(expression, bytes(hex"0006"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(iDeployer, bytecode, constants);

        vm.mockCall(
            address(iDeployerForEvalHandleTransfer),
            abi.encodeWithSelector(IExpressionDeployerV3.deployExpression2.selector),
            abi.encode(iInterpreter, iStore, expression, bytes(hex"00000006"))
        );

        FlowERC721ConfigV2 memory flowERC721ConfigV2 = FlowERC721ConfigV2(
            name, symbol, baseURI, EvaluableConfigV3(iDeployerForEvalHandleTransfer, bytecode, constants), flowConfig
        );

        vm.recordLogs();
        iCloneFactory.clone(address(iFlowImplementation), abi.encode(flowERC721ConfigV2));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256(
            "Initialize(address,(string,string,string,(address,bytes,uint256[]),(address,bytes,uint256[])[]))"
        );

        Vm.Log memory concreteEvent = logs.findEvent(eventSignature);
        (address sender, FlowERC721ConfigV2 memory config) =
            abi.decode(concreteEvent.data, (address, FlowERC721ConfigV2));

        assertEq(sender, address(iCloneFactory), "wrong sender in Initialize event");
        assertEq(keccak256(abi.encode(flowERC721ConfigV2)), keccak256(abi.encode(config)), "wrong compare Structs");
    }
}
