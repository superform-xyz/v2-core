# DETH Oracle Spec

## Metadata
- Project: Superform v2
- Milestone: DETH Vault Integration
- Linear Issue: N/A
- Interview Date: 2026-05-12
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Custom yield source oracle for Dialectic's DETH/Machine vault enabling Superform's accounting system to calculate PPS, performance fees, and TVL for the DETH async redemption flow. The oracle receives AsyncRedeemer as `yieldSourceAddress`, discovers Machine vault immutably via `.machine()`, and calls ERC-4626 conversion functions on Machine for pricing. It accounts for pending async redemptions (ERC-721 NFT receipts) in TVL to prevent artificial PPS drops during the finalization window.

## Requirements

### Functional
1. Extend `AbstractYieldSourceOracle` with immutable Machine/DETH/WETH resolution
2. Route pricing calls (convertToAssets, convertToShares) to Machine vault
3. Track pending async redemptions in `getTVLByOwnerOfShares` to prevent TVL drops
4. Use `convertToAssets`/`convertToShares` (not preview functions) for async safety
5. Ceil rounding on `getWithdrawalShareOutput` (favors vault)

### Non-Functional
- Gas-efficient: immutable address caching, early zero returns
- Hard revert (R1) for pricing functions, graceful degradation (R2) for async TVL components
- NatSpec documentation with security assumptions

## Technical Design

### Architecture
- **yieldSourceAddress** = AsyncRedeemer (`0xE44b6...`)
- **Discovery chain**: asyncRedeemer.machine() -> Machine -> shareToken()/accountingToken()
- **All pricing**: routed to `IERC4626(MACHINE)`, not AsyncRedeemer
- **Balance**: `IERC20(DETH_TOKEN).balanceOf(owner)`
- **TVL**: held DETH value + pending redemption value

### Data Model
- Extend `IMachine` interface with: `convertToAssets`, `convertToShares`, `totalAssets`, `decimals`
- New contract: `DETHYieldSourceOracle` in `src/accounting/oracles/`

### API (IYieldSourceOracle methods)
| Method | Implementation |
|--------|---------------|
| `decimals()` | `IMachine(MACHINE).decimals()` |
| `getShareOutput()` | `IMachine(MACHINE).convertToShares(assetsIn)` |
| `getAssetOutput()` | `IMachine(MACHINE).convertToAssets(sharesIn)` |
| `getWithdrawalShareOutput()` | `Math.mulDiv(assetsIn, oneShare, assetsPerShare, Ceil)` |
| `getPricePerShare()` | `IMachine(MACHINE).convertToAssets(ONE_SHARE)` |
| `getBalanceOfOwner()` | `IERC20(DETH_TOKEN).balanceOf(owner)` |
| `getTVL()` | `IMachine(MACHINE).totalAssets()` |
| `getTVLByOwnerOfShares()` | `heldValue + pendingRedemptionValue` |

## Implementation Plan

### Phase 1: Verify On-Chain
- [ ] Fork-test Machine's ERC-4626 view functions
- [ ] Fork-test AsyncRedeemer's NFT enumeration
- [ ] Determine pending redemption tracking strategy

### Phase 2: Implement
- [ ] Extend IMachine interface with ERC-4626 view functions
- [ ] Create DETHYieldSourceOracle.sol
- [ ] Create unit tests with inline mocks
- [ ] Create fork integration tests

## Test Plan
- [ ] Unit tests: all 8 oracle functions with mock Machine/AsyncRedeemer
- [ ] Fuzz tests: rounding invariants, round-trip conservation, overflow
- [ ] Integration tests: oracle against mainnet Machine (fork)
- [ ] TVL preservation test: requestRedeem doesn't drop getTVLByOwnerOfShares

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Machine convertToAssets uses external pool prices | Oracle | Low | Critical | Use internal accounting only, monitor PPS | Makina 2026 - $4M |
| Donation attack inflates Machine totalAssets | Vault Accounting | Low | High | Rely on Machine's own mitigations + off-chain monitoring | Venus/wUSDM 2025 |
| BeaconProxy upgrade changes convertToAssets | Proxy/Upgrade | Low | High | Oracle uses immutable Machine, redeploy if changed | N/A |
| No NFT enumeration on AsyncRedeemer | Operational | Medium | Medium | Fall back to held-shares-only TVL | N/A |
| DETH decimal mismatch | Arithmetic | Low | Medium | Verify on mainnet fork before implementation | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Yield source address? | AsyncRedeemer | User |
| Include pending redemptions? | Yes | User |
| Machine ERC-4626 support? | Verify on-chain first | User |
| Oracle manipulation mitigations? | Trust Machine directly | User |
| Deposit side? | Both inflow and outflow | User |
| Reference pattern? | ERC7540 + Firelight + Yo oracles | User |

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
After approval, run: `/superform:work specs/deth-oracle/technical-spec.md`
