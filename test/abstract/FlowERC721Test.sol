// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {IFlowERC721V5} from "src/interface/unstable/IFlowERC721V5.sol";
import {FlowERC721, FlowERC721ConfigV2} from "src/concrete/erc721/FlowERC721.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";

abstract contract FlowERC721Test is FlowBasicTest {
    using LibUint256Matrix for uint256[];

    IExpressionDeployerV3 internal immutable iDeployerForEvalHandleTransfer;

    constructor() {
        vm.pauseGasMetering();
        iFlowImplementation = address(new FlowERC721());
        iDeployerForEvalHandleTransfer =
            IExpressionDeployerV3(address(uint160(uint256(keccak256("deployer.for.evalhandle.transfer.rain.test")))));
        vm.etch(address(iInterpreter), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    function deployFlowERC721(string memory name, string memory symbol, string memory baseURI)
        internal
        returns (IFlowERC721V5 flowErc721, EvaluableV2 memory evaluable)
    {
        (flowErc721, evaluable) =
            deployFlowERC721(address(uint160(uint256(keccak256("expression")))), name, symbol, baseURI);
    }

    function deployFlowERC721(address expression, string memory name, string memory symbol, string memory baseURI)
        internal
        returns (IFlowERC721V5, EvaluableV2 memory)
    {
        address[] memory expressions = new address[](1);
        expressions[0] = expression;
        uint256[] memory constants = new uint256[](0);
        (IFlowERC721V5 flowErc721, EvaluableV2[] memory evaluables) = deployFlowERC721(
            expressions,
            address(uint160(uint256(keccak256("configExpression")))),
            constants.matrixFrom(),
            name,
            symbol,
            baseURI
        );
        return (flowErc721, evaluables[0]);
    }

    function deployFlowERC721(
        address[] memory expressions,
        address configExpression,
        uint256[][] memory constants,
        string memory,
        string memory,
        string memory
    ) internal returns (IFlowERC721V5, EvaluableV2[] memory) {
        (address flow, EvaluableV2[] memory evaluables) = deployFlow(expressions, configExpression, constants);
        return (IFlowERC721V5(flow), evaluables);
    }

    function buildConfig(address configExpression, EvaluableConfigV3[] memory flowConfig)
        internal
        override
        returns (bytes memory)
    {
        EvaluableConfigV3 memory evaluableConfig =
            expressionDeployer(configExpression, new uint256[](0), hex"0100026001FF");
        // Initialize the FlowERC721Config struct
        FlowERC721ConfigV2 memory flowErc721Config = FlowERC721ConfigV2({
            name: "FlowERC721",
            symbol: "F721",
            baseURI: "https://www.rainprotocol.xyz/nft/",
            evaluableConfig: evaluableConfig,
            flowConfig: flowConfig
        });

        return abi.encode(flowErc721Config);
    }
}
