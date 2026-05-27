# Framework Documentation: Morpho Vault V2

## Key Technical Insight

**The penalty is NOT time-based.** It's a static per-adapter value set by `setForceDeallocatePenalty`. The formula is simply `assets * penalty[adapter] / WAD` with no time-dependent component.

## Version Info

- Solidity pragma: `0.8.28` (implementation), `>=0.5.0` (interfaces)
- License: GPL-2.0-or-later
- Latest release: `2025-12-04`
- Foundry install: `forge install morpho-org/vault-v2`

## Minimal Vendor Interface

```solidity
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IMorphoVaultV2 {
    function forceDeallocate(
        address adapter,
        bytes memory data,
        uint256 assets,
        address onBehalf
    ) external returns (uint256 penaltyShares);

    function forceDeallocatePenalty(address adapter) external view returns (uint256);

    function asset() external view returns (address);
}
```

## Adapter Data Encoding

For `MorphoMarketV1AdapterV2`: `data = abi.encode(MarketParams)` where `MarketParams` is the Morpho Blue struct.

## ERC-4626 Caveat

VaultV2's `maxDeposit`, `maxMint`, `maxWithdraw`, `maxRedeem` always return zero. Non-standard behavior.

## `onBehalf` Requirement

The `onBehalf` address must hold sufficient vault shares to cover the penalty. Since our hook always sets `onBehalf = msg.sender` (the smart account), the smart account must hold vault shares.

## Deployment

- VaultV2Factory: `0xA1D94F746dEfa1928926b84fB2596c06926C0405` (same across chains via CREATE2)
- Individual vaults are created via the factory — addresses vary per vault
- Available on 28+ chains including all our target chains (Ethereum, Base, Optimism, Arbitrum)

## Sources

- [GitHub: morpho-org/vault-v2](https://github.com/morpho-org/vault-v2)
- [Morpho Vault V2 Docs](https://docs.morpho.org/learn/concepts/vault-v2/)
- [Contract Addresses](https://docs.morpho.org/get-started/resources/contracts/morpho-vaults-v2/)
