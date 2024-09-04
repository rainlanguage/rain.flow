// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";

import {IFlowERC721V5} from "src/interface/unstable/IFlowERC721V5.sol";
import {FlowERC721, FlowERC721ConfigV2} from "src/concrete/erc721/FlowERC721.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE} from "./TestConstants.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";

abstract contract FlowERC721Test is FlowBasicTest {
    using LibUint256Matrix for uint256[];

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
        (flowErc721, evaluable) = deployFlowERC721(address(0), name, symbol, baseURI);
    }

    function deployFlowERC721(address expression, string memory name, string memory symbol, string memory baseURI)
        internal
        returns (IFlowERC721V5, EvaluableV2 memory)
    {
        address[] memory expressions = new address[](1);
        expressions[0] = expression;
        uint256[] memory constants = new uint256[](0);
        (IFlowERC721V5 flowErc721, EvaluableV2[] memory evaluables) =
            deployFlowERC721(expressions, address(1), constants.matrixFrom(), name, symbol, baseURI);
        return (flowErc721, evaluables[0]);
    }

    function deployFlowERC721(
        address[] memory expressions,
        address configExpression,
        uint256[][] memory constants,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) internal returns (IFlowERC721V5 flowErc721, EvaluableV2[] memory evaluables) {
        require(expressions.length == constants.length, "Expressions and constants array lengths must match");

        {
            EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](expressions.length);

            for (uint256 i = 0; i < expressions.length; i++) {
                flowConfig[i] = expressionDeployer(i + 1, expressions[i], constants[i]);
            }

            EvaluableConfigV3 memory evaluableConfig =
                expressionDeployer(configExpression, new uint256[](0), hex"0100026001FF");

            // Initialize the FlowERC721Config struct
            FlowERC721ConfigV2 memory flowErc721Config =
                FlowERC721ConfigV2(name, symbol, baseURI, evaluableConfig, flowConfig);

            vm.recordLogs();
            flowErc721 =
                IFlowERC721V5(iCloneFactory.clone(address(iFlowERC721Implementation), abi.encode(flowErc721Config)));
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
