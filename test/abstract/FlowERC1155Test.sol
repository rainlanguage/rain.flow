// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {
    IFlowERC1155V5,
    FlowERC1155ConfigV3,
    ERC1155SupplyChange,
    FlowERC1155IOV1
} from "src/interface/unstable/IFlowERC1155V5.sol";
import {FlowTransferV1} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {FlowERC1155} from "../../src/concrete/erc1155/FlowERC1155.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {FlowTest} from "test/abstract/FlowTest.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

abstract contract FlowERC1155Test is FlowTest {
    using LibUint256Matrix for uint256[];
    using LibStackGeneration for uint256;

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
        string memory baseURI
    ) internal returns (IFlowERC1155V5, EvaluableV2[] memory) {
        (address flow, EvaluableV2[] memory evaluables) =
            deployFlow("", "", baseURI, expressions, configExpression, constants);
        return (IFlowERC1155V5(flow), evaluables);
    }

    function deployFlowImplementation() internal override returns (address flow) {
        flow = address(new FlowERC1155());
    }

    function buildConfig(
        string memory,
        string memory,
        string memory baseURI,
        address configExpression,
        EvaluableConfigV3[] memory flowConfig
    ) internal override returns (bytes memory) {
        EvaluableConfigV3 memory evaluableConfig =
            expressionDeployer(configExpression, new uint256[](0), hex"0100026001FF");
        FlowERC1155ConfigV3 memory flowErc1155Config = FlowERC1155ConfigV3(baseURI, evaluableConfig, flowConfig);
        return abi.encode(flowErc1155Config);
    }

    function mintAndBurnFlowStack(
        address account,
        uint256 mint,
        uint256 burn,
        uint256 id,
        FlowTransferV1 memory transfer
    ) internal view override returns (uint256[] memory stack, bytes32 transferHash) {
        ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](1);
        mints[0] = ERC1155SupplyChange({account: account, id: id, amount: mint});

        ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
        burns[0] = ERC1155SupplyChange({account: account, id: id, amount: burn});

        FlowERC1155IOV1 memory flowERC1155 = FlowERC1155IOV1(mints, burns, transfer);

        transferHash = keccak256(abi.encode(flowERC1155));

        stack = sentinel.generateFlowStack(flowERC1155);
    }
}
