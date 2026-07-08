# Repository Analysis: UniV2 LP Token Yield Source Oracle

## Oracle Architecture

### Abstract Base: `AbstractYieldSourceOracle`
- 8 abstract methods to implement + concrete batch methods
- Constructor: `(address superLedgerConfiguration_)`
- `getAssetOutputWithFees()` already implemented in base (uses SuperLedgerConfiguration)

### Methods to Implement
| Method | Visibility | Purpose |
|---|---|---|
| `decimals(address)` | external view | Share token decimals |
| `getShareOutput(address, address, uint256)` | external view | Assets -> shares |
| `getWithdrawalShareOutput(address, address, uint256)` | external view | Assets -> shares (inverse) |
| `getAssetOutput(address, address, uint256)` | public view | Shares -> assets |
| `getPricePerShare(address)` | public view | Price per 1 full share |
| `getTVLByOwnerOfShares(address, address)` | public view | Owner TVL |
| `getTVL(address)` | public view | Total TVL |
| `getBalanceOfOwner(address, address)` | external view | Raw share balance |

### Relevant Precedents
- **ERC4626YieldSourceOracle** - simplest reference
- **DETHYieldSourceOracle** - constructor with additional immutable param (oracle_)
- **PendlePTYieldSourceOracle** - decimal normalization with Math.mulDiv()
- **SuperVaultYieldSourceOracle** - getWithdrawalShareOutput inverse pattern

### Key Patterns
- `getPricePerShare()` returns value of 1 full share (10^decimals) in asset terms
- `getWithdrawalShareOutput()` uses `Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil)`
- IOracle (EIP-7726): `getQuote(baseAmount, base, quote)` for cross-asset pricing

### Existing UniV2 Interfaces
- `lib/modulekit/.../IUniswapV2Pair.sol` - has `token0()`, `token1()`, `getReserves()` but NOT `totalSupply()`/`decimals()`
- Need to use `IERC20Metadata` alongside or create extended interface

### Files to Create
1. `src/accounting/oracles/UniV2LPYieldSourceOracle.sol`
2. `src/vendor/uniswap/IUniswapV2Pair.sol`
3. `test/unit/accounting/oracles/UniV2LPYieldSourceOracle.t.sol`
4. `test/mocks/MockUniswapV2Pair.sol`

### Files to Modify
1. `script/utils/Constants.sol` - add oracle key/salt
2. `script/DeployV2Core.s.sol` - add to deployment

### Test Patterns
- Test base: `Helpers` (extends `Test, Constants`)
- Mock oracle: `MockSuperOracle` already exists (`test/mocks/MockSuperOracle.sol`)
- Fork testing: `vm.createFork(vm.envString(RPC_URL), blockNumber)`
- Mainnet WETH/USDC pair for fork tests
