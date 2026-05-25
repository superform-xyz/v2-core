# rFLR Claiming Hook — Technical Specification

## Overview

Build two NONACCOUNTING hooks for claiming and withdrawing rFLR rewards on Flare mainnet (chain 14). rFLR is Flare's reward token distributed monthly to participating dApps and their users, backed by WFLR with a 12-month linear vesting schedule.

## Problem Statement

Superform users on Flare need to claim rFLR rewards from the RNat contract and optionally withdraw them as WFLR. Currently there is no hook integration for Flare's reward system. The hooks must follow the established NONACCOUNTING claim pattern (MerklClaimRewardHook) with fee handling support.

## Proposed Solution

Two hooks following existing patterns:
1. **ClaimRFLRHook** — Claims rFLR rewards via `IRNat.claimRewards()` with optional fee deduction
2. **WithdrawRFLRHook** — Converts rFLR to WFLR via `IRNat.withdrawAll(true)`

Both are NONACCOUNTING hooks with `HookSubTypes.CLAIM`, using balance snapshot patterns for tracking deltas.

## Technical Design

### Vendor Interface

**File:** `src/vendor/flare/IRNat.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IRNat
/// @notice Minimal interface for Flare's RNat (rFLR) reward contract
/// @dev rFLR tokens vest linearly over 12 months. Early withdrawal of locked tokens
///      incurs a 50% penalty (burned). The RNat contract IS the rFLR ERC-20 token.
interface IRNat {
    /// @notice Claims rFLR rewards across specified projects up to a given month
    /// @param projectIds Array of project IDs to claim from
    /// @param month The month up to which to claim (inclusive, cumulative)
    /// @return claimedAmount Total WFLR deposited into caller's RNat account
    function claimRewards(uint256[] calldata projectIds, uint256 month) external returns (uint128 claimedAmount);

    /// @notice Withdraws all funds from the caller's RNat account
    /// @dev 50% penalty on locked (unvested) portion — half is burned
    /// @param wrap If true returns WFLR (ERC-20); if false returns native FLR
    /// @return withdrawnAmount Total withdrawn after penalty deduction
    function withdrawAll(bool wrap) external returns (uint128 withdrawnAmount);
}
```

### ClaimRFLRHook

**File:** `src/hooks/claim/flare/ClaimRFLRHook.sol`

**Pattern:** MerklClaimRewardHook (NONACCOUNTING + fee handling) + TransferERC20Hook (balance tracking)

**Constructor:**
```solidity
constructor(address rNat_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
    if (rNat_ == address(0)) revert ADDRESS_NOT_VALID();
    RNAT = rNat_;
}
```

**Immutables:**
- `address public immutable RNAT` — The IRNat contract (also the rFLR ERC-20 token)

**Data layout:**
```
offset 0:   address feeReceiver         (20 bytes)
offset 20:  uint256 feeBPS              (32 bytes)
offset 52:  uint256 month               (32 bytes)
offset 84:  uint256 expectedClaimAmount (32 bytes) — computed off-chain for fee calculation
offset 116: uint256 projectIdsLength    (32 bytes)
offset 148: uint256[] projectIds        (N × 32 bytes, tightly packed)
```

**`_buildHookExecutions`:**
1. Decode feeReceiver, feeBPS, month, expectedClaimAmount, projectIds from data
2. Validate: `feeBPS <= MAX_FEE_BPS`, `feeReceiver != address(0)` when `feeBPS > 0`
3. Compute `fee = (expectedClaimAmount * feeBPS) / BPS`
4. Build Execution array:
   - `executions[0]`: `IRNat(RNAT).claimRewards(projectIds, month)`
   - `executions[1]` (if fee > 0): `IERC20(RNAT).transfer(feeReceiver, fee)`

**`_preExecute`:**
```solidity
asset = address(RNAT); // rFLR IS the RNat ERC-20
_setOutAmount(IERC20(RNAT).balanceOf(account), account);
```

**`_postExecute`:**
```solidity
_setOutAmount(IERC20(RNAT).balanceOf(account) - getOutAmount(account), account);
```

**`inspect()`:** `abi.encodePacked(feeReceiver)` — matches MerklClaimRewardHook

**Interfaces:** `BaseHook`, `ISuperHookInflowOutflow`, `ISuperHookContextAware`, `ISuperHookInspector`

**Constants:**
```solidity
uint256 private constant FEE_RECEIVER_POSITION = 0;
uint256 private constant FEE_BPS_POSITION = 20;
uint256 private constant MONTH_POSITION = 52;
uint256 private constant EXPECTED_AMOUNT_POSITION = 84;
uint256 private constant PROJECT_IDS_LENGTH_POSITION = 116;
uint256 private constant PROJECT_IDS_START_POSITION = 148;
uint256 internal constant BPS = 10_000;
uint256 internal constant MAX_FEE_BPS = 5000;
```

### WithdrawRFLRHook

**File:** `src/hooks/claim/flare/WithdrawRFLRHook.sol`

**Pattern:** WithdrawWETHHook (NONACCOUNTING + balance tracking)

**Constructor:**
```solidity
constructor(address rNat_, address wflr_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
    if (rNat_ == address(0) || wflr_ == address(0)) revert ADDRESS_NOT_VALID();
    RNAT = rNat_;
    WFLR = wflr_;
}
```

**Immutables:**
- `address public immutable RNAT` — The IRNat contract
- `address public immutable WFLR` — The WFLR (wrapped FLR) ERC-20 token

**Data layout:**
```
(no user-provided data needed — all parameters are immutables or hardcoded)
```

Note: `_buildHookExecutions` receives `data` but does not decode it. The hook always calls `IRNat.withdrawAll(true)`.

**`_buildHookExecutions`:**
```solidity
executions = new Execution[](1);
executions[0] = Execution({
    target: RNAT,
    value: 0,
    callData: abi.encodeCall(IRNat.withdrawAll, (true))
});
```

**`_preExecute`:**
```solidity
asset = WFLR;
_setOutAmount(IERC20(WFLR).balanceOf(account), account);
```

**`_postExecute`:**
```solidity
_setOutAmount(IERC20(WFLR).balanceOf(account) - getOutAmount(account), account);
```

**`inspect()`:** `abi.encodePacked(RNAT)` — returns the key external contract

**Interfaces:** `BaseHook`, `ISuperHookInspector`

### Key External Contract Addresses (Flare Mainnet)

| Contract | Address |
|----------|---------|
| RNat (rFLR) | `0x26d460c3Cf931Fb2014FA436a49e3Af08619810e` |
| WFLR (WNat) | `0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d` |

## Acceptance Criteria

### Functional
- [ ] ClaimRFLRHook claims rFLR rewards for specified projectIds and month
- [ ] ClaimRFLRHook deducts fee (feeBPS) and transfers to feeReceiver
- [ ] ClaimRFLRHook reverts if feeBPS > MAX_FEE_BPS (5000)
- [ ] ClaimRFLRHook reverts if feeReceiver is zero when feeBPS > 0
- [ ] ClaimRFLRHook skips fee transfer when computed fee is 0
- [ ] WithdrawRFLRHook calls IRNat.withdrawAll(true) to get WFLR
- [ ] WithdrawRFLRHook tracks WFLR balance delta in outAmount
- [ ] Both hooks use NONACCOUNTING type with HookSubTypes.CLAIM
- [ ] Both hooks have RNAT as immutable constructor arg
- [ ] inspect() returns correct packed addresses for both hooks

### Security
- [ ] Fee validated at build time (MAX_FEE_BPS cap)
- [ ] Balance snapshot pattern (not return values) for delta tracking
- [ ] Zero-value fee transfer skipped (prevents revert on some ERC-20s)
- [ ] Non-empty projectIds array validated in ClaimRFLRHook
- [ ] Constructor validates non-zero addresses
- [ ] NatSpec documents 50% penalty risk on WithdrawRFLRHook

### Testing
- [ ] Unit tests for both hooks in `test/unit/hooks/claim/rflr/`
- [ ] Constructor verification tests
- [ ] Build execution array structure tests
- [ ] Revert tests (invalid fee, zero addresses, empty projectIds)
- [ ] PreExecute/PostExecute balance delta tests
- [ ] inspect() output verification
- [ ] Fee calculation edge cases (zero fee, max fee, small amounts)

## Deployment

### Files to Create
| File | Description |
|------|-------------|
| `src/vendor/flare/IRNat.sol` | Minimal IRNat interface |
| `src/hooks/claim/flare/ClaimRFLRHook.sol` | Claim hook |
| `src/hooks/claim/flare/WithdrawRFLRHook.sol` | Withdraw hook |
| `test/unit/hooks/claim/rflr/ClaimRFLRHookTest.t.sol` | Claim hook unit tests |
| `test/unit/hooks/claim/rflr/WithdrawRFLRHookTest.t.sol` | Withdraw hook unit tests |

### Files to Modify
| File | Change |
|------|--------|
| `script/utils/ConstantsOtherHooks.sol` | Add `CLAIM_RFLR_HOOK_KEY`, `WITHDRAW_RFLR_HOOK_KEY`, `RNAT_FLARE`, `WFLR_FLARE` |
| `script/DeployV2OtherHooks.s.sol` | Add `RFLRHookAddresses` struct, `_deployRFLRHooks()`, chain-gate on `FLARE_CHAIN_ID` |
| `script/run/regenerate_bytecode.sh` | Add rFLR hook contracts to `RFLR_HOOK_CONTRACTS` |
| `script/run/deploy_v2_other_hooks_staging_prod.sh` | Add rFLR section with `RFLR_SUPPORTED_CHAINS=("14")` |

### Deployment Configuration
- Chain-gated on `FLARE_CHAIN_ID = 14` (already defined in Constants.sol)
- Constructor args for both hooks: `abi.encode(RNAT_FLARE)` and `abi.encode(RNAT_FLARE, WFLR_FLARE)`
- Bytecode goes to `generated-bytecode-other/` → `locked-bytecode-other/`

## Implementation Plan

### Phase 1: Core Implementation
- [ ] Create `src/vendor/flare/IRNat.sol`
- [ ] Create `src/hooks/claim/flare/ClaimRFLRHook.sol`
- [ ] Create `src/hooks/claim/flare/WithdrawRFLRHook.sol`
- [ ] Verify `forge build` compiles

### Phase 2: Unit Tests
- [ ] Create `test/unit/hooks/claim/rflr/ClaimRFLRHookTest.t.sol`
- [ ] Create `test/unit/hooks/claim/rflr/WithdrawRFLRHookTest.t.sol`
- [ ] Run and pass all tests

### Phase 3: Deployment Scripts
- [ ] Add constants to `ConstantsOtherHooks.sol`
- [ ] Add deployment logic to `DeployV2OtherHooks.s.sol`
- [ ] Add to `regenerate_bytecode.sh` and `deploy_v2_other_hooks_staging_prod.sh`
- [ ] Regenerate bytecode and copy to locked folders
- [ ] Simulate deployment on staging

## Risks & Mitigations

| Risk | Category | Likelihood | Impact | Mitigation |
|------|----------|------------|--------|------------|
| Reentrancy via IRNat external calls | Reentrancy | Low | Medium | BaseHook mutexes + CEI pattern + balance snapshots |
| Fee calculation rounding to zero | Arithmetic | Medium | Low | Acceptable — favors user. Skip zero-value transfers |
| 50% penalty on locked withdrawal | Business Logic | Medium | Medium | Document clearly in NatSpec. Off-chain bundler warns user |
| Zero-value ERC-20 transfer reverts | Token Behavior | Medium | Low | Skip fee transfer when fee = 0 |
| Claim + Withdraw chained same tx | Business Logic | Low | High | Off-chain bundler prevents this by default |
| First-time RNat account creation gas | Operational | Low | Low | Off-chain gas estimation accounts for ~200-400k extra gas |

## References

### Internal
- MerklClaimRewardHook (fee pattern): `src/hooks/claim/merkl/MerklClaimRewardHook.sol`
- TransferERC20Hook (balance tracking): `src/hooks/tokens/erc20/TransferERC20Hook.sol`
- WithdrawWETHHook (NONACCOUNTING + balance): `src/hooks/tokens/weth/WithdrawWETHHook.sol`
- Firelight hooks (Flare deployment): `src/hooks/vaults/firelight/`

### External
- [Flare rFLR Cookbook](https://dev.flare.network/network/flare-tx-sdk/cookbook#rflr-rewards)
- [IRNat source](https://github.com/flare-foundation/flare-smart-contracts-v2)
- [WFLR address](https://dev.flare.network/support/faqs)
