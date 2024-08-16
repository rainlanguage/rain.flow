// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {IFlowV5, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {FLOW_MAX_OUTPUTS, FLOW_ENTRYPOINT} from "src/abstract/FlowCommon.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {REVERTING_MOCK_BYTECODE} from "test/abstract/TestConstants.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibEncodedDispatch} from "rain.interpreter.interface/lib/caller/LibEncodedDispatch.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";

contract FlowMulticallTest is FlowBasicTest {
    using LibUint256Matrix for uint256[];

    address internal immutable iTokenA;
    address internal immutable iTokenB;
    address internal immutable iTokenC;

    constructor() {
        vm.pauseGasMetering();
        iTokenA = address(uint160(uint256(keccak256("tokenA.test"))));
        vm.etch(address(iTokenA), REVERTING_MOCK_BYTECODE);

        iTokenB = address(uint160(uint256(keccak256("tokenB.test"))));
        vm.etch(address(iTokenB), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();

        iTokenC = address(uint160(uint256(keccak256("tokenC.test"))));
        vm.etch(address(iTokenC), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    /**
     * @dev Should call multiple flows from same flow contract at once using multicall
     *
     */
    function testFlowBasicMulticallFlows(
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
        uint256[] memory constants = new uint256[](0);

        (IFlowV5 flow, EvaluableV2[] memory evaluables) = deployFlow(expressions, constants.matrixFrom(constants));

        assumeEtchable(bob, address(flow));

        //FlowA
        {
            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
            erc721Transfers[0] = ERC721Transfer({token: address(iTokenA), from: address(flow), to: bob, id: tokenId});

            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
            erc20Transfers[0] = ERC20Transfer({token: address(iTokenB), from: bob, to: address(flow), amount: amount});

            uint256[] memory stack =
                generateTokenTransferStack(new ERC1155Transfer[](0), erc721Transfers, erc20Transfers);

            interpreterEval2MockCall(
                address(flow),
                LibEncodedDispatch.encode2(evaluables[0].expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
                stack,
                new uint256[](0)
            );
        }

        {
            vm.mockCall(
                iTokenA, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), ""
            );
            vm.expectCall(
                iTokenA,
                abi.encodeWithSelector(
                    bytes4(keccak256("safeTransferFrom(address,address,uint256)")), flow, bob, tokenId
                )
            );

            vm.mockCall(iTokenB, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
            vm.expectCall(iTokenB, abi.encodeWithSelector(IERC20.transferFrom.selector, bob, flow, amount));
        }

        //FlowB
        {
            ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](1);
            erc1155Transfers[0] =
                ERC1155Transfer({token: address(iTokenC), from: address(flow), to: bob, id: tokenId, amount: amount});

            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
            erc721Transfers[0] = ERC721Transfer({token: address(iTokenA), from: bob, to: address(flow), id: tokenId});

            uint256[] memory stack =
                generateTokenTransferStack(erc1155Transfers, erc721Transfers, new ERC20Transfer[](0));

            interpreterEval2MockCall(
                address(flow),
                LibEncodedDispatch.encode2(evaluables[1].expression, FLOW_ENTRYPOINT, FLOW_MAX_OUTPUTS),
                stack,
                new uint256[](0)
            );
        }

        {
            vm.mockCall(
                iTokenA, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), ""
            );
            vm.expectCall(
                iTokenA,
                abi.encodeWithSelector(
                    bytes4(keccak256("safeTransferFrom(address,address,uint256)")), bob, flow, tokenId
                )
            );

            vm.mockCall(iTokenC, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
            vm.expectCall(
                iTokenC, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector, flow, bob, tokenId, amount, "")
            );
        }

        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeCall(flow.flow, (evaluables[0], new uint256[](0), new SignedContextV1[](0)));
        calldatas[1] = abi.encodeCall(flow.flow, (evaluables[1], new uint256[](0), new SignedContextV1[](0)));

        vm.startPrank(bob);
        Multicall(address(flow)).multicall(calldatas);
    }
}