# Odos Router V3 Framework Documentation

## Router Address
`0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05` -- single canonical address across all EVM chains.

## V3 `swapReferralInfo` Struct (CRITICAL: uses uint64, not uint256)

```solidity
struct swapReferralInfo {
    uint64 code;          // Referral code with packed bit fields
    uint64 fee;           // Fee amount (denominator = FEE_DENOM = 1e18)
    address feeRecipient; // Partner fee recipient
}
```

### `code` Bit Layout
- Bits 0-31: Referral code identifier
- Bits 32-47: splitBPS (partner share, 0 defaults to 8000 = 80%)
- Bit 48: Positive slippage flag (0 = router captures, 1 = user keeps)

### Fee Calculation
```
Router max: fee <= FEE_DENOM / 50 = 2e16 = 2%
Partner share: amountOut * fee * splitBPS / (FEE_DENOM * 10000)
User receives: amountOut * (FEE_DENOM - fee) / FEE_DENOM
```

## V3 `swap()` Signature

```solidity
function swap(
    swapTokenInfo memory tokenInfo,
    bytes calldata pathDefinition,
    address executor,
    swapReferralInfo memory referralInfo
) external payable returns (uint256 amountOut);
```

## V3 `_swap()` Internal Flow
1. Validate: outputMin <= outputQuote, outputMin > 0, inputToken != outputToken
2. Record balance before
3. Execute via `IOdosExecutor(executor).executePath(pathDefinition, amountsIn, msg.sender)`
4. Calculate output delta
5. Deduct referral fee (if fee > 0)
6. Capture positive slippage (if bit 48 = 0)
7. Check outputMin
8. Transfer output to receiver

## Executor Trust Model
- Executor is fully trusted -- receives input tokens and executes pathDefinition
- Router safety comes from outputMin enforcement AFTER execution
- pathDefinition is opaque bytes from Odos API -- never modify manually

## Key V2 -> V3 Changes
| Property | V2 | V3 |
|---|---|---|
| Referral param | `uint32 referralCode` | `swapReferralInfo { uint64, uint64, address }` |
| Fee storage | On-chain mapping | Per-transaction in calldata |
| Fee type | `uint64` with `FEE_DENOM = 1e18` | Same |
| Max fee | 2% | 2% (same) |
| Code type | `uint32` | `uint64` (packed bit fields) |
| Positive slippage | Router captures | Configurable via bit 48 |
| swapTokenInfo | Unchanged | Unchanged |

## References
- [Odos Router V3 GitHub](https://github.com/odos-xyz/odos-router-v3)
- [Odos Documentation](https://docs.odos.xyz/)
- [Odos V3 on Etherscan](https://etherscan.io/address/0x0d05a7d3448512b78fa8a9e46c4872c88c4a0d05)
