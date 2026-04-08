# EVM & DeFi Security Research: MetaMorpho Reallocate Hook

## Feature Context

A NONACCOUNTING Superform hook that calls `reallocate(MarketAllocation[] calldata allocations)` on MetaMorpho vaults to redistribute funds between Morpho Blue markets. The hook decodes `MarketAllocation[]` from calldata and forwards it to the target MetaMorpho vault. Called by SuperVault managers who hold allocator/curator roles on the MetaMorpho vault.

---

## 1. RELEVANT VULNERABILITY PATTERNS

### 1.1 Calldata Forwarding and ABI Encoding Risks

**Pattern**: The hook decodes variable-length `MarketAllocation[]` data from Superform's packed byte format, then re-encodes it for the `reallocate()` call. Incorrect decoding or re-encoding of the struct array can lead to malformed calldata that either reverts harmlessly or, in edge cases, targets unintended markets.

**Relevance**: HIGH. The `MarketAllocation` struct contains a nested `MarketParams` struct with 5 fields (4 addresses + 1 uint256), plus the outer `assets` uint256. Variable-length arrays of nested structs are the most error-prone ABI encoding pattern. Existing Morpho loan hooks in this codebase (`BaseMorphoLoanHook.sol`) use fixed-offset `BytesLib.toAddress` / `BytesLib.toUint256` decoding, but this hook must handle a dynamic array of structs -- a fundamentally different decoding challenge.

**Specific risks**:
- Off-by-one errors in byte offset calculations when the array length varies
- Truncated calldata passing silently (Solidity's `abi.decode` reverts on underflow, but manual BytesLib slicing may not)
- Encoding the struct array incorrectly for the external call, causing MetaMorpho to misinterpret market params

### 1.2 Access Control Bypass via Hook Chaining

**Pattern**: Superform hooks are executed by smart accounts via ERC-7579 modules. The `msg.sender` to MetaMorpho's `reallocate()` will be the smart account (SuperVault strategy), not the human manager. If the smart account holds allocator role on MetaMorpho but the Superform access control layer (who can trigger this hook) is insufficiently restrictive, unauthorized parties could trigger reallocations.

**Relevance**: HIGH. From Superform's `SECURITY.md`: "Hooks are external contracts and may not always be trustworthy." The trust boundary here is dual-layered:
1. Superform level: Who can call `executeHooks()` on the SuperVaultStrategy
2. MetaMorpho level: The smart account must hold allocator/curator/owner role

If Superform's access control allows any account to trigger this hook execution on the smart account, and the smart account has allocator role, the attacker effectively inherits allocator privileges.

### 1.3 Denial of Service via Griefing the Net-Zero Invariant

**Pattern**: MetaMorpho's `reallocate()` requires `totalWithdrawn == totalSupplied`. A third party can grief the reallocation by front-running with actions that change market balances (donations to Morpho Blue, large deposits/withdrawals from the MetaMorpho vault itself), causing the pre-computed allocations to no longer sum to net-zero.

**Relevance**: MEDIUM. The reallocation will simply revert with `InconsistentReallocation`, causing no fund loss but wasting gas and requiring recomputation. This is a griefing/DOS vector, not a fund-loss vector.

**MetaMorpho's own documentation notes**: "The function's behavior can be altered by concurrent deposits, withdrawals, donations, or market-level transactions."

### 1.4 Supply Cap Overflow via Concurrent Operations

**Pattern**: Between when the allocation array is computed off-chain and when `reallocate()` executes on-chain, other deposits to the MetaMorpho vault or direct supplies to Morpho Blue markets could push a market's supply close to its cap. The reallocation then reverts because supply would exceed the cap.

**Relevance**: MEDIUM. Causes revert (no fund loss), but is a liveness issue. MetaMorpho enforces: `if (supplyAssets + suppliedAssets > supplyCap) revert AllCapsReached()`.

### 1.5 Stale Interest Accrual Leading to Incorrect Allocation Amounts

**Pattern**: `reallocate()` calls `_accruedSupplyBalance()` which triggers `MORPHO.accrueInterest()` before reading each market's current balance. If significant time has passed since the allocation was computed off-chain, accrued interest changes the actual supply balances, potentially making the intended allocation amounts incorrect for achieving the desired target distribution.

**Relevance**: LOW-MEDIUM. No fund loss (net-zero invariant still holds), but the resulting allocation may differ from the manager's intent. The `type(uint256).max` pattern on the last allocation mitigates this for the "absorb remaining" use case.

### 1.6 Reentrancy via External Protocol Callbacks

**Pattern**: Morpho Blue's `supply()` and `withdraw()` functions interact with external tokens via ERC-20 `transfer`/`transferFrom`. If the underlying loan token has callback mechanisms (ERC-777, hooks on transfer), there is a theoretical reentrancy vector during the reallocation.

**Relevance**: LOW for this specific hook. MetaMorpho's `reallocate()` operates atomically within a single call and Morpho Blue explicitly documents: "The token should not re-enter Morpho on transfer nor transferFrom." Additionally, Superform's `BaseHook` uses transient storage mutexes (`PRE_EXECUTE_ALREADY_CALLED` / `POST_EXECUTE_ALREADY_CALLED`) that prevent hook-level reentrancy. However, the risk exists if weird ERC-20 tokens (fee-on-transfer, rebasing, ERC-777) are used as loan tokens in Morpho Blue markets.

### 1.7 `usePrevHookAmount` Injection into Allocation Array

**Pattern**: If the hook supports `usePrevHookAmount` to modify one allocation entry's `assets` field from a previous hook's output, the integration point must be carefully validated. An attacker who controls the previous hook's output could inject an arbitrary amount into one allocation, potentially:
- Setting a supply amount that violates the net-zero invariant (causing revert -- safe)
- Setting `type(uint256).max` on a non-terminal allocation entry (undefined behavior if not the final supply)
- Setting `0` on an entry, triggering full withdrawal from that market

**Relevance**: MEDIUM. MetaMorpho's own invariants protect against fund loss (net-zero check, supply caps), but malicious `usePrevHookAmount` values could cause unexpected market exposure changes or griefing reverts.

---

## 2. EXPLOIT PRECEDENTS

### 2.1 Morpho Blue Oracle Misconfiguration Exploit (October 2024)

**What happened**: An attacker exploited a permissionlessly deployed Morpho Blue market with a misconfigured oracle (incorrect `SCALE_FACTOR` due to decimal mismatch between USDC 6 decimals and PAXG 18 decimals). The oracle overvalued PAXG by 10^12, treating gold at $2.6 trillion. The attacker deposited $351 of PAXG and borrowed $230,000 in USDC.

**Relevance to this hook**: The attack was isolated to a single misconfigured market, not a protocol-level vulnerability. However, if the reallocate hook redirects funds into a market with a compromised or misconfigured oracle, the vault's funds in that market become exposed to oracle-based attacks (bad debt from inflated borrowing against the vault's supply position).

**Mitigation**: MetaMorpho's supply cap mechanism limits exposure per market. The curator/owner must vet markets before adding them to the vault's supply queue. The hook itself should not validate market safety (that is MetaMorpho's responsibility), but the hook's documentation should warn that reallocation to compromised markets amplifies exposure.

**Source**: [Morpho User Exploits Oracle Error](https://thedefiant.io/news/defi/morpho-user-exploits-oracle-error-to-turn-usd350-into-usd230k), [QuillAudits analysis](https://medium.com/coinmonks/decoding-morphoblues-230k-exploit-6296565ced40)

### 2.2 Aerodrome cUSDO/USDC LP Oracle Manipulation on Morpho (May 2025)

**What happened**: An attacker used a 6.66M USDC flash loan to manipulate an AMM LP token oracle used as collateral pricing in a Morpho lending market. By executing massive swaps to skew pool reserves, the LP token price was inflated, allowing over-borrowing. The attacker then reversed the swaps and self-liquidated, creating ~49,303 USDC in bad debt.

**Relevance to this hook**: If a MetaMorpho vault has exposure to markets that use manipulable oracles, reallocating more funds into those markets increases the vault's exposure to oracle manipulation attacks. The reallocate hook amplifies risk by concentrating supply into potentially vulnerable markets.

**Mitigation**: This is a market curation risk, not a hook-level risk. The hook should not attempt to validate oracle safety. The curator's due diligence on market parameters is the primary defense.

**Source**: [Morpho Governance Forum Post-Mortem](https://forum.morpho.org/t/post-mortem-aerodrome-cusdo-usdc-amm-lp-oracle-manipulation-on-morpho-lending-market/1794)

### 2.3 Morpho App Bundler3 Approval Misdirection (April 2025)

**What happened**: A frontend/SDK misconfiguration caused token approvals to be granted to Morpho's Bundler3 contract instead of its adapter contracts. Because Bundler3 lacks initiator-based access restrictions (by design), anyone could craft transactions to drain approved tokens. One user's transaction was intercepted by a white hat.

**Relevance to this hook**: The incident demonstrates the risk of approval misdirection in Morpho's ecosystem. For the reallocate hook specifically, no ERC-20 approvals are involved (reallocate operates on the vault's existing Morpho Blue positions), so this exact attack vector does not apply. However, it reinforces the importance of ensuring the hook's `Execution.target` is exactly the intended MetaMorpho vault address and not a proxy or substitute.

**Source**: [Morpho App Incident Report](https://morpho.org/blog/morpho-app-incident-april-10-2025/)

### 2.4 Penpie Finance Reentrancy ($27M, September 2024)

**What happened**: An attacker exploited a missing `nonReentrant` modifier on `batchHarvestMarketRewards()` in Penpie Finance (a Pendle-based yield protocol). The attacker created a fake Pendle Market to gain reentry during reward harvesting, manipulating reward calculations to drain funds.

**Relevance to this hook**: Demonstrates that vault management functions (harvesting, reallocation, reward distribution) that interact with external protocols are prime targets for reentrancy if guards are missing. The Superform `BaseHook` provides transient storage mutexes, and MetaMorpho's `reallocate()` does not have callback mechanisms, but this precedent reinforces the need for reentrancy protection at the hook execution layer.

**Source**: [Three Sigma 2024 DeFi Exploits Analysis](https://threesigma.xyz/blog/exploit/2024-defi-exploits-top-vulnerabilities)

### 2.5 DeltaPrime Improper Input Validation ($4.85M, 2024)

**What happened**: Unchecked parameters in debt-swap functions allowed attackers to bypass repayment logic and manipulate reward claims.

**Relevance to this hook**: The hook accepts variable-length calldata (`MarketAllocation[]`) that is decoded and forwarded to an external contract. If the hook does not validate the decoded data's structural integrity (correct array length, non-zero market params where required), malformed inputs could cause unexpected behavior.

**Source**: [Three Sigma 2024 DeFi Exploits Analysis](https://threesigma.xyz/blog/exploit/2024-defi-exploits-top-vulnerabilities)

---

## 3. ATTACK SURFACE MAP

### Category A: Calldata Integrity

| # | Attack Vector | Severity | Likelihood | Impact |
|---|---|---|---|---|
| A1 | Malformed `MarketAllocation[]` encoding causes misinterpreted market params | HIGH | LOW | Funds redirected to wrong Morpho market |
| A2 | Truncated calldata produces partial allocation array | MEDIUM | LOW | Revert or incomplete reallocation |
| A3 | `usePrevHookAmount` injects unexpected value into allocation entry | MEDIUM | MEDIUM | Net-zero invariant violation (revert) or unintended allocation |
| A4 | ABI encoding mismatch between hook's encoding and MetaMorpho's decoding | HIGH | LOW | Silent misinterpretation of allocation targets |

### Category B: Access Control

| # | Attack Vector | Severity | Likelihood | Impact |
|---|---|---|---|---|
| B1 | Unauthorized trigger of hook execution via Superform access control gap | HIGH | LOW | Unauthorized reallocation of vault funds between markets |
| B2 | Hook called with arbitrary MetaMorpho vault address (since vault address is in hook data, not constructor) | MEDIUM | MEDIUM | Execution targets wrong vault or non-vault contract |
| B3 | Allocator role revoked between hook submission and execution | LOW | LOW | Transaction reverts (no fund loss) |

### Category C: Protocol Interaction

| # | Attack Vector | Severity | Likelihood | Impact |
|---|---|---|---|---|
| C1 | Front-running changes market balances, breaking net-zero invariant | LOW | MEDIUM | Revert (griefing, no fund loss) |
| C2 | Flash loan manipulates Morpho Blue market state before reallocation | MEDIUM | LOW | Reallocation succeeds with suboptimal allocation (interest/share manipulation) |
| C3 | Market oracle compromise after reallocation concentrates funds | HIGH | LOW | Bad debt exposure in targeted market |
| C4 | Concurrent MetaMorpho deposit/withdrawal changes supply during reallocation | LOW | MEDIUM | Slightly different allocation than intended |
| C5 | Token with callbacks (ERC-777) enables reentrancy during Morpho supply/withdraw | MEDIUM | VERY LOW | Only applies to non-standard tokens; Morpho documents this assumption |

### Category D: Economic / MEV

| # | Attack Vector | Severity | Likelihood | Impact |
|---|---|---|---|---|
| D1 | Sandwich attack: observe pending reallocation, manipulate target market rates before/after | MEDIUM | MEDIUM | Vault gets worse interest rates during the block of reallocation |
| D2 | Strategic reallocation to low-utilization markets reduces vault yield | MEDIUM | LOW | Requires malicious allocator (trust assumption) |
| D3 | Reallocation used to drain liquidity from one market, enabling oracle manipulation in that market | HIGH | VERY LOW | Complex multi-step attack requiring allocator role |

### Category E: Hook-Specific

| # | Attack Vector | Severity | Likelihood | Impact |
|---|---|---|---|---|
| E1 | Zero-address MetaMorpho vault in hook data | LOW | LOW | Revert at address(0) call |
| E2 | Hook data points to a contract that is not a MetaMorpho vault | MEDIUM | MEDIUM | Unpredictable behavior from arbitrary `reallocate()` selector match |
| E3 | Empty allocations array passed to reallocate() | LOW | LOW | Reverts or no-op (net-zero of zero) |
| E4 | `type(uint256).max` used on non-terminal allocation entry | LOW | LOW | MetaMorpho handles this with `zeroFloorSub`; may cause unexpected allocation |

---

## 4. RECOMMENDED SECURITY PATTERNS

### 4.1 Input Validation (MUST HAVE)

```solidity
// Validate MetaMorpho vault address is non-zero
if (metaMorphoVault == address(0)) revert ADDRESS_NOT_VALID();

// Validate allocations array is not empty
if (allocations.length == 0) revert AMOUNT_NOT_VALID();
```

**Rationale**: Zero-address or empty-array inputs cause confusing reverts deep in the MetaMorpho contract. Early validation provides clear error messages and prevents wasted gas on doomed transactions.

### 4.2 Strict ABI Encoding for External Call (MUST HAVE)

```solidity
// Use abi.encodeCall for type-safe encoding (compiler-checked)
bytes memory callData = abi.encodeCall(
    IMetaMorpho.reallocate,
    (allocations)
);
```

**Rationale**: `abi.encodeCall` provides compile-time type checking, preventing ABI encoding mismatches. This is critical for the `MarketAllocation[]` struct array which has complex nested encoding. Never use `abi.encodeWithSelector` or `abi.encodeWithSignature` for this pattern as they lack type safety.

### 4.3 Transient Storage Mutex (INHERITED -- ALREADY IN PLACE)

The `BaseHook` contract already provides transient storage mutexes via `PRE_EXECUTE_ALREADY_CALLED` and `POST_EXECUTE_ALREADY_CALLED` checks. These prevent reentrancy at the hook execution layer. No additional reentrancy guards are needed in the hook itself.

### 4.4 Minimal Hook Surface Area (MUST HAVE)

```solidity
// The hook should ONLY build the execution calldata.
// It should NOT:
// - Hold any token balances
// - Make any state changes beyond BaseHook's transient storage
// - Perform any token approvals
// - Have any payable functions
// - Accept native ETH
```

**Rationale**: The reallocate hook is purely a calldata forwarding mechanism. Keeping it stateless (beyond BaseHook's transient storage) eliminates entire classes of vulnerabilities (token drainage, stuck funds, approval exploits). MetaMorpho's `reallocate()` operates on the vault's existing Morpho Blue positions and does not require any token transfers from the caller.

### 4.5 `usePrevHookAmount` Bounds Checking (RECOMMENDED)

If `usePrevHookAmount` modifies an allocation entry's `assets` field, consider:
- The modified value should not be `0` unless the manager explicitly intends full withdrawal
- The modified value should be validated against reasonable bounds
- Document that `usePrevHookAmount` with `reallocate()` is inherently dangerous because the net-zero invariant depends on all entries summing correctly

**Rationale**: Unlike simple token transfer hooks where `usePrevHookAmount` sets a single amount, here it modifies one entry in an array that must satisfy a global constraint (net-zero). A stale or unexpected previous hook output breaks the constraint.

### 4.6 No Return Value Dependency (RECOMMENDED)

```solidity
// reallocate() returns void. The hook's _postExecute should not
// attempt to read return values. For NONACCOUNTING hooks, outAmount
// tracking may not be meaningful.
```

**Rationale**: Since `reallocate()` has no return value and is a NONACCOUNTING operation, the hook should not set meaningful `outAmount` values. If `_preExecute` and `_postExecute` are implemented, they should be no-ops or minimal (consistent with other NONACCOUNTING hooks like `SetOperator7540Hook`).

### 4.7 Event Emission for Off-Chain Monitoring (RECOMMENDED)

MetaMorpho's `reallocate()` does not emit a dedicated event (the underlying Morpho Blue `supply` and `withdraw` calls emit events). Consider whether the Superform system's existing hook execution events provide sufficient audit trail, or whether additional off-chain monitoring of the underlying Morpho Blue events is needed.

---

## 5. PROTOCOL INTERACTION RISKS

### 5.1 How reallocate() Interacts with Morpho Blue

```
MetaMorpho.reallocate(allocations[])
    |
    +-- For each allocation:
    |   +-- MORPHO.accrueInterest(marketParams)  // Updates interest state
    |   +-- _accruedSupplyBalance(marketParams)   // Reads current supply
    |   |
    |   +-- If current > target: MORPHO.withdraw(...)  // Pull from market
    |   |   +-- totalWithdrawn += withdrawn
    |   |
    |   +-- If target > current: MORPHO.supply(...)    // Push to market
    |       +-- Check supplyCap
    |       +-- totalSupplied += supplied
    |
    +-- REQUIRE: totalWithdrawn == totalSupplied  // Net-zero invariant
```

### 5.2 Interest Accrual Timing

Each market's interest is accrued at the start of its processing within `reallocate()`. This means:
- Markets processed earlier in the array have their interest accrued before markets processed later
- The order of allocations can affect the exact amounts withdrawn/supplied due to interest accrual
- Between the off-chain computation and on-chain execution, additional interest accrues, potentially invalidating exact amounts

**Risk**: If the hook constructs exact `assets` values off-chain, they may not match on-chain reality. Using `type(uint256).max` for the last supply entry absorbs this difference.

### 5.3 Morpho Blue's Singleton Architecture

Morpho Blue is a singleton contract -- all markets share the same contract. This means:
- `reallocate()` calls `MORPHO.withdraw()` and `MORPHO.supply()` on the same target contract
- The MetaMorpho vault's ERC-20 `approve` for Morpho Blue covers all markets (since they use the same contract)
- There is no per-market isolation at the contract level; isolation is purely accounting-based within Morpho Blue's storage

**Risk**: A vulnerability in Morpho Blue itself could affect all markets simultaneously. The hook cannot mitigate this risk.

### 5.4 Supply Cap Enforcement

MetaMorpho enforces per-market supply caps during reallocation:
```solidity
if (supplyAssets + suppliedAssets > supplyCap) revert AllCapsReached();
```

**Important**: The cap check is against the market's total supply from this MetaMorpho vault, not just the reallocation amount. If other deposits to the vault have increased the market's supply since the allocation was computed, the cap check may fail.

**Risk**: Liveness issue (transaction reverts), not a fund loss risk.

### 5.5 Market Removal Interaction

If a market is in the process of being removed from the MetaMorpho vault (via `submitMarketRemoval()`), `reallocate()` can still withdraw from it (it can withdraw from any market with the same loan token, even if not in the withdraw queue). However, it cannot supply to a market that has been removed or has a zero supply cap.

**Risk**: A malicious allocator could use `reallocate()` to move all funds out of a market that is about to be removed, then into a market with higher risk exposure. This is a trust assumption on the allocator role.

### 5.6 Idle Market

MetaMorpho vaults can have an "idle" market (collateralToken = address(0), LLTV = 0) that holds guaranteed-withdrawable liquidity. Reallocation can move funds in/out of the idle market like any other market.

**Risk**: Moving all funds out of the idle market reduces the vault's instant withdrawal liquidity. This is intentional behavior controlled by the allocator, but has implications for user withdrawal availability.

### 5.7 Try/Catch in Internal Supply/Withdraw (MetaMorpho v1.1+)

MetaMorpho v1.1 uses try/catch around individual market supply/withdraw operations, allowing reallocation to continue even if one market reverts. This means:
- A single broken market does not block all reallocations
- The try/catch silently swallows errors, which means a market might not receive its intended allocation without explicit notification

**Risk**: The net-zero invariant check at the end still applies. If a supply is silently skipped, `totalSupplied` will be less than `totalWithdrawn`, causing the entire reallocation to revert. This is actually a safety mechanism.

---

## 6. TESTING RECOMMENDATIONS

### 6.1 Fuzz Testing Scenarios

#### Fuzz Test 1: Random Allocation Arrays
```
Invariant: For any valid MarketAllocation[] where markets exist and are enabled,
           reallocate() either succeeds with totalWithdrawn == totalSupplied
           or reverts with a known error.

Fuzz inputs:
- Number of allocations: 1 to MAX_QUEUE_LENGTH
- Assets per allocation: 0, 1, random, type(uint256).max
- Market params: mix of valid and invalid markets
```

#### Fuzz Test 2: usePrevHookAmount Injection
```
Invariant: When usePrevHookAmount modifies one allocation entry, the hook
           correctly constructs calldata that MetaMorpho can decode.

Fuzz inputs:
- Previous hook outAmount: 0, 1, random, type(uint256).max
- Position of modified entry in array: first, middle, last
- Original allocation's assets value before modification
```

#### Fuzz Test 3: Calldata Encoding Round-Trip
```
Invariant: encode(decode(hookData)) == hookData for any valid input.

Fuzz inputs:
- Random MarketAllocation[] arrays with varying lengths
- Random MarketParams combinations
- Boundary values for assets (0, 1, type(uint256).max)
```

### 6.2 Unit Test Scenarios

| # | Test Case | Expected Behavior |
|---|---|---|
| U1 | Zero-address MetaMorpho vault | Revert with `ADDRESS_NOT_VALID()` |
| U2 | Empty allocations array | Revert (or defined behavior per hook design) |
| U3 | Single allocation (withdraw all from one market) | Reverts at MetaMorpho level (net-zero violation) |
| U4 | Two allocations: withdraw from A, supply to B (balanced) | Success; verify calldata encoding |
| U5 | Three allocations with `type(uint256).max` on last | Success; verify encoding of max value |
| U6 | `usePrevHookAmount` with valid previous hook output | Modified allocation entry has correct assets value |
| U7 | `usePrevHookAmount` with zero previous hook output | Defined behavior (revert or allow zero) |
| U8 | Large allocation array (20+ entries) | Verify gas and encoding correctness |
| U9 | Allocation with all zero addresses in MarketParams | MetaMorpho reverts (market does not exist) |
| U10 | Hook build() returns correct Execution[] structure | Target is MetaMorpho vault, callData is correct selector + encoding |
| U11 | preExecute and postExecute are no-ops for NONACCOUNTING | No state changes beyond mutex |
| U12 | inspect() returns expected encoded data | Correct abi.encodePacked of vault address |

### 6.3 Integration Test Scenarios (Forked Mainnet)

| # | Test Case | Expected Behavior |
|---|---|---|
| I1 | Reallocate between two real Morpho Blue markets on mainnet fork | Success; verify market balances changed |
| I2 | Reallocate with amount exceeding supply cap | Revert with supply cap error |
| I3 | Reallocate with net-zero violation | Revert with `InconsistentReallocation` |
| I4 | Reallocate with `type(uint256).max` on last entry | Success; last market absorbs remainder |
| I5 | Reallocate with `assets = 0` to withdraw all from a market | Success; market fully exited |
| I6 | Reallocate when caller lacks allocator role | Revert with access control error |
| I7 | Sequential reallocations in same transaction | Both succeed independently |
| I8 | Reallocate after interest accrual changes balances | Success; amounts may differ slightly from pre-computed |

### 6.4 Invariant Testing

```
// Global invariants to validate:

INVARIANT_1: The hook never holds any token balance after execution.
             (NONACCOUNTING hook should be completely stateless regarding tokens)

INVARIANT_2: The hook's build() output always produces exactly one Execution
             targeting the MetaMorpho vault with the reallocate() selector,
             plus the pre/post execute calls.

INVARIANT_3: For any input, either the hook reverts with a known error
             or produces valid calldata that MetaMorpho can decode.

INVARIANT_4: The MetaMorpho vault's total assets (across all markets)
             do not change after a successful reallocate() call
             (net-zero invariant, verified from outside the hook).

INVARIANT_5: The hook's transient storage is properly cleaned up after
             execution (inherited from BaseHook's resetExecutionState).
```

### 6.5 Negative Test Scenarios

| # | Test Case | Expected Behavior |
|---|---|---|
| N1 | Call hook with non-MetaMorpho contract address | Revert (no `reallocate` function or wrong signature) |
| N2 | Call hook directly (not through SuperVault execution flow) | Revert with `UNAUTHORIZED_CALLER()` |
| N3 | Double preExecute call | Revert with `PRE_EXECUTE_ALREADY_CALLED()` |
| N4 | Reentrancy attempt during hook execution | Revert due to transient storage mutex |
| N5 | Extremely large allocation array (gas limit test) | Revert due to out-of-gas or MetaMorpho's queue length limit |

---

## Sources

- [MetaMorpho Source Code (GitHub)](https://github.com/morpho-org/metamorpho/blob/main/src/MetaMorpho.sol)
- [MetaMorpho v1.1 (GitHub)](https://github.com/morpho-org/metamorpho-v1.1)
- [Morpho Vaults Documentation](https://docs.morpho.org/morpho-vaults/contracts/overview/)
- [Morpho Risk & Security Documentation](https://docs.morpho.org/learn/resources/risks/)
- [Morpho Audits](https://docs.morpho.org/get-started/resources/audits/)
- [Morpho Bug Bounty (Immunefi)](https://immunefi.com/bug-bounty/morpho/information/)
- [Morpho App Incident April 2025](https://morpho.org/blog/morpho-app-incident-april-10-2025/)
- [Morpho Oracle Exploit (The Defiant)](https://thedefiant.io/news/defi/morpho-user-exploits-oracle-error-to-turn-usd350-into-usd230k)
- [Aerodrome cUSDO/USDC Oracle Manipulation Post-Mortem](https://forum.morpho.org/t/post-mortem-aerodrome-cusdo-usdc-amm-lp-oracle-manipulation-on-morpho-lending-market/1794)
- [MetaMorpho Internals (Taichi Audit)](https://taichiaudit.com/blog/morpho-internals-part-4-metamorpho)
- [MetaMorpho DeepWiki](https://deepwiki.com/morpho-org/metamorpho/2.1-metamorpho-vault)
- [2024 Most Exploited DeFi Vulnerabilities (Three Sigma)](https://threesigma.xyz/blog/exploit/2024-defi-exploits-top-vulnerabilities)
- [MetaMorpho Cantina Competition](https://cantina.xyz/competitions/8409a0ce-6c21-4cc9-8ef2-bd77ce7425af)
- [Superform v2-core SECURITY.md](/Users/cosming/1.Coding/Superform/v2-core/SECURITY.md)
- [Superform BaseHook.sol](/Users/cosming/1.Coding/Superform/v2-core/src/hooks/BaseHook.sol)
- [Existing Morpho Loan Hooks](/Users/cosming/1.Coding/Superform/v2-core/src/hooks/loan/morpho/)
