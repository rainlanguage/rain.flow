// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";
import {
    FlowUtilsAbstractTest,
    ERC1155Transfer,
    ERC721Transfer,
    ERC20Transfer
} from "test/abstract/FlowUtilsAbstractTest.sol";
import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {IFlowV5} from "src/interface/unstable/IFlowV5.sol";
import {Flow} from "src/concrete/basic/Flow.sol";
import {EvaluableConfigV3, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {STUB_EXPRESSION_BYTECODE} from "./TestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";

abstract contract FlowBaseTest is FlowUtilsAbstractTest, InterpreterMockTest {
    CloneFactory internal immutable _iCloneFactory;
    IFlowV5 internal immutable _flowImplementation;

    constructor() {
        vm.pauseGasMetering();
        _iCloneFactory = new CloneFactory();
        _flowImplementation = new Flow();
        vm.resumeGasMetering();
    }

    function deployFlow() internal returns (IFlowV5 flow, EvaluableV2 memory evaluable) {
        expressionDeployerDeployExpression2MockCall(address(0), bytes(hex"0006"));

        EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
        flowConfig[0] = EvaluableConfigV3(iDeployer, STUB_EXPRESSION_BYTECODE, new uint256[](0));
        vm.recordLogs();
        flow = IFlowV5(_iCloneFactory.clone(address(_flowImplementation), abi.encode(flowConfig)));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory concreteEvent = findEvent(logs, keccak256("FlowInitialized(address,(address,address,address))"));
        (, evaluable) = abi.decode(concreteEvent.data, (address, EvaluableV2));
    }

    function performFlow(
        IFlowV5 flow,
        EvaluableV2 memory evaluable,
        ERC20Transfer[] memory erc20Transfers,
        ERC721Transfer[] memory erc721Transfers,
        ERC1155Transfer[] memory erc1155Transfers
    ) internal {
        vm.pauseGasMetering();
        uint256[] memory stack = generateTokenTransferStack(erc1155Transfers, erc721Transfers, erc20Transfers);
        interpreterEval2MockCall(stack, new uint256[](0));
        vm.resumeGasMetering();
        flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
    }
}
