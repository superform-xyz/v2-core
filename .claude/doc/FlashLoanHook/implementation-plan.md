# Flash Loan Hook for Superform v2-core -- Implementation Plan

## Date: 2026-04-27
## Author: superform-hook-master (Claude Opus 4.6)
## Status: PROPOSAL -- Awaiting Review

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Architecture Analysis](#2-architecture-analysis)
3. [Approach Evaluation](#3-approach-evaluation)
4. [Recommended Architecture: Approach A -- DelegateCall-Based FlashLoanAction](#4-recommended-architecture)
5. [Detailed Implementation Plan](#5-detailed-implementation-plan)
6. [Files to Create](#6-files-to-create)
7. [Files to Modify](#7-files-to-modify)
8. [Security Analysis](#8-security-analysis)
9. [Testing Strategy](#9-testing-strategy)
10. [Deployment Integration](#10-deployment-integration)
11. [Open Questions](#11-open-questions)

---

## 1. Problem Statement

Flash loans require a **callback pattern** that is fundamentally incompatible with Superform's flat `Execution[]` model:

```
Normal Hook Flow:
  Executor -> hook.build() -> [preExecute, op1, op2, ..., postExecute] -> account.executeFromExecutor(BATCH)

Flash Loan Flow Required:
  1. Call flashLoan(receiver, token, amount, data)
  2. Provider sends tokens to receiver
  3. Provider calls callback on receiver (e.g., onFlashLoan)
  4. INSIDE the callback: receiver uses tokens AND ensures repayment
  5. After callback returns: provider verifies repayment
```

The critical issue: operations must execute **inside** a callback, but `_buildHookExecutions` returns a flat array of `Execution` structs that the smart account executes sequentially via `CALLTYPE_BATCH`. There is no way to express "execute these operations inside a callback" in the current Execution[] model.

---

## 2. Architecture Analysis

### 2.1 Current Execution Flow (Critical Path)

```
SuperExecutorBase._processHook(account, hook, prevHook, hookData)
  |
  +-> validateHookCompliance(hook, prevHook, account, hookData)
  |     |
  |     +-> hook.build(prevHook, account, hookData)  // VIEW function
  |     |     returns Execution[] = [preExecute, ...ops..., postExecute]
  |     |
  |     +-> Validates: first = preExecute, last = postExecute
  |     +-> Validates: NO middle executions target the hook itself
  |     returns Execution[]
  |
  +-> hook.setExecutionContext(account)
  |
  +-> _execute(account, executions)  // calls IERC7579Account.executeFromExecutor(CALLTYPE_BATCH, ...)
  |     |
  |     +-> Nexus.executeFromExecutor(mode, executionCalldata)
  |           |-- onlyExecutorModule (SuperExecutor must be installed)
  |           |-- withHook (Nexus hook module, NOT Superform hooks)
  |           |-- withRegistry
  |           |
  |           +-> _handleBatchExecutionAndReturnData(executionCalldata, execType)
  |                 +-> for each execution: _execute(target, value, callData)  // regular CALL
  |
  +-> hook.resetExecutionState(account)
  +-> _updateAccounting(account, hook, hookData)
```

### 2.2 Key Constraints Identified From Code

1. **`build()` is `view`**: Cannot perform state changes; must return a static Execution[] array.

2. **`validateHookCompliance` enforcement** (SuperExecutorBase.sol L116-147):
   - First execution MUST be `preExecute` targeting the hook
   - Last execution MUST be `postExecute` targeting the hook
   - NO middle execution may target the hook itself
   - This prevents the hook from calling itself during execution

3. **Execution is CALLTYPE_BATCH** (ERC7579ExecutorBase.sol L57-73):
   - All executions run as regular `CALL` from the smart account
   - The smart account is `msg.sender` for all calls
   - No nested execution capability in batch mode

4. **Nexus supports CALLTYPE_DELEGATECALL** (Nexus.sol L183-186):
   - `executeFromExecutor` accepts `CALLTYPE_DELEGATECALL`
   - Runs code in the smart account's context
   - `ERC7579ExecutorBase._executeDelegateCall()` exists but is UNUSED in Superform executors

5. **Nexus Fallback Handlers** (ModuleManager.sol L305-348, L652-691):
   - Can install fallback handlers for specific selectors: `installModule(MODULE_TYPE_FALLBACK, handler, abi.encode(selector, calltype))`
   - Calltype restricted to `CALLTYPE_SINGLE` or `CALLTYPE_STATIC` only
   - Handler is called via `handler.call{value: msg.value}(get2771CallData(callData))` -- a regular CALL, NOT delegatecall
   - Appends msg.sender (the external caller) to calldata for ERC-2771 context
   - This means: the handler runs in its OWN context, not the smart account's

6. **Morpho flashLoan specifics** (IMorpho.sol L288-292):
   - Morpho sends tokens to `msg.sender` (the caller of `flashLoan`)
   - Morpho calls `onMorphoFlashLoan` on `msg.sender`
   - So if the smart account calls `morpho.flashLoan(...)`, the callback arrives AT the smart account

7. **`_processHook` has `nonReentrant`** (SuperExecutorBase.sol L308):
   - The entire hook processing is wrapped in `nonReentrant`
   - This prevents re-entering the executor during a flash loan callback

---

## 3. Approach Evaluation

### 3.1 Approach A: DelegateCall-Based FlashLoanAction

**Concept**: The hook returns a SINGLE execution that instructs the smart account to delegatecall a `FlashLoanAction` contract. This action contract:
- Runs in the smart account's context (has its storage, balance, address)
- Initiates the flash loan with `receiver = address(this)` (which is the smart account due to delegatecall)
- The flash loan provider sends tokens to the smart account
- The callback (e.g., `onFlashLoan`) arrives at the smart account
- A Nexus fallback handler routes the callback to a `FlashLoanCallbackHandler`
- The handler executes the inner operations and ensures repayment

**Problem**: The executor uses `_execute(account, executions)` which calls `executeFromExecutor(CALLTYPE_BATCH, ...)`. There is NO way for a single hook to return an Execution[] that includes a delegatecall -- the current `_execute` method always uses CALLTYPE_BATCH which runs individual executions as regular CALLs.

**Could we modify the executor?** Yes, but:
- `validateHookCompliance` would need changes
- The entire hook lifecycle (preExecute -> batch -> postExecute) model breaks
- Very invasive change

**Verdict**: PARTIALLY VIABLE but requires executor changes. Not ideal.

### 3.2 Approach B: Hook-as-Receiver

**Concept**: The hook contract itself implements callback interfaces and serves as the flash loan receiver.

**Problem**: The hook receives the tokens, but it cannot execute operations on behalf of the smart account. The hook is not an installed executor module, so it cannot call `executeFromExecutor`. Even if it were, re-entering the executor is blocked by `nonReentrant`.

**Verdict**: NOT VIABLE in its simple form.

### 3.3 Approach C: Modify the Executor

**Concept**: Add a new execution mode to SuperExecutorBase that supports nested callbacks.

**Problem**: Requires changes to the audited executor code, the hook compliance validation, and fundamentally changes the execution model. Too invasive.

**Verdict**: TOO INVASIVE for a hook feature.

### 3.4 Approach D: Standalone Flash Loan Executor Module

**Concept**: Create a separate ERC-7579 executor module (`FlashLoanExecutor`) that:
1. Implements callback interfaces (IERC3156FlashBorrower, IFlashLoanRecipient, etc.)
2. Is installed as an executor on the smart account
3. The flash loan hook returns an Execution that calls the FlashLoanExecutor
4. The FlashLoanExecutor initiates the flash loan, receives the callback, executes inner operations, and handles repayment

**Problem**: Executor modules can call `executeFromExecutor` on the smart account, but the FlashLoanExecutor itself is not the smart account -- it runs in its own context. When the smart account calls `flashLoanExecutor.executeFlashLoan(...)`, the executor runs in its own address space, not the smart account's. So `flashLoan(receiver=address(this))` would point to the executor, not the smart account.

**BUT**: The executor COULD call `executeFromExecutor` to make the smart account call `flashLoan(receiver=smartAccount)`. However, then the callback comes to the smart account, not the executor. We're back to needing a fallback handler.

**Verdict**: PARTIALLY VIABLE when combined with a fallback handler.

### 3.5 Approach E: FlashLoanAction via DelegateCall from Smart Account (RECOMMENDED)

This is a refined version of Approach A that works WITHIN the existing hook system by having the hook emit a single execution: the smart account calls a `FlashLoanRouter` contract, which orchestrates everything externally.

**ACTUALLY -- the cleanest approach that needs ZERO executor modifications:**

**The "Router" Pattern (Approach E)**:

```
1. Hook.build() returns Execution[]:
   [preExecute, approve(token, flashLoanRouter, amount+fee), router.executeFlashLoan(...), postExecute]

2. FlashLoanRouter.executeFlashLoan() is called BY the smart account (regular CALL):
   - FlashLoanRouter stores msg.sender (=smartAccount) in transient storage
   - FlashLoanRouter calls flashLoanProvider.flashLoan(receiver=address(this), ...)
   - Provider sends tokens to FlashLoanRouter
   - Provider calls FlashLoanRouter.onFlashLoan(...) / receiveFlashLoan(...)

3. Inside the callback, FlashLoanRouter:
   - Has the borrowed tokens
   - Transfers tokens to the smart account
   - Executes pre-encoded inner operations by calling smart account via executeFromExecutor?
     NO -- FlashLoanRouter is NOT an executor module!
   - Instead: transfers tokens to smart account, that's it. Inner operations are SUBSEQUENT hooks.

4. After callback: FlashLoanRouter needs amount+fee back
   - Smart account already approved FlashLoanRouter for amount+fee
   - FlashLoanRouter pulls tokens back from smart account
   - FlashLoanRouter repays the flash loan provider
```

**Wait, this doesn't work for the core use case**. The whole point of flash loans is to USE the borrowed tokens for operations (like liquidations, arbitrage) and repay from the proceeds, all atomically. If the router just transfers tokens to the smart account, the inner operations need to happen BEFORE repayment. But the router's callback must return before the provider checks repayment.

**Let me reconsider...**

### 3.6 THE ACTUAL RECOMMENDED APPROACH: Two-Hook Pattern with FlashLoanRouter

After deep analysis, the simplest viable architecture is:

**Key Insight**: The flash loan callback requires nested execution, but we can SPLIT the flash loan into TWO phases and use the FlashLoanRouter as an intermediary that holds the callback logic. The inner operations are PRE-ENCODED and passed as data to the router.

```
FlashLoanRouter (standalone contract, NOT a hook, NOT an executor module):
  - Implements IERC3156FlashBorrower, IFlashLoanRecipient, etc.
  - Has executeFlashLoan(provider, token, amount, innerCalldata) function
  - Inside the callback:
    a. Receives borrowed tokens from provider
    b. Transfers borrowed tokens to the smart account (msg.sender from step 1)
    c. Calls back to the smart account to execute inner operations
    d. Smart account sends back amount+fee to router
    e. Router repays provider
```

**BUT**: Step (c) is the problem. The router cannot call `executeFromExecutor` because it's not an executor module. And even if it were, the `nonReentrant` guard blocks re-entry.

**FINAL RECOMMENDED APPROACH**: The router does NOT need to call back to the smart account for inner operations. Instead:

```
Hook Execution Flow:
  Hook 1: FlashLoanBorrowHook (NONACCOUNTING)
    build() returns:
      [preExecute,
       approve(token, router, amount + fee),     // pre-approve for repayment
       router.initiateFlashLoan(provider, token, amount, account),
       postExecute]

    The router:
      1. Calls provider.flashLoan(receiver=router, token, amount, ...)
      2. In callback: router transfers tokens to smart account (stored in transient)
      3. Callback returns (provider checks router has amount+fee -- NOT YET, just borrowed)

    WAIT -- this still doesn't work because the provider checks repayment AFTER callback.

Let me reconsider the ACTUAL flow of flash loan providers:

Morpho:
  - flashLoan(token, assets, data) on Morpho
  - Morpho sends tokens to msg.sender
  - Morpho calls onMorphoFlashLoan(assets, data) on msg.sender
  - After callback returns, Morpho checks token.balanceOf(morpho) >= pre + assets
  - So msg.sender must have transferred tokens BACK to Morpho before callback returns

Balancer:
  - flashLoan(recipient, tokens, amounts, userData)
  - Vault sends tokens to recipient
  - Vault calls receiveFlashLoan(tokens, amounts, feeAmounts, userData) on recipient
  - After callback returns, Vault checks balances

ERC-3156:
  - flashLoan(receiver, token, amount, data)
  - Lender sends tokens to receiver
  - Lender calls onFlashLoan(initiator, token, amount, fee, data) on receiver
  - After callback returns, lender pulls amount+fee from receiver via transferFrom
```

So in ALL cases, the receiver must:
1. Receive tokens
2. Use them (the whole point)
3. Ensure repayment amount is available BEFORE callback returns

This means inner operations MUST happen inside the callback. Period.

---

## 4. Recommended Architecture

### The FlashLoanRouter + Fallback Handler Approach

After exhaustive analysis, the cleanest approach that requires MINIMAL changes to the existing system:

### Architecture Overview

```
Components:
  1. FlashLoanHook (extends BaseHook) -- the Superform hook
  2. FlashLoanRouter (standalone contract) -- orchestrates the flash loan
  3. FlashLoanCallbackModule (ERC-7579 Fallback Module) -- handles callbacks on the smart account

Installation Required (one-time setup per smart account):
  - FlashLoanCallbackModule installed as FALLBACK handler for:
    - onFlashLoan selector (ERC-3156)
    - receiveFlashLoan selector (Balancer)
    - onMorphoFlashLoan selector (Morpho)
```

### Flow Diagram

```
Step 1: Hook builds Execution[]
  FlashLoanHook.build() returns:
    [0] preExecute (on hook)
    [1] token.approve(router, 0)                    // reset approval
    [2] token.approve(router, amount + maxFee)       // approve for repayment pull
    [3] router.executeFlashLoan(provider, providerType, token, amount, innerOpsData, account)
    [4] token.approve(router, 0)                    // cleanup approval
    [5] postExecute (on hook)

Step 2: Smart account executes batch
  Account calls router.executeFlashLoan(...) [execution #3]

Step 3: Router initiates flash loan
  router stores:
    - caller = msg.sender (smart account) in transient storage
    - innerOpsData in transient storage
  router calls: provider.flashLoan(receiver=address(router), token, amount, ...)

Step 4: Provider sends tokens to router

Step 5: Provider calls callback on router
  router.onFlashLoan(...) / router.receiveFlashLoan(...)
  Inside callback:
    a. Router transfers borrowed tokens to smart account
    b. Router calls smartAccount.onFlashLoan(...)
       (This hits the Nexus FALLBACK handler)
    c. Fallback handler (FlashLoanCallbackModule) receives the call
       FlashLoanCallbackModule decodes innerOpsData from the call
       FlashLoanCallbackModule executes inner operations:
         - For each inner op: call target with calldata (the module runs as CALLTYPE_SINGLE)

    PROBLEM: Fallback handler runs via handler.call(...), NOT in the smart account's context!
    The fallback handler CANNOT execute transactions on behalf of the smart account.

    From ModuleManager._fallback():
      handler.call{ value: msg.value }(ExecLib.get2771CallData(callData))
    This calls the handler contract, which runs in its OWN context, not the account's.
```

**This doesn't work either.** The fallback handler approach fails because the handler runs in its own context, not the smart account's.

---

### REVISED ARCHITECTURE: The DelegateCall Action Pattern

After analyzing ALL approaches, here is the ONLY viable pattern that requires MINIMAL changes:

**Key Insight from Nexus.sol L195-201**:
```solidity
function executeUserOp(PackedUserOperation calldata userOp, bytes32)
    external payable virtual onlyEntryPoint withHook
{
    bytes calldata callData = userOp.callData[4:];
    (bool success, bytes memory innerCallRet) = address(this).delegatecall(callData);
    if (!success) { revert ExecutionFailed(); }
}
```

Nexus already does `delegatecall` to itself in `executeUserOp`. This means delegatecall is a proven pattern in Nexus.

**And from ERC7579ExecutorBase.sol L80-97**:
```solidity
function _executeDelegateCall(
    address account,
    address delegateTarget,
    bytes memory callData
) internal returns (bytes[] memory results) {
    ModeCode modeCode = ERC7579ModeLib.encode({
        callType: CALLTYPE_DELEGATECALL,
        execType: EXECTYPE_DEFAULT,
        mode: MODE_DEFAULT,
        payload: ModePayload.wrap(bytes22(0))
    });
    results = IERC7579Account(account).executeFromExecutor(
        modeCode, abi.encodePacked(delegateTarget, callData)
    );
}
```

The executor CAN issue delegatecall instructions. It just doesn't currently.

### THE PLAN: Modify SuperExecutorBase to support a new hook type + FlashLoanAction via delegatecall

**Actually, let me reconsider once more.** The hook's `build()` function returns `Execution[]` which the executor processes via `_execute(account, executions)` using `CALLTYPE_BATCH`. There is no way to make ONE execution in the batch be a delegatecall while others are regular calls.

But what if we DON'T change the executor at all? What if the hook's Execution[] includes a call to the smart account itself that triggers a delegatecall?

**From Nexus.sol L149**:
```solidity
function execute(ExecutionMode mode, bytes calldata executionCalldata)
    external payable onlyEntryPoint withHook { ... }
```

This is `onlyEntryPoint` -- can't use it.

**BUT**: `executeFromExecutor` at L167 is `onlyExecutorModule`. The SuperExecutor IS an installed executor module. So could the batch include:

```
execution[i] = Execution({
    target: account,  // call the account itself
    value: 0,
    callData: abi.encodeCall(
        IERC7579Account.execute,
        (delegateCallMode, abi.encodePacked(flashLoanAction, actionCalldata))
    )
})
```

**No** -- `Nexus.execute()` is `onlyEntryPoint`, not callable by the account itself during a batch.

What about making the account call `executeFromExecutor` on itself? No, that's circular.

---

### FINAL ARCHITECTURE (The Simplest That Actually Works)

After exhaustive analysis of every possible path through the code, I conclude that the cleanest approach requires a **small, surgical modification** to `SuperExecutorBase` to add delegatecall support for a new "FLASH_LOAN" hook processing mode. Here is why and how:

**Why modification is needed**: Flash loans fundamentally require nested execution (operations inside a callback). The current flat Execution[] batch model cannot express this. Every approach that avoids executor modification either (a) requires the smart account to have callback handling capability it doesn't have, or (b) requires an external contract to execute operations on behalf of the smart account, which it cannot do.

**The minimal change**: Add a method to SuperExecutorBase that allows processing a hook via delegatecall instead of batch call. The delegatecall target (`FlashLoanAction`) runs in the smart account's context and can therefore:
- Initiate flash loans where `msg.sender` IS the smart account
- Handle callbacks that arrive at the smart account (since the code is running there)
- Execute arbitrary operations with the smart account's tokens
- Repay the flash loan

### Architecture Components

```
1. FlashLoanHook (BaseHook)
   - Standard Superform hook
   - build() returns special execution data that signals "use delegatecall"
   - hook type: NONACCOUNTING

2. FlashLoanAction (library-like contract, deployed once)
   - Contains the flash loan logic
   - Implements callback interfaces
   - Designed to be delegatecalled by smart accounts
   - Executes inner operations during the callback
   - Handles token approvals and repayment

3. SuperExecutorBase modification (MINIMAL)
   - Add _processDelegateCallHook() method alongside _processHook()
   - OR: Detect hook subtype and use delegatecall for FLASH_LOAN hooks
```

---

## 5. Detailed Implementation Plan

### Phase 0: Decision Point -- Executor Modification Scope

**Option 1 (RECOMMENDED): Minimal Executor Change**

Add a new internal method `_processFlashLoanHook` to `SuperExecutorBase` that:
- Calls `hook.build()` to get hook data (not Execution[])
- Calls `hook.setExecutionContext(account)`
- Calls `hook.preExecute()`
- Uses `_executeDelegateCall(account, flashLoanAction, actionCalldata)` to delegatecall the action
- Calls `hook.postExecute()`
- Calls `hook.resetExecutionState(account)`
- Updates accounting

The hook would need a way to signal that it should be processed via delegatecall. This could be:
- A new HookType (e.g., `FLASH_LOAN`)
- A new interface method `requiresDelegateCall() returns (bool)`
- Checking the hook's subtype (e.g., `HookSubTypes.FLASH_LOAN`)

**Option 2 (ALTERNATIVE): No Executor Change -- Router Pattern**

If executor modification is absolutely off-limits, we can use a **FlashLoanRouter** pattern where:
- The router is an installed EXECUTOR MODULE on the smart account
- The hook calls the router, the router initiates the flash loan
- The router receives the callback
- Inside the callback, the router calls `executeFromExecutor` on the smart account to execute inner operations
- This works but hits the `nonReentrant` guard on SuperExecutorBase

**Wait** -- the router is a SEPARATE executor module, not SuperExecutor. It would call `account.executeFromExecutor()` directly. The `nonReentrant` is on SuperExecutorBase, but the router's call goes through Nexus's `executeFromExecutor` which checks `onlyExecutorModule`. The `nonReentrant` is an instance variable on SuperExecutor, NOT on the Nexus account. So the router calling `executeFromExecutor` would NOT be blocked by SuperExecutor's reentrancy guard.

**THIS IS THE KEY INSIGHT.** Let me verify...

From SuperExecutorBase.sol:
```solidity
abstract contract SuperExecutorBase is ERC7579ExecutorBase, ISuperExecutor, ReentrancyGuard {
```

`ReentrancyGuard` is from OpenZeppelin. Its `_status` variable lives in the SuperExecutorBase contract's storage. When the FlashLoanRouter (a different contract) calls `account.executeFromExecutor()`, it goes through Nexus's `onlyExecutorModule` check, NOT through SuperExecutorBase. So there is NO reentrancy conflict!

### REVISED FINAL ARCHITECTURE: FlashLoanRouter as Separate Executor Module (NO EXECUTOR CHANGES NEEDED)

#### Design Decision: Push-Only Token Flow

The router never holds `transferFrom` authority over the smart account's balance. All token movement is push-based:
- Router pushes borrowed tokens TO the account
- Inner ops push repayment (amount + fee) BACK to the router
- Router repays provider (approve-based or push-based per provider)

This eliminates the approve sandwich (no `approve(router, amount+fee)` / `approve(router, 0)` in the hook batch), reducing the hook from 6 to 3 executions.

#### Design Decision: Hash-Commit Transient Storage

`TSTORE` only supports value types. `bytes innerExecutions` cannot be stored in transient storage. Solution:

- **S1)** In `executeFlashLoan`: TSTORE a single 32-byte hash:
  `tHash = keccak256(abi.encode(caller, provider, token, amount, keccak256(innerOps)))`
- **S2)** Pass the actual `(caller, provider, token, amount, innerOps)` blob as the `data` parameter into the provider's flash loan function (provider passes it through to callback unchanged)
- **S3)** In callback: decode `data`, recompute hash, TLOAD stored hash, compare. Only proceed if equal.
- **S4)** Clear the slot before exiting (explicit clear for same-tx correctness; TSTORE auto-clears at end of tx regardless)

The "context already set" check (non-zero tHash) IS the reentrancy guard. No separate `isInFlashLoan` bool needed.

#### Design Decision: No Nested Flash Loans (v1)

Nested flash loans (e.g., atomic debt migration: flashloan A → [ops + flashloan B → repay B] → repay A) would require a depth-keyed map (`mapping(uint256 depth => bytes32 hash)` via manual TSTORE slot math). This adds complexity for a use case that can be deferred.

**v1 enforces single-depth flash loans via hard revert when tHash is already set.** Document as known limitation.

```
Components:
  1. FlashLoanHook (BaseHook, NONACCOUNTING)
  2. FlashLoanRouter (ERC-7579 Executor Module, implements flash loan callbacks)

Installation (one-time per smart account):
  - FlashLoanRouter installed as an executor module (MODULE_TYPE_EXECUTOR)

Flow:
  Hook.build() returns:
    [0] preExecute
    [1] flashLoanRouter.executeFlashLoan(providerType, provider, token, amount, innerOps)
    [2] postExecute

  Inside router.executeFlashLoan() [called by smart account]:
    S1. Guard: if (tHash != 0) revert NESTED_FLASH_LOAN_NOT_SUPPORTED()
    S2. Compute and TSTORE: tHash = keccak256(abi.encode(msg.sender, provider, token, amount, keccak256(innerOps)))
    S3. Encode passthrough: data = abi.encode(msg.sender, provider, token, amount, innerOps)
    S4. Call provider based on providerType:
        - MORPHO:   IMorpho(provider).flashLoan(token, amount, data)
        - AAVE_V3:  IPool(provider).flashLoanSimple(address(this), token, amount, data, 0)
        - ERC3156:  IERC3156FlashLender(provider).flashLoan(this, token, amount, data)
        - BALANCER:  IBalancerVault(provider).flashLoan(this, [token], [amount], data)
    S5. Clear tHash (TSTORE 0) -- explicit clear for same-tx correctness

  Provider sends tokens to router.
  Provider calls callback on router:
    router.onMorphoFlashLoan() / executeOperation() / onFlashLoan() / receiveFlashLoan():
      T1. Decode (caller, provider, token, amount, innerOps) from data
      T2. Recompute hash, TLOAD tHash, verify match → revert if mismatch
      T3. Push borrowed tokens: IERC20(token).transfer(caller, amount)
      T4. Execute inner ops: _execute(caller, innerOps)
          -- Router IS an installed executor, so this works!
          -- Nexus has NO reentrancy guard on executeFromExecutor
          -- SuperExecutor's nonReentrant is on a different contract instance
          -- Last inner op: token.transfer(router, amount + fee)  ← user-encoded push-back
      T5. Repay provider (per-provider branch):
          - Morpho/Aave/ERC-3156: token.forceApprove(provider, amount + fee) → provider pulls
          - Balancer: token.transfer(vault, amount + fee) → push-based
      T6. Return success value (provider-specific)
```

**Key properties:**
- Router never holds transferFrom authority over the account's existing balance
- Router only holds tokens transiently during callback (borrowed amount arrives, gets pushed to account, repayment arrives back)
- tHash serves as both context integrity check AND reentrancy guard
- Inner ops are user-signed (part of UserOp) — router trusts them by design
- If inner ops don't push back enough, provider's repayment check fails and entire tx reverts

**Nexus compatibility confirmed:**
- `executeFromExecutor` has NO reentrancy guard (Nexus.sol L167-189)
- `withHook` modifier calls Nexus-level preCheck/postCheck — benign for standard setups
- `onlyExecutorModule` checks `executors.contains(msg.sender)` — passes because router IS installed
- `validateHookCompliance` passes: hook batch targets router (not the hook itself)

**CONFIRMED: This architecture is viable with ZERO changes to the existing executor or hook base.**

---

## 5. Detailed Implementation Plan (Revised)

### Phase 1: Interface Definitions

#### 5.1 Flash Loan Provider Interface Abstraction

Create a unified interface that the router uses internally to support multiple flash loan providers:

```solidity
// src/hooks/flashloan/interfaces/IFlashLoanProvider.sol
enum FlashLoanProviderType {
    ERC3156,        // ERC-3156 (Maker, many ERC20s)
    BALANCER_V2,    // Balancer Vault
    MORPHO,         // Morpho Blue
    AAVE_V3         // Aave V3 Pool
}
```

### Phase 2: FlashLoanRouter (ERC-7579 Executor Module)

Core component. Installed as executor module on smart accounts. Orchestrates flash loan operations using hash-commit transient storage and push-only token flow.

```solidity
// src/hooks/flashloan/FlashLoanRouter.sol

contract FlashLoanRouter is
    ERC7579ExecutorBase,
    IMorphoFlashLoanCallback,
    IFlashLoanSimpleReceiver,
    IERC3156FlashBorrower,
    IFlashLoanRecipient
{
    using SafeERC20 for IERC20;

    // ── Transient storage: single 32-byte hash-commit ──
    // Serves as BOTH context integrity check AND reentrancy guard.
    // Non-zero tHash means a flash loan is in progress.
    bytes32 transient tHash;

    // ── Entry point (called by smart account via SuperExecutor batch) ──

    function executeFlashLoan(
        FlashLoanProviderType providerType,
        address provider,
        address token,
        uint256 amount,
        bytes calldata innerExecutions
    ) external {
        // S1. Reentrancy guard: tHash != 0 means nested flash loan attempt
        if (tHash != bytes32(0)) revert NESTED_FLASH_LOAN_NOT_SUPPORTED();

        // S2. Hash-commit: store context fingerprint
        tHash = keccak256(abi.encode(msg.sender, provider, token, amount, keccak256(innerExecutions)));

        // S3. Encode passthrough data (provider forwards to callback unchanged)
        bytes memory data = abi.encode(msg.sender, provider, token, amount, innerExecutions);

        // S4. Dispatch to provider
        if (providerType == FlashLoanProviderType.MORPHO) {
            IMorpho(provider).flashLoan(token, amount, data);
        } else if (providerType == FlashLoanProviderType.AAVE_V3) {
            IPool(provider).flashLoanSimple(address(this), token, amount, data, 0);
        } else if (providerType == FlashLoanProviderType.ERC3156) {
            IERC3156FlashLender(provider).flashLoan(this, token, amount, data);
        } else if (providerType == FlashLoanProviderType.BALANCER_V2) {
            address[] memory tokens_ = new address[](1);
            tokens_[0] = token;
            uint256[] memory amounts_ = new uint256[](1);
            amounts_[0] = amount;
            IBalancerVault(provider).flashLoan(this, tokens_, amounts_, data);
        } else {
            revert UNSUPPORTED_PROVIDER_TYPE();
        }

        // S5. Clear tHash (explicit clear for same-tx-multiple-flashloan correctness)
        tHash = bytes32(0);

        emit FlashLoanExecuted(msg.sender, provider, token, amount);
    }

    // ── Shared callback logic ──

    function _handleCallback(
        address expectedProvider,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) internal {
        // T1. Decode passthrough data
        (address caller, address provider, address token, uint256 amt, bytes memory innerOps) =
            abi.decode(data, (address, address, address, uint256, bytes));

        // T2. Verify hash-commit integrity
        bytes32 expected = keccak256(abi.encode(caller, provider, token, amt, keccak256(innerOps)));
        if (tHash != expected) revert INVALID_FLASH_LOAN_CONTEXT();
        if (msg.sender != expectedProvider) revert UNAUTHORIZED_CALLBACK();

        // T3. Push borrowed tokens to smart account
        IERC20(token).safeTransfer(caller, amount);

        // T4. Execute inner ops on smart account
        // Last inner op MUST push (amount + fee) back to this router
        Execution[] memory executions = abi.decode(innerOps, (Execution[]));
        _execute(caller, executions);

        // T5. Repay provider (per-provider branch in each callback below)
    }

    // ── Provider-specific callbacks (thin wrappers) ──

    // Morpho: tokens sent to msg.sender (router). Provider pulls via transferFrom.
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        _handleCallback(msg.sender, assets, 0, data);
        // T5: Morpho pulls amount via transferFrom
        IERC20(_decodeToken(data)).forceApprove(msg.sender, assets);
    }

    // Aave V3: tokens sent to receiver (router). Provider pulls via transferFrom.
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (initiator != address(this)) revert INVALID_INITIATOR();
        _handleCallback(msg.sender, amount, premium, params);
        // T5: Aave pulls (amount + premium) via transferFrom
        IERC20(asset).forceApprove(msg.sender, amount + premium);
        return true;
    }

    // ERC-3156: tokens sent to receiver (router). Provider pulls via transferFrom.
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        if (initiator != address(this)) revert INVALID_INITIATOR();
        _handleCallback(msg.sender, amount, fee, data);
        // T5: Lender pulls (amount + fee) via transferFrom
        IERC20(token).forceApprove(msg.sender, amount + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // Balancer V2: tokens sent to recipient (router). Borrower pushes repayment.
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        _handleCallback(msg.sender, amounts[0], feeAmounts[0], userData);
        // T5: Balancer is push-based — transfer directly back to vault
        tokens[0].safeTransfer(msg.sender, amounts[0] + feeAmounts[0]);
    }

    // ── Helper ──
    function _decodeToken(bytes calldata data) internal pure returns (address) {
        (, , address token, , ) = abi.decode(data, (address, address, address, uint256, bytes));
        return token;
    }

    // ── ERC-7579 module lifecycle ──
    // onInstall, onUninstall, isModuleType(TYPE_EXECUTOR), name, version
}
```

### Phase 3: FlashLoanHook (Superform Hook)

```solidity
// src/hooks/flashloan/FlashLoanHook.sol

contract FlashLoanHook is BaseHook, ISuperHookContextAware {
    address public immutable FLASH_LOAN_ROUTER;
    address public immutable VALIDATOR;

    // hook type: NONACCOUNTING
    // hook subtype: FLASH_LOAN (new constant)

    // Data layout (compact packed encoding):
    //   uint8   providerType      (offset 0,   1 byte)   -- FlashLoanProviderType enum
    //   address provider          (offset 1,  20 bytes)
    //   address token             (offset 21, 20 bytes)
    //   uint256 amount            (offset 41, 32 bytes)
    //   bool    usePrevHookAmount (offset 73,  1 byte)
    //   bytes   innerExecutions   (offset 74+, variable)  -- ABI-encoded Execution[]
    //
    // MIN_DATA_LENGTH = 74
    //
    // NOTE: No maxFee field. Push-only flow means the hook doesn't need to
    // approve the router for repayment. The user encodes the repayment
    // push (token.transfer(router, amount+fee)) as the last inner op.

    function _buildHookExecutions(...) returns (Execution[] memory) {
        // Decode data
        // If usePrevHookAmount, get amount from previous hook

        // Return 1 execution:
        // [0] router.executeFlashLoan(providerType, provider, token, amount, innerExecutions)

        // Total hook batch = pre + 1 + post = 3 executions
    }

    function _preExecute(...) internal {
        // Record token balance for outAmount tracking
    }

    function _postExecute(...) internal {
        // outAmount = balance delta (may be 0 for leverage ops)
    }

    function inspect(bytes calldata data) external view returns (bytes memory) {
        // Return addresses only: provider, token, FLASH_LOAN_ROUTER
        address provider = BytesLib.toAddress(data, 1);
        address token = BytesLib.toAddress(data, 21);
        return abi.encodePacked(provider, token, FLASH_LOAN_ROUTER);
    }
}
```

### Phase 4: Inner Operations Encoding

The `innerExecutions` field in the hook data contains pre-encoded `Execution[]` that will be executed by the FlashLoanRouter on behalf of the smart account during the flash loan callback. These are encoded off-chain by the SuperBundler.

**Critical convention**: The last inner execution MUST push `amount + fee` back to the router. The router does NOT pull tokens — all token flow is push-based.

Example use case -- leveraged Morpho position (fee = 0 for Morpho):
```
innerExecutions = [
    Execution(collateralToken, 0, approve(morpho, borrowedAmount)),
    Execution(morpho, 0, supplyCollateral(marketParams, borrowedAmount, account, "")),
    Execution(morpho, 0, borrow(marketParams, loanAmount, 0, account, account)),
    Execution(collateralToken, 0, approve(morpho, 0)),
    Execution(loanToken, 0, transfer(flashLoanRouter, borrowedAmount))  // push repayment back
]
```

If the provider charges a fee (Aave: `premium`, ERC-3156: `fee`), the last inner op must push `amount + fee`. The fee is known at encoding time (queryable via `flashFee()` or `FLASHLOAN_PREMIUM_TOTAL()`).

---

## 6. Files to Create

### 6.1 Source Files

```
src/hooks/flashloan/
  |-- interfaces/
  |     |-- IFlashLoanRouter.sol          -- Interface for the router + FlashLoanProviderType enum
  |-- FlashLoanRouter.sol                  -- ERC-7579 executor module + callback handler
  |-- FlashLoanHook.sol                    -- Superform hook (single executeFlashLoan call)
```

**Note**: No `ApproveAndFlashLoanHook` variant needed — push-only flow means the hook never approves the router. No separate library files. All logic consolidated in the router per the "Consolidation Over Fragmentation" principle.

### 6.2 Interface Files

```
src/vendor/flashloan/
  |-- IBalancerVault.sol                   -- Balancer flash loan interface (if not using modulekit)
  |-- IMorphoFlashLoan.sol                 -- Morpho flash loan callback interface
```

### 6.3 Test Files

```
test/unit/hooks/flashloan/
  |-- FlashLoanHookUnit.t.sol              -- Unit tests for hook build/decode logic
  |-- FlashLoanRouterUnit.t.sol            -- Unit tests for router callback logic

test/integration/flashloan/
  |-- FlashLoanIntegration.t.sol           -- Integration tests with real protocols on forks
```

---

## 7. Files to Modify

### 7.1 HookSubTypes.sol

**File**: `src/libraries/HookSubTypes.sol`

**Change**: Add new constant:
```solidity
bytes32 public constant FLASH_LOAN = keccak256(bytes("FlashLoan"));
```

### 7.2 Constants.sol (script)

**File**: `script/utils/Constants.sol`

**Change**: Add hook key:
```solidity
string internal constant FLASH_LOAN_HOOK_KEY = "FlashLoanHook";
string internal constant FLASH_LOAN_ROUTER_KEY = "FlashLoanRouter";
```

### 7.3 Constants.sol (test)

**File**: `test/utils/Constants.sol`

**Change**: Add test constants for flash loan provider addresses on various networks:
```solidity
// Morpho Blue mainnet
address public constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
// Balancer V2 Vault
address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
// Aave V3 Pool (Ethereum)
address public constant AAVE_V3_POOL_ETH = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
```

### 7.4 No Executor Changes Required

**SuperExecutorBase.sol**: NO CHANGES NEEDED. The flash loan inner operations go through the FlashLoanRouter's own `executeFromExecutor` calls, bypassing SuperExecutor entirely.

---

## 8. Security Analysis

### 8.1 Critical Security Considerations

**1. Reentrancy: Hash-Commit as Guard**

The `tHash` transient slot serves as both context integrity check AND reentrancy guard:
```solidity
function executeFlashLoan(...) external {
    if (tHash != bytes32(0)) revert NESTED_FLASH_LOAN_NOT_SUPPORTED();
    tHash = keccak256(abi.encode(msg.sender, provider, token, amount, keccak256(innerOps)));
    // ... flash loan ...
    tHash = bytes32(0);  // explicit clear for same-tx correctness
}
```
- Non-zero tHash blocks nested flash loans (v1 limitation, documented)
- tHash auto-clears at end of tx (TSTORE semantics), explicit clear is for same-tx-multiple-flashloan correctness
- The hash binds (caller, provider, token, amount, innerOps) — callback cannot be replayed with different parameters

**2. Callback Validation: Hash Recompute**

Each callback decodes the passthrough `data`, recomputes the hash, and verifies against TLOAD:
```solidity
bytes32 expected = keccak256(abi.encode(caller, provider, token, amt, keccak256(innerOps)));
if (tHash != expected) revert INVALID_FLASH_LOAN_CONTEXT();
if (msg.sender != expectedProvider) revert UNAUTHORIZED_CALLBACK();
```
This validates: (a) the provider is the one we called, (b) the data wasn't tampered with by the provider, (c) we are inside a legitimate flash loan initiated by this router.

**3. Smart Account Validation**

`msg.sender` in `executeFlashLoan` IS the smart account (called via SuperExecutor batch). The caller address is hashed into `tHash` and verified in the callback. Nexus's `onlyExecutorModule` provides an additional check when the router calls `executeFromExecutor`.

**4. Inner Operations Validation**

Inner ops are user-signed (part of UserOp). The router trusts them by design — same as how SuperExecutor trusts the hook-produced executions. The inner ops execute as the smart account via `executeFromExecutor`, so Nexus-level hooks (preCheck/postCheck) still apply.

**5. Token Repayment: Push-Only Guarantee**

- The router NEVER holds `transferFrom` authority over the smart account's balance
- Router only holds tokens transiently during callback: borrowed amount arrives from provider, gets pushed to account, repayment arrives back from account's last inner op
- If inner ops don't push back enough, the provider's own repayment verification fails and entire tx reverts
- No approve sandwich = no leftover approval attack surface

**6. Transient Storage Safety**

- tHash is the ONLY transient slot used (single bytes32)
- Auto-cleared at end of tx (TSTORE semantics)
- Explicit clear after provider returns (for same-tx-multiple-flashloan correctness)
- No dynamic data in transient — all context travels through provider's data passthrough

**7. Front-Running Protection**

Flash loans are atomic (borrow + use + repay in one tx). The inner operations (swaps, liquidations) may be susceptible to front-running/sandwiching — this is the user's responsibility via slippage protection in inner ops.

**8. Fund Safety**

- Router never holds tokens between transactions
- Router never holds transferFrom authority over any account
- Router only holds borrowed tokens for the duration of the callback (pushed in by provider, pushed out to account, repayment pushed back, repaid to provider)
- If the transaction reverts at any point, all state changes are rolled back atomically

**9. Nexus executeFromExecutor Dependency (C1 from security-analysis.md)**

FlashLoanRouter depends on Nexus's `executeFromExecutor` having NO reentrancy guard. This is observed behavior, not a written invariant. A CI property test MUST verify this against the pinned Nexus submodule. See `security-analysis.md` C1 for details.

### 8.2 Inspector Function Compliance

The hook's `inspect()` function MUST only return addresses:
```solidity
function inspect(bytes calldata data) external view override returns (bytes memory) {
    address provider = BytesLib.toAddress(data, 1);   // offset 1 (after providerType)
    address token = BytesLib.toAddress(data, 21);
    return abi.encodePacked(provider, token, FLASH_LOAN_ROUTER);
}
```

---

## 9. Testing Strategy

### 9.1 Unit Tests (FlashLoanHookUnit.t.sol)

Inherit from `Helpers`. Use `vm.mockCall` for external dependencies.

Tests:
1. `test_constructor_setsCorrectParameters` -- Verify hookType, subType, router address
2. `test_build_correctExecutionCount` -- Should return 3 executions (pre + 1 executeFlashLoan + post)
3. `test_build_singleExecution_targetsRouter` -- Middle execution targets FLASH_LOAN_ROUTER
4. `test_build_withUsePrevHookAmount` -- Verify amount is read from previous hook
5. `test_build_revertsOnZeroAmount` -- AMOUNT_NOT_VALID
6. `test_build_revertsOnZeroProvider` -- ADDRESS_NOT_VALID
7. `test_build_revertsOnInvalidDataLength` -- DATA_NOT_VALID (< 74 bytes)
8. `test_decode_allFieldsCorrect` -- Verify all data field decoding at correct offsets
9. `test_inspect_returnsOnlyAddresses` -- Protocol requirement (provider, token, router)
10. `test_preExecute_recordsBalance` -- Track pre-flash-loan balance
11. `test_postExecute_calculatesOutAmount` -- Track post-flash-loan balance delta
12. Fuzz tests for data encoding edge cases

### 9.2 Unit Tests (FlashLoanRouterUnit.t.sol)

Inherit from `Helpers`. Use `vm.mockCall` extensively. Mock flash loan providers for each type.

Tests:
1. `test_executeFlashLoan_storesToHash` -- Verify tHash is set (non-zero during flash loan)
2. `test_executeFlashLoan_revertsOnNestedFlashLoan` -- tHash already set → NESTED_FLASH_LOAN_NOT_SUPPORTED
3. `test_executeFlashLoan_clearsTHashAfterCompletion` -- tHash = 0 after successful flash loan
4. `test_callback_revertsOnHashMismatch` -- Tampered data → INVALID_FLASH_LOAN_CONTEXT
5. `test_callback_revertsOnUnauthorizedCaller` -- msg.sender != provider → UNAUTHORIZED_CALLBACK
6. `test_callback_pushesTokensToBorrower` -- Router transfers borrowed tokens to caller
7. `test_callback_executesInnerOperations` -- Inner ops run on smart account via executeFromExecutor
8. `test_onMorphoFlashLoan_approvesProviderForPull` -- Morpho approve-based repayment
9. `test_executeOperation_approvesProviderForPull` -- Aave approve-based repayment
10. `test_onFlashLoan_approvesProviderForPull` -- ERC-3156 approve-based repayment
11. `test_receiveFlashLoan_pushesRepaymentToVault` -- Balancer push-based repayment
12. `test_onInstall_onUninstall` -- ERC-7579 module lifecycle
13. `test_isModuleType_executor` -- Returns true for TYPE_EXECUTOR
14. `test_providerDispatch_allTypes` -- Each FlashLoanProviderType calls correct provider function
15. `test_executeFlashLoan_revertsOnUnsupportedType` -- Invalid enum → UNSUPPORTED_PROVIDER_TYPE
16. Fuzz tests for amounts, fees, token addresses

### 9.3 Integration Tests (FlashLoanIntegration.t.sol)

Inherit from `MinimalBaseIntegrationTest`. MUST include `receive() external payable { }`.

Tests against real mainnet forks:

1. `test_E2E_MorphoFlashLoan_SimpleRoundTrip`
   - Flash loan USDC from Morpho (fee = 0)
   - Inner ops: last op pushes exact amount back to router
   - Verify: account balance unchanged, no cost (Morpho is fee-free)

2. `test_E2E_MorphoFlashLoan_LeveragedPosition`
   - Flash loan USDC from Morpho
   - Inner ops: supply as collateral to Morpho, borrow against it, push borrowed amount back
   - Verify: account has leveraged position

3. `test_E2E_BalancerFlashLoan_SimpleRoundTrip`
   - Flash loan from Balancer Vault (currently fee-free)
   - Inner ops: push exact amount back to router
   - Verify: account balance unchanged

4. `test_E2E_FlashLoanHookChaining`
   - Previous hook produces tokens
   - Flash loan hook uses `usePrevHookAmount`
   - Verify: correct chaining behavior

5. `test_E2E_FlashLoan_Revert_InsufficientRepayment`
   - Flash loan with inner ops that don't push back enough
   - Verify: entire transaction reverts cleanly (provider's transferFrom/balance check fails)

6. `test_NexusInvariant_executeFromExecutor_AllowsNestedCalls`
   - Verify Nexus allows router's `executeFromExecutor` during SuperExecutor's batch
   - If this test fails after Nexus upgrade, ALL flash loan flows are broken (C1 from security-analysis.md)

All integration tests MUST use UserOp execution through SuperExecutor/paymaster, never direct contract calls.

### 9.4 Gas Tolerance

Allow +/- 0.01 ETH tolerance in balance assertions due to gas costs.

---

## 10. Deployment Integration

### 10.1 FlashLoanRouter Deployment

The FlashLoanRouter must be deployed as a standalone contract (similar to how hooks are deployed). Each smart account must install it as an executor module before using flash loan hooks.

**Question for team**: Should the FlashLoanRouter be deployed alongside hooks in `DeployV2Core.s.sol`, or separately? Since it's an executor module (not a hook), it may need a different deployment path.

### 10.2 Configuration

No chain-specific dependencies for the router itself. The flash loan providers are passed as parameters in the hook data (not constructor args), so the router is chain-agnostic.

However, we should add provider addresses to `ConfigCore.sol` for reference:

```solidity
// ===== FLASH LOAN PROVIDER ADDRESSES =====
// Morpho Blue - same address on all chains where deployed
configuration.morphoBlue[MAINNET_CHAIN_ID] = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
configuration.morphoBlue[BASE_CHAIN_ID] = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
// Balancer V2 Vault - same address on most chains
configuration.balancerVault[MAINNET_CHAIN_ID] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
```

### 10.3 Smart Account Setup

For smart accounts to use flash loans, the FlashLoanRouter must be installed as an executor module. This can be done via:
```
account.installModule(MODULE_TYPE_EXECUTOR, flashLoanRouterAddress, "")
```

This is a one-time setup per account and could be included in the account bootstrap process.

---

## 11. Open Questions

### 11.1 For Team Discussion

1. **Executor Module Installation**: Should the FlashLoanRouter be automatically installed on all smart accounts during bootstrap, or should it be opt-in? Auto-install is simpler for UX but adds gas to account creation.

2. **Inner Operations Format**: Should inner operations be raw `Execution[]` or should they go through Superform hook validation? Raw Execution[] is simpler but bypasses hook compliance checks.

3. **Fee Cap**: Should the hook enforce a maximum flash loan fee, or is the approval amount (`amount + maxFee`) sufficient protection?

4. **Multi-Token Flash Loans**: Should the first version support multi-token flash loans (Balancer supports this), or start with single-token only?

5. **Nexus-Level Hook Interaction**: If the smart account has a Nexus-level hook installed, the FlashLoanRouter's `executeFromExecutor` call will trigger the Nexus hook's `preCheck`/`postCheck`. Could this cause issues? Need to verify with the Nexus team.

6. **Gas Considerations**: The delegatecall-through-router approach adds extra external calls compared to a native delegatecall implementation. Is the gas overhead acceptable? Should we benchmark against the "modify executor" approach?

7. **Provider Whitelist**: Should the FlashLoanRouter enforce a whitelist of allowed flash loan providers, or trust the user's signed UserOp to specify valid providers?

### 11.2 Architecture Decision Record

**Decision**: Use FlashLoanRouter as separate ERC-7579 Executor Module

**Rationale**:
- Zero changes to existing audited executor code
- Clean separation of concerns
- Flash loan logic isolated in its own module
- Can be upgraded/replaced independently
- Nexus already supports multiple executor modules
- The `nonReentrant` on SuperExecutorBase does NOT block the router's `executeFromExecutor` calls because they go through Nexus directly, not through SuperExecutor

**Trade-offs**:
- Requires smart accounts to install an additional executor module
- Inner operations bypass Superform hook compliance validation
- Additional gas overhead from extra external calls vs delegatecall approach
- Flash loan provider callbacks hit the router, not the smart account -- this means Morpho's `flashLoan` (which sends tokens to `msg.sender`) sends to the router, not the account

**Mitigation for Morpho**: The router's callback transfers tokens to the account. Since Morpho sends to `msg.sender` (the router), the router has the tokens and can forward them.

---

## Summary: Implementation Priority Order

1. **Phase 1** (Core): `FlashLoanRouter.sol` -- The ERC-7579 executor module with callback handling
2. **Phase 2** (Hook): `FlashLoanHook.sol` -- The Superform hook that orchestrates the flow
3. **Phase 3** (Interfaces): `IFlashLoanRouter.sol` and any missing provider interfaces
4. **Phase 4** (Testing): Unit tests for both components
5. **Phase 5** (Integration): Fork-based integration tests with real flash loan providers
6. **Phase 6** (Deployment): Script updates and configuration
7. **Phase 7** (Subtype): Add `FLASH_LOAN` to `HookSubTypes.sol`

### Key Implementation Notes

- **Solidity 0.8.30** for all files
- **Transient storage** (EIP-1153) for all flash loan context -- automatic cleanup
- **No libraries** -- consolidate all logic in the router contract
- **Immutable constructor params** for the hook (router address only)
- **Chain-agnostic** -- provider addresses come from hook data, not constructor
- **Inspector compliance** -- only return addresses from `inspect()`
- The router's `onInstall`/`onUninstall` can be no-ops (stateless module)
- The router MUST be the same deployed address referenced by the hook's `FLASH_LOAN_ROUTER` immutable
