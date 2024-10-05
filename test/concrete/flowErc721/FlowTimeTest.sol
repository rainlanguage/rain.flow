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
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

contract FlowTimeTest is FlowERC721Test {
    using SignContextLib for Vm;
    using Address for address;

    function testFlowERC721FlowTime(
        string memory uri,
        string memory name,
        string memory symbol,
        address alice,
        uint256[] memory writeToStore
    ) public {
        vm.assume(writeToStore.length != 0);
        vm.assume(alice != address(0));
        vm.assume(!alice.isContract());

        (IFlowERC721V5 erc1155Flow, EvaluableV2 memory evaluable) = deployFlowERC721(name, symbol, uri);
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
