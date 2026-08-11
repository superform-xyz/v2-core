# Security Analysis Report — Aave V3 Loan-Hook Suite

## Metadata
- **Target:** `src/hooks/loan/aave-v3/` (BaseAaveV3LoanHook + 7 hooks) + `src/vendor/aave-v3/` (IPool, DataTypes)
- **Mode:** review (inline scan + 2 parallel agents: vulnerability scanner, coding standards)
- **Date:** 2026-08-05
- **Contract type:** Lending-protocol integration — pure `Execution[]` builder hooks (NONACCOUNTING), no custody, no roles
- **Files analyzed:** 10
- **Vulnerability DB:** `superform-specs/guidelines/solidity/vulnerabilities.md` (36 sections, 300+ patterns)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 0 | No |
| P3 Low / Informational | 6 | No |

## Verdict
**PASS** — No P0/P1/P2 findings. The suite is soundly constructed for a pure-builder, no-custody execution model. The one CI-blocking item (`forge fmt`) has been fixed. Remaining items are low-severity design notes and cosmetics.

---

## Execution-model framing (why severity is low by construction)
These hooks only **build** an `Execution[]` (via `view` `_buildHookExecutions`) that the user's own ERC-7579 smart account later executes. They custody no funds, hold no privileged roles, and hardcode `onBehalfOf`/`to = account`. Therefore the classic lending-protocol criticals — oracle→bad-debt, liquidation MEV, first-depositor/share inflation — are **protocol-owned (Aave V3)** and cannot be introduced by a hook. They are explicitly out of scope (noted below), not findings.

---

## P0 / P1 / P2
None found.

## P3 — Low / Informational

### P3-1 — `usePrevHookAmount` has no prev-hook out-token identity guard
- **File:** all 7 hooks, `_buildHookExecutions` · **Category:** Business logic / input validation · **Ref:** §14.3
- When `usePrevHookAmount` is set, the hook adopts `prevHook.getOutAmount(account)` without checking `prevHook.getOutToken(account)` matches the token it operates on. A mis-chained bundle uses an amount denominated in the wrong token/decimals.
- **No theft vector:** `onBehalfOf`/`to` is hardcoded to `account`, so the account can only ever move *its own* tokens into *its own* Aave position. Failure mode is safe — an insufficient-balance revert on the approve/`transferFrom`, or the account acts on an unintended amount of a token it holds.
- **Status:** Accepted design (matches audited V4). Leg sizing is the bundler's responsibility, documented in NatSpec. Optional hardening: assert `getOutToken == operatingToken` to fail fast.

### P3-2 — Unvalidated calldata `pool` is approved and called
- **File:** `BaseAaveV3LoanHook` decoders + supply/repay approve+call executions · **Category:** Arbitrary external call / token integration · **Ref:** §8.2, §10.5
- `pool` (offset 92) is untrusted calldata; supply/repay/combined hooks `approve(pool, amount)` then call `pool.supply/repay(...)`. A malicious `pool` could pull the granted allowance during that call.
- **Within trust boundary:** the entire `hookData` (including `pool`) is part of the **user-signed intent** executed by the user's own account — equivalent to a user signing a tx targeting an address they chose; it only affects the account that selected it. Allowance hygiene is correct: every supply/repay path resets `approve(pool, 0)` **after** the call, so no dangling allowance persists. Borrow/Withdraw/RepayWithATokens grant no allowance. Matches the V4 spoke model.
- **Intended control (off-chain):** `inspect()` returns `abi.encodePacked(pool)` precisely so an allowlist/validator can pin `pool` to canonical Aave Pool addresses before signing. **Recommend enforcing that allowlist in intent construction.**

### P3-3 — `repayWithATokens(max)` silently leaves residual debt — **ADDRESSED**
- **File:** `AaveV3RepayWithATokensHook` (documented in header) · **Category:** Business logic · **Ref:** §14.4
- `repayWithATokens(max)` repays `min(currentDebt, aTokenBalance)`; if aToken balance < debt it does not revert, leaving residual debt (a chained `withdraw(max)` may then hit an HF revert). Funds never at risk.
- **Resolution:** No on-chain fix is possible — the hook is a stateless builder and cannot read aToken-balance-vs-debt at build time. The header NatSpec was strengthened with the explicit **off-chain mitigation**: the bundler must not chain `repayWithATokens(max) → withdraw(max)` when aToken balance may be below debt; route `AaveV3RepayHook(max)` for a guaranteed full close, or size the follow-on withdraw to actual post-repay collateral.

### P3-4 — Degenerate `loanToken == collateralToken` combined config fails via checked-math revert
- **File:** combined hooks `_postExecute` · **Category:** Edge case · **Ref:** §29
- If a caller sets `loanToken == collateralToken` (nonsensical), the second leg moves the same balance measured by the `pre−post` delta, and the subtraction can underflow → **safe revert** (Solidity 0.8). Not exploitable; degenerate config fails closed.

### P3-5 — `forge fmt` non-compliance (5 files) — **FIXED**
- Two `amountRoles` lines in the combined hooks exceeded 120 chars; 5 files had `forge fmt` diffs (CI `forge fmt --check` would fail). **Resolved:** ran `forge fmt`; `--check` now reports 0 diffs; build + unit tests re-confirmed green.

### P3-6 — Missing NatSpec on `name()`/`description()` (all 7 hooks) — **FIXED**
- **Ref:** coding-rules.md line 51 (NatSpec for public/external). The sibling V4 suite documents these; V3 omitted them — a minor convention regression.
- **Resolution:** Added `/// @notice Human-readable name for UI display` and `/// @notice One-sentence description of what this hook does` to `name()`/`description()` on all 7 hooks (parity with V4). `forge fmt` clean; build + unit tests re-confirmed green.

---

## Attack Surface Summary
- **External entry points:** `build`/`preExecute`/`postExecute`/`inspect`/`decodeAmounts`/`replaceCalldataAmounts`/`amountRoles`/`decodeUsePrevHookAmount` — `preExecute`/`postExecute` enforce `msg.sender == account` + one-shot mutexes (BaseHook); the rest are `view`/`pure`.
- **Value transfer points:** none in the hooks — they only emit `Execution[]` the account runs (approve/supply/withdraw/borrow/repay to the calldata `pool`).
- **Oracle dependencies:** none in-hook (Aave-owned).
- **Cross-contract interactions:** Aave V3 `IPool` (address from calldata), ERC20 approve on the user token.
- **Upgrade mechanisms:** none — stateless, argless constructors, no admin.

## Out of Scope — Protocol-Owned (noted, not hook findings)
- Oracle manipulation → bad debt, liquidation MEV, first-depositor/share inflation (§4, §17.3, §18.4, §22.1) — owned by Aave V3.
- Fee-on-transfer / rebasing / >18-decimal tokens (§10.1/10.2/46) — out-amount accounting uses real `balanceOf` deltas, so measured amounts are accurate; nominal amounts passed to Aave are an Aave-side compatibility concern.
- Missing-return tokens/USDT (§10.3) — handled: `approve(pool,0)` precedes every `approve(pool,amount)` (USDT set-to-zero-first); return-checking is the executing account's responsibility.

## Confirmed non-issues
- **Byte offsets & bounds:** loanToken@52, collateralToken@72, pool@92, rate@112; SW amount@112/usePrev@144 (min 145), BR amount@113/usePrev@145 (min 146), CB amounts@113/145/usePrev@177 (min 178) — all consistent; every `BytesLib` read bounds-checked (reverts OOB); min-length checked in every decoder; `address(0)` validated on every path.
- **interestRateMode:** `!= 2` rejected in all decoders **and** the `IPool` calls hardcode `VARIABLE_RATE_MODE` — no bypass.
- **Approval reset after `repay(max)`:** trailing `approve(pool, 0)` present — no infinite allowance persists.
- **Reentrancy / access control / arithmetic / tx.origin / delegatecall / floating pragma / `encodePacked` collision / returnbomb:** none applicable to these pure builders (pragma pinned `0.8.30`; `inspect` packs a single address).
- **Vendored `IPool`/`DataTypes`:** signatures + `ReserveDataLegacy` field order (aToken@8, variableDebt@10) match Aave V3 (validated against real Pools in fork tests).

## Recommendations (all optional / low priority)
1. Enforce a canonical-Pool **allowlist in off-chain intent construction** (leverages `inspect()`'s returned pool) — P3-2.
2. Optionally add a `getOutToken` identity guard for `usePrevHookAmount` to fail fast on mis-chains — P3-1.
3. Add the two NatSpec lines on `name()`/`description()` for V4 parity — P3-6.

## Security Knowledge Sources
- `vulnerabilities.md` sections referenced: 1, 2, 3, 4, 8, 9, 10, 13, 14, 15, 17, 18, 22, 29, 36, 46
- coding-rules.md validated (NatSpec, custom errors, pragma pinning, visibility, imports, `forge fmt`)
- Prior feature research: `research/evm-security.md` (attack surface A1–A10, invariants INV-1..6)
