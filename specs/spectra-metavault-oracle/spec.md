# SpectraMetaVaultOracle Spec

## Metadata
- Project: v2-core
- Milestone: Spectra MetaVault Integration
- Linear Issue: N/A
- Interview Date: 2026-05-28
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

The generic `ERC7540YieldSourceOracle` has two bugs when used with Spectra MetaVaultWrapper: (1) `getTVL()` returns 0 because MetaVaultWrapper inherits OZ `totalAssets()` which returns idle USDC instead of vault NAV, and (2) Component 3 (claimable redeem) uses `maxWithdraw()` which calls OZ `_convertToAssets` (idle USDC pricing) instead of the epoch snapshot rate from the overridden `convertToAssets()`.

This spec defines a custom `SpectraMetaVaultOracle` that fixes both issues by using `convertToAssets(totalSupply())` for TVL and `claimableRedeemRequest → convertToAssets` for Component 3. All other behavior is identical to the generic oracle.

## Requirements

### Functional
1. `getTVL()` returns `convertToAssets(totalSupply())` instead of `totalAssets()`
2. Component 3 uses `claimableRedeemRequest(requestId, owner)` → `convertToAssets(claimableShares)` instead of `maxWithdraw(owner)`
3. Components 1, 2, 4, 5 behave identically to `ERC7540YieldSourceOracle`
4. `getPricePerShare()` returns epoch snapshot rate via `convertToAssets(10^decimals)`
5. Share token discovery via `share()` fallback to vault address
6. Works for any Spectra MetaVaultWrapper instance (not hardcoded to 0x6420)

### Non-Functional
- Pure view oracle — no state modifications
- R1/R2 error handling pattern (hard revert for PPS, try/catch for async components)
- Constructor matches generic oracle: `(address superLedgerConfiguration_, uint256 requestId_)`

## Technical Design

### Architecture
```
AbstractYieldSourceOracle
    └── SpectraMetaVaultOracle  (new, fixes getTVL + Component 3)
    └── ERC7540YieldSourceOracle (existing, used for other 7540 vaults)
```

### Key Changes from ERC7540YieldSourceOracle

| Method | Generic Oracle | Spectra Oracle |
|--------|---------------|----------------|
| `getTVL()` | `totalAssets()` | `convertToAssets(totalSupply())` |
| Component 3 | `maxWithdraw(owner)` | `claimableRedeemRequest(requestId, owner)` → `convertToAssets(claimableShares)` |
| All other methods | - | Identical |

### Data Model
No new storage. Single immutable: `REQUEST_ID` (same as generic oracle).

### File Location
`src/accounting/oracles/SpectraMetaVaultOracle.sol`

## Implementation Plan

### Phase 1: Oracle Contract
- [ ] Create `SpectraMetaVaultOracle.sol` extending `AbstractYieldSourceOracle`
- [ ] Implement all 8 abstract methods (copy unchanged ones from ERC7540YieldSourceOracle)
- [ ] Override `getTVL` with `convertToAssets(totalSupply())`
- [ ] Override Component 3 with `claimableRedeemRequest` → `convertToAssets`
- [ ] Add `getAsyncStateBreakdown` public method for monitoring

### Phase 2: Testing
- [ ] Unit tests with mock MetaVault (zero totalAssets, epoch pricing, reverting share())
- [ ] Fork test against live 0x6420 on Base
- [ ] Edge cases: zero balances, zero supply, reverts from claimableRedeemRequest

### Phase 3: Deployment Integration
- [ ] Add to `ORACLE_CONTRACTS` in `regenerate_bytecode.sh`
- [ ] Add Constants.sol key
- [ ] Generate and lock bytecode

## Test Plan
- [ ] Unit tests: Mock MetaVault with divergent totalAssets vs convertToAssets(totalSupply)
- [ ] Unit tests: All 5 TVL components individually
- [ ] Unit tests: Component 3 uses claimableRedeemRequest not maxWithdraw
- [ ] Unit tests: Graceful degradation on claimableRedeemRequest revert
- [ ] Fork test: getTVL > 0 against live 0x6420 on Base
- [ ] Fork test: PPS matches expected epoch rate

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| UUPS proxy upgrade changes behavior | Proxy/Upgrade | Low | High | Same risk as all vault integrations; monitoring alerts | N/A |
| Epoch snapshot rate manipulation | Oracle | Very Low | Medium | Rate set by vault admin during epoch settlement, not manipulable by external actors | Amphor Sherlock 2024 |
| PPS lag between epochs | Business Logic | Certain | Low | Accepted — aligned with vault's own pricing model, no fee leakage beyond epoch boundary | N/A |
| claimableRedeemRequest returns assets not shares | Vault Accounting | Very Low | High | Verified on-chain: function exists, returns 0 for empty positions, ERC-7540 standard requires shares | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Oracle scope? | Spectra-specific, not generic | Interview |
| getTVL fix? | `convertToAssets(totalSupply())` | Interview |
| PPS guards? | None — oracle is pure read layer | Interview |
| Share token discovery? | Inherit `try share() catch { return vault }` fallback | Interview |
| Error handling for claimableRedeemRequest? | try/catch (R2 graceful degradation) | Interview |
| Pending redeem component? | Keep as-is — convertToAssets already uses epoch snapshot | Interview |
| Read-only reentrancy? | Not a concern — pure view oracle | Interview |
| UUPS upgrade risk? | Accept the risk | Interview |
| Multiple vaults? | Yes — works for any MetaVaultWrapper instance | Interview |
| Share decimals? | 6 (USDC-aligned, verified on-chain) | On-chain verification |

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/)

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/spectra-metavault-oracle/technical-spec.md`
