// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {IFlowV5} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE, REVERTING_MOCK_BYTECODE} from "./TestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

abstract contract FlowTest is FlowUtilsAbstractTest, InterpreterMockTest {
    using LibUint256Matrix for uint256[];
    using LibLogHelper for Vm.Log[];
    using LibStackGeneration for uint256;
    using Address for address;

    CloneFactory internal immutable iCloneFactory;

    constructor() {
        vm.pauseGasMetering();
        iCloneFactory = new CloneFactory();
        vm.resumeGasMetering();
    }

    function buildConfig(address, EvaluableConfigV3[] memory flowConfig) internal virtual returns (bytes memory);

    function deployFlowImplementation() internal virtual returns (address flow);

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

    function deployFlow(address[] memory expressions, address configExpression, uint256[][] memory constants)
        internal
        returns (address flow, EvaluableV2[] memory evaluables)
    {
        require(expressions.length == constants.length, "Expressions and constants array lengths must match");

        {
            EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](expressions.length);

            for (uint256 i = 0; i < expressions.length; i++) {
                flowConfig[i] = expressionDeployer(i + 1, expressions[i], constants[i]);
            }

            vm.recordLogs();
            flow = iCloneFactory.clone(deployFlowImplementation(), buildConfig(configExpression, flowConfig));
        }

        {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            logs = logs.findEvents(keccak256("FlowInitialized(address,(address,address,address))"));
            evaluables = new EvaluableV2[](logs.length);
            for (uint256 i = 0; i < logs.length; i++) {
                (, EvaluableV2 memory evaluable) = abi.decode(logs[i].data, (address, EvaluableV2));
                evaluables[i] = evaluable;
            }
        }
    }

    function deployFlow() internal returns (address, EvaluableV2 memory) {
        address[] memory expressions = new address[](1);
        expressions[0] = address(uint160(uint256(keccak256("expression"))));
        (address flow, EvaluableV2[] memory evaluables) =
            deployFlow({expressions: expressions, constants: new uint256[](0).matrixFrom()});
        return (flow, evaluables[0]);
    }

    function deployFlow(address[] memory expressions, uint256[][] memory constants)
        internal
        returns (address flow, EvaluableV2[] memory evaluables)
    {
        (flow, evaluables) = deployFlow({
            expressions: expressions,
            configExpression: address(uint160(uint256(keccak256("configExpression")))),
            constants: constants
        });
        return (flow, evaluables);
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
        vm.assume(account != address(this));
        vm.assume(account != address(vm));
        vm.assume(sentinel != uint256(uint160(account)));
        vm.assume(account != address(expression));
        vm.assume(!account.isContract());
        // The console.
        vm.assume(account != address(0x000000000000000000636F6e736F6c652e6c6f67));
    }
}
