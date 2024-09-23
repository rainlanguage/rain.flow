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
    function testFlowERC721PreviewDefinedFlowIOForERC721MultiElementArrays(
        string memory symbol,
        string memory baseURI,
        address alice,
        uint256 erc721TokenIdA,
        uint256 erc721TokenIdB
    ) external {
        vm.assume(sentinel != erc721TokenIdA);
        vm.assume(sentinel != erc721TokenIdB);

        vm.label(alice, "alice");

        (IFlowERC721V5 flow,) = deployFlowERC721({name: symbol, symbol: symbol, baseURI: baseURI});
        assumeEtchable(alice, address(flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](4);
        erc721Transfers[0] = ERC721Transfer({token: iTokenA, from: address(flow), to: alice, id: erc721TokenIdA});
        erc721Transfers[1] = ERC721Transfer({token: iTokenB, from: address(flow), to: alice, id: erc721TokenIdB});
        erc721Transfers[2] = ERC721Transfer({token: iTokenA, from: alice, to: address(flow), id: erc721TokenIdA});
        erc721Transfers[3] = ERC721Transfer({token: iTokenB, from: alice, to: address(flow), id: erc721TokenIdB});

        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](2);
        mints[0] = ERC721SupplyChange({account: alice, id: 1});
        mints[1] = ERC721SupplyChange({account: alice, id: 2});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: 2});

        FlowERC721IOV1 memory flowERC721IO = FlowERC721IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC721IO);

        assertEq(
            keccak256(abi.encode(flowERC721IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     *      using multi-element arrays.
     */
    function testFlowERC721PreviewDefinedFlowIOForERC20MultiElementArrays(
        string memory symbol,
        string memory baseURI,
        address alice,
        uint256 erc20AmountA,
        uint256 erc20AmountB
    ) external {
        vm.assume(sentinel != erc20AmountA);
        vm.assume(sentinel != erc20AmountB);

        vm.label(alice, "alice");

        (IFlowERC721V5 flow,) = deployFlowERC721({name: symbol, symbol: symbol, baseURI: baseURI});
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

        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](2);
        mints[0] = ERC721SupplyChange({account: alice, id: 1});
        mints[1] = ERC721SupplyChange({account: alice, id: 2});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: 2});

        FlowERC721IOV1 memory flowERC721IO = FlowERC721IOV1(
            mints, burns, FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC721IO);

        assertEq(
            keccak256(abi.encode(flowERC721IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC1155
     *      using single-element arrays.
     */
    function testFlowERC721PreviewDefinedFlowIOForERC1155SingleElementArrays(
        string memory symbol,
        string memory baseURI,
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

        (IFlowERC721V5 flow,) = deployFlowERC721({name: symbol, symbol: symbol, baseURI: baseURI});
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

        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](2);
        mints[0] = ERC721SupplyChange({account: alice, id: 1});
        mints[1] = ERC721SupplyChange({account: alice, id: 2});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: 2});

        FlowERC721IOV1 memory flowERC721IO = FlowERC721IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers)
        );

        uint256[] memory stack = generateFlowStack(flowERC721IO);

        assertEq(
            keccak256(abi.encode(flowERC721IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC721
     *      using single-element arrays.
     */
    function testFlowERC721PreviewDefinedFlowIOForERC721SingleElementArrays(
        string memory symbol,
        string memory baseURI,
        address alice,
        uint256 erc721TokenInId,
        uint256 erc721TokenOutId
    ) external {
        vm.assume(sentinel != erc721TokenInId);
        vm.assume(sentinel != erc721TokenOutId);

        vm.label(alice, "alice");

        (IFlowERC721V5 flow,) = deployFlowERC721({name: symbol, symbol: symbol, baseURI: baseURI});
        assumeEtchable(alice, address(flow));

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
        erc721Transfers[0] = ERC721Transfer({token: iTokenA, from: address(flow), to: alice, id: erc721TokenOutId});
        erc721Transfers[1] = ERC721Transfer({token: iTokenA, from: alice, to: address(flow), id: erc721TokenInId});

        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](2);
        mints[0] = ERC721SupplyChange({account: alice, id: 1});
        mints[1] = ERC721SupplyChange({account: alice, id: 2});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: 2});

        FlowERC721IOV1 memory flowERC721IO = FlowERC721IOV1(
            mints, burns, FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC721IO);

        assertEq(
            keccak256(abi.encode(flowERC721IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of defined Flow IO for ERC20
     *      using single-element arrays.
     */
    function testFlowERC721PreviewDefinedFlowIOForERC20SingleElementArrays(
        string memory symbol,
        string memory baseURI,
        address alice,
        uint256 erc20AmountIn,
        uint256 erc20AmountOut
    ) external {
        vm.assume(sentinel != erc20AmountIn);
        vm.assume(sentinel != erc20AmountOut);

        vm.label(alice, "alice");

        (IFlowERC721V5 flow,) = deployFlowERC721({name: symbol, symbol: symbol, baseURI: baseURI});
        assumeEtchable(alice, address(flow));

        ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
        erc20Transfers[0] =
            ERC20Transfer({token: address(iTokenA), from: address(flow), to: alice, amount: erc20AmountOut});
        erc20Transfers[1] =
            ERC20Transfer({token: address(iTokenA), from: alice, to: address(flow), amount: erc20AmountIn});

        ERC721SupplyChange[] memory mints = new ERC721SupplyChange[](2);
        mints[0] = ERC721SupplyChange({account: alice, id: 1});
        mints[1] = ERC721SupplyChange({account: alice, id: 2});

        ERC721SupplyChange[] memory burns = new ERC721SupplyChange[](1);
        burns[0] = ERC721SupplyChange({account: alice, id: 2});

        FlowERC721IOV1 memory flowERC721IO = FlowERC721IOV1(
            mints, burns, FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0))
        );

        uint256[] memory stack = generateFlowStack(flowERC721IO);

        assertEq(
            keccak256(abi.encode(flowERC721IO)), keccak256(abi.encode(flow.stackToFlow(stack))), "wrong compare Structs"
        );
    }

    /**
     * @dev Tests the preview of an empty Flow IO.
     */
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
