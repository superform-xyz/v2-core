// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @dev  Struct representing an order.
struct Order {
    /// Nonce for each maker.
    uint64 makerOrderNonce;
    /// Order maker address (EOA signer for EVM) in the source chain.
    bytes makerSrc;
    /// Chain ID where the order's was created.
    uint256 giveChainId;
    /// Address of the ERC-20 token that the maker is offering as part of this order.
    /// Use the zero address to indicate that the maker is offering a native blockchain token (such as Ether, Matic,
    /// etc.).
    bytes giveTokenAddress;
    /// Amount of tokens the maker is offering.
    uint256 giveAmount;
    // the ID of the chain where an order should be fulfilled.
    uint256 takeChainId;
    /// Address of the ERC-20 token that the maker is willing to accept on the destination chain.
    bytes takeTokenAddress;
    /// Amount of tokens the maker is willing to accept on the destination chain.
    uint256 takeAmount;
    /// Address on the destination chain where funds should be sent upon order fulfillment.
    bytes receiverDst;
    /// Address on the source (current) chain authorized to patch the order by adding more input tokens, making it more
    /// attractive to takers.
    bytes givePatchAuthoritySrc;
    /// Address on the destination chain authorized to patch the order by reducing the take amount, making it more
    /// attractive to takers,
    /// and can also cancel the order in the take chain.
    bytes orderAuthorityAddressDst;
    // An optional address restricting anyone in the open market from fulfilling
    // this order but the given address. This can be useful if you are creating a order
    // for a specific taker. By default, set to empty bytes array (0x)
    bytes allowedTakerDst;
    // An optional address on the source (current) chain where the given input tokens
    // would be transferred to in case order cancellation is initiated by the orderAuthorityAddressDst
    // on the destination chain. This property can be safely set to an empty bytes array (0x):
    // in this case, tokens would be transferred to the arbitrary address specified
    // by the orderAuthorityAddressDst upon order cancellation
    bytes allowedCancelBeneficiarySrc;
    /// An optional external call data payload.
    bytes externalCall;
}

interface IDlnDestination {
    function fulfillOrder(
        Order memory _order,
        uint256 _fulFillAmount,
        bytes32 _orderId,
        bytes calldata _permitEnvelope,
        address _unlockAuthority,
        address _externalCallRewardBeneficiary
    )
        external
        payable;

    function externalCallAdapter() external view returns (address);

    /// @dev Send cancel order in [`Order::give::chain_id`]
    ///
    /// If the order was not filled or canceled earlier, [`Order::order_authority_address_dst`] can cancel it and get back the give part in [`Order::give::chain_id`] chain
    /// In the receive chain, the [`dln::source::claim_order_cancel`] will be called
    ///
    /// @param _order Full order for patch
    /// @param _cancelBeneficiary address that will receive refund in give chain chain
    ///     * If [`Order::allowed_cancel_beneficiary`] is None then any [`Address`]
    ///     * If [`Order::allowed_cancel_beneficiary`] is Some then only itself
    /// @param _executionFee execution fee for auto claim by keepers
    /// # Allowed
    /// By [`Order::order_authority_address_dst`] only
    function sendEvmOrderCancel(
        Order memory _order,
        address _cancelBeneficiary,
        uint256 _executionFee
    ) external payable;
}
