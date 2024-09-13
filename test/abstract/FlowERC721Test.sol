// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {IFlowERC721V5, ERC721SupplyChange, FlowERC721IOV1} from "src/interface/unstable/IFlowERC721V5.sol";
import {FlowTransferV1} from "src/interface/unstable/IFlowV5.sol";
import {FlowERC721, FlowERC721ConfigV2} from "src/concrete/erc721/FlowERC721.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";
import {AbstractFlowTest} from "test/abstract/flow/AbstractFlowTest.sol";
import {AbstractPreviewTest} from "test/abstract/flow/AbstractPreviewTest.sol";

abstract contract FlowERC721Test is FlowBasicTest, AbstractFlowTest, AbstractPreviewTest {
    using LibUint256Matrix for uint256[];
    using LibStackGeneration for uint256;

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
        string memory, /*name*/
        string memory, /*symbol*/
        string memory /*baseURI*/
    ) internal returns (IFlowERC721V5, EvaluableV2[] memory) {
        (address flow, EvaluableV2[] memory evaluables) = deployFlow(expressions, configExpression, constants);
        return (IFlowERC721V5(flow), evaluables);
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

    function abstractStackToFlowCall(address flowAddress, uint256[] memory stack)
        internal
        pure
        override
        returns (bytes32 stackToFlowTransfersHash)
    {
        stackToFlowTransfersHash = keccak256(abi.encode(IFlowERC721V5(flowAddress).stackToFlow(stack)));
    }

    function mintAndBurnFlowStack(
        address account,
        uint256, /*mint*/
        uint256, /*burn*/
        uint256 id,
        FlowTransferV1 memory transfer
    ) internal view override returns (uint256[] memory stack, bytes32 transferHash) {
        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](1);
        mints[0] = ERC721SupplyChange({account: account, id: id});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: account, id: id});

        FlowERC721IOV1 memory flowERC721 = FlowERC721IOV1(mints, burns, transfer);

        transferHash = keccak256(abi.encode(flowERC721));

        stack = sentinel.generateFlowStack(flowERC721);
    }
}
