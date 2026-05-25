# User Flow & Gap Analysis: rFLR Claiming Hooks for Superform V2

**Date:** 2026-05-14
**Analyst:** User Experience Flow Analyst
**Feature:** ClaimRFLRHook + WithdrawRFLRHook (NONACCOUNTING hooks, Flare mainnet chain 14)
**Reference spec sources:** `specs/rflr-claiming-hook/interview-notes.md`, `specs/rflr-claiming-hook/research/repo-analysis.md`, `specs/rflr-claiming-hook/research/best-practices.md`, `specs/rflr-claiming-hook/research/evm-security.md`

---

## Phase 1: User Flow Overview

### Top-Level User Journeys

There are five distinct end-to-end user journeys this feature touches.

```
Flow 1: Claim Only
  User has claimable rFLR rewards
  --> ClaimRFLRHook executes claimRewards(projectIds, month)
  --> rFLR balance increases
  --> Optional: fee deducted from rFLR delta to feeReceiver
  --> rFLR remains in smart account balance (vested on 12-month schedule)
  RESULT: User holds rFLR in smart account

Flow 2: Withdraw Only (rFLR already present in account from prior claim)
  User already holds rFLR from a previous claim operation
  --> WithdrawRFLRHook executes withdrawAll(wrap=true)
  --> IRNat burns rFLR, sends WFLR to smart account
  --> WFLR balance increases (post-penalty amount)
  RESULT: User holds WFLR in smart account

Flow 3: Claim then Withdraw (separate operations / transactions)
  --> Flow 1 (ClaimRFLRHook in tx A)
  [Time passes -- rFLR vests over weeks/months]
  --> Flow 2 (WithdrawRFLRHook in tx B)
  RESULT: Optimal path -- user avoids 50% penalty on locked tokens

Flow 4: Claim then Withdraw (chained within same transaction)
  --> ClaimRFLRHook + WithdrawRFLRHook in same Merkle leaf / execution batch
  WARNING: Newly claimed rFLR is 0/12 vested -- withdrawAll applies 50% penalty to ALL of it
  RESULT: User receives only 50% of claimed rewards as WFLR

Flow 5: Withdraw then Compose (WithdrawRFLRHook chained with downstream hook)
  --> WithdrawRFLRHook
  --> [Downstream hook uses outAmount = WFLR delta, e.g., Deposit4626VaultHook]
  RESULT: WFLR is deposited downstream in same transaction
```

### Hook-Level Execution Flow (ClaimRFLRHook)

```
[Off-chain bundler]
  1. Encodes hook data: feeReceiver + feeBPS + month + expectedClaimAmount + projectIdsLen + projectIds[]
  2. Calls hook.build(prevHook, account, data) to obtain execution array

[hook.build() -- view, no state change]
  3. Validates feeReceiver, feeBPS <= MAX_FEE_BPS (5000)
  4. Decodes month, projectIdsLen, projectIds[] from data via BytesLib
  5. Constructs Execution array:
     [0] preExecute(prevHook, account, data)        -- target: hook contract
     [1] IRNat.claimRewards(projectIds, month)       -- target: RNAT (immutable)
     [2] IERC20(rFLR).transfer(feeReceiver, fee)     -- ONLY if feeBPS > 0 AND fee > 0
     [last] postExecute(prevHook, account, data)     -- target: hook contract

[Smart account executes array atomically]
  6. preExecute called by smart account (msg.sender == account enforced by BaseHook)
     - Snapshots rFLR balance via IERC20(rewardToken).balanceOf(account)
     - Stores snapshot in _setOutAmount(balanceBefore, account)
  7. IRNat.claimRewards(projectIds, month) executes
     - Claimed WFLR deposited to user's RNat account
     - rFLR tokens minted to caller (smart account)
  8. If feeBPS > 0 and fee > 0:
     - IERC20(rFLR).transfer(feeReceiver, fee) executes
  9. postExecute called by smart account
     - Reads current rFLR balance: balanceAfter = IERC20(rewardToken).balanceOf(account)
     - Sets outAmount = balanceAfter - balanceBefore (net to user, after fee)
```

### Hook-Level Execution Flow (WithdrawRFLRHook)

```
[Off-chain bundler]
  1. Encodes hook data: (minimal / empty -- spec says "minimal/empty data")
     NOTE: WFLR address is immutable constructor arg; RNAT address is immutable constructor arg

[hook.build() -- view, no state change]
  2. Constructs Execution array:
     [0] preExecute(prevHook, account, data)    -- target: hook contract
     [1] IRNat.withdrawAll(wrap=true)           -- target: RNAT (immutable)
     [last] postExecute(prevHook, account, data) -- target: hook contract

[Smart account executes array atomically]
  3. preExecute called by smart account
     - Snapshots WFLR balance via IERC20(WFLR).balanceOf(account)
     - Stores snapshot in _setOutAmount(wflrBalanceBefore, account)
  4. IRNat.withdrawAll(true) executes
     - Burns ALL rFLR from caller's RNat account
     - Pays out unlocked portion as WFLR 1:1
     - Pays out only 50% of locked portion as WFLR (50% burned as penalty)
     - Sends WFLR to caller (smart account)
  5. postExecute called by smart account
     - wflrBalanceAfter = IERC20(WFLR).balanceOf(account)
     - outAmount = wflrBalanceAfter - wflrBalanceBefore
```

---

## Phase 2: Flow Permutations Matrix

### ClaimRFLRHook Permutations

| Dimension | Variant A | Variant B | Variant C |
|-----------|-----------|-----------|-----------|
| Fee config | feeBPS = 0 (no fee) | feeBPS = 1..4999 | feeBPS = 5000 (max 50%) |
| Project IDs | Single project | Multiple projects (N) | Empty array |
| Claim result | Non-zero rewards claimed | Zero rewards (already claimed / invalid month) | Partial (some projects have rewards, some do not) |
| First-time user | RNat account does NOT exist yet | RNat account already exists | n/a |
| Month validity | Valid past month with unclaimed rewards | Future month (no rewards yet) | Already-claimed month |
| Hook position in chain | First hook (prevHook = address(0)) | After another hook (prevHook set) | n/a |
| Downstream chaining | Last hook in batch | Followed by WithdrawRFLRHook | Followed by a deposit hook |

### WithdrawRFLRHook Permutations

| Dimension | Variant A | Variant B | Variant C |
|-----------|-----------|-----------|-----------|
| rFLR vesting state | Fully unlocked (12+ months vested) | Partially locked | Fully locked (just claimed) |
| Prior balance | rFLR already in account from past claim | rFLR just claimed in same tx (chained) | Zero rFLR balance |
| WFLR prior balance | Account has no pre-existing WFLR | Account has pre-existing WFLR | n/a |
| Hook position | First and only hook | Preceded by ClaimRFLRHook | Followed by a deposit hook |
| FlareDrop compounding | wNatBalance == rNatBalance | wNatBalance > rNatBalance (FlareDrop earned) | n/a |

### Chained Execution Permutations

| Sequence | Notes | Economic Risk |
|----------|-------|---------------|
| ClaimRFLRHook (no fee) only | Clean simple claim | None |
| ClaimRFLRHook (with fee) only | Fee deducted from rFLR delta | None (user signed intent) |
| WithdrawRFLRHook only | Withdraw pre-existing rFLR | 50% penalty if locked tokens present |
| ClaimRFLRHook + WithdrawRFLRHook (same tx) | Full penalty on newly claimed rFLR | HIGH -- 50% of just-claimed amount burned |
| WithdrawRFLRHook + downstream deposit hook | WFLR flows to vault | Penalty applied before deposit |
| ClaimRFLRHook (fee) + WithdrawRFLRHook + deposit | Fee on rFLR, then penalty on WFLR, then deposit | HIGHEST risk -- two loss events |

---

## Phase 3: Missing Elements and Gaps

### GAP-01: Data Layout Conflict Between Spec and Research Documents

**Category:** Specification Conflict (Critical)

**Gap description:** The feature specification states the ClaimRFLRHook data layout as:

```
feeReceiver(20) + feeBPS(32) + month(32) + expectedClaimAmount(32) + projectIdsLen(32) + projectIds(N*32)
```

This is 148+ bytes. However, the repo-analysis research document (`specs/rflr-claiming-hook/research/repo-analysis.md`, Section 10) proposes a different layout:

```
feeReceiver(20) + feeBPS(32) + rewardToken(20) + month(32) + projectIdsLen(32) + projectIds(N*32)
```

This is also 136+ bytes. These two layouts are **mutually incompatible**:
- The spec includes `expectedClaimAmount` (32 bytes) but no `rewardToken` address
- The research includes `rewardToken` address (20 bytes) but no `expectedClaimAmount`

**Impact:** If implemented with the spec layout, the `rewardToken` address needed for balance snapshots in `_preExecute`/`_postExecute` has no source. If implemented with the research layout, `expectedClaimAmount` is absent (and its purpose is unclear).

**Current ambiguity:** It is also unclear whether `rewardToken` (rFLR token address) should be in the data at all, since `RNAT` is an immutable address and rFLR could be derived from it if the IRNat contract is also the rFLR ERC20. The best-practices research document (Section 3) notes: "rFLR IS the RNat token itself (the RNat contract is an ERC-20). Verify this assumption."

### GAP-02: Purpose and Use of expectedClaimAmount Is Undefined

**Category:** Specification Ambiguity (Critical)

**Gap description:** The spec data layout includes `expectedClaimAmount(32)` but there is no description of how or when this field is used. Potential interpretations:
- It is a minimum slippage check (revert if actual claimed amount < expectedClaimAmount)
- It is pre-computed off-chain to calculate the fee without needing to read `claimed()` from the distributor (unlike MerklClaimRewardHook's approach)
- It is unused and exists only for off-chain display purposes
- It replaces a balance-snapshot with a static expected value for fee calculation

**Impact:** If it is a slippage check, the hook must revert in `_postExecute` if the actual delta is less than expected. If it is used for fee calculation, the fee becomes predictable at build time (like MerklClaimRewardHook), but if rewards were already partially claimed, the fee would be over-estimated. If it is unused, it wastes 32 bytes of calldata on every execution.

**Current ambiguity:** There is no specification for how this value interacts with fee computation or what happens if the actual claimed amount differs from the expected claim amount.

### GAP-03: Hook Type Conflict -- NONACCOUNTING vs OUTFLOW

**Category:** Specification Conflict (Critical)

**Gap description:** The feature specification states both hooks use `NONACCOUNTING` (consistent with interview-notes.md). However, the best-practices research document (Sections 3 and 4) recommends `OUTFLOW` for both hooks, with reasoning that reward claiming and withdrawal are outflow-like operations.

The repo-analysis document (Section 2.1) explicitly resolves this for the Superform pattern: the MerklClaimRewardHook is NONACCOUNTING with `_preExecute` and `_postExecute` both setting `outAmount = 0`. The FluidClaimRewardHook, GearboxClaimRewardHook, and YearnClaimOneRewardHook are OUTFLOW with balance-delta tracking.

The interview notes confirm NONACCOUNTING. The spec confirms NONACCOUNTING.

**Impact:** NONACCOUNTING means the accounting system (SuperLedger) does not track this hook's output. If a downstream hook needs to use `outAmount` from ClaimRFLRHook or WithdrawRFLRHook via `usePrevHookAmount = true`, the hook MUST set a meaningful outAmount, which requires balance-delta tracking regardless of the NONACCOUNTING type designation. The hook type affects the accounting layer but does NOT prevent setting outAmount.

**Current ambiguity:** If NONACCOUNTING with balance-delta tracking and meaningful outAmount is the intent, this is valid (there is no rule that NONACCOUNTING hooks must set outAmount to 0). The MerklClaimRewardHook sets outAmount to 0 because Merkl does not need downstream chaining. If rFLR hooks are expected to be chainable (e.g., ClaimRFLRHook -> WithdrawRFLRHook), outAmount should be the delta. This needs explicit confirmation.

### GAP-04: rewardToken Address Source for Balance Snapshot

**Category:** Implementation Blocker (Critical)

**Gap description:** The `_preExecute` and `_postExecute` methods in ClaimRFLRHook need to know the rFLR ERC20 token address in order to call `IERC20(rFLR).balanceOf(account)`. There are three possible sources:

- Option A: Derive it from the RNAT immutable via a call to `IRNat.getBalancesOf()` or similar -- but this is an external call and not guaranteed to be the rFLR token address
- Option B: Encode the rFLR token address in the hook data (the `rewardToken` field in the research layout)
- Option C: The RNAT contract IS the rFLR ERC20 (the research best-practices document notes this as a possible assumption to verify). In that case, `IERC20(RNAT).balanceOf(account)` is the rFLR balance check

**For WithdrawRFLRHook:** The balance to track is WFLR. The WFLR address is specified as an immutable constructor arg. This is unambiguous.

**Current ambiguity:** The rFLR token address derivation path for ClaimRFLRHook is not confirmed. If rFLR IS the RNat contract itself (Option C), then the RNAT immutable is sufficient and no extra data field or on-chain resolution is needed.

### GAP-05: WithdrawRFLRHook Data Layout Is "Minimal/Empty" Without Definition

**Category:** Specification Incompleteness (Important)

**Gap description:** The spec states the WithdrawRFLRHook has "Minimal/empty data." The hook always calls `IRNat.withdrawAll(wrap=true)` with no user-configurable parameters (both RNAT and WFLR are immutable). However, the execution model in BaseHook.build() passes `data` to `_buildHookExecutions`, `preExecute`, and `postExecute`. If data is truly empty (`bytes("")`), BytesLib operations on it will revert if any offset-based access is attempted.

The repo-analysis (Section 10) proposes an empty constructor for WithdrawRFLRHook with RNAT as immutable. There is no data encoding at all. This is consistent with how some NONACCOUNTING hooks work (e.g., `MarkRootAsUsedHook` passes minimal data).

**Impact:** Any test or bundler that passes empty bytes to this hook must work. Any `BytesLib.toAddress` or similar call in the hook on the empty data bytes will panic/revert. This is only a problem if the hook accidentally tries to decode from empty data.

**Current ambiguity:** Is the data truly zero-length bytes, or is there a minimum data layout (e.g., a bytes32 placeholder at offset 0 as used in standard hook data)?

### GAP-06: Fee Calculation Timing -- Build-Time vs Post-Execute

**Category:** Architecture Decision (Important)

**Gap description:** The MerklClaimRewardHook calculates fees at `_buildHookExecutions` time (a view call) by reading `IDistributor.claimed()` to know the pre-claim cumulative amount. This lets the fee transfer be included as a static Execution in the build array. For rFLR, the claimed amount is determined by IRNat at execution time and cannot be read in advance without a view call.

Two approaches are possible:
- Approach A (Build-time fee, static): Use `expectedClaimAmount` from data as the fee basis. Fee Execution is built statically. If actual claimed amount differs, fee is wrong.
- Approach B (Post-execute fee, dynamic): No fee Execution in build array. Instead, `_postExecute` computes the fee and then executes a transfer -- but BaseHook.postExecute is called by the smart account, so a transfer from postExecute would require a separate Execution added to the array, which cannot be done post-build.

Actually, the correct pattern for dynamic fees must mirror MerklClaimRewardHook: the fee transfer MUST be included in the Execution array during `_buildHookExecutions`. This means either reading state during build (not pure -- it becomes a view function) or using `expectedClaimAmount` as the static basis.

**Impact:** If `expectedClaimAmount` is the fee basis: if the user has already partially claimed for the month, the actual delta is less than expected, and the fee transfer of `expectedClaimAmount * feeBPS / BPS` would attempt to transfer more rFLR than the user received, causing a potential overdraft.

**Current ambiguity:** Which approach is intended? Does `expectedClaimAmount` serve as the fee basis, or should the hook use `IRNat.getClaimableRewards()` at build time (a view call) to compute an accurate fee basis?

### GAP-07: Zero-Value Fee Transfer Handling

**Category:** Security/Correctness (Important)

**Gap description:** When `feeBPS = 0` or when the actual claimed amount rounds the fee to 0, the Execution array should NOT include an `IERC20.transfer(feeReceiver, 0)` call. Some ERC20 implementations revert on zero-value transfers. The evm-security research (Section 1.3) explicitly flags this risk.

**Impact:** If the fee Execution is always included when `feeBPS > 0` (regardless of whether fee rounds to zero for small amounts), a zero-value transfer attempt could revert the entire transaction for small claims.

**Current ambiguity:** The spec does not explicitly state that zero-value fee transfers should be skipped. The MerklClaimRewardHook does not explicitly guard against zero-value transfers either -- it always builds the fee transfer when `feePercent > 0`. For rFLR this risk is the same but should be documented.

### GAP-08: Empty projectIds Array Handling

**Category:** Validation/Error Handling (Important)

**Gap description:** The spec does not specify what should happen when `projectIds` is an empty array (`projectIdsLen = 0`). The IRNat contract does not revert on empty arrays -- it simply returns 0 claimed. The research best-practices (Section 8.1) confirms this.

**Impact:** An empty projectIds array is a wasteful but non-reverting call. The hook should either:
- Revert with `AMOUNT_NOT_VALID()` if projectIdsLen == 0
- Allow it silently (outAmount = 0, no fee)

The evm-security research (Section 4.6) recommends validating non-empty arrays. This is also consistent with the spec stating the data layout includes `projectIdsLen` explicitly.

**Current ambiguity:** Should the hook revert on zero-length projectIds, or silently succeed with zero outAmount?

### GAP-09: Month Parameter Validation

**Category:** Validation/Error Handling (Important)

**Gap description:** The spec does not specify validation rules for the `month` parameter. A `month = 0` is likely invalid (RNat uses 1-based month indexing). A `month` far in the future would silently claim nothing.

**Impact:** If `month = 0` causes a revert in IRNat, the hook would propagate that revert without a user-friendly error. If the month is valid but has no rewards, the operation succeeds with `outAmount = 0`.

**Current ambiguity:** Should the hook validate `month > 0` before encoding the claim call?

### GAP-10: First-Time RNat Account Creation Gas Cost

**Category:** Operational Concern (Important)

**Gap description:** The first call to `claimRewards` by any address creates a new per-user RNat account contract on-chain. This incurs approximately 200,000-400,000 extra gas (per best-practices research Section 6). Neither the spec nor the interview notes mention this first-time gas cost or any mechanism to inform the off-chain bundler.

**Impact:** Gas estimation for first-time claimers will be significantly underestimated if the bundler does not check for RNat account existence before submitting the transaction.

**Current ambiguity:** Is there an expected mechanism for the bundler to detect first-time accounts and adjust gas estimates? Should the hook emit an event or provide a view function for this check?

### GAP-11: Penalty Warning and User Consent in WithdrawRFLRHook

**Category:** UX / Risk Communication (Important)

**Gap description:** `IRNat.withdrawAll(wrap=true)` applies a 50% penalty to locked (unvested) rFLR. The spec acknowledges this ("50% penalty applies to locked (unvested) rFLR — enforced by IRNat, not hook") but does not specify:
- Whether the hook should check the locked balance and potentially revert or warn if locked > 0
- Whether there is a slippage-like parameter for minimum expected WFLR output
- How the user communicates explicit consent to the penalty via the signed intent

**Impact:** A user who expects to receive X WFLR could receive significantly less due to the penalty. Without a `minExpectedWFLR` parameter or an on-chain pre-check, there is no mechanism to protect against unexpected penalty application.

**Current ambiguity:** Should WithdrawRFLRHook include a `minWFLROut` parameter to guard against excessive penalties? Should the hook revert if the locked amount is above a configurable threshold?

### GAP-12: Hook Chaining Between ClaimRFLRHook and WithdrawRFLRHook

**Category:** Integration / Architecture (Important)

**Gap description:** The spec describes "Optional: fee deduction from claimed rFLR" and "Chaining: claim -> (optionally) -> withdraw in separate operations." However, the chaining mechanics are unspecified:

- If ClaimRFLRHook sets outAmount = rFLR delta, and WithdrawRFLRHook is chained next, does WithdrawRFLRHook use `usePrevHookAmount = true`? If so, what does that amount mean to WithdrawRFLRHook? It always calls `withdrawAll` regardless of amount.
- WithdrawRFLRHook uses `withdrawAll` which withdraws the ENTIRE rFLR balance, not just the amount from the previous hook. If the account already had pre-existing rFLR, `withdrawAll` would withdraw that too.
- There is no `usePrevHookAmount` field defined in WithdrawRFLRHook's data layout ("minimal/empty data").

**Impact:** Chaining ClaimRFLRHook -> WithdrawRFLRHook does not follow the standard `usePrevHookAmount` pattern since WithdrawRFLRHook always withdraws everything. This is an intentional design choice but needs to be explicitly documented to avoid implementer confusion.

**Current ambiguity:** Should the chaining be documented as "implicit" (both hooks operate on the full rFLR balance sequentially, not via amount passing)? Is there a case where a user would want to withdraw only the just-claimed amount rather than all rFLR?

### GAP-13: WithdrawRFLRHook -- Zero rFLR Balance Behavior

**Category:** Error Handling / Edge Case (Important)

**Gap description:** If the smart account has zero rFLR balance (or an RNat account does not exist), calling `IRNat.withdrawAll(true)` will either revert or return 0 with no WFLR transferred. The spec and research documents do not specify the expected behavior.

**Impact:** The transaction would either revert (propagating an IRNat error) or succeed silently with `outAmount = 0`. The user would waste gas without receiving WFLR.

**Current ambiguity:** Should the hook validate that the rFLR balance is non-zero before building the withdrawal Execution? This would require a view call in `_buildHookExecutions`, changing it from `pure` to `view`.

### GAP-14: inspect() Return Value Not Specified

**Category:** Specification Incompleteness (Nice-to-have)

**Gap description:** The spec does not define the return value of `inspect()` for either hook. Existing patterns from the codebase are:
- MerklClaimRewardHook: `abi.encodePacked(feeReceiver)`
- FluidClaimRewardHook: `abi.encodePacked(yieldSource, rewardToken)`
- WithdrawWETHHook: `abi.encodePacked(WETH)`

**Impact:** Off-chain systems that parse `inspect()` output need a defined schema. Without a spec, implementers may return inconsistent encodings.

**Reasonable default assumption:**
- ClaimRFLRHook: `abi.encodePacked(feeReceiver, RNAT)` or `abi.encodePacked(feeReceiver)`
- WithdrawRFLRHook: `abi.encodePacked(RNAT)` or `abi.encodePacked(RNAT, WFLR)`

### GAP-15: Interface Inheritance List Not Specified

**Category:** Specification Incompleteness (Nice-to-have)

**Gap description:** The spec does not enumerate which ISuperHook sub-interfaces each hook should implement beyond `BaseHook`. The interview notes confirm NONACCOUNTING type but do not specify whether the hooks implement:
- `ISuperHookInflowOutflow` (requires `decodeAmount()`)
- `ISuperHookContextAware` (requires `decodeUsePrevHookAmount()`)
- `ISuperHookOutflow` (requires `replaceCalldataAmount()`)

For NONACCOUNTING hooks the codebase is inconsistent:
- MerklClaimRewardHook: `BaseHook` only (no additional interfaces)
- TransferERC20Hook: `BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow`
- WithdrawWETHHook: `BaseHook, ISuperHookContextAware`

**Impact:** Missing interface implementations cause compilation errors if the executor or bundler expects those methods.

**Reasonable default assumption:** Since both hooks have no input amount (rewards are determined by IRNat, not user input), `decodeAmount()` should return 0. If downstream chaining via `usePrevHookAmount` is NOT supported (as implied by "minimal/empty data"), neither `ISuperHookContextAware` nor `ISuperHookInflowOutflow` is needed.

### GAP-16: RNAT Address Verification -- Is IRNat the rFLR ERC20?

**Category:** External Dependency Verification (Critical)

**Gap description:** The research documents identify a critical assumption that has not been verified on-chain: "rFLR IS the RNat token itself (the RNat contract is an ERC-20)." The spec's RNAT address is `0x26d460c3Cf931Fb2014FA436a49e3Af08619810e`. If the RNat contract at this address is simultaneously:
(a) The reward distribution contract (with `claimRewards`, `withdrawAll`), AND
(b) The rFLR ERC20 token (with `balanceOf`, `transfer`),

then ClaimRFLRHook can use `IERC20(RNAT).balanceOf(account)` directly for both tracking and fee transfer.

If these are SEPARATE contracts (rFLR is a different token address, and RNAT is only the reward distribution contract), then the hook MUST have the rFLR token address either as a second immutable constructor arg or encoded in the hook data.

**Impact:** This is a blocker. The wrong assumption here leads to:
- Balance tracking against the wrong contract
- Fee transfers to a contract that is not an ERC20 or does not hold user balances

**Current ambiguity:** This needs to be verified against the deployed contract at `0x26d460c3Cf931Fb2014FA436a49e3Af08619810e` on Flare mainnet (chain 14).

### GAP-17: Constructor Argument Scope for WithdrawRFLRHook

**Category:** Specification Ambiguity (Important)

**Gap description:** The spec states "RNAT and WFLR addresses as immutable constructor args" for WithdrawRFLRHook. This is clear. For ClaimRFLRHook, the spec states "RNAT address as immutable constructor arg."

If the rFLR token address is needed for balance tracking (GAP-04/GAP-16 above), ClaimRFLRHook may also need a second immutable for the rFLR token. The spec does not mention this.

**Current ambiguity:** Does ClaimRFLRHook have one or two constructor args?

### GAP-18: Fee Transfer Token Identity

**Category:** Correctness (Important)

**Gap description:** The spec says "Fee handling: feeReceiver + feeBPS (max 5000 / 50%) from claimed rFLR rewards." This implies the fee is taken in rFLR tokens. However, the evm-security research (Section 1.3) raises the question: "If rFLR has any transfer restrictions (e.g., cannot transfer locked rFLR), this could fail."

The rFLR token represents vested rewards. If the claimed rFLR is newly minted (0/12 months vested), it may or may not be transferable to the feeReceiver depending on rFLR's transfer mechanics.

**Impact:** If rFLR is non-transferable until unlocked (or has other transfer restrictions), the fee transfer would revert, blocking the entire claim transaction.

**Current ambiguity:** Is rFLR freely transferable as an ERC20 regardless of vesting state? This requires on-chain verification.

### GAP-19: Deployment Script Details Not Specified

**Category:** Specification Incompleteness (Nice-to-have)

**Gap description:** The spec does not describe deployment requirements. Based on repo-analysis research (Section 4.3), the following files need modification:
- `script/utils/ConstantsOtherHooks.sol` -- CLAIM_RFLR_HOOK_KEY, WITHDRAW_RFLR_HOOK_KEY, RNAT_ADDRESS_FLARE, WFLR_ADDRESS_FLARE
- `script/DeployV2OtherHooks.s.sol` -- RFLRHookAddresses struct, _deployRFLRHooks(), runRFLR(), chain-gate on FLARE_CHAIN_ID
- `script/run/regenerate_bytecode.sh` -- RFLR_HOOK_CONTRACTS array
- `script/run/deploy_v2_other_hooks_staging_prod.sh` -- rFLR section

**Current ambiguity:** Should ClaimRFLRHook and WithdrawRFLRHook be deployed alongside existing Firelight hooks on Flare (FLARE_CHAIN_ID = 14) only? This appears to be the intent but is not stated explicitly in the spec.

### GAP-20: Testing Requirements Not Specified

**Category:** Specification Incompleteness (Nice-to-have)

**Gap description:** The spec does not define testing requirements. Based on repo patterns, expected test files would be:
- `test/unit/hooks/claim/rflr/ClaimRFLRHook.t.sol`
- `test/unit/hooks/claim/rflr/WithdrawRFLRHook.t.sol`
- Possibly `test/integration/rflr/RFLRHooksE2E.t.sol` (fork tests against Flare mainnet)

Flare mainnet fork tests require a Flare RPC endpoint in the Makefile/environment -- it is not confirmed whether this is already configured.

---

## Phase 4: Critical Questions Requiring Clarification

### Priority 1 -- Critical (Blockers)

**Q1. Is RNAT the rFLR ERC20 token, or is rFLR a separate contract?**

Why it matters: This determines whether `IERC20(RNAT).balanceOf(account)` is the correct rFLR balance check, and whether fee transfers via `IERC20(RNAT).transfer(feeReceiver, fee)` are valid. If RNAT and rFLR are separate, ClaimRFLRHook needs a second immutable or data field for the rFLR token address.

Assumption if unanswered: Treat them as separate until verified. Include rFLR token address in hook data or as a second immutable constructor arg.

Example: On Ethereum, WETH is the token contract AND the "protocol contract." But Flare's RNat could be analogous to a MasterChef that mints a separate reward token.

**Q2. What is the purpose of expectedClaimAmount in the data layout, and how does it interact with fee calculation?**

Why it matters: This field appears in the spec but not in the research documents. If it is the fee basis, fees could be over-charged if rewards were partially claimed. If it is a minimum check, the hook must revert in postExecute when actual delta < expected. If unused, it should be removed.

Assumption if unanswered: Treat expectedClaimAmount as a minimum slippage check for the claim output. Revert in `_postExecute` if actual delta < expectedClaimAmount.

**Q3. Should the fee calculation use expectedClaimAmount (static, build-time) or the actual balance delta (dynamic, post-execute)?**

Why it matters: The MerklClaimRewardHook uses a query to `IDistributor.claimed()` at build time to compute the fee as a static Execution. If rFLR hooks must also compute fees statically, they need either `expectedClaimAmount` or a call to `IRNat.getClaimableRewards()` at build time. The latter makes `_buildHookExecutions` a `view` function (not `pure`), which is acceptable but differs from MerklClaimRewardHook's approach.

Assumption if unanswered: Use `expectedClaimAmount` as the static fee basis at build time (consistent with spec). Build fee transfer as a static Execution. Accept the risk that over-estimation is possible if rewards were partially claimed.

**Q4. Confirm the hook type: NONACCOUNTING with meaningful outAmount set (balance delta pattern), or NONACCOUNTING with outAmount = 0?**

Why it matters: The MerklClaimRewardHook uses NONACCOUNTING with outAmount = 0. The interview notes say "NONACCOUNTING pattern (like MerklClaimRewardHook)" but also says "balance snapshot pattern for tracking rFLR delta." These two descriptions are incompatible if interpreted literally (MerklClaimRewardHook does NOT use balance snapshots -- it sets outAmount to 0 in both pre and post).

Assumption if unanswered: Use NONACCOUNTING with meaningful balance-delta outAmount (not 0). This enables downstream chaining and is consistent with the spec's statement about balance snapshot pattern.

### Priority 2 -- Important (Significant UX or Correctness Impact)

**Q5. What should happen when projectIds is empty (length 0)?**

Why it matters: An empty array call to IRNat is a no-op that wastes gas. Should the hook revert with `AMOUNT_NOT_VALID` to protect users from accidentally submitting zero-cost but still fee-consuming transactions?

Assumption if unanswered: Revert with `AMOUNT_NOT_VALID()` when `projectIdsLen == 0`.

**Q6. Should WithdrawRFLRHook include a minimum expected WFLR output parameter to guard against the 50% penalty?**

Why it matters: Without a `minWFLROut` guard, a user who intends to withdraw only unlocked rFLR could lose 50% of their locked balance if they call `withdrawAll` without realizing they have locked tokens. The signed intent does provide implicit consent, but a min-out parameter provides a final protection.

Assumption if unanswered: No min-out parameter. Document the 50% penalty risk prominently in NatSpec. The off-chain bundler is responsible for checking locked balance via `getBalancesOf()` before encoding the hook data.

**Q7. Is rFLR freely transferable as a standard ERC20 (enabling fee transfers), or does it have transfer restrictions?**

Why it matters: If rFLR cannot be transferred before a certain vesting period, the fee transfer Execution will revert for newly claimed rewards, blocking the entire claim transaction.

Assumption if unanswered: Assume standard ERC20 transferability. If verified to have restrictions, the fee mechanism must be redesigned (e.g., take fees in WFLR after a subsequent withdrawal instead).

**Q8. What is the exact data layout for ClaimRFLRHook -- does it include expectedClaimAmount, rewardToken, both, or neither?**

Why it matters: The spec layout and research layout conflict (GAP-01). The final layout must be decided before implementation.

Assumption if unanswered: Use the following reconciled layout:
```
feeReceiver (20 bytes, offset 0)
feeBPS      (32 bytes, offset 20)
month       (32 bytes, offset 52)
expectedClaimAmount (32 bytes, offset 84) -- used as fee basis AND minimum output check
projectIdsLen (32 bytes, offset 116)
projectIds[] (N * 32 bytes, offset 148+)
```
The rFLR token address is derived from RNAT (if RNAT IS the rFLR ERC20, confirmed by Q1). A separate rewardToken field is not needed if RNAT is the rFLR ERC20.

**Q9. Should the hook validate month > 0?**

Why it matters: Month 0 is likely invalid for IRNat and would either revert or return 0. A user-friendly revert at the hook level is preferable to an opaque IRNat revert.

Assumption if unanswered: Validate `month > 0`, revert with `AMOUNT_NOT_VALID()`.

**Q10. Does WithdrawRFLRHook need to support downstream chaining via usePrevHookAmount (i.e., ISuperHookContextAware)?**

Why it matters: If a downstream hook (e.g., a deposit hook) should receive the WFLR amount from WithdrawRFLRHook via `outAmount`, the hook must set a meaningful outAmount and implement `decodeUsePrevHookAmount`. The spec says "minimal/empty data" which suggests no such field exists.

Assumption if unanswered: Set meaningful outAmount (WFLR delta) in postExecute for potential downstream use. Do NOT implement `ISuperHookContextAware` or `usePrevHookAmount` in WithdrawRFLRHook since the data is "minimal/empty." The downstream hook would instead reference the WFLR balance directly.

### Priority 3 -- Nice-to-Have (Clarifications)

**Q11. What should inspect() return for each hook?**

Assumption if unanswered:
- ClaimRFLRHook: `abi.encodePacked(feeReceiver)` (mirrors MerklClaimRewardHook)
- WithdrawRFLRHook: `abi.encodePacked(RNAT)` (the protocol contract interacted with)

**Q12. Should there be a maximum projectIds array length to bound calldata size and gas?**

Assumption if unanswered: No explicit cap. Document in NatSpec that large arrays increase gas costs proportionally.

**Q13. Is a Flare mainnet fork RPC endpoint available in the test environment for fork tests?**

Assumption if unanswered: Unit tests only, using mocked IRNat. Fork tests documented as a TODO requiring Flare RPC configuration.

**Q14. Should the hooks be deployed to Flare testnet (Coston2) before mainnet?**

Assumption if unanswered: Deploy to staging (which maps to the existing staging chain configuration) before production.

---

## Phase 5: Recommended Next Steps

### Step 1 -- Resolve Blockers Before Implementation

1. Verify on-chain whether `0x26d460c3Cf931Fb2014FA436a49e3Af08619810e` (IRNat) is simultaneously the rFLR ERC20 token by calling `balanceOf(address)`, `symbol()`, and `decimals()` on it. Use `cast call 0x26d460c3... "symbol()(string)" --rpc-url <FLARE_RPC>`.

2. Confirm the rFLR transfer mechanics: is `IERC20(RNAT).transfer(feeReceiver, fee)` valid for newly-claimed rFLR? Test by checking whether rFLR has any transfer lock or transfer restriction logic.

3. Decide the final data layout for ClaimRFLRHook (GAP-01). The two candidate layouts from spec and research must be reconciled into one authoritative layout before coding begins.

4. Confirm whether `expectedClaimAmount` is a minimum-output guard, a fee calculation basis, or unused (GAP-02). This changes the implementation significantly.

### Step 2 -- Write Implementation Plan

Once blockers are resolved:
1. Define authoritative NatSpec data layout comments for both hooks
2. List exact interfaces each hook implements
3. Confirm constructor signatures
4. Lock in the fee calculation approach

### Step 3 -- Implement in This Order

1. Create `src/vendor/flare/IRNat.sol` with minimal interface
2. Create `src/hooks/claim/flare/ClaimRFLRHook.sol`
3. Create `src/hooks/claim/flare/WithdrawRFLRHook.sol`
4. Create unit tests with mocked IRNat
5. Update deployment scripts (ConstantsOtherHooks.sol, DeployV2OtherHooks.s.sol, regenerate_bytecode.sh, deploy_v2_other_hooks_staging_prod.sh)
6. Create fork tests if Flare RPC is available

### Step 4 -- Security Review Checklist

Before finalizing implementation:
- [ ] Verify `feeBPS > MAX_FEE_BPS` reverts at build time (not only execution time)
- [ ] Verify `feeReceiver == address(0)` reverts when `feeBPS > 0`
- [ ] Verify zero-value fee transfers are skipped (or document that they are not)
- [ ] Verify balance delta subtraction does not underflow (Solidity 0.8.30 checked arithmetic)
- [ ] Verify that the 50% penalty documentation in WithdrawRFLRHook NatSpec is prominent and accurate
- [ ] Verify that same-tx Claim+Withdraw economic risk is documented in NatSpec

---

## Summary Table of Gaps

| Gap ID | Category | Priority | Description |
|--------|----------|----------|-------------|
| GAP-01 | Specification Conflict | Critical | Data layout in spec vs research conflicts (expectedClaimAmount vs rewardToken field) |
| GAP-02 | Specification Ambiguity | Critical | Purpose of expectedClaimAmount field is undefined |
| GAP-03 | Specification Conflict | Critical | NONACCOUNTING type with "balance snapshot" is inconsistent with MerklClaimRewardHook reference |
| GAP-04 | Implementation Blocker | Critical | rFLR token address source for balance snapshot not confirmed |
| GAP-05 | Specification Incompleteness | Important | WithdrawRFLRHook "minimal/empty" data not formally defined |
| GAP-06 | Architecture Decision | Important | Fee calculation is build-time (static) vs post-execute (dynamic) -- approach unspecified |
| GAP-07 | Security/Correctness | Important | Zero-value fee transfer behavior not specified |
| GAP-08 | Validation | Important | Empty projectIds array handling not specified |
| GAP-09 | Validation | Important | Month parameter validation not specified |
| GAP-10 | Operational | Important | First-time RNat account creation gas cost not addressed |
| GAP-11 | UX/Risk | Important | No minimum expected WFLR output guard for 50% penalty in WithdrawRFLRHook |
| GAP-12 | Integration | Important | Chaining mechanics between the two hooks not formally specified |
| GAP-13 | Edge Case | Important | Zero rFLR balance on withdrawAll behavior not specified |
| GAP-14 | Incompleteness | Nice-to-have | inspect() return value not specified for either hook |
| GAP-15 | Incompleteness | Nice-to-have | Interface inheritance list not specified |
| GAP-16 | External Dependency | Critical | RNAT == rFLR ERC20 assumption not verified on-chain |
| GAP-17 | Specification Ambiguity | Important | Number of constructor args for ClaimRFLRHook unclear |
| GAP-18 | Correctness | Important | rFLR transferability for fee payments not verified |
| GAP-19 | Incompleteness | Nice-to-have | Deployment script scope not specified |
| GAP-20 | Incompleteness | Nice-to-have | Testing requirements not specified |

---

## Appendix: Data Layout Candidates (For Resolution)

### Candidate A (Spec Layout)

```
Offset  Size   Field
0       20     address feeReceiver
20      32     uint256 feeBPS
52      32     uint256 month
84      32     uint256 expectedClaimAmount
116     32     uint256 projectIdsLen
148     N*32   uint256[] projectIds
```

Issues: No rewardToken field. Requires RNAT to be the rFLR ERC20 (verified via Q1). expectedClaimAmount purpose must be clarified (Q2/Q3).

### Candidate B (Research Layout)

```
Offset  Size   Field
0       20     address feeReceiver
20      32     uint256 feeBPS
52      20     address rewardToken (rFLR ERC20)
72      32     uint256 month
104     32     uint256 projectIdsLen
136     N*32   uint256[] projectIds
```

Issues: No expectedClaimAmount. Fee basis must come from a view call at build time (getClaimableRewards or balance-delta approach).

### Candidate C (Reconciled / Recommended)

```
Offset  Size   Field
0       20     address feeReceiver
20      32     uint256 feeBPS
52      32     uint256 month
84      32     uint256 expectedClaimAmount (acts as min-output slippage guard AND fee basis)
116     32     uint256 projectIdsLen
148     N*32   uint256[] projectIds
```

Notes: Only valid if RNAT is confirmed to be the rFLR ERC20. Fee is computed as `expectedClaimAmount * feeBPS / BPS` at build time (static Execution). postExecute validates `actualDelta >= expectedClaimAmount`. No separate rewardToken field needed.
