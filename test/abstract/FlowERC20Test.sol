// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {IFlowERC20V5, FlowERC20ConfigV2} from "src/interface/unstable/IFlowERC20V5.sol";
import {FlowERC20} from "src/concrete/erc20/FlowERC20.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowTest} from "test/abstract/FlowTest.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";

abstract contract FlowERC20Test is FlowTest {
    using LibUint256Matrix for uint256[];

    function deployFlowImplementation() internal override returns (address flow) {
        flow = address(new FlowERC20());
    }

    function buildConfig(
        string memory name,
        string memory symbol,
        string memory,
        address configExpression,
        EvaluableConfigV3[] memory flowConfig
    ) internal override returns (bytes memory) {
        EvaluableConfigV3 memory evaluableConfig =
            expressionDeployer(configExpression, new uint256[](0), hex"0100026001FF");
        // Initialize the FlowERC20Config struct
        FlowERC20ConfigV2 memory flowErc721Config =
            FlowERC20ConfigV2({name: name, symbol: symbol, evaluableConfig: evaluableConfig, flowConfig: flowConfig});

        return abi.encode(flowErc721Config);
    }

    function deployFlowERC20(string memory name, string memory symbol)
        internal
        returns (IFlowERC20V5 flow, EvaluableV2 memory evaluable)
    {
        (flow, evaluable) = deployFlowERC20(address(uint160(uint256(keccak256("expression")))), name, symbol);
    }

    function deployFlowERC20(address expression, string memory name, string memory symbol)
        internal
        returns (IFlowERC20V5, EvaluableV2 memory)
    {
        address[] memory expressions = new address[](1);
        expressions[0] = expression;
        uint256[] memory constants = new uint256[](0);
        (IFlowERC20V5 flow, EvaluableV2[] memory evaluables) = deployFlowERC20(
            expressions, address(uint160(uint256(keccak256("configExpression")))), constants.matrixFrom(), name, symbol
        );
        return (flow, evaluables[0]);
    }

    function deployFlowERC20(
        address[] memory expressions,
        address configExpression,
        uint256[][] memory constants,
        string memory name,
        string memory symbol
    ) internal returns (IFlowERC20V5, EvaluableV2[] memory) {
        (address flow, EvaluableV2[] memory evaluables) =
            deployFlow(name, symbol, "", expressions, configExpression, constants);
        return (IFlowERC20V5(flow), evaluables);
    }
}
