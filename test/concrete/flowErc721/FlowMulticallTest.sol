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

contract FlowMulticallTest is FlowERC721Test {
    using LibUint256Matrix for uint256[];

    /// Should call multiple flows from same flow contract at once using multicall
    function testFlowErc721MulticallFlows(
        address bob,
        uint256 tokenId,
        uint256 amount,
        address expressionA,
        address expressionB,
        string memory baseURI
    ) public {
        vm.assume(expressionA != expressionB);
        vm.assume(sentinel != tokenId);
        vm.assume(sentinel != amount);
        vm.assume(bob != address(0));

        vm.label(bob, "Bob");
        vm.label(expressionA, "expressionA");
        vm.label(expressionB, "expressionB");

        address[] memory expressions = new address[](2);
        expressions[0] = expressionA;
        expressions[1] = expressionB;
        uint256[] memory constants = new uint256[](0);

        (IFlowERC721V5 erc721Flow, EvaluableV2[] memory evaluables) =
            deployFlowERC721(expressions, address(1), constants.matrixFrom(constants), "Flow ERC721", "F721", baseURI);

        assumeEtchable(bob, address(erc721Flow));

        //Flow A
        {
            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
            erc721Transfers[0] =
                ERC721Transfer({token: address(iTokenA), from: address(erc721Flow), to: bob, id: tokenId});

            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
            erc20Transfers[0] =
                ERC20Transfer({token: address(iTokenB), from: bob, to: address(erc721Flow), amount: amount});

            ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](1);
            mints[0] = ERC721SupplyChange({account: bob, id: tokenId});

            ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
            burns[0] = ERC721SupplyChange({account: bob, id: tokenId});

            uint256[] memory stack = generateFlowStack(
                FlowERC721IOV1(mints, burns, FlowTransferV1(erc20Transfers, erc721Transfers, new ERC1155Transfer[](0)))
            );

            interpreterEval2MockCall(
                address(erc721Flow),
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
                    bytes4(keccak256("safeTransferFrom(address,address,uint256)")), erc721Flow, bob, tokenId
                )
            );

            vm.mockCall(iTokenB, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
            vm.expectCall(iTokenB, abi.encodeWithSelector(IERC20.transferFrom.selector, bob, erc721Flow, amount));
        }

        //Flow B
        {
            ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](1);
            erc1155Transfers[0] = ERC1155Transfer({
                token: address(iTokenC),
                from: address(erc721Flow),
                to: bob,
                id: tokenId,
                amount: amount
            });

            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
            erc721Transfers[0] =
                ERC721Transfer({token: address(iTokenA), from: bob, to: address(erc721Flow), id: tokenId});

            uint256[] memory stack = generateFlowStack(
                FlowERC721IOV1(
                    new ERC721SupplyChange[](0),
                    new ERC721SupplyChange[](0),
                    FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, erc1155Transfers)
                )
            );

            interpreterEval2MockCall(
                address(erc721Flow),
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
                    bytes4(keccak256("safeTransferFrom(address,address,uint256)")), bob, erc721Flow, tokenId
                )
            );

            vm.mockCall(iTokenC, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
            vm.expectCall(
                iTokenC,
                abi.encodeWithSelector(IERC1155.safeTransferFrom.selector, erc721Flow, bob, tokenId, amount, "")
            );
        }

        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encodeCall(erc721Flow.flow, (evaluables[0], new uint256[](0), new SignedContextV1[](0)));
        calldatas[1] = abi.encodeCall(erc721Flow.flow, (evaluables[1], new uint256[](0), new SignedContextV1[](0)));

        vm.startPrank(bob);
        Multicall(address(erc721Flow)).multicall(calldatas);
    }
}
