// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {FlowERC1155} from "../../../src/concrete/erc1155/FlowERC1155.sol";
import {
    FlowUtilsAbstractTest,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    ERC1155SupplyChange
} from "test/abstract/FlowUtilsAbstractTest.sol";
import {IFlowERC1155V5} from "../../../src/interface/unstable/IFlowERC1155V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowERC1155Test} from "../../abstract/FlowERC1155Test.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";

contract FlowTimeTest is FlowUtilsAbstractTest, FlowERC1155Test {
    using SignContextLib for Vm;

    function testFlowTime(string memory uri, uint256[] memory writeToStore) public {
        vm.assume(writeToStore.length != 0);

        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);

        uint256[] memory stack = generateFlowERC1155Stack(
            new ERC1155Transfer[](0),
            new ERC721Transfer[](0),
            new ERC20Transfer[](0),
            new ERC1155SupplyChange[](0),
            new ERC1155SupplyChange[](0)
        );

        interpreterEval2MockCall(stack, writeToStore);

        vm.mockCall(address(iStore), abi.encodeWithSelector(IInterpreterStoreV2.set.selector), abi.encode());

        vm.expectCall(
            address(iStore),
            abi.encodeWithSelector(IInterpreterStoreV2.set.selector, DEFAULT_STATE_NAMESPACE, writeToStore)
        );

        erc1155Flow.flow(evaluable, writeToStore, new SignedContextV1[](0));
    }
}
