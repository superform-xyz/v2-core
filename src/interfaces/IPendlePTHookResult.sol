// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IPendlePTHookResult
/// @author Superform Labs
/// @notice Context-aware result interface exposing BOTH sides of a completed PendlePTHook trade.
/// @dev The generic `ISuperHookResult` only exposes a hook's output (amount + token), which is correct
///      for a PT purchase (output == PT) but structurally wrong for a PT sale/redemption (output == the
///      asset received; PT is the INPUT). This interface lets a following record hook read the actual
///      PT amount for either direction from real execution balance deltas.
interface IPendlePTHookResult {
    /// @notice The operation a PendlePTHook execution performed.
    /// @dev NONE indicates no trade was recorded for the queried account in the current execution
    ///      (empty/stale context) — record hooks MUST reject it.
    enum Operation {
        NONE,
        BUY_PT,
        SELL_PT,
        REDEEM_PT
    }

    /// @notice Both sides of the completed PT trade, populated from actual balance deltas.
    /// @param operation The operation performed (BUY_PT / SELL_PT / REDEEM_PT), or NONE if unset.
    /// @param market The Pendle market (yieldSource) the trade executed against.
    /// @param inputToken The token spent (PT for SELL_PT/REDEEM_PT; the asset for BUY_PT).
    /// @param outputToken The token received (PT for BUY_PT; the asset for SELL_PT/REDEEM_PT).
    /// @param inputAmount The actual amount of `inputToken` spent (balanceBefore - balanceAfter).
    /// @param outputAmount The actual amount of `outputToken` received (balanceAfter - balanceBefore).
    struct TradeResult {
        Operation operation;
        address market;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
    }

    /// @notice Returns the completed PT trade for `account` in the current execution context.
    /// @dev Populated in the producing hook's postExecute from actual balance deltas and held in
    ///      transient, account-keyed storage — it is wiped at end of tx and never leaks across
    ///      accounts. `operation == NONE` means no trade was recorded this execution.
    /// @param account The account the trade was executed for.
    /// @return result The trade result (operation + input/output token + input/output amount).
    function getPendleTradeResult(address account) external view returns (TradeResult memory result);
}
