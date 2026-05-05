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

**Attack Vector:**
1. Attacker flash-loans large amount of assets
2. Deposits into the 7540 vault (gets shares)
3. Calls requestRedeem(shares) -- shares move from balanceOf to pendingRedeemRequest
4. Oracle is read (by keeper or on-chain consumer)
5. Claims or cancels to recoup position
6. Repays flash loan

**Analysis:**
- For standard 7540 vaults (Centrifuge V3), `requestRedeem` is NOT instant -- it goes through an epoch-based fulfillment cycle. The attacker cannot claim in the same transaction. The shares sit in pending state until the epoch is processed off-chain by Centrifuge.
- For Yo-style vaults with synchronous fulfillment, `requestRedeem` may burn shares and lock an asset amount immediately. However, this does not create a net TVL change if the oracle correctly sums held + pending.
- The keeper reads via `eth_call` (not a transaction), so it cannot be sandwiched within a flash loan transaction. The keeper observes state at a specific block.

**Key Insight:** The oracle is VIEW-ONLY. Flash loan attacks require state changes + oracle read + exploitation in a single tx. Since the keeper reads off-chain, the attacker would need to:
1. Manipulate state in block N
2. Hope the keeper reads at block N (timing attack)
3. State reverts or is claimed in block N+1

This is a **sandwich-the-keeper** attack, addressed in section 1C.

**Residual Risk:** If the oracle is ever consumed ON-CHAIN (not just by off-chain keeper), flash loan attacks become viable. The current architecture where PPS is pushed by keeper provides a natural defense.

### 1B. Donation Attack Affecting convertToAssets

**Severity: P1 High (vault-dependent)**

**Attack Vector:**
1. Attacker donates large amount of underlying assets directly to the 7540 vault
2. `convertToAssets()` returns inflated values (totalAssets increases, totalShares stays same)
3. Components 1 (held value) and 2 (pending redeem value) are both inflated
4. Keeper reads inflated TVL, computes higher PPS
5. Attacker withdraws at inflated PPS, extracting value from other depositors

**Analysis:**
- This is the classic ERC-4626 donation attack, extensively documented by [Euler Finance](https://www.euler.finance/blog/exchange-rate-manipulation-in-erc4626-vaults) and [OpenZeppelin](https://docs.openzeppelin.com/contracts/5.x/erc4626).
- Standard ERC-4626 vaults using `totalAssets = token.balanceOf(address(this))` are vulnerable. Vaults using internal balance tracking (like EVK) are NOT vulnerable.
- Centrifuge V3 vaults use price oracle updates pushed from Centrifuge Chain -- `convertToAssets` uses the pushed price, NOT a spot calculation from balances. This makes them **resistant** to donation attacks.
- Yo vaults implement rate-locking at requestRedeem time -- donations cannot retroactively change locked rates but CAN affect `convertToAssets` for the held component.

**Impact on 5 components:**
| Component | Affected by Donation? | Notes |
|-----------|----------------------|-------|
| held (convertToAssets(balanceOf)) | YES | Direct inflation of exchange rate |
| pendingRedeem (convertToAssets(pendingShares)) | YES | Same inflated rate applied to pending shares |
| claimableRedeem (maxWithdraw) | DEPENDS | Centrifuge: NO (locked redeemPrice). Vanilla: possibly |
| pendingDeposit (pendingDepositRequest) | NO | Returns assets, not share-converted value |
| claimableDeposit (claimableDepositRequest) | NO | Returns assets, not share-converted value |

**Mitigation:**
- Per-vault assessment at onboarding: verify internal balance tracking or oracle-based pricing
- Keeper-side: compare oracle reading against previous reading, reject PPS jumps > threshold
- Keeper-side: TWAP or median filter on PPS updates
- Follow-up: asymmetric pricing (bid/ask spread) as noted in interview-notes.md D6

### 1C. Sandwich Attack on Keeper's Oracle Read

**Severity: P2 Medium**

**Attack Vector:**
1. Attacker monitors keeper's `eth_call` pattern (block interval, gas price patterns)
2. In block N: attacker manipulates vault state (donation, requestRedeem, etc.)
3. Keeper reads at block N, gets manipulated values
4. Keeper pushes manipulated PPS on-chain
5. Attacker deposits at favorable PPS or withdraws at favorable PPS
6. In block N+k: state normalizes

**Analysis:**
- The keeper operates off-chain and reads at discrete block intervals. An attacker can predict these intervals if the keeper runs on a fixed schedule.
- The attack requires both mempool monitoring (to detect keeper transactions) and the ability to front-run/back-run.
- Unlike AMM sandwich attacks, this targets the keeper's READ, not a swap transaction.

**Mitigation:**
- Keeper should use private mempools (Flashbots Protect, MEV Blocker) for the PPS push transaction
- Keeper should implement PPS change rate limits (e.g., reject >5% change per update)
- Keeper should use a sliding window / TWAP approach rather than single-point reading
- Keeper should randomize read timing within a window

---

## 2. READ-ONLY REENTRANCY

**Severity: P3 Low (for standard 7540 implementations)**

### Background

Read-only reentrancy occurs when a view function is called during a callback in a state-mutating operation, and the view function returns stale or inconsistent values because the state mutation is incomplete. The canonical example is [Curve's get_virtual_price vulnerability](https://chainsecurity.com/curve-lp-oracle-manipulation-post-mortem/) where `get_virtual_price()` could be called mid-liquidity-removal via a raw ETH transfer callback, returning an inflated value because tokens were sent but LP supply not yet decremented.

### Attack Vector Against 7540 Oracle

For read-only reentrancy to work against this oracle, an attacker needs:
1. A state-mutating function on the 7540 vault that triggers a callback (e.g., ERC-777 token transfer, or native ETH receive)
2. During that callback, the oracle is read
3. The oracle reads inconsistent intermediate state

### Analysis per 7540 Vault Type

**Centrifuge V3:**
- Uses ERC-20 transfers (no callbacks unless using ERC-777 tokens, which Centrifuge does not)
- State transitions are epoch-based and controlled by cross-chain messages from Centrifuge Chain
- `fulfillRedeemRequest` is called by the Gateway/InvestmentManager, not by users
- No native ETH handling in vault contract
- **Verdict: NOT VULNERABLE** to read-only reentrancy

**Yo Vaults:**
- Uses standard ERC-20 (no native ETH callbacks in vault operations)
- `requestRedeem` burns shares and records pending in same transaction
- No external callbacks during state transitions
- **Verdict: LOW RISK** -- would need to examine actual implementation for any callback patterns

**Vanilla 7540 (Unknown Implementations):**
- If the vault uses WETH wrapping/unwrapping with native ETH, a fallback callback could create a reentrancy window
- If the vault's `requestRedeem` triggers any external call before updating `pendingRedeemRequest`, the oracle could read stale state
- **Verdict: VAULT-DEPENDENT** -- must be verified per vault at onboarding

### Specific Oracle View Functions

| Function | Reentrancy Risk | Reason |
|----------|----------------|--------|
| `balanceOf(owner)` | Low | Standard ERC-20, no intermediate states during transfers |
| `convertToAssets(shares)` | Low | Pure math on totalAssets/totalShares |
| `pendingRedeemRequest(rid, owner)` | Low | Read from storage slot, not derived from external state |
| `maxWithdraw(owner)` | Medium | May involve internal calculations, vault-dependent |
| `pendingDepositRequest(rid, owner)` | Low | Read from storage slot |
| `claimableDepositRequest(rid, owner)` | Low | Read from storage slot |

**Key Mitigation:** The oracle is called by an off-chain keeper via `eth_call`, which means it cannot be called mid-transaction during a reentrancy callback. The risk only applies if the oracle is consumed on-chain by another contract in the same transaction as a vault state change.

---

## 3. DOUBLE-COUNT ATTACKS

**Severity: P1 High (vault-compliance-dependent)**

### Attack Vectors

**3A. Held + Pending Double Count**

When `requestRedeem(shares)` is called:
- Well-behaved vault: `balanceOf` decreases by `shares`, `pendingRedeemRequest` increases by `shares`
- Buggy vault: `balanceOf` stays the same (shares not transferred/burned), `pendingRedeemRequest` increases

Oracle reads: `convertToAssets(balanceOf) + convertToAssets(pendingRedeemRequest)`
If shares are counted in BOTH, TVL is doubled.

**Per ERC-7540 spec (IERC7540Vault.sol lines 123-136):**
```
pendingRedeemRequest:
  - MUST NOT include any shares in Claimable state for redeem or withdraw.
  - MUST NOT show any variations depending on the caller.
```

The spec mandates mutual exclusivity between pending and claimable. However, the spec does NOT explicitly mandate that `balanceOf` must decrease when `pendingRedeemRequest` increases. Most implementations escrow shares (transfer from user to vault), which reduces `balanceOf`, but this is an implementation detail.

**3B. Pending + Claimable Double Count**

When epoch fulfillment occurs:
- Well-behaved vault: `pendingRedeemRequest` decreases, `maxWithdraw` increases
- Buggy vault: `pendingRedeemRequest` stays the same, `maxWithdraw` also increases

The ERC-7540 spec explicitly states: `pendingRedeemRequest MUST NOT include any shares in Claimable state`. If the vault violates this, double-counting occurs.

**3C. Claimable Redeem + Held Double Count**

After claiming (calling `withdraw` or `redeem`):
- Well-behaved vault: `maxWithdraw` decreases, assets transferred to user (reflected in SV idle balance, NOT in vault oracle)
- Buggy vault: `maxWithdraw` stays non-zero after claim

This is less concerning because claiming transfers assets out of the vault entirely.

**3D. Deposit-Side Double Count**

When `requestDeposit(assets)` is called:
- Assets are transferred from the user to the vault/escrow
- `pendingDepositRequest` increases
- User's idle balance of the asset decreases

The oracle reads `pendingDepositRequest` for component 4. If the SuperVault's idle asset balance (tracked separately by `totalAssets()`) doesn't decrease, this creates double-counting at the SuperVault level (not at the oracle level).

**This is the most subtle attack:** The oracle correctly reports the 5 components, but the KEEPER must ensure it doesn't double-count assets that are both in the SuperVault's idle balance AND in `pendingDepositRequest`.

**Centrifuge-Specific Analysis:**
From `IInvestmentManager.sol`:
- `fulfillRedeemRequest` burns shares and sets `maxWithdraw`. It also decrements `pendingRedeemRequest` by the fulfilled amount.
- Partial fulfillment is supported: `pendingRedeemRequest` is decremented by the fulfilled portion only.
- The `InvestmentState` struct shows `pendingRedeemRequest` and `maxWithdraw` are separate fields, updated independently by fulfillment messages from Centrifuge Chain.

**Risk:** If two Centrifuge messages (`fulfillRedeemRequest` + `fulfillCancelDepositRequest`) arrive out of order, there is a transient window where bookkeeping may be inconsistent. However, this is a Centrifuge architectural property and happens at epoch boundaries, not exploitable by an attacker.

**Mitigation:**
- INV-4 invariant test (from interview-notes.md): `held + pending + claimable pools mutually exclusive`
- Per-vault validation at onboarding: verify `requestRedeem` decrements `balanceOf`
- Per-vault validation: verify `fulfillRedeemRequest` decrements `pendingRedeemRequest` atomically with `maxWithdraw` increase
- Keeper-side: sanity check that sum of 5 components does not exceed vault's `totalAssets()`

---

## 4. VAULT NON-COMPLIANCE RISKS

**Severity: P1 High (for the overall system; mitigated by per-vault onboarding)**

### 4A. pendingRedeemRequest Not Decremented on Fulfillment

**Impact:** Double-counting between pending and claimable. TVL overstated. PPS inflated. Depositors enter at inflated PPS, existing holders diluted when PPS corrects.

**Real-World Precedent:** The Centrifuge `IInvestmentManager` documentation explicitly acknowledges that `fulfillment` and actual asset amounts may differ due to precision loss, and uses a separate `fulfillment` parameter to avoid dust in `pendingDepositRequest` (see `fulfillCancelDepositRequest` comments in `IInvestmentManager.sol` lines 230-268).

**Detection:** Compare `pendingRedeemRequest(t0)` vs `pendingRedeemRequest(t1)` after fulfillment. If unchanged while `maxWithdraw` increased, the vault is non-compliant.

### 4B. maxWithdraw Returns Stale/Incorrect Values

**Impact:** Claimable component is wrong. Could be over- or under-stated.

**Specific Risks:**
- Some vaults return 0 for `maxWithdraw` if the user hasn't explicitly claimed, even though assets are available
- Some vaults return the TOTAL position value, not just the claimable portion
- Centrifuge V3 stores `maxWithdraw` as `uint128` -- amounts exceeding 2^128 are truncated

**Detection:** After fulfillment, verify `maxWithdraw > 0` and `maxWithdraw <= totalAssets`.

### 4C. pendingDepositRequest Returns Shares Instead of Assets

**Impact:** Massive TVL miscalculation. If the vault returns shares (denominated in share decimals/value) instead of assets, and the oracle treats it as assets, the value could be orders of magnitude wrong.

**Per ERC-7540 spec (IERC7540Vault.sol lines 57-69):**
```
pendingDepositRequest:
  returns (uint256 pendingAssets)
```
The spec clearly defines the return as assets. But a non-compliant vault could return anything.

**Detection:** Sanity check at onboarding: `pendingDepositRequest` value should be in the same order of magnitude as the deposit amount (in asset decimals).

### 4D. Selective Reversion on Some Methods

**Impact:** If the oracle uses try/catch (as designed per D3 hybrid error handling), a selectively reverting method causes that component to be treated as 0. An attacker who can force a specific method to revert can understate TVL.

**Examples:**
- Vault pauses `pendingRedeemRequest` but not `balanceOf` -- oracle misses pending redemptions
- Vault has a gas-dependent computation in `maxWithdraw` that OOGs at certain state sizes

**This is addressed in detail in Section 5.**

### 4E. Decimal Mismatch Between Components

**Impact:** If `pendingDepositRequest` returns assets in 6 decimals but the oracle assumes 18, the component is understated by 10^12.

**Mitigation:** All 5 components should be in the vault's asset denomination. The oracle should validate decimal consistency at deployment/configuration time.

---

## 5. TRY/CATCH SECURITY

**Severity: P2 Medium**

### Design Context

Per design decision D3 (interview-notes.md):
- `getPricePerShare()` hard reverts (no try/catch) -- R1 pattern
- `getTVLByOwnerOfShares()` wraps async calls in try/catch -- R2 pattern
- On catch, the component is treated as 0 (graceful degradation)

### 5A. Forced Revert to Undercount TVL

**Attack Vector:**
1. Attacker causes `pendingRedeemRequest` to revert (e.g., by manipulating vault state to trigger an overflow check, or by griefing the vault into a paused state)
2. Oracle's try/catch catches the revert, treats pending redeem as 0
3. TVL is understated by the pending redeem amount
4. PPS drops
5. Attacker deposits at deflated PPS
6. When the revert condition clears, PPS rebounds
7. Attacker withdraws at higher PPS, profiting

**Analysis:**
The ERC-7540 spec states for `pendingRedeemRequest`:
```
MUST NOT revert unless due to integer overflow caused by an unreasonably large input.
```

If the vault is spec-compliant, `pendingRedeemRequest` should NEVER revert under normal conditions. However:
- Non-compliant vaults may revert (e.g., when paused, when requestId is invalid, etc.)
- Gas griefing: an attacker could potentially inflate the gas cost of the view function to cause OOG within the try/catch's gas allocation

### 5B. Solidity Try/Catch Limitations

Per [RareSkills research](https://rareskills.io/post/try-catch-solidity):
- `try/catch` only catches errors from external calls
- If the external call runs out of gas, the entire transaction reverts (not caught by try/catch) unless gas is explicitly limited
- Solidity's `try/catch` does NOT catch all revert types in all versions

**Specific Risk for the Oracle:**
```solidity
try vault.pendingRedeemRequest(REQUEST_ID, owner) returns (uint256 pending) {
    pendingValue = vault.convertToAssets(pending);
} catch {
    // pendingValue stays 0
}
```

If `pendingRedeemRequest` succeeds but `convertToAssets` within the try block reverts, the ENTIRE try block reverts and the catch handles it. This is correct behavior but means a vault where `convertToAssets` reverts for certain inputs would cause the pending component to be lost.

### 5C. Gas-Limited External Calls

**Mitigation Pattern:** Use a fixed gas limit for try/catch external calls to prevent OOG from propagating:
```solidity
try vault.pendingRedeemRequest{gas: 100_000}(REQUEST_ID, owner) returns (uint256 pending) {
    ...
}
```

**Risk:** If the vault legitimately needs more gas (e.g., complex state lookups), the call fails. This is a tradeoff between safety and compatibility.

**Recommendation:** Do NOT use gas-limited calls. Instead, rely on:
1. Per-vault validation at onboarding (verify none of the 5 functions revert)
2. Keeper-side monitoring: alert if any component suddenly drops to 0
3. PPS rate-limiting: reject PPS updates where any component drops >X% in a single update

---

## 6. PPS MANIPULATION CHAIN -- END-TO-END ATTACK ANALYSIS

**Severity: P1 High (composite risk)**

### Full Chain

```
[1] Underlying Vault State
      |
      v
[2] Oracle View Functions (5 components)
      |
      v
[3] Keeper eth_call (reads oracle)
      |
      v
[4] Keeper Computation (PPS = totalTVL / totalShares)
      |
      v
[5] SuperVaultAggregator (PPS pushed on-chain)
      |
      v
[6] SuperVault (uses PPS for deposit/withdrawal pricing)
```

### Attack Surfaces Per Stage

**Stage 1 -- Underlying Vault State:**
- Donation attacks inflate `convertToAssets` (P1)
- Flash loan + deposit/requestRedeem creates transient state (P2)
- Vault admin actions (pause, rate update) change state unpredictably (P3)

**Stage 2 -- Oracle View Functions:**
- try/catch forced revert undercounts components (P2)
- Non-compliant vault returns wrong values (P1, mitigated by onboarding)
- Read-only reentrancy if oracle consumed on-chain (P3)
- Double-counting if vault doesn't decrement correctly (P1)

**Stage 3 -- Keeper eth_call:**
- Sandwich the keeper: manipulate state in block N, keeper reads at block N (P2)
- Block stuffing to delay keeper reads (P3)
- RPC manipulation if keeper uses untrusted RPC endpoint (P2)

**Stage 4 -- Keeper Computation:**
- Integer overflow/underflow in PPS calculation (P3, use SafeMath)
- Division by zero if totalShares = 0 (P3, handle edge case)
- Stale component data if some components are cached (P3)

**Stage 5 -- SuperVaultAggregator Push:**
- Front-running the PPS push transaction (P2)
- Keeper key compromise allows arbitrary PPS (P0 if no bounds checking)
- Transaction replay if no nonce/timestamp protection (P2)

**Stage 6 -- SuperVault Pricing:**
- Users deposit at manipulated PPS, extract value on correction (P1)
- Withdrawal at manipulated PPS, extract more assets than entitled (P1)
- MEV bots front-run PPS update + deposit/withdraw in same block (P2)

### Highest-Impact Composite Attack

**Scenario: Keeper Key Compromise + PPS Push**
- **Severity: P0 Critical**
- If the keeper's private key is compromised, an attacker can push arbitrary PPS values
- Must have on-chain bounds checking: reject PPS changes > X% from previous
- Must have multi-keeper quorum or timelock on PPS updates

**Scenario: Donation + Keeper Sandwich**
- **Severity: P1 High**
- Attacker donates to underlying vault in block N
- Keeper reads at block N, sees inflated convertToAssets
- Keeper pushes inflated PPS
- Attacker deposits into SuperVault at inflated PPS (gets fewer shares than they should)
- WAIT -- this hurts the attacker. The attacker gets fewer shares at high PPS.
- **Correction:** The attacker should WITHDRAW at inflated PPS to extract more assets.
- But to withdraw, attacker needs existing shares deposited at a LOWER PPS.
- **Revised attack:** Attacker deposits at normal PPS, then donates to inflate PPS, then withdraws at inflated PPS.
- Net profit = (donation cost) vs (extra assets extracted from withdrawal at inflated PPS)
- Profitable only if extracted value > donation cost + gas

**Scenario: Forced Revert + Deposit at Deflated PPS**
- **Severity: P2 Medium**
- Attacker forces `pendingRedeemRequest` to revert (vault grief)
- Oracle reports lower TVL (missing pending component)
- Keeper pushes lower PPS
- Attacker deposits at lower PPS (gets more shares)
- Revert condition clears, PPS rebounds
- Attacker withdraws at higher PPS

---

## 7. HISTORICAL EXPLOITS

### 7A. Euler Finance (March 2023) -- $197M

**Relevance: MEDIUM**

- The actual Euler exploit was NOT an oracle manipulation -- it was a donation + self-collateral + liquidation penalty abuse
- However, Euler's subsequent [research on ERC-4626 exchange rate manipulation](https://www.euler.finance/blog/exchange-rate-manipulation-in-erc4626-vaults) is directly relevant
- Key finding: most ERC-4626 vaults don't implement defenses against donation-based exchange rate manipulation
- Euler Vault Kit (EVK) introduced internal balance tracking as mitigation
- **Applicable Lesson:** Vaults that use `token.balanceOf(address(this))` for `totalAssets` are vulnerable to donation attacks that inflate `convertToAssets`

### 7B. Curve / dForce Read-Only Reentrancy (Feb-July 2023)

**Relevance: HIGH**

- [dForce lost $3.7M](https://www.certik.com/resources/blog/curve-conundrum-the-dforce-attack-via-a-read-only-reentrancy-vector-exploit) through Curve's `get_virtual_price` read-only reentrancy
- [ChainSecurity documented](https://chainsecurity.com/curve-lp-oracle-manipulation-post-mortem/) that during `remove_liquidity`, a raw ETH transfer triggers a fallback, during which `get_virtual_price()` returns an inflated value (tokens sent out but LP supply not yet decremented)
- [Balancer vault](https://github.com/sherlock-audit/2023-04-blueberry-judging/issues/141) had similar read-only reentrancy where token balances and BPT supply could be out of sync during reentrancy
- **Applicable Lesson:** Any oracle that reads from a contract during a callback risks getting inconsistent state. For the 7540 oracle, this risk is LOW because:
  1. 7540 vaults use ERC-20 tokens (no native ETH callbacks)
  2. The oracle is read by an off-chain keeper (not during a vault callback)
  3. BUT: if the oracle is ever consumed on-chain by another protocol, this risk increases

### 7C. ERC-7540 Specific Exploits

**Relevance: DIRECT**

- No major publicly disclosed exploits specifically targeting ERC-7540 vaults as of April 2026
- The [Centrifuge Code4rena audit (Sep 2023)](https://code4rena.com/reports/2023-09-centrifuge) found 8 Medium severity issues, focused on:
  - `requestRedeemWithPermit` front-running
  - Decimal precision issues between currency and tranche token amounts in `depositPrice` and `redeemPrice`
  - Message ordering issues between `fulfillRedeemRequest` and `fulfillCancelDepositRequest`
- [Zealynx Security analysis](https://www.zealynx.io/blogs/erc-7540-asynchronous-settlement) identified:
  - Under-collateralization risk during async settlement
  - DoS when vault lacks on-chain liquidity
  - Settlement failures leaving shares locked
  - "Dust" attacks stalling fulfillment queues

### 7D. Centrifuge-Specific Considerations

**Relevance: DIRECT**

- Centrifuge uses epoch-based fulfillment with prices computed on Centrifuge Chain
- `redeemPrice` is a weighted average locked per-user at fulfillment time
- `maxWithdraw` returns the exact locked asset amount for a user based on their `redeemPrice`
- If `convertToAssets(claimableRedeemRequest)` is used instead of `maxWithdraw`, the WRONG price is applied (global current rate vs. user's locked redeemPrice)
- **This is why design decision D1 uses maxWithdraw** -- validated by interview-notes.md
- The Centrifuge `InvestmentState` struct uses `uint128` for `maxWithdraw` -- amounts exceeding `type(uint128).max` (~3.4e38) would overflow, though this is practically unreachable for asset amounts

### 7E. $700K Oracle Manipulation (2024-2025)

**Relevance: HIGH**

- [The Block reported](https://www.theblock.co/post/348785/analysis-of-700k-oracle-manipulation-exploit-highlights-vulnerabilities-in-defi-vaults) a $700K exploit in 2025 targeting DeFi vault oracles
- Attack vector: exchange rate manipulation in ERC-4626 style vaults
- Reinforces that donation-based exchange rate attacks remain a live threat

---

## 8. ERC-4626 ORACLE PRECEDENTS

### 8A. Share Inflation / First Depositor Attack

**Severity: P2 Medium (for 7540 oracle context)**

**Attack Mechanics:**
1. First depositor deposits 1 wei of assets, receives 1 share
2. Donates large amount (e.g., 1e18) of assets directly to vault
3. `convertToAssets(1 share)` now returns ~1e18
4. Next depositor deposits < 1e18 assets, receives 0 shares due to rounding
5. First depositor redeems, taking both deposits

**Applicability to 7540 Oracle:**
- The oracle reads `convertToAssets`, which is directly affected by this attack
- If the underlying 7540 vault is vulnerable to share inflation, the oracle will report inflated per-share values
- Most modern vaults implement [OpenZeppelin's virtual shares/assets defense](https://docs.openzeppelin.com/contracts/5.x/erc4626) or Euler's internal balance tracking

**Mitigation:** Per-vault assessment at onboarding. Verify the vault uses virtual shares or internal balance tracking.

### 8B. convertToAssets Manipulation via Donation

**Severity: P1 High (vault-dependent)**

As covered in Section 1B. The core issue:
```
convertToAssets(shares) = shares * totalAssets / totalShares
```

If `totalAssets` can be inflated via donation (direct ERC-20 transfer to vault), `convertToAssets` returns inflated values. This affects components 1 and 2 of the oracle.

**Defense mechanisms in the wild:**
| Defense | Effectiveness | Used By |
|---------|--------------|---------|
| Virtual shares/assets offset | High | OpenZeppelin 5.x ERC4626 |
| Internal balance tracking | High | Euler Vault Kit |
| Price oracle (not spot calc) | High | Centrifuge V3 |
| Deposit cap / minimum deposit | Medium | Various |
| Snapshot-based pricing | High | Some RWA vaults |

### 8C. Exchange Rate Rounding Attacks

**Severity: P3 Low**

- `convertToAssets` uses integer division, which truncates
- For small share amounts, rounding can cause significant relative error
- Not exploitable in isolation but compounds with other attack vectors
- The oracle uses `convertToAssets(10^decimals)` for PPS, which minimizes rounding error for the PPS component
- Individual owner TVL calculations use actual share balances, where rounding is proportionally smaller for larger positions

---

## SEVERITY SUMMARY

| ID | Vulnerability | Severity | Likelihood | Impact | Mitigated By |
|----|--------------|----------|------------|--------|-------------|
| 1B | Donation attack on convertToAssets | **P1 High** | Medium | High | Per-vault onboarding, keeper rate limits |
| 3A | Held + Pending double count (non-compliant vault) | **P1 High** | Low | Critical | INV-4 invariant, per-vault validation |
| 3B | Pending + Claimable double count | **P1 High** | Low | Critical | ERC-7540 spec compliance, per-vault validation |
| 4A | pendingRedeemRequest not decremented | **P1 High** | Low | High | Per-vault validation at onboarding |
| 4B | maxWithdraw returns wrong values | **P1 High** | Low | High | Per-vault validation at onboarding |
| 4C | pendingDepositRequest returns shares not assets | **P1 High** | Low | Critical | Per-vault validation at onboarding |
| 6-5 | Keeper key compromise | **P0 Critical** | Very Low | Critical | On-chain PPS bounds, multi-sig, timelock |
| 1C | Sandwich attack on keeper read | **P2 Medium** | Medium | Medium | Private mempool, PPS rate limits, TWAP |
| 1A | Flash loan + async state manipulation | **P2 Medium** | Low | Medium | Off-chain keeper architecture |
| 4D | Selective reversion forcing try/catch | **P2 Medium** | Low | Medium | Keeper monitoring, PPS rate limits |
| 5A | Forced revert to undercount TVL | **P2 Medium** | Low | Medium | ERC-7540 MUST NOT revert spec |
| 6-Front | Front-running PPS push transaction | **P2 Medium** | Medium | Medium | Private mempool, MEV protection |
| 3D | Deposit-side double count at SV level | **P2 Medium** | Medium | Medium | Keeper must subtract idle from pending |
| 2 | Read-only reentrancy | **P3 Low** | Very Low | High | Off-chain keeper, ERC-20 only tokens |
| 5C | Gas griefing on try/catch | **P3 Low** | Very Low | Medium | No gas limits, keeper monitoring |
| 8A | Share inflation / first depositor | **P2 Medium** | Low | High | Per-vault onboarding validation |
| 8C | Exchange rate rounding | **P3 Low** | Very Low | Low | Use 10^decimals for PPS calc |

---

## RECOMMENDATIONS

### Must Have (for oracle contract)
1. **Hard revert on getPricePerShare** -- never return 0 or stale PPS (already decided in D3)
2. **Try/catch on async components** with individual component degradation (already decided in D3)
3. **getAsyncStateBreakdown** returning all 5 components for monitoring instrumentation
4. **REQUEST_ID as immutable constructor param** (already decided in D2)
5. **Use maxWithdraw for claimable, not convertToAssets(claimableShares)** (already decided in D1)

### Must Have (for keeper)
6. **PPS rate limiting**: reject updates where PPS changes > configurable threshold (e.g., 5%) per update
7. **Component monitoring**: alert if any component drops to 0 unexpectedly
8. **Private mempool** for PPS push transactions (Flashbots Protect or equivalent)
9. **On-chain PPS bounds checking** in SuperVaultAggregator: reject pushes outside [prevPPS * 0.95, prevPPS * 1.05]

### Must Have (for vault onboarding)
10. **Validate mutual exclusivity**: verify requestRedeem decrements balanceOf
11. **Validate fulfillment atomicity**: verify epoch fulfillment decrements pendingRedeemRequest
12. **Validate return types**: verify pendingDepositRequest returns assets, not shares
13. **Validate non-reversion**: verify all 5 view functions don't revert in normal and edge-case states
14. **Validate donation resistance**: verify convertToAssets is not manipulable via direct token transfer

### Recommended (defense in depth)
15. **Keeper TWAP/median filter**: use rolling average of last N readings instead of single point
16. **Asymmetric pricing (bid/ask spread)**: apply haircut on deposit PPS, premium on withdrawal PPS (deferred per D6)
17. **Multi-keeper quorum**: require 2+ keepers to agree on PPS before pushing
18. **Historical PPS tracking**: maintain on-chain history for dispute resolution

### Optional (future hardening)
19. **On-chain oracle fallback**: if keeper is unavailable, allow governance to push PPS with timelock
20. **Cross-reference totalAssets**: verify sum of 5 components <= vault.totalAssets() for sanity
21. **ERC-7540 compliance test suite**: automated test battery run at vault onboarding

---

## SOURCES

- [Euler Finance: Exchange Rate Manipulation in ERC4626 Vaults](https://www.euler.finance/blog/exchange-rate-manipulation-in-erc4626-vaults)
- [Euler Docs: Donation Attacks](https://docs.euler.finance/security/attack-vectors/donation-attacks/)
- [OpenZeppelin: A Novel Defense Against ERC4626 Inflation Attacks](https://www.openzeppelin.com/news/a-novel-defense-against-erc4626-inflation-attacks)
- [OpenZeppelin: ERC-4626 Documentation](https://docs.openzeppelin.com/contracts/5.x/erc4626)
- [ChainSecurity: Curve LP Oracle Manipulation Post Mortem](https://chainsecurity.com/curve-lp-oracle-manipulation-post-mortem/)
- [CertiK: Curve Conundrum / dForce Read-Only Reentrancy](https://www.certik.com/resources/blog/curve-conundrum-the-dforce-attack-via-a-read-only-reentrancy-vector-exploit)
- [Sherlock: Balancer Oracle Read-Only Reentrancy](https://github.com/sherlock-audit/2023-04-blueberry-judging/issues/141)
- [Code4rena: Centrifuge Findings & Analysis Report (2023)](https://code4rena.com/reports/2023-09-centrifuge)
- [Cantina: Centrifuge Protocol Security Audit Summary](https://cantina.xyz/portfolio/8c15e83a-08fc-48b9-8cc1-4f9ca76bb064)
- [ERC-7540 Specification](https://eips.ethereum.org/EIPS/eip-7540)
- [Zealynx: ERC-7540 vs ERC-4626 Async Settlement](https://www.zealynx.io/blogs/erc-7540-asynchronous-settlement)
- [RareSkills: Try Catch in Solidity](https://rareskills.io/post/try-catch-solidity)
- [The Block: $700K Oracle Manipulation Exploit](https://www.theblock.co/post/348785/analysis-of-700k-oracle-manipulation-exploit-highlights-vulnerabilities-in-defi-vaults)
- [Halborn: Oracle Manipulation Attacks in DeFi](https://www.halborn.com/blog/post/what-are-price-oracle-manipulation-attacks-in-defi)
- [OpenZeppelin: ERC-4626 Tokens in DeFi Exchange Rate Manipulation Risks](https://www.openzeppelin.com/news/erc-4626-tokens-in-defi-exchange-rate-manipulation-risks)
- [GitHub: ERC-7540 ERCs Specification](https://github.com/ethereum/ERCs/blob/master/ERCS/erc-7540.md)
- [OpenZeppelin: Smart Contract Security Guidelines - Dangers of Price Oracles](https://blog.openzeppelin.com/secure-smart-contract-guidelines-the-dangers-of-price-oracles/)
- [Centrifuge: Liquidity Pools GitHub](https://github.com/centrifuge/liquidity-pools)
- [DEV.to: How to Detect ERC4626 First Depositor Attack](https://dev.to/ohmygod/how-to-detect-erc4626-first-depositor-attack-a-security-researchers-guide-19bo)
