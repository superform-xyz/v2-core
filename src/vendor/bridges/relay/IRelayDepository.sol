// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IRelayDepository
/// @notice Minimal interface for Relay Protocol's RelayDepository (origin-side escrow deposits)
/// @dev Source: github.com/relayprotocol/relay-depository packages/ethereum-vm/src/RelayDepository.sol
/// @dev Deposits only emit events — the depository records no per-deposit state on-chain.
///      Deposit → fill → refund correlation happens off-chain via the `id` (Relay quote orderId).
/// @dev The full-allowance depositErc20 overload is intentionally excluded — explicit amounts only.
interface IRelayDepository {
    /// @notice Emitted on a native deposit
    event RelayNativeDeposit(address from, uint256 amount, bytes32 id);

    /// @notice Emitted on an ERC20 deposit
    event RelayErc20Deposit(address from, address token, uint256 amount, bytes32 id);

    /// @notice Deposit native tokens, credited to `depositor` under order `id`
    /// @param depositor The address credited with the deposit (address(0) credits msg.sender)
    /// @param id The Relay order id from the quote API (protocol.v2.orderId)
    function depositNative(address depositor, bytes32 id) external payable;

    /// @notice Deposit ERC20 tokens (pulled from msg.sender via transferFrom), credited to `depositor` under `id`
    /// @param depositor The address credited with the deposit
    /// @param token The ERC20 token to deposit
    /// @param amount The amount to deposit (requires prior approval to the depository)
    /// @param id The Relay order id from the quote API (protocol.v2.orderId)
    function depositErc20(address depositor, address token, uint256 amount, bytes32 id) external;

    /// @notice The allocator authorized to sign withdrawal/fill requests
    function allocator() external view returns (address);
}
