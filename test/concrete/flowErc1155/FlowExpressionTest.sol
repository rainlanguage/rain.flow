// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";
import {IFlowERC1155V5, ERC1155SupplyChange} from "src/interface/unstable/IFlowERC1155V5.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {FlowERC1155Test} from "../../abstract/FlowERC1155Test.sol";
import {FlowERC1155IOV1} from "src/interface/unstable/IFlowERC1155V5.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

contract FlowExpressionTest is FlowERC1155Test {
    using SignContextLib for Vm;
    using LibUint256Matrix for uint256[];
    using LibContextWrapper for uint256[][];
    using Address for address;

    /**
     * @dev Tests that the addresses of expressions emitted in the event
     *      match the addresses provided by the deployer.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155ShouldDeployExpression(address[] memory expressions, string memory uri, address expression)
        public
    {
        uint256 length = bound(expressions.length, 1, 10);
        assembly ("memory-safe") {
            mstore(expressions, length)
        }

        uint256[][] memory constants = new uint256[][](expressions.length);

        (, EvaluableV2[] memory evaluables) = deployIFlowERC1155V5(expressions, expression, constants, uri);

        for (uint256 i = 0; i < evaluables.length; i++) {
            assertEq(evaluables[i].expression, expressions[i]);
        }
    }

    /**
     * @dev Validates that the context emitted in the event matches the expected values.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC1155ShouldValidateContextFromEvent(
        uint256 fuzzedKeyAlice,
        uint256[] memory fuzzedcallerContext0,
        uint256[] memory fuzzedcallerContext1,
        string memory uri,
        uint256 amount,
        address alice
    ) public {
        vm.assume(!alice.isContract());
        vm.assume(alice != address(0));
        vm.assume(sentinel != amount);

        uint256[][] memory matrixCallerContext =
            fuzzedcallerContext0.matrixFrom(fuzzedcallerContext1, fuzzedcallerContext0);

        (IFlowERC1155V5 flowErc1155, EvaluableV2 memory evaluable) = deployIFlowERC1155V5(uri);

        {
            (uint256[] memory stack,) = mintAndBurnFlowStack(alice, 20 ether, 10 ether, 5, transferEmpty());
            interpreterEval2MockCall(stack, new uint256[](0));
        }

        SignedContextV1[] memory signedContext = new SignedContextV1[](matrixCallerContext.length);
        {
            // Ensure the fuzzed key is within the valid range for secp256k1
            uint256 aliceKey = (fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1;
            for (uint256 i = 0; i < matrixCallerContext.length; i++) {
                signedContext[i] = vm.signContext(aliceKey, aliceKey, matrixCallerContext[i]);
            }

            vm.recordLogs();
            flowErc1155.flow(evaluable, fuzzedcallerContext0, signedContext);
        }

        {
            uint256[][] memory buildContextInput = LibContextWrapper.buildAndSetContext(
                fuzzedcallerContext0.matrixFrom(), signedContext, address(this), address(flowErc1155)
            );

            Vm.Log[] memory logs = vm.getRecordedLogs();
            Vm.Log memory log = findEvent(logs, keccak256("Context(address,uint256[][])"));
            (address sender, uint256[][] memory buildContextOutput) = abi.decode(log.data, (address, uint256[][]));

            assertEq(sender, address(this), "wrong sender");
            assertEq(
                keccak256(abi.encode(buildContextInput)),
                keccak256(abi.encode(buildContextOutput)),
                "wrong compare  Context Input Output"
            );
        }
    }
}
