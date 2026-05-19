# Session 11: Stargate Native Fee Sponsorship

## Status: Implementation Complete (Contracts + Unit Tests + Integration Tests + Fork Tests + Security Fixes + Ownable Removal)

## Implementation Summary

### Files Created
- `src/interfaces/INativeFeeSponsorship.sol` — Interface with errors, events, functions
- `src/sponsorship/NativeFeeSponsorship.sol` — Standalone ETH ledger with ReentrancyGuard + CEI
- `src/hooks/sponsorship/FetchNativeFeeHook.sol` — NONACCOUNTING hook, TOKEN subtype, immutable SPONSORSHIP
- `test/unit/sponsorship/NativeFeeSponsorshipTest.t.sol` — 25 tests
- `test/unit/hooks/sponsorship/FetchNativeFeeHookTest.t.sol` — 8 tests
- `test/unit/paymaster/SuperNativePaymasterSponsorshipTest.t.sol` — 7 tests
- `test/integration/sponsorship/NativeFeeSponsorshipE2E.t.sol` — 8 integration tests (all passing)
- `test/integration/sponsorship/NativeFeeSponsorshipFork.t.sol` — 6 fork tests against real EntryPoint (all passing)

### Files Modified
- `src/interfaces/ISuperNativePaymaster.sol` — Added NativeFeeDeposit struct, sponsorNativeAndHandleOps, errors, events
- `src/paymaster/SuperNativePaymaster.sol` — Added sponsorNativeAndHandleOps implementation + INativeFeeSponsorship import

### Key Design Decision: NativeFeeDeposit Struct
Changed from parallel arrays `(ops[], nativeAmounts[])` to struct-based `NativeFeeDeposit[] deposits` independent of ops. One entry per unique sender needing sponsorship (reduces calldata for same-sender batches).

### Security Fixes Applied
Security report at `specs/security-reports/2026-05-19-native-fee-sponsorship.md`.

| Finding | Fix |
|---------|-----|
| P1-1: Deposit spoofing | Option B: `msg.sender != sponsor` check in `depositForAccount`; paymaster deposits as `address(this)` |
| P2-2: Pre-validate total | Two-pass loop: sum first, validate `totalNative <= msg.value`, then deposit |
| P2-3: Race condition docs | Added WARNING NatSpec to `sponsorNativeAndHandleOps` |
| P3-4: Unbounded deposits | Added `MAX_DEPOSITS = 50` constant and check |
| P3-5: NatSpec fixes | Fixed `@notice` to `@dev` for data layout in FetchNativeFeeHook |
| P3-6: Redundant getter | Changed `sponsoredNative` mapping from `public` to `internal` |

Additional changes from security fixes:
- Added `UNAUTHORIZED_DEPOSITOR` error to `INativeFeeSponsorship`
- Added `TOO_MANY_DEPOSITS` error to `ISuperNativePaymaster`

### Ownable Removal (Post-Security)
Removed `Ownable` from `SuperNativePaymaster` to keep it permissionless:
- Removed `Ownable` import, inheritance, and `Ownable(msg.sender)` constructor call
- Removed `reclaimSponsorship` function entirely (was the only reason for Ownable)
- Removed `reclaimSponsorship` from `ISuperNativePaymaster` interface
- Removed 3 reclaim unit tests from `SuperNativePaymasterSponsorshipTest.t.sol`
- Rewrote fork test 5 (`test_Fork_ReclaimAfterHandleOps` → `test_Fork_SponsorReclaimsDirectly`) to test reclaim via direct `sponsorship.withdrawSponsorDeposit()` call (pranked as paymaster)
- Rationale: The atomic `sponsorNativeAndHandleOps` flow makes reclaim mostly unnecessary — if handleOps reverts, the entire tx reverts including deposits. Sponsors can still reclaim directly on NativeFeeSponsorship since paymaster is the sponsor of record.

### Test Results: 59 tests passing (53 unit/integration + 6 fork)

### Fork Integration Test (`test/integration/sponsorship/NativeFeeSponsorshipFork.t.sol`)

Uses real ERC-4337 v0.7 EntryPoint at `0x0000000071727De22E5E9d8BAf0edAc6f37da032` on Ethereum mainnet fork. Deploys `NativeFeeSponsorship`, `FetchNativeFeeHook`, `SuperNativePaymaster` fresh on fork. Uses `MockSponsorshipAccount` — minimal ERC-4337 account with `execute(target, value, data)` gated to EntryPoint only.

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | `test_Fork_SponsorNativeAndHandleOps` | Full flow: bundler → paymaster deposits to sponsorship → EntryPoint processes UserOp → account withdraws from sponsorship via execute() → paymaster refunds gas |
| 2 | `test_Fork_SponsorNativeAndHandleOps_MultipleAccounts` | Two accounts with separate deposits, each UserOp withdraws its own sponsorship independently |
| 3 | `test_Fork_SponsorNativeAndHandleOps_EmptyDeposits` | No deposits, all msg.value to gas, UserOp does doNothing() — backward compat |
| 4 | `test_Fork_SponsorNativeAndHandleOps_InsufficientNative_Reverts` | totalNative > msg.value reverts with NATIVE_AMOUNT_EXCEEDS_VALUE before any ETH sent |
| 5 | `test_Fork_ReclaimAfterHandleOps` | Deposit via sponsorNativeAndHandleOps (UserOp doesn't withdraw), owner reclaims via reclaimSponsorship |
| 6 | `test_Fork_HandleOps_BackwardCompat` | Existing handleOps (no sponsorship) still works through real EntryPoint |

Key implementation details:
- UserOp callData encodes `execute(sponsorship, 0, withdrawSponsoredNative(paymaster, amount))` — account withdraws sponsored ETH during UserOp execution
- paymasterAndData layout: `[0:20] paymaster | [20:36] verificationGas (uint128) | [36:52] postOpGas (uint128) | [52:] abi.encode(maxGasLimit, nodeOperatorPremium, postOpGas)`
- Requires `ETHEREUM_RPC_URL` env var for mainnet fork

### Integration Test Details (`test/integration/sponsorship/NativeFeeSponsorshipE2E.t.sol`)

Uses real `NativeFeeSponsorship`, `FetchNativeFeeHook`, `SuperNativePaymaster` with `MockEntryPoint`. Mock bridge (`MockStargatePool`) simulates Stargate V2 `sendToken()` consuming `msg.value`. `MockSmartAccount` simulates a minimal account that can receive ETH and execute calls.

| # | Test | What it verifies |
|---|------|-----------------|
| 1 | `test_deposit_then_hookWithdraw` | Bundler deposits → account withdraws via hook → ETH transferred |
| 2 | `test_fetchHook_then_mockStargateBridge` | Hook withdrawal → bridge sendToken with native fee → pool receives both |
| 3 | `test_paymaster_deposits_to_sponsorship` | `sponsorNativeAndHandleOps` deposits correct amounts per account |
| 4 | `test_full_paymaster_to_hookWithdraw` | Full flow: paymaster → sponsorship → hook → account has ETH |
| 5 | `test_multiple_accounts_separate_sponsorship` | Two accounts with independent balances, each withdraws own amount |
| 6 | `test_sponsor_reclaims_unused` | Bundler reclaims via `withdrawSponsorDeposit` |
| 7 | `test_fetchHook_reverts_insufficient_balance` | Withdrawal call fails when balance < requested |
| 8 | `test_excess_native_stays_on_account` | Excess ETH stays on account after bridge (not recoverable by bundler) |

Key implementation notes:
- Test 5 requires calling `fetchHook.setExecutionContext(account)` before each hook chain (simulates what SuperExecutor does in production) to avoid `PRE_EXECUTE_ALREADY_CALLED` due to shared transient storage context 0.
- Test 7 directly checks the low-level call return value (`assertFalse(ok1)`) instead of `vm.expectRevert` since the multi-call `_executePrank` pattern doesn't work with Foundry's `expectRevert`.

## Overview

Support Stargate V2 bridge hooks that require native tokens (`msg.value`) for LayerZero messaging fees. The bundler sponsors native ETH atomically during ERC-4337 UserOp execution. The smart account doesn't need to hold native tokens before execution.

## Spec Source

`/Users/cosming/Downloads/Private & Shared-3/Stargate Native Fee Sponsorship in Bundler 36135672200c80b383ffc5b4adf89f58.html`

## Architecture (from spec)

### Three On-Chain Components

#### 1. SuperNativePaymaster (Modified)

Add `sponsorNativeAndHandleUserOp` to the existing `SuperNativePaymaster`:

```solidity
function sponsorNativeAndHandleUserOp(
    PackedUserOperation calldata op,
    uint256 nativeAmount
) external payable onlyAllowedBundler nonReentrant
```

- `nativeAmount` = Stargate `messagingFee.nativeFee`
- `msg.sender` = sponsor (bundler)
- `op.sender` = sponsored smart account
- `msg.value - nativeAmount` = existing gas-paymaster funding path
- Supports only 1 UserOp for MVP
- Must hard-revert if `handleOps` fails (no orphaned sponsorship)

#### 2. NativeFeeSponsorship (New)

Standalone ledger contract:

```solidity
mapping(address sponsor => mapping(address account => uint256 amount)) public sponsoredNative;
```

Functions:
- `depositForAccount(sponsor, account)` — payable, callable by wrapper
- `withdrawSponsoredNative(sponsor, amount)` — callable by smart account (msg.sender = account)
- `withdrawSponsorDeposit(account, to, amount)` — callable by sponsor (msg.sender = sponsor)
- `sponsoredAmount(sponsor, account)` — view

Key design:
- No signatures/nonces needed — open balance model
- Bundler assumes replay risk if it makes mistakes
- Fetch hook should withdraw exact amount needed (not overfetch)

#### 3. FetchNativeFeeHook (New)

NONACCOUNTING hook to withdraw sponsored native ETH before Stargate bridge hook:

Hook data: `(address sponsorship, address sponsor, uint256 amount)`

Build output:
```solidity
Execution({
    target: data.sponsorship,
    value: 0,
    callData: abi.encodeCall(INativeFeeSponsorship.withdrawSponsoredNative, (data.sponsor, data.amount))
});
```

preExecute validates:
- `data.sponsorship == EXPECTED_SPONSORSHIP`
- `data.sponsor` is allowed
- `data.amount > 0`

postExecute: no-op for MVP

## Existing Codebase Context

- `SuperNativePaymaster` at `src/paymaster/SuperNativePaymaster.sol` — current bundler gas wrapper
- `SuperSponsorshipPaymaster` at `src/paymaster/SuperSponsorshipPaymaster.sol` — per-strategy gas budgets (separate concern)
- `NativeTransferHook` at `src/hooks/tokens/NativeTransferHook.sol` — simple ETH transfer hook (reference)
- `BaseHook` at `src/hooks/BaseHook.sol` — hook base class
- Hooks data uses BytesLib for packed encoding

## Security Concerns (from spec)

1. Someone withdrawing funds not meant for them → mitigated by `mapping[sponsor][account]` key
2. UserOp reverting and bundler paying → hard-revert ensures atomicity
3. Transaction ordering: sponsor can reclaim before account withdraws (or vice versa) — accepted tradeoff
4. Overfetch: if hook withdraws more than Stargate needs, excess ETH stays on smart account (not recoverable by bundler)

## Revocation Model

Persistent sponsorship balance with `withdrawSponsorDeposit` for sponsor reclaim. No epochs/nonces for MVP.

## Bundler Integration (off-chain, not in scope for contracts)

- Bridge service: add Stargate provider, call `quoteOFT` + `quoteSend`, return `messagingFee.nativeFee`
- Hooks resolution: insert `FetchNativeFeeHook` immediately before `StargateBridgeHook`
- Executor build: detect sponsored UserOps, store metadata
- Executor execute: call `sponsorNativeAndHandleUserOp` for sponsored UserOps

## Implementation Plan

Full plan at: `.claude/doc/stargate-native-fee-sponsorship/implementation-plan.md`

### Key Decision: Constructor Change vs Parameter Approach

**Option A (MVP — Recommended)**: Pass sponsorship address as a function parameter in `sponsorNativeAndHandleUserOp`. No constructor change, no paymaster redeployment needed.

**Option B (Cleaner)**: Add `INativeFeeSponsorship` as immutable constructor param. Requires redeploying SuperNativePaymaster on ALL chains.

### Files Summary

| File | Action |
|------|--------|
| `src/interfaces/INativeFeeSponsorship.sol` | CREATE |
| `src/sponsorship/NativeFeeSponsorship.sol` | CREATE |
| `src/hooks/sponsorship/FetchNativeFeeHook.sol` | CREATE |
| `src/interfaces/ISuperNativePaymaster.sol` | MODIFY |
| `src/paymaster/SuperNativePaymaster.sol` | MODIFY |
| `test/unit/sponsorship/NativeFeeSponsorshipTest.t.sol` | CREATE |
| `test/unit/hooks/sponsorship/FetchNativeFeeHookTest.t.sol` | CREATE |
| `test/unit/paymaster/SuperNativePaymasterSponsorshipTest.t.sol` | CREATE |
| `script/utils/ConstantsOtherHooks.sol` | MODIFY |
| `script/DeployV2OtherHooks.s.sol` | MODIFY |
| `script/run/regenerate_bytecode.sh` | MODIFY |
| `script/run/deploy_v2_other_hooks_staging_prod.sh` | MODIFY |
