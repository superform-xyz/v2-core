// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IHyperCoreDepositGateway
/// @author Superform Labs
/// @notice Per-token gateway that moves an EVM balance into a HyperCore account
/// @dev The address returned by the HyperCore `tokenInfo` precompile as `evmContract` is this
///      gateway, NOT the ERC-20. Its `transfer` reverts with "Caller is not the system address" and
///      it implements none of the ERC-20 view methods. Read the token address from configuration,
///      never from the precompile.
/// @dev Gateways are per-token: USDC, PURR, HFUN, UBTC and MUX each have a distinct address, so the
///      gateway already knows which token it credits.
/// @dev Internally the gateway calls CoreWriter itself (`sendRawAction` is present in its
///      implementation) and emits action 13 `sendAsset`, forwarding `destinationDex` straight
///      through. Every one of 1,712 sampled mainnet emissions carries
///      `(subAccount 0, sourceDex uint32::MAX, destinationDex 0)` — gateway spot to the depositor's
///      perp account.
/// @dev Hyperliquid's docs for action 13: "Specify uint32::MAX for the source_dex or destination_dex
///      for spot." So `0` is perp dex 0, not spot.
interface IHyperCoreDepositGateway {
    /// @notice Deposits `amount` of the gateway's token, crediting msg.sender on HyperCore
    /// @dev Selector 0x2b2dfd2c.
    /// @param amount Token amount in EVM decimals
    /// @param destinationDex Which HyperCore balance to credit: `0` is perp dex 0 (perp margin),
    ///        `type(uint32).max` is spot. Forwarded verbatim to CoreWriter action 13.
    function deposit(uint256 amount, uint32 destinationDex) external;

    /// @notice Deposits on behalf of `recipient`, pulling the tokens from msg.sender
    /// @dev Selector 0xc23c545a, present in the implementation and permissionless — the token pull
    ///      is reached without an auth check. NOT used by the hook: crediting msg.sender means there
    ///      is no recipient parameter to validate and equally none to abuse. Declared so the
    ///      capability is on the record, since it is what allows a backend to pre-activate an
    ///      account's HyperCore side without a UserOp.
    function depositFor(address recipient, uint256 amount, uint32 destinationDex) external;
}
