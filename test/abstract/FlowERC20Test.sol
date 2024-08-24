// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {IFlowERC20V5, FlowERC20ConfigV2} from "src/interface/unstable/IFlowERC20V5.sol";
import {FlowERC20} from "src/concrete/erc20/FlowERC20.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE} from "./TestConstants.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";

abstract contract FlowERC20Test is FlowBasicTest {
    using LibUint256Matrix for uint256[];

    CloneFactory internal immutable iCloneErc20Factory;
    IFlowERC20V5 internal immutable iFlowERC20Implementation;

    constructor() {
        vm.pauseGasMetering();
        iCloneErc20Factory = new CloneFactory();
        iFlowERC20Implementation = new FlowERC20();
        vm.resumeGasMetering();
    }

    function deployFlowERC20(string memory name, string memory symbol)
        internal
        returns (IFlowERC20V5 flow, EvaluableV2 memory evaluable)
    {
        (flow, evaluable) = deployFlowERC20(address(0), name, symbol);
    }

    function deployFlowERC20(address expression, string memory name, string memory symbol)
        internal
        returns (IFlowERC20V5, EvaluableV2 memory)
    {
        address[] memory expressions = new address[](1);
        expressions[0] = expression;
        uint256[] memory constants = new uint256[](0);
        (IFlowERC20V5 flow, EvaluableV2[] memory evaluables) =
            deployFlowERC20(expressions, constants.matrixFrom(), name, symbol);
        return (flow, evaluables[0]);
    }

    function deployFlowERC20(
        address[] memory expressions,
        uint256[][] memory constants,
        string memory name,
        string memory symbol
    ) internal returns (IFlowERC20V5 flow, EvaluableV2[] memory evaluables) {
        require(expressions.length == constants.length, "Expressions and constants array lengths must match");

        {
            EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](expressions.length);

            for (uint256 i = 0; i < expressions.length; i++) {
                bytes memory generatedBytecode = abi.encodePacked(vm.addr(i + 1));
                expressionDeployerDeployExpression2MockCall(
                    generatedBytecode, constants[i], expressions[i], bytes(hex"0006")
                );

                flowConfig[i] = EvaluableConfigV3(iDeployer, generatedBytecode, constants[i]);
            }

            // Initialize the FlowERC20Config struct
            FlowERC20ConfigV2 memory flowErc20Config = FlowERC20ConfigV2(name, symbol, flowConfig[0], flowConfig);

            for (uint256 i = 0; i < expressions.length; i++) {
                bytes memory generatedBytecode = abi.encodePacked(vm.addr(i + 1));
                expressionDeployerDeployExpression2MockCall(
                    generatedBytecode, constants[i], expressions[i], bytes(hex"0006")
                );

                flowConfig[i] = EvaluableConfigV3(iDeployer, generatedBytecode, constants[i]);
            }

            vm.recordLogs();
            flow = IFlowERC20V5(iCloneFactory.clone(address(iFlowERC20Implementation), abi.encode(flowErc20Config)));
        }

        {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            logs = findEvents(logs, keccak256("FlowInitialized(address,(address,address,address))"));
            evaluables = new EvaluableV2[](logs.length);
            for (uint256 i = 0; i < logs.length; i++) {
                (, EvaluableV2 memory evaluable) = abi.decode(logs[i].data, (address, EvaluableV2));
                evaluables[i] = evaluable;
            }
        }
    }
}
