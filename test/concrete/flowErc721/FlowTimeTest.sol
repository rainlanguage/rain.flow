// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {IFlowERC721V5, ERC721SupplyChange, FlowERC721IOV1} from "../../../src/interface/unstable/IFlowERC721V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowERC721Test} from "../../abstract/FlowERC721Test.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

contract FlowTimeTest is FlowERC721Test {
    using SignContextLib for Vm;
    using LibStackGeneration for uint256;

    function testFlowERC721FlowTime(uint256[] memory writeToStore) public {
        vm.assume(writeToStore.length != 0);

        (address flow, EvaluableV2 memory evaluable) = deployFlow();
        (uint256[] memory stack,) = emptyFlowStack();
        interpreterEval2MockCall(stack, writeToStore);

        vm.mockCall(address(iStore), abi.encodeWithSelector(IInterpreterStoreV2.set.selector), abi.encode());

        vm.expectCall(
            address(iStore),
            abi.encodeWithSelector(IInterpreterStoreV2.set.selector, DEFAULT_STATE_NAMESPACE, writeToStore)
        );

        IFlowERC721V5(flow).flow(evaluable, writeToStore, new SignedContextV1[](0));
    }
}
