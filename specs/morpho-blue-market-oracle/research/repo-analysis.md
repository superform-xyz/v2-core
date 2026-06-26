# Repository Research — Morpho Blue Market Oracle

## Oracle Architecture Pattern

```
IYieldSourceOracle  (interface)
  └── AbstractYieldSourceOracle  (abstract base — implements batch methods, getAssetOutputWithFees)
        └── ConcreteOracle  (implements the six core abstract methods)
```

### Key Files

| File | Purpose |
|---|---|
| `src/interfaces/accounting/IYieldSourceOracle.sol` | Full interface |
| `src/accounting/oracles/AbstractYieldSourceOracle.sol` | Base class with batch plumbing |
| `src/accounting/oracles/ERC4626YieldSourceOracle.sol` | Simplest reference oracle |
| `src/accounting/oracles/MorphoBlueMarketWrapper.sol` | **Implemented — wrapper** |
| `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol` | **Implemented — oracle** |

## Oracle Interface Methods

All take `yieldSourceAddress` as first argument. `getAssetOutput` must be `public view` (not `external`) — AbstractYieldSourceOracle calls it internally in `getAssetOutputWithFees`.

```solidity
decimals(address) → uint8
getShareOutput(address, address, uint256) → uint256        // deposit preview
getWithdrawalShareOutput(address, address, uint256) → uint256 // withdraw preview
getAssetOutput(address, address, uint256) → uint256        // redeem preview (PUBLIC)
getPricePerShare(address) → uint256
getBalanceOfOwner(address, address) → uint256
getTVL(address) → uint256
getTVLByOwnerOfShares(address, address) → uint256
```

Batch methods in AbstractYieldSourceOracle (do NOT override):
- `getPricePerShareMultiple`, `getTVLMultiple`, `getTVLByOwnerOfSharesMultiple`, `getAssetOutputWithFees`

## ERC4626 Pattern (Canonical Reference)

```solidity
decimals()        → IERC4626(addr).decimals()
getShareOutput()  → vault.previewDeposit(assetsIn)       // rounds down
getWithdrawal..() → vault.previewWithdraw(assetsIn)      // rounds up
getAssetOutput()  → vault.previewRedeem(sharesIn)        // public
getPricePerShare()→ vault.convertToAssets(10 ** decimals)
getBalanceOf..()  → vault.balanceOf(owner)               // ERC20 balance
getTVLByOwner..() → vault.convertToAssets(vault.balanceOf(owner))
getTVL()          → vault.totalAssets()
```

## Morpho Vendor Files

**`src/vendor/morpho/IMorpho.sol`** — Key types:
```solidity
type Id is bytes32;
struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
struct Market { uint128 totalSupplyAssets; uint128 totalSupplyShares; uint128 totalBorrowAssets;
                uint128 totalBorrowShares; uint128 lastUpdate; uint128 fee; }
struct Position { uint256 supplyShares; uint128 borrowShares; uint128 collateral; }

// IMorphoStaticTyping view functions:
function market(Id id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
function position(Id id, address user) external view returns (uint256, uint128, uint128);
function idToMarketParams(Id id) external view returns (address, address, address, address, uint256);
```

**`src/vendor/morpho/MarketParamsLib.sol`** — `id()` = keccak256 of 5×32 bytes of MarketParams.

**`src/vendor/morpho/SharesMathLib.sol`** — `VIRTUAL_SHARES=1e6`, `VIRTUAL_ASSETS=1`:
```solidity
toSharesDown(assets, totalAssets, totalShares) // deposit, fee minting
toSharesUp(assets, totalAssets, totalShares)   // withdrawal
toAssetsDown(shares, totalAssets, totalShares) // value display
toAssetsUp(shares, totalAssets, totalShares)   // repayment
```

**`src/vendor/morpho/MathLib.sol`** — `WAD=1e18`, `wMulDown`, `wTaylorCompounded` (3-term Taylor for e^(rt)-1)

**`src/vendor/morpho/IIrm.sol`** — `borrowRateView(MarketParams, Market) → uint256` (view-safe)

## Hook Data Layouts

**MorphoLendHook (145 bytes)**:
```
[0-20):   loanToken
[20-40):  collateralToken
[40-60):  oracle
[60-80):  irm
[80-112): amount (uint256)
[112-144): lltv (uint256)
[144]:    usePrevHookAmount (bool)
```

**MorphoWithdrawHook (176 bytes)**:
```
[0-20):   loanToken
[20-40):  collateralToken
[40-60):  oracle
[60-80):  irm
[80-112): lltv (uint256)   ← different position than LendHook
[112-144): assets (uint256)
[144-176): shares (uint256)
```

`inspect()` on both returns `abi.encodePacked(loanToken, collateralToken, oracle, irm)` = 80 bytes.

## Fork Test Constants

```solidity
// test/utils/Constants.sol
address MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
address MORPHO_ORACLE_WBTC_USDC = 0xDddd770BADd886dF3864029e4B377B5F6a2B6b83;
address MORPHO_IRM_WBTC_USDC = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
uint256 ETH_BLOCK = 21_929_476;
address CHAIN_1_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address CHAIN_1_WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
address CHAIN_1_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address CHAIN_1_WST_ETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
```

## Implementation Conventions

1. `pragma solidity 0.8.30` in all production files
2. `SCREAMING_SNAKE_CASE` custom errors: `error MARKET_DOES_NOT_EXIST()`
3. `/// @inheritdoc AbstractYieldSourceOracle` on all overrides
4. Constructor takes only `address superLedgerConfiguration_` (single arg pattern)
5. `address,` (unnamed) for the unused assetIn/assetOut param in share/asset conversions
6. `getAssetOutput` must be `public view` not `external view`
