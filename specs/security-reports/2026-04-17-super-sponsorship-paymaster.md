# Security Analysis Report: SuperSponsorshipPaymaster

## Metadata
- **Target:** `src/paymaster/SuperSponsorshipPaymaster.sol`
- **Mode:** review (3-agent parallel analysis)
- **Date:** 2026-04-17
- **Contract Types Detected:** ERC-4337 v0.7 Paymaster, OpenZeppelin AccessControl
- **Files Analyzed:** 3 (SuperSponsorshipPaymaster.sol, BasePaymaster.sol, ISuperSponsorshipPaymaster.sol)
- **Agents:** Vulnerability Scanner, Best Practices Reviewer, EVM Security Researcher

## Summary

| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 1 | Yes |
| P1 High | 2 | Yes |
| P2 Medium | 5 | No |
| P3 Low | 5 | No |

## Verdict

**FAIL** -- 3 blocking findings (1x P0, 2x P1) must be resolved before merge.

---

## P0 Critical

### [P0-1] `_postOp` Underflow Revert Causes Untracked EntryPoint Deposit Drain

- **File:** `SuperSponsorshipPaymaster.sol:201-206`
- **SWC:** N/A (ERC-4337 specific)
- **Category:** ERC4337 / Arithmetic / State Consistency

**Description:**
`_validatePaymasterUserOp` checks `budget.balance >= maxCost` (line 183), but `_postOp` debits `totalCost = actualGasCost + (postOpGasOverhead * actualUserOpFeePerGas)` (line 201). The overhead surcharge is added **on top of** `actualGasCost`, so `totalCost` can exceed `budget.balance`. When this happens, `budget.balance -= totalCost` reverts due to Solidity 0.8.30 checked arithmetic.

Per the ERC-4337 spec: "If postOp reverts, the EntryPoint still charges the paymaster for the gas used." The v0.7 EntryPoint does **not** call `postOp` again with `postOpReverted` mode (confirmed by BasePaymaster comment line 92: `postOpReverted - never passed in a call to postOp()`). This means:
1. The EntryPoint deposit is debited for the actual gas cost
2. The internal accounting (`_budgets[strategy].balance`, `totalAllocated`) is **never updated**
3. `totalAllocated` now exceeds the real EntryPoint deposit permanently

Additionally, ERC-4337 v0.7 imposes a **10% penalty on unused gas** (when unused gas >= 40,000 units) that is charged from the paymaster deposit but not included in `actualGasCost`. This further accelerates drift.

**Exploit Scenario:**
An attacker submits UserOps where `maxCost` is close to the strategy budget. With any non-zero `postOpGasOverhead`, `totalCost` exceeds the balance, `_postOp` reverts, and the EntryPoint silently drains the deposit. Repeated exploitation drains the deposit while internal balances remain inflated. Eventually `withdrawStrategyFunds` fails for all strategies because the EntryPoint lacks sufficient funds. Even without `postOpGasOverhead`, the inherent gap (postOp gas + 10% penalty not in `actualGasCost`) causes slow drift over many operations.

**Vulnerable Code:**
```solidity
// Line 183: validates against maxCost only (no overhead)
if (budget.balance < maxCost) revert INSUFFICIENT_STRATEGY_BUDGET();

// Lines 201-206: debits totalCost which can exceed budget.balance
uint256 totalCost = actualGasCost + (postOpGasOverhead * actualUserOpFeePerGas);
budget.balance -= totalCost;      // REVERTS if totalCost > balance
budget.totalDebited += totalCost;
totalAllocated -= totalCost;
```

**Secure Pattern:**
Cap `totalCost` to `budget.balance` so `_postOp` never reverts:
```solidity
function _postOp(
    PostOpMode,
    bytes calldata context,
    uint256 actualGasCost,
    uint256 actualUserOpFeePerGas
) internal virtual override {
    address strategy = abi.decode(context, (address));
    uint256 totalCost = actualGasCost + (postOpGasOverhead * actualUserOpFeePerGas);

    StrategyBudget storage budget = _budgets[strategy];
    // Cap to available balance -- EP already charged us, so we must never revert
    if (totalCost > budget.balance) {
        totalCost = budget.balance;
    }
    budget.balance -= totalCost;
    budget.totalDebited += totalCost;
    totalAllocated -= totalCost;

    emit StrategyDebited(strategy, totalCost);
}
```

**References:**
- ERC-4337 spec: "actualGasCost is the gas cost so far (not including this postOp call)"
- OtterSec: "A revert in postOp does not undo the payment that already happened during validation"
- BasePaymaster.sol:92: `postOpReverted - never passed in a call to postOp()`

---

## P1 High

### [P1-1] Optimistic Validation Allows Budget Over-Commitment Within a Bundle

- **File:** `SuperSponsorshipPaymaster.sol:164-186`
- **SWC:** N/A
- **Category:** ERC4337 / Logic

**Description:**
The EntryPoint validates **all** UserOps in a bundle before executing any. If a bundler includes N UserOps from different senders all referencing the same strategy, each `_validatePaymasterUserOp` check passes against the same un-decremented balance. The ERC-4337 spec allows different senders to share a paymaster in the same bundle.

Example: strategy has 1 ETH, three UserOps each declare 0.5 ETH maxCost. All three pass validation. During execution, the third `_postOp` attempts to subtract from a near-zero balance, triggering the P0-1 revert issue.

**Exploit Scenario:**
An attacker deploys multiple cheap smart accounts and submits a bundle of UserOps all referencing the same strategy. Each passes validation against the full budget. The actual gas debits exceed the budget, causing cascading `_postOp` reverts and untracked deposit drain.

**Vulnerable Code:**
```solidity
// _validatePaymasterUserOp -- read-only check, no reservation
if (budget.balance < maxCost) revert INSUFFICIENT_STRATEGY_BUDGET();
return (abi.encode(strategy), 0);  // no debit during validation
```

**Secure Pattern:**
Pre-charge during validation, refund excess in `_postOp`:
```solidity
function _validatePaymasterUserOp(...) internal virtual override
    returns (bytes memory context, uint256 validationData)
{
    // ... checks ...
    budget.balance -= maxCost;       // reserve full maxCost
    totalAllocated -= maxCost;       // will be re-adjusted in _postOp
    return (abi.encode(strategy, maxCost), 0);
}

function _postOp(...) internal virtual override {
    (address strategy, uint256 maxCost) = abi.decode(context, (address, uint256));
    uint256 totalCost = actualGasCost + (postOpGasOverhead * actualUserOpFeePerGas);
    uint256 refund = maxCost - totalCost;

    StrategyBudget storage budget = _budgets[strategy];
    budget.balance += refund;        // return unused portion
    budget.totalDebited += totalCost;
    totalAllocated += refund;

    emit StrategyDebited(strategy, totalCost);
}
```

**Reference:** OtterSec: "Always collect full payment during validation, not after execution."

---

### [P1-2] `totalAllocated` Systematically Drifts Above Real EntryPoint Deposit

- **File:** `SuperSponsorshipPaymaster.sol:152-156, 201-206`
- **SWC:** N/A
- **Category:** State Consistency

**Description:**
Even under normal operation (no exploits), `totalAllocated` exceeds the real EntryPoint deposit due to three compounding factors:

1. **`actualGasCost` excludes postOp gas** -- The EntryPoint charges the full cost (including postOp execution) from the paymaster deposit, but `actualGasCost` passed to `_postOp` does not include the postOp gas itself (BasePaymaster.sol:94). With `postOpGasOverhead = 0` (the default), each op under-debits by ~40-60k gas units.

2. **10% unused gas penalty** (ERC-4337 v0.7) -- Charged from the deposit but not included in `actualGasCost`.

3. **`_postOp` reverts** (P0-1) -- Prevents any accounting update.

The fork test explicitly documents this (line 362-369): `assertTrue(internalBalance >= epDeposit)`.

Over time, this makes `withdrawStrategyFunds` fail for the last strategy to withdraw, effectively locking funds.

**Secure Pattern:**
Combine: (A) enforce minimum `postOpGasOverhead` in constructor, (B) add a `reconcile()` admin function:
```solidity
uint256 public constant MIN_POST_OP_OVERHEAD = 40_000;

constructor(...) {
    postOpGasOverhead = MIN_POST_OP_OVERHEAD;
    // ...
}

function reconcile() external onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 deposit = entryPoint.balanceOf(address(this));
    if (totalAllocated > deposit) {
        emit Reconciled(totalAllocated - deposit);
        totalAllocated = deposit;
    }
}
```

---

## P2 Medium

### [P2-1] `withdrawStrategyFunds` Can Fail Due to EP Deposit < Internal Balance

- **File:** `SuperSponsorshipPaymaster.sol:82-93`
- **SWC:** SWC-113
- **Category:** DoS / ETH Handling

**Description:**
Checks `amount > _budgets[strategy].balance` but not `amount <= entryPoint.balanceOf(address(this))`. Due to P1-2 drift, the check passes but `entryPoint.withdrawTo` reverts.

**Secure Pattern:** Add `if (amount > entryPoint.balanceOf(address(this))) revert INSUFFICIENT_ENTRYPOINT_DEPOSIT();`

---

### [P2-2] No Upper Bound on `postOpGasOverhead`

- **File:** `SuperSponsorshipPaymaster.sol:122-125`
- **Category:** Logic / Centralization

**Description:**
A compromised admin could set `postOpGasOverhead` to an astronomically high value, causing `totalCost` overflow or exceeding any strategy balance, which would make every `_postOp` revert (triggering P0-1 deposit drain).

**Secure Pattern:** Add `MAX_POST_OP_GAS_OVERHEAD = 500_000` constant and validate.

---

### [P2-3] No Emergency Withdrawal Path from EntryPoint Deposit

- **File:** `SuperSponsorshipPaymaster.sol:134-140`
- **Category:** ETH Handling

**Description:**
`sweepETH` only sweeps `address(this).balance` (ETH sitting on the contract). All meaningful funds are in the EntryPoint deposit. If accounting is broken (P1-2), there is no escape hatch to directly recover EP deposit without going through `withdrawStrategyFunds` (which may fail).

**Secure Pattern:** Add `emergencyWithdrawFromEntryPoint(address to, uint256 amount)` with admin role.

---

### [P2-4] No `callData` / Sender Validation -- Open Gas Sponsorship

- **File:** `SuperSponsorshipPaymaster.sol:164-186`
- **Category:** ERC4337 / Access Control

**Description:**
Anyone who knows a funded strategy address can craft a UserOp with that strategy in `paymasterAndData` and get their gas sponsored. There is no sender allowlist, no callData validation, and no signature verification.

**Secure Pattern:** Add a signature-based scheme (VerifyingPaymaster pattern) where a backend signs UserOp hashes to authorize sponsorship, or add a per-strategy sender allowlist.

---

### [P2-5] `_postOp` Ignores `PostOpMode` Parameter + Missing `sweepETH` Event

- **File:** `SuperSponsorshipPaymaster.sol:189, 134`
- **Category:** Logic / Best Practices

**Description:**
Two related issues: (1) `_postOp` does not differentiate behavior based on `PostOpMode` -- though in v0.7 `postOpReverted` is never actually passed, this reduces forward-compatibility. (2) `sweepETH` is the only state-changing admin function that does not emit an event, making it invisible to off-chain monitoring.

**Secure Pattern:** Emit an `ETHSwept(to, amount)` event in `sweepETH`.

---

## P3 Low

### [P3-1] Missing `address(0)` Check in Management Functions

- **File:** `SuperSponsorshipPaymaster.sol:100,106,112`
- **Description:** `setMaxSingleOpCost`, `pauseStrategy`, `unpauseStrategy` don't validate `strategy != address(0)`, inconsistent with funding functions.

### [P3-2] `receive()` Accepts ETH That Isn't Usable for Sponsorship

- **File:** `SuperSponsorshipPaymaster.sol:216`
- **Description:** ETH sent directly to the contract doesn't reach the EntryPoint deposit and can't be used for sponsorship until manually swept and re-deposited.

### [P3-3] Centralization Risk -- Admin Holds All Three Roles

- **File:** `SuperSponsorshipPaymaster.sol:44-49`
- **Description:** Constructor grants all roles to single address. Should separate post-deployment. Consider `AccessControlDefaultAdminRules` for 2-step admin transfer.

### [P3-4] Missing `supportsInterface` Override

- **File:** `SuperSponsorshipPaymaster.sol:15`
- **Description:** Both `AccessControl` and `IPaymaster` (via IERC165) provide `supportsInterface`. Without explicit override, `IPaymaster.interfaceId` won't be reported.

### [P3-5] `PAYMASTER_DATA_OFFSET_` Naming Inconsistency

- **File:** `SuperSponsorshipPaymaster.sol:23`
- **Description:** Trailing underscore to avoid collision with base class constant. Consider renaming to `STRATEGY_DATA_OFFSET` for clarity.

---

## Attack Surface Summary

| Surface | Details |
|---------|---------|
| **External Entry Points** | `fundStrategy`, `creditStrategy`, `withdrawStrategyFunds`, `setMaxSingleOpCost`, `pauseStrategy`, `unpauseStrategy`, `setPostOpGasOverhead`, `setGlobalPause`, `sweepETH`, `validatePaymasterUserOp` (via EP), `postOp` (via EP) |
| **Value Transfer Points** | `fundStrategy` (ETH in -> EP), `withdrawStrategyFunds` (EP -> recipient), `sweepETH` (contract -> recipient), `_postOp` (internal debit) |
| **Trust Assumptions** | EntryPoint is trusted (canonical v0.7), FUNDING_ROLE is trusted with all funds, bundlers are untrusted |
| **Accounting Invariants** | `totalAllocated == sum(strategy.balance)`, `totalAllocated <= EP deposit` (currently violated) |

---

## Gas Optimization Note

The `StrategyBudget` struct uses 4 storage slots. If `maxSingleOpCost` can be constrained to `uint128`, it could share a slot with `bool paused`, saving 1 SSTORE per access (~20k gas on cold write).

---

## Recommended Fix Priority

1. **P0-1** -- Cap `totalCost` to `budget.balance` in `_postOp` (prevents revert + untracked drain)
2. **P1-1** -- Pre-charge `maxCost` in validation, refund in `_postOp` (prevents over-commitment)
3. **P1-2** -- Set default `postOpGasOverhead` + add `reconcile()` (prevents drift accumulation)
4. **P2-2** -- Bound `postOpGasOverhead` with max constant
5. **P2-4** -- Add signature verification for UserOp authorization
