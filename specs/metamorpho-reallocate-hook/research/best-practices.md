# MetaMorpho `reallocate()` Integration Best Practices

## Research Summary

This document consolidates best practices for integrating with MetaMorpho's `reallocate()` function
from an external Superform v2-core hook. Research draws from official Morpho documentation, the
MetaMorpho v1 and v1.1 source code, the Taichi Audit deep-dive, the Public Allocator reference
implementation, and multiple independent security audits.

---

## Table of Contents

1. [Function Specification](#1-function-specification)
2. [Ordering: Withdrawals Before Supplies](#2-ordering-withdrawals-before-supplies)
3. [The Max Catcher Pattern](#3-the-max-catcher-pattern)
4. [Full Market Exit (assets == 0)](#4-full-market-exit-assets--0)
5. [Rounding and Dust Considerations](#5-rounding-and-dust-considerations)
6. [Security Considerations](#6-security-considerations)
7. [Gas Optimization](#7-gas-optimization)
8. [Interface Versioning: v1 vs v1.1](#8-interface-versioning-v1-vs-v11)
9. [Common Pitfalls](#9-common-pitfalls)
10. [Superform Hook Integration Notes](#10-superform-hook-integration-notes)
11. [Sources](#11-sources)

---

## 1. Function Specification

### Signature

```solidity
function reallocate(MarketAllocation[] calldata allocations) external onlyAllocatorRole;
```

### MarketAllocation Struct

```solidity
struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;            // Target final amount of assets in this market
}
```

### MarketParams Struct (from Morpho Blue)

```solidity
struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}
```

### Access Control

Only addresses with the **allocator role** can call `reallocate()`. The modifier checks:

```solidity
modifier onlyAllocatorRole() {
    address sender = _msgSender();
    if (!isAllocator[sender] && sender != curator && sender != owner()) {
        revert ErrorsLib.NotAllocatorRole();
    }
    _;
}
```

This means the smart account (the `msg.sender` to MetaMorpho) must be registered as an allocator
on the specific MetaMorpho vault. For a Superform hook, the **smart account itself** is the
`msg.sender` since the hook builds `Execution` structs that the account executes. The smart account
must therefore hold the allocator role on the target MetaMorpho vault.

---

## 2. Ordering: Withdrawals Before Supplies

### Critical Requirement

The `reallocate()` function processes allocations **sequentially in array order**. It determines
whether each allocation is a withdrawal or supply based on the relationship between the current
supply position and the target `assets` value:

```
if current_supply > target_assets --> WITHDRAW (current_supply - target_assets)
if current_supply < target_assets --> SUPPLY (target_assets - current_supply)
if current_supply == target_assets --> SKIP (no-op)
```

### Best Practice: Place All Withdrawals Before Supplies

**Withdrawals must appear before supplies in the array.** The function tracks running totals of
`totalWithdrawn` and `totalSupplied`. When it encounters a supply allocation, the assets to supply
come from previously withdrawn assets. If a supply appears before sufficient withdrawals have
accumulated, the vault will not have the tokens available to supply.

Example of correct ordering:

```
allocations[0] = { marketA, 50e18 }    // Currently 70e18, withdraws 20e18
allocations[1] = { marketB, 20e18 }    // Currently 0, supplies 20e18
```

Example of INCORRECT ordering (will revert or supply 0):

```
allocations[0] = { marketB, 20e18 }    // Currently 0, tries to supply 20e18 but nothing withdrawn yet
allocations[1] = { marketA, 50e18 }    // Currently 70e18, withdraws 20e18 (too late)
```

### Why This Matters

The function computes supply amounts relative to accumulated withdrawals:

```solidity
uint256 suppliedAssets = allocation.assets == type(uint256).max
    ? totalWithdrawn.zeroFloorSub(totalSupplied)
    : allocation.assets.zeroFloorSub(supplyAssets);
```

When `type(uint256).max` is used, the amount supplied is exactly `totalWithdrawn - totalSupplied`.
If no withdrawals have occurred yet, this is zero and the allocation is silently skipped (`continue`).

---

## 3. The Max Catcher Pattern

### Definition

The **max catcher** is the critical best practice of making the **last** allocation in the array
a "catch-all" market with `assets = type(uint256).max`. This is typically the **Idle Market**
(a market with zero collateral token, oracle, IRM, and LLTV that holds uninvested assets).

### Why It Is Essential

From the official Morpho documentation:

> "To ensure that the total supplied always matches the total withdrawn and to avoid failed
> transactions due to rounding or accrued interest, it is a critical best practice to make the
> last item in your allocations array a 'catcher.'"

### How It Works

When `allocation.assets == type(uint256).max`:

```solidity
uint256 suppliedAssets = totalWithdrawn.zeroFloorSub(totalSupplied);
```

This computes exactly how much remains to be supplied and supplies that exact amount, guaranteeing
`totalWithdrawn == totalSupplied` at the end.

### Example

```json
[
  { "marketParams": "...Market A...", "assets": "50000000000000000000" },
  { "marketParams": "...Market B...", "assets": "20000000000000000000" },
  { "marketParams": "...Idle Market...", "assets": "MAX_UINT256" }
]
```

### Hook Implication

When building the hook, if `usePrevHookAmount` modifies one allocation's assets, the max catcher
at the end will automatically absorb the difference, making the system resilient to amount changes
from previous hooks.

---

## 4. Full Market Exit (assets == 0)

### Share-Based Withdrawal for Full Exit

When `allocation.assets == 0`, MetaMorpho switches from asset-based to **share-based withdrawal**:

```solidity
if (allocation.assets == 0) {
    shares = supplyShares;   // Withdraw ALL shares
    withdrawn = 0;           // Pass 0 to Morpho.withdraw for the assets param
}

(uint256 withdrawnAssets, uint256 withdrawnShares) =
    MORPHO.withdraw(allocation.marketParams, withdrawn, shares, address(this), address(this));
```

### Why This Matters

A straightforward asset-based full withdrawal (`MORPHO.withdraw(supplyAssets, 0, ...)`) could fail
if someone front-runs the transaction with a donation to the market, changing the supply balance.
By passing all shares instead, the withdrawal captures any unknown donations and guarantees a
complete exit regardless of balance changes between transaction submission and execution.

### Security Note

This is an important anti-frontrunning protection built into MetaMorpho. External callers should
always use `assets = 0` rather than passing the exact current supply balance when seeking a full
market exit.

---

## 5. Rounding and Dust Considerations

### Share-to-Asset Conversion Rounding

MetaMorpho uses `_accruedSupplyBalance()` to compute current positions:

```solidity
function _accruedSupplyBalance(MarketParams memory marketParams, Id id)
    internal
    returns (uint256 assets, uint256 shares, Market memory market)
{
    MORPHO.accrueInterest(marketParams);
    market = MORPHO.market(id);
    shares = MORPHO.supplyShares(id, address(this));
    assets = shares.toAssetsDown(market.totalSupplyAssets, market.totalSupplyShares);
}
```

Key points:
- `toAssetsDown` rounds **down** when converting shares to assets
- This means the computed `supplyAssets` may be slightly less than the true value
- Accrued interest between when the allocation was prepared off-chain and when it executes on-chain
  can cause small discrepancies in expected vs actual balances

### Dust Accumulation

- Repeated rounding-down in `toAssetsDown` can leave small "dust" amounts (1-2 wei) stranded
- The max catcher pattern absorbs this dust automatically
- Without a max catcher, the `InconsistentReallocation` error will trigger on dust mismatches

### Fee Rounding

Morpho Blue's fee system acknowledges rounding:
> "feeAssets may be rounded down to 0 if totalInterest * fee < WAD"

This means fee accrual between blocks can create sub-wei discrepancies that affect supply balances.

### Best Practice for the Hook

- **Always include a max catcher** (type(uint256).max) as the last allocation
- **Never hardcode exact asset amounts** that assume a specific supply balance at execution time
- **Assume 1-2 wei of dust** may be created per market interaction

---

## 6. Security Considerations

### 6.1 Access Control: Allocator Role

The calling smart account MUST be registered as an allocator on the target MetaMorpho vault.
Without this, the transaction reverts with `NotAllocatorRole()`.

**Hook Implication:** The hook cannot autonomously grant itself the allocator role. This must be
set up by the vault owner/curator beforehand. The hook should document this prerequisite clearly.

### 6.2 Net-Zero Invariant

```solidity
if (totalWithdrawn != totalSupplied) revert ErrorsLib.InconsistentReallocation();
```

This invariant is the primary security mechanism. It ensures that `reallocate()` can only
**redistribute** assets, never extract or inject them. An allocator cannot use `reallocate()` to
steal funds from the vault.

**Hook Implication:** The hook is inherently safe from a value-extraction perspective because
of this invariant. The NONACCOUNTING classification is correct since no net value enters or leaves.

### 6.3 Supply Cap Enforcement

Before supplying to any market, MetaMorpho validates:

```solidity
uint256 supplyCap = config[id].cap;
if (supplyCap == 0) revert ErrorsLib.UnauthorizedMarket(id);
if (supplyAssets + suppliedAssets > supplyCap) revert ErrorsLib.SupplyCapExceeded(id);
```

**Hook Implication:** The hook caller must respect supply caps. If the off-chain system proposes
an allocation that would exceed a cap, the entire transaction reverts. The hook itself does not
need to validate caps since MetaMorpho enforces them, but error handling should account for
`SupplyCapExceeded` reverts.

### 6.4 Market Enabled Check

- **v1:** The `config[id].enabled` check is performed **only during withdrawals**, inside the
  `if (withdrawn > 0)` branch. Supply-side validation uses `supplyCap == 0` as the
  unauthorized-market guard.
- **v1.1:** The `config[id].enabled` check is performed **for all allocations** at the top of the
  loop, before determining if it is a withdrawal or supply. This is stricter.

```solidity
// v1.1 -- check is at the top, before withdrawal/supply branching
if (!config[id].enabled) revert ErrorsLib.MarketNotEnabled(id);
```

**Hook Implication:** When targeting v1 vaults, disabled markets can still appear in the allocation
array for supply operations (as long as they have a cap). For v1.1 vaults, all markets must be
enabled. The hook should be tested against both behaviors.

### 6.5 Frontrunning Risk

- **Donation attacks** on full market exits are mitigated by MetaMorpho's share-based withdrawal
  (see Section 4)
- **Interest accrual** between transaction submission and execution can change supply balances.
  The max catcher pattern absorbs this.
- **Sandwich attacks** are not directly relevant since `reallocate()` does not swap tokens on
  external DEXs.

### 6.6 Stranded Funds Risk

If a market becomes illiquid or its underlying Morpho market reverts after a reallocation supplies
to it, those assets may become temporarily or permanently stranded. MetaMorpho's `reallocate()`
does **not** use try/catch for individual allocations (unlike the internal `_supplyMorpho()` used
during deposits). A single reverting market will revert the entire `reallocate()` call.

**Hook Implication:** The off-chain system preparing the allocation array must verify market
liquidity and health before constructing the allocations.

### 6.7 Reentrancy

MetaMorpho's `reallocate()` does not have explicit reentrancy guards, but:
- Morpho Blue itself is designed to be non-reentrant for supply/withdraw operations
- The net-zero invariant check at the end provides implicit protection against partial reentrancy
- The hook's own `preExecute`/`postExecute` mutex system provides additional protection

---

## 7. Gas Optimization

### 7.1 Calldata Encoding

The `MarketAllocation[]` array is passed as `calldata`, not `memory`. Each `MarketAllocation`
contains:
- `MarketParams`: 5 fields (3 addresses + 1 address + 1 uint256) = ~160 bytes
- `assets`: 1 uint256 = 32 bytes
- **Total per allocation: ~192 bytes**

For N allocations, calldata cost is approximately:
- `4 bytes (selector) + 32 bytes (offset) + 32 bytes (length) + N * 192 bytes`
- On L1: ~16 gas per non-zero calldata byte = ~3,072 gas per allocation
- On L2 (post-EIP-4844): significantly cheaper but still proportional

### 7.2 Minimizing Allocation Array Size

**Best Practice:** Only include markets that need changes. Markets where
`current_supply == target_assets` are no-ops and waste gas. The hook should not pass through
markets that need no rebalancing.

### 7.3 Encoding in the Hook

Two approaches for encoding the `MarketAllocation[]` in the hook:

**Option A: Pass Pre-encoded calldata**
The off-chain system pre-encodes the entire `abi.encodeCall(IMetaMorpho.reallocate, (allocations))`
and the hook passes it through. This is gas-efficient but makes `usePrevHookAmount` harder to
implement since the amount is buried inside the ABI-encoded array.

**Option B: Decode and re-encode in the hook**
The hook receives a structured representation of the allocations, optionally modifies one entry
using `usePrevHookAmount`, and re-encodes. This is more flexible but costs more gas for the
memory operations.

**Recommended Approach (Option B with optimization):** Since the hook needs to support
`usePrevHookAmount`, decode the allocations, modify the target entry's `assets` field, and
encode the call. The gas overhead is acceptable because `reallocate()` itself is already expensive
(multiple Morpho Blue interactions per allocation).

### 7.4 Morpho Blue Layer Gas Costs

Each allocation in the array triggers either a `MORPHO.withdraw()` or `MORPHO.supply()` call
to Morpho Blue. These are the dominant gas consumers (~50k-100k gas each depending on market
state). The encoding overhead in the hook is minor relative to this.

### 7.5 L2 Calldata Optimization

Morpho Blue provides an `idToMarketParams` mapping specifically for L2 optimization:
> "This mapping is there to enable reducing the cost associated to calldata on layer 2s by
> creating a wrapper contract with functions that take `id` as input instead of `marketParams`."

However, MetaMorpho's `reallocate()` requires full `MarketParams`, not just `Id`. For L2
deployments, the calldata cost is the primary concern, and there is no shortcut within the
current MetaMorpho interface.

---

## 8. Interface Versioning: v1 vs v1.1

### Identical Function Signature

Both v1 and v1.1 use the same `reallocate()` signature:

```solidity
function reallocate(MarketAllocation[] calldata allocations) external;
```

The `MarketAllocation` struct is identical in both versions.

### Key Differences

| Aspect | v1 (MetaMorpho) | v1.1 (MetaMorphoV1_1) |
|--------|-----------------|----------------------|
| **Market enabled check** | Only on withdrawal path | On all allocations (top of loop) |
| **Bad debt handling** | Realizes bad debt | Does NOT realize bad debt |
| **Timelock at deploy** | Minimum 24 hours | Can be set to zero |
| **Name/symbol mutability** | Immutable | Mutable (owner can change) |
| **Interface name** | `IMetaMorpho` | `IMetaMorphoV1_1` |
| **Multicall** | Not inherited | Inherits `IMulticall` |
| **Supply-side unauthorized check** | Uses `supplyCap == 0` | Uses `!config[id].enabled` |

### v1 `reallocate()` - Market Enabled Check Placement

```solidity
// v1: enabled check is INSIDE the withdrawal branch
if (withdrawn > 0) {
    if (!config[id].enabled) revert ErrorsLib.MarketNotEnabled(id);
    // ... withdraw logic
} else {
    // Supply branch: no enabled check, uses supplyCap == 0 instead
    uint256 supplyCap = config[id].cap;
    if (supplyCap == 0) revert ErrorsLib.UnauthorizedMarket(id);
    // ... supply logic
}
```

### v1.1 `reallocate()` - Market Enabled Check Placement

```solidity
// v1.1: enabled check is at the TOP of the loop, before branching
if (!config[id].enabled) revert ErrorsLib.MarketNotEnabled(id);

if (withdrawn > 0) {
    // ... withdraw logic (no separate enabled check)
} else {
    // ... supply logic (no separate enabled check, still has cap check)
}
```

### Hook Compatibility Strategy

The hook should use a **minimal shared interface** that works with both versions:

```solidity
interface IMetaMorphoReallocate {
    struct MarketAllocation {
        MarketParams marketParams;
        uint256 assets;
    }

    function reallocate(MarketAllocation[] calldata allocations) external;
}
```

Since the function signature and struct are identical, a single hook contract can target both v1
and v1.1 vaults. The behavioral differences (enabled-check placement, bad debt) are internal to
MetaMorpho and transparent to the caller.

### Deployed Addresses

- **v1 Factory:** Deployed on Ethereum mainnet (original MetaMorpho)
- **v1.1 Factory:** `0x1897a8997241c1cd4bd0698647e4eb7213535c24` (Ethereum),
  also deployed on Base and Scroll

---

## 9. Common Pitfalls

### 9.1 Forgetting the Max Catcher

**Symptom:** `InconsistentReallocation()` revert.
**Cause:** Rounding dust or accrued interest makes `totalWithdrawn != totalSupplied` by 1-2 wei.
**Fix:** Always append a max catcher allocation (`type(uint256).max`) as the last entry.

### 9.2 Wrong Ordering of Allocations

**Symptom:** Supply allocations are silently skipped (supply amount is 0), or the final
`InconsistentReallocation` check fails.
**Cause:** Supply allocations appear before the withdrawal allocations that fund them.
**Fix:** Order all withdrawals first, then supplies, with the max catcher last.

### 9.3 Exceeding Supply Caps

**Symptom:** `SupplyCapExceeded(id)` revert.
**Cause:** The target allocation plus existing supply exceeds the market's configured cap.
**Fix:** Check `config[id].cap` off-chain before constructing the allocation array.

### 9.4 Targeting Disabled or Unauthorized Markets

**Symptom:** `MarketNotEnabled(id)` (v1.1) or `UnauthorizedMarket(id)` (v1, supply path).
**Cause:** Market has been removed or its cap was set to 0.
**Fix:** Verify market status before constructing the allocation.

### 9.5 Stale Allocation Data

**Symptom:** Unexpected withdrawal/supply amounts or revert due to insufficient liquidity.
**Cause:** Market state changed between off-chain computation and on-chain execution (interest
accrual, other allocators acting, user deposits/withdrawals).
**Fix:** Use the max catcher pattern and avoid hardcoding exact supply amounts. Account for
potential state drift.

### 9.6 Missing Allocator Role

**Symptom:** `NotAllocatorRole()` revert.
**Cause:** The `msg.sender` (the smart account executing the hook) is not registered as an
allocator on the target MetaMorpho vault.
**Fix:** Ensure vault governance has granted the allocator role to the smart account address.

### 9.7 Passing Incorrect MarketParams

**Symptom:** Operations on the wrong market, or `MarketNotCreated` revert from Morpho Blue.
**Cause:** `MarketParams` fields do not exactly match the market's registered parameters.
The market `Id` is computed as `keccak256(abi.encode(marketParams))`, so any field mismatch
produces a different ID.
**Fix:** Use verified, on-chain-sourced `MarketParams` data. Double-check all 5 fields.

### 9.8 Liquidity Constraints on Withdrawal

**Symptom:** Revert from Morpho Blue's `withdraw()` due to insufficient liquidity.
**Cause:** The target market does not have enough available liquidity (assets are borrowed).
**Fix:** Check available liquidity off-chain. If liquidity is insufficient, the official
recommendation is to remove available liquidity via `reallocate()` and adjust the withdraw queue.

---

## 10. Superform Hook Integration Notes

### Hook Classification

- **HookType:** `NONACCOUNTING` -- correct, since `reallocate()` is net-zero by invariant
- **No value enters or leaves the smart account** -- assets only move between Morpho Blue markets
  within the same MetaMorpho vault

### Data Layout Recommendation

For the hook calldata, a recommended layout:

```
Offset  | Size     | Field
--------|----------|----------------------------------------------
0       | 20 bytes | MetaMorpho vault address
20      | 1 byte   | usePrevHookAmount flag
21      | 2 bytes  | prevHookAllocationIndex (which allocation to modify)
23      | 2 bytes  | numAllocations (N)
25      | N * 192  | MarketAllocation[] data (packed)
```

Each MarketAllocation entry (192 bytes):
```
Offset  | Size     | Field
--------|----------|------
0       | 20 bytes | loanToken
20      | 20 bytes | collateralToken
40      | 20 bytes | oracle
60      | 20 bytes | irm
80      | 32 bytes | lltv
112     | 32 bytes | assets (target amount)
```

Alternatively, use standard ABI encoding for the `MarketAllocation[]` and prepend only the vault
address, the `usePrevHookAmount` flag, and the allocation index. This is simpler to implement
and more maintainable, with modest gas overhead.

### usePrevHookAmount Behavior

When `usePrevHookAmount` is true, the hook should:
1. Read `ISuperHookResult(prevHook).getOutAmount(account)` to get the dynamic amount
2. Replace `allocations[prevHookAllocationIndex].assets` with this amount
3. Ensure a max catcher (`type(uint256).max`) is present as the last allocation to absorb any
   difference caused by the dynamic amount

### Execution Construction

The hook should build a single `Execution`:

```solidity
executions = new Execution[](1);
executions[0] = Execution({
    target: vaultAddress,
    value: 0,
    callData: abi.encodeCall(IMetaMorphoReallocate.reallocate, (allocations))
});
```

### postExecute Behavior

Since `reallocate()` is net-zero, `_postExecute` can simply set `outAmount = 0` or skip it
entirely. There is no meaningful output amount for subsequent hooks unless the hook is chained
with operations that depend on knowing the reallocation occurred.

### Error Handling

The hook itself does not need to wrap `reallocate()` in try/catch. If the call reverts, the entire
ERC-7579 execution batch reverts, which is the desired behavior (atomic execution). The off-chain
system should detect and handle failures at the transaction level.

---

## 11. Sources

### Primary Sources (Official)

- [MetaMorpho GitHub Repository](https://github.com/morpho-org/metamorpho) -- v1 source code
  and reference implementation
- [MetaMorpho v1.1 GitHub Repository](https://github.com/morpho-org/metamorpho-v1.1) -- v1.1
  source code with behavioral changes
- [Morpho Docs: Manage Allocations (Vaults V1)](https://docs.morpho.org/curate/tutorials-v1/manage-allocations/)
  -- official tutorial on the max catcher pattern and reallocate best practices
- [Morpho Docs: Public Allocator](https://docs.morpho.org/tools/onchain/public-allocator/) --
  reference implementation showing sorted withdrawals and max catcher usage
- [Morpho Docs: Vault Contracts](https://docs.morpho.org/get-started/resources/contracts/morpho-vaults/)
  -- contract addresses and interface reference
- [Morpho Docs: Security Audits](https://docs.morpho.org/get-started/resources/audits/) -- audit
  reports from OpenZeppelin, Spearbit/Cantina, and competition findings

### Secondary Sources (Analysis)

- [Taichi Audit: Morpho Internals Part 4 - MetaMorpho](https://taichiaudit.com/blog/morpho-internals-part-4-metamorpho)
  -- detailed technical analysis of reallocate() internals, including frontrunning mitigations
  and share-based withdrawal edge cases
- [DeepWiki: MetaMorpho Vault](https://deepwiki.com/morpho-org/metamorpho/2.1-metamorpho-vault)
  -- synthesized technical documentation of the vault architecture
- [Morpho Public Allocator GitHub](https://github.com/morpho-org/public-allocator) -- on-chain
  reference implementation of a contract that calls reallocate()
- [Cantina Competition: MetaMorpho and Periphery](https://cantina.xyz/competitions/8409a0ce-6c21-4cc9-8ef2-bd77ce7425af)
  -- competitive security review

### Audit Reports

| Auditor | Target | Date |
|---------|--------|------|
| OpenZeppelin | MetaMorpho | 2023-11-16 |
| Spearbit (Cantina-managed) | MetaMorpho | 2023-11-16 |
| Cantina Competition | MetaMorpho + Periphery | 2023-11 to 2023-12 |
| OpenZeppelin | MetaMorpho Diff (v1.1) | 2024-11-16 |
| Spearbit (Cantina-managed) | MetaMorpho (v1.1) | 2024-11-23 |
| ChainSecurity | Morpho Vault V2 | 2025 |

### Codebase References (Superform v2-core)

- Existing Morpho loan hooks: `src/hooks/loan/morpho/` (BaseMorphoLoanHook, MorphoSupplyHook, etc.)
- Morpho vendor interfaces: `src/vendor/morpho/IMorpho.sol`
- MarketParams struct: `src/vendor/morpho/IMorpho.sol` (lines 6-12)
- NONACCOUNTING hook pattern: `src/hooks/tokens/erc20/ApproveERC20Hook.sol`
- Base hook infrastructure: `src/hooks/BaseHook.sol`
- Hook interfaces: `src/interfaces/ISuperHook.sol`

---

## Appendix A: Complete v1.1 reallocate() Source

Extracted from
[metamorpho-v1.1/src/MetaMorphoV1_1.sol](https://github.com/morpho-org/metamorpho-v1.1/blob/main/src/MetaMorphoV1_1.sol):

```solidity
function reallocate(MarketAllocation[] calldata allocations) external onlyAllocatorRole {
    uint256 totalSupplied;
    uint256 totalWithdrawn;
    for (uint256 i; i < allocations.length; ++i) {
        MarketAllocation memory allocation = allocations[i];
        Id id = allocation.marketParams.id();
        if (!config[id].enabled) revert ErrorsLib.MarketNotEnabled(id);

        (uint256 supplyAssets, uint256 supplyShares,) = _accruedSupplyBalance(allocation.marketParams, id);
        uint256 withdrawn = supplyAssets.zeroFloorSub(allocation.assets);

        if (withdrawn > 0) {
            uint256 shares;
            if (allocation.assets == 0) {
                shares = supplyShares;
                withdrawn = 0;
            }

            (uint256 withdrawnAssets, uint256 withdrawnShares) =
                MORPHO.withdraw(allocation.marketParams, withdrawn, shares, address(this), address(this));

            emit EventsLib.ReallocateWithdraw(_msgSender(), id, withdrawnAssets, withdrawnShares);

            totalWithdrawn += withdrawnAssets;
        } else {
            uint256 suppliedAssets = allocation.assets == type(uint256).max
                ? totalWithdrawn.zeroFloorSub(totalSupplied)
                : allocation.assets.zeroFloorSub(supplyAssets);

            if (suppliedAssets == 0) continue;

            uint256 supplyCap = config[id].cap;
            if (supplyAssets + suppliedAssets > supplyCap) revert ErrorsLib.SupplyCapExceeded(id);

            (, uint256 suppliedShares) =
                MORPHO.supply(allocation.marketParams, suppliedAssets, 0, address(this), hex"");

            emit EventsLib.ReallocateSupply(_msgSender(), id, suppliedAssets, suppliedShares);

            totalSupplied += suppliedAssets;
        }
    }

    if (totalWithdrawn != totalSupplied) revert ErrorsLib.InconsistentReallocation();
}
```

## Appendix B: v1 reallocate() Source (Key Difference Highlighted)

Extracted from
[metamorpho/src/MetaMorpho.sol](https://github.com/morpho-org/metamorpho/blob/main/src/MetaMorpho.sol):

```solidity
function reallocate(MarketAllocation[] calldata allocations) external onlyAllocatorRole {
    uint256 totalSupplied;
    uint256 totalWithdrawn;
    for (uint256 i; i < allocations.length; ++i) {
        MarketAllocation memory allocation = allocations[i];
        Id id = allocation.marketParams.id();

        // NOTE: No top-level enabled check here (differs from v1.1)

        (uint256 supplyAssets, uint256 supplyShares,) = _accruedSupplyBalance(allocation.marketParams, id);
        uint256 withdrawn = supplyAssets.zeroFloorSub(allocation.assets);

        if (withdrawn > 0) {
            // v1: enabled check is here, inside withdrawal branch only
            if (!config[id].enabled) revert ErrorsLib.MarketNotEnabled(id);

            uint256 shares;
            if (allocation.assets == 0) {
                shares = supplyShares;
                withdrawn = 0;
            }

            (uint256 withdrawnAssets, uint256 withdrawnShares) =
                MORPHO.withdraw(allocation.marketParams, withdrawn, shares, address(this), address(this));

            emit EventsLib.ReallocateWithdraw(_msgSender(), id, withdrawnAssets, withdrawnShares);

            totalWithdrawn += withdrawnAssets;
        } else {
            uint256 suppliedAssets = allocation.assets == type(uint256).max
                ? totalWithdrawn.zeroFloorSub(totalSupplied)
                : allocation.assets.zeroFloorSub(supplyAssets);

            if (suppliedAssets == 0) continue;

            uint256 supplyCap = config[id].cap;
            // v1: uses supplyCap == 0 as the unauthorized guard, not enabled check
            if (supplyCap == 0) revert ErrorsLib.UnauthorizedMarket(id);

            if (supplyAssets + suppliedAssets > supplyCap) revert ErrorsLib.SupplyCapExceeded(id);

            (, uint256 suppliedShares) =
                MORPHO.supply(allocation.marketParams, suppliedAssets, 0, address(this), hex"");

            emit EventsLib.ReallocateSupply(_msgSender(), id, suppliedAssets, suppliedShares);

            totalSupplied += suppliedAssets;
        }
    }

    if (totalWithdrawn != totalSupplied) revert ErrorsLib.InconsistentReallocation();
}
```

## Appendix C: zeroFloorSub Utility

```solidity
/// @dev Returns max(0, x - y).
function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
    assembly {
        z := mul(gt(x, y), sub(x, y))
    }
}
```

## Appendix D: _accruedSupplyBalance Internal

```solidity
function _accruedSupplyBalance(MarketParams memory marketParams, Id id)
    internal
    returns (uint256 assets, uint256 shares, Market memory market)
{
    MORPHO.accrueInterest(marketParams);

    market = MORPHO.market(id);
    shares = MORPHO.supplyShares(id, address(this));
    assets = shares.toAssetsDown(market.totalSupplyAssets, market.totalSupplyShares);
}
```

Note: `_accruedSupplyBalance` calls `accrueInterest()` first, which is a state-changing
operation. This means `reallocate()` is NOT a view function and modifies Morpho Blue state
(interest accrual) as a side effect.
