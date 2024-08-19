// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {FlowBasicTest} from "test/abstract/FlowBasicTest.sol";
import {
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer
} from "test/abstract/FlowUtilsAbstractTest.sol";
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
import {IFlowERC20V5} from "../../../src/interface/unstable/IFlowERC20V5.sol";

contract FlowMulticallTest is FlowBasicTest, FlowERC20Test {
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
    function testFlowERC20MulticallFlows(
        address alice,
        uint256 tokenId,
        uint256 amount,
        address expressionA,
        address expressionB,
        string memory flow
    ) public {
        vm.assume(expressionA != expressionB);
        vm.assume(sentinel != tokenId);
        vm.assume(sentinel != amount);

        address[] memory expressions = new address[](2);
        expressions[0] = expressionA;
        expressions[1] = expressionB;
        uint256[] memory constants = new uint256[](0);

        (IFlowERC20V5 erc20Flow, EvaluableV2 memory evaluable) = deployFlowERC20(flow, flow);

        assumeEtchable(alice, address(erc20Flow));

        //FlowA
        {
            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
            erc721Transfers[0] = ERC721Transfer({token: address(iTokenA), from: address(erc20Flow), to: alice, id: tokenId});

            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
            erc20Transfers[0] = ERC20Transfer({token: address(iTokenB), from: alice, to: address(erc20Flow), amount: amount});

            uint256[] memory stack =
                generateTokenTransferStack(new ERC1155Transfer[](0), erc721Transfers, erc20Transfers);

            interpreterEval2MockCall(
                address(erc20Flow),
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
                    bytes4(keccak256("safeTransferFrom(address,address,uint256)")), erc20Flow, alice, tokenId
                )
            );

            vm.mockCall(iTokenB, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
            vm.expectCall(iTokenB, abi.encodeWithSelector(IERC20.transferFrom.selector, alice, erc20Flow, amount));
        }

        //FlowB
        {
            ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](1);
            erc1155Transfers[0] =
                ERC1155Transfer({token: address(iTokenC), from: address(erc20Flow), to: alice, id: tokenId, amount: amount});

            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
            erc721Transfers[0] = ERC721Transfer({token: address(iTokenA), from: alice, to: address(erc20Flow), id: tokenId});

            uint256[] memory stack =
                generateTokenTransferStack(erc1155Transfers, erc721Transfers, new ERC20Transfer[](0));

            interpreterEval2MockCall(
                address(erc20Flow),
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
                    bytes4(keccak256("safeTransferFrom(address,address,uint256)")), alice, erc20Flow, tokenId
                )
            );

            vm.mockCall(iTokenC, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
            vm.expectCall(
                iTokenC, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector, erc20Flow, alice, tokenId, amount, "")
            );
        }

        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeCall(erc20Flow.flow, (evaluables[0], new uint256[](0), new SignedContextV1[](0)));
        calldatas[1] = abi.encodeCall(erc20Flow.flow, (evaluables[1], new uint256[](0), new SignedContextV1[](0)));

        vm.startPrank(alice);
        Multicall(address(erc20Flow)).multicall(calldatas);
    }
}
