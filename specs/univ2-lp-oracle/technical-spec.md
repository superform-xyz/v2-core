# UniV2 LP Token Yield Source Oracle - Technical Specification

## Overview

Create a Uniswap V2 LP Token Yield Source Oracle that extends `AbstractYieldSourceOracle` and implements pricing for Uniswap V2 LP tokens using the Alpha Homora fair pricing formula. This oracle supports all V2-compatible DEX forks (SushiSwap, PancakeSwap, etc.) since they share the same `IUniswapV2Pair` interface.

## Problem Statement

Superform needs to track yield and price per share for UniV2 LP token positions. Naive LP pricing (`(r0*p0 + r1*p1) / totalSupply`) is vulnerable to flash loan manipulation via reserve skewing. The Alpha Homora fair pricing formula eliminates this attack vector by using `sqrt(r0 * r1)` which is invariant under swaps (constant product property).

## Fair Pricing Formula

### Full Formula
```
LP_price = 2 * sqrt((r0 * p0) * (r1 * p1)) / totalSupply
```

### Token0 Denomination (Simplified)
Since we denominate in token0, `p0 = 1` (token0 priced in itself):
```
LP_price_in_token0 = 2 * sqrt(r0 * r1 * p1_in_token0) / totalSupply
```
Where `p1_in_token0 = IOracle(ORACLE).getQuote(10^token1Decimals, token1, token0)`

### Why Flash-Loan Resistant
- `k = r0 * r1` is invariant under swaps (constant product AMM)
- `p1_in_token0` comes from external oracle (TWAP/Chainlink), not manipulable in single tx
- `totalSupply` only changes on mint/burn, not swaps
- Attacker can change `r0/r1 ratio` but `sqrt(r0 * r1) = sqrt(k)` stays constant

## Technical Considerations

### Architecture
- Extends `AbstractYieldSourceOracle` (same as all other oracles)
- Constructor takes `(address superLedgerConfiguration_, address oracle_)` following DETHYieldSourceOracle pattern
- `oracle_` stored as immutable `IOracle ORACLE`
- Fully immutable: no admin, no pause, no upgrade

### Decimal Normalization
- LP tokens: always 18 decimals (UniV2 hardcoded)
- Underlying tokens: vary (USDC=6, WBTC=8, WETH=18)
- Reserves: in token-native decimals (uint112)
- IOracle.getQuote: returns in quote token decimals (token0 decimals)
- Output (getPricePerShare): must be in token0 decimals

**Strategy**: Normalize `r0 * r1 * p1_in_token0` via `Math.mulDiv` before sqrt, then scale result to token0 decimals.

### Arithmetic Safety
- `r0 * r1`: uint112 * uint112 = max ~2^224 bits, fits uint256 (safe)
- After decimal scaling: use `Math.mulDiv` to prevent intermediate overflow
- `Math.sqrt`: OZ implementation, rounds down (conservative for pricing)
- Division by `totalSupply`: check for zero

### IOracle Integration
```solidity
// Get price of 1 full unit of token1 in token0 terms
uint256 p1 = IOracle(ORACLE).getQuote(10 ** token1Decimals, token1, token0);
```
- Let `OracleUntrustedData` / `OracleUnsupportedPair` reverts propagate (hard revert pattern)
- Do NOT try/catch oracle calls for price queries

## Attack Surface Analysis

### Oracle Manipulation
- [x] Flash-loan reserve manipulation: MITIGATED by fair pricing formula (sqrt of k invariant)
- [x] External oracle manipulation: Delegated to IOracle implementation (must use TWAP/Chainlink)
- [x] Stale prices: Let IOracle.OracleUntrustedData revert propagate

### Arithmetic
- [x] Overflow in r0*r1: Safe (224 bits < 256 bits)
- [x] Overflow after scaling: Use Math.mulDiv throughout
- [x] sqrt precision: OZ Math.sqrt rounds down (conservative)
- [x] Division by zero: Check totalSupply > 0

### Reentrancy
- [x] All functions are view-only, no state changes
- [x] Read-only reentrancy: low risk for accounting oracle context

### Token Behavior
- [x] Fee-on-transfer: Out of scope (standard ERC20 only)
- [x] Rebasing: Out of scope
- [x] >18 decimals: Not supported (per SECURITY.md)

### Exploit Precedent
| Protocol | Year | Loss | Attack | Our Mitigation |
|----------|------|------|--------|----------------|
| Warp Finance | 2020 | $7.7M | Naive LP pricing via reserves | Fair pricing formula |
| Harvest Finance | 2020 | $34M | Oracle manipulation | External IOracle (not spot) |
| Alpha Homora | 2021 | $37M | Reentrancy in lending (NOT oracle) | N/A - oracle formula was sound |

## Acceptance Criteria

### Functional
- [ ] Extends `AbstractYieldSourceOracle`
- [ ] Implements all 8 abstract methods
- [ ] Uses Alpha Homora fair pricing formula
- [ ] Handles all decimal combinations (6/6, 6/18, 18/6, 18/18, 8/18)
- [ ] Works with any V2-compatible pair (Uniswap, Sushi, Pancake, etc.)
- [ ] Token0 denomination for all outputs

### Non-Functional
- [ ] No admin functions (fully immutable)
- [ ] No state changes (all view functions)
- [ ] Math.mulDiv used for all overflow-sensitive arithmetic
- [ ] Zero-checks on totalSupply and oracle prices

### Testing
- [ ] Unit tests with mocked pair and oracle
- [ ] Fork tests against real mainnet pairs (WETH/USDC)
- [ ] Fuzz tests for arithmetic edge cases
- [ ] Flash loan resistance invariant test

## Implementation

### Files to Create

1. `src/vendor/uniswap/IUniswapV2Pair.sol` - Extended interface
2. `src/accounting/oracles/UniV2LPYieldSourceOracle.sol` - Oracle implementation
3. `test/unit/accounting/oracles/UniV2LPYieldSourceOracle.t.sol` - Tests
4. `test/mocks/MockUniswapV2Pair.sol` - Mock pair for unit tests

### Files to Modify

1. `script/utils/Constants.sol` - Add oracle key/salt (lines ~309-333)
2. `script/DeployV2Core.s.sol` - Add to deployment (lines ~634-648, 3620-3669)

### 1. IUniswapV2Pair Interface

`src/vendor/uniswap/IUniswapV2Pair.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IUniswapV2Pair
/// @notice Extended interface for Uniswap V2 pair contracts
/// @dev Includes ERC20 methods needed for LP token oracle (totalSupply, balanceOf, decimals)
///      Compatible with all V2 forks (SushiSwap, PancakeSwap, etc.)
interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function decimals() external pure returns (uint8); // Always returns 18 for UniV2
}
```

### 2. Oracle Implementation

`src/accounting/oracles/UniV2LPYieldSourceOracle.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IOracle } from "../../vendor/awesome-oracles/IOracle.sol";
import { IUniswapV2Pair } from "../../vendor/uniswap/IUniswapV2Pair.sol";

/// @title UniV2LPYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Uniswap V2 LP tokens using Alpha Homora fair pricing formula
/// @dev Supports all V2-compatible DEX forks (SushiSwap, PancakeSwap, etc.)
///      Prices LP tokens in token0 terms using:
///        LP_price = 2 * sqrt(r0 * r1 * p1_in_token0) / totalSupply
///      where p1_in_token0 = IOracle.getQuote(10^token1Decimals, token1, token0)
///
///      Flash-loan resistant: sqrt(r0 * r1) is invariant under constant-product swaps.
///      External oracle prices (from IOracle) are not manipulable within a single tx.
///
///      Security: Fully immutable, no admin functions, no state changes.
///      All external calls are view functions. Oracle reverts propagate (hard revert pattern).
contract UniV2LPYieldSourceOracle is AbstractYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is provided
    error ZERO_ADDRESS();

    /// @notice Thrown when the pool has zero total supply (no LP tokens minted)
    error ZERO_TOTAL_SUPPLY();

    /// @notice Thrown when the oracle returns a zero price
    error ZERO_ORACLE_PRICE();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice LP token decimals (always 18 for UniV2)
    uint8 private constant LP_DECIMALS = 18;

    /// @notice One full LP token (10^18)
    uint256 private constant ONE_LP = 1e18;

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The external price oracle (EIP-7726) for underlying token pricing
    IOracle public immutable ORACLE;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructs the UniV2 LP oracle
    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract
    /// @param oracle_ Address of the IOracle (EIP-7726) for underlying token pricing
    constructor(
        address superLedgerConfiguration_,
        address oracle_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        if (oracle_ == address(0)) revert ZERO_ADDRESS();
        ORACLE = IOracle(oracle_);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns LP token decimals (always 18 for UniV2)
    function decimals(address) external pure override returns (uint8) {
        return LP_DECIMALS;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns LP tokens receivable for a given token0 amount
    /// @dev sharesOut = assetsIn * ONE_LP / pricePerShare
    function getShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        if (assetsIn == 0) return 0;

        uint256 pps = getPricePerShare(yieldSourceAddress);
        if (pps == 0) return 0;

        return Math.mulDiv(assetsIn, ONE_LP, pps);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns LP tokens to burn for a given token0 withdrawal amount
    /// @dev Uses Ceil rounding to favor the protocol (user burns slightly more LP)
    function getWithdrawalShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        if (assetsIn == 0) return 0;

        uint256 pps = getPricePerShare(yieldSourceAddress);
        if (pps == 0) return 0;

        return Math.mulDiv(assetsIn, ONE_LP, pps, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns token0 value for a given amount of LP tokens
    /// @dev assetsOut = sharesIn * pricePerShare / ONE_LP
    function getAssetOutput(
        address yieldSourceAddress,
        address,
        uint256 sharesIn
    )
        public
        view
        override
        returns (uint256)
    {
        if (sharesIn == 0) return 0;

        uint256 pps = getPricePerShare(yieldSourceAddress);
        return Math.mulDiv(sharesIn, pps, ONE_LP);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the fair price of one LP token in token0 terms
    /// @dev Uses Alpha Homora formula: 2 * sqrt(r0 * r1 * p1_in_token0) / totalSupply
    ///      The formula is flash-loan resistant because sqrt(r0*r1) is constant-product invariant.
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(yieldSourceAddress);

        // Get pool state
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        uint256 totalSupply = pair.totalSupply();
        if (totalSupply == 0) revert ZERO_TOTAL_SUPPLY();

        // Get token addresses and decimals
        address token0 = pair.token0();
        address token1 = pair.token1();
        uint8 token0Decimals = IERC20Metadata(token0).decimals();
        uint8 token1Decimals = IERC20Metadata(token1).decimals();

        // Get price of 1 full unit of token1 in token0 terms
        // p1_in_token0 is denominated in token0 decimals
        uint256 p1InToken0 = ORACLE.getQuote(10 ** token1Decimals, token1, token0);
        if (p1InToken0 == 0) revert ZERO_ORACLE_PRICE();

        // Compute: 2 * sqrt(r0 * r1 * p1_in_token0) / totalSupply
        //
        // Decimal analysis:
        //   r0 has token0Decimals precision
        //   r1 has token1Decimals precision
        //   p1InToken0 has token0Decimals precision (price of 10^token1Decimals token1 in token0)
        //
        //   r0 * r1 * p1InToken0 has (token0Decimals + token1Decimals + token0Decimals) precision
        //   After sqrt: (token0Decimals + token1Decimals + token0Decimals) / 2 precision
        //   We need result in token0Decimals precision (PPS = value of 1e18 LP in token0 terms)
        //   So we need to scale appropriately
        //
        // To avoid overflow and maintain precision:
        //   1. Compute k = r0 * r1 (safe: uint112 * uint112 = max 224 bits)
        //   2. Compute k * p1InToken0 via mulDiv if needed
        //   3. sqrt of the product
        //   4. Scale to token0Decimals and divide by totalSupply

        // Step 1: k = r0 * r1 (fits uint256, max 224 bits)
        uint256 k = uint256(reserve0) * uint256(reserve1);

        // Step 2: k * p1InToken0
        // k has (token0Decimals + token1Decimals) precision
        // p1InToken0 has token0Decimals precision
        // Product has (2*token0Decimals + token1Decimals) precision
        // This could overflow for large reserves + high prices, so use mulDiv to scale
        // We want: sqrt(k * p1InToken0 * 10^token0Decimals) to get result in token0Decimals after sqrt
        //
        // More precisely, we want the final PPS in token0Decimals, representing value of 1e18 LP tokens
        // PPS = 2 * sqrt(r0 * r1 * p1) * 1e18 / totalSupply
        // where r0 is in token0Decimals, r1 is in token1Decimals, p1 is in token0Decimals (per 1e(token1Dec) of token1)
        //
        // r1 * p1 / 10^token1Decimals = r1's value in token0 terms (in token0Decimals)
        // So r0 * (r1 * p1 / 10^token1Decimals) = product in 2*token0Decimals
        // sqrt of that = result in token0Decimals
        //
        // To maintain precision: sqrt(r0 * r1 * p1 / 10^token1Decimals)
        // = sqrt(mulDiv(k, p1InToken0, 10^token1Decimals))

        uint256 scaledProduct = Math.mulDiv(k, p1InToken0, 10 ** token1Decimals);
        uint256 sqrtValue = Math.sqrt(scaledProduct);

        // sqrtValue is now in token0Decimals precision
        // PPS = 2 * sqrtValue * ONE_LP / totalSupply
        // This gives price per 1e18 LP tokens in token0 terms
        return Math.mulDiv(2 * sqrtValue, ONE_LP, totalSupply);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns LP token balance of a given owner
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        external
        view
        override
        returns (uint256)
    {
        return IUniswapV2Pair(yieldSourceAddress).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns TVL in token0 terms for a given LP token holder
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        uint256 shares = IUniswapV2Pair(yieldSourceAddress).balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return getAssetOutput(yieldSourceAddress, address(0), shares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns total TVL of the LP pair in token0 terms
    /// @dev TVL = totalSupply * pricePerShare / ONE_LP
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(yieldSourceAddress);
        uint256 totalSupply = pair.totalSupply();
        if (totalSupply == 0) return 0;
        return getAssetOutput(yieldSourceAddress, address(0), totalSupply);
    }
}
```

### 3. Mock UniswapV2Pair

`test/mocks/MockUniswapV2Pair.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title MockUniswapV2Pair
/// @notice Mock for unit testing UniV2LPYieldSourceOracle
contract MockUniswapV2Pair {
    address public token0;
    address public token1;
    uint112 private _reserve0;
    uint112 private _reserve1;
    uint32 private _blockTimestampLast;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setReserves(uint112 reserve0_, uint112 reserve1_) external {
        _reserve0 = reserve0_;
        _reserve1 = reserve1_;
        _blockTimestampLast = uint32(block.timestamp);
    }

    function setTotalSupply(uint256 totalSupply_) external {
        _totalSupply = totalSupply_;
    }

    function setBalance(address account, uint256 amount) external {
        _balances[account] = amount;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}
```

### 4. Test File Structure

`test/unit/accounting/oracles/UniV2LPYieldSourceOracle.t.sol`

```solidity
// Key test cases:

// --- Unit Tests ---
test_decimals_returns18()
test_getPricePerShare_basicCalculation()
    // Known reserves, known oracle price -> verify exact PPS
test_getPricePerShare_differentDecimals_6_18()
test_getPricePerShare_differentDecimals_18_6()
test_getPricePerShare_sameDecimals_18_18()
test_getPricePerShare_sameDecimals_6_6()
test_getPricePerShare_revertsOnZeroTotalSupply()
test_getPricePerShare_revertsOnZeroOraclePrice()
test_getShareOutput_basicCalculation()
test_getShareOutput_returnsZeroForZeroInput()
test_getWithdrawalShareOutput_roundsUp()
test_getAssetOutput_basicCalculation()
test_getAssetOutput_returnsZeroForZeroInput()
test_getTVLByOwnerOfShares_correctValue()
test_getTVLByOwnerOfShares_returnsZeroForNoBalance()
test_getTVL_correctValue()
test_getBalanceOfOwner_correctBalance()

// --- Invariant Tests ---
test_swapInvariance()
    // PPS unchanged when r0/r1 changes but k stays constant
test_shareAssetRoundTrip()
    // getAssetOutput(getShareOutput(x)) <= x (rounding favors protocol)
test_ppsConsistency()
    // getPricePerShare(pair) == getAssetOutput(pair, _, 1e18)

// --- Fuzz Tests ---
testFuzz_getPricePerShare_noOverflow(uint112 r0, uint112 r1, uint256 p1)
testFuzz_getPricePerShare_alwaysPositive(uint112 r0, uint112 r1, uint256 p1)
testFuzz_shareAssetRoundTrip(uint256 assetsIn)
testFuzz_swapInvariance(uint112 r0, uint112 r1, uint256 swapAmt)

// --- Fork Tests (optional, mainnet) ---
test_fork_WETH_USDC_realPair()
test_fork_flashLoanResistance()
```

## References

### Internal
- `src/accounting/oracles/AbstractYieldSourceOracle.sol` - Base class
- `src/accounting/oracles/DETHYieldSourceOracle.sol` - Constructor pattern with extra immutable
- `src/accounting/oracles/SuperVaultYieldSourceOracle.sol` - getWithdrawalShareOutput inverse pattern
- `src/accounting/oracles/PendlePTYieldSourceOracle.sol` - Decimal normalization with Math.mulDiv
- `src/vendor/awesome-oracles/IOracle.sol` - EIP-7726 oracle interface
- `test/mocks/MockSuperOracle.sol` - Existing IOracle mock for testing

### External
- [Alpha Homora Fair LP Token Pricing](https://blog.alphaventuredao.io/fair-lp-token-pricing/)
- [cmichel: Pricing LP Tokens](https://cmichel.io/pricing-lp-tokens)
- [Warp Finance Exploit Analysis](https://slowmist.medium.com/analysis-of-warp-finance-hacked-incident-cb12a1af74cc)
- [OpenZeppelin Math.sol (mulDiv, sqrt)](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol)
