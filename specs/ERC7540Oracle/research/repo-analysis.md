# Repository Analysis: ERC7540YieldSourceOracle

## Date: 2026-04-29

---

## 1. Existing Oracle Architecture

### Base Class: `AbstractYieldSourceOracle`
**File**: `src/accounting/oracles/AbstractYieldSourceOracle.sol`

- Single constructor arg: `address superLedgerConfiguration_` stored as `SUPER_LEDGER_CONFIGURATION` (immutable)
- 7 abstract methods: `decimals`, `getShareOutput`, `getWithdrawalShareOutput`, `getAssetOutput`, `getPricePerShare`, `getTVLByOwnerOfShares`, `getTVL`, `getBalanceOfOwner`
- Batch methods: `getPricePerShareMultiple`, `getTVLByOwnerOfSharesMultiple`, `getTVLMultiple`
- Fee method: `getAssetOutputWithFees` reads config from `SuperLedgerConfiguration`

### Constructor Pattern (all oracles):
```solidity
constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) { }
```

### YoYieldSourceOracle (reference — has pending tracking)
**File**: `src/accounting/oracles/YoYieldSourceOracle.sol`

- `getTVLByOwnerOfShares` includes TWO components: `heldValue + pendingAssets`
- Uses `IYoVault` interface (non-standard, address-based accumulator)
- `pendingRedeemRequest(owner)` returns `(uint256 assets, uint256 shares)` — assets fixed at request time
- `getWithdrawalShareOutput` uses manual inverse: `Math.mulDiv(..., Math.Rounding.Ceil)` (previewRedeem reverts)
- `getAssetOutput` uses `convertToAssets()` (not `previewRedeem`)

### ERC4626YieldSourceOracle (simplest — held only)
**File**: `src/accounting/oracles/ERC4626YieldSourceOracle.sol`

- `getShareOutput` -> `previewDeposit`
- `getWithdrawalShareOutput` -> `previewWithdraw`
- `getAssetOutput` -> `previewRedeem`
- `getPricePerShare` -> `convertToAssets(10 ** decimals)`
- `getTVLByOwnerOfShares` -> `convertToAssets(balanceOf(owner))`
- `getTVL` -> `totalAssets()`

### SuperVaultYieldSourceOracle (async redeems, no pending tracking)
**File**: `src/accounting/oracles/SuperVaultYieldSourceOracle.sol`

- `getWithdrawalShareOutput` uses manual inverse: `Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil)`
- `getAssetOutput` uses `convertToAssets()` (previewRedeem reverts for async)
- Only tracks held shares

## 2. ERC-7540 Interfaces

### Vendor Interface (used by hooks)
**File**: `src/vendor/vaults/7540/IERC7540.sol`

Extends `IERC7575` which provides: `share()`, `asset()`, `convertToAssets()`, `convertToShares()`, `totalAssets()`, `maxWithdraw()`, `maxRedeem()`, `previewDeposit`, `previewRedeem`, etc.

Plus 7540-specific: `pendingDepositRequest(requestId, controller)`, `pendingRedeemRequest(requestId, controller)`, `claimableDepositRequest(requestId, controller)`, `claimableRedeemRequest(requestId, controller)`, `requestDeposit`, `requestRedeem`, etc.

### Standard Interface
**File**: `src/vendor/standards/ERC7540/IERC7540Vault.sol`

## 3. Existing 7540 Hooks

**Directory**: `src/hooks/vaults/7540/` — 12 hooks

**requestId convention**: ALL use `requestId = 0`:
- `Redeem7540VaultHook.sol:123`: `IERC7540(yieldSource).claimableRedeemRequest(0, account)`
- `Withdraw7540VaultHook.sol:124`: same
- `CancelDepositRequest7540Hook.sol:46`: `cancelDepositRequest(0, account)`
- `CancelRedeemRequest7540Hook.sol:46`: `cancelRedeemRequest(0, account)`

**Import pattern**: Hooks import from `../../../vendor/vaults/7540/IERC7540.sol`

**Share token**: Hooks use `IERC7540(yieldSource).share()` to get share token

## 4. Test Patterns

### Existing Oracle Tests
**File**: `test/unit/accounting/YieldSourceOracles.t.sol`

- Extends `Helpers` (which extends `Test`, `Constants`)
- Sets up `ISuperLedgerConfiguration`, `ISuperLedger`, mock vaults, oracles in `setUp()`
- Uses `vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY))`
- Tests organized by category: decimals, share output, withdrawal share output, asset output, PPS, TVL, balance, getAssetOutputWithFees
- Uses `vm.mockCall` for mocking vault responses
- Uses `makeAddr("name")` for test addresses

### Constants for Oracle Keys
**File**: `test/utils/Constants.sol` (lines 143-145)
```solidity
string public constant ERC4626_YIELD_SOURCE_ORACLE_KEY = "ERC4626YieldSourceOracle";
string public constant ERC7540_YIELD_SOURCE_ORACLE_KEY = "ERC7540YieldSourceOracle";
```
**The `ERC7540_YIELD_SOURCE_ORACLE_KEY` constant already exists.**

## 5. Deleted Oracle
**File**: `test/mocks/unused-oracles/ERC7540YieldSourceOracle.sol`

4626 clone with NO async tracking:
- `getWithdrawalShareOutput` -> manual inverse with `convertToAssets(1e18)` hardcoded (**BUG**: should use share decimals)
- `getTVLByOwnerOfShares` -> `convertToAssets(IERC20(share).balanceOf(owner))` — NO PENDING/CLAIMABLE

## 6. Registration Pattern
**File**: `src/accounting/SuperLedgerConfiguration.sol`

- `setYieldSourceOracles(bytes32[] salts, YieldSourceOracleConfigArgs[] configs)`
- Derives unique ID: `keccak256(abi.encodePacked(salt, msg.sender))`
- Stores `YieldSourceOracleConfig` struct: `yieldSourceOracle`, `feePercent`, `feeRecipient`, `manager`, `ledger`
- Timelock: `proposeYieldSourceOracleConfig` -> 1 week wait -> `acceptYieldSourceOracleConfigProposal`

## 7. Ledger Integration
**File**: `src/accounting/BaseLedger.sol`

`_updateAccounting` (line 262-304):
1. Gets PPS via `IYieldSourceOracle(config.yieldSourceOracle).getPricePerShare(yieldSource)` — **MUST NOT RETURN 0** (`if (pps == 0) revert INVALID_PRICE()`)
2. Gets decimals
3. Takes snapshot / processes outflow

**Critical**: Only `getPricePerShare()` and `decimals()` called onchain by ledger. `getTVLByOwnerOfShares()` is called by offchain keeper only.

## 8. Existing Mock Vault
**File**: `test/mocks/Mock7540Vault.sol`

Minimal — does NOT implement any async methods. Need new comprehensive mocks.

## 9. Implementation Patterns Summary

**Interface**: Import from `src/vendor/vaults/7540/IERC7540.sol` (vendor interface)
**Share token**: `IERC7540(yieldSourceAddress).share()`
**Decimals**: `IERC20Metadata(share).decimals()`
**Manual inverse**: `Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil)` for `getWithdrawalShareOutput`
**previewRedeem**: AVOID — reverts on async vaults. Use `convertToAssets` instead.
