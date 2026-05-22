# EVM Security Research: ForceDeallocateMorphoHook

## 1. Relevant Vulnerability Patterns

### 1.1 External Vault Calls to Arbitrary Adapters (HIGH)
- `forceDeallocate` calls `adapter.deallocate()` on an external contract
- Adapter interacts with downstream DeFi protocols that may have callbacks (ERC-777, ERC-1155)
- **Mitigated**: NONACCOUNTING hook doesn't read vault state post-call; BaseHook transient storage mutex prevents re-entry

### 1.2 Penalty/Fee Manipulation (MEDIUM)
- `forceDeallocatePenalty[adapter]` can change between signing and execution (curator timelock)
- Share price manipulation could distort actual penalty cost in shares
- `mulDivUp` rounding favors the vault
- **Mitigated**: `maxPenaltyBps` parameter creates hard upper bound

### 1.3 Permissionless forceDeallocate by External Actors (LOW)
- When penalty is 0, anyone can call `forceDeallocate` on the smart account's behalf
- Could disrupt allocation strategy before hook executes
- **Mitigated**: Cannot prevent; hook handles gracefully with deadline + maxPenaltyBps

## 2. Exploit Precedents

| Protocol | Date | Exploit | Loss | Relevance |
|----------|------|---------|------|-----------|
| Morpho App | Apr 2025 | Frontend vulnerability | $2.6M (recovered) | LOW — frontend, not contract |
| Morpho Blue | Oct 2024 | Oracle misconfiguration | $230K | MEDIUM — oracle pricing affects share value |
| Morpho V2 | Sherlock audit | Atomic share price manipulation | N/A (caught in audit) | HIGH — penalty shares could be distorted |
| BakerFi | May 2024 | Vault sandwich attack | N/A (Code4rena finding) | MEDIUM — MEV on vault operations |

## 3. Attack Surface Map

| Vector | Risk | Can Attack? | Mitigation |
|--------|------|-------------|------------|
| Force hook execution at bad time | LOW | NO — requires UserOp signature | Standard Superform validation |
| Front-run pending UserOp | MEDIUM | YES — mempool visible | deadline + maxPenaltyBps |
| Sandwich penalty cost | LOW | Theoretical | 2% cap + maxPenaltyBps |
| Manipulate adapter address | NONE | NO — signed in UserOp calldata | Signature validation |
| Compromised adapter | HIGH (vault-level) | YES — if adapter is malicious | Cannot mitigate at hook level |
| Vault paused | LOW | YES — execution reverts | Graceful revert |
| Calldata parsing bugs | HIGH | If present | Strict length validation + fuzz |

## 4. Recommended Security Patterns

1. **Deadline validation** in `_buildHookExecutions` (early revert, saves gas)
2. **maxPenaltyBps check** — track share balance in `_preExecute`, verify in `_postExecute`
3. **Zero address validation** for vault and adapter
4. **Data length validation** (minimum data length check)
5. **Assets > 0 validation**
6. **Hardcode onBehalf = msg.sender** (never configurable)

### Key Decision: Where to validate maxPenaltyBps

The penalty is only known after execution. Two approaches:

**Option A: Pre-check (estimate)**
- Query `forceDeallocatePenalty(adapter)` in `_buildHookExecutions`
- Compare against maxPenaltyBps
- Pro: Reverts before execution, saves gas
- Con: Penalty could change between build and execute (unlikely in same tx)

**Option B: Post-check (actual)**
- Track vault share balance in `_preExecute`
- Verify actual shares burned in `_postExecute`
- Pro: Checks actual penalty paid
- Con: Gas consumed before revert

**Recommendation**: Option A (pre-check) is sufficient since penalty is deterministic within a transaction and NONACCOUNTING hooks don't typically use pre/postExecute.

## 5. Risk Priority Matrix

| Risk | Severity | Likelihood | Priority |
|------|----------|------------|----------|
| Penalty exceeds expectation | HIGH | MEDIUM | P1 |
| Stale execution | MEDIUM | HIGH | P1 |
| Calldata parsing bugs | HIGH | LOW | P2 |
| Adapter compromise | HIGH | LOW | P2 (vault-level) |
| Share price manipulation | MEDIUM | LOW | P3 |
| Reentrancy via adapter | MEDIUM | LOW | P3 |
| External forceDeallocate | LOW | MEDIUM | P3 |

## 6. Testing Recommendations

### Fuzz Tests
1. Penalty boundary: `fuzz(assets, maxPenaltyBps)` — verify revert when exceeded
2. Deadline: `fuzz(deadline)` — verify revert when expired
3. Data encoding: `fuzz(bytes data)` — graceful revert on malformed input
4. Assets edge cases: `fuzz(assets)` — 0, 1, max, vault total

### Fork Test Scenarios
1. Happy path on mainnet fork with real Vault V2
2. Penalty exceeds maxPenaltyBps → revert
3. Expired deadline → revert
4. Unregistered adapter → vault-level revert
5. Zero assets → revert
6. Zero penalty adapter → no shares burned
7. Concurrent external forceDeallocate
8. Approve variant approval lifecycle

### Invariants
1. Penalty shares burned <= maxPenaltyBps tolerance
2. `block.timestamp > deadline` → always revert
3. `onBehalf` always equals executing smart account
4. No tokens leave smart account control

## Sources
- [Morpho V2 Security Considerations](https://docs.morpho.org/curate/concepts/security-considerations/)
- [ChainSecurity Morpho V2 Audit](https://www.chainsecurity.com/security-audit/morpho-vault-v2)
- [Sherlock Morpho V2 Case Study](https://sherlock.xyz/case-studies/morpho)
- [OWASP SC03: Timestamp Dependence](https://owasp.org/www-project-smart-contract-top-10/2023/en/src/SC03-timestamp-dependence.html)
