// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {IERC5313Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC5313Upgradeable.sol";
import {
    RAIN_FLOW_SENTINEL,
    FLOW_ERC721_MIN_FLOW_SENTINELS,
    FLOW_ERC721_HANDLE_TRANSFER_MAX_OUTPUTS,
    FLOW_ERC721_HANDLE_TRANSFER_MIN_OUTPUTS,
    FLOW_ERC721_TOKEN_URI_MAX_OUTPUTS,
    FLOW_ERC721_TOKEN_URI_MIN_OUTPUTS,
    ERC721SupplyChange,
    FlowERC721IOV1
} from "../IFlowERC721V4.sol";
import {EvaluableV2, EvaluableConfigV3, SignedContextV1, SourceIndexV2} from "./IFlowV5.sol";

/// @dev Entrypont of the `handleTransfer` evaluation.
SourceIndexV2 constant FLOW_ERC721_HANDLE_TRANSFER_ENTRYPOINT = SourceIndexV2.wrap(0);
/// @dev Entrypont of the `tokenURI` evaluation.
SourceIndexV2 constant FLOW_ERC721_TOKEN_URI_ENTRYPOINT = SourceIndexV2.wrap(1);

/// Initialization config.
/// @param name As per Open Zeppelin `ERC721Upgradeable`.
/// @param symbol As per Open Zeppelin `ERC721Upgradeable`.
/// @param baseURI As per Open Zeppelin `ERC721Upgradeable`.
/// @param initialOwner The initial owner of the contract. MAY be transferred
/// by the owner later by calling `transferOwnership`.
/// @param evaluableConfig The `EvaluableConfigV2` to use to build the
/// `evaluable` that can be used to handle transfers and build token IDs for the
/// token URI.
/// @param flowConfig Initialization config for the `Evaluable`s that define the
/// flow behaviours outside self mints/burns.
struct FlowERC721ConfigV3 {
    string name;
    string symbol;
    string baseURI;
    address initialOwner;
    EvaluableConfigV3 evaluableConfig;
    EvaluableConfigV3[] flowConfig;
}

/// @title IFlowERC721V5
/// Conceptually identical to `IFlowV4`, but the flow contract itself is an
/// ERC721 token. This means that ERC721 self mints and burns are included in the
/// stack that the flows must evaluate to. As stacks are processed by flow from
/// bottom to top, this means that the self mint/burn will be the last thing
/// evaluated, with mints at the bottom and burns next, followed by the flows.
///
/// As the flow is an ERC721 token it also includes an evaluation to be run on
/// every token transfer. This is the `handleTransfer` entrypoint. The return
/// stack of this evaluation is ignored, but reverts MUST be respected. This
/// allows expression authors to prevent transfers from occurring if they don't
/// want them to, by reverting within the expression.
///
/// The flow contract also includes an evaluation to be run on every token URI
/// request. This is the `tokenURI` entrypoint. The return value of this
/// evaluation is the token ID to use for the token URI. This entryoint is
/// optional, and if not provided the token URI will be the default Open Zeppelin
/// token URI logic.
///
/// The `IFlowERC721V5` contract is identical to `IFlowERC721V4` except that it
/// includes an owner in the initialization and MUST be ERC5313 compatible. The
/// owner MAY NOT have any special privileges onchain, but is often used to
/// provide offchain access to the contract for administrative purposes, such as
/// on centralised NFT marketplaces.
///
/// Otherwise the flow contract is identical to `IFlowV4`.
interface IFlowERC721V5 is IERC5313Upgradeable {
    /// Contract has initialized.
    /// @param sender `msg.sender` initializing the contract (factory).
    /// @param config All initialized config.
    event Initialize(address sender, FlowERC721ConfigV3 config);

    /// As per `IFlowV4` but returns a `FlowERC721IOV1` instead of a
    /// `FlowTransferV1`.
    function stackToFlow(uint256[] memory stack) external pure returns (FlowERC721IOV1 memory flowERC721IO);

    /// As per `IFlowV4` but returns a `FlowERC721IOV1` instead of a
    /// `FlowTransferV1` and mints/burns itself as an ERC721 accordingly.
    /// @param evaluable The `Evaluable` to use to evaluate the flow.
    /// @param callerContext The caller context to use to evaluate the flow.
    /// @param signedContexts The signed contexts to use to evaluate the flow.
    /// @return flowERC721IO The `FlowERC721IOV1` representing all token
    /// mint/burns and transfers that occurred during the flow.
    function flow(
        EvaluableV2 calldata evaluable,
        uint256[] calldata callerContext,
        SignedContextV1[] calldata signedContexts
    ) external returns (FlowERC721IOV1 calldata flowERC721IO);
}
