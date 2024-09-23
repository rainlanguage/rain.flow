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
    function testFlowERC20PreviewDefinedFlowIOForERC20MultiElementArrays(
        string memory name,
        string memory symbol,
        address alice,
        uint256 erc20AmountA,
        uint256 erc20AmountB
    ) external {
        vm.assume(sentinel != erc20AmountA);
        vm.assume(sentinel != erc20AmountB);

        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20(name, symbol);
        assumeEtchable(alice, address(flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](4);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(flow), to: alice, amount: erc20AmountA});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenB), from: address(flow), to: alice, amount: erc20AmountB});
        erc20Transfers[2] =
            ERC20Transfer({token: address(iTokenA), from: alice, to: address(flow), amount: erc20AmountA});
        erc20Transfers[3] =
            ERC20Transfer({token: address(iTokenB), from: alice, to: address(flow), amount: erc20AmountB});

        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: alice, amount: 20 ether});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: alice, amount: 10 ether});

        FlowERC20IOV1 memory flowERC20IO = FlowERC20IOV1(
            mints, burns, FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC20IO);

        assertEq(
            keccak256(abi.encode(flowERC20IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using single-element arrays.
     */
    function testFlowERC20PreviewDefinedFlowIOForERC1155SingleElementArrays(
        string memory name,
        string memory symbol,
        address alice,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155InTokenId,
        uint256 erc1155InAmount
    ) external {
        vm.assume(sentinel != erc1155OutTokenId);
        vm.assume(sentinel != erc1155OutAmount);
        vm.assume(sentinel != erc1155InTokenId);
        vm.assume(sentinel != erc1155InAmount);
        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20(name, symbol);
        assumeEtchable(alice, address(flow));

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);

        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iTokenA),
            from: address(flow),
            to: alice,
            id: erc1155OutTokenId,
            amount: erc1155OutAmount
        });

        erc1155Transfers[1] = ERC1155Transfer({
            token: address(iTokenA),
            from: alice,
            to: address(flow),
            id: erc1155InTokenId,
            amount: erc1155InAmount
        });

        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: alice, amount: 20 ether});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: alice, amount: 10 ether});

        FlowERC20IOV1 memory flowERC20IO = FlowERC20IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers)
        );

        uint256[] memory stack = generateFlowStack(flowERC20IO);

        assertEq(
            keccak256(abi.encode(flowERC20IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     *      using single-element arrays.
     */
    function testFlowERC20PreviewDefinedFlowIOForERC721SingleElementArrays(
        string memory name,
        string memory symbol,
        address alice,
        uint256 erc721TokenInId,
        uint256 erc721TokenOutId
    ) external {
        vm.assume(sentinel != erc721TokenInId);
        vm.assume(sentinel != erc721TokenOutId);

        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20(name, symbol);
        assumeEtchable(alice, address(flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
        erc721Transfers[0] = ERC721Transfer({token: iTokenA, from: address(flow), to: alice, id: erc721TokenOutId});
        erc721Transfers[1] = ERC721Transfer({token: iTokenA, from: alice, to: address(flow), id: erc721TokenInId});

        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: alice, amount: 20 ether});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: alice, amount: 10 ether});

        FlowERC20IOV1 memory flowERC20IO = FlowERC20IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC20IO);

        assertEq(
            keccak256(abi.encode(flowERC20IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     *      using single-element arrays.
     */
    function testFlowERC20PreviewDefinedFlowIOForERC20SingleElementArrays(
        string memory name,
        string memory symbol,
        address alice,
        uint256 erc20AmountIn,
        uint256 erc20AmountOut
    ) external {
        vm.assume(sentinel != erc20AmountIn);
        vm.assume(sentinel != erc20AmountOut);

        vm.label(alice, "alice");

        (IFlowERC20V5 flow,) = deployFlowERC20(name, symbol);
        assumeEtchable(alice, address(flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(flow), to: alice, amount: erc20AmountOut});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenA), from: alice, to: address(flow), amount: erc20AmountIn});

        ERC20SupplyChange[] memory mints = new ERC20SupplyChange[](1);
        mints[0] = ERC20SupplyChange({account: alice, amount: 20 ether});

        ERC20SupplyChange[] memory burns = new ERC20SupplyChange[](1);
        burns[0] = ERC20SupplyChange({account: alice, amount: 10 ether});

        FlowERC20IOV1 memory flowERC20IO = FlowERC20IOV1(
            mints, burns, FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC20IO);

        assertEq(
            keccak256(abi.encode(flowERC20IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of an empty Flow IO.
     */
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
