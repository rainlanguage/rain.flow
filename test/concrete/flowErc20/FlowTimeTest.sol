// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {IFlowERC20V5, ERC20SupplyChange, FlowERC20IOV1} from "../../../src/interface/unstable/IFlowERC20V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowERC20Test} from "../../abstract/FlowERC20Test.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";

contract FlowTimeTest is FlowERC20Test {
    using SignContextLib for Vm;

    function testFlowERC20FlowTime(string memory name, string memory symbol, uint256[] memory writeToStore) public {
        vm.assume(writeToStore.length != 0);
        (IFlowERC20V5 erc20Flow, EvaluableV2 memory evaluable) = deployFlowERC20(name, symbol);

        uint256[] memory stack = generateFlowStack(
            FlowERC20IOV1(
                new ERC20SupplyChange[](0),
                new ERC20SupplyChange[](0),
                FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
            )
        );

        interpreterEval2MockCall(stack, writeToStore);

        vm.mockCall(address(iStore), abi.encodeWithSelector(IInterpreterStoreV2.set.selector), abi.encode());

        vm.expectCall(
            address(iStore),
            abi.encodeWithSelector(IInterpreterStoreV2.set.selector, DEFAULT_STATE_NAMESPACE, writeToStore)
        );

        erc20Flow.flow(evaluable, writeToStore, new SignedContextV1[](0));
    }
}
