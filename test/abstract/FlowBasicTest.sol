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
import {LibLogHelper} from "test/lib/LibLogHelper.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

abstract contract FlowBasicTest is FlowUtilsAbstractTest, InterpreterMockTest {
    using LibUint256Matrix for uint256[];
    using LibLogHelper for Vm.Log[];
    using LibStackGeneration for uint256;
    using Address for address;

    CloneFactory internal immutable iCloneFactory;
    address internal iFlowImplementation;

    constructor() {
        vm.pauseGasMetering();
        iCloneFactory = new CloneFactory();
        iFlowImplementation = address(new Flow());
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

    function buldConfig(address, /*configExpression*/ EvaluableConfigV3[] memory flowConfig)
        internal
        virtual
        returns (bytes memory)
    {
        return abi.encode(flowConfig);
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
            flow = iCloneFactory.clone(iFlowImplementation, buldConfig(configExpression, flowConfig));
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

    function deployFlowWithConfig() internal returns (address, EvaluableV2 memory) {
        address[] memory expressions = new address[](1);
        expressions[0] = address(uint160(uint256(keccak256("expression"))));
        (address flow, EvaluableV2[] memory evaluables) =
            deployFlow({expressions: expressions, constants: new uint256[][](1)});
        return (flow, evaluables[0]);
    }

    // A temporary solution.
    function deployFlow() internal returns (IFlowV5, EvaluableV2 memory) {
        (address flowAddress, EvaluableV2 memory evaluable) = deployFlowWithConfig();
        return (IFlowV5(flowAddress), evaluable);
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
        vm.assume(account != address(iFlowImplementation));
        vm.assume(account != address(this));
        vm.assume(account != address(vm));
        vm.assume(sentinel != uint256(uint160(account)));
        vm.assume(account != address(expression));
        vm.assume(!account.isContract());
        // The console.
        vm.assume(account != address(0x000000000000000000636F6e736F6c652e6c6f67));
    }
}
