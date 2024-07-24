// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Test, Vm, console2} from "forge-std/Test.sol";
import {REVERTING_MOCK_BYTECODE} from "test/util/lib/LibTestConstants.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {IInterpreterV2} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {IERC1820Registry} from "openzeppelin-contracts/contracts/utils/introspection/IERC1820Registry.sol";
import {IERC1820_REGISTRY} from "test/util/lib/LibTestConstants.sol";
import {IFlowV5} from "src/interface/unstable/IFlowV5.sol";
import {Flow} from "src/concrete/basic/Flow.sol";
import {CloneFactory, ICloneableFactoryV2} from "rain.factory/src/concrete/CloneFactory.sol";
import {EvaluableConfigV3} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";

abstract contract FlowMockRealTest is Test {
    IInterpreterV2 internal immutable iInterpreter;
    IInterpreterStoreV2 internal immutable iStore;
    IExpressionDeployerV3 internal immutable iDeployer;
    IFlowV5 internal immutable iFlow;
    ICloneableFactoryV2 internal immutable iCloneableFactoryV2;

    constructor() {
        iInterpreter = IInterpreterV2(address(uint160(uint256(keccak256("interpreter.rain.test")))));
        vm.etch(address(iInterpreter), REVERTING_MOCK_BYTECODE);

        iStore = IInterpreterStoreV2(address(uint160(uint256(keccak256("store.rain.test")))));
        vm.etch(address(iStore), REVERTING_MOCK_BYTECODE);

        iDeployer = IExpressionDeployerV3(address(uint160(uint256(keccak256("deployer.rain.test")))));
        vm.etch(address(iDeployer), REVERTING_MOCK_BYTECODE);

        vm.etch(address(IERC1820_REGISTRY), REVERTING_MOCK_BYTECODE);
        vm.mockCall(
            address(IERC1820_REGISTRY),
            abi.encodeWithSelector(IERC1820Registry.interfaceHash.selector),
            abi.encode(bytes32(uint256(5)))
        );

        vm.mockCall(
            address(IERC1820_REGISTRY), abi.encodeWithSelector(IERC1820Registry.setInterfaceImplementer.selector), ""
        );

        iFlow = IFlowV5(new Flow());
        iCloneableFactoryV2 = ICloneableFactoryV2(new CloneFactory());
    }

    function findEvent(Vm.Log[] memory logs, bytes32 eventSignature) internal pure returns (Vm.Log memory) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                return logs[i];
            }
        }
        revert("Event not found!");
    }
}
