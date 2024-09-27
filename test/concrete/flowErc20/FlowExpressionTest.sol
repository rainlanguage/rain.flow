// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Vm} from "forge-std/Test.sol";
import {IFlowERC20V5, ERC20SupplyChange} from "src/interface/unstable/IFlowERC20V5.sol";
import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {SignedContextV1} from "rain.interpreter.interface/interface/IInterpreterCallerV2.sol";
import {LibUint256Matrix} from "rain.solmem/lib/LibUint256Matrix.sol";
import {SignContextLib} from "test/lib/SignContextLib.sol";
import {LibContextWrapper} from "test/lib/LibContextWrapper.sol";
import {FlowERC20Test} from "../../abstract/FlowERC20Test.sol";
import {FlowERC20IOV1} from "src/interface/unstable/IFlowERC20V5.sol";

contract FlowExpressionTest is FlowERC20Test {
    using SignContextLib for Vm;
    using LibUint256Matrix for uint256[];
    using LibContextWrapper for uint256[][];

    /**
     * @dev Tests that the addresses of expressions emitted in the event
     *      match the addresses provided by the deployer.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20ShouldDeployExpression(
        string memory name,
        string memory symbol,
        address expressionA,
        address expressionB,
        address expressionC
    ) public {
        vm.assume(expressionA != expressionB && expressionC != expressionB && expressionC != expressionA);

        address[] memory expressions = new address[](2);
        expressions[0] = expressionA;
        expressions[1] = expressionB;

        (, EvaluableV2[] memory evaluables) =
            deployFlowERC20(expressions, expressionC, new uint256[](0).matrixFrom(new uint256[](0)), name, symbol);

        for (uint256 i = 0; i < evaluables.length; i++) {
            assertEq(evaluables[i].expression, expressions[i]);
        }
    }

    /**
     * @dev Validates that the context emitted in the event matches the expected values.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20ShouldValidateContextFromEvent(
        uint256 fuzzedKeyAlice,
        uint256[] memory fuzzedcallerContext0,
        uint256[] memory fuzzedcallerContext1,
        string memory name,
        string memory symbol,
        address alice
    ) public {
        vm.assume(alice != address(0));
        uint256[][] memory matrixCallerContext =
            fuzzedcallerContext0.matrixFrom(fuzzedcallerContext1, fuzzedcallerContext0);

        (IFlowERC20V5 flowErc20, EvaluableV2 memory evaluable) = deployFlowERC20(name, symbol);

        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: alice, amount: 20 ether});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: alice, amount: 10 ether});

        {
            uint256[] memory stack = generateFlowStack(
                FlowERC20IOV1(
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
            flowErc20.flow(evaluable, fuzzedcallerContext0, signedContext);
        }

        {
            uint256[][] memory buildContextInput = LibContextWrapper.buildAndSetContext(
                fuzzedcallerContext0.matrixFrom(), signedContext, address(this), address(flowErc20)
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
