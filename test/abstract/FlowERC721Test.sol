// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";

import {IFlowERC721V5, ERC721SupplyChange, FlowERC721IOV1} from "src/interface/unstable/IFlowERC721V5.sol";
import {FlowERC721, FlowERC721ConfigV2} from "src/concrete/erc721/FlowERC721.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE} from "./TestConstants.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {LibLogHelper} from "test/lib/LibLogHelper.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {AbstractFlowTimeTest} from "test/abstract/flow/AbstractFlowTimeTest.sol";
import {AbstractFlowSignedContextTest} from "test/abstract/flow/AbstractFlowSignedContextTest.sol";

abstract contract FlowERC721Test is FlowBasicTest, AbstractFlowTimeTest, AbstractFlowSignedContextTest {
    using LibUint256Matrix for uint256[];
    using LibStackGeneration for uint256;
    using LibLogHelper for Vm.Log[];

    IExpressionDeployerV3 internal immutable iDeployerForEvalHandleTransfer;

    constructor() {
        vm.pauseGasMetering();
        iFlowImplementation = address(new FlowERC721());
        iDeployerForEvalHandleTransfer =
            IExpressionDeployerV3(address(uint160(uint256(keccak256("deployer.for.evalhandle.transfer.rain.test")))));
        vm.resumeGasMetering();
    }

    function buldConfig(address configExpression, EvaluableConfigV3[] memory flowConfig)
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

    function abstractFlowCall(
        address flowAddress,
        EvaluableV2 memory evaluable,
        uint256[] memory callerContext,
        SignedContextV1[] memory signedContexts
    ) internal override {
        IFlowERC721V5(flowAddress).flow(evaluable, callerContext, signedContexts);
    }

    function emptyFlowStack() internal view override returns (uint256[] memory stack, bytes32 transferHash) {
        FlowERC721IOV1 memory flowERC721 =
            FlowERC721IOV1(new ERC721SupplyChange[](0), new ERC721SupplyChange[](0), transferEmpty());

        transferHash = keccak256(abi.encode(flowERC721));

        stack = sentinel.generateFlowStack(flowERC721);
    }
}
