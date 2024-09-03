// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {IFlowV5} from "src/interface/unstable/IFlowV5.sol";
import {Flow} from "src/concrete/basic/Flow.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE, REVERTING_MOCK_BYTECODE} from "./TestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";

abstract contract FlowBasicTest is FlowUtilsAbstractTest, InterpreterMockTest {
    using LibUint256Matrix for uint256[];

    CloneFactory internal immutable iCloneFactory;
    IFlowV5 internal immutable iFlowImplementation;

    address internal immutable iTokenA;
    address internal immutable iTokenB;
    address internal immutable iTokenC;

    constructor() {
        vm.pauseGasMetering();
        iCloneFactory = new CloneFactory();
        iFlowImplementation = new Flow();

        iTokenA = address(uint160(uint256(keccak256("tokenA.test"))));
        vm.etch(address(iTokenA), REVERTING_MOCK_BYTECODE);

        iTokenB = address(uint160(uint256(keccak256("tokenB.test"))));
        vm.etch(address(iTokenB), REVERTING_MOCK_BYTECODE);

        iTokenC = address(uint160(uint256(keccak256("tokenC.test"))));
        vm.etch(address(iTokenC), REVERTING_MOCK_BYTECODE);

        vm.resumeGasMetering();
    }

    function expressionDeployer(address expression, uint256[] memory constants, bytes memory bytecode)
        internal
        returns (EvaluableConfigV3 memory)
    {
        expressionDeployerDeployExpression2MockCall(bytecode, constants, expression, bytes(hex"0006"));
        return EvaluableConfigV3(iDeployer, bytecode, constants);
    }

    function expressionDeployer(uint256 key, address expression, uint256[] memory constants)
        internal
        returns (EvaluableConfigV3 memory)
    {
        return expressionDeployer(expression, constants, abi.encodePacked(vm.addr(key)));
    }

    function deployFlow() internal returns (IFlowV5 flow, EvaluableV2 memory evaluable) {
        (flow, evaluable) = deployFlow(address(0));
    }

    function deployFlow(address expression) internal returns (IFlowV5, EvaluableV2 memory) {
        address[] memory expressions = new address[](1);
        expressions[0] = expression;
        uint256[] memory constants = new uint256[](0);
        (IFlowV5 flow, EvaluableV2[] memory evaluables) = deployFlow(expressions, constants.matrixFrom());
        return (flow, evaluables[0]);
    }

    function deployFlow(address[] memory expressions, uint256[][] memory constants)
        internal
        returns (IFlowV5 flow, EvaluableV2[] memory evaluables)
    {
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

            vm.recordLogs();
            flow = IFlowV5(iCloneFactory.clone(address(iFlowImplementation), abi.encode(flowConfig)));
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

    function assumeEtchable(address account) internal view {
        assumeEtchable(account, address(0));
    }

    function assumeEtchable(address account, address expression) internal view {
        assumeNotPrecompile(account);
        vm.assume(account != address(iDeployer));
        vm.assume(account != address(iInterpreter));
        vm.assume(account != address(iStore));
        vm.assume(account != address(iCloneFactory));
        vm.assume(account != address(iFlowImplementation));
        vm.assume(account != address(this));
        vm.assume(account != address(vm));
        vm.assume(sentinel != uint256(uint160(account)));
        vm.assume(account != address(expression));
        // The console.
        vm.assume(account != address(0x000000000000000000636F6e736F6c652e6c6f67));
    }
}
