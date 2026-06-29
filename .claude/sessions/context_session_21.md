# Session 21: Hook Sequencing — Pass-Through `outAmount` Architecture Design

## Status: DESIGN SKETCH (not yet implemented)
- Date: 2026-06-19

## Context

A colleague raised the question: "all the hooks should have the getOutAmount no? even if that amount out is same as in — like 'approval' semantics?" The concern is that without uniform pipe semantics, arbitrary hook sequencing requires a combinatorial allowlist of valid hook pairs. If every hook reports `(outToken, outAmount)`, any sequence whose token types flow correctly is valid — no allowlist needed.

## Problem Statement

Today, hooks have inconsistent `outAmount` behavior:

| Hook | What `outAmount` reports | Correct for chaining? |
|------|-------------------------|----------------------|
| SwapOdosV3Hook | outputToken balance delta | Yes |
| ApproveAndDeposit4626VaultHook | vault share balance delta | Yes |
| TransferHook | recipient balance delta | Yes |
| ClaimRFLRHook | rFLR balance delta | Yes |
| **ApproveERC20Hook** | **allowance(account, spender)** | **No** — works accidentally when allowance == amount, but breaks on pre-existing allowances or max approvals |
| SetOperator7540Hook | **0 (never set)** | **No** — downstream hooks reading `usePrevHookAmount` get 0 |
| MarkRootAsUsedHook | **0 (never set)** | **No** — same problem |

Additionally, there's no `outToken` — a downstream hook has no on-chain way to know *what* token the previous hook produced. The bundler must know this off-chain.

## Design: Three Pipe Modes

We introduce a `PipeMode` enum that every hook declares. This tells BaseHook how to handle `outAmount` and `outToken` in the default `_preExecute` / `_postExecute` flow.

### PipeMode.TRANSFORM — "I convert token A into token B"

**Semantics:** The hook takes an input token, does something with it, and produces an output token (possibly different). `outAmount` is the balance delta of the *output* token. `outToken` is the output token address.

**How it works:**
1. `_preExecute`: Snapshot output token balance → store in `outAmount` (as "before" value)
2. Hook executions run (swap, deposit, withdraw, etc.)
3. `_postExecute`: `outAmount = currentBalance - snapshotBalance` (the delta). Set `outToken` to the output token address.

**Examples:**
- `SwapOdosV3Hook`: USDC in → WETH out. `outAmount = WETH delta`, `outToken = WETH`
- `ApproveAndDeposit4626VaultHook`: USDC in → vault shares out. `outAmount = share delta`, `outToken = vault`
- `Redeem4626VaultHook`: vault shares in → USDC out. `outAmount = USDC delta`, `outToken = USDC`
- `TransferHook`: token in → same token arrives at recipient. `outAmount = recipient balance delta`, `outToken = token`
- `ClaimRFLRHook`: no input → rFLR out. `outAmount = rFLR delta`, `outToken = RNAT` (also a transform — from nothing to something)
- `WithdrawRFLRHook`: rFLR in → WFLR out. `outAmount = WFLR delta`, `outToken = WFLR`

**Who uses this:** The vast majority of hooks — swaps, deposits, withdrawals, redeems, claims, bridges. Any hook where a balance changes.

**This is the default.** Hooks that don't override `_pipeMode()` get `TRANSFORM`.

### PipeMode.PASSTHROUGH — "I don't touch any amounts, just forward what came before"

**Semantics:** The hook performs a side-effect (approval, config change, operator setup) that doesn't consume or produce any token amount. It transparently forwards the previous hook's `outAmount` and `outToken` so the downstream hook can read them as if the pass-through hook wasn't there.

**How it works:**
1. `_preExecute`: Read `prevHook.getOutAmount(account)` and `prevHook.getOutToken(account)`, store both as this hook's `outAmount` and `outToken`.
2. Hook executions run (approve, setOperator, etc.)
3. `_postExecute`: No-op. Values are already set.

**Think of it as a transparent relay in a pipeline:**
```
Swap (out: 100 USDC) → Approve (passthrough: 100 USDC) → Deposit (reads: 100 USDC)
```
The Approve hook is invisible to the Deposit hook — it sees the same `(token, amount)` the Swap produced.

**Examples:**
- `ApproveERC20Hook`: Approves a spender. No tokens move. Forward prev `(token, amount)`.
- `SetOperator7540Hook`: Sets an operator on a 7540 vault. No tokens move.
- `SetSlippageHook`: Configures slippage. No tokens move.
- `MarkRootAsUsedHook`: Marks a Merkle root as used. No tokens move.
- `FetchNativeFeeHook`: Reads a fee value. No tokens move.
- `CircleGatewayAddDelegateHook` / `RemoveDelegateHook`: Admin operations.
- All 8 cancel/claim 7540 hooks (CancelDepositRequest, ClaimCancelDeposit, etc.)

**Key rule:** A PASSTHROUGH hook at position 0 (no prevHook) has `outAmount = 0` and `outToken = address(0)`. This is fine — it means "I produce nothing." The next hook must not have `usePrevHookAmount = true` unless there's a real source upstream.

### PipeMode.SOURCE — "I create a new amount from nothing (or from internal state)"

**Semantics:** The hook produces a new token amount that is NOT derived from the previous hook's output. It ignores `prevHook.getOutAmount()` entirely. The amount comes from an external source — a claim, a reward calculation, an oracle read, etc.

**How it works:**
1. `_preExecute`: Snapshot the source token balance (same as TRANSFORM)
2. Hook executions run (claim rewards, etc.)
3. `_postExecute`: `outAmount = currentBalance - snapshotBalance`. Set `outToken`.

**Difference from TRANSFORM:** Conceptual, not mechanical. TRANSFORM hooks accept `usePrevHookAmount` to optionally read from prevHook. SOURCE hooks never do — their amount is always self-determined. This distinction matters for the sequencing validator: a SOURCE hook can appear anywhere in a chain without needing a compatible upstream token.

**Examples:**
- `ClaimRFLRHook`: Claims rFLR rewards. Amount comes from the contract's internal accounting, not from prevHook.
- `WithdrawVestedRFLRHook`: Withdraws a vested amount determined by the vesting contract.

**Note:** In practice, SOURCE and TRANSFORM have identical mechanics in BaseHook (both do balance-diff). The distinction is for the *sequencing validator* — it knows a SOURCE hook doesn't require token-type compatibility with its predecessor.

## New BaseHook Infrastructure

### New transient storage: `outToken`

```solidity
uint256 private constant OUT_TOKEN_OFFSET = 4;  // new slot alongside OUT_AMOUNT (1)

function getOutToken(address caller) public view returns (address);
function _setOutToken(address token, address caller) internal;
```

### PipeMode enum + virtual

```solidity
enum PipeMode { TRANSFORM, PASSTHROUGH, SOURCE }

/// @dev Override to declare pipe semantics. Default: TRANSFORM.
function _pipeMode() internal pure virtual returns (PipeMode) {
    return PipeMode.TRANSFORM;
}
```

### Default _preExecute / _postExecute for PASSTHROUGH

BaseHook gets a default `_preExecute` that handles PASSTHROUGH mode automatically:

```solidity
function _preExecute(address prevHook, address account, bytes calldata data) internal virtual {
    if (_pipeMode() == PipeMode.PASSTHROUGH && prevHook != address(0)) {
        _setOutAmount(ISuperHookResult(prevHook).getOutAmount(account), account);
        _setOutToken(ISuperHookResult(prevHook).getOutToken(account), account);
    }
    // TRANSFORM and SOURCE hooks override this entirely
}
```

### ISuperHookResult interface addition

```solidity
interface ISuperHookResult {
    function getOutAmount(address caller) external view returns (uint256);
    function getOutToken(address caller) external view returns (address);  // NEW
    // ... existing ...
}
```

## Per-Hook Changes

### Pass-through hooks (~15 hooks) — minimal change

```solidity
// Example: ApproveERC20Hook
// REMOVE existing _postExecute that reads allowance
// ADD:
function _pipeMode() internal pure override returns (PipeMode) {
    return PipeMode.PASSTHROUGH;
}
// BaseHook handles the rest automatically.
```

### Transform hooks (~30 hooks) — add 1 line

```solidity
// Example: SwapOdosV3Hook — existing _postExecute:
function _postExecute(address, address account, bytes calldata data) internal override {
    _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
    _setOutToken(BytesLib.toAddress(data, OUTPUT_TOKEN_POSITION), account); // NEW LINE
}
```

### Source hooks (~5 hooks) — add _pipeMode + 1 line

```solidity
// Example: ClaimRFLRHook
function _pipeMode() internal pure override returns (PipeMode) {
    return PipeMode.SOURCE;
}

function _postExecute(address, address account, bytes calldata) internal override {
    uint256 delta = IERC20(RNAT).balanceOf(account) - getOutAmount(account);
    _setOutAmount(delta, account);
    _setOutToken(RNAT, account); // NEW LINE
}
```

## On-Chain Sequencing Validation (Future)

With `(outToken, outAmount)` as a uniform pipe, the executor can validate at runtime:

```solidity
// In _processHook, after execution:
if (prevHook != address(0) && currentHook._pipeMode() == PipeMode.TRANSFORM) {
    address prevOutToken = ISuperHookResult(prevHook).getOutToken(account);
    address currentInToken = ISuperHookInspector(currentHook).getInToken(hookData);
    require(prevOutToken == currentInToken, "TOKEN_MISMATCH");
}
// PASSTHROUGH hooks: no check needed (they forward anything)
// SOURCE hooks: no check needed (they produce their own token)
```

This eliminates the combinatorial allowlist problem. Any sequence is valid as long as token types flow correctly.

## Hook Classification

### TRANSFORM (default — ~30 hooks)
All swap, deposit, withdraw, redeem, bridge send hooks:
- SwapOdosV3Hook, SwapOdosV2Hook, Swap1InchHook, SwapUniswapV2Hook, SwapAlgebraIntegralHook, etc.
- ApproveAndDeposit4626VaultHook, Deposit4626VaultHook, Deposit5115VaultHook, etc.
- Redeem4626VaultHook, Redeem5115VaultHook, Redeem7540VaultHook, etc.
- ApproveAndStargateSendHook, ApproveAndCCTPSendHook, etc.
- TransferHook, TransferERC20Hook, BatchTransferHook, BatchTransferFromHook
- WithdrawRFLRHook, EthenaUnstakeHook, etc.
- PendleUnifiedHook, SpectraExchangeDepositHook

### PASSTHROUGH (~15 hooks)
Admin, config, approval, and side-effect-only hooks:
- ApproveERC20Hook
- SetOperator7540Hook, SetSlippageHook
- MarkRootAsUsedHook
- FetchNativeFeeHook
- CircleGatewayAddDelegateHook, CircleGatewayRemoveDelegateHook, CircleGatewayWalletHook
- CancelDepositRequest7540Hook, CancelDepositRequestWithId7540Hook
- CancelRedeemRequest7540Hook, CancelRedeemRequestWithId7540Hook
- ClaimCancelDepositRequest7540Hook, ClaimCancelDepositRequestWithId7540Hook
- ClaimCancelRedeemRequest7540Hook, ClaimCancelRedeemRequestWithId7540Hook
- RecordPurchasePendlePTAmortizedOracleHook (V1/V2)
- RecordRedemptionPendlePTAmortizedOracleHook (V1/V2)

### SOURCE (~3-5 hooks)
Hooks that create amounts from external state:
- ClaimRFLRHook (claims from RNat contract)
- WithdrawVestedRFLRHook (withdraws from vesting schedule)
- ClaimWithdrawFirelightVaultHook (claims from Firelight)
- OfframpTokensHook (receives from offramp)

## Migration Path

1. **Phase 1 (non-breaking):** Add `outToken` slot + `PipeMode` enum + `_pipeMode()` virtual to BaseHook. Add `getOutToken()` to ISuperHookResult. Default `_pipeMode()` returns TRANSFORM. `outToken` defaults to address(0). No hook changes needed — everything compiles and works as before.

2. **Phase 2:** Tag each hook with its `_pipeMode()`. Fix `ApproveERC20Hook._postExecute` (remove allowance reporting). Add `_setOutToken()` to all transform/source hooks' `_postExecute`.

3. **Phase 3 (optional):** Enable on-chain token-flow validation in executor. Add `getInToken(hookData)` to inspector interface.

## Key Design Decisions

1. **PipeMode is `internal pure virtual`** — no storage, no gas overhead. The compiler inlines it.
2. **PASSTHROUGH auto-forwards in BaseHook._preExecute** — derived hooks don't need to know about prevHook.
3. **SOURCE vs TRANSFORM is conceptual, not mechanical** — both do balance-diff. The distinction guides the sequencing validator.
4. **outToken is transient storage** — same pattern as outAmount, zero persistence cost.
5. **Backward compatible** — Phase 1 changes nothing for existing hooks. Phase 2 can be rolled out hook-by-hook.

---

## Implementation Status: COMPLETE (2026-06-19)

All 6 tasks from the plan have been implemented and verified.

### Task 1: BaseHook + ISuperHookResult Infrastructure (DONE)
- Added `getOutToken(address caller)` to `ISuperHookResult` interface
- Added `PipeMode` enum, `OUT_TOKEN_OFFSET = 4`, `_pipeMode()`, `getOutToken()`, `_setOutToken()`, `_getOutToken()` to BaseHook
- Default `_preExecute` auto-forwards prevHook's outAmount + outToken for PASSTHROUGH hooks
- Bug fix: `_clearExecutionState` must NOT clear outToken (same as outAmount — both persist for next hook)

### Task 2: Tag 15 PASSTHROUGH Hooks (DONE)
Each received `_pipeMode()` override returning `PipeMode.PASSTHROUGH`:
MarkRootAsUsedHook, FetchNativeFeeHook, CircleGatewayAddDelegateHook, CircleGatewayRemoveDelegateHook, DeBridgeCancelOrderHook, RecordPurchasePendlePTAmortizedOracleHook (V1/V2), RecordRedemptionPendlePTAmortizedOracleHook (V1/V2), CancelDepositRequest7540Hook, CancelDepositRequestWithId7540Hook, CancelRedeemRequest7540Hook, CancelRedeemRequestWithId7540Hook, SetOperator7540Hook, SetSlippageHook

### Task 3: Fix ApproveERC20Hook → PASSTHROUGH (DONE)
- Added `_pipeMode()` override → `PASSTHROUGH`
- Removed `_postExecute` that incorrectly reported allowance as outAmount

### Task 4: Add `_setOutToken()` to All TRANSFORM Hooks (DONE)
~80+ hooks modified across all categories:
- **Vault inflow** (7): outToken = spToken
- **Vault outflow** (18): outToken = asset
- **Swap** (27): outToken from hook-specific data offset or local variable
- **Token** (2): outToken from data[0]
- **WETH** (2): outToken = WETH immutable
- **Claim** (8): outToken = asset/reward token
- **Loan** (13): outToken = asset
- **Stake** (4): outToken = yieldSource
- **Bridge** (1): outToken from data[0]
- **ForceDeallocateMorpho** (1): outToken = yieldSource (set in _preExecute)

### Task 5: Tests (DONE)
Created `test/unit/hooks/HookPipeMode.t.sol` with 6 tests:
- `test_TransformHook_SetsOutTokenAndAmount` — transform hook sets both outAmount and outToken
- `test_TransformHook_DefaultPipeMode` — default values are zero
- `test_PassthroughHook_ForwardsFromPrevHook` — passthrough auto-forwards from transform hook
- `test_PassthroughHook_NoPrevHook_ZeroValues` — passthrough at position 0 returns zeros
- `test_PassthroughChain_MultiplePassthrough` — chained passthroughs all carry same values
- `test_TransformOverridesPassthroughValues` — transform2 has its own output, transform1 preserved

### Task 6: Build & Verification (DONE)
- `forge build` — 0 errors (only external library warnings)
- All 6 HookPipeMode tests pass
- All 6 BaseHook tests pass
- All 122 MorphoLoanHooks tests pass
- All 76 CircleGateway tests pass

### Additional Fixes
- Fixed 3 test mock contracts that didn't implement the new `getOutToken()` from `ISuperHookResult`:
  - `test/mocks/MockHook.sol`
  - `test/integration/kyberswap/KyberSwapE2ESwap.t.sol::MockPrevHookForE2E`
  - `test/unit/hooks/bridges/CircleGatewayUnitTests.sol::MockPrevHook`

---

## Manifest: Add `pipeMode` Field (2026-06-22)

### What Changed

Added `pipeMode` field (`"transform"` | `"passthrough"` | `"source"`) to every entry in `hook-sizing-manifest.json`. This exposes each hook's pipe semantics so OMS can validate hook chain token flow.

### Files Modified

1. **`tooling/generate-hook-sizing-manifest.ts`**
   - Added `pipeMode` to `ManifestEntry` interface
   - Added `detectPipeMode(hookSolName)` — reads each hook's `.sol` file for `PipeMode.PASSTHROUGH` / `PipeMode.SOURCE`, defaults to `"transform"`
   - Set `pipeMode` on every code path in `buildManifest()`
   - Added pipeMode breakdown to console summary

2. **`tooling/validate-hook-sizing-manifest.ts`**
   - Added `pipeMode` to `ManifestEntry` interface
   - Check 8: Every entry has valid `pipeMode` value
   - Check 9: Cross-validates passthrough hooks are typically sizeless (warns if not)
   - Added pipeMode breakdown to console summary

3. **`hook-sizing-manifest.json`** — Regenerated with `pipeMode` on all 116 entries

### Distribution
- `"transform"`: 100 hooks
- `"passthrough"`: 16 hooks (ApproveERC20, MarkRootAsUsed, FetchNativeFee, CircleGateway Add/Remove Delegate, DeBridgeCancel, RecordPurchase/Redemption Pendle V1/V2, Cancel/ClaimCancel 7540 Deposit/Redeem, SetOperator, SetSlippage)
- `"source"`: 0 hooks (none currently override to SOURCE)
