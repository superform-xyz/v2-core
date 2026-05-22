# Morpho Vault V2 — forceDeallocate Research

## 1. Function Signature

```solidity
function forceDeallocate(
    address adapter,
    bytes memory data,
    uint256 assets,
    address onBehalf
) external returns (uint256 penaltyShares);
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `adapter` | `address` | Registered adapter to deallocate from (`isAdapter[adapter]` must be true) |
| `data` | `bytes memory` | Market-specific data passed to `IAdapter.deallocate()` |
| `assets` | `uint256` | Amount of underlying assets to deallocate |
| `onBehalf` | `address` | Address whose vault shares are burned for penalty |

**Return:** `penaltyShares` — number of vault shares burned from `onBehalf`.

**Related view:**
```solidity
function forceDeallocatePenalty(address adapter) external view returns (uint256);
```

## 2. Implementation Logic

```solidity
function forceDeallocate(address adapter, bytes memory data, uint256 assets, address onBehalf)
    external returns (uint256)
{
    bytes32[] memory ids = deallocateInternal(adapter, data, assets);
    uint256 penaltyAssets = assets.mulDivUp(forceDeallocatePenalty[adapter], WAD);
    uint256 penaltyShares = withdraw(penaltyAssets, address(this), onBehalf);
    emit EventsLib.ForceDeallocate(msg.sender, adapter, assets, onBehalf, ids, penaltyAssets);
    return penaltyShares;
}
```

Flow:
1. `deallocateInternal` validates adapter, calls `IAdapter(adapter).deallocate()`, updates caps, transfers assets from adapter to vault
2. Calculate penalty: `penaltyAssets = assets * forceDeallocatePenalty[adapter] / WAD` (rounded up)
3. Burn shares from `onBehalf` via internal `withdraw(penaltyAssets, address(this), onBehalf)`
4. Emit event, return penalty shares

## 3. Penalty Mechanism

- **Formula:** `penaltyAssets = assets.mulDivUp(forceDeallocatePenalty[adapter], WAD)`
- **WAD** = 1e18 (100% = 1e18)
- **Max penalty:** `MAX_FORCE_DEALLOCATE_PENALTY = 0.02e18` (2%)
- **Per-adapter:** configurable by curator via timelocked `setForceDeallocatePenalty`
- **Zero penalty:** anyone can forceDeallocate at zero cost (only gas)
- **Penalty distribution:** shares burned → value redistributed to remaining shareholders

## 4. Adapter Architecture

```solidity
interface IAdapter {
    function allocate(bytes memory data, uint256 assets, bytes4 selector, address sender)
        external returns (bytes32[] memory ids, int256 change);
    function deallocate(bytes memory data, uint256 assets, bytes4 selector, address sender)
        external returns (bytes32[] memory ids, int256 change);
    function realAssets() external view returns (uint256 assets);
}
```

- `data`: protocol-specific encoded data (e.g., which Morpho Blue market)
- `selector`: `msg.sig` from VaultV2 — lets adapter distinguish between `deallocate` vs `forceDeallocate`
- `sender`: `msg.sender` from VaultV2

**Available adapters:** MorphoMarketV1AdapterV2, MorphoVaultV1Adapter, MorphoMarketV2Adapter

## 5. Deployment Addresses (CREATE2, same across chains)

| Contract | Address |
|----------|---------|
| VaultV2Factory | `0xA1D94F746dEfa1928926b84fB2596c06926C0405` |
| MorphoVaultV1AdapterFactory | `0xD1B8E2dee25c2b89DCD2f98448a7ce87d6F63394` |
| MorphoMarketV1AdapterV2Factory | `0x32BB1c0D48D8b1B3363e86eeB9A0300BAd61ccc1` |
| MorphoRegistry | `0x3696c5eAe4a7Ffd04Ea163564571E9CD8Ed9364e` |

**Chains:** Ethereum, Arbitrum, Avalanche, Base, Cronos, Linea, OP Mainnet, Plume, Polygon, Unichain, WorldChain, 28+ total

## 6. Events

**Primary (forceDeallocate):**
```solidity
event ForceDeallocate(
    address indexed sender, address adapter, uint256 assets,
    address indexed onBehalf, bytes32[] ids, uint256 penaltyAssets
);
```

**Secondary (deallocateInternal):**
```solidity
event Deallocate(
    address indexed sender, address indexed adapter,
    uint256 assets, bytes32[] ids, int256 change
);
```

## 7. Access Control

- **Fully permissionless** — no role checks on caller
- `onBehalf` must hold sufficient vault shares for penalty
- `adapter` must be registered (`isAdapter[adapter]` must be true)
- Zero penalty = anyone can force deallocate at zero cost

## 8. Security Considerations

1. **Zero penalty risk:** When penalty is 0, anyone can manipulate allocations freely
2. **Penalty as value redistribution:** Penalty goes to remaining shareholders (by design)
3. **Flash loan pattern:** Expected usage — flashloan → supply to adapter market → forceDeallocate → withdraw → repay
4. **Adapter removal frontrunning:** Assets allocated after removal proposal can get stuck
5. **Audited by:** ChainSecurity, Spearbit, Blackthorn/Sherlock, Zellic, Cantina

## 9. Errors

```solidity
error NotAdapter();       // adapter not registered
error ZeroAllocation();   // market ID has zero allocation
error PenaltyTooHigh();   // exceeds MAX_FORCE_DEALLOCATE_PENALTY (2%)
```

## Sources

- [Morpho Vault V2 GitHub](https://github.com/morpho-org/vault-v2)
- [Morpho Vault V2 Docs](https://docs.morpho.org/learn/concepts/vault-v2/)
- [Contract Addresses](https://docs.morpho.org/get-started/resources/contracts/morpho-vaults-v2/)
- [Security Considerations](https://docs.morpho.org/curate/concepts/security-considerations/)
- [ChainSecurity Audit](https://www.chainsecurity.com/security-audit/morpho-vault-v2)
