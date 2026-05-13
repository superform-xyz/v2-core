# Security Analysis Report

## Metadata
- **Target:** `src/accounting/oracles/DETHYieldSourceOracle.sol`
- **Mode:** review
- **Date:** 2026-05-12
- **Contract Types Detected:** Vault/Oracle (yield source pricing oracle)
- **Files Analyzed:** 1 (+ 3 dependencies: IMachine.sol, IDETHAsyncRedeemer.sol, AbstractYieldSourceOracle.sol)
- **Agents Used:** Vulnerability Scanner, Best Practices Reviewer, EVM Security Researcher

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | - |
| P1 High | 1 | Yes |
| P2 Medium | 5 | No |
| P3 Low | 6 | No |

## Verdict
**FAIL** - 1 blocking finding (P1) should be resolved before merge.

---

## P0 Findings (Critical - Must Fix)

None found.

---

## P1 Findings (High - Must Fix)

### [F-01] Unvalidated `yieldSourceAddress` enables TVL manipulation via arbitrary contract injection

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:171-188`
- **SWC:** N/A
- **Category:** Logic
- **Description:** `getTVLByOwnerOfShares` passes the caller-supplied `yieldSourceAddress` to `_getPendingRedemptionValue`, where it becomes the `asyncRedeemer` address for calling `lastFinalizedRequestId()`, `nextRequestId()`, `ownerOf()`, and `getShares()`. All other oracle functions use immutable state (MACHINE, DETH_TOKEN). This creates an inconsistency: pricing uses trusted immutables, but pending redemption scanning uses an untrusted parameter. If a wrong or malicious address is passed, pending TVL can be inflated or deflated arbitrarily.

  **Mitigating context:** In practice, this oracle is called by the SuperLedger system which controls the yieldSourceAddress parameter. However, defense-in-depth dictates using immutables consistently, especially since the constructor already resolves the async redeemer.

- **Exploit Scenario:** A malicious contract passed as `yieldSourceAddress` returns crafted `lastFinalizedRequestId=0`, `nextRequestId=201`, and huge `getShares()` values where `ownerOf()` returns the target. Pending value becomes massively inflated, flowing through to fee calculations.

- **Vulnerable Code:**
```solidity
function getTVLByOwnerOfShares(
    address yieldSourceAddress,   // <-- not validated
    address ownerOfShares
) public view override returns (uint256) {
    uint256 heldShares = IERC20(DETH_TOKEN).balanceOf(ownerOfShares);
    uint256 heldValue = heldShares > 0 ? IMachine(MACHINE).convertToAssets(heldShares) : 0;
    uint256 pendingValue = _getPendingRedemptionValue(yieldSourceAddress, ownerOfShares);
    return heldValue + pendingValue;
}
```

- **Secure Pattern:** Cache the async redeemer as an immutable:
```solidity
address public immutable ASYNC_REDEEMER;

constructor(address superLedgerConfiguration_, address asyncRedeemer_)
    AbstractYieldSourceOracle(superLedgerConfiguration_)
{
    ASYNC_REDEEMER = asyncRedeemer_;
    address machine = IDETHAsyncRedeemer(asyncRedeemer_).machine();
    MACHINE = machine;
    // ...
}

function getTVLByOwnerOfShares(
    address,  // yieldSourceAddress ignored - using immutable
    address ownerOfShares
) public view override returns (uint256) {
    uint256 heldShares = IERC20(DETH_TOKEN).balanceOf(ownerOfShares);
    uint256 heldValue = heldShares > 0 ? IMachine(MACHINE).convertToAssets(heldShares) : 0;
    uint256 pendingValue = _getPendingRedemptionValue(ASYNC_REDEEMER, ownerOfShares);
    return heldValue + pendingValue;
}
```

- **Reference:** Trust boundary violation -- immutable state should be used consistently. All other functions already ignore the parameter and use immutables.

---

## P2 Findings (Medium - Should Fix)

### [F-02] `decimals()` makes external call on every invocation; should cache as immutable

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:82-84`
- **SWC:** N/A
- **Category:** Gas / Logic
- **Description:** `decimals()` calls `IERC20Metadata(DETH_TOKEN).decimals()` on every invocation. Since DETH_TOKEN is immutable and token decimals never change, this value is already known at construction time (it is used to compute `ONE_SHARE`). External call costs ~2,600 gas vs. 3 gas for an immutable read.

- **Current Code:**
```solidity
function decimals(address) external view override returns (uint8) {
    return IERC20Metadata(DETH_TOKEN).decimals();
}
```

- **Secure Pattern:**
```solidity
uint8 public immutable DETH_DECIMALS;

// In constructor:
uint8 dethDecimals = IERC20Metadata(DETH_TOKEN).decimals();
DETH_DECIMALS = dethDecimals;
ONE_SHARE = 10 ** uint256(dethDecimals);

function decimals(address) external view override returns (uint8) {
    return DETH_DECIMALS;
}
```

### [F-03] Flash-loan manipulable `convertToAssets` if Machine uses spot pricing

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:100,119,139,146,182,259`
- **SWC:** SWC-136
- **Category:** Oracle
- **Description:** Every pricing function routes through `Machine.convertToAssets()` / `Machine.convertToShares()`. The NatSpec documents the trust assumption that Machine uses internal accounting, not AMM prices. However, this is unverified. If Machine's pricing is based on spot token balances, donation attacks or flash loans could inflate conversion rates. The Makina Finance exploit (Jan 2026, $4.13M on the same Dialectic/Machine vault family) demonstrated this exact attack vector on the MachineShareOracle.

- **Real-World Precedent:** Makina Finance ($4.13M, Jan 2026) -- same vault architecture. ResupplyFi ($9.56M, June 2025) -- donation attack on ERC-4626 vault.

- **Secure Pattern:** Verify Machine uses internal balance tracking. Consider adding a PPS sanity bound:
```solidity
uint256 pps = IMachine(MACHINE).convertToAssets(ONE_SHARE);
if (pps > MAX_REASONABLE_PPS || pps < MIN_REASONABLE_PPS) revert PPS_OUT_OF_BOUNDS();
```

### [F-04] `lastTotalAum()` stale data risk in `getTVL()`

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:193-195`
- **SWC:** N/A
- **Category:** Oracle
- **Description:** `getTVL()` returns `Machine.lastTotalAum()`, a cached snapshot that only updates when Machine's accounting refreshes. Between updates, significant yield/loss events are invisible to the oracle. If downstream consumers use this for solvency checks or fee calculations, stale data could lead to incorrect decisions.

- **Secure Pattern:** Document the staleness risk. If Machine exposes `lastUpdateTimestamp`, add a freshness check.

### [F-05] Missing zero-address validation in constructor

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:62-73`
- **SWC:** N/A
- **Category:** Logic
- **Description:** The constructor accepts `asyncRedeemer_` without zero-address validation. If passed `address(0)`, the call to `.machine()` reverts with an opaque low-level error. A custom error provides clearer diagnostics. This oracle has a multi-hop discovery chain (`asyncRedeemer -> machine -> shareToken/accountingToken`) making bad input harder to debug.

- **Secure Pattern:**
```solidity
error ZERO_ADDRESS();

constructor(address superLedgerConfiguration_, address asyncRedeemer_)
    AbstractYieldSourceOracle(superLedgerConfiguration_)
{
    if (asyncRedeemer_ == address(0)) revert ZERO_ADDRESS();
    // ...
}
```

### [F-06] Silent truncation when >200 pending requests under-reports TVL

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:236,239`
- **SWC:** N/A
- **Category:** Logic
- **Description:** When `pendingCount > MAX_PENDING_REQUESTS`, the scan silently caps at 200 oldest requests. Newer requests are dropped without any indication. Users with recent requests beyond position 200 have under-reported TVL. An attacker could spam cheap redemption requests to push legitimate requests beyond the scan window.

- **Secure Pattern:** At minimum, document the limitation. Consider scanning from newest to oldest (reverse order) since recent requests are more likely to belong to active users.

---

## P3 Findings (Low - Consider Fixing)

### [F-07] Redundant `shareToken()` call in constructor

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:70,72`
- **Category:** Gas
- **Description:** `IMachine(machine).shareToken()` is called twice -- once on L70 (stored in `DETH_TOKEN`) and again on L72. The second call should reuse `DETH_TOKEN`.

- **Fix:**
```solidity
DETH_TOKEN = IMachine(machine).shareToken();
WETH_TOKEN = IMachine(machine).accountingToken();
ONE_SHARE = 10 ** IERC20Metadata(DETH_TOKEN).decimals();  // reuse DETH_TOKEN
```

### [F-08] R2 error handling inconsistency -- final `convertToAssets` not wrapped in try/catch

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:258-260`
- **Category:** Logic
- **Description:** The pending redemption scan uses try/catch (R2 graceful degradation) for all AsyncRedeemer calls. But the final `IMachine(MACHINE).convertToAssets(totalPendingShares)` on L259 is NOT wrapped in try/catch, making it R1. If this reverts (edge case in Machine), the entire TVL function fails instead of gracefully returning just the held value.

- **Fix:** Wrap in try/catch:
```solidity
if (totalPendingShares > 0) {
    try IMachine(MACHINE).convertToAssets(totalPendingShares) returns (uint256 value) {
        totalPendingValue = value;
    } catch { }
}
```

### [F-09] Potential overflow in `totalPendingShares` accumulation

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:247`
- **Category:** Arithmetic
- **Description:** `totalPendingShares += shares` is inside a try/catch for `getShares()`, but the addition itself is NOT caught. If `getShares()` returns extremely large values (e.g., from a malicious contract per F-01), the overflow reverts the entire function. With F-01 fixed (using immutable redeemer), this risk is minimal.

### [F-10] Gas consumption risk -- up to 400 external calls per TVL query

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:239-255`
- **Category:** Gas
- **Description:** The pending scan loop makes up to 200 x 2 = 400 external calls (~2-4M gas). When used in batch functions (`getTVLByOwnerOfSharesMultiple`), this multiplies and can exceed block gas limits. Document this constraint.

### [F-11] `IERC20Metadata` import path inconsistency

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:7`
- **Category:** Other
- **Description:** Imports from `@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol`. The ERC7540 oracle uses `@openzeppelin/contracts/interfaces/IERC20Metadata.sol`. Both resolve to the same interface.

### [F-12] `getBalanceOfOwner` declared `public` but never called internally

- **File:** `src/accounting/oracles/DETHYieldSourceOracle.sol:152`
- **Category:** Gas
- **Description:** Could be `external` for marginal gas savings. Matches most sibling oracle patterns though.

---

## Attack Surface Summary

- **External Entry Points:** `decimals`, `getShareOutput`, `getWithdrawalShareOutput`, `getAssetOutput`, `getPricePerShare`, `getBalanceOfOwner`, `getTVLByOwnerOfShares`, `getTVL` (all `view`)
- **Value Transfer Points:** None (read-only oracle)
- **Oracle Dependencies:** `Machine.convertToAssets()`, `Machine.convertToShares()`, `Machine.lastTotalAum()` -- single point of pricing truth
- **Cross-Contract Interactions:** Machine (pricing), AsyncRedeemer (pending requests), DETH token (balances)
- **Upgrade Mechanisms:** None in oracle itself; Machine and AsyncRedeemer are BeaconProxies (upgradeable by Dialectic)

## Coding Standards Findings

From the Best Practices agent:

| # | Finding | Severity | Action |
|---|---------|----------|--------|
| 1 | Redundant `shareToken()` call in constructor | P3 | Fix (L72) |
| 2 | `decimals()` should cache as immutable | P2 | Fix |
| 3 | Missing zero-address validation | P2 | Fix |
| 4 | `getBalanceOfOwner` public vs external | P3 | Acceptable |
| 5 | Import path inconsistency | P3 | Nice-to-fix |
| 6 | NatSpec `@param` missing for unnamed params | P3 | Acceptable (codebase pattern) |

**Positive observations:** Well-structured section comments, thorough NatSpec with security assumptions documented, correct use of Math.Rounding.Ceil for withdrawals, proper try/catch for async components, bounded iteration for DoS prevention.

## Security Knowledge Sources
- **Vulnerability patterns checked:** Reentrancy, Access Control, Arithmetic, Oracle Manipulation, Flash Loans, DoS, Token Integration, Proxy Safety, ERC-4626 Inflation
- **External research:** evmresearch.io (vulnerability-patterns, exploit-analyses, security-patterns, protocol-mechanics), OWASP SC Top 10 2025
- **Historical exploits cross-referenced:** Makina Finance ($4.13M, Jan 2026), ResupplyFi ($9.56M, June 2025), dForce/Curve read-only reentrancy ($3.7M, Feb 2023), Venus/wUSDM ($700K, Feb 2025)
- **Coding rules validated:** NatSpec, custom errors, naming conventions, import organization, gas optimization, visibility modifiers
