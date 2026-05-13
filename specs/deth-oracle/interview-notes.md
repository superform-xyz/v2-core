# DETH Oracle Interview Notes

## Date: 2026-05-12

## Feature Summary
Create a custom yield source oracle for Dialectic's DETH (Machine) vault, similar to the Firelight and ERC-7540 oracle patterns. The oracle enables Superform's accounting system (SuperLedger) to calculate PPS, fees, and TVL for the DETH async redemption flow.

## Interview Transcript

### Q1: Yield Source Address
**Q:** What should the oracle's yieldSourceAddress point to?
**A:** **AsyncRedeemer** (`0xE44b62dD3F6379D6d14c38081fe1499D1a56250F`). The oracle discovers Machine via `asyncRedeemer.machine()` and calls conversion functions on Machine indirectly.

### Q2: Pending Redemption TVL Tracking
**Q:** Does the oracle need to track pending async redemptions?
**A:** **Yes, include pending redemptions.** Like Firelight, the oracle should include the value of NFT receipts (pending requestRedeem claims) in owner's TVL to prevent artificial PPS drops during finalization wait periods.

### Q3: Machine ERC-4626 API
**Q:** Can we call standard IERC4626 functions on Machine?
**A:** **Need to verify on-chain first.** Fork-test against mainnet to confirm which ERC-4626 functions Machine actually supports before deciding on the interface.

### Q4: NFT Enumeration for Pending Tracking
**Q:** How to enumerate pending NFT request IDs per user?
**A:** **Need to check on-chain.** Verify what functions AsyncRedeemer exposes for pending request enumeration.

### Q5: Hook Usage
**Q:** Which hooks reference this oracle?
**A:** **All 3 DETH hooks** - RequestRedeem, ApproveAndRequestRedeem, and ClaimAssets all reference this oracle via their yieldSourceOracleId field.

### Q6: Deposit Side
**Q:** Should the oracle handle deposits (WETH -> DETH)?
**A:** **Both inflow and outflow.** Oracle handles both deposit (WETH->DETH conversion) and redeem (DETH->WETH conversion) pricing.

### Q7: Decimals
**Q:** How to handle decimals?
**A:** **Verify Machine decimals on-chain.** Follow the pattern from other oracles (ERC4626, ERC7540, Firelight).

### Q8: Oracle Safety (Makina Exploit)
**Q:** Any manipulation mitigations for the Makina/Dialectic exploit (Jan 2026, $4M)?
**A:** **Trust Machine directly.** Use Machine's convertToAssets/convertToShares directly. The exploit was in a different oracle component, not in the vault's conversion functions.

### Q9: Reference Patterns
**Q:** Any other oracle patterns to reference?
**A:** **Check ERC7540 oracle too.** DETH's async pattern is closer to ERC-7540 (async vaults) than Firelight. The ERC7540 oracle handles 5 TVL components with graceful degradation via try/catch.

## Technical Decisions

- **Yield source = AsyncRedeemer**: Oracle discovers Machine via `asyncRedeemer.machine()`, then calls ERC-4626 functions on Machine
- **TVL includes pending redemptions**: Prevents artificial PPS drops during async finalization wait
- **Trust Machine's conversion functions**: No TWAP or bounds checking - monitoring system handles oracle manipulation
- **Both inflow and outflow**: getShareOutput (deposit), getAssetOutput (redeem), getWithdrawalShareOutput all needed
- **Verification needed**: Fork-test Machine's ERC-4626 support and AsyncRedeemer's NFT enumeration before finalizing

## Key Addresses (Mainnet)
- DETH share token: `0x871aB8E36CaE9AF35c6A3488B049965233DeB7ed` (18 decimals)
- Machine vault: `0x0447D0aD7FD6a3409B48Ecbb9DDB075C1e11D735`
- AsyncRedeemer: `0xE44b62dD3F6379D6d14c38081fe1499D1a56250F`
- WETH: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`

## Reference Oracle Patterns
1. **FirelightYieldSourceOracle**: Async withdrawal tracking via period scanning, uses convertToAssets/convertToShares (not preview functions)
2. **ERC7540YieldSourceOracle**: 5-component TVL (held + pendingRedeem + claimableRedeem + pendingDeposit + claimableDeposit), share token discovery, try/catch graceful degradation
3. **ERC4626YieldSourceOracle**: Simple baseline pattern for standard vaults
