// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {FLOW_MAX_OUTPUTS, FLOW_ENTRYPOINT} from "src/abstract/FlowCommon.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";
import {FlowERC20Test} from "../../abstract/FlowERC20Test.sol";
import {IFlowERC20V5, ERC20SupplyChange, FlowERC20IOV1} from "../../../src/interface/unstable/IFlowERC20V5.sol";

contract FlowMulticallTest is FlowERC20Test {
    using LibUint256Matrix for uint256[];

    /// Should call multiple flows from same flow contract at once using multicall
    function testFlowErc20MulticallFlows(
        address bob,
        uint256 tokenId,
        uint256 amount,
        address expressionA,
        address expressionB,
        string memory flowName
    ) public {
        vm.assume(expressionA != expressionB);
        vm.assume(bob != address(0));

        vm.label(bob, "Bob");
        vm.label(expressionA, "expressionA");
        vm.label(expressionB, "expressionB");

        address[] memory expressions = new address[](2);
        expressions[0] = expressionA;
        expressions[1] = expressionB;

        (IFlowERC20V5 flow, EvaluableV2[] memory evaluables) = deployFlowERC20(
            expressions,
            address(uint160(uint256(keccak256("configExpression")))),
            new uint256[](0).matrixFrom(new uint256[](0)),
            flowName,
            flowName
        );

        assumeEtchable(bob, address(flow));

        executeFlowA(bob, address(flow), evaluables[0], amount);
        executeFlowB(bob, address(flow), evaluables[1], tokenId, amount);

        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeCall(flow.flow, (evaluables[0], new uint256[](0), new SignedContextV1[](0)));
        calldatas[1] = abi.encodeCall(flow.flow, (evaluables[1], new uint256[](0), new SignedContextV1[](0)));

        vm.startPrank(bob);
        Multicall(address(flow)).multicall(calldatas);
    }

    function executeFlowA(address bob, address flow, EvaluableV2 memory evaluable, uint256 amount) internal {
        (uint256[] memory stack,) =
            mintAndBurnFlowStack(bob, 20 ether, 10 ether, 5, transfersERC20toERC20(bob, flow, amount, amount));
        interpreterEval2MockCall(
            address(flow),
            LibEncodedDispatch.encode2(evaluable.expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
            stack,
            new uint256[](0)
        );
    }

    function executeFlowB(address bob, address flow, EvaluableV2 memory evaluable, uint256 tokenId, uint256 amount)
        internal
    {
        (uint256[] memory stack,) = mintAndBurnFlowStack(
            bob, 20 ether, 10 ether, 5, transferERC721ToERC1155(flow, bob, tokenId, amount, tokenId)
        );
        interpreterEval2MockCall(
            flow,
            LibEncodedDispatch.encode2(evaluable.expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
            stack,
            new uint256[](0)
        );
    }
}
