# Repository Analysis: DETH Oracle Patterns

## Oracle Architecture

### Interface (IYieldSourceOracle)
8 abstract methods every oracle must implement:
- `decimals(yieldSourceAddress)` - Share token decimals
- `getShareOutput(yieldSourceAddress, assetIn, assetsIn)` - Inflow: assets to shares
- `getWithdrawalShareOutput(yieldSourceAddress, assetIn, assetsIn)` - Shares needed to withdraw assets
- `getAssetOutput(yieldSourceAddress, assetOut, sharesIn)` - Outflow: shares to assets
- `getPricePerShare(yieldSourceAddress)` - PPS for fee calculations
- `getBalanceOfOwner(yieldSourceAddress, ownerOfShares)` - Share balance
- `getTVLByOwnerOfShares(yieldSourceAddress, ownerOfShares)` - User TVL (most complex)
- `getTVL(yieldSourceAddress)` - Total vault TVL

### Base Contract (AbstractYieldSourceOracle)
- Constructor: `(address superLedgerConfiguration_)`
- Stores `SUPER_LEDGER_CONFIGURATION` immutable
- Provides batch methods: `getPricePerShareMultiple`, `getTVLByOwnerOfSharesMultiple`, `getTVLMultiple`
- Provides `getAssetOutputWithFees` (reads config from SuperLedgerConfiguration)

### Closest Analogs for DETH Oracle

1. **YoYieldSourceOracle** - Simplest async vault oracle
   - TVL = held shares value + pendingRedeemRequest assets
   - Uses `convertToAssets()` (not preview functions)
   - Uses `Math.mulDiv(..., Ceil)` for getWithdrawalShareOutput

2. **FirelightYieldSourceOracle** - Period-based async withdrawal scanning
   - TVL = held shares value + pending withdrawal values across periods
   - MAX_LOOKBACK constant for period scanning
   - Uses `convertToAssets/convertToShares` (not preview functions)

3. **ERC7540YieldSourceOracle** - 5-component async TVL
   - Separate share token discovery via `_getShareToken()` helper
   - try/catch graceful degradation for async components
   - REQUEST_ID immutable for vault-specific patterns

### Key Pattern: yieldSourceAddress = AsyncRedeemer
- HookDataDecoder extracts `asyncRedeemer` as the `yieldSource` (offset 32)
- Oracle receives AsyncRedeemer address, must discover Machine via `.machine()`
- All pricing calls go to Machine (the ERC-4626 vault), not AsyncRedeemer

### Registration
- `SuperLedgerConfiguration.setYieldSourceOracles(bytes32[] salts, configs[])`
- yieldSourceOracleId = `keccak256(abi.encodePacked(salt, msg.sender))`
- Config contains: yieldSourceOracle address, feePercent, feeRecipient, manager, ledger

### Deployment Pattern
- Standalone deploy script extending DeployV2Base
- Oracle key constant in script/utils/Constants.sol
- Locked bytecode JSON files
- Constructor arg: `superLedgerConfiguration_` address

### Test Patterns
- Inline mock vault in same test file
- Sections: constructor, decimals, getShareOutput, getAssetOutput, getWithdrawalShareOutput, getPricePerShare, getBalanceOfOwner, getTVL, getTVLByOwnerOfShares, batch, fees, edges, fuzz
- Naming: `test_methodName_scenario()` and `testFuzz_methodName(params)`
- Key assertions: TVL preservation, PPS stability, claimed exclusion

### Files to Create
- `src/accounting/oracles/DETHYieldSourceOracle.sol`
- `test/unit/accounting/DETHYieldSourceOracle.t.sol`
- Extend `src/vendor/vaults/deth/IMachine.sol` with ERC-4626 view functions
