# CCTP Bridge Hooks - Best Practices Research

## Date: 2026-05-06

## CCTP V2 Protocol Overview

### What is CCTP?
Cross-Chain Transfer Protocol (CCTP) is Circle's official protocol for native USDC transfers across blockchains. Uses burn-and-mint mechanism — USDC is burned on source chain and natively minted on destination chain.

### CCTP V2 vs V1
- **V2** adds fast finality support via `minFinalityThreshold` parameter
- **V2** adds `maxFee` parameter for fee caps
- **V2** adds `destinationCaller` for restricting who can relay messages
- V1 deprecation starts July 31, 2026

### TokenMessengerV2 Address (VERIFIED)
**`0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d`** — same on all EVM chains (CREATE2 deployment)

Verified on:
- Etherscan: https://etherscan.io/address/0x28b5a0e9c621a5badaa536219b3a228c8168cf5d
- BaseScan: https://basescan.org/address/0x28b5a0e9c621a5badaa536219b3a228c8168cf5d

**NOTE**: The implementation plan had an incorrect address (`0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440`). The correct address is `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d`.

### CCTP Domain IDs (NOT EVM Chain IDs)

| Chain | Domain ID | Chain ID |
|-------|-----------|----------|
| Ethereum | 0 | 1 |
| Avalanche | 1 | 43114 |
| Optimism | 2 | 10 |
| Arbitrum | 3 | 42161 |
| Noble | 4 | N/A |
| Solana | 5 | N/A |
| Base | 6 | 8453 |
| Polygon PoS | 7 | 137 |

### Finality Thresholds
- `minFinalityThreshold >= 2000` → Standard finality (15-19 minutes)
- `minFinalityThreshold < 2000` → Fast finality (8-20 seconds)

### Security Best Practices
1. **Approval pattern**: approve(0) → approve(amount) → call → approve(0)
2. **destinationCaller**: Set to Superform-controlled address to prevent front-running
3. **maxFee**: Set reasonable caps
4. **mintRecipient validation**: Must be non-zero bytes32
5. **No msg.value needed**: CCTP V2 requires no native ETH
6. **1:1 mint guarantee**: CCTP guarantees exact minting minus fee

## Key Discrepancies Found

### Parameter Name: `maxFee` vs `maxBurnAmountPerMessage`
The actual CCTP V2 parameter is `maxFee`, NOT `maxBurnAmountPerMessage` as used in the implementation plan. Must be corrected.

### `depositForBurnWithHook` Function — CONFIRMED EXISTS
CCTP V2 HAS a `depositForBurnWithHook` function with `hookData` parameter:

```solidity
function depositForBurnWithHook(
    uint256 amount,
    uint32 destinationDomain,
    bytes32 mintRecipient,
    address burnToken,
    bytes32 destinationCaller,
    uint256 maxFee,
    uint32 minFinalityThreshold,
    bytes memory hookData
) external returns (bytes memory);
```

This enables composable cross-chain actions — the `hookData` is delivered with the mint on the destination. This is analogous to Stargate's `composeMsg` and Across's `destinationMessage`.

### `depositForBurn` Function (without hook)

```solidity
function depositForBurn(
    uint256 amount,
    uint32 destinationDomain,
    bytes32 mintRecipient,
    address burnToken,
    bytes32 destinationCaller,
    uint256 maxFee,
    uint32 minFinalityThreshold
) external returns (bytes memory);
```

### Chain Support (MUCH broader than initially assumed)
CCTP V2 TokenMessengerV2 deployed on ALL these chains:
- Ethereum (Domain 0), Avalanche (Domain 1), Optimism (Domain 2), Arbitrum (Domain 3)
- Base (Domain 6), Polygon PoS (Domain 7), Unichain (Domain 10), Linea (Domain 11)
- Sonic (Domain 13), World Chain (Domain 14), HyperEVM (Domain 19)
- Plus: Codex (12), Monad (15), Sei (16), XDC (18), Ink (21), Plume (22), Morph (30), Pharos (31)

**IMPORTANT**: The implementation plan incorrectly listed Linea, Sonic, Unichain, World Chain, HyperEVM as "not deployed." They ARE deployed.

### Per-Message Limit
$10 million limit on the amount of USDC that can be burned in a single transaction.

## References
- Circle CCTP Docs: https://developers.circle.com/cctp/evm-smart-contracts
- TokenMessengerV2 GitHub: https://github.com/circlefin/evm-cctp-contracts
- Etherscan: https://etherscan.io/address/0x28b5a0e9c621a5badaa536219b3a228c8168cf5d
