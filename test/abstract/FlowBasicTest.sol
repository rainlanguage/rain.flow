// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {FlowTest} from "test/abstract/FlowTest.sol";
import {Flow} from "src/concrete/basic/Flow.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {IFlowV5, FlowTransferV1} from "src/interface/unstable/IFlowV5.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

abstract contract FlowBasicTest is FlowTest {
    using LibUint256Matrix for uint256[];
    using LibStackGeneration for uint256;

    function buildConfig(string memory, string memory, string memory, address, EvaluableConfigV3[] memory flowConfig)
        internal
        pure
        override
        returns (bytes memory)
    {
        return abi.encode(flowConfig);
    }

    function deployFlowImplementation() internal override returns (address) {
        return address(new Flow());
    }

    function deployFlow() internal returns (IFlowV5, EvaluableV2 memory) {
        address[] memory expressions = new address[](1);
        expressions[0] = address(uint160(uint256(keccak256("expression"))));
        (IFlowV5 flow, EvaluableV2[] memory evaluables) =
            deployFlow({expressions: expressions, constants: new uint256[](0).matrixFrom()});
        return (flow, evaluables[0]);
    }

    function deployFlow(address[] memory expressions, uint256[][] memory constants)
        internal
        returns (IFlowV5, EvaluableV2[] memory)
    {
        (address flow, EvaluableV2[] memory evaluables) = deployFlow({
            name: "",
            symbol: "",
            baseURI: "",
            expressions: expressions,
            configExpression: address(uint160(uint256(keccak256("configExpression")))),
            constants: constants
        });
        return (IFlowV5(flow), evaluables);
    }

    function mintAndBurnFlowStack(address, uint256, uint256, uint256, FlowTransferV1 memory transfer)
        internal
        view
        override
        returns (uint256[] memory stack, bytes32 transferHash)
    {
        transferHash = keccak256(abi.encode(transfer));
        stack = sentinel.generateFlowStack(transfer);
    }
}
