# PendlePTHook Security Vulnerability Research Report

## Table of Contents
1. [Relevant Vulnerability Patterns](#1-relevant-vulnerability-patterns)
2. [Exploit Precedents](#2-exploit-precedents)
3. [Attack Surface Map](#3-attack-surface-map)
4. [Recommended Security Patterns](#4-recommended-security-patterns)
5. [Protocol Interaction Risks](#5-protocol-interaction-risks)
6. [Testing Recommendations](#6-testing-recommendations)

---

## 1. Relevant Vulnerability Patterns

### 1.1 Malicious Market via `readTokens()` -- Untrusted Yield Source
**Risk Level: HIGH (mitigated by trust model)**

If a malicious market address is supplied, `readTokens()` can return attacker-controlled token addresses. The hook would then approve attacker-controlled tokens to the Pendle Router.

**Current mitigation**: Trust model relies on intent signer only submitting known-good markets. No on-chain whitelist.

### 1.2 Arbitrary External Router Calldata Injection
**Risk Level: HIGH (mitigated by trust model)**

`SwapData.extRouter` and `SwapData.extCalldata` are user-supplied and forwarded to Pendle Router V4. No whitelist of permitted `extRouter` addresses.

**Real-world parallel**: LI.FI Protocol lost $9M to similar unvalidated calldata; Silo Finance exploited via arbitrary call targets.

### 1.3 Precision Loss in Output Scaling
**Risk Level: LOW**

`HookDataUpdater.getUpdatedOutputAmount()` uses `1e5` precision. For extreme ratios or low-decimal tokens, `scaledOutputMin` could provide inadequate slippage protection.

### 1.4 Expired Market Boundary Conditions
**Risk Level: MEDIUM**

For PendlePTHook specifically: the hook derives operation from `yt.isExpired()` on-chain, which eliminates the selector mismatch risk present in PendleUnifiedHook. However, race conditions at the expiry boundary still apply.

---

## 2. Exploit Precedents

### 2.1 Penpie Hack (September 2024) -- $27M Lost
Reentrancy via malicious SY contract with permissionless market registration. **Not directly applicable** to PendlePTHook (no staking, delegates to Router, no permissionless registration). Key lesson: SY contracts can be malicious.

### 2.2 LI.FI Protocol -- $9M Lost
Unvalidated `callData` in swap logic. PendlePTHook's `SwapData.extCalldata` has same pattern, mitigated by intent signer trust + Pendle Router intermediary.

### 2.3 Silo Finance (June 2024) -- Arbitrary Call Target
Arbitrary target and calldata in swap logic. Same class as `extRouter` risk.

---

## 3. Attack Surface Map

### 3.1 Trust Boundary Analysis

| Component | Trusted? | Source of Trust | Risk if Compromised |
|---|---|---|---|
| `PENDLE_ROUTER_V4` | Yes (immutable) | Set at deployment | Complete fund loss |
| `yieldSource` (market) | Conditionally | Intent signer | Malicious token addresses from `readTokens()` |
| `SY` contract | Conditionally | Derived from market | Fake `isValidTokenOut()` responses |
| `PT` token | Conditionally | Derived from market | Approvals to attacker-controlled address |
| `YT` token | Conditionally | Derived from market | Approvals to attacker-controlled address |
| `extRouter` | Conditionally | Intent signer | Arbitrary external calls |
| `pendleSwap` | Conditionally | Intent signer | Intermediary swap manipulation |

### 3.2 Flash Loan Attack Paths
- **AMM Price Manipulation**: Flash-borrow to push PT price, front-run victim's buy. Mitigated by `outputMin`.
- **SY Exchange Rate Manipulation**: Flash-borrow to manipulate SY rate. Mitigated by `minTokenOut` in Router.
- **Balance Difference Manipulation**: Inject tokens during execution to inflate `outAmount`. Limited impact.

---

## 4. Recommended Security Patterns

### 4.1 Already Present in PendleUnifiedHook (carry forward)
- Approval hygiene: reset-set-cleanup pattern
- Transient storage execution context
- Minimum output enforcement (`outputMin != 0`)
- Gas griefing limits (MAX_FILLS=64, MAX_ITERATIONS=256, MAX_OPT_DATA_LENGTH=1024)

### 4.2 New for PendlePTHook
- **Expiry-aware routing on-chain**: PendlePTHook checks `yt.isExpired()` to route between sell/redeem, eliminating selector mismatch risk
- **No limit orders**: Removes entire attack surface around limit order validation
- **Simpler payload**: Fewer user-controlled fields = smaller attack surface

---

## 5. Protocol Interaction Risks

### 5.1 Fee-on-Transfer Tokens
Not explicitly handled. Balance-difference pattern captures actual output but `scaledOutputMin` may be set based on pre-fee amount.

### 5.2 `tokenMintSy` Validation Asymmetry
Buy path does not validate `tokenMintSy` against SY. Sell/redeem paths validate `tokenRedeemSy`. Fail-safe but asymmetric.

---

## 6. Testing Recommendations

1. **Fuzz tests for amount scaling** with extreme ratios and low-decimal tokens
2. **Expiry boundary tests**: swap intent at expiry-1 executed at expiry+1
3. **Mock market tests**: zero-address SY, permissive SY, reentrant PT
4. **External router abuse**: self-referential extRouter, token drain via extCalldata
5. **Balance difference edge cases**: inflation via callbacks, underflow on fee-on-transfer
6. **Token validation asymmetry**: invalid tokenMintSy (buy path) vs invalid tokenRedeemSy (sell/redeem path)

---

## Sources
- [Penpie Exploit Analysis - Halborn](https://www.halborn.com/blog/post/explained-the-penpie-hack-september-2024)
- [2024 Most Exploited DeFi Vulnerabilities - Three Sigma](https://threesigma.xyz/blog/exploit/2024-defi-exploits-top-vulnerabilities)
- [Pendle Router System - DeepWiki](https://deepwiki.com/pendle-finance/pendle-core-v2-public/3-router-system)
- [Pendle High Level Architecture - Official Docs](https://docs.pendle.finance/pendle-v2/Developers/HighLevelArchitecture)
- [Top 100 DeFi Hacks 2025 - Halborn](https://www.halborn.com/reports/top-100-defi-hacks-2025)
