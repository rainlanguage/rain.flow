// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {
    IFlowERC20V5, FlowERC20ConfigV2, ERC20SupplyChange, FlowERC20IOV1
} from "src/interface/unstable/IFlowERC20V5.sol";
import {FlowTransferV1} from "src/interface/unstable/IFlowV5.sol";
import {FlowERC20} from "src/concrete/erc20/FlowERC20.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";

import {AbstractFlowTest} from "test/abstract/flow/AbstractFlowTest.sol";
import {AbstractPreviewTest} from "test/abstract/flow/AbstractPreviewTest.sol";

abstract contract FlowERC20Test is FlowBasicTest, AbstractFlowTest, AbstractPreviewTest {
    using LibUint256Matrix for uint256[];
    using LibStackGeneration for uint256;

    constructor() {
        vm.pauseGasMetering();
        iFlowImplementation = address(new FlowERC20());
        vm.resumeGasMetering();
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
        string memory, /*name*/
        string memory /*symbol*/
    ) internal returns (IFlowERC20V5, EvaluableV2[] memory) {
        (address flow, EvaluableV2[] memory evaluables) = deployFlow(expressions, configExpression, constants);
        return (IFlowERC20V5(flow), evaluables);
    }

    function buldConfig(address configExpression, EvaluableConfigV3[] memory flowConfig)
        internal
        override
        returns (bytes memory)
    {
        EvaluableConfigV3 memory evaluableConfig =
            expressionDeployer(configExpression, new uint256[](0), hex"0100026001FF");
        // Initialize the FlowERC20Config struct
        FlowERC20ConfigV2 memory flowErc721Config = FlowERC20ConfigV2({
            name: "FlowERC20",
            symbol: "F20",
            evaluableConfig: evaluableConfig,
            flowConfig: flowConfig
        });

        return abi.encode(flowErc721Config);
    }

    function mintAndBurnFlowStack(
        address account,
        uint256 mint,
        uint256 burn,
        uint256, /*id*/
        FlowTransferV1 memory transfer
    ) internal view override returns (uint256[] memory stack, bytes32 transferHash) {
        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: account, amount: mint});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: account, amount: burn});

        FlowERC20IOV1 memory flowERC20IO = FlowERC20IOV1(mints, burns, transfer);

        transferHash = keccak256(abi.encode(flowERC20IO));

        stack = sentinel.generateFlowStack(flowERC20IO);
    }

    function abstractFlowCall(
        address flowAddress,
        EvaluableV2 memory evaluable,
        uint256[] memory callerContext,
        SignedContextV1[] memory signedContexts
    ) internal override {
        IFlowERC20V5(flowAddress).flow(evaluable, callerContext, signedContexts);
    }

    function abstractStackToFlowCall(address flowAddress, uint256[] memory stack)
        internal
        pure
        override
        returns (bytes32 stackToFlowTransfersHash)
    {
        stackToFlowTransfersHash = keccak256(abi.encode(IFlowERC20V5(flowAddress).stackToFlow(stack)));
    }
}
