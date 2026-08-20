// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IHyperCoreDepositGateway
/// @author Superform Labs
/// @notice Per-token deposit gateway that credits an EVM sender's HyperCore spot balance
/// @dev The address returned by the HyperCore `tokenInfo` precompile as `evmContract` is this
///      gateway, NOT the ERC-20. Its `transfer` reverts with "Caller is not the system address" and
///      it implements none of the ERC-20 view methods. Read the token address from configuration,
///      never from the precompile.
/// @dev Gateways are per-token: USDC, PURR, HFUN, UBTC and MUX each have a distinct address, so the
///      gateway already knows which token it credits.
/// @dev This deposit path is undocumented by Hyperliquid — the published mechanism is a plain ERC-20
///      transfer to the `0x20…` system address. The gateway path is verified working on mainnet
///      (credited in ~1s, 74,942 gas for approve + deposit) but carries no documentation guarantee.
interface IHyperCoreDepositGateway {
    /// @notice Deposits `amount` of the gateway's token, crediting msg.sender's HyperCore spot balance
    /// @dev Selector 0x2b2dfd2c. Credits msg.sender; there is no recipient-taking overload.
    /// @param amount Token amount in EVM decimals
    /// @param arg Undocumented uint32. Every observed mainnet call passes 0, and it is NOT a token
    ///        index (gateways are per-token). Supplied by the hook as a deployment immutable.
    function deposit(uint256 amount, uint32 arg) external;
}
