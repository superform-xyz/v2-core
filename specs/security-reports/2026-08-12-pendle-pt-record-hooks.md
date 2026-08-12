# Security Analysis Report

## Metadata
- **Target:** Pendle PT record-hooks feature (branch `feat/pendle-pt-record-hooks`)
  - `src/hooks/swappers/pendle/PendlePTHook.sol` (extended: `IPendlePTHookResult` producer)
  - `src/interfaces/IPendlePTHookResult.sol` (new)
  - `src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol` (new)
  - `src/hooks/oracles/pendle/RecordRedemptionPendlePTHook.sol` (new)
- **Mode:** review (inline critical-pattern scan + 3 parallel agents: vulnerability scanner, best-practices, external EVM research)
- **Date:** 2026-08-12
- **Contract Types Detected:** ERC-7579 executor hook modules (swap producer + two side-effect oracle recorders), oracle integration
- **Files Analyzed:** 4 targets + context (`BaseHook.sol`, `PendlePTAmortizedOracleV2.sol`, `IPendlePTAmortizedOracleV2.sol`, `IPendleMarket.sol`, the existing V2 record hooks, unit + fuzz + fork tests)
- **Vulnerability Database:** `/guidelines/solidity/vulnerabilities.md` (300+ patterns) cross-referenced; supplemented with SWC registry, OWASP SC Top 10 (2025), weird-erc20, and ERC-7579 hook literature.

## Execution model (context for all severity calls)
`build()` is view-only and stateless; the returned `Execution[]` runs **on the user's own smart account against its own balance**, and the hook address + full calldata are committed in the user's Merkle-signed intent. `SuperExecutor._processHook` is `nonReentrant` and wraps each hook with pre/post mutexes keyed by a per-account **execution-context nonce** (`BaseHook`), validating `lastCaller` post-execution. A record hook runs **immediately after an approved `PendlePTHook`** in the same sequence and reads that hook's `TradeResult` from transient storage. Consequently the surface is not "attacker drains victim" but: cross-context/cross-account leakage of the `TradeResult`, recording the wrong side (input vs output) or an inflated PT amount into the oracle, and weird-token balance-delta correctness.

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|--------------|
| P0 Critical | 0 | — |
| P1 High | 0 | — |
| P2 Medium | 1 | No |
| P3 Low | 3 | No |

## Verdict
**PASS** — No P0 or P1 findings. The single P2 (execution-context leakage of the `TradeResult`) and all three P3s have been remediated on this branch (see status below). Re-tested green.

## Remediation status (2026-08-12, same day)
- **P-1 FIXED** — `TradeResult` transient storage is now keyed by the per-account **execution-context nonce** (`_currentContext(account)`), not by `account` alone. Fix is **self-contained inside `PendlePTHook.sol`** — it recomputes the nonce by reading `BaseHook`'s `ACCOUNT_CONTEXT_STORAGE` slot; **`BaseHook.sol` is unchanged** (per the standing constraint). New fork test `test_TradeResult_ContextIsolation_RealMarket` reproduces the leak pre-fix and asserts `Operation.NONE` + recorder revert post-fix.
- **P-2 FIXED** — both recorders now build oracle calldata with `abi.encodeCall(IPendlePTAmortizedOracleV2.recordPurchase/recordRedemption, (...))` instead of stringly-typed `abi.encodeWithSignature(...)`.
- **P-3 FIXED** — added the missing `IPendlePTAmortizedOracleV2` import to `RecordRedemptionPendlePTHook.sol` (required by the `encodeCall` fix and for symmetry with the purchase recorder).
- **P-4 FIXED** — restored `@param`/`@return` NatSpec on the `decodeMarket` / `decodePtAmount` / `decodeTwapDuration` / `decodePtSold` decode helpers in both recorders.
- Tests after fixes: **42 unit** (record hooks) + **116** (existing `PendlePTHook`) + **40** (existing V2 record hooks) + **32 fork/E2E** — all green. Deploy bytecode invariant `fresh == generated == locked == locked-dev` re-verified for all three changed contracts (only `PendlePTHook` creation code changed; the recorders' cosmetic edits do not alter creation bytecode).

---

## P0 Findings (Critical)
None found.

## P1 Findings (High)
None found.

## P2 Findings (Medium)

### [P-1] `TradeResult` keyed by account only — leaks across execution contexts
- **File:** src/hooks/swappers/pendle/PendlePTHook.sol (`_tradeKey`)
- **SWC:** N/A (transient-storage isolation defect) — vulnerabilities.md §1 (reentrancy/stale-state family), §16 (context confusion)
- **Category:** Logic / State isolation
- **Description:** The `TradeResult` was written to and read from transient storage under a key derived from `(PT_TRADE_STORAGE, account, field)` — **account only**. `BaseHook`'s own execution state (out-amount, out-token, mutexes) is instead keyed by the per-account **execution-context nonce**, which increments on every `setExecutionContext(account)`. Because the `TradeResult` omitted the nonce, a trade recorded in one execution context remained readable in a **later** context for the same account within the same transaction (transient storage persists to end-of-tx). A record hook running in a subsequent context — or after the producing hook's context was rotated — could therefore consume a **stale** `TradeResult` and record it into the amortized oracle.
- **Exploit Scenario:** Within one tx, account A buys PT (context N, `TradeResult` = BUY_PT/ptReceived). A later hook sequence rotates to context N+1 and runs a redemption recorder in automatic mode; absent nonce keying it reads the stale BUY_PT result, passes the operation/market/PT checks against the wrong-context trade, and records a PT amount that does not correspond to any trade in the current context — corrupting the oracle's amortized rate. The `BaseHook`-native out-amount is immune to this precisely because it is nonce-keyed; the new `TradeResult` must match that isolation.
- **Fix (applied, self-contained — no `BaseHook` change):**
  ```solidity
  bytes32 private constant PT_TRADE_STORAGE = keccak256("pendle.pt.hook.trade");
  // MUST match BaseHook.ACCOUNT_CONTEXT_STORAGE — the slot holding the per-account context nonce.
  bytes32 private constant ACCOUNT_CONTEXT_STORAGE = keccak256("hook.account.context");

  function _currentContext(address account) private view returns (uint256 context) {
      bytes32 key = keccak256(abi.encodePacked(ACCOUNT_CONTEXT_STORAGE, account));
      assembly ("memory-safe") { context := tload(key) }
  }
  function _tradeKey(address account, uint256 field) private view returns (bytes32) {
      return keccak256(abi.encodePacked(PT_TRADE_STORAGE, _currentContext(account), account, field));
  }
  ```
- **Regression guard:** `test/integration/pendle/PendlePTHookE2E.t.sol::test_TradeResult_ContextIsolation_RealMarket` — real buy in context N, `setExecutionContext(user)` → context N+1, asserts `getPendleTradeResult` returns `Operation.NONE` and a redemption recorder reverts `OPERATION_NOT_VALID`.

## P3 Findings (Low)

### [P-2] Stringly-typed oracle calldata via `abi.encodeWithSignature`
- **File:** src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol / RecordRedemptionPendlePTHook.sol (`_buildHookExecutions`)
- **Category:** Code quality — vulnerabilities.md §15
- **Description:** Oracle executions were encoded with `abi.encodeWithSignature("recordPurchase(address,uint256,uint32)", ...)`. A silent signature-string typo or an oracle-side signature change would compile cleanly and only fail at runtime (or, worse, hash to an unintended selector). `abi.encodeCall` binds to the actual interface function and type-checks arguments at compile time.
- **Fix (applied):** `abi.encodeCall(IPendlePTAmortizedOracleV2.recordPurchase, (market, ptAmount, twapDuration))` and `abi.encodeCall(IPendlePTAmortizedOracleV2.recordRedemption, (market, ptSold))`. Creation bytecode is unchanged (identical selector + ABI encoding), so no re-lock was required for the recorders.

### [P-3] Missing `IPendlePTAmortizedOracleV2` import in the redemption recorder
- **File:** src/hooks/oracles/pendle/RecordRedemptionPendlePTHook.sol (imports)
- **Category:** Code quality — vulnerabilities.md §15
- **Description:** The redemption recorder referenced the oracle only through a signature string and did not import its interface, an inconsistency with the purchase recorder and a blocker for the `encodeCall` hardening above.
- **Fix (applied):** added `import { IPendlePTAmortizedOracleV2 } from "../../../vendor/pendle/IPendlePTAmortizedOracleV2.sol";`.

### [P-4] Incomplete NatSpec on public decode helpers
- **File:** both recorders (`decodeMarket`, `decodePtAmount`, `decodeTwapDuration`, `decodePtSold`)
- **Category:** Documentation — vulnerabilities.md §15
- **Description:** Public decode helpers carried a one-line `@notice` but no `@param`/`@return`, below the house standard for externally-callable ABI surface consumed by off-chain registry tooling.
- **Fix (applied):** added `@param data` / `@return` on each helper, clarifying that the decoded amount is the **fallback** used only when `usePrevHookAmount == false`.

---

## Attack-surface review of the requested focus areas (confirmed non-issues)
- **Cross-account leakage:** `TradeResult` key includes `account`; `preExecute`/`postExecute` enforce `msg.sender == account`. Cross-account read returns another account's key space, never the caller's. Covered by `test_CrossAccount_Isolation`.
- **Cross-execution leakage:** was the P-1 defect; now nonce-keyed and regression-tested.
- **Read-only reentrancy of `getPendleTradeResult` / `getOutAmount`:** both are `view` over transient storage with **no external calls**; there is no cross-contract state a reentrant reader could observe mid-update. The producing hook writes all `TradeResult` fields in a single `_postExecute` frame before any subsequent hook runs.
- **Balance-delta correctness under fee-on-transfer / rebasing PT or asset:** amounts are derived from **actual pre/post balance deltas of the account**, not router quotes — so a fee-on-transfer or rebasing token records the *realized* delta by construction. The input side uses an explicit underflow guard (`inputPreBal > inputPostBal ? inputPreBal - inputPostBal : 0`), and a resolved amount of `0` **always reverts** (`AMOUNT_NOT_VALID`) in both hooks. PT and Pendle SY are standard-return ERC20s (no rebasing), bounding real-world exposure.
- **Malicious `market.readTokens()` returning attacker-controlled PT:** the recorder binds `prevHook == immutable APPROVED_PENDLE_PT_HOOK` **before any external call**, requires `TradeResult.market == committed market`, and re-reads `readTokens()` on that same committed market, requiring PT (index 1) to equal the trade's output token (purchase) / input token (redemption). A rogue market cannot be substituted without failing the market-match check against the approved hook's recorded trade.
- **Prev-hook spoofing / operation-direction confusion:** purchase requires `operation == BUY_PT` and records `outputAmount`; redemption requires `operation ∈ {SELL_PT, REDEEM_PT}` and records `inputAmount` (the PT spent) — **never** the output asset (the original motivating bug). Cross-direction attempts revert `OPERATION_NOT_VALID` (fork-tested `test_RecordPurchase_RejectsSell_RealMarket`).
- **Native-ETH handling:** PT/SY legs are ERC20; the hooks never snapshot or move native ETH, so no native-balance edge case applies.
- **TWAP-min enforcement oracle-side only:** `recordPurchase` forwards `twapDuration` to `PendlePTAmortizedOracleV2`, which enforces `twapDuration >= getMinTwapDuration()`. Enforcement centralized in the oracle is intentional (single source of truth); the recorder passes it through and a too-small value reverts oracle-side.
- **No `PendlePTHook` regression:** existing `getOutAmount`/`getOutToken` semantics are untouched (116 unit + existing E2E green); the `TradeResult` is additive at new transient offsets.

## Sources
- `/guidelines/solidity/vulnerabilities.md` — §1 (reentrancy/stale-state), §4 (oracle), §10 (token integration / weird-ERC20), §15 (code quality), §16 (context confusion)
- SWC Registry (SWC-104 unchecked return — N/A here, raw transfers absent), OWASP Smart Contract Top 10 (2025)
- weird-erc20 (fee-on-transfer, rebasing, missing-return behaviors)
- Pendle V4 router / SY / PT / YT interfaces; `PendlePTAmortizedOracleV2` (`getPtToSyRate`, `getMinTwapDuration`)

---

## Addendum (2026-08-12, post-review): retarget to PendlePTAmortizedOracle (V1)

Product decision: the record hooks bind to **PendlePTAmortizedOracle (V1)**, not V2. Changes after this review:

- `RecordPurchasePendlePTHook` now encodes `abi.encodeCall(IPendlePTAmortizedOracle.recordPurchase, (market, sySpent, ptAmount))` — V1 signature `(address,uint256,uint256)`; the V2 selector `(address,uint256,uint32)` does not exist on V1. `sySpent` is computed ON-CHAIN as `ORACLE.getAssetOutput(market, address(0), ptAmount)` (the oracle's own PT→asset TWAP valuation, V1 books cost in SY accounting-asset units — never user input, calldata schema unchanged). `twapDuration` is now validated hook-side against `ORACLE.TWAP_DURATION()` (V1 has no per-call rate; new error `TWAP_DURATION_TOO_SHORT`).
- `RecordRedemptionPendlePTHook`: no functional change (`recordRedemption(address,uint256)` selector identical in V1/V2); import/doc rebound to the V1 interface.
- `IPendlePTAmortizedOracle` vendor interface extended with `TWAP_DURATION()` and `getAssetOutput()` views.
- `DeployV2Core.s.sol` wires both recorders to `configuration.pendlePTAmortizedOracles` (V1).
- New fork suite `test/integration/pendle/PendlePTHookV1AmortizedOracleE2E.t.sol` (14 tests): real router swaps on the live mAPOLLO market against a source-built V1 oracle AND the deployed mainnet instance (0xD640...eB62), incl. selector-compat documentation, arg-order pinning, amortization to par, pro-rata redemption, matured redeem, context isolation.
- Operational prerequisite surfaced by the fork tests: a Pendle market with observation cardinality 1 (mAPOLLO's shipped state) makes same-transaction swap→record IMPOSSIBLE (`OracleTargetTooOld` — any trade resets the single observation). `increaseObservationsCardinalityNext` (permissionless) + buffer fill is required before onboarding a market to this flow.
