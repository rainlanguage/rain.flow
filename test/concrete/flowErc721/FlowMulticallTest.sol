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
import {FlowERC721Test} from "../../abstract/FlowERC721Test.sol";
import {IFlowERC721V5, ERC721SupplyChange, FlowERC721IOV1} from "../../../src/interface/unstable/IFlowERC721V5.sol";
import {LibStackGeneration} from "test/lib/LibStackGeneration.sol";

contract FlowMulticallTest is FlowERC721Test {
    using LibUint256Matrix for uint256[];
    using LibStackGeneration for uint256;
    /// Should call multiple flows from same flow contract at once using multicall

    function testFlowErc721MulticallFlows(
        address bob,
        uint256 tokenId,
        uint256 amount,
        address expressionA,
        address expressionB
    ) public {
        vm.assume(expressionA != expressionB);
        vm.assume(sentinel != tokenId);
        vm.assume(sentinel != amount);

        vm.label(bob, "Bob");
        vm.label(expressionA, "expressionA");
        vm.label(expressionB, "expressionB");

        address[] memory expressions = new address[](2);
        expressions[0] = expressionA;
        expressions[1] = expressionB;

        (address flow, EvaluableV2[] memory evaluables) = deployFlow(expressions, new uint256[][](2));

        assumeEtchable(bob, flow);

        //Flow A
        {
            uint256[] memory stack = sentinel.generateFlowStack(
                FlowERC721IOV1(
                    new ERC721SupplyChange[](0),
                    new ERC721SupplyChange[](0),
                    transferERC20ToERC721(bob, flow, amount, tokenId)
                )
            );

            interpreterEval2MockCall(
                flow,
                LibEncodedDispatch.encode2(evaluables[0].expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
                stack,
                new uint256[](0)
            );
        }
        {
            //Flow B
            uint256[] memory stack = sentinel.generateFlowStack(
                FlowERC721IOV1(
                    new ERC721SupplyChange[](0),
                    new ERC721SupplyChange[](0),
                    transferRC721ToERC1155(bob, flow, tokenId, amount, tokenId)
                )
            );

            interpreterEval2MockCall(
                flow,
                LibEncodedDispatch.encode2(evaluables[1].expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
                stack,
                new uint256[](0)
            );
        }

        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] =
            abi.encodeCall(IFlowERC721V5(flow).flow, (evaluables[0], new uint256[](0), new SignedContextV1[](0)));
        calldatas[1] =
            abi.encodeCall(IFlowERC721V5(flow).flow, (evaluables[1], new uint256[](0), new SignedContextV1[](0)));

        vm.startPrank(bob);
        Multicall(flow).multicall(calldatas);
    }
}
