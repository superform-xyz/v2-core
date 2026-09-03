# Aave V4 Oracles — Technical Specification

**Linear:** SUP-20854 | **Date:** 2026-09-02 | **Status:** Draft (pod-leader review pending)
**Baseline:** `dev` + PR #990 (Euler loan hooks) + PR #996 (SUP-20842 repay-cap semantics). The oracle contracts themselves have no dependency on either PR (they read spoke state directly); the outflow-flow narrative assumes #996's zero-debt-skip semantics.

## Overview

Aave V4 has no Superform accounting oracle on either side. This spec adds three contracts so SuperLedger-family consumers (monitoring, SuperVaults, periphery, and — after future wiring — the fee pipeline) can price smart-account positions on Aave V4 spokes:

- **`AaveV4DebtOracle`** — debt side, Euler-shaped identity-PPS oracle over `spoke.getUserDebt(reserveId, account)` (drawn + premium).
- **`AaveV4SupplyYieldSourceOracle`** — supply side, identity-PPS asset-denominated oracle over `spoke.getUserSuppliedAssets(reserveId, account)`, fee-capable in shape.
- **`AaveV4ReserveRegistry`** — maps a hash-derived pseudo-address key to `(spoke, reserveId)`, shared by both oracles (MorphoBlueMarketRegistry model).

Driver: Aave V4 tokenized-equities launch on Base (borrow stables against equity collateral). Execution-side hooks (`AaveV4*HookV2`) already exist and need no changes for new markets.

## Problem Statement / Motivation

SuperLedger's oracle registry keys yield sources by `address`. Aave V4 positions are `(spoke, reserveId)` pairs with no aToken/debtToken handles (positions are spoke-internal shares), so there is nothing to point an existing oracle at. Without these oracles, Aave V4 positions are invisible to Superform accounting, monitoring, and any future fee configuration — blocking the Base equities integration beyond bare hook execution.

## Scope resolution (from spec-flow analysis — read this first)

Three P0 findings from `research/specflow-analysis.md` shape the scope:

**S1 — These are STANDALONE accounting oracles, exactly like their precedents.** Every loan hook in the repo is `HookType.NONACCOUNTING`; `SuperExecutorBase._updateAccounting` never fires for them, and the deployed `EulerDebtOracle`/`MorphoBlueDebtOracle`/`MorphoBlueYieldSourceOracle` are equally hook-unwired. SUP-20854 delivers the same class of artifact: on-chain view oracles consumed by monitoring/periphery/off-chain accounting. **Live ledger wiring (hook `HookType` changes, two-position publication from bundled hooks) is explicitly OUT of scope** and becomes a follow-up ticket if/when the pod wants on-chain fees for loan positions. This matches the interview note that "oracle work does not block a basic hook-level integration demo" — and conversely, hook execution does not block oracle value.

**S2 — Supply oracle is identity/asset-denominated (Euler-shaped), not shares-PPS.** The research's real-PPS recommendation is architecturally incompatible with the loan-hook family: hooks measure ERC20 wallet deltas (asset units) and V4 has no share token; `BaseLedger._takeSnapshot` treats inflow amounts as shares, which is only unit-safe when hook-reported units and oracle PPS units agree. Identity PPS (shares ≡ assets) keeps every consumer unit-consistent with what hooks can actually report. The oracle stays **fee-capable in shape** (inherited `getAssetOutputWithFees`, no override — interview decision #6): with identity PPS, ledger cost-basis math degenerates to principal-tracking, which under-charges yield fees but never over-charges; real yield-fee capability requires the future wiring work and is documented as such in NatSpec.

**S3 — Implementation gate: confirm Base equity reserves use plain `ISpoke`, not `TokenizationSpoke`.** If equities route through Aave's ERC-4626 `TokenizationSpoke` wrapper, the existing `ERC4626YieldSourceOracle` covers them with zero new code and this spec's deliverable shrinks. Joao-call question #1; do not start implementation before it's answered.

## Proposed Solution

### Architecture

```
                            ┌──────────────────────────┐
     MARKET_MANAGER_ROLE ──▶│   AaveV4ReserveRegistry   │  registerReserve(spoke, reserveId)
                            │  key = addr(keccak(spoke, │  ── validates spoke.getReserve(id)
                            │        reserveId)[12:])   │  ── stores (spoke, id, underlying, decimals)
                            └────────────┬─────────────┘
                                         │ getReserveInfo(key) / MARKET_NOT_REGISTERED
                        ┌────────────────┴───────────────┐
             ┌──────────▼─────────┐          ┌───────────▼──────────────┐
             │  AaveV4DebtOracle  │          │ AaveV4SupplyYieldSource  │
             │  (identity PPS)    │          │ Oracle (identity PPS,    │
             │  bal = drawn+prem  │          │  fee-capable shape)      │
             │  TVL = reserveDebt │          │  bal = suppliedAssets    │
             └──────────┬─────────┘          └───────────┬──────────────┘
                        └───────────┬────────────────────┘
                                    ▼
                     IAaveV4Spoke (extended: + getReserveDebt,
                       getReserveSuppliedAssets)   [view-only reads]
```

Both oracles extend `AbstractYieldSourceOracle`, are immutable and constructor-light (`superLedgerConfiguration_`, `registry_` with zero-address check), and hold no admin surface. The registry is the only writable contract.

### Contract specifications

#### `src/vendor/aave-v4/IAaveV4Spoke.sol` (extension)

Add (verified present upstream in `ISpoke`, see `research/framework-docs.md` §2.2):

```solidity
function getReserveDebt(uint256 reserveId) external view returns (uint256 drawnDebt, uint256 premiumDebt);
function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256);
```

No other additions (keep the vendored surface minimal; document the upstream commit verified against).

#### `src/accounting/oracles/AaveV4ReserveRegistry.sol`

MorphoBlueMarketRegistry model, verbatim where applicable:

- **Key derivation (security-critical, non-negotiable):** `reserveKey = address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))))`. Hash-derived, never operator-chosen — a key can only ever bind to the `(spoke, reserveId)` that hashes to it, making rebinding impossible by construction (evm-security §1.4). Pure preview: `computeReserveKey(address spoke, uint256 reserveId)`.
- **Governance:** OZ `AccessControl`; `MARKET_MANAGER_ROLE`; constructor grants `DEFAULT_ADMIN_ROLE` + manager to `admin_`. Registration is role-gated and add-only; no overwrite (`RESERVE_ALREADY_REGISTERED`); deregistration via propose/execute/cancel with `DEREGISTER_DELAY = 2 days` and the SAFETY INVARIANT NatSpec copied from Morpho (deregistering a key with live positions bricks reads and fee-charging withdrawals).
- **Registration validation:** `IAaveV4Spoke(spoke).getReserve(reserveId)` must succeed (reverts for codeless spokes and unlisted reserves — both become the registry's typed revert) and return non-zero `underlying`. Store `(spoke, reserveId, underlying, decimals)` from the returned `Reserve` struct.
- **Resolution:** `getReserveInfo(reserveKey) → (spoke, reserveId, underlying, decimals)`, reverting `RESERVE_NOT_REGISTERED` for unknown keys (never return zero-structs); `isRegistered(key)` view.
- **Intentional absences (document for reviewers):** no IRM-approval analog (V4 accrual is hub-internal; nothing external executes in reads); no spoke allowlist — the spoke address is the trust root behind `MARKET_MANAGER_ROLE`, same trust shape as Morpho's caller-trusted singleton. The multi-spoke duplication risk (same economic reserve under two spokes → one user position split across two keys) is an **accepted, documented operational risk** with a registry NatSpec warning + ops-runbook rule ("one key per economic reserve per chain"), matching interview decision #8's precedent-verbatim instruction.

#### `src/accounting/oracles/AaveV4DebtOracle.sol`

Euler shape with the Morpho fee-bypass hardening:

- `decimals(key)` = registry-stored reserve decimals.
- `getPricePerShare(key)` = `10 ** decimals(key)` (identity; never zero → `BaseLedger.INVALID_PRICE` unreachable).
- `getShareOutput` / `getWithdrawalShareOutput` / `getAssetOutput` = pure identity passthroughs.
- `getBalanceOfOwner(key, owner)` = `getTVLByOwnerOfShares(key, owner)` = `drawn + premium` from `spoke.getUserDebt(reserveId, owner)` — the exact read `BaseAaveV4LoanHookV2._totalDebt` uses, so hook-resolved repays and oracle-read debt can never disagree. Asset units, not shares (NatSpec).
- `getTVL(key)` = `drawn + premium` from `spoke.getReserveDebt(reserveId)` (the `totalBorrows()` analog).
- **Override `getAssetOutputWithFees` to bypass fee math** (MorphoBlueDebtOracle L215-228 pattern — the security review's P2-1 hardening; interview decision #5's "precedent" is honored by taking the *newer* of the two divergent precedents, with NatSpec noting the older Euler oracle lacks it).
- **feePercent = 0 operational invariant** NatSpec block at EulerDebtOracle L17-24 strength: debt takes no cost-basis snapshots; a nonzero fee makes the ENTIRE debt read as profit through `BaseLedger._processOutflow` (which the override cannot protect); invariant enforced by ops runbook + governance checklist + the executable misconfiguration test (T1).
- Rounding: pass-through only — V4 already rounds debt up at source (`rayMulUp` drawn, `fromRayUp` premium); document no double-rounding.

#### `src/accounting/oracles/AaveV4SupplyYieldSourceOracle.sol`

Identity shape, fee-capable:

- `decimals` / `getPricePerShare` / identity passthroughs: as debt oracle.
- `getBalanceOfOwner(key, owner)` = `getTVLByOwnerOfShares(key, owner)` = `spoke.getUserSuppliedAssets(reserveId, owner)` (asset units; V4 rounds down at source — conservative for claims; NatSpec).
- `getTVL(key)` = `spoke.getReserveSuppliedAssets(reserveId)`.
- **`getAssetOutputWithFees` override: fee BYPASS for the standalone phase** (REVISED per PR #997 review F1, superseding interview decision #6's fee-capable-view shape): with no hook wiring, supply positions never take cost-basis snapshots, so the inherited fee view would treat the entire principal as profit and inflate quoted outputs. Both oracles now bypass the fee view identically; **feePercent = 0 is an operational invariant for BOTH oracles** until accounting hooks exist. The ledger path (`BaseLedger._processOutflow`) remains unguarded on-chain (documented) and, once wired, fees measured asset-delta profit only (yield, never principal — pinned by the real-ledger tests). Re-enabling the fee view requires a new oracle version, not a config change.
- Cost-basis desync via direct spoke withdrawal (self-calls allowed by `onlyPositionManager`) is the existing SECURITY.md trade-off — restate.

### What does NOT change

- No hook changes of any kind (types, settle logic, layouts). No `SuperExecutorBase` changes. No `BaseLedger`/`SuperLedgerConfiguration` changes.
- Legacy oracles untouched; Euler's missing fee-bypass override is noted, not backported (candidate follow-up).
- No price feeds anywhere in the three contracts (interview decision #7) — cross-asset valuation stays external; equity trading-hours/Chainlink-24/5 staleness is absorbed at Aave's layer.

## Attack Surface Analysis

(Condensed from `research/evm-security.md`; full detail there.)

### Token / RWA risks
- [x] No token transfers occur in any of the three contracts — fee-on-transfer/rebasing/pausable classes N/A to the oracles (10.x). B20 equity tokens: freely transferable, corporate actions via internal multiplier (no rebase drift on spoke reads). Confirm B20 transfer hooks with Aave (residual read-only-reentrancy surface — hook layer, not oracle).

### Reentrancy
- [x] View-only oracles; registry writes are role-gated with no external calls after state writes (CEI trivial) (1.1).
- [x] Read-only reentrancy (1.4): V4 spoke mutations are `nonReentrant` (transient); views unguarded but the oracles hold no ratio math and SuperLedger reads occur inside Superform's own executor flow, never inside Aave callback frames. Documented, not engineered. Future flash-loan hooks would reopen this — flagged for hook design reviews.

### Oracle & price
- [x] No external price feeds; no staleness surface (4.x). Spoke views verified virtually-accrued to `block.timestamp` upstream; fork tests re-pin this.

### Access control & upgrades
- [x] Oracles immutable, no admin. Registry: role-gated add-only, hash-derived keys (rebinding impossible by construction), 2-day timelocked deregistration (2.1, 2.4). No proxies anywhere in the deliverable (11.x N/A). Aave spokes ARE proxies — binding survives upgrades (stable address); semantics drift mitigated by interface pinning + fork tests + ops monitoring of Aave governance.

### Accounting / fee risks (the real surface)
- [x] **feePercent misconfiguration = full debt taxed as profit** — highest-consequence item; triple-anchored (NatSpec both paths, ops runbook, executable test T1). Note: inert under current NONACCOUNTING wiring; the test documents a hazard that becomes reachable only with future wiring.
- [x] Donation/inflation (22.x, 28.x): structurally mitigated — V4 supply is internal index bookkeeping; donations don't move `getUserSuppliedAssets`. Early-participation risk on fresh low-liquidity equity reserves is an Aave-side note.
- [x] Unregistered keys revert typed (never return 0 → no zero-value-outflow fee bypass).
- [x] Batch isolation: `getTVLByOwnerOfSharesMultiple` isolates per-entry; `getPricePerShareMultiple`/`getTVLMultiple` do NOT (inherited) — documented + known-issue test T8.

### Exploit precedent
- [x] Sentiment/Sturdy/Cream/Curve class (manipulable views) eliminated by design (no ratio math, no donatable balances, no price feeds). Compound Prop-62 class (wrong-baseline accrual) survives as the feePercent invariant — where test effort concentrates. Euler-2023 lesson → Joao question on discontinuous `getUserDebt` changes (safe only while feePercent = 0).

## Acceptance Criteria

### Contracts
- [ ] `IAaveV4Spoke` extended with `getReserveDebt` + `getReserveSuppliedAssets` (verified against pinned upstream commit).
- [ ] `AaveV4ReserveRegistry` with hash-derived keys, `computeReserveKey` preview, register-time `getReserve` validation, add-only + 2-day timelocked deregistration, SAFETY INVARIANT NatSpec, typed `RESERVE_NOT_REGISTERED`/`RESERVE_ALREADY_REGISTERED` errors, `isRegistered`/`getReserveInfo` views.
- [ ] `AaveV4DebtOracle`: identity PPS; balance/TVL-by-owner = drawn + premium; TVL = reserve-level aggregate; `getAssetOutputWithFees` fee-bypass override; feePercent = 0 NatSpec block covering both fee paths; asset-units documentation.
- [ ] `AaveV4SupplyYieldSourceOracle`: identity PPS; balance/TVL-by-owner = supplied assets; TVL = reserve aggregate; NO fee override; NatSpec covering principal-tracking fee semantics, config-fallthrough, and the future-wiring non-goal.
- [ ] Explicit scope statement in both oracles' NatSpec: standalone accounting oracles; no hook currently drives them through the ledger (S1); wiring is a follow-up.

### Tests (unit — `test/unit/accounting/oracles/`, reusing `MockAaveV4SpokeV2`; ~Euler/Morpho suite bar)
- [ ] T1: feePercent-misconfiguration demonstration (feePercent=1000 → fee == 10% of full debt; 0 → 0) via `MockZeroCostBasisLedger` pattern.
- [ ] T2: zero edges — (0,0), drawn-only, premium-only debt; zero supply; fuzz drawn/premium to `uint128.max`, `total == drawn + premium` exact.
- [ ] T3: unregistered key — every view reverts typed; `getTVLByOwnerOfSharesMultiple` isolates the entry (`0, succeeded=false`) while others succeed.
- [ ] T4: registry lifecycle — duplicate register reverts; deregistration timelock boundary fuzz; post-deregistration reads revert; re-registration restores the identical key (`computeReserveKey` property test).
- [ ] T5: registry validation — reverting / zero-underlying / codeless-EOA spoke → typed revert.
- [ ] T6: decimals independence — 6-decimal loan reserve + 18-decimal collateral reserve resolve independently per key.
- [ ] T7: supply fee math via inherited path — configured fee with identity PPS never over-charges (profit == 0 on principal round-trip); missing config falls through to plain output.
- [ ] T8: known-issue test — one reverting key poisons `getPricePerShareMultiple`/`getTVLMultiple` (documented inherited limitation).
- [ ] T9: hook/oracle consistency — oracle debt read equals `_totalDebt`-style read on the same mock state (anchors Finding C's unit analysis).

### Tests (fork — pinned block; Ethereum spoke `0x94e7A5dCbE816e498b89ab752661904E2F56c485` now, Base spoke when address known)
- [ ] F1: `getUserDebt` accrual visible in-view after warp with no state touch; premium included same-block after borrow.
- [ ] F2: repay-to-zero via V2 hooks → oracle reads exactly 0 (consistent with SUP-20842 zero-debt-skip; baseline dev+#990+#996).
- [ ] F3: view liveness under paused/frozen flags (mock flags if pause can't be induced) — pins the Aave-side assumption.
- [ ] F4: real-market registration + all views on USDC (6) and WETH (18) reserves; equity reserve added when live.

### Tooling / deployment
- [ ] All three contracts appended to `regenerate_bytecode.sh` ORACLE_CONTRACTS; generated + locked-bytecode-dev twins committed fresh (no stale ABI/selectors — PR #990 R1 precedent); prod locked-bytecode only at lock time (`__checkBytecodeExists` guard covers absence).
- [ ] `*_KEY` constants + versioned salt strings in `script/utils/Constants.sol`; registry-first deploy wiring + verification records in `DeployV2Core.s.sol`; per-chain output JSONs + `DeployV2CoreVerificationRecords.t.sol`.
- [ ] Ledger-config runbook: debt-oracle id registered with **feePercent = 0** (or left unregistered); supply-side fee per market decision; governance-review checklist line item.
- [ ] Deployment matrix: enumerate chains with live Aave V4 spokes (Ethereum confirmed; Base pending equities spoke address; others per Aave governance) — "all V4 chains day one" scoped to chains where a spoke actually exists.
- [ ] Security-review report at `specs/security-reports/<date>-aave-v4-oracles.md` (3-agent flow, MorphoBlue precedent).

## Success Metrics
- Both oracles return correct values against the live spoke for every registered reserve (fork-verified).
- Zero P0/P1 findings in the security review.
- Registry seeded for the Base equities markets within one day of Aave publishing the spoke address.

## Dependencies & Risks

| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| feePercent > 0 misconfig on debt oracle | Vault Accounting | Low | High (full debt taxed as profit) | Fee-bypass override (view path) + NatSpec + runbook + T1; inert until wiring exists | Compound Prop 62 (~$80M, wrong-baseline accrual) |
| Registry key rebinding | Access Control | ~0 by construction | High | Hash-derived keys; no-overwrite; timelocked deregistration | Morpho registry model |
| TokenizationSpoke used for equities | Business Logic | Medium | High (wrong deliverable shape) | S3 implementation gate — Joao question before coding | — |
| V4 API/semantics drift (pre-hardening) | Operational | Medium | Medium | Interface pinning, fork tests, ops monitoring of spoke upgrades (proxies) | — |
| Views revert under pause/freeze | Operational | Low | Medium (accounting reads DoS during trading-hours pauses) | F3 + Joao confirmation; batch try/catch containment | Venus/LUNA freeze |
| Same reserve under two spokes | Operational | Low | Medium (split positions) | Documented accepted risk + runbook rule; no on-chain allowlist (precedent-verbatim) | — |
| Read-only reentrancy | Reentrancy | Low | Low (no ratio math; reads inside own executor flow) | Documented; B20-hooks question to Aave; flag for future flash-loan hook reviews | Sentiment 2023 (~$1M) |
| Deregistration with live positions | Operational | Low | High (bricks reads/withdraw accounting) | SAFETY INVARIANT + 2-day timelock | Morpho registry NatSpec |
| Premium 1-wei rounding vs repay(max) | Token Behavior | Low | Low (hook-side revert, not misaccounting) | Joao question + fork test | — |

**Dependencies:** Aave publishing the Base equities spoke address + reserve ids (fork tests, registry seeding, deployment matrix). Joao-call answers to the seven questions in `research/specflow-analysis.md` (question 6 gates implementation).

## Implementation (skeletons)

### AaveV4DebtOracle.sol (shape)
```solidity
contract AaveV4DebtOracle is AbstractYieldSourceOracle {
    IAaveV4ReserveRegistry public immutable REGISTRY;

    constructor(address slc_, address registry_) AbstractYieldSourceOracle(slc_) {
        if (registry_ == address(0)) revert ZERO_ADDRESS();
        REGISTRY = IAaveV4ReserveRegistry(registry_);
    }

    function decimals(address key) public view override returns (uint8) {
        (,, , uint8 dec) = REGISTRY.getReserveInfo(key); // reverts RESERVE_NOT_REGISTERED
        return dec;
    }

    function getPricePerShare(address key) public view override returns (uint256) {
        return 10 ** decimals(key); // identity
    }

    function getBalanceOfOwner(address key, address owner) external view override returns (uint256) {
        (address spoke, uint256 reserveId,,) = REGISTRY.getReserveInfo(key);
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(spoke).getUserDebt(reserveId, owner);
        return drawn + premium; // asset units; V4 rounds up at source — pass through
    }
    // getTVLByOwnerOfShares = same sum; getTVL via getReserveDebt; identity converters;
    // getAssetOutputWithFees override returns getAssetOutput(...) unconditionally (fee bypass)
}
```

### AaveV4ReserveRegistry.sol (key + registration core)
```solidity
function computeReserveKey(address spoke, uint256 reserveId) public pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))));
}

function registerReserve(address spoke, uint256 reserveId) external onlyRole(MARKET_MANAGER_ROLE) {
    IAaveV4Spoke.Reserve memory r = IAaveV4Spoke(spoke).getReserve(reserveId); // reverts: codeless/unlisted
    if (r.underlying == address(0)) revert INVALID_RESERVE();
    address key = computeReserveKey(spoke, reserveId);
    if (reserves[key].spoke != address(0)) revert RESERVE_ALREADY_REGISTERED();
    reserves[key] = ReserveInfo(spoke, reserveId, r.underlying, r.decimals);
    emit ReserveRegistered(key, spoke, reserveId, r.underlying);
}
// + propose/execute/cancelDeregistration with DEREGISTER_DELAY = 2 days (Morpho verbatim)
```

Supply oracle mirrors the debt oracle with `getUserSuppliedAssets`/`getReserveSuppliedAssets` and no fee override.

## Future Considerations
- **Live ledger wiring** (follow-up ticket): accounting-typed single-leg hooks or a two-position settle interface; a shares-PPS supply-oracle variant becomes viable then.
- **Euler fee-bypass backport**: `EulerDebtOracle` lacks the `getAssetOutputWithFees` override — candidate hardening PR.
- **TokenizationSpoke markets**: covered by existing `ERC4626YieldSourceOracle` — no new work if Aave routes future markets through it.
- **Aave V3 oracles**: explicitly out of scope; the V3 aToken/variableDebtToken model would use plain token-address keys (no registry needed) if ever wanted.

## References & Research
- Interview: [interview-notes.md](./interview-notes.md)
- Repo conventions & precedents: [research/repo-analysis.md](./research/repo-analysis.md)
- Aave V4 API verification: [research/framework-docs.md](./research/framework-docs.md)
- Architecture & Base equities context: [research/best-practices.md](./research/best-practices.md)
- Security analysis: [research/evm-security.md](./research/evm-security.md)
- Flow gaps (P0 findings): [research/specflow-analysis.md](./research/specflow-analysis.md)
- Precedent code: `src/accounting/oracles/{EulerDebtOracle,MorphoBlueDebtOracle,MorphoBlueMarketRegistry,ERC4626YieldSourceOracle}.sol`, `src/accounting/BaseLedger.sol`, `src/vendor/aave-v4/IAaveV4Spoke.sol`
- Precedent commit: `e58a82b5` (Euler/MorphoBlue debt oracle recording); security report `specs/security-reports/2026-08-17-morpho-blue-debt-oracle.md`
- Vulnerability DB: `superform-specs/guidelines/solidity/vulnerabilities.md`
