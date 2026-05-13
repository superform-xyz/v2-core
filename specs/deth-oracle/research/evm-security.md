# EVM Security Research: DETHYieldSourceOracle

## Attack Surface Map

### A. Oracle Price Manipulation
- A1. Flash loan manipulation of Machine's underlying positions (CRITICAL)
- A2. Donation attack on Machine vault inflating totalAssets (HIGH)
- A3. Reentrancy during price query if convertToAssets makes external calls (MEDIUM)
- A4. Stale price during async window (MEDIUM)

### B. Async Redemption State Tracking
- B1. NFT receipt double-counting in TVL (HIGH)
- B2. Phantom NFT receipts after claim (MEDIUM)
- B3. Cross-account NFT attribution (MEDIUM)
- B4. Unclaimed receipt accumulation requiring bounded iteration (LOW)

### C. External Contract Trust
- C1. AsyncRedeemer.machine() returning malicious address (HIGH) - mitigated by immutable constructor
- C2. Machine BeaconProxy upgrade changing convertToAssets semantics (HIGH)
- C3. Whitelisting dependency (MEDIUM)

### D. Decimal and Arithmetic
- D1. DETH vs WETH decimal precision (HIGH if mismatch)
- D2. Division-before-multiplication rounding (MEDIUM)
- D3. Zero totalSupply edge case (MEDIUM)

## Exploit Precedent

| Protocol | Date | Loss | Root Cause | Relevance |
|----------|------|------|-----------|-----------|
| Makina Finance | Jan 2026 | $4M | Oracle used Curve spot prices for AUM | Same Machine vault family |
| Venus/wUSDM | Feb 2025 | 86 WETH | ERC-4626 donation-based convertToAssets manipulation | Same convertToAssets pattern |
| ERC-4626 First Depositor | Ongoing | Various | Zero-share inflation attack | If Machine lacks virtual shares |

## Recommended Mitigations
1. Trust Machine's convertToAssets directly (not external pool prices)
2. Immutable Machine address in constructor (prevent redirection attacks)
3. Hard revert on zero PPS (R1 policy)
4. Graceful degradation for async TVL components (R2 policy)
5. Bounded iteration for NFT enumeration
6. Document Machine's pricing assumptions in NatSpec
