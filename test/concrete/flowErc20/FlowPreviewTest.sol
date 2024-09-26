// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {IFlowERC20V5, ERC20SupplyChange, FlowERC20IOV1} from "../../../src/interface/unstable/IFlowERC20V5.sol";
import {EvaluableV2} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {LibEvaluable} from "rain.interpreter.interface/lib/caller/LibEvaluable.sol";
import {FlowERC20Test} from "test/abstract/FlowERC20Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract FlowPreviewTest is FlowERC20Test {
    using LibEvaluable for EvaluableV2;

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using multi-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20PreviewDefinedFlowIOForERC1155MultiElementArrays(
        address alice,
        uint256 erc1155Amount,
        uint256 erc1155TokenId
    ) external {
        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20("Flow ERC20", "F20");
        assumeEtchable(alice, address(flow));
        {
            (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
                alice,
                20 ether,
                10 ether,
                5,
                multiTransferERC1155(alice, address(flow), erc1155TokenId, erc1155Amount, erc1155TokenId, erc1155Amount)
            );

            assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
        }
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     *      using multi-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20PreviewDefinedFlowIOForERC721MultiElementArrays(
        address alice,
        uint256 erc721TokenIdA,
        uint256 erc721TokenIdB
    ) external {
        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20("Flow ERC20", "F20");
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice, 20 ether, 10 ether, 5, multiTransferERC721(alice, address(flow), erc721TokenIdA, erc721TokenIdB)
        );

        assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     *      using multi-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20PreviewDefinedFlowIOForERC20MultiElementArrays(
        address alice,
        uint256 erc20AmountA,
        uint256 erc20AmountB
    ) external {
        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20("Flow ERC20", "F20");
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice, 20 ether, 10 ether, 5, multiTransfersERC20(alice, address(flow), erc20AmountA, erc20AmountB)
        );

        assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using single-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20PreviewDefinedFlowIOForERC1155SingleElementArrays(
        address alice,
        uint256 erc1155Amount,
        uint256 erc1155TokenId
    ) external {
        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20("Flow ERC20", "F20");
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice,
            20 ether,
            10 ether,
            5,
            createTransferERC1155ToERC1155(
                alice, address(flow), erc1155TokenId, erc1155Amount, erc1155TokenId, erc1155Amount
            )
        );

        assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     *      using single-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20PreviewDefinedFlowIOForERC721SingleElementArrays(
        address alice,
        uint256 erc721TokenInId,
        uint256 erc721TokenOutId
    ) external {
        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20("Flow ERC20", "F20");
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice,
            20 ether,
            10 ether,
            5,
            createTransferERC721ToERC721(alice, address(flow), erc721TokenInId, erc721TokenOutId)
        );

        assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     *      using single-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20PreviewDefinedFlowIOForERC20SingleElementArrays(
        address alice,
        uint256 erc20AmountIn,
        uint256 erc20AmountOut
    ) external {
        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20("Flow ERC20", "F20");
        assumeEtchable(alice, address(flow));

        (uint256[] memory stack, bytes32 transferHash) = mintAndBurnFlowStack(
            alice,
            20 ether,
            10 ether,
            5,
            createTransfersERC20toERC20(alice, address(flow), erc20AmountIn, erc20AmountOut)
        );

        assertEq(transferHash, keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs");
    }

    /**
     * @dev Tests the preview of an empty Flow IO.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC20PreviewEmptyFlowIO(string memory name, string memory symbol, address alice) public {
        (IFlowERC20V5 flow,) = deployFlowERC20(name, symbol);
        assumeEtchable(alice, address(flow));

        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: alice, amount: 20 ether});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: alice, amount: 10 ether});

        FlowERC20IOV1 memory flowERC20IO = FlowERC20IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC20IO);

        assertEq(
            keccak256(abi.encode(flowERC20IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }
}
