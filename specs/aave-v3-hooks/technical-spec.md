# Aave V3 Hooks — Technical Specification

## Overview
Add a suite of Superform v2 hooks integrating **Aave V3** lending, mirroring the existing Aave V4 suite
(`src/hooks/loan/aave-v4/`) but targeting the Aave V3 `IPool` interface. Aave V3 is the dominant lending
deployment on nearly every chain (V4 is Ethereum-only), so this materially expands cross-chain lending
coverage for strategies.

The hooks are `NONACCOUNTING` `Execution[]` **builders**: they decode calldata and return the executions
the user's ERC-7579 smart account runs. They custody no funds and hold no privileged roles.

## Problem Statement / Motivation
Superform strategies can lend/borrow on Aave V4 (Ethereum only) and Morpho, but not on Aave V3 — the
largest, most widely-deployed money market. Without V3 hooks, cross-chain lending strategies on
Arbitrum, Base, Optimism, Polygon, etc. cannot route through Aave.

## Proposed Solution
Seven hooks + a shared base, mirroring the V4 suite's structure and conventions:

| Hook | Aave V3 Pool call | Approval? |
|------|-------------------|-----------|
| `AaveV3SupplyHook` | `supply(asset, amount, account, 0)` | yes (asset → pool) |
| `AaveV3WithdrawHook` | `withdraw(asset, amount, account)` (max = all) | no |
| `AaveV3BorrowHook` | `borrow(asset, amount, 2, 0, account)` | no |
| `AaveV3RepayHook` | `repay(asset, amount, 2, account)` (max = all) | yes (asset → pool) |
| `AaveV3SupplyAndBorrowHook` | supply then borrow | yes |
| `AaveV3RepayAndWithdrawHook` | repay then withdraw | yes |
| `AaveV3RepayWithATokensHook` | `repayWithATokens(asset, amount, 2)` (max = all) | **no** (burns aTokens) |
| `BaseAaveV3LoanHook` | shared decode / vars / pipe / accounting | — |

### Key structural difference from V4
Aave V3 keys every operation on the **asset token address**, not a `reserveId` + `spoke`. So the two
32-byte reserveId slots in the V4 layout disappear; the hook data carries asset addresses + a `pool`
address + an `interestRateMode` byte.

### Deployment model (resolves the per-market concern)
One Aave V3 `Pool` = one market and serves all its reserves; a chain can host multiple markets
(Ethereum: Core, Prime, EtherFi), each its own Pool. To avoid one deployment per (chain × market), the
**`pool` address is passed in hook data** — exactly as V4 passes the `spoke`. A single hook deployment
(one CREATE2 address) then works with every V3 market on every chain. `BaseAaveV4LoanHook` documents
this precise rationale; we replicate it.

## Technical Considerations

### Interface to vendor
Create `src/vendor/aave-v3/IPool.sol` — a minimal MIT-licensed subset from `aave-dao/aave-v3-origin`
(compiles under 0.8.30), containing only:
```solidity
function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
function withdraw(address asset, uint256 amount, address to) external returns (uint256);
function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);
function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode) external returns (uint256);
function getReserveData(address asset) external view returns (DataTypes.ReserveDataLegacy memory); // aToken @ index 8, variableDebtToken @ index 10
```
`getReserveData` returns `ReserveDataLegacy` (ABI-stable V3.0→V3.4). `stableDebtToken` (index 9) reads
`address(0)` on V3.2+ — never dereference it. Vendor a minimal `DataTypes` with `ReserveDataLegacy`.

### Interest rate mode
Stable rate (mode 1) was disabled in V3.1 and **removed in V3.2** — passing `1` reverts on every live
market; only variable (`2`) is valid. **Decision (revised from interview):** keep the `interestRateMode`
byte in hook data for layout/forward-compat, but **validate it equals `2`** and revert
`INVALID_RATE_MODE` otherwise (rather than blindly forwarding). This honors the "in-data" preference while
eliminating the guaranteed-revert / mode-0 footgun. *(Simpler alternative for pod review: drop the byte
and hardcode `2`.)*

### Data layout (per-hook; base mandates `loanToken@52`, `collateralToken@72`)
`BaseAaveV3LoanHook`/`BaseHook` hardcode getters and balance reads at `loanToken@52` and
`collateralToken@72` — these offsets **must** be preserved. Representative layouts (final offsets to be
confirmed in `/work` with `superform-hook-master`):

```
Supply / Withdraw:
  [0]  bytes32 placeholder0
  [32] address placeholder1
  [52] address loanToken            // asset supplied/withdrawn
  [72] address collateralToken      // = loanToken for single-asset ops (kept for base invariant)
  [92] address pool
  [112] uint256 amount              // withdraw: type(uint256).max = all
  [144] bool    usePrevHookAmount

Borrow / Repay / RepayWithATokens:
  ...[92] address pool
  [112] uint8   interestRateMode     // validated == 2
  [113] uint256 amount               // repay/repayWithATokens: max = all
  [145] bool    usePrevHookAmount

SupplyAndBorrow:  ...pool@92, mode@112, supplyAmount@113, borrowAmount@145, usePrevHookAmount@177
RepayAndWithdraw: ...pool@92, mode@112, repayAmount@113, withdrawAmount@145 (max), usePrevHookAmount@177
```
Use `BytesLib.toUint8` (`src/vendor/BytesLib.sol:286`) for the mode byte; `_decodeBool` for the bool.

### Execution build pattern (mirror V4)
Supply/repay: `approve(pool, 0) → forceApprove(pool, amount) → poolCall → approve(pool, 0)`. Use
`SafeERC20.forceApprove` (USDT non-zero→non-zero, missing-return). `repayWithATokens` = single execution,
no approval. Preserve the V4 `_preExecute`/`_postExecute` balance-delta accounting so `usePrevHookAmount`
chaining and fee-on-transfer are handled from the *actual* delta, not the requested `amount`.

### Full repay / withdraw
Use `type(uint256).max` for full repay/withdraw rather than a computed amount — interest accrues between
build and execution, so a fixed amount leaves ~1-wei dust that keeps the position open. `repay(max)` is
safe because `onBehalfOf == account == msg.sender`.

## Attack Surface Analysis (on-chain feature)

**Framing:** these hooks build `Execution[]` with `onBehalfOf = account` and custody nothing. Classic
Aave-fork criticals — oracle→bad-debt, first-depositor share inflation, liquidation MEV — are
**protocol-owned and cannot be introduced by the hook**; explicitly out of scope. The real surface is
calldata decoding, approvals, execution ordering, and building routes that revert or strand funds.

### Token Risks
- [ ] Missing-return-value tokens (USDT) — `SafeERC20.forceApprove`/`safeTransfer` (vuln DB §10.3)
- [ ] Fee-on-transfer — balance-delta accounting, not requested `amount` (§10.1)
- [ ] Rebasing / >18-decimals — documented; amounts flow through unchanged (§10.2/10.4)

### Approvals (the one theft-adjacent risk)
- [ ] Reset allowance to 0 after every supply/repay, **including after `repay(max)`** — a lingering
      infinite allowance to a **user-supplied `pool`** address is the fund-drain vector (maps to
      LiFi/unvalidated-calldata precedent, DB §M.5/§8.2)
- [ ] Consider validating `pool` against a trusted registry/allowlist (defense-in-depth) — note V4 does
      not validate the `spoke`; the intent is user-signed. At minimum: zero-allowance invariant + docs.

### Reentrancy
- [ ] CEI / approval-reset ordering (§1.1); executions run by the account, hook holds no state between calls
- [ ] aToken/variableDebtToken are non-callback ERC20s (no 777/1155 hooks)

### Aave-V3-specific revert/strand conditions (safe — no bad debt — but fail routes)
- [ ] `interestRateMode != 2` → validate in-hook, revert `INVALID_RATE_MODE`
- [ ] Isolation mode (can't add 2nd collateral; borrow restricted to approved stables; debt ceiling)
- [ ] Siloed borrowing (only-that-asset); 0%-LTV collateral (supply ok, borrow fails); e-mode mismatch
- [ ] Frozen/paused reserve; supply/borrow caps exceeded
- These have no cheap build-time precheck (hook has no account/reserve state) → **fork tests + docs**, not code

### Access Control / Upgrades
- [ ] No privileged functions; stateless hook; argless constructor
- [ ] `pool` supports Aave Pool proxy upgrades transparently (proxy address stable)

### Exploit Precedent
- [ ] Unvalidated-calldata router drains (LiFi 2022, Dough) → zero-allowance invariant + optional pool allowlist
- [ ] V4 `RepayHook` known limits P1-2 (front-run full-repay DoS) and P1-3 (interest-accrual approval staleness)
      carry over; V3 `repay(max)` semantics make P1-2 **lower impact** (max repays whatever remains)

## Acceptance Criteria
- [ ] `src/vendor/aave-v3/IPool.sol` (+ minimal `DataTypes.ReserveDataLegacy`), MIT, compiles 0.8.30
- [ ] `BaseAaveV3LoanHook` + 7 hooks, `NONACCOUNTING`, argless constructors, `pool` from calldata
- [ ] `interestRateMode` validated `== 2` (`INVALID_RATE_MODE`)
- [ ] `SafeERC20.forceApprove` bracketing; allowance reset to 0 after supply/repay incl. `repay(max)`
- [ ] `type(uint256).max` full repay/withdraw; `repayWithATokens` needs no approval
- [ ] `usePrevHookAmount` + balance-delta accounting preserved (supply→borrow, repay→withdraw, swap→supply)
- [ ] `AAVE_V3_*` Pool constants (Ethereum Core/Prime/EtherFi, Arbitrum, Base, Optimism, Polygon) in `test/utils/Constants.sol`
- [ ] Unit tests per hook (decode, build, usePrevHookAmount, reverts) mirroring `AaveV4LoanHooks.t.sol`
- [ ] No-mock fork integration tests per chain (pinned blocks), positions asserted via aToken/variableDebtToken balances
- [ ] Deploy script `_deployAaveV3HooksSet` + 7 manifest entries (`compatibleProtocols: ["aave-v3"]`)

## Dependencies & Risks
- **Vendor interface accuracy** across V3.0–V3.3 markets → use ABI-stable `ReserveDataLegacy`, minimal subset
- **Per-market aToken addresses** must be resolved per market via that market's `getReserveData` (don't cache across markets); needed for test assertions
- **Fork RPC reliability** per chain → pin fork blocks (avoid the latest-fork CI flakiness we just fixed for Flare)
- **`superform-hook-master` planning** required before writing hook code (CLAUDE.md) — this spec is its input

## Implementation (skeleton)
```solidity
// src/hooks/loan/aave-v3/AaveV3SupplyHook.sol
contract AaveV3SupplyHook is BaseAaveV3LoanHook {
    constructor() BaseAaveV3LoanHook(HookSubTypes.LOAN) {}
    function _buildHookExecutions(address prevHook, address account, bytes calldata data)
        internal view override returns (Execution[] memory ex)
    {
        Vars memory v = _decode(data);                 // loanToken@52, pool@92, amount@112...
        if (v.usePrevHookAmount) v.amount = ISuperHookResult(prevHook).getOutAmount(account);
        // approve0 -> forceApprove(amount) -> supply(asset, amount, account, 0) -> approve0
    }
}
// Borrow/Repay additionally: require(mode == 2, INVALID_RATE_MODE);
// RepayWithATokens: single execution repayWithATokens(asset, amount, 2), no approval
```

## References & Research
- Repo patterns & exact V4→V3 mapping: `research/repo-analysis.md`
- Aave V3 best practices (max sentinels, rate mode, isolation): `research/best-practices.md`
- IPool signatures, versions, addresses: `research/framework-docs.md`
- Security (attack surface A1–A10, invariants INV-1..6): `research/evm-security.md`
- Flow/gap analysis: `research/specflow-analysis.md`
- V4 suite to mirror: `src/hooks/loan/aave-v4/`, tests `test/integration/AaveV4HooksIntegrationTest.t.sol`, `test/integration/AaveV4MultiReserveHooksIntegrationTest.t.sol`
- Vuln DB: `superform-specs/guidelines/solidity/vulnerabilities.md`
