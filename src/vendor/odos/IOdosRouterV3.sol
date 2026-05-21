// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IOdosRouterV3 {
    struct swapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }

    struct swapReferralInfo {
        uint64 code;
        uint64 fee;
        address feeRecipient;
    }

    /// @notice Externally facing interface for swapping two tokens
    /// @param tokenInfo All information about the tokens being swapped
    /// @param pathDefinition Encoded path definition for executor
    /// @param executor Address of contract that will execute the path
    /// @param referralInfo Referral fee configuration with code, fee amount, and recipient
    function swap(
        swapTokenInfo memory tokenInfo,
        bytes calldata pathDefinition,
        address executor,
        swapReferralInfo memory referralInfo
    )
        external
        payable
        returns (uint256 amountOut);
}
