// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {FlowERC1155Test} from "test/abstract/FlowERC1155Test.sol";
import {
    IFlowERC1155V5, ERC1155SupplyChange, FlowERC1155IOV1
} from "../../../src/interface/unstable/IFlowERC1155V5.sol";
import {IFlowERC1155V5} from "../../../src/interface/unstable/IFlowERC1155V5.sol";

contract FlowPreviewTest is FlowERC1155Test {
    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using multi-element arrays.
     */
    function testFlowERC1155PreviewDefinedFlowIOForERC1155MultiElementArrays(
        address alice,
        uint256 erc1155Amount,
        uint256 erc1155TokenId
    ) external {
        vm.label(alice, "alice");

        (IFlowERC1155V5 flow,) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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
    function testFlowERC1155PreviewDefinedFlowIOForERC721MultiElementArrays(
        address alice,
        uint256 erc721TokenIdA,
        uint256 erc721TokenIdB
    ) external {
        vm.label(alice, "alice");

        (IFlowERC1155V5 flow,) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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
    function testFlowERC1155PreviewDefinedFlowIOForERC20MultiElementArrays(
        address alice,
        uint256 erc20AmountA,
        uint256 erc20AmountB
    ) external {
        vm.label(alice, "alice");

        (IFlowERC1155V5 flow,) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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
    function testFlowERC1155PreviewDefinedFlowIOForERC1155SingleElementArrays(
        address alice,
        uint256 erc1155Amount,
        uint256 erc1155TokenId
    ) external {
        vm.label(alice, "alice");

        (IFlowERC1155V5 flow,) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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
    function testFlowERC1155PreviewDefinedFlowIOForERC721SingleElementArrays(
        address alice,
        uint256 erc721TokenInId,
        uint256 erc721TokenOutId
    ) external {
        vm.label(alice, "alice");

        (IFlowERC1155V5 flow,) = deployIFlowERC1155V5("https://www.rainprotocol.xyz/nft/");
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
    function testFlowERC1155PreviewDefinedFlowIOForERC20SingleElementArrays(
        address alice,
        uint256 erc20AmountIn,
        uint256 erc20AmountOut
    ) external {
        flowPreviewDefinedFlowIOForERC20SingleElementArrays(alice, erc20AmountIn, erc20AmountOut);
    }

    /// Should preview empty flow io
    function testFlowERC1155PreviewEmptyFlowIO(string memory uri, address alice, uint256 amount) public {
        (IFlowERC1155V5 flow,) = deployIFlowERC1155V5({uri: uri});
        assumeEtchable(alice, address(flow));
        vm.assume(sentinel != amount);

        ERC1155SupplyChange[] memory mints = new ERC1155SupplyChange[](2);
        mints[0] = ERC1155SupplyChange({account: alice, id: 1, amount: amount});
        mints[1] = ERC1155SupplyChange({account: alice, id: 2, amount: amount});

        ERC1155SupplyChange[] memory burns = new ERC1155SupplyChange[](1);
        burns[0] = ERC1155SupplyChange({account: alice, id: 2, amount: amount});

        FlowERC1155IOV1 memory flowERC1155IO = FlowERC1155IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC1155IO);

        assertEq(
            keccak256(abi.encode(flowERC1155IO)),
            keccak256(abi.encode(flow.stackToFlow(stack))),
            "wrong compare Structs"
        );
    }
}
