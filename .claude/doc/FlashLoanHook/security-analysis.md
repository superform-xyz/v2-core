# FlashLoanRouter Security Analysis: Reentrancy & Nexus Invariants

## Date: 2026-04-28
## Status: Analysis — Open Issues

---

## C1: Nexus `executeFromExecutor` Reentrancy Invariant

### The Assumption

The FlashLoanRouter design depends on a critical property of Nexus:

> **`executeFromExecutor` has NO reentrancy guard.**

Confirmed at `lib/nexus/contracts/Nexus.sol:167-189`:
```solidity
function executeFromExecutor(
    ExecutionMode mode,
    bytes calldata executionCalldata
)
    external
    payable
    onlyExecutorModule      // ← access control only
    withHook                // ← Nexus-level hook (preCheck/postCheck), NOT reentrancy
    withRegistry(msg.sender, MODULE_TYPE_EXECUTOR)
    returns (bytes[] memory returnData)
```

No `nonReentrant`, no reentrancy guard. This is **observed behavior, not a written invariant**.

### The Risk

If Biconomy adds a reentrancy guard to `executeFromExecutor` in a future Nexus upgrade, all FlashLoanRouter flows break silently:
- The flash loan callback calls `account.executeFromExecutor(innerOps)`
- This happens inside the SAME transaction that originated from an executor module call
- A Nexus reentrancy guard would block this nested call
- **Silent failure**: the entire flash loan reverts, no explicit error about the reentrancy guard

### Recommendation: CI Property Test

Write a property test pinned to the Nexus version we deploy against:

```solidity
/// @notice Verify Nexus allows nested executeFromExecutor calls (no reentrancy guard)
/// @dev If this test fails after a Nexus upgrade, ALL FlashLoanRouter flows are broken
function test_NexusInvariant_executeFromExecutor_AllowsNestedCalls() public {
    // 1. Install both SuperExecutor and FlashLoanRouter on the account
    // 2. SuperExecutor calls account.executeFromExecutor (outer call)
    // 3. Inside that execution, FlashLoanRouter calls account.executeFromExecutor (inner call)
    // 4. Assert: inner call succeeds (no reentrancy revert)
}
```

This test should:
- Run against the pinned Nexus commit in `lib/nexus`
- Be in CI (fails loudly on submodule update)
- Be documented in the FlashLoanRouter's NatSpec as a deployment prerequisite

---

## C2: Reentrancy Surface During Flash Loan Inner Ops

### The Problem

During a flash loan callback, the FlashLoanRouter calls `account.executeFromExecutor(CALLTYPE_BATCH, innerExecutions)`. Those inner ops execute as the account. A malicious external contract reached during inner ops could attempt to re-enter the system.

The FlashLoanRouter's transient storage state machine (`isInFlashLoan`, `currentBorrower`, etc.) is the **sole reentrancy guard** for the flash loan execution path. It prevents nested flash loans but does NOT prevent inner ops from interacting with other executor modules on the same account.

### Attack Surface: SuperExecutor Re-Entry

**Call chain during flash loan:**
```
User → Account.execute(SuperExecutor.execute(entry))
  → SuperExecutor.execute(entry)                          [no nonReentrant]
    → SuperExecutor._execute(account, entry)
      → SuperExecutor._processHook(account, hook, ...)    [nonReentrant ACQUIRED on SuperExecutor instance]
        → hook.setExecutionContext(account)                [sets lastCaller = SuperExecutor]
        → SuperExecutor._execute(account, executions)      [calls account.executeFromExecutor]
          → Account.executeFromExecutor(batch executions)
            → execution[i]: router.executeFlashLoan(...)
              → provider.flashLoan(...)
                → router callback
                  → account.executeFromExecutor(innerOps)  [Nexus allows — no reentrancy guard]
                    → MALICIOUS INNER OP: ???
```

### Question: Can a malicious inner op call SuperExecutor.processHooks?

**Trace the re-entry attempt:**

A malicious inner execution targets `SuperExecutor.execute(forgedEntry)`. The account calls `SuperExecutor.execute()` (line 108):

```solidity
function execute(bytes calldata data) external virtual {
    if (!_initialized[msg.sender]) revert NOT_INITIALIZED();  // ← passes (account IS initialized)
    _execute(msg.sender, abi.decode(data, (ExecutorEntry)));   // ← calls _processHook
}
```

But wait — this is called via `account.executeFromExecutor`. The FlashLoanRouter calls `account.executeFromExecutor(CALLTYPE_BATCH, innerOps)`. Nexus's `executeFromExecutor` uses regular `call()` to execute each target in the batch (confirmed: `ExecutionHelper._execute` uses `call(gas(), target, value, ...)`, not `delegatecall`).

**However**: inner ops from `executeFromExecutor` are raw `(target, value, calldata)` tuples. The account calls `target.call{value}(calldata)` directly. It does NOT go through `SuperExecutor.execute()` — it calls the target directly.

So for a malicious inner op to hit `SuperExecutor.execute()`, it would need:
- `target = address(SuperExecutor)`
- `calldata = abi.encodeCall(SuperExecutor.execute, forgedEntry)`

The account would then call `SuperExecutor.execute(forgedEntry)`. Inside:
1. `_initialized[msg.sender]` → `msg.sender` is the account → passes ✓
2. `_execute(account, entry)` → iterates hooks
3. `_processHook(account, hook, ...)` → **`nonReentrant` check**

**The `nonReentrant` on `_processHook` IS still held** from the outer call. Same SuperExecutor contract instance, same OZ ReentrancyGuard storage slot. The re-entry REVERTS with `ReentrancyGuardReentrantCall()`.

### But `execute()` Itself Has NO `nonReentrant`

Critical observation: `SuperExecutor.execute()` at line 108 does **NOT** have `nonReentrant`. Only `_processHook()` at line 307 does.

The `execute()` function:
1. Checks `_initialized[msg.sender]` → passes
2. Calls `_execute(account, entry)` which iterates hooks and calls `_processHook` for each

So `execute()` can be entered, the `_initialized` check passes, and then it calls `_processHook` which reverts due to the reentrancy guard. **The attack is blocked at the `_processHook` level, not at the `execute()` level.**

This means a malicious inner op calling `SuperExecutor.execute()` would revert, which would revert the entire inner ops batch, which would revert the flash loan callback, which would revert the entire transaction. **The attack is closed, but the failure mode is a full transaction revert** (griefing/DoS of the flash loan, not state corruption).

### What About Other SuperExecutor Functions?

Functions on SuperExecutorBase accessible during inner ops:

| Function | Has nonReentrant? | Accessible via inner op? | Risk |
|----------|-------------------|--------------------------|------|
| `execute(bytes)` | **NO** | YES (if account is initialized) | Enters, then reverts at `_processHook` |
| `_processHook(...)` | **YES** | No (internal) | Blocked by reentrancy guard |
| `validateHookCompliance(...)` | No (view) | YES (but view-only, no state change) | None |
| `onInstall(bytes)` | **NO** | YES (msg.sender = account) | Could re-initialize — but account is already initialized → reverts `ALREADY_INITIALIZED` |
| `onUninstall(bytes)` | **NO** | YES (msg.sender = account) | **DANGEROUS**: Could uninstall SuperExecutor mid-flight. After uninstall, `_initialized[account] = false`. When the outer `_processHook` tries to continue, subsequent hooks would... still execute because the check is only in `execute()`, not `_processHook`. But `resetExecutionState` and `_updateAccounting` would still run. |

**`onUninstall` is the concerning one.** A malicious inner op could call `SuperExecutor.onUninstall("")` with `msg.sender = account`. This sets `_initialized[account] = false`. After the flash loan completes and execution returns to the outer `_processHook` loop, subsequent hooks still process (no `_initialized` check inside `_processHook`). But any future execution attempts on this SuperExecutor would fail with `NOT_INITIALIZED`.

This is a griefing vector, not a state corruption vector. The transaction would complete (all hooks process), but the account's SuperExecutor is now uninstalled. The account owner would need to re-install it.

**Mitigation**: Inner ops are user-signed (part of the UserOp). A user signing inner ops that uninstall their own executor is self-inflicted. But if inner ops interact with a malicious external contract that has been granted executor rights... this needs more analysis.

### The Deeper Question: Cross-Executor State Interleaving

The user's core concern: "can a malicious inner op call SuperExecutor.processHooks with a forged calldata, reusing the still-live SuperExecutor state?"

**SuperExecutor state during `_processHook`:**
1. `ReentrancyGuard._status` = `_ENTERED` (storage, locked)
2. `hook.lastCaller` = `address(SuperExecutor)` (transient on hook contract)
3. Hook's execution context (transient on hook contract)
4. Hook's pre/post execute mutexes (transient on hook contract)

If a malicious inner op calls a DIFFERENT function on SuperExecutor (not `_processHook`), it could potentially read the hook's state or the execution context. But:
- The hook's transient state is on the HOOK contract, not on SuperExecutor
- SuperExecutor doesn't store inter-hook state (it's all in function args and local variables)
- The `prevHook` chain is in local memory, not storage

**Conclusion on cross-executor interleaving**: SuperExecutor's `_processHook` reentrancy guard blocks re-entry to the hook processing loop. The hook chain state is in local memory and transient storage on hook contracts (not accessible via SuperExecutor). No cross-call interleaving of hook chains is possible.

### What nonReentrant on SuperExecutorBase Prevents (Enumeration)

The user asked: "enumerate the attacks [nonReentrant] prevents and verify each remains closed when a second principal (FlashLoanRouter) is also calling executeFromExecutor."

| Attack | How nonReentrant Prevents It | Still Closed During Flash Loan? |
|--------|-----------------------------|---------------------------------|
| **Double-processing a hook chain** | Re-entering `_processHook` in the middle of processing reverts | **YES** — FlashLoanRouter doesn't call `_processHook`, and a malicious inner op hitting `execute()` would revert at `_processHook` |
| **Interleaving two hook chains** | Can't start a second `_processHook` while one is running | **YES** — same reason |
| **Double-spend via nested processHooks** | Can't re-enter `_processHook` to process the same outflow hook twice | **YES** — `_processHook` reentrancy guard blocks it |
| **Manipulating hook transient state mid-execution** | `_processHook` holds the lock during hook.setExecutionContext → executions → hook.resetExecutionState | **YES** — transient state is on the hook contract, and the mutex lifecycle completes before returning |
| **Re-entering `_updateAccounting` with stale hook state** | `_updateAccounting` runs inside `_processHook`'s nonReentrant scope | **YES** — can't re-enter `_processHook` to trigger a second `_updateAccounting` |

**All attacks remain closed.** The FlashLoanRouter operates through a different executor module path (`account.executeFromExecutor` via FlashLoanRouter), which doesn't interact with SuperExecutor's state at all. The only overlap is they both call `account.executeFromExecutor`, and Nexus processes these as independent calls.

---

## Summary of Findings

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| **C1** | Nexus `executeFromExecutor` no-reentrancy-guard is observed behavior, not a written invariant. Future Nexus upgrade could break all flash loan flows silently. | **P2 Medium** (operational risk) | **Requires CI property test** |
| **C2a** | FlashLoanRouter transient storage is sole reentrancy guard for flash loan path. Re-entry to `SuperExecutor._processHook` is blocked by OZ ReentrancyGuard (same instance). | **P3 Low** (closed by existing guard) | Verified closed |
| **C2b** | `SuperExecutor.onUninstall` callable as inner op — could uninstall executor mid-flight. Self-inflicted (user signs inner ops). | **P3 Low** (griefing, self-inflicted) | Document in NatSpec |
| **C2c** | All 5 enumerated attacks that `nonReentrant` prevents remain closed during flash loan inner ops execution. | **Informational** | Verified closed |
| **C2d** | Malicious inner op hitting `SuperExecutor.execute()` causes full tx revert (reentrancy guard fires at `_processHook` level), not state corruption. | **P3 Low** (DoS of single tx) | Acceptable — inner ops are user-signed |

## Action Items

1. **[MUST]** Write CI property test for C1 (Nexus executeFromExecutor nested call invariant)
2. **[SHOULD]** Document C1 dependency in FlashLoanRouter NatSpec and deployment prerequisites
3. **[SHOULD]** Document that inner ops must not target SuperExecutor (validate in hook's `inspect()` or bundler-side)
4. **[COULD]** Add inner ops validation in FlashLoanRouter to reject executions targeting any installed executor module (defense in depth)
