// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IOFT
/// @notice Interface for LayerZero V2 OFT (Omnichain Fungible Token) contracts
/// @dev Used by StargateSendHook and ApproveAndStargateSendHook in OFT mode (mode=2)
/// @dev Both OFT and OFTAdapter implement this interface. OFT burns tokens from the caller;
///      OFTAdapter locks tokens via transferFrom (requires approval).
/// @dev Reference: https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/interfaces/IOFT.sol
interface IOFT {
    /// @notice Parameters for sending tokens cross-chain (identical layout to IStargate.SendParam)
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

    /// @notice Send tokens cross-chain via LayerZero V2
    /// @param _sendParam The send parameters
    /// @param _fee The messaging fee
    /// @param _refundAddress Address to refund excess native fee
    /// @return msgReceipt The messaging receipt
    /// @return oftReceipt The OFT receipt with actual amounts
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);

    /// @notice Get the underlying token address
    /// @return For OFT: address(this). For OFTAdapter: underlying ERC20 address.
    /// @dev Selector 0xfc0c546a - identical to IStargate.token()
    function token() external view returns (address);
}
