# ERC-7540 Yield Source Oracle -- Security Vulnerability Research

## Date: 2026-04-29
## Status: Complete
## Scope: VIEW-ONLY oracle reading 5 TVL components from async 7540 vaults

---

## Architecture Under Analysis

```
Oracle (view-only, on-chain)
  --> reads 5 components from 7540 vault:
      1. convertToAssets(balanceOf(owner))           -- held shares value
      2. convertToAssets(pendingRedeemRequest(rid,o)) -- pending redeem value
      3. maxWithdraw(owner)                          -- claimable redeem value
      4. pendingDepositRequest(rid, owner)            -- pending deposit value
      5. claimableDepositRequest(rid, owner)          -- claimable deposit value

Keeper (off-chain)
  --> reads oracle via eth_call
  --> computes PPS = totalTVL / totalShares
  --> pushes PPS on-chain via SuperVaultAggregator

SuperVault
  --> uses pushed PPS for deposit/withdrawal pricing
```

---

## 1. ORACLE MANIPULATION VIA ASYNC STATE

### 1A. Flash Loan + requestRedeem + Read Oracle + Claim in Same TX

**Severity: P2 Medium (mitigated by architecture)**

- For standard 7540 vaults (Centrifuge V3), `requestRedeem` is NOT instant -- epoch-based fulfillment cycle
- Keeper reads via `eth_call` (off-chain), cannot be sandwiched within a flash loan transaction
- **Residual Risk:** If oracle ever consumed ON-CHAIN, flash loan attacks become viable

### 1B. Donation Attack Affecting convertToAssets

**Severity: P1 High (vault-dependent)**

- Classic ERC-4626 donation attack inflating `convertToAssets`
- Centrifuge V3 uses pushed prices (resistant). Yo vaults lock rates at request time.
- Components 1 (held) and 2 (pending redeem) affected. Components 3-5 NOT affected.
- **Mitigation:** Per-vault onboarding validation, keeper rate limits, TWAP

### 1C. Sandwich Attack on Keeper's Oracle Read

**Severity: P2 Medium**

- Attacker predicts keeper read timing, manipulates state in target block
- **Mitigation:** Private mempools, PPS rate limits, randomized timing

---

## 2. READ-ONLY REENTRANCY

**Severity: P3 Low (for standard 7540 implementations)**

- Centrifuge V3: NOT VULNERABLE (ERC-20 only, epoch-based, no user-triggered callbacks)
- Yo Vaults: LOW RISK (standard ERC-20, no native ETH)
- Vanilla 7540: VAULT-DEPENDENT (must verify at onboarding)
- Key defense: oracle read by off-chain keeper, not during on-chain callbacks

---

## 3. DOUBLE-COUNT ATTACKS

**Severity: P1 High (vault-compliance-dependent)**

- **3A. Held + Pending**: If `requestRedeem` doesn't decrement `balanceOf`, both are counted
- **3B. Pending + Claimable**: If fulfillment doesn't decrement `pendingRedeemRequest`, both counted
- **3C. Claimable + Held**: Less concerning — claiming transfers assets out entirely
- **3D. Deposit-Side**: Most subtle — keeper must not double-count idle balance AND `pendingDepositRequest`
- ERC-7540 spec mandates mutual exclusivity but non-compliant vaults exist
- **Mitigation:** INV-4 invariant test, per-vault validation at onboarding

---

## 4. VAULT NON-COMPLIANCE RISKS

**Severity: P1 High (mitigated by per-vault onboarding)**

- **4A.** `pendingRedeemRequest` not decremented on fulfillment → double-count
- **4B.** `maxWithdraw` returns stale/incorrect values
- **4C.** `pendingDepositRequest` returns shares instead of assets
- **4D.** Selective reversion forcing try/catch → component drops to 0
- **4E.** Decimal mismatch between components

---

## 5. TRY/CATCH SECURITY

**Severity: P2 Medium**

- **5A.** Forced revert to undercount TVL (spec says MUST NOT revert, but non-compliant vaults may)
- **5B.** If `pendingRedeemRequest` succeeds but `convertToAssets` reverts in try block → entire component lost
- **5C.** Gas griefing — recommend NO gas-limited calls, rely on per-vault validation + keeper monitoring
- **Recommendation:** Don't use gas limits. Rely on onboarding validation + keeper monitoring + PPS rate limits.

---

## 6. PPS MANIPULATION CHAIN

**Severity: P1 High (composite)**

Full attack chain: Vault State → Oracle → Keeper → Aggregator → SuperVault

### Highest-Impact Scenarios

| Scenario | Severity | Attack |
|----------|----------|--------|
| Keeper key compromise | **P0 Critical** | Push arbitrary PPS — needs on-chain bounds + multi-sig |
| Donation + keeper sandwich | **P1 High** | Inflate convertToAssets, withdraw at inflated PPS |
| Forced revert + deflated deposit | **P2 Medium** | Force component revert, deposit at lower PPS |

---

## 7. HISTORICAL EXPLOITS

- **Euler Finance ($197M, 2023)**: Exchange rate manipulation research directly applicable
- **Curve/dForce ($3.7M, 2023)**: Read-only reentrancy via `get_virtual_price` — LOW risk for 7540
- **$700K Oracle Manipulation (2025)**: ERC-4626 vault oracle exchange rate attack — LIVE threat
- **Centrifuge Code4rena (2023)**: 8 Medium findings — decimal precision, message ordering
- **No major ERC-7540 specific exploits** disclosed as of April 2026

---

## 8. SEVERITY SUMMARY

| ID | Vulnerability | Severity | Mitigated By |
|----|--------------|----------|-------------|
| 1B | Donation attack on convertToAssets | **P1 High** | Per-vault onboarding, keeper rate limits |
| 3A-3B | Double count (non-compliant vault) | **P1 High** | INV-4 invariant, per-vault validation |
| 4A-4C | Vault non-compliance | **P1 High** | Per-vault validation at onboarding |
| 6-5 | Keeper key compromise | **P0 Critical** | On-chain PPS bounds, multi-sig, timelock |
| 1C | Sandwich keeper read | **P2 Medium** | Private mempool, PPS rate limits |
| 5A | Forced revert undercount | **P2 Medium** | Keeper monitoring, PPS rate limits |
| 2 | Read-only reentrancy | **P3 Low** | Off-chain keeper, ERC-20 only |

---

## RECOMMENDATIONS

### Must Have (oracle contract): Hard revert on PPS, try/catch on async, getAsyncStateBreakdown, REQUEST_ID immutable, maxWithdraw for claimable
### Must Have (keeper): PPS rate limiting, component monitoring, private mempool, on-chain PPS bounds
### Must Have (onboarding): Validate mutual exclusivity, fulfillment atomicity, return types, non-reversion, donation resistance
### Recommended: Keeper TWAP, asymmetric pricing (deferred), multi-keeper quorum
