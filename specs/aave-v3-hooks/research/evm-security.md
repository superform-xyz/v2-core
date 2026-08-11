# EVM / DeFi Security Research — Aave V3 Lending Hook Suite

**Scope:** Superform v2-core hooks that build `Execution[]` structs the user's ERC-7579 account
executes against the Aave V3 `Pool`: `supply` / `withdraw` / `borrow` / `repay` /
`repayWithATokens`, plus combined `SupplyAndBorrow` and `RepayAndWithdraw`. Pool address and
`interestRateMode` are passed in hook calldata. Hooks are **NONACCOUNTING** (no cost-basis ledger).

**Primary reference:** The path in the task brief
(`/Users/cosming/1.Coding/Superform/v2-core/guidelines/solidity/vulnerabilities.md`) does **not**
exist. The internal vulnerability DB was located at
`/Users/cosming/1.Coding/Superform/superform-specs/guidelines/solidity/vulnerabilities.md`
(5052 lines) and is used throughout; section numbers below refer to it.

**Codebase anchors used** (Aave V4 suite this work mirrors):
- `src/hooks/loan/aave-v4/BaseAaveV4LoanHook.sol` (decoding, offsets, `onBehalfOf == account` invariant)
- `src/hooks/loan/aave-v4/AaveV4SupplyHook.sol` (approve-0/approve-N/call/approve-0 pattern; pre/post balance-delta)
- `src/hooks/loan/aave-v4/AaveV4RepayHook.sol` (full-repay via `type(uint256).max`; documented P1-2/P1-3 limitations)

**Threat-model framing (important):** These hooks do not custody user funds and do not hold
privileged roles. They are pure builders: `_buildHookExecutions` returns calldata the *user's own
account* executes with `onBehalfOf = account`. So the classic Aave-fork criticals (oracle
manipulation → bad debt, first-depositor share inflation, liquidation manipulation — DB §18.4.1,
§22.1, §17.3) are **Aave-protocol** risks, not hook risks; the hook cannot introduce them. The
hook's real attack surface is: (a) calldata decoding / address validation, (b) token-transfer and
approval mechanics, (c) execution ordering and dangling state, (d) building routes that revert or
strand funds, and (e) building routes that silently leave the account in an unsafe (liquidatable)
position. This report is scoped accordingly.

---

## 1. RELEVANT VULNERABILITY PATTERNS (with DB refs)

### 1.1 Token behaviors on supply / repay
The account transfers underlying into Aave on `supply` and `repay` (Aave's aToken/pool pulls via
`transferFrom` after the account `approve`s). Weird-ERC20 behaviors matter because Superform markets
support arbitrary assets across many chains.

- **Missing-return tokens (USDT, BNB, OMG)** — DB §10.3, §26.4.1, §26.6. `USDT.approve`/`transfer`
  do not return a bool. Any hook execution that calls `IERC20.approve` / `IERC20.transfer` and lets
  the account's execution layer decode a bool return will revert on USDT. Aave's own aToken pull
  uses `safeTransferFrom` internally, but the **hook-built approval executions** are the risk: they
  must be encoded so a non-returning `approve` does not revert. This is the single highest-frequency
  correctness issue for this suite because USDT is a top-3 Aave reserve on nearly every target chain
  (Ethereum, Arbitrum, Polygon, Optimism).
- **Approval race / non-zero-to-non-zero approve** — DB §10.5, §26.5. USDT specifically reverts if
  you `approve` a non-zero allowance while a non-zero allowance already exists. The V4 suite already
  handles this with the **approve-0 → approve-N → call → approve-0** sequence
  (`AaveV4SupplyHook` executions[0,1,4]); V3 hooks must replicate it exactly.
- **Fee-on-transfer tokens** — DB §10.1, §46.1. If the underlying takes a transfer fee, the amount
  Aave receives is less than the `amount` argument. For `supply(asset, amount, ...)` Aave mints
  aTokens against what it *received*, not the requested `amount`. Two failure modes: (1) the
  approval/`amount` passed to Aave may exceed what actually lands, and (2) any hook-level
  balance-delta accounting that assumes `amount` was moved is wrong. Fee-on-transfer assets are rare
  as Aave reserves (Aave governance excludes them), but because the Pool is caller-supplied the hook
  cannot assume the asset is a listed reserve — see §2 attack surface. Mitigation is balance-delta
  measurement in `_preExecute`/`_postExecute`, which the V4 pattern already does.
- **Rebasing tokens (stETH, AMPL)** — DB §10.2, §46.2. Aave lists **wstETH** (non-rebasing), not
  stETH, precisely to avoid this. A hook that supplied a raw rebasing token would see balance drift
  between build and execute. Low likelihood given Aave's reserve list, but document that the hook's
  `amount`/balance-delta logic assumes non-rebasing underlying.
- **Tokens with >18 decimals / very small decimals** — DB §37.4 (decimal mismatch). Amount math in
  the hook is pass-through (no scaling), so this is mostly an Aave-internal concern, but
  `type(uint256).max` "max" semantics (below) interact with decimals — full-repay approval of `max`
  is decimals-agnostic and safe.
- **Pausable / blocklist tokens (USDC, USDT)** — DB §46.4. If the account address is blacklisted by
  USDC/USDT, every `supply`/`repay`/`withdraw` execution reverts. Not exploitable *by* the hook, but
  it means a built route can become permanently un-executable; there is no hook-side escape hatch
  (the account still holds its aTokens and can act directly). Document as a known external
  dependency, not a hook bug.
- **Multiple-entry-point tokens** — DB §46.3. Address-based validation of `asset`/`pool` can be
  fooled by proxy tokens with two entry points. Because the hook validates addresses but does not
  whitelist them (they are user-supplied), this is a user-trust concern, not a hook invariant break.

### 1.2 Approval hygiene / lingering allowances
- DB §10.5, §26.5, §47.4 (infinite-approval exploitation). The dangerous pattern is leaving a
  non-zero (or infinite) allowance from the account to the Pool after execution. The V4 suite fixes
  this ("P1-1: Reset approval after supply to prevent dangling allowance",
  `AaveV4SupplyHook` executions[4]; `AaveV4RepayHook` executions[3]). **V3 must reset to 0 after
  every supply/repay**, including the full-repay path that approves `type(uint256).max`. A lingering
  `max` allowance to a *user-supplied* Pool address is the worst case: if the caller passed a
  malicious contract as `pool`, an infinite allowance would let it drain that token from the account
  later. Trailing `approve(pool, 0)` closes this.

### 1.3 Reentrancy via aToken / execution ordering
- DB §1.1–1.5 (reentrancy), §1.4 (read-only reentrancy), §10.4 (ERC-777 callbacks), §18.4.2
  (Gnosis native-token callback → Agave Finance). The hooks themselves are `view`/`pure` builders
  and hold no funds, so classic reentrancy against the *hook* is not applicable. The relevant
  surfaces:
  - **Combined hooks** (`SupplyAndBorrow`, `RepayAndWithdraw`) emit a multi-step `Execution[]` run
    sequentially by the account. Ordering must be strictly correct — e.g. supply-then-borrow, and
    repay-then-withdraw — because withdrawing collateral *before* repaying debt can trip Aave's
    health-factor check and revert the whole batch, or (worse ordering in a leverage unwind) leave
    the account under-collateralised mid-batch. Aave reverts on unhealthy states, so this is a
    liveness/DoS risk, not a theft risk.
  - **aToken transfer callbacks:** Aave V3 aTokens do **not** implement ERC-777 receive hooks;
    `repayWithATokens` burns aTokens the account already holds (no external callback). So no
    reentrancy is introduced. The one chain-specific caveat is DB §18.4.2: native-token callback
    behavior on Gnosis — not a target chain here (Ethereum/Arbitrum/Base/Optimism/Polygon), so out
    of scope, but note it if Gnosis is added.
  - **Inter-hook transient storage:** `usePrevHookAmount` pulls `getOutAmount(account)` from the
    previous hook via transient storage (see `AaveV4SupplyHook._buildHookExecutions`). DB §23.7
    (transient storage misuse / EIP-1153). Ensure the V3 hooks read the amount at build time and do
    not leave transient state that a later hook in the same UserOp could misread.

### 1.4 Unchecked external-call returns
- DB §8.1 (SWC-104), §26.6 (silent transfer failure). The hook builds `Execution` calldata; the
  account's execution library is what actually performs the calls and bubbles reverts. Two things to
  verify: (1) the account executor reverts the batch on any sub-call failure (Superform's
  `SuperExecutor` does), so a failed `supply`/`repay` does not silently continue; and (2) return
  values that carry meaning — `withdraw` returns the actual amount withdrawn, `repay` and
  `repayWithATokens` return the actual amount repaid — are consumed correctly if any downstream hook
  or the pre/post accounting depends on them. The safest design (matching V4) is to derive
  downstream amounts from **account balance deltas** measured in `_preExecute`/`_postExecute`, not
  from the Pool's return value, so a token that under-delivers cannot desync the route.

---

## 2. AAVE-V3-SPECIFIC RISKS

Aave V3 `Pool` signatures (asset-keyed, per interview notes):
```
supply(asset, amount, onBehalfOf, referralCode)
withdraw(asset, amount, to) returns (uint256)                       // amount == max → withdraw full aToken balance
borrow(asset, amount, interestRateMode, referralCode, onBehalfOf)
repay(asset, amount, interestRateMode, onBehalfOf) returns (uint256) // amount == max → repay full debt of that mode
repayWithATokens(asset, amount, interestRateMode) returns (uint256)  // burns caller's aTokens; onBehalfOf implicit = msg.sender
setUserUseReserveAsCollateral(asset, useAsCollateral)
```

### 2.1 interestRateMode misuse — stable rate removed in V3.1
**Highest V3-specific correctness risk.** Aave V3.1 (deployed everywhere live) **removed stable-rate
borrowing**. `interestRateMode`:
- `1` = STABLE → **reverts** on all current markets (Aave errors around stable-borrow being
  disabled). Passing mode 1 in `borrow` / `repay` / `repayWithATokens` bricks the route.
- `2` = VARIABLE → the only valid value in practice.
The interview decision makes the rate mode a **configurable byte in hook data** for
forward/backward compatibility. Defensive stance: either (a) validate the byte ∈ {2} (reject 1 and
anything else with a custom error) for the MVP, or (b) if genuinely leaving it selectable, document
loudly that mode 1 will revert on every current market and add a test asserting the revert. Do
**not** silently default an out-of-range byte to 0 — mode 0 (`NONE`) is invalid for borrow and will
also revert. Cross-reference DB §14.3 (missing input validation) and §25.5 (zero-value
initialization: a zero byte is not a safe "default", it is an invalid mode).

### 2.2 Isolation mode & siloed borrowing → reverts / stuck routes
Aave V3 isolation mode: an asset listed as an **isolated collateral** allows the user to borrow only
**isolation-mode-permitted stablecoins**, up to a **debt ceiling**, and *only while it is the sole
collateral*. Siloed borrowing: some reserves can only be borrowed alone (no other borrows
simultaneously). Consequences for `SupplyAndBorrow` and `Borrow`:
- Supplying an isolated asset then trying to `borrow` a non-permitted asset → **revert**
  (`ASSET_NOT_BORROWABLE_IN_ISOLATION` / debt-ceiling exceeded).
- Borrowing a siloed asset while already holding other debt, or borrowing a second asset while
  holding a siloed debt → **revert**.
- These are Aave-enforced (safe — no bad debt), but they make the built route un-executable. The
  hook has no view into the account's existing positions at build time, so it cannot pre-validate.
  **Mitigation is documentation + tests**, not code: fork-test an isolation-mode market
  (e.g. a market listing an isolated asset) and assert the expected revert so integrators know.
DB refs: §17 (DeFi-specific), Appendix G.2 lending patterns.

### 2.3 Full-repay dust / interest accrual between build and execute
- `repay(asset, type(uint256).max, mode, account)` repays the **entire** current debt of that rate
  mode and refunds nothing (Aave pulls only what is owed). This is the correct "full repay" idiom
  and is decimals/interest-safe — mirrors `AaveV4RepayHook`'s `type(uint256).max` path.
- **The trap is the approval, not the repay.** For full repay the account must have approved
  *enough* underlying to cover principal + interest accrued up to the execution block. Interest
  accrues every block, so an approval sized to a stale debt snapshot can under-approve and revert.
  The V4 suite solves this by approving `type(uint256).max` for the full-repay branch
  (`AaveV4RepayHook` executions[1]) — do the same for V3, then reset to 0 (executions[3]).
- **Dust after partial repay:** a `repay(amount)` sized off a stale snapshot leaves a few wei of
  debt (interest since snapshot). If a downstream hook assumes debt is fully cleared (e.g. a
  `RepayAndWithdraw` that then tries to withdraw *all* collateral), the residual debt can keep the
  position from being fully unwound or trip the health-factor check. For true "close the position"
  UX, prefer the `type(uint256).max` full-repay branch, not a computed amount. Documented in V4 as
  **P1-3** (interest accrues between build and execute).

### 2.4 withdraw(max) / repay(max) semantics
- `withdraw(asset, type(uint256).max, to)` withdraws the account's **entire aToken balance** of that
  reserve and returns the actual amount. Good for "exit fully". But if the reserve is being used as
  collateral against an outstanding borrow, Aave reverts on health-factor violation
  (`HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD`) — a max-withdraw of collateral while debt is
  open is a revert, not a silent unsafe state. Correct sequencing in `RepayAndWithdraw` (repay
  first) avoids this.
- Because `withdraw`/`repay` **return the actual amount**, any `usePrevHookAmount` chaining that
  feeds the *next* hook must use the real delta (balance-based), not the requested `max` sentinel —
  otherwise a downstream hook receives `type(uint256).max` as an "amount" and mis-encodes. Mirror
  V4's balance-delta `_postExecute`.

### 2.5 Supplying a non-collateral asset, then borrowing (health factor)
V3 **auto-enables** a freshly supplied asset as collateral *only if* the reserve's LTV > 0 and the
user has not disabled it. Assets with **LTV = 0** (listed as borrowable-but-not-collateral, e.g.
some stablecoins in certain markets) are supplied **without** becoming collateral. A `SupplyAndBorrow`
that supplies an LTV-0 asset and expects to borrow against it → **revert** (collateral 0, health
factor undefined/insufficient). The interview decision is to **rely on Aave auto-enable** and not
ship a collateral-toggle hook for MVP — acceptable, but the LTV-0 edge must be tested and documented,
because the failure is a silent-looking revert to the user.

### 2.6 Leaving a position liquidatable
The hooks build user-signed intents; there is no oracle logic in-hook (per interview). A `Borrow` or
`SupplyAndBorrow` route can leave the account at a low health factor, and a later price move makes it
liquidatable — user risk, not a hook bug, but it must be documented (interview "Security Focus"
already flags this). DB §17.3 (liquidation manipulation) and §18.4.1 (bad debt) are **Aave**
concerns; the hook neither prevents nor enables them. The one hook-controllable factor: do not build
routes that *withdraw collateral* or *borrow more* without the user's explicit amounts — never
inject `max` on the borrow leg.

### 2.7 Frozen / paused reserves and supply/borrow caps
Aave reserves have `frozen`, `paused`, `supplyCap`, `borrowCap` flags:
- **Paused reserve** → all actions revert (`RESERVE_PAUSED`).
- **Frozen reserve** → `supply`/`borrow` revert, but `repay`/`withdraw`/`liquidation` still allowed
  (`RESERVE_FROZEN`). So a `SupplyAndBorrow` on a frozen reserve reverts, while `RepayAndWithdraw`
  still works — asymmetry worth a test.
- **supplyCap exceeded** → `supply` reverts (`SUPPLY_CAP_EXCEEDED`); **borrowCap exceeded** →
  `borrow` reverts (`BORROW_CAP_EXCEEDED`).
All are Aave-enforced reverts (safe), but they turn built routes into un-executable ones. Same
mitigation posture: cannot pre-check at build time (no account/reserve state), so document + test the
revert paths. DB Appendix G.2 ("Yield Collection Lockup — Paused states blocking withdrawals").

---

## 3. ATTACK SURFACE MAP (these hooks specifically)

| # | Surface | What flows through it | Risk if wrong | Primary control | DB ref |
|---|---------|-----------------------|---------------|-----------------|--------|
| A1 | **Calldata decoding** (offsets for asset/pool/amount/rateMode/usePrevHookAmount) | User/bundler-supplied `bytes` | Mis-decoded address or amount → wrong target/amount; OOB read | `data.length` min-length guard (`INVALID_DATA_LENGTH`), fixed offsets, `BytesLib` bounds | §14.3, §23.6 |
| A2 | **`pool` address (from calldata)** | Arbitrary contract address | Malicious "pool" receives `approve` and a call from the account | Non-zero check; trailing `approve(pool,0)`; document that pool is user-trusted; consider optional allowlist | §8.2, §10.6, §3.955 (unvalidated calldata / LiFi pattern) |
| A3 | **`asset` address (from calldata)** | Arbitrary token | approve/transfer to attacker token; weird-ERC20 revert | Non-zero check; SafeERC20-style encoding; balance-delta verify | §10.1/§10.3, §46.x |
| A4 | **`interestRateMode` byte** | 0/1/2/other | mode 1 (stable, removed) or invalid → revert / bricked route | Validate ∈ {2} for MVP or reject non-{2}; explicit revert test | §14.3, §25.5 |
| A5 | **Approval sequence** | approve-0 / approve-N / approve-0 (or max for full repay) | Dangling/infinite allowance to user-supplied pool → later drain | Reset-to-0 after every supply/repay incl. max path | §10.5, §26.5, §47.4 |
| A6 | **Execution ordering in combined hooks** | supply→borrow, repay→withdraw | Wrong order → health-factor revert or unsafe mid-batch state | Hard-code correct order; fork tests | §14.4 (state machine), §7.4 (unexpected revert DoS) |
| A7 | **`usePrevHookAmount` / transient storage** | prev hook `getOutAmount` | Wrong/stale amount; `max` sentinel leaking into next hook | Balance-delta pre/post; never forward `max` as a real amount | §23.7, §25.5 |
| A8 | **`onBehalfOf` / recipient** | Should always be `account` | If ever settable → borrow/withdraw on behalf of / to attacker | Hard-code `account` (invariant from `BaseAaveV4LoanHook` L17) | §2.1 (access), §25.4 |
| A9 | **Full-repay approval staleness** | interest since build | Under-approval → revert (liveness) | `type(uint256).max` approve for full-repay branch | §17.5, V4 P1-3 |
| A10 | **Front-run full repay** | third party repays 1 wei on behalf of borrower | victim `repay(max)` still succeeds in V3 (max repays remaining) — low impact vs V4 note | documented; private mempool optional | V4 P1-2, §6.1 |

**Not in surface (protocol-owned, cannot be introduced by the hook):** oracle/price manipulation →
bad debt (§18.4.1), first-depositor/share inflation (§22.1, §37.1), interest-rate-model manipulation
(§17.5), liquidation MEV (§17.3). Note these in the spec as *out of hook scope* so reviewers do not
mis-file them as hook bugs.

---

## 4. RECOMMENDED DEFENSIVE PATTERNS

Mirror the V4 suite; the following are the concrete, load-bearing patterns.

1. **Approve-0 → approve-N → call → approve-0 (USDT-safe, no dangling allowance).**
   Every supply/repay must bracket the Pool interaction with a leading `approve(pool, 0)` and a
   trailing `approve(pool, 0)`, exactly as `AaveV4SupplyHook` executions[0,1,4] and
   `AaveV4RepayHook` executions[0,1/2,3]. This simultaneously defeats the USDT non-zero-approve
   revert (DB §10.5/§26.5) and eliminates lingering allowance to a user-supplied pool (DB §47.4).
   The full-repay branch approves `type(uint256).max` between the two zeros.

2. **SafeERC20 / non-returning-token-safe encoding.** The `approve` executions the hook builds must
   not assume a bool return (USDT). Encode so the account executor tolerates empty return data
   (Aave's own pulls already use SafeERC20 internally). DB §8.1, §26.4.1.

3. **Balance-delta verification in `_preExecute`/`_postExecute`.** Record the relevant token balance
   before, and set `outAmount = balanceBefore - balanceAfter` (supply/repay) or
   `balanceAfter - balanceBefore` (withdraw/borrow), as `AaveV4SupplyHook`/`AaveV4RepayHook` do. This
   makes fee-on-transfer and under-delivery safe and gives downstream hooks a *real* amount rather
   than the requested `amount`/`max` sentinel. DB §10.1, §46.1.

4. **Validate `pool` and `asset` non-zero (and each other-distinct where meaningful).** Reuse the
   `ADDRESS_NOT_VALID()` guard from `BaseAaveV4LoanHook._decode*`. Add a minimum-`data.length` check
   per hook (`INVALID_DATA_LENGTH()`) before any offset read to prevent OOB decode. DB §10.6, §14.3.

5. **`onBehalfOf` and `to` hard-coded to `account`.** Never decode a recipient from calldata. Keep
   the `BaseAaveV4LoanHook` invariant ("onBehalfOf is always hardcoded to `account` — never
   arbitrary", L17). This closes A8 entirely. `repayWithATokens` has no `onBehalfOf` param (implicit
   `msg.sender = account`), which is inherently correct.

6. **Max-amount handling.** Use `type(uint256).max` deliberately and only where semantically safe:
   - `repay` / `repayWithATokens`: `max` = repay full debt — safe, interest-proof. Pair with `max`
     approval (repay) reset to 0 after.
   - `withdraw`: `max` = withdraw full aToken balance — safe.
   - **`borrow` / `supply`: never `max`.** A `max` borrow is nonsensical/dangerous; a `max` supply is
     not a Pool feature. Reject or require an explicit amount.
   - Never forward a `max` sentinel to a downstream hook via `usePrevHookAmount` — forward the
     measured balance delta instead. DB §25.5.

7. **Revert-on-zero amount.** Keep `if (amount == 0) revert AMOUNT_NOT_VALID();` on every
   non-full-repay/non-max path (as in `AaveV4SupplyHook` L66, `AaveV4RepayHook` L91). A zero-amount
   supply/borrow is a wasted, potentially reverting call. DB §14.3.

8. **Validate `interestRateMode`.** Reject mode ≠ 2 (or ≠ {2} allowed set) with a custom error for
   MVP; if kept selectable, add an explicit revert-expecting test for mode 1. DB §14.3, §25.5.

9. **Correct combined-hook ordering, encoded not inferred.** `SupplyAndBorrow` = [approve0, approveN,
   supply, approve0, borrow]; `RepayAndWithdraw` = [approve0, approve(N|max), repay, approve0,
   withdraw]. Repay strictly before withdraw; supply strictly before borrow. DB §14.4.

10. **Keep hooks `view`/`pure` builders with no fund custody** (they already are). This structurally
    removes reentrancy against the hook (DB §1.x) and keeps the trust boundary at the account +
    Aave, not the hook.

---

## 5. EXPLOIT PRECEDENTS (lending-protocol integrations)

- **Aave V2 price-manipulation bad debt (~$1.6M), Polter Finance, RoeFinance** — DB §18.4.1. Flash-loan
  oracle attacks creating uncollateralized positions. *Relevance:* protocol-level; the hook cannot
  cause it. Listed so reviewers scope it out. Reinforces "never inject amounts / never disable the
  user's collateral toggle without intent."
- **Agave Finance (Aave fork on Gnosis)** — DB §18.4.2. Gnosis native-token callback reentrancy on
  an Aave fork. *Relevance:* only if Gnosis is ever a target chain (it is not in the MVP set). If
  added, native-token flows need reentrancy care.
- **Sonne Finance donation / empty-market exploit** — DB §18.1.2, §28, §M.4. Compound-fork
  first-depositor / donation attack on an empty market. *Relevance:* first-depositor & donation
  (DB §22.1, §37.1, §37.3) are **empty-market / share-accounting** attacks against the lending
  protocol's own aToken/cToken minting. Aave V3 mitigates via its own virtual-accounting; the
  Superform hook, supplying into a live production market it does not deploy, cannot trigger or be
  hurt by this. Document as out-of-scope but keep the mental model: *the hook must never be the first
  actor bootstrapping a market it controls.*
- **LiFi / Dough Finance — unvalidated calldata** — DB §3.955 (§M.5), §8.2. Integrators that passed
  attacker-controlled calldata/target into an external call lost funds. *Relevance: directly
  applicable.* The `pool` address flows from calldata into an `approve` + call by the account. The
  trailing `approve(pool,0)` and non-zero validation are the mitigations; if a stronger guarantee is
  wanted, an optional on-chain allowlist of known Aave V3 Pool addresses per chain would convert A2
  from "user-trusted" to "protocol-verified."
- **Compound double-entry-point token issue** — DB §18.1.3, §46.3. Tokens with two entry points
  (old SNX/TUSD) defeat address-based checks. *Relevance:* the hook does not whitelist tokens, so it
  inherits Aave's reserve trust; note it.
- **Infinite-approval drain via integrator vulnerability** — DB §47.4. The canonical reason to reset
  approvals to 0. Directly motivates pattern §4.1 for the `type(uint256).max` full-repay branch.

---

## 6. TESTING RECOMMENDATIONS

### 6.1 Fork tests (real Pool, no mocks) — per chain × market
Mirror `AaveV4HooksIntegrationTest`. Pin fork blocks (interview note: avoid latest-fork CI flakiness).
Run the matrix on **Ethereum (Core + Prime + EtherFi where applicable), Arbitrum, Base, Optimism,
Polygon**, each with its real V3.1 Pool address supplied via hook data.

Core scenarios per hook:
- Supply → assert aToken balance delta == received (balance-delta, not requested amount).
- Supply then Borrow (variable mode 2) → assert debt token minted, health factor > 1.
- Partial repay → assert debt decreases; residual dust tolerated.
- **Full repay via `type(uint256).max`** → assert debt == 0, allowance reset to 0, no leftover
  `max` approval.
- Withdraw partial and **withdraw(max)** → assert full aToken balance exits; assert revert when
  withdrawing collateral with open debt (health-factor revert).
- `RepayAndWithdraw` full lifecycle → repay-then-withdraw ordering; assert position fully closed.
- `SupplyAndBorrow` full lifecycle → supply-then-borrow ordering.
- **`repayWithATokens`** → repay using held aTokens, no underlying transfer, assert aToken burn and
  debt reduction (leverage-unwind route).
- Multi-asset market: supply asset X as collateral, borrow asset Y.

### 6.2 Aave-state edge scenarios (assert expected reverts)
- **interestRateMode = 1 (stable)** → assert borrow/repay revert (stable removed in V3.1).
- **interestRateMode = 0 or >2** → assert revert (or hook-level rejection).
- **Isolation-mode collateral** → supply isolated asset, borrow non-permitted asset → assert revert;
  borrow permitted stablecoin within debt ceiling → assert success; exceed debt ceiling → revert.
- **Siloed reserve** → borrow siloed asset while holding other debt → assert revert.
- **LTV-0 asset** → supply, then `SupplyAndBorrow` expecting collateral → assert revert (no
  collateral enabled).
- **Frozen reserve** → supply/borrow revert; repay/withdraw still succeed (asymmetry test).
- **Paused reserve** → all actions revert.
- **supplyCap / borrowCap exceeded** → assert respective reverts.

### 6.3 Fuzz tests
- Fuzz `amount` across [1, reserve liquidity] for supply/withdraw/borrow/repay; assert no overflow,
  correct balance deltas, revert-on-zero.
- Fuzz `interestRateMode` over full `uint8`/`uint256` domain; assert only 2 succeeds.
- Fuzz `usePrevHookAmount` chaining: previous-hook amount = 0, = max, = normal; assert 0 reverts,
  max is not forwarded as a literal borrow/supply amount.
- Fuzz `data.length` below each hook's minimum → assert `INVALID_DATA_LENGTH()`.
- Fuzz `pool`/`asset` = address(0) → assert `ADDRESS_NOT_VALID()`.

### 6.4 Weird-ERC20 cases (unit, with mock/adversarial tokens)
Use a weird-ERC20 harness (missing-return, fee-on-transfer, reverting-approve-on-nonzero,
pausable/blocklist, returns-false):
- **USDT-style missing-return** approve/transfer → supply and repay must succeed (SafeERC20 encoding).
- **Reverts-on-nonzero-approve (USDT)** → assert the approve-0-first sequence prevents revert.
- **Fee-on-transfer** underlying → assert balance-delta accounting records *received*, not
  requested; downstream `usePrevHookAmount` gets the real delta.
- **Returns-false-on-approve** → assert revert (do not silently proceed).
- **Blocklist token, account blacklisted** → assert clean revert (no partial state).
- **>18-decimal token** → assert `max` full-repay path is decimals-agnostic.

### 6.5 Invariants (property tests)
- **INV-1 No dangling allowance:** after any hook executes, `allowance(account, pool) == 0` for the
  touched asset (including the full-repay `max` branch).
- **INV-2 onBehalfOf integrity:** every built `supply/borrow/repay` has `onBehalfOf == account`;
  every `withdraw` has `to == account`. (Static/structural check on built `Execution[]`.)
- **INV-3 Ordering:** in combined hooks, the supply/repay execution index precedes the
  borrow/withdraw index.
- **INV-4 No `max` on borrow/supply:** the borrow and supply legs never encode `type(uint256).max`.
- **INV-5 Amount consistency:** `outAmount` set by `_postExecute` equals the measured token balance
  delta, never the raw calldata `amount` when `max` sentinel was used.
- **INV-6 Rate mode:** every borrow/repay/repayWithATokens leg encodes an accepted mode (2).

---

## Summary of the highest-signal items
1. **interestRateMode = 1 reverts everywhere (stable removed in V3.1)** — validate it (§2.1, §4.8).
2. **USDT-safe approvals: approve-0 → N → 0, and reset the `max` full-repay allowance to 0** — the
   dangling-allowance-to-user-supplied-pool case is the only theft-adjacent hook risk (§1.2, §3-A2/A5, §4.1).
3. **Balance-delta accounting, not requested amount** — makes fee-on-transfer / under-delivery /
   `max` sentinels safe and feeds correct amounts downstream (§4.3, INV-5).
4. **`onBehalfOf`/`to` hard-coded to `account`** — preserve the V4 invariant (§4.5, INV-2).
5. **Isolation/siloed/frozen/paused/cap reverts are Aave-enforced (safe) but strand routes** — cover
   with fork tests and documentation, not code (§2.2, §2.7, §6.2).
6. **Oracle/bad-debt/first-depositor/liquidation criticals are protocol-owned and out of hook
   scope** — state this explicitly so reviewers don't mis-scope (§3, §5).
