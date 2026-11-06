// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IGyldTradePolicy
/// @author Superform Labs
/// @notice The tradability facade `ApproveAndTradeGyldBondHook` consults from inside its own execution.
/// @dev DELIBERATELY GENERIC AND GYLD-FREE IN SHAPE. The hook pins one implementation address in an
///      immutable and knows nothing about registries, oracles, feeds or the aggregator. Everything
///      Gyld-specific lives behind this boundary, which is what lets the trade hook stay a plain swap hook
///      and keeps the registry dependency out of its import graph.
/// @dev WHY THIS EXISTS (review finding F1). The guard hook could not be bound to the trade it accompanied:
///      `SuperVaultStrategy.executeHooks` authorises each Merkle leaf independently and nothing recorded
///      that a guard had run, so a manager leaf could omit the guard entirely, or guard a healthy bond while
///      trading a suspended one. Moving the checks behind this interface and calling them from the trade
///      hook's own `preExecute`/`postExecute` makes them unavoidable: `BaseHook.build` always emits those two
///      executions and `BaseHook` reverts `INCOMPLETE_HOOK_EXECUTION` unless both ran.
interface IGyldTradePolicy {
    /// @notice Which side of the instrument a hook instance is allowed to be
    /// @dev BUY  = cash in, bond out (the `cash-in` deploy key)
    ///      SELL = bond in, cash out (the `bond-in` deploy key)
    enum TradeSide {
        BUY,
        SELL
    }

    /// @notice Observed outcome of one trade leg, measured rather than declared
    /// @param account The executing account; the SuperVault strategy itself on the manager path
    /// @param side The hook instance's immutable side, asserted against the token pair
    /// @param inputToken Header `inputToken`, the token being spent
    /// @param outputToken Header `outputToken`, the token being received
    /// @param inputSpent Observed decrease in `inputToken` balance across the leg
    /// @param received Observed increase in `outputToken` balance across the leg
    struct FillArgs {
        address account;
        TradeSide side;
        address inputToken;
        address outputToken;
        uint256 inputSpent;
        uint256 received;
    }

    /// @notice Eligibility gate. MUST revert if this trade must not proceed.
    /// @dev Called from the hook's `_preExecute`, before any allowance is granted.
    /// @param account The executing account. Needed for the strategy pause / PPS reads, which are keyed by
    ///        strategy address, and for nothing else.
    /// @param side The calling hook's immutable side. Passed in rather than read back from the hook, so the
    ///        policy never has to know the hook's storage layout or trust a getter.
    /// @param inputToken Header `inputToken`, already decoded and length-checked by the hook, so the policy
    ///        carries no knowledge of `SwapCalldataLayout`.
    /// @param outputToken Header `outputToken`, same reasoning.
    /// @param data The hook's full calldata, forwarded verbatim and UNUSED by this version. Present so a
    ///        later policy can inspect the venue payload WITHOUT changing this interface — which matters
    ///        because the policy address is an immutable of the hook, so an interface change costs a hook
    ///        redeploy, two fresh CREATE2 addresses and a Merkle root re-sign.
    function validateTrade(
        address account,
        TradeSide side,
        address inputToken,
        address outputToken,
        bytes calldata data
    )
        external
        view;

    /// @notice Outcome gate. MUST revert if the realised fill is outside policy.
    /// @dev Called from the hook's `_postExecute` with OBSERVED balance deltas, never with declared header
    ///      amounts. This is where the price floor has teeth: the header `inputAmount` is an allowance
    ///      ceiling rather than the spend, so a floor derived from it would reject honest trades whenever a
    ///      venue spends less than authorised. Flooring against measured amounts has no such failure mode,
    ///      and it is the only sound place to check the declared side against actual token flow.
    function validateFill(FillArgs calldata args) external view;

    /// @notice A commitment to the account's vault share supply, for pinning across one trade leg.
    /// @dev R4-1. `validateFill` compares MEASURED balance deltas, and those can be faked: a mid-leg
    ///      `SuperVault.deposit` sends the asset straight to the strategy and pays the depositor in shares,
    ///      so a venue can hand back the cash it just pulled and collapse the measured `inputSpent` to
    ///      ~zero, or satisfy `received` with its own cash and take it back as shares. The strategy's
    ///      `nonReentrant` is on `executeHooks`; the vault's is on the vault, so it does not block this.
    /// @dev Deposits and mints are the only paths that put asset into the strategy AND PAY THE SENDER, and
    ///      both move share supply. The "and pay the sender" half is load-bearing: `SuperVault.withdraw`
    ///      and `redeem` accept an arbitrary receiver, so a controller CAN push asset into the strategy
    ///      without moving supply — but that spends their own `maxWithdraw`, making it an uncompensated
    ///      donation, and a donation cannot beat the floor (it is arithmetically identical to trading
    ///      less). Do not relax this invariant to "any inflow"; it is specifically compensated inflow. Burns cannot
    /// happen mid-leg: `SuperVault.burnShares` is strategy-only and is reached through the `nonReentrant`
    /// `fulfillRedeemRequests`. So supply is a sound
    ///      per-leg invariant.
    /// @return A value that MUST be identical before and after the leg, or `bytes32(0)` when the account
    ///         has no vault to commit (a plain smart account rather than a SuperVault strategy).
    function accountStateCommitment(address account) external view returns (bytes32);

    /// @notice Pre-flight for the off-chain order manager. Zero means `validateTrade` would pass.
    /// @dev NOT UNCONDITIONALLY NON-REVERTING, despite what this said before. An implementation is expected
    ///      to absorb an unregistered instrument and an unregistered strategy, and this one does. It may
    ///      still revert when a DEPENDENCY reverts: a NAV, cash or sequencer feed that throws rather than
    ///      returning a bad value, an aggregator that reverts on the pause/staleness reads, or an
    ///      aggregator address that has become codeless (a call there succeeds with empty returndata, which
    ///      Solidity can neither decode nor catch). Callers must tolerate a revert; treat one as "unknown",
    ///      not as "eligible".
    /// @dev Precedent: `GyldTradeGuardHook.previewTradable`, `MorphoHealthCheckHook.previewHealthFactor`.
    /// @return reasonCode 0 when eligible, otherwise the first failing condition's code
    function previewTrade(
        address account,
        TradeSide side,
        address inputToken,
        address outputToken
    )
        external
        view
        returns (uint256 reasonCode);
}
