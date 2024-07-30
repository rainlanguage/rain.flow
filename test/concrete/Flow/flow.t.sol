// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Test, Vm, console2} from "forge-std/Test.sol";

import {FlowMockRealTest} from "test/util/abstract/FlowMockRealTest.sol";
import {IFlowV5, RAIN_FLOW_SENTINEL} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableConfigV3, SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {IExpressionDeployerV3} from "rain.interpreter.interface/interface/IExpressionDeployerV3.sol";
import {STUB_EXPRESSION_BYTECODE} from "test/util/lib/LibTestConstants.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {IInterpreterV2} from "lib/rain.factory/lib/rain.interpreter.interface/src/interface/unstable/IInterpreterV2.sol";
import {Flow} from "src/concrete/basic/Flow.sol";

import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

contract FlowConstructionTest is FlowMockRealTest {
    IFlowV5 internal flowImplementation;

    function testSuccessfulERC721ToERC1155Flow(
        address alice,
        uint256 erc721TokenId,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmmount
    ) external {
        IFlowV5 flow;
        address erc721In = makeAddr("erc721In");
        address erc1155Out = makeAddr("erc1155Out");

        {
            // Block 1: Setting up the environment and initial actions
            vm.mockCall(
                address(iDeployer),
                abi.encodeWithSelector(IExpressionDeployerV3.deployExpression2.selector),
                abi.encode(iInterpreter, iStore, address(0), hex"0006")
            );

            uint256[] memory constants = new uint256[](1);
            constants[0] = 2;

            EvaluableConfigV3[] memory flowConfig = new EvaluableConfigV3[](1);
            flowConfig[0] = EvaluableConfigV3(iDeployer, STUB_EXPRESSION_BYTECODE, constants);
            flowImplementation = new Flow();

            vm.recordLogs();
            flow = IFlowV5(iCloneableFactoryV2.clone(address(flowImplementation), abi.encode(flowConfig)));
        }

        uint256[] memory stack;
        {
            // Block 2: Prepare the data stack
            stack = new uint256[](12);

            stack[0] = 115183058774379759847873638693462432260838474092724525396123647190314935293775;
            stack[1] = uint256(uint160(erc1155Out)); // TOKEN
            stack[2] = uint256(uint160(address(flow))); // FROM
            stack[3] = uint256(uint160(alice)); // TO
            stack[4] = erc1155OutTokenId; // ID
            stack[5] = erc1155OutAmmount; // ammount

            stack[6] = 115183058774379759847873638693462432260838474092724525396123647190314935293775;
            stack[7] = uint256(uint160(erc721In)); // TOKEN
            stack[8] = uint256(uint160(alice)); // FROM
            stack[9] = uint256(uint160(address(flow))); // TO
            stack[10] = erc721TokenId; // ID
            stack[11] = 115183058774379759847873638693462432260838474092724525396123647190314935293775;
        }

        {
            vm.mockCall(
                erc1155Out,
                abi.encodeWithSelector(
                    IERC1155.safeTransferFrom.selector, address(flow), alice, erc1155OutTokenId, erc1155OutAmmount, ""
                ),
                abi.encode()
            );

            vm.mockCall(
                erc721In,
                abi.encodeWithSelector(
                    bytes4(keccak256("safeTransferFrom(address,address,uint256)")), alice, address(flow), erc721TokenId
                ),
                abi.encode()
            );

            vm.mockCall(
                address(iInterpreter),
                abi.encodeWithSelector(IInterpreterV2.eval2.selector),
                abi.encode(stack, new uint256[](0))
            );
        }

        {
            // Block 5: Processing logs and calling the flow function
            Vm.Log[] memory logs = vm.getRecordedLogs();
            Vm.Log memory concreteEvent =
                findEvent(logs, keccak256("FlowInitialized(address,(address,address,address))"));
            (, EvaluableV2 memory evaluable) = abi.decode(concreteEvent.data, (address, EvaluableV2));

            vm.prank(alice);
            flow.flow(evaluable, new uint256[](0), new SignedContextV1[](0));
        }
    }
}
