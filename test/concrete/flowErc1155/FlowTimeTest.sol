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

    function testFlowTime(string memory uri, uint256[] memory writeToStore, uint256 id, uint256 amount, address alice)
        public
    {
        vm.assume(alice != address(0));
        vm.assume(amount != 0);
        vm.assume(writeToStore.length != 0);
        vm.assume(!alice.isContract());

        (IFlowERC1155V5 erc1155Flow, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);

        ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](1);
        mints[0] = ERC1155SupplyChange({account: alice, id: id, amount: amount});

        ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
        burns[0] = ERC1155SupplyChange({account: alice, id: id, amount: amount});

        uint256[] memory stack = generateFlowStack(
            FlowERC1155IOV1(
                mints, burns, FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
            )
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
