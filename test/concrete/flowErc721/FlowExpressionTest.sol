// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";
import {IFlowERC721V5, ERC721SupplyChange} from "src/interface/unstable/IFlowERC721V5.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {FlowERC721Test} from "../../abstract/FlowERC721Test.sol";
import {FlowERC721IOV1} from "src/interface/unstable/IFlowERC721V5.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";

contract FlowExpressionTest is FlowERC721Test {
    using SignContextLib for Vm;
    using LibUint256Matrix for uint256[];

    /**
     * @dev Tests that the addresses of expressions emitted in the event
     *      match the addresses provided by the deployer.
     */
    function testFlowERC721ShouldDeployExpression(
        address[] memory expressions,
        string memory name,
        string memory symbol,
        string memory uri
    ) public {
        uint256 length = bound(expressions.length, 1, 10);
        assembly ("memory-safe") {
            mstore(expressions, length)
        }

        uint256[][] memory constants = new uint256[][](expressions.length);

        (, EvaluableV2[] memory evaluables) =
            deployFlowERC721(expressions, expressions[0], constants, name, symbol, uri);

        for (uint256 i = 0; i < evaluables.length; i++) {
            assertEq(evaluables[i].expression, expressions[i]);
        }
    }

    /**
     * @dev Validates that the context emitted in the event matches the expected values.
     */
    function testFlowERC721ShouldValidateContextFromEvent(
        uint256 fuzzedKeyAlice,
        uint256[] memory fuzzedcallerContext0,
        uint256[] memory fuzzedcallerContext1,
        string memory name,
        string memory symbol,
        string memory uri,
        address alice,
        uint256 id
    ) public {
        vm.assume(alice != address(0));
        uint256[][] memory matrixCallerContext =
            fuzzedcallerContext0.matrixFrom(fuzzedcallerContext1, fuzzedcallerContext0);

        (IFlowERC721V5 flowErc721, EvaluableV2 memory evaluable) = deployFlowERC721(name, symbol, uri);
        {
            ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](1);
            mints[0] = ERC721SupplyChange({account: alice, id: id});

            ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
            burns[0] = ERC721SupplyChange({account: alice, id: id});

            uint256[] memory stack = generateFlowStack(
                FlowERC721IOV1(
                    mints,
                    burns,
                    FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
                )
            );

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
            flowErc721.flow(evaluable, fuzzedcallerContext0, signedContext);
        }

        {
            uint256[][] memory buildContextInput = LibContextWrapper.buildAndSetContext(
                fuzzedcallerContext0.matrixFrom(), signedContext, address(this), address(flowErc721)
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
