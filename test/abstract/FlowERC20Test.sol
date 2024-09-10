// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {
    IFlowERC20V5, FlowERC20ConfigV2, FlowERC20IOV1, ERC20SupplyChange
} from "src/interface/unstable/IFlowERC20V5.sol";
import {FlowTransferV1} from "src/interface/unstable/IFlowV5.sol";
import {FlowERC20} from "src/concrete/erc20/FlowERC20.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE} from "./TestConstants.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {AbstractFlowTimeTest} from "test/abstract/flow/AbstractFlowTimeTest.sol";
import {AbstractFlowSignedContextTest} from "test/abstract/flow/AbstractFlowSignedContextTest.sol";

abstract contract FlowERC20Test is FlowBasicTest, AbstractFlowTimeTest, AbstractFlowSignedContextTest {
    using LibUint256Matrix for uint256[];
    using LibLogHelper for Vm.Log[];
    using LibStackGeneration for uint256;

    CloneFactory internal immutable iCloneErc20Factory;

    constructor() {
        vm.pauseGasMetering();
        iFlowImplementation = address(new FlowERC20());
        iCloneErc20Factory = new CloneFactory();
        vm.resumeGasMetering();
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
        returns (bytes32 stackToFlowTransfersHash)
    {
        stackToFlowTransfersHash = keccak256(abi.encode(IFlowERC20V5(flowAddress).stackToFlow(stack)));
    }

    function emptyFlowStack() internal view override returns (uint256[] memory stack, bytes32 transferHash) {
        (stack, transferHash) = emptyFlowStack(transferEmpty());
    }

    function emptyFlowStack(FlowTransferV1 memory transfer)
        internal
        view
        override
        returns (uint256[] memory stack, bytes32 transferHash)
    {
        FlowERC20IOV1 memory flowERC20IO =
            FlowERC20IOV1(new ERC20SupplyChange[](0), new ERC20SupplyChange[](0), transfer);

        transferHash = keccak256(abi.encode(flowERC20IO));

        stack = sentinel.generateFlowStack(flowERC20IO);
    }

    function mintFlowStack(address account, uint256 amount, FlowTransferV1 memory transfer)
        internal
        view
        override
        returns (uint256[] memory stack, bytes32 transferHash)
    {
        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: account, amount: amount});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: account, amount: 0 ether});

        FlowERC20IOV1 memory flowERC20IO = FlowERC20IOV1(mints, burns, transfer);

        transferHash = keccak256(abi.encode(flowERC20IO));
        stack = sentinel.generateFlowStack(flowERC20IO);
    }

    function mintAndBurnFlowStack(address account, uint256 mint, uint256 burn, FlowTransferV1 memory transfer)
        internal
        view
        override
        returns (uint256[] memory stack, bytes32 transferHash)
    {
        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: account, amount: mint});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: account, amount: burn});

        FlowERC20IOV1 memory flowERC20IO = FlowERC20IOV1(mints, burns, transfer);

        transferHash = keccak256(abi.encode(flowERC20IO));

        stack = sentinel.generateFlowStack(flowERC20IO);
    }
}
