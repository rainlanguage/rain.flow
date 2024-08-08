// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Test.sol";

import {InterpreterMockTest} from "test/abstract/InterpreterMockTest.sol";
import {IFlowERC721V5} from "src/interface/unstable/IFlowERC721V5.sol";
import {FlowERC721} from "src/concrete/erc721/FlowERC721.sol";
import {CloneFactory} from "rain.factory/src/concrete/CloneFactory.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";

contract FlowERC721Test is InterpreterMockTest, FlowUtilsAbstractTest {
    CloneFactory internal immutable iCloneFactory;
    IFlowERC721V5 internal immutable iFlowERC721Implementation;
    IExpressionDeployerV3 internal immutable iDeployerForEvalHandleTransfer;

    constructor() {
        vm.pauseGasMetering();
        iCloneFactory = new CloneFactory();
        iFlowERC721Implementation = new FlowERC721();
        vm.pauseGasMetering();
        iDeployerForEvalHandleTransfer =
            IExpressionDeployerV3(address(uint160(uint256(keccak256("deployer.for.evalhandle.transfer.rain.test")))));
        vm.etch(address(iInterpreter), REVERTING_MOCK_BYTECODE);

        vm.resumeGasMetering();
    }
}
