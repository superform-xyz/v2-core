// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IRecoverable {
    /// @notice Used to recover any ERC-20 token.
    /// @dev    This method is called only by authorized entities
    /// @param  token It could be 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
    ///         to recover locked native ETH or any ERC20 compatible token.
    /// @param  to Receiver of the funds
    /// @param  amount Amount to send to the receiver.
    function recoverTokens(address token, address to, uint256 amount) external;
}
