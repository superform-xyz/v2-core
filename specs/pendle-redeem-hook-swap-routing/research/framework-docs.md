# Pendle Finance Router Integration Research Report

## 1. Summary

Pendle Finance is a DeFi protocol for tokenizing and trading future yields:
- **Standardized Yield (SY)** tokens as wrappers around yield-bearing assets
- **Principal Tokens (PT)** representing the principal value
- **Yield Tokens (YT)** representing the future yield
- **PendleRouterV4** as the main entry point for all operations

## 2. IPendleRouterV4 Interface - `redeemPyToToken`

**File**: `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IPendleRouterV4.sol`

```solidity
function redeemPyToToken(
    address receiver,
    address YT,
    uint256 netPyIn,
    TokenOutput calldata output
) external returns (uint256 netTokenOut, uint256 netSyInterm);
```

**Parameters**:
- `receiver`: Address that receives the output tokens
- `YT`: The Yield Token address (used to derive PT and SY)
- `netPyIn`: Amount of PT/YT to redeem (must have equal amounts)
- `output`: TokenOutput struct defining the desired output

**Internal Flow**:
```solidity
function redeemPyToToken(...) external returns (uint256 netTokenOut, uint256 netSyInterm) {
    address SY = IPYieldToken(YT).SY();
    netSyInterm = _redeemPyToSy(SY, YT, netPyIn, 1);
    netTokenOut = _redeemSyToToken(receiver, SY, netSyInterm, output, false);
}
```

## 3. TokenOutput Struct - tokenRedeemSy vs tokenOut

**File**: `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IPendleRouterV4.sol`

```solidity
struct TokenOutput {
    address tokenOut;        // Final token user receives
    uint256 minTokenOut;     // Minimum acceptable amount (slippage protection)
    address tokenRedeemSy;   // Token to redeem SY into (must be in SY.getTokensOut())
    address pendleSwap;      // Swap helper address (address(0) if no aggregator)
    SwapData swapData;       // Aggregator swap data
}
```

**Key Behavior**:

| Scenario | tokenOut | tokenRedeemSy | pendleSwap | swapData.swapType |
|----------|----------|---------------|------------|-------------------|
| Direct redemption (no swap) | Same as tokenRedeemSy | Valid SY output token | address(0) | SwapType.NONE |
| With aggregator swap | Different from tokenRedeemSy | Valid SY output token | Pendle swap helper | KYBERSWAP/ODOS/etc |
| ETH/WETH conversion | ETH or WETH | WETH or ETH | address(0) | SwapType.ETH_WETH |

## 4. IStandardizedYield Interface

**File**: `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IStandardizedYield.sol`

```solidity
/// @notice returns all tokens that can be redeemed by this SY
function getTokensOut() external view returns (address[] memory res);

/// @notice checks if a token is a valid output token
function isValidTokenOut(address token) external view returns (bool);

/// @notice returns all tokens that can mint this SY
function getTokensIn() external view returns (address[] memory res);

function isValidTokenIn(address token) external view returns (bool);
```

**Important**: The `tokenRedeemSy` in TokenOutput MUST be in `SY.getTokensOut()`.

## 5. SwapData Struct and SwapType Enum

```solidity
struct SwapData {
    SwapType swapType;    // Type of swap aggregator
    address extRouter;    // External router address
    bytes extCalldata;    // Calldata for the external router
    bool needScale;       // Whether to scale the calldata for different amounts
}

enum SwapType {
    NONE,           // 0 - No swap needed
    KYBERSWAP,      // 1
    ODOS,           // 2
    ETH_WETH,       // 3 - Special: wrap/unwrap ETH <-> WETH
    OKX,            // 4
    ONE_INCH,       // 5
    PARASWAP,       // 6
    RESERVE_2,      // 7
    RESERVE_3,      // 8
    RESERVE_4,      // 9
    RESERVE_5       // 10
}
```

**Note**: There's a discrepancy between your vendor interface and the actual Pendle contract:
- Your vendor: `RESERVE_1` at position 6
- Actual Pendle: `PARASWAP` at position 6

## 6. Native ETH Handling

**File**: `/Users/cosming/1.Coding/Superform/v2-core/lib/pendle-core-v2-public/contracts/core/libraries/TokenHelper.sol`

```solidity
address internal constant NATIVE = address(0);

function _wrap_unwrap_ETH(address tokenIn, address tokenOut, uint256 netTokenIn) internal {
    if (tokenIn == NATIVE) IWETH(tokenOut).deposit{value: netTokenIn}();
    else IWETH(tokenIn).withdraw(netTokenIn);
}
```

**Redemption Flow with Native ETH**:

```solidity
function _redeemSyToToken(...) internal returns (uint256 netTokenOut) {
    SwapType swapType = out.swapData.swapType;

    if (swapType == SwapType.NONE) {
        // Direct redemption - tokenOut must equal tokenRedeemSy
        netTokenOut = __redeemSy(receiver, SY, netSyIn, out, doPull);
    } else if (swapType == SwapType.ETH_WETH) {
        // ETH <-> WETH conversion
        netTokenOut = __redeemSy(address(this), SY, netSyIn, out, doPull);
        _wrap_unwrap_ETH(out.tokenRedeemSy, out.tokenOut, netTokenOut);
        _transferOut(out.tokenOut, receiver, netTokenOut);
    } else {
        // Aggregator swap
        uint256 netTokenRedeemed = __redeemSy(out.pendleSwap, SY, netSyIn, out, doPull);
        IPSwapAggregator(out.pendleSwap).swap(out.tokenRedeemSy, netTokenRedeemed, out.swapData);
        netTokenOut = _selfBalance(out.tokenOut);
        _transferOut(out.tokenOut, receiver, netTokenOut);
    }

    if (netTokenOut < out.minTokenOut) revert("Slippage: INSUFFICIENT_TOKEN_OUT");
}
```

**Native ETH Scenarios**:

1. **Redeem SY directly to ETH** (if SY supports native ETH):
   - `tokenRedeemSy = address(0)` (NATIVE)
   - `tokenOut = address(0)` (NATIVE)
   - `swapData.swapType = NONE`

2. **Redeem SY to WETH, then unwrap to ETH**:
   - `tokenRedeemSy = WETH_ADDRESS`
   - `tokenOut = address(0)` (NATIVE)
   - `swapData.swapType = ETH_WETH`

3. **Redeem SY to token, swap to ETH via aggregator**:
   - `tokenRedeemSy = some_token`
   - `tokenOut = address(0)` (NATIVE)
   - `swapData.swapType = ODOS/KYBERSWAP/etc`

## 7. Building TokenOutput for Different Scenarios

**Simple Redemption (no swap)**:
```solidity
TokenOutput memory output = TokenOutput({
    tokenOut: validSyOutputToken,
    minTokenOut: minAmount,
    tokenRedeemSy: validSyOutputToken, // Same as tokenOut
    pendleSwap: address(0),
    swapData: SwapData({
        swapType: SwapType.NONE,
        extRouter: address(0),
        extCalldata: "",
        needScale: false
    })
});
```

**With Odos Aggregator**:
```solidity
TokenOutput memory output = TokenOutput({
    tokenOut: desiredToken,            // Final token (e.g., USDC)
    minTokenOut: minAmount,
    tokenRedeemSy: syOutputToken,      // Must be in SY.getTokensOut()
    pendleSwap: pendleSwapHelper,
    swapData: SwapData({
        swapType: SwapType.ODOS,
        extRouter: odosRouterAddress,
        extCalldata: odosSwapCalldata,
        needScale: true
    })
});
```

**ETH Unwrap**:
```solidity
TokenOutput memory output = TokenOutput({
    tokenOut: address(0),              // Native ETH
    minTokenOut: minAmount,
    tokenRedeemSy: wethAddress,
    pendleSwap: address(0),
    swapData: SwapData({
        swapType: SwapType.ETH_WETH,
        extRouter: address(0),
        extCalldata: "",
        needScale: false
    })
});
```

## 8. Best Practices

1. **Always validate tokenRedeemSy**: Must be in `SY.getTokensOut()`

2. **Use Pendle SDK for aggregator swaps**: The SDK generates proper `pendleSwap` addresses and `swapData`

3. **Handle ETH/WETH carefully**: Check both `isValidTokenOut(address(0))` and `isValidTokenOut(WETH)`

4. **PT and YT amounts must match**: For redemption, need equal amounts

5. **Approve both PT and YT**: Your hook correctly approves both tokens to the router

## 9. References

**Source Files in Codebase**:
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IPendleRouterV4.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IStandardizedYield.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/lib/pendle-core-v2-public/contracts/router/ActionMiscV3.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/lib/pendle-core-v2-public/contracts/router/base/ActionBase.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/lib/pendle-core-v2-public/contracts/core/libraries/TokenHelper.sol`
