// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {
    FlowTransferV1,
    ERC20Transfer,
    ERC721Transfer,
    ERC1155Transfer,
    RAIN_FLOW_SENTINEL
} from "src/interface/unstable/IFlowV5.sol";
import {STUB_EXPRESSION_BYTECODE, REVERTING_MOCK_BYTECODE} from "./TestConstants.sol";
import {Sentinel} from "rain.solmem/lib/LibStackSentinel.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

abstract contract FlowTransferOperation is Test {
    address internal immutable iTokenA;
    address internal immutable iTokenB;
    address internal immutable iTokenC;
    uint256 internal immutable sentinel;

    constructor() {
        vm.pauseGasMetering();
        sentinel = Sentinel.unwrap(RAIN_FLOW_SENTINEL);

        iTokenA = address(uint160(uint256(keccak256("tokenA.test"))));
        vm.etch(address(iTokenA), REVERTING_MOCK_BYTECODE);

        iTokenB = address(uint160(uint256(keccak256("tokenB.test"))));
        vm.etch(address(iTokenB), REVERTING_MOCK_BYTECODE);

        iTokenC = address(uint160(uint256(keccak256("tokenC.test"))));
        vm.etch(address(iTokenC), REVERTING_MOCK_BYTECODE);
        vm.resumeGasMetering();
    }

    function transferEmpty() internal pure returns (FlowTransferV1 memory) {
        return FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), new ERC1155Transfer[](0));
    }

    function transferRC721ToERC1155(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155OutTokenId
    ) internal returns (FlowTransferV1 memory transfer) {
        transfer = createTransferRC721ToERC1155(addressA, addressB, erc721InTokenId, erc1155OutAmount, erc1155OutTokenId);
        mockTransferRC721ToERC1155(addressA, addressB, erc721InTokenId, erc1155OutAmount, erc1155OutTokenId);
    }

    function createTransferRC721ToERC1155(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155OutTokenId
    ) internal view returns (FlowTransferV1 memory) {
        {
            vm.assume(sentinel != erc721InTokenId);
            vm.assume(sentinel != erc1155OutTokenId);
            vm.assume(sentinel != erc1155OutAmount);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
        erc721Transfers[0] =
            ERC721Transfer({token: address(iTokenB), from: addressA, to: addressB, id: erc721InTokenId});

        ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](1);
        erc1155Transfers[0] = ERC1155Transfer({
            token: address(iTokenC),
            from: addressB,
            to: addressA,
            id: erc1155OutTokenId,
            amount: erc1155OutAmount
        });

        return FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, erc1155Transfers);
    }

    function mockTransferRC721ToERC1155(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc1155OutAmount,
        uint256 erc1155OutTokenId
    ) internal {
        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), addressA, addressB, erc721InTokenId
            )
        );

        vm.mockCall(iTokenC, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
        vm.expectCall(
            iTokenC,
            abi.encodeWithSelector(
                IERC1155.safeTransferFrom.selector, addressB, addressA, erc1155OutTokenId, erc1155OutAmount, ""
            )
        );
    }

    function transferERC20ToERC721(address addressA, address addressB, uint256 erc20InAmount, uint256 erc721OutTokenId)
        internal
        returns (FlowTransferV1 memory transfer)
    {
        transfer = createTransferERC20ToERC721(addressA, addressB, erc20InAmount, erc721OutTokenId);
        mockTransferERC20ToERC721(addressA, addressB, erc20InAmount, erc721OutTokenId);
    }

    function createTransferERC20ToERC721(
        address addressA,
        address addressB,
        uint256 erc20InAmount,
        uint256 erc721OutTokenId
    ) internal view returns (FlowTransferV1 memory transfer) {
        {
            vm.assume(sentinel != erc20InAmount);
            vm.assume(sentinel != erc721OutTokenId);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](1);
            erc20Transfers[0] =
                ERC20Transfer({token: address(iTokenA), from: addressA, to: addressB, amount: erc20InAmount});

            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](1);
            erc721Transfers[0] = ERC721Transfer({token: iTokenB, from: addressB, to: addressA, id: erc721OutTokenId});

            transfer = FlowTransferV1(erc20Transfers, erc721Transfers, new ERC1155Transfer[](0));
        }
    }

    function mockTransferERC20ToERC721(
        address addressA,
        address addressB,
        uint256 erc20InAmount,
        uint256 erc721OutTokenId
    ) internal {
        vm.mockCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(iTokenA, abi.encodeWithSelector(IERC20.transferFrom.selector, addressA, addressB, erc20InAmount));

        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), addressB, addressA, erc721OutTokenId
            )
        );
    }

    function transferERC721ToERC721(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc721OutTokenId
    ) internal returns (FlowTransferV1 memory transfer) {
        transfer = createTransferERC721ToERC721(addressA, addressB, erc721InTokenId, erc721OutTokenId);
        mockTransferERC721ToERC721(addressA, addressB, erc721InTokenId, erc721OutTokenId);
    }

    function createTransferERC721ToERC721(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc721OutTokenId
    ) internal view returns (FlowTransferV1 memory transfer) {
        {
            vm.assume(sentinel != erc721InTokenId);
            vm.assume(sentinel != erc721OutTokenId);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](2);
            erc721Transfers[0] =
                ERC721Transfer({token: address(iTokenA), from: addressA, to: addressB, id: erc721InTokenId});
            erc721Transfers[1] =
                ERC721Transfer({token: address(iTokenB), from: addressB, to: addressA, id: erc721OutTokenId});
            transfer = FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0));
        }
    }

    function mockTransferERC721ToERC721(
        address addressA,
        address addressB,
        uint256 erc721InTokenId,
        uint256 erc721OutTokenId
    ) internal {
        vm.mockCall(iTokenA, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenA,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), addressA, addressB, erc721InTokenId
            )
        );

        vm.mockCall(iTokenB, abi.encodeWithSelector(bytes4(keccak256("safeTransferFrom(address,address,uint256)"))), "");
        vm.expectCall(
            iTokenB,
            abi.encodeWithSelector(
                bytes4(keccak256("safeTransferFrom(address,address,uint256)")), addressB, addressA, erc721OutTokenId
            )
        );
    }

    function transfersERC20toERC20(address addressA, address addressB, uint256 erc20BInAmount, uint256 erc20OutAmount)
        internal
        returns (FlowTransferV1 memory transfer)
    {
        transfer = createTransfersERC20toERC20(addressA, addressB, erc20BInAmount, erc20OutAmount);
        mockTransfersERC20toERC20(addressA, addressB, erc20BInAmount, erc20OutAmount);
    }

    function createTransfersERC20toERC20(
        address addressA,
        address addressB,
        uint256 erc20BInAmount,
        uint256 erc20OutAmount
    ) internal view returns (FlowTransferV1 memory transfer) {
        {
            vm.assume(sentinel != erc20BInAmount);
            vm.assume(sentinel != erc20OutAmount);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](2);
            erc20Transfers[0] =
                ERC20Transfer({token: address(iTokenA), from: addressA, to: addressB, amount: erc20BInAmount});
            erc20Transfers[1] =
                ERC20Transfer({token: address(iTokenB), from: addressB, to: addressA, amount: erc20OutAmount});
            transfer = FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0));
        }
    }

    function mockTransfersERC20toERC20(
        address addressA,
        address addressB,
        uint256 erc20BInAmount,
        uint256 erc20OutAmount
    ) internal {
        vm.mockCall(address(iTokenA), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.expectCall(
            address(iTokenA), abi.encodeWithSelector(IERC20.transferFrom.selector, addressA, addressB, erc20BInAmount)
        );

        vm.mockCall(address(iTokenB), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        vm.expectCall(address(iTokenB), abi.encodeWithSelector(IERC20.transfer.selector, addressA, erc20OutAmount));
    }

    function transferERC1155ToERC1155(
        address addressA,
        address addressB,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmount,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) internal returns (FlowTransferV1 memory transfer) {
        transfer = createTransferERC1155ToERC1155(
            addressA, addressB, erc1155BInTokenId, erc1155BInAmount, erc1155OutTokenId, erc1155OutAmount
        );
        MockTransferERC1155ToERC1155(
            addressA, addressB, erc1155BInTokenId, erc1155BInAmount, erc1155OutTokenId, erc1155OutAmount
        );
    }

    function createTransferERC1155ToERC1155(
        address addressA,
        address addressB,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmount,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) internal view returns (FlowTransferV1 memory transfer) {
        {
            vm.assume(sentinel != erc1155OutTokenId);
            vm.assume(sentinel != erc1155OutAmount);
            vm.assume(sentinel != erc1155BInTokenId);
            vm.assume(sentinel != erc1155BInAmount);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](2);

            erc1155Transfers[0] = ERC1155Transfer({
                token: address(iTokenA),
                from: addressA,
                to: addressB,
                id: erc1155BInTokenId,
                amount: erc1155BInAmount
            });

            erc1155Transfers[1] = ERC1155Transfer({
                token: address(iTokenB),
                from: addressB,
                to: addressA,
                id: erc1155OutTokenId,
                amount: erc1155OutAmount
            });

            transfer = FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers);
        }
    }

    function MockTransferERC1155ToERC1155(
        address addressA,
        address addressB,
        uint256 erc1155BInTokenId,
        uint256 erc1155BInAmount,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) internal {
        {
            vm.mockCall(iTokenA, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
            vm.expectCall(
                iTokenA,
                abi.encodeWithSelector(
                    IERC1155.safeTransferFrom.selector, addressA, addressB, erc1155BInTokenId, erc1155BInAmount, ""
                )
            );

            vm.mockCall(iTokenB, abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), "");
            vm.expectCall(
                iTokenB,
                abi.encodeWithSelector(
                    IERC1155.safeTransferFrom.selector, addressB, addressA, erc1155OutTokenId, erc1155OutAmount, ""
                )
            );
        }
    }

    function multiTransfersERC20(address addressA, address addressB, uint256 erc20AmountA, uint256 erc20AmountB)
        internal
        view
        returns (FlowTransferV1 memory transfer)
    {
        {
            vm.assume(sentinel != erc20AmountA);
            vm.assume(sentinel != erc20AmountB);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC20Transfer[] memory erc20Transfers = new ERC20Transfer[](4);
            erc20Transfers[0] =
                ERC20Transfer({token: address(iTokenA), from: address(addressB), to: addressA, amount: erc20AmountA});
            erc20Transfers[1] =
                ERC20Transfer({token: address(iTokenB), from: address(addressB), to: addressA, amount: erc20AmountB});
            erc20Transfers[2] =
                ERC20Transfer({token: address(iTokenA), from: addressA, to: address(addressB), amount: erc20AmountA});
            erc20Transfers[3] =
                ERC20Transfer({token: address(iTokenB), from: addressA, to: address(addressB), amount: erc20AmountB});
            transfer = FlowTransferV1(erc20Transfers, new ERC721Transfer[](0), new ERC1155Transfer[](0));
        }
    }

    function multiTransferERC721(address addressA, address addressB, uint256 erc721TokenIdA, uint256 erc721TokenIdB)
        internal
        view
        returns (FlowTransferV1 memory transfer)
    {
        {
            vm.assume(sentinel != erc721TokenIdA);
            vm.assume(sentinel != erc721TokenIdB);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC721Transfer[] memory erc721Transfers = new ERC721Transfer[](4);
            erc721Transfers[0] = ERC721Transfer({token: iTokenA, from: addressB, to: addressA, id: erc721TokenIdA});
            erc721Transfers[1] = ERC721Transfer({token: iTokenB, from: addressB, to: addressA, id: erc721TokenIdB});
            erc721Transfers[2] = ERC721Transfer({token: iTokenA, from: addressA, to: addressB, id: erc721TokenIdA});
            erc721Transfers[3] = ERC721Transfer({token: iTokenB, from: addressA, to: addressB, id: erc721TokenIdB});
            transfer = FlowTransferV1(new ERC20Transfer[](0), erc721Transfers, new ERC1155Transfer[](0));
        }
    }

    function multiTransferERC1155(
        address addressA,
        address addressB,
        uint256 erc1155InTokenId,
        uint256 erc1155InAmount,
        uint256 erc1155OutTokenId,
        uint256 erc1155OutAmount
    ) internal view returns (FlowTransferV1 memory transfer) {
        {
            vm.assume(sentinel != erc1155OutTokenId);
            vm.assume(sentinel != erc1155OutAmount);
            vm.assume(sentinel != erc1155InTokenId);
            vm.assume(sentinel != erc1155InAmount);
            assumeAddressNotSentinel(addressA);
            assumeAddressNotSentinel(addressB);
        }

        {
            ERC1155Transfer[] memory erc1155Transfers = new ERC1155Transfer[](4);

            erc1155Transfers[0] = ERC1155Transfer({
                token: address(iTokenA),
                from: addressB,
                to: addressA,
                id: erc1155OutTokenId,
                amount: erc1155OutAmount
            });

            erc1155Transfers[1] = ERC1155Transfer({
                token: address(iTokenB),
                from: addressB,
                to: addressA,
                id: erc1155InTokenId,
                amount: erc1155InAmount
            });

            erc1155Transfers[2] = ERC1155Transfer({
                token: address(iTokenA),
                from: addressA,
                to: addressB,
                id: erc1155OutTokenId,
                amount: erc1155OutAmount
            });

            erc1155Transfers[3] = ERC1155Transfer({
                token: address(iTokenB),
                from: addressA,
                to: addressB,
                id: erc1155InTokenId,
                amount: erc1155InAmount
            });

            transfer = FlowTransferV1(new ERC20Transfer[](0), new ERC721Transfer[](0), erc1155Transfers);
        }
    }

    function assumeAddressNotSentinel(address inputAddress) internal view {
        vm.assume(sentinel != uint256(uint160(inputAddress)));
    }
}
