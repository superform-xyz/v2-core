// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface IBridgeValidator {
    /// @notice Validate the request data
    /// @dev Used inside modules to validate the order data
    /// @param txData_ The order data
    /// @param account_ The account
    function validateBridgeOperation(bytes memory txData_, address account_) external view;
    /// @notice Validate the receiver
    /// @param txData_ The order data
    /// @param receiver_ The receiver
    function validateReceiver(bytes memory txData_, address receiver_) external view;
}
