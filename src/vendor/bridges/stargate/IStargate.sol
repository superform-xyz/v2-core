// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

/// @title IStargate
/// @notice Interface for Stargate V2 pool contracts (per-token pools implementing OFT pattern)
/// @dev Each token has its own Stargate pool contract (e.g., StargatePoolUSDC, StargatePoolETH)
interface IStargate {
    /// @notice Parameters for sending tokens cross-chain
    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    /// @notice Fee structure for LayerZero V2 messaging
    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    /// @notice Receipt from LayerZero V2 messaging
    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    /// @notice Receipt from OFT send operation
    struct OFTReceipt {
        uint256 amountSentLD;
        uint256 amountReceivedLD;
    }

    /// @notice Send tokens cross-chain via Stargate/LayerZero V2
    /// @param _sendParam The send parameters
    /// @param _fee The messaging fee
    /// @param _refundAddress Address to refund excess native fee
    /// @return msgReceipt The messaging receipt
    /// @return oftReceipt The OFT receipt with actual amounts
    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);

    /// @notice Quote the messaging fee for a send operation
    /// @param _sendParam The send parameters
    /// @param _payInLzToken Whether to pay in LZ token
    /// @return fee The estimated messaging fee
    function quoteSend(SendParam calldata _sendParam, bool _payInLzToken)
        external
        view
        returns (MessagingFee memory fee);

    /// @notice Get the underlying token address for this pool
    /// @return The ERC20 token address (or address(0) for native pools)
    function token() external view returns (address);
}
