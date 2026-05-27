# rFLR Claiming Hook - Interview Notes

**Date:** 2026-05-14
**Feature:** rFLR claiming hook for Superform V2

## Summary

Build two NONACCOUNTING hooks for claiming and withdrawing rFLR rewards on Flare mainnet (chain 14):
1. **ClaimRFLRHook** — wraps `IRNat.claimRewards(projectIds, month)` with fee handling
2. **WithdrawRFLRHook** — wraps `IRNat.withdrawAll(wrap=true)` to convert rFLR → WFLR

## Technical Decisions

### Operations
- **Two separate hooks** (Claim + Withdraw), not a combined single hook
- Claim hook: `claimRewards(uint256[] projectIds, uint256 month)`
- Withdraw hook: `withdrawAll(bool wrap)` with `wrap=true` always

### Chain Target
- Flare mainnet only (chain ID 14)
- Deploy alongside existing Firelight hooks

### Hook Type
- Both hooks use **NONACCOUNTING** pattern (like MerklClaimRewardHook)
- Tracks reward/balance deltas via `_preExecute`/`_postExecute` balance snapshots

### Claim Parameters
- Project IDs and month **encoded in hook data** (not auto-detected)
- Caller provides `uint256[] projectIds` and `uint256 month` in the data bytes
- Requires off-chain knowledge of claimable projects

### Fee Handling
- **Yes** — same pattern as MerklClaimRewardHook
- `feeBPS` and `feeReceiver` encoded in hook data
- `MAX_FEE_BPS = 5000` (50% cap)
- Fee taken from claimed rFLR rewards

### Withdraw Mode
- **Always `withdrawAll`** with `wrap=true`
- No partial withdrawal support needed
- Output is always WFLR (ERC20), not native FLR
- Simpler for smart account handling

### Wrap Option
- Always wrap to WFLR — smart accounts handle ERC20 more easily than native tokens

## Key External Contracts

### IRNat (RNat contract)
- Address: `0x26d460c3Cf931Fb2014FA436a49e3Af08619810e` (Flare mainnet)
- `claimRewards(uint256[] projectIds, uint256 month) returns (uint128)` — claims vested rFLR
- `withdraw(uint128 amount, bool wrap)` — withdraws rFLR to WFLR/FLR
- `withdrawAll(bool wrap)` — withdraws entire rFLR balance
- `getBalancesOf(address owner) returns (uint256 wNatBalance, uint256 rNatBalance, uint256 lockedBalance)`
- `getClaimableRewards(uint256 projectId, uint256 month, address owner) returns (uint128)`

### rFLR Mechanics
- rFLR = vested rewards backed by WFLR
- 12-month linear vesting schedule
- 50% penalty for withdrawing locked (unvested) rFLR
- Project-based monthly reward distribution

## Security Considerations
- 50% penalty on locked withdrawal — hook should only withdraw vested/unlocked amounts
- `withdrawAll` includes both vested and locked — user accepts penalty on locked portion
- No reentrancy concern — IRNat is a Flare system contract
- Fee handling follows established MerklClaimRewardHook pattern (audited)

## References
- IRNat interface: `flare-foundation/flare-smart-contracts-v2` (GitHub)
- Flare rFLR docs: https://dev.flare.network/network/flare-tx-sdk/cookbook#rflr-rewards
- Existing claim hooks: `src/hooks/claim/BaseClaimRewardHook.sol`, `src/hooks/claim/merkl/MerklClaimRewardHook.sol`
