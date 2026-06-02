# SpecFlow Analysis: SpectraMetaVaultOracle

## User Flows

### Flow 1 — SuperLedger Inflow (Deposit)
SuperExecutor → BaseLedger._updateAccounting → oracle.getPricePerShare → convertToAssets(10^decimals)

### Flow 2 — SuperLedger Outflow (Withdrawal)
SuperExecutor → BaseLedger._updateAccounting → oracle.getPricePerShare → fee calculation

### Flow 3 — getTVL Query
Monitoring/fee preview → oracle.getTVL → convertToAssets(totalSupply())

### Flow 4 — Per-Owner TVL Query
BaseLedger.previewFees → oracle.getTVLByOwnerOfShares → 5 components aggregated

### Flow 5 — Monitoring State Breakdown
Off-chain monitoring → oracle.getAsyncStateBreakdown → all 5 components individually

### Flow 6 — Oracle Registration (Admin)
SuperLedgerConfiguration.setYieldSourceOracles → wires oracle to vault

## Critical Gaps Identified

### G1: claimableRedeemRequest return unit
Must confirm `claimableRedeemRequest(0, owner)` returns shares (not assets) on the live Spectra MetaVaultWrapper. If it returns assets, Component 3 would double-convert.
**Resolution**: Verify on-chain with cast call.

### G2: All IYieldSourceOracle methods must be implemented
Spec focuses on getTVL/Component 3 fixes but must implement all 8 abstract methods from AbstractYieldSourceOracle: decimals, getShareOutput, getWithdrawalShareOutput, getAssetOutput, getPricePerShare, getBalanceOfOwner, getTVLByOwnerOfShares, getTVL.
**Resolution**: Copy unchanged methods from ERC7540YieldSourceOracle.

### G3: Share token decimals confirmation
Must verify `vault.decimals()` returns 6 (USDC-aligned) not 18 on the live contract.
**Resolution**: Verify on-chain.

### G4: convertToAssets revert inside try success block
If claimableRedeemRequest succeeds but convertToAssets reverts, entire getTVLByOwnerOfShares reverts. Consistent with existing oracle pattern (R1-level for convertToAssets).
**Resolution**: Accept existing pattern - document as design choice.

### G5: getTVL vs sum of per-owner TVLs
convertToAssets(totalSupply()) may not include pending deposit assets. Known limitation.
**Resolution**: Document as acceptable - same limitation as all ERC7540 oracles.

### G6: Spectra-specific mock needed for unit tests
Existing MockERC7540VaultFull doesn't simulate zero totalAssets() or reverting share().
**Resolution**: Create a MockSpectraMetaVault in test file.
