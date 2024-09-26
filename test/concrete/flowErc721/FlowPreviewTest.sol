// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {FlowTransferV1, ERC20Transfer, ERC721Transfer, ERC1155Transfer} from "src/interface/unstable/IFlowV5.sol";
import {FlowERC721Test} from "test/abstract/FlowERC721Test.sol";
import {IFlowERC721V5, ERC721SupplyChange, FlowERC721IOV1} from "../../../src/interface/unstable/IFlowERC721V5.sol";

contract FlowPreviewTest is FlowERC721Test {
    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using multi-element arrays.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721PreviewDefinedFlowIOForERC1155MultiElementArrays(
        address alice,
        uint256 erc1155Amount,
        uint256 erc1155TokenId
    ) external {
        vm.label(alice, "alice");

        (IFlowERC721V5 flow,) =
            deployFlowERC721({name: "FlowErc721", symbol: "FErc721", baseURI: "https://www.rainprotocol.xyz/nft/"});
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
    function testFlowERC721PreviewDefinedFlowIOForERC721MultiElementArrays(
        address alice,
        uint256 erc721TokenIdA,
        uint256 erc721TokenIdB
    ) external {
        vm.label(alice, "alice");

        (IFlowERC721V5 flow,) =
            deployFlowERC721({name: "FlowErc721", symbol: "FErc721", baseURI: "https://www.rainprotocol.xyz/nft/"});
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
    function testFlowERC721PreviewDefinedFlowIOForERC20MultiElementArrays(
        address alice,
        uint256 erc20AmountA,
        uint256 erc20AmountB
    ) external {
        vm.label(alice, "alice");

        (IFlowERC721V5 flow,) =
            deployFlowERC721({name: "FlowErc721", symbol: "FErc721", baseURI: "https://www.rainprotocol.xyz/nft/"});
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
    function testFlowERC721PreviewDefinedFlowIOForERC1155SingleElementArrays(
        address alice,
        uint256 erc1155Amount,
        uint256 erc1155TokenId
    ) external {
        vm.label(alice, "alice");

        (IFlowERC721V5 flow,) =
            deployFlowERC721({name: "FlowErc721", symbol: "FErc721", baseURI: "https://www.rainprotocol.xyz/nft/"});
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
    function testFlowERC721PreviewDefinedFlowIOForERC721SingleElementArrays(
        address alice,
        uint256 erc721TokenInId,
        uint256 erc721TokenOutId
    ) external {
        vm.label(alice, "alice");

        (IFlowERC721V5 flow,) =
            deployFlowERC721({name: "FlowErc721", symbol: "FErc721", baseURI: "https://www.rainprotocol.xyz/nft/"});
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
    function testFlowERC721PreviewDefinedFlowIOForERC20SingleElementArrays(
        address alice,
        uint256 erc20AmountIn,
        uint256 erc20AmountOut
    ) external {
        flowPreviewDefinedFlowIOForERC20SingleElementArrays(alice, erc20AmountIn, erc20AmountOut);
    }

    /**
     * @dev Tests the preview of an empty Flow IO.
     */
    /// forge-config: default.fuzz.runs = 100
    function testFlowERC721PreviewEmptyFlowIO(string memory symbol, string memory baseURI, address alice) public {
        (IFlowERC721V5 flow,) = deployFlowERC721({name: symbol, symbol: symbol, baseURI: baseURI});
        assumeEtchable(alice, address(flow));

        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](2);
        mints[0] = ERC721SupplyChange({account: alice, id: 1});
        mints[1] = ERC721SupplyChange({account: alice, id: 2});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: 2});

        FlowERC721IOV1 memory flowERC721IO = FlowERC721IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC721IO);

        assertEq(
            keccak256(abi.encode(flowERC721IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }
}
