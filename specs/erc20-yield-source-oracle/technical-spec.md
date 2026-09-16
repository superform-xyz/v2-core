# ERC20YieldSourceOracle — Technical Specification

**Linear:** N/A (SuperMAG7-on-BSC workstream) | **Date:** 2026-09-15 | **Status:** Draft (pod-leader review pending)
**Baseline:** `dev` (post PR #1002/#1003/#1004). No dependency on the unmerged AaveV4 oracle branch — its *patterns* are adopted, not its code.

## Overview

A minimal, stateless, identity-PPS yield-source oracle for **plain ERC20 tokens held directly by
SuperVault strategies** — first consumers: BSC tokenized stocks (NVDAb, TSLAb, …) for the
SuperMAG7 vault. `SuperVaultStrategy.manageYieldSource` requires every whitelisted yield source
to carry an oracle satisfying `IYieldSourceOracle`; plain tokens have none today. This contract
closes that gap with pure passthroughs: the token is simultaneously the "vault", the "share",
and the "asset". **All pricing stays off-chain** in the validator network, which keys on the
oracle address as a type discriminator and prices `getBalanceOfOwner(token, strategy)` against
off-chain stock prices. supervault-pricing changes are a separate workstream and explicitly out
of scope here.

## Problem Statement / Motivation

The SuperMAG7 vault holds USDT + tokenized stocks directly (no wrapping vault, no lending). The
on-chain yield-source whitelist is the source of truth for *what* contributes to PPS
(SuperVaultStrategy.sol:94, 871–877), and the stored oracle tells the off-chain pricer *how* to
price it. Without an ERC20-shaped oracle, stock tokens cannot be whitelisted at all — blocking
the vault. (Slack thread Kurisu/Subhasish/Vik 2026-09-15; proposal by Subhasish.)

## Proposed Solution

One new contract, `src/accounting/oracles/ERC20YieldSourceOracle.sol`, extending
`AbstractYieldSourceOracle`:

| Interface function | Implementation |
|---|---|
| `decimals(token)` | `IERC20Metadata(token).decimals()` — doubles as the natural validation gate: non-ERC20s revert here |
| `getPricePerShare(token)` | `10 ** uint256(decimals)` — identity PPS in token decimals (≥78 checked-overflow boundary documented, unreachable for real tokens) |
| `getShareOutput` / `getWithdrawalShareOutput` / `getAssetOutput` | pure identity passthrough of the amount; `assetIn` ignored (fleet-wide accepted precedent); `getAssetOutput` stays `public` (fee-bypass calls it) |
| `getBalanceOfOwner(token, owner)` | `IERC20(token).balanceOf(owner)` |
| `getTVLByOwnerOfShares(token, owner)` | delegates to `getBalanceOfOwner` (PPS = 1:1) |
| `getTVL(token)` | `IERC20(token).totalSupply()` — **global token supply; monitoring-only, never a pricing input** (NatSpec-pinned; pricing consumers must use `getBalanceOfOwner`) |
| `getAssetOutputWithFees` | **bypass override** — returns `getAssetOutput(...)`, never consults `SUPER_LEDGER_CONFIGURATION` (post-#997 AaveV4Supply/MorphoBlueDebt shape, verbatim) |
| batch views | inherited from the abstract (isolated ByOwner batch; unisolated PPS/TVL batches — documented) |

Constructor: `constructor(address superLedgerConfiguration_)` with `ZERO_ADDRESS` check and the
"retained for interface parity" NatSpec (AaveV4 precedent). No registry, no storage, no admin,
no events — one deployed instance serves every ERC20 (ERC4626YieldSourceOracle structural
template, ~100–140 lines). Standalone accounting-oracle class: no hook or ledger wiring
(NONACCOUNTING loan-hook precedent — Euler/MorphoBlue debt oracles).

### Contract-level `@dev` invariant block (required content)

1. **feePercent = 0 operational invariant, BOTH fee paths** (view path overridden here; ledger
   path `BaseLedger._processOutflow` NOT guarded on-chain). No hook ever snapshots cost basis
   for plain ERC20 holdings → any configured fee taxes principal as profit (PR #997 F1 class).
   **FlatFeeLedger registration is categorically forbidden** (fees full principal with cost
   basis hardcoded 0 — FlatFeeLedger.sol:38–57). Re-enabling fees = new oracle version, never a
   config change.
2. **Identity semantics**: values in token units; cross-asset pricing is external (validator
   network / SuperOracle).
3. **`getTVL` = global `totalSupply()`** — monitoring-only.
4. **Token-behavior scope**: rebasing and fee-on-transfer tokens out of scope (documented, not
   engineered); >18-decimals caution note; whitelister owns token due-diligence (single entry
   point — TUSD double-entry class; corporate-action/split mechanics; blocklist semantics).
5. **Revert surface, scoped precisely** (avoid AaveV4-P3-3-style overclaim): `decimals` and
   `getPricePerShare` revert for non-ERC20 addresses; identity converters answer for ANY
   address; balance/TVL views revert if the target lacks the read.
6. **Batch behavior**: standard fleet block (ByOwner isolated; PPS/TVL batches poisoned by one
   reverting entry). Duplicate entries: dedup is the caller's job.

## Technical Considerations

- **Architecture**: pure view leaf, zero coupling; consumed off-chain today (no on-chain reader
  of these views exists in `src/` — verified). SuperYieldSourceOracle router works with it
  unchanged (pass as `yieldSourceOracle` param).
- **ABI note**: implements the current interface → lands on the new tuple-ABI side of the
  `getTVLByOwnerOfSharesMultiple` mixed-fleet ROLLOUT.
- **Performance**: 3 STATICCALLs max per view; nothing to optimize.
- **Periphery**: zero code change — `manageYieldSource(token, erc20Oracle, Add)` suffices.

## Attack Surface Analysis

(Full detail: research/evm-security.md. Honest summary — the surface is small.)

### Token risks
- [x] Rebasing (10.2): OUT OF SCOPE, documented + made executable via a rebasing-mock
  documentation test; realistic trigger is stock splits implemented as rebases — whitelisting
  checklist requires the issuer's corporate-action mechanism confirmed in writing.
- [x] Fee-on-transfer (10.1): N/A to a settled-balance reader; whitelisting checklist item only.
- [x] **Double-entry/proxy tokens (18.1.3 — TUSD class): strongest applicable risk.** Two entry
  points → off-chain pricer double-counts → PPS inflation → extractable via SuperVault
  mint/redeem. Mitigation is operational (single-entry-point verification per whitelisting) +
  an executable canonical-entry check; the oracle stays registry-free by design.
- [x] Blocklist/pausable (7.4-adjacent): reads stay live while assets are frozen → PPS overstates
  *redeemable* NAV; monitoring concern (rsETH-precedent framing), documented.
- [x] ≥78 decimals: checked-overflow boundary pinned by test (AaveV4 pattern).

### Fee pipeline (the #997 F1 class)
- [x] View path: bypass override (code-guarded).
- [x] `BaseLedger._processOutflow`: benign today only via emergent cost-basis math — invariant
  triple-anchored (NatSpec + runbook + executable tests).
- [x] `FlatFeeLedger`: maximal hazard (full-principal fee) — categorically forbidden; executable
  hazard-documentation test required.

### Reentrancy / oracle / MEV / access / upgrades
- [x] Read-only reentrancy (1.4): N/A today — no on-chain consumer, off-chain reads at settled
  blocks; assumption documented, not engineered.
- [x] Price manipulation / flash loans (4.x, 5.x): no curve to bend — identity only.
- [x] Access control / proxy / storage / first-depositor of the oracle itself: structurally
  absent (stateless, immutable-only, no admin).
- [x] Batch poisoning (7.1/13.2): inherited, documented, pinned by known-issue test.

### Exploit precedent
- [x] Compound TUSD double-entry (2021) — adapted: double-count, the one precedent converting to
  extraction here. Compound Prop 62 / Moonwell 2025 — the config-not-code fee class. rsETH
  2026 — live-reads-≠-realizable-value. Donation/first-depositor (Hundred/Sonne) — assessed
  N/A for the oracle (no exchange-rate function of its own; SuperVault's surface, not ours).

## Acceptance Criteria

### Contract
- [ ] `src/accounting/oracles/ERC20YieldSourceOracle.sol`: 8 overrides per the table above;
  fee-bypass override verbatim-shaped on MorphoBlueDebtOracle.sol:208–228; `ZERO_ADDRESS`
  constructor check + parity NatSpec; full contract-level `@dev` invariant block (6 items
  above); house style (banners, `@inheritdoc`, unnamed unused params, `10 ** uint256(dec)`).

### Tests — `test/unit/accounting/oracles/ERC20YieldSourceOracle.t.sol` (EulerDebtOracle.t.sol bar)
- [ ] T1 identity fuzz: all three converters return amount ∀ (token, assetIn incl. zero/self,
  amount ≤ uint128.max); round-trip identity.
- [ ] T2 decimals: 6/8/18 mock fixtures passthrough; PPS = 10^d; 77 max-safe / 78 reverts.
- [ ] T3 balance/TVL: track mint/burn/transfer on real MockERC20s; TVL = totalSupply;
  invariant fuzz `getTVL ≥ getBalanceOfOwner` on standard mocks (comment: hostile tokens can
  violate — sanity pin, not guarantee).
- [ ] T4 fee-bypass proof: real `SuperLedgerConfiguration` with feePercent = 10% against (a)
  MockZeroCostBasisLedger and (b) `FlatFeeLedger` → `getAssetOutputWithFees == getAssetOutput`
  in both. Companion FlatFeeLedger hazard-documentation test (outflow fees full principal —
  the executable *why* of the invariant).
- [ ] T5 real-ledger round trip: BaseLedger snapshot-then-outflow at identity PPS → fee 0 on
  principal at 10% configured fee.
- [ ] T6 non-ERC20 sweep: EOA + contract-without-decimals → `decimals`/`getPricePerShare`
  revert; converter behavior for arbitrary addresses pinned per function.
- [ ] T7 batch: ByOwner failure isolation (EOA entry → `succeeded=false`, others fine);
  ARRAY_LENGTH_MISMATCH; empty arrays; KNOWN-ISSUE pin
  `test_batch_ppsAndTvlMultiple_knownIssue_abortOnNonToken`; duplicate-entry passthrough.
- [ ] T8 rebasing documentation test: rebasing mock shifts reported balance — the out-of-scope
  declaration made executable.
- [ ] (Optional, if B-token addresses confirmed from Venus VIP-654) BSC fork parity test:
  decimals/balanceOf/totalSupply vs direct reads at a pinned block; liveness under issuer
  pause flags if exposed; canonical-entry-point assertion (implementation-slot read).

### Wiring (6 mechanical edits — locations verified in research/repo-analysis.md §4)
- [ ] `regenerate_bytecode.sh` ORACLE_CONTRACTS + fresh `generated-bytecode/` +
  `locked-bytecode-dev/` artifacts in the same PR.
- [ ] `DeployV2Core.s.sol`: `_deployOracles` len 20→21 + `oracles[20]` (Euler single-arg
  precedent, :4861); availability array `string[21]` + `// [20]` entry.
- [ ] `Constants.sol`: `ERC20_YIELD_SOURCE_ORACLE_KEY` (no legacy `_SALT` constant).
- [ ] `verify_v2_staging_prod.sh`: BOTH cases (constructor-args group + source-path map) — do
  not replicate the EulerDebtOracle gap.
- [ ] Ops runbook note (SECURITY.md or ledger-config runbook): never register this id in
  SuperLedgerConfiguration; if ever required, feePercent = 0 and ledger ≠ FlatFeeLedger;
  per-token whitelisting checklist (single entry point, non-rebasing, corporate-action
  mechanism, blocklist semantics, not itself a vault share, decimals ≤ 18); curator/manager is
  a multisig.

## Success Metrics
- SuperMAG7 staging vault on BSC can whitelist NVDAb/TSLAb via
  `manageYieldSource(token, erc20Oracle, Add)` with no periphery change.
- Zero P0/P1 in security review; fee-bypass and hazard tests green.

## Dependencies & Risks
- None on other in-flight PRs (AaveV4 branch not required).
- Validator-network contract (documented, not built here): price
  `getBalanceOfOwner(token, strategy)` per whitelisted token; dedup by balance slot; never use
  `getTVL` for pricing.
- Risk table: see spec.md.

## Implementation

### src/accounting/oracles/ERC20YieldSourceOracle.sol (skeleton)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title ERC20YieldSourceOracle
/// @author Superform Labs
/// @notice Identity-PPS yield-source oracle for plain ERC20 tokens held directly by strategies
/// @dev [contract-level invariant block — 6 items per spec §"invariant block"]
contract ERC20YieldSourceOracle is AbstractYieldSourceOracle {
    error ZERO_ADDRESS();

    /// @param superLedgerConfiguration_ Retained for interface parity with a future fee-capable
    ///        oracle version; this oracle's getAssetOutputWithFees intentionally bypasses the
    ///        inherited fee path. Must be non-zero.
    constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) {
        if (superLedgerConfiguration_ == address(0)) revert ZERO_ADDRESS();
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        return IERC20Metadata(yieldSourceAddress).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) {
        return assetsIn;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getWithdrawalShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) {
        return assetsIn;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getAssetOutput(address, address, uint256 sharesIn) public pure override returns (uint256) {
        return sharesIn;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Always 1:1 identity in token decimals; reverts via checked arithmetic if
    ///      decimals >= 78 (cannot occur with real ERC-20 tokens)
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        return 10 ** uint256(IERC20Metadata(yieldSourceAddress).decimals());
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares) public view override returns (uint256) {
        return IERC20(yieldSourceAddress).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Identical to getBalanceOfOwner since PPS = 1:1
    function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares) public view override returns (uint256) {
        return getBalanceOfOwner(yieldSourceAddress, ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev GLOBAL token totalSupply — monitoring-only; never a pricing input (pricing consumers
    ///      must use getBalanceOfOwner)
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return IERC20(yieldSourceAddress).totalSupply();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Overridden to bypass fee computation entirely [full NOTE block per
    ///      MorphoBlueDebtOracle.sol:208–228 shape]
    function getAssetOutputWithFees(
        bytes32,
        address yieldSourceAddress,
        address assetOut,
        address,
        uint256 usedShares
    )
        external
        view
        override
        returns (uint256)
    {
        return getAssetOutput(yieldSourceAddress, assetOut, usedShares);
    }
}
```

## References & Research
- Repo patterns & wiring: [research/repo-analysis.md](./research/repo-analysis.md)
- Security analysis: [research/evm-security.md](./research/evm-security.md)
- Flow gaps: [research/specflow-analysis.md](./research/specflow-analysis.md)
- Interview: [interview-notes.md](./interview-notes.md)
- Fee-bypass precedent: MorphoBlueDebtOracle.sol:208–228; PR #997 review F1 (AaveV4 branch)
- Closest deployed sibling (pre-#997 shape, do better): StakingYieldSourceOracle.sol
- Consumer: v2-periphery SuperVaultStrategy.sol:462–464, 871–878
