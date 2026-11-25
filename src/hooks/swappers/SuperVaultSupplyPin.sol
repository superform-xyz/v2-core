// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISuperVaultStrategyVault } from "../../interfaces/ISuperVaultStrategyState.sol";

/// @title SuperVaultSupplyPin
/// @author Superform Labs
/// @notice Pins the executing account's SuperVault share supply across a swap leg (SUP-21772).
/// @dev WHY. The aggregator swap hooks measure their output as the account's balance delta of the output
///      token. When the account is a SuperVault STRATEGY, any contract the route reaches can call
///      `SuperVault.deposit(x, attacker)` on that vault mid-swap: the vault forwards `x` to the strategy and
///      pays the depositor in shares, so the delta clears the floor while the input leg was never paid for.
///      The strategy's `executeHooks` lock does not cover that path (the deposit handler only checks that the
///      vault is calling). Deposits and mints are the only flows that put asset into the strategy with a claim
///      attached, and both move the vault's `totalSupply`: pinning it in `_preExecute` and re-checking it in
///      `_postExecute` closes the gap without changing the swap flow, the data layout or the leaves.
/// @dev NO-OP FOR PLAIN ACCOUNTS. An account that does not expose `getVaultInfo()` (an ERC-7579 smart account
///      on the 4337 path) commits to zero both times, so the app path is untouched. Shape adapted from
///      `GyldTradePolicy.accountStateCommitment` / `ApproveAndTradeGyldBondHook`, with a raw staticcall so that
///      short or empty return data cannot brick a leg. Two cases still fail the leg, by design: 96 bytes that do not
///      decode as (address, address, uint8), and a named vault that cannot answer `totalSupply()`. Only the account
///      itself can produce either, and a real strategy produces neither.
/// @dev TAMPER RESISTANCE. The slot is keyed by `account` in this contract's transient storage; the only writers
///      are `preExecute` / `postExecute`, which BaseHook restricts to `msg.sender == account`. A route calling
///      the unpermissioned `setExecutionContext` mid-swap does not touch the slot, and the commitment is
///      re-derived in post, so the comparison still fires.
abstract contract SuperVaultSupplyPin {
    /// @notice The SuperVault share supply read in `_preExecute` differs in `_postExecute`: a route minted or
    ///         burned vault shares mid-swap (`SuperVault.deposit` / `mint` forward cash to the strategy), so the
    ///         measured output delta no longer describes this swap
    error SUPERVAULT_SUPPLY_CHANGED_DURING_SWAP();

    bytes32 private constant SUPPLY_PIN_NAMESPACE = keccak256("superform.supervault.supplyPin.transient.v1");

    /// @dev Call first in `_preExecute`
    function _pinVaultSupply(address account) internal {
        bytes32 key = _supplyPinKey(account);
        bytes32 commitment = _vaultSupplyCommitment(account);
        assembly ("memory-safe") {
            tstore(key, commitment)
        }
    }

    /// @dev Call first in `_postExecute`, before the measured delta is trusted
    function _requireVaultSupplyUnchanged(address account) internal {
        bytes32 key = _supplyPinKey(account);
        bytes32 pinned;
        assembly ("memory-safe") {
            pinned := tload(key)
        }
        if (_vaultSupplyCommitment(account) != pinned) revert SUPERVAULT_SUPPLY_CHANGED_DURING_SWAP();
        assembly ("memory-safe") {
            tstore(key, 0)
        }
    }

    /// @dev keccak(vault, totalSupply) for a SuperVault strategy, zero for anything else. A raw staticcall rather
    ///      than try/catch: a revert (Nexus / Safe7579 reject the unknown selector), empty or short return data
    ///      (a permissive fallback) all read as "not a SuperVault strategy" instead of an uncatchable decode failure.
    ///      A strategy that names a vault is held to it: a vault that cannot answer `totalSupply()` fails the leg.
    function _vaultSupplyCommitment(address account) private view returns (bytes32) {
        if (account.code.length == 0) return bytes32(0);
        (bool ok, bytes memory ret) = account.staticcall(abi.encodeCall(ISuperVaultStrategyVault.getVaultInfo, ()));
        if (!ok || ret.length != 96) return bytes32(0);
        (address vault,,) = abi.decode(ret, (address, address, uint8));
        if (vault == address(0)) return bytes32(0);
        return keccak256(abi.encode(vault, IERC20(vault).totalSupply()));
    }

    function _supplyPinKey(address account) private pure returns (bytes32) {
        return keccak256(abi.encode(SUPPLY_PIN_NAMESPACE, account));
    }
}
