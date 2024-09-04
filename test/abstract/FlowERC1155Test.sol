// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {IFlowERC1155V5, FlowERC1155ConfigV3} from "src/interface/unstable/IFlowERC1155V5.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {FlowERC1155} from "../../src/concrete/erc1155/FlowERC1155.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";

abstract contract FlowERC1155Test is FlowBasicTest {
    using LibUint256Matrix for uint256[];

    CloneFactory internal immutable iCloneErc1155Factory;
    IFlowERC1155V5 internal immutable iFlowErc1155Implementation;

    constructor() {
        vm.pauseGasMetering();
        iCloneErc1155Factory = new CloneFactory();
        iFlowErc1155Implementation = new FlowERC1155();
        vm.resumeGasMetering();
    }

    function deployIFlowERC1155V5(string memory uri)
        internal
        returns (IFlowERC1155V5 flowErc1155, EvaluableV2 memory evaluable)
    {
        (flowErc1155, evaluable) = deployIFlowERC1155V5(address(0), uri);
    }

    function deployIFlowERC1155V5(address expression, string memory uri)
        internal
        returns (IFlowERC1155V5, EvaluableV2 memory)
    {
        address[] memory expressions = new address[](1);
        expressions[0] = expression;
        uint256[] memory constants = new uint256[](0);
        (IFlowERC1155V5 flowErc1155, EvaluableV2[] memory evaluables) =
            deployIFlowERC1155V5(expressions, address(1), constants.matrixFrom(), uri);
        return (flowErc1155, evaluables[0]);
    }

    function deployIFlowERC1155V5(
        address[] memory expressions,
        address configExpression,
        uint256[][] memory constants,
        string memory uri
    ) internal returns (IFlowERC1155V5 flowErc1155, EvaluableV2[] memory evaluables) {
        require(expressions.length == constants.length, "Expressions and constants array lengths must match");

        {
            EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](expressions.length);

            for (uint256 i = 0; i < expressions.length; i++) {
                flowConfig[i] = expressionDeployer(i + 1, expressions[i], constants[i]);
            }

            EvaluableConfigV3 memory evaluableConfig =
                expressionDeployer(configExpression, new uint256[](0), hex"0100026001FF");

            // Initialize the FlowERC1155Config struct
            FlowERC1155ConfigV3 memory flowErc1155Config = FlowERC1155ConfigV3(uri, evaluableConfig, flowConfig);

            vm.recordLogs();
            flowErc1155 =
                IFlowERC1155V5(iCloneFactory.clone(address(iFlowErc1155Implementation), abi.encode(flowErc1155Config)));
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
