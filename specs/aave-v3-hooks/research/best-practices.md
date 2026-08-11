# Aave V3 Integration — Best Practices for Call-Forwarding Hooks

Context: Superform "hooks" build `Execution` structs (target, value, calldata) that the
user's ERC-7579 smart account executes. The account itself is the caller/holder, so
`msg.sender` at the Aave `Pool` is the **smart account**, and all balances/positions are
held by the smart account. Hooks do not custody funds or compute health factors; they only
assemble calldata. This document captures the semantics, gotchas, and defensive patterns a
hook builder must respect.

Authority legend: **[OFFICIAL]** = Aave docs / source; **[COMMUNITY]** = widely-adopted
convention or third-party analysis.

---

## 0. TL;DR checklist for hook authors

- **[OFFICIAL]** Always pass `interestRateMode = 2` (variable). Stable rate (`1`) is
  deprecated in V3.1 and fully removed in V3.2 — passing `1` reverts. Do **not** expose a
  free-form mode byte to callers; hardcode `2` (see §2).
- **[OFFICIAL]** `withdraw` with `amount = type(uint256).max` means "withdraw entire aToken
  balance". `repay` with `type(uint256).max` means "repay whole debt" — but **only** when
  `onBehalfOf == msg.sender` (the smart account itself). See §1.
- **[OFFICIAL]** `repayWithATokens(asset, type(uint256).max, 2)` cleans up residual aToken
  dust — the preferred way to fully close a debt using held collateral.
- **[COMMUNITY]** For full repay from underlying, interest accrues between quote and
  execution. Approve/hold slightly more than the quoted debt, or prefer the `max` sentinel,
  to avoid a leftover-dust position. See §4.
- **[OFFICIAL/COMMUNITY]** Use `SafeERC20.forceApprove` (approve-0-then-amount) before
  `supply`/`repay`; never assume `approve` returns a bool (USDT). See §5.
- **[OFFICIAL]** First `supply` of a fresh reserve auto-enables it as collateral **only if**
  it doesn't break isolation rules; otherwise call `setUserUseReserveAsCollateral`. Isolation
  mode, siloed borrowing, 0%-LTV assets, and e-mode can each make a `supply`/`borrow`/
  `withdraw` revert. See §3.
- **[OFFICIAL]** Resolve the `Pool` per market; there are multiple markets per chain
  (Core / Prime / EtherFi on Ethereum). Prefer resolving via `PoolAddressesProvider.getPool()`
  or validating an explicitly-passed pool against a registry. See §6.

---

## 1. `IPool` function semantics and gotchas

Source: Aave V3 Pool reference. [OFFICIAL]
- https://aave.com/docs/developers/smart-contracts/pool
- Interface: `@aave/core-v3/contracts/interfaces/IPool.sol`

### `supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)`
- Transfers `amount` of `asset` from `msg.sender` into the pool and mints aTokens to
  `onBehalfOf`. Requires the pool to hold ERC20 allowance from `msg.sender`.
- `referralCode` — referral program is inactive; pass `0`. [OFFICIAL]
- For a call-forwarding hook, `msg.sender` and `onBehalfOf` are both the smart account.
  Setting `onBehalfOf` to a different address supplies collateral **to that other address's
  position** — almost never what a hook wants; default to the account itself.
- Reverts if the reserve is frozen/inactive, if supply cap is exceeded, or if `amount == 0`.
  [OFFICIAL]
- `type(uint256).max` is **not** special for `supply` — it will try to pull `uint256.max`
  and revert on transfer. Only `withdraw`/`repay`/`repayWithATokens` treat max as a sentinel.

### `withdraw(address asset, uint256 amount, address to) returns (uint256)`
- Burns aTokens from `msg.sender`, sends underlying to `to`. Returns the actual amount
  withdrawn.
- **`amount = type(uint256).max` ⇒ withdraw the entire aToken balance.** [OFFICIAL] The
  return value is the concrete amount; a hook that chains the output to a later step must
  read the return value, not assume `uint256.max`.
- Reverts if it would drop health factor below 1 (when the account has debt), or if the
  asset is being used as collateral with 0% LTV and other collateral depends on it. [OFFICIAL]
- Withdrawing collateral can move a leveraged position toward liquidation — the hook cannot
  see this; document it (see §7).

### `borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)`
- Mints variableDebtTokens to `onBehalfOf` and sends `asset` to `msg.sender`.
- `interestRateMode` must be `2`. See §2. [OFFICIAL]
- If `onBehalfOf != msg.sender`, `onBehalfOf` must have **delegated credit** to `msg.sender`
  via `approveDelegation` on the variableDebtToken; otherwise it reverts. For a hook,
  `onBehalfOf` should be the smart account itself. [OFFICIAL]
- Reverts on: insufficient collateral / health factor < 1 after borrow, borrow cap exceeded,
  reserve borrowing disabled/frozen, isolation-mode debt ceiling exceeded, siloed-borrowing
  violation, borrowed asset not permitted for the collateral's isolation/e-mode config. See §3.

### `repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) returns (uint256)`
- Pulls `asset` from `msg.sender`, burns debt tokens of `onBehalfOf`. Returns amount repaid.
- **`amount = type(uint256).max` ⇒ repay the whole debt — ONLY when the repayment is not on
  behalf of a 3rd party** (i.e. `onBehalfOf == msg.sender`). [OFFICIAL] For third-party
  repay, the pool cannot pre-know the debt precisely; send slightly more than the current
  debt and the surplus is not pulled. In hooks, `onBehalfOf` = smart account, so `max` is
  safe and preferred for full close-out.
- `interestRateMode` must be `2`. [OFFICIAL]

### `repayWithATokens(address asset, uint256 amount, uint256 interestRateMode) returns (uint256)`
- Repays variable debt of `msg.sender` using that user's **own aTokens** of the same asset
  (no underlying transfer, no allowance needed). Useful to deleverage without external funds.
- **`amount = type(uint256).max` cleans up residual aToken dust** while repaying, avoiding
  leftover 1-wei debt/collateral positions. [OFFICIAL]
- `interestRateMode` must be `2`. [OFFICIAL] Always repays `msg.sender`'s own position — no
  `onBehalfOf` parameter.

### `setUserUseReserveAsCollateral(address asset, bool useAsCollateral)`
- Toggles whether an already-supplied reserve counts as collateral for `msg.sender`.
- Reverts if: enabling would violate isolation mode (you already hold an isolated collateral,
  or the asset is isolated and you hold other collateral); the asset has 0% LTV (cannot be
  enabled); or disabling would drop health factor below the liquidation threshold. [OFFICIAL]

---

## 2. `interestRateMode`: variable = 2, stable = 1 (DEPRECATED/REMOVED)

Sources: [OFFICIAL]
- Aave V3.2 feature notes (stable-rate removal):
  https://github.com/aave-dao/aave-v3-origin/blob/v3.2.0/docs/3.2/Aave-3.2-features.md
- Pool reference (only variable rate available):
  https://aave.com/docs/developers/smart-contracts/pool

Facts:
- `DataTypes.InterestRateMode { NONE = 0, STABLE = 1, VARIABLE = 2 }`.
- **Aave V3.1**: stable-rate borrowing was disabled by governance across Ethereum mainnet and
  the L2 markets — a `borrow(..., 1, ...)` reverts on those markets. [OFFICIAL/COMMUNITY]
- **Aave V3.2**: all stable-rate logic was **removed** from the protocol. New reserves no
  longer instantiate a stable debt token, and `ValidationLogic` enforces `mode == VARIABLE`
  on borrow/repay/flashloan-with-debt. Passing `1` reverts. [OFFICIAL]

Implications for hooks that expose a configurable mode byte:
- **Do not expose a free-form mode byte to the caller.** Hardcode `interestRateMode = 2` in
  the borrow/repay hooks. This removes an entire class of "user passed 1 → revert" support
  tickets and future-proofs against markets that never had stable rate.
- If backward-compat with an existing calldata layout forces a mode field, **validate it ==
  2 and revert with a custom error** (e.g. `UnsupportedInterestRateMode`) rather than
  forwarding it and letting Aave revert opaquely.
- `repayWithATokens` already takes only a mode param that must be `2`.

---

## 3. Collateral enablement, isolation, siloed borrowing, e-mode — unexpected reverts

Sources: [OFFICIAL]
- Isolation Mode: https://aave.com/help/supplying/isolation-mode
- V3 overview (isolation / siloed / e-mode): https://aave.com/docs/aave-v3/overview
- Pool reference (collateral rules): https://aave.com/docs/developers/smart-contracts/pool

### Collateral auto-enable on first supply
- The **first** `supply` of a reserve for a user auto-enables it as collateral **iff** doing
  so does not violate isolation rules (see below) and the asset's LTV > 0. On subsequent
  supplies the collateral flag is not changed. If auto-enable didn't happen (isolation /
  0%-LTV), an explicit `setUserUseReserveAsCollateral(asset, true)` is required before it
  backs a borrow — and that call itself may revert. [OFFICIAL]

### Isolation mode
- An **isolated collateral asset** can only be used to borrow specific governance-approved
  stablecoins, subject to a global **debt ceiling**. While a user holds an isolated asset as
  collateral, they **cannot enable any other asset as collateral**. [OFFICIAL]
- Reverts a hook can hit: `borrow` of a non-permitted asset while in isolation; `borrow`
  exceeding the isolation debt ceiling; `setUserUseReserveAsCollateral(true)` / auto-enable
  on a second asset while an isolated asset is already collateral; supplying an isolated
  asset does not auto-enable it as collateral if the user already has other collateral.

### Siloed borrowing
- A reserve flagged **siloed** restricts a user who borrows it to borrowing **only that
  asset** — they cannot have any other open borrow simultaneously. [OFFICIAL] A borrow hook
  can revert if the account already has debt in another asset and tries to borrow a siloed
  one, or vice-versa.

### E-mode (efficiency mode)
- E-mode groups correlated assets (e.g. stablecoins, ETH-correlated) to allow higher LTV /
  lower liquidation thresholds, but restricts borrowing to assets in the same category.
  [OFFICIAL]
- A user with an **isolated asset as collateral cannot enter e-mode** until they disable/
  withdraw it. [OFFICIAL] Borrow of an out-of-category asset while in e-mode reverts.
- Hooks generally should **not** silently change e-mode; if an e-mode hook exists, it calls
  `setUserEMode(categoryId)` and can revert if the resulting position would be
  under-collateralized.

### Summary — which operations revert unexpectedly
| Operation | Revert triggers to document |
|---|---|
| `supply` | reserve frozen/inactive, supply cap exceeded, `amount == 0` |
| first-supply collateral auto-enable | silently skipped under isolation / 0% LTV (no revert, but borrow later fails) |
| `setUserUseReserveAsCollateral(true)` | isolation conflict, 0% LTV asset |
| `setUserUseReserveAsCollateral(false)` | health factor would fall below liquidation threshold |
| `borrow` | HF < 1, borrow cap, borrowing disabled/frozen, isolation debt ceiling, isolation asset-not-permitted, siloed-borrowing violation, e-mode category mismatch |
| `withdraw` | HF < 1, 0%-LTV collateral gating other assets |
| `repay`/`repayWithATokens` | mode != 2, no outstanding debt |

Recommendation: hooks cannot pre-validate all of these cheaply. Emit clear events with the
resolved `pool`, `asset`, and `amount`, and let Aave's own revert propagate; do not swallow
reverts. Where a hook can cheaply pre-check (e.g. mode == 2, amount != 0), do so with custom
errors for better UX.

---

## 4. aToken / variableDebtToken mechanics; full-repay dust

Sources: [OFFICIAL] Pool + tokenization docs; [COMMUNITY] integration write-ups.
- https://aave.com/docs/developers/smart-contracts/tokenization
- https://aave.com/docs/developers/smart-contracts/pool

- aTokens and variableDebtTokens are **rebasing/interest-bearing**: `balanceOf` grows every
  block via a liquidity/borrow index. A debt figure read off-chain (the "quote") is stale by
  the time the account executes; the real debt at execution time is strictly larger.
- **Full-repay dust problem**: if a hook computes `amount = quotedDebt` and repays exactly
  that, interest accrued between quote and execution leaves a tiny residual debt (dust). The
  position stays "open" with ~1 wei of debt, blocking clean collateral withdrawal and
  leaving the reserve flagged as borrowed.
- Mitigations (in preference order):
  1. **Use the max sentinel** for self-repay: `repay(asset, type(uint256).max, 2, account)`
     or `repayWithATokens(asset, type(uint256).max, 2)`. The pool computes the exact current
     debt and repays it fully, pulling only what's owed. [OFFICIAL]
  2. If a concrete amount is required (e.g. partial repay, or third-party repay where `max`
     is disallowed), **approve/hold a small buffer above the quote** (e.g. quote × 1.001 or
     quote + fixed epsilon). The surplus is not pulled on a `max` self-repay, but for a fixed
     amount it caps the repay, so buffer only matters for allowance/balance, not the repaid
     amount. [COMMUNITY]
- Same reasoning applies to `withdraw`: to fully exit collateral, use `type(uint256).max`
  so the pool burns the exact current aToken balance including accrued interest, rather than
  a stale figure that leaves dust aTokens behind. [OFFICIAL]

---

## 5. ERC20 approval hygiene for `supply` / `repay`

Sources: [COMMUNITY/OFFICIAL]
- OpenZeppelin SafeERC20: https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#SafeERC20
- weird-erc20 catalogue: https://github.com/d-xo/weird-erc20

- `supply` and `repay` (underlying) require the **pool** to hold allowance from the caller
  (the smart account). The hook must build an `approve` execution to the token, targeting the
  resolved pool address, **before** the supply/repay execution.
- **Approve-0-then-amount**: some tokens (USDT, KNC-style) revert on a non-zero→non-zero
  `approve`. Set allowance to `0` first, then to the desired amount — i.e. use
  `SafeERC20.forceApprove`. [OFFICIAL OZ / COMMUNITY]
- **Missing return value (USDT)**: `approve`/`transfer` on USDT return no bool. Always route
  through `SafeERC20` (`safeTransfer`, `forceApprove`) which tolerates missing/false returns;
  never rely on the raw `IERC20` bool. [COMMUNITY]
- **Fee-on-transfer / deflationary tokens**: the amount that lands in the pool can be less
  than `amount`, which can make `supply` behave unexpectedly or revert on internal
  accounting. Aave generally does not support fee-on-transfer reserves; a hook that supports
  arbitrary assets should either (a) restrict to known-good reserves, or (b) measure balance
  delta rather than trusting `amount`. [COMMUNITY]
- **Approval amount vs repay**: for a `repay` where you intend `max`, you still need a
  concrete allowance number (you cannot approve `uint256.max` of underlying you don't hold).
  Approve a slight buffer over the quoted debt so the pool can pull the exact current debt
  without an allowance shortfall. Consider resetting leftover allowance to `0` in a trailing
  execution to avoid dangling approvals. [COMMUNITY]
- Prefer **exact/scoped approvals** over infinite approvals to the pool where practical;
  infinite approval to a trusted-but-upgradeable pool is a standing risk surface.

---

## 6. Pool address discovery — one Pool per market, many markets per chain

Sources: [OFFICIAL]
- Address book / deployed contracts: https://aave.com/docs/resources/addresses
- PoolAddressesProvider: https://aave.com/docs/developers/smart-contracts/pool-addresses-provider

- Each Aave **market** has exactly one `Pool` proxy. A single chain can host **multiple
  markets**: on Ethereum mainnet there are **Core**, **Prime**, and **EtherFi** markets, each
  with its own `PoolAddressesProvider` and `Pool`. Reserve lists and risk params differ per
  market. Do not assume "the Aave pool on chain X". [OFFICIAL]
- `PoolAddressesProvider.getPool()` returns the current `Pool` proxy for that market. The
  provider is the source of truth and survives pool upgrades (the proxy address it returns
  can change). [OFFICIAL]

Trade-offs — passing pool per-call vs resolving via provider:

| Approach | Pros | Cons |
|---|---|---|
| **Pass `pool` in hook calldata** | Cheapest (no extra call); explicit; caller picks the exact market | Trusts caller-supplied address — a malicious/incorrect pool could route approvals+funds to an attacker. MUST validate against an allowlist/registry |
| **Resolve via `PoolAddressesProvider.getPool()`** | Always current after upgrades; harder to spoof if the provider address is itself trusted/allowlisted | Still need to pick the right provider (which market); one extra external call; provider address must be trusted |

Recommendation: accept a **market/provider identifier or pool address that the hook
validates against a trusted registry** (Superform's `SuperRegistry` or a hook-local
allowlist), rather than blindly forwarding an arbitrary `pool` from calldata. If passing the
pool directly, at minimum verify it is a known Aave pool before issuing token approvals to
it — an unchecked pool address is a fund-drain vector because the hook approves tokens to it.

---

## 7. Health factor / liquidation exposure to document

Sources: [OFFICIAL]
- Liquidations: https://aave.com/docs/developers/smart-contracts/liquidations
- Pool `getUserAccountData`: https://aave.com/docs/developers/smart-contracts/pool

- Health Factor = (Σ collateral × liquidation threshold) / total borrows. HF < 1 makes the
  position liquidatable. `borrow` and `withdraw` both **lower** HF; `borrow`/`withdraw` that
  would push HF below 1 revert, but a call can legitimately leave HF **just above 1**,
  i.e. one price tick from liquidation. [OFFICIAL]
- Hooks do not compute HF and should not pretend to. What to document and, where cheap, to
  surface:
  - A borrow/withdraw hook can leave the account near liquidation; this is the user's
    (or the intent-signer's) responsibility. State this explicitly in hook NatSpec.
  - Optionally, a hook or the surrounding executor MAY read
    `Pool.getUserAccountData(account)` after the operation and revert if `healthFactor` is
    below a caller-supplied `minHealthFactor` bound — a cheap, opt-in safety rail that turns
    "silently near-liquidation" into an explicit failure. [COMMUNITY pattern]
  - Cross-chain / delayed execution amplifies this: an intent signed when HF was safe may
    execute later at a worse price. The static-system assumption in Superform's SECURITY.md
    applies directly here.
- e-mode raises LTV and thus lets HF sit "healthy" at much higher leverage; a borrow hook
  operating under e-mode is closer to liquidation for the same nominal HF than one outside
  e-mode. Note this in risk docs.

---

## Primary sources
- Aave V3 Pool contract reference — https://aave.com/docs/developers/smart-contracts/pool [OFFICIAL]
- Aave V3.2 feature notes (stable-rate removal) — https://github.com/aave-dao/aave-v3-origin/blob/v3.2.0/docs/3.2/Aave-3.2-features.md [OFFICIAL]
- Isolation Mode — https://aave.com/help/supplying/isolation-mode [OFFICIAL]
- Aave V3 overview (isolation / siloed / e-mode) — https://aave.com/docs/aave-v3/overview [OFFICIAL]
- PoolAddressesProvider — https://aave.com/docs/developers/smart-contracts/pool-addresses-provider [OFFICIAL]
- Deployed addresses (per-market pools) — https://aave.com/docs/resources/addresses [OFFICIAL]
- Tokenization (aToken / debt tokens) — https://aave.com/docs/developers/smart-contracts/tokenization [OFFICIAL]
- Liquidations — https://aave.com/docs/developers/smart-contracts/liquidations [OFFICIAL]
- OpenZeppelin SafeERC20 — https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#SafeERC20 [OFFICIAL]
- weird-erc20 (USDT, fee-on-transfer, etc.) — https://github.com/d-xo/weird-erc20 [COMMUNITY]
