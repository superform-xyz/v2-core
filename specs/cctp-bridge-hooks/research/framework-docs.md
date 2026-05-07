# CCTP Bridge Hooks - Framework Documentation Research

## Date: 2026-05-06

## CCTP V2 Official Documentation

### Core Functions

#### `depositForBurn`
Burns tokens on source chain for minting on destination chain.
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

#### `depositForBurnWithHook`
Burns tokens with additional hook data for composable cross-chain actions.
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

#### `getMinFeeAmount`
Calculates the minimum fee for a given transfer amount.

### TokenMessengerV2 Contract Address
`0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d` — universal across all EVM chains via CREATE2.

This is a proxy contract (EIP-1967) with implementation at a separate address.

### Deployed Chains & Domain IDs (as of May 2026)

| Chain | Domain ID | EVM Chain ID | Superform Constant |
|-------|-----------|-------------|-------------------|
| Ethereum | 0 | 1 | MAINNET_CHAIN_ID |
| Avalanche | 1 | 43114 | AVALANCHE_CHAIN_ID |
| Optimism | 2 | 10 | OPTIMISM_CHAIN_ID |
| Arbitrum | 3 | 42161 | ARBITRUM_CHAIN_ID |
| Base | 6 | 8453 | BASE_CHAIN_ID |
| Polygon PoS | 7 | 137 | POLYGON_CHAIN_ID |
| Unichain | 10 | 130 | UNICHAIN_CHAIN_ID |
| Linea | 11 | 59144 | LINEA_CHAIN_ID |
| Sonic | 13 | 146 | SONIC_CHAIN_ID |
| World Chain | 14 | 480 | WORLDCHAIN_CHAIN_ID |
| HyperEVM | 19 | 999 | HYPEREVM_CHAIN_ID |

**NOT deployed on**: BNB (56), Gnosis (100), Berachain (80094), Flare (14)

### Key Protocol Constraints

1. **$10M per-message limit**: Maximum burn amount per transaction
2. **USDC only**: TokenMessengerV2 only accepts USDC (and EURC on some chains, but out of scope)
3. **Fees**: Deducted from transfer amount, not via msg.value. `maxFee` sets the cap.
4. **Finality**: Standard (>= 2000 threshold) = 15-19 min, Fast (< 2000) = 8-20 sec

### Integration Pattern

```
Source Chain:
1. User approves USDC to TokenMessengerV2
2. Call depositForBurn (or depositForBurnWithHook)
3. USDC is burned, CCTP message created
4. Circle attestation service signs the message

Destination Chain:
5. Relayer calls receiveMessage with attestation
6. USDC is minted to mintRecipient
7. If hookData provided (via depositForBurnWithHook), hook is executed
```

## Superform Hook Framework

### BaseHook Interface
All hooks extend `BaseHook` which provides:
- `build(address prevHook, address account, bytes calldata data)` — external entry point
- `_buildHookExecutions(...)` — internal, must be implemented by each hook
- `preExecute` / `postExecute` — mutex guards
- `inspect(bytes calldata data)` — returns inspectable addresses from hook data

### Hook Types
- `HookType.NONACCOUNTING` — bridge hooks don't affect accounting (correct for CCTP)
- `HookSubTypes.BRIDGE` — bridge hook subtype

### Transient Storage
Hooks use transient storage for inter-hook communication:
- `ISuperHookResult(prevHook).getOutAmount(account)` — get previous hook's output amount
- Used when `usePrevHookAmount = true`

### Validator Signature Pattern
```solidity
ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account)
```
Returns the validator signature that gets appended to destination execution data.
