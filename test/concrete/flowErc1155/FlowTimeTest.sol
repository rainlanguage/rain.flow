// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {FlowERC1155} from "../../../src/concrete/erc1155/FlowERC1155.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {FlowUtilsAbstractTest} from "test/abstract/FlowUtilsAbstractTest.sol";
import {
    IFlowERC1155V5, ERC1155SupplyChange, FlowERC1155IOV1
} from "../../../src/interface/unstable/IFlowERC1155V5.sol";
import {EvaluableV2, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {FlowERC1155Test} from "../../abstract/FlowERC1155Test.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {DEFAULT_STATE_NAMESPACE} from "rain.interpreter.interface/interface/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "rain.interpreter.interface/interface/IInterpreterStoreV2.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

contract FlowTimeTest is FlowUtilsAbstractTest, FlowERC1155Test {
    using SignContextLib for Vm;
    using Address for address;

    function testFlowERC1155FlowTime(string memory uri, uint256[] memory writeToStore, address alice) public {
        vm.assume(alice != address(0));
        vm.assume(writeToStore.length != 0);

        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);
        assumeEtchable(alice, address(erc1155Flow));

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(alice, 20 ether, 10 ether, 5, transferEmpty());
            interpreterEval2MockCall(stack, writeToStore);
            vm.expectCall(
                address(iStore),
                abi.encodeWithSelector(IInterpreterStoreV2.set.selector, DEFAULT_STATE_NAMESPACE, writeToStore)
            );
        }

        vm.mockCall(address(iStore), abi.encodeWithSelector(IInterpreterStoreV2.set.selector), abi.encode());

        erc1155Flow.flow(evaluable, writeToStore, new SignedContextV1[](0));
    }
}
