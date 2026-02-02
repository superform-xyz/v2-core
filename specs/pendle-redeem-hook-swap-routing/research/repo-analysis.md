# Repository Research Summary

## Architecture and Structure

### Existing Pendle Hooks Location
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/pendle/PendleRouterSwapHook.sol` (lines 1-285)
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/pendle/PendleRouterRedeemHook.sol` (lines 1-207)

### Base Hook Architecture
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/BaseHook.sol` (lines 1-364)
  - All hooks inherit from `BaseHook`
  - Uses transient storage for inter-hook communication
  - Implements lifecycle: `build()` -> `preExecute()` -> hook operations -> `postExecute()`
  - `_buildHookExecutions()` is the abstract method hooks must implement (line 224-232)
  - `_decodeBool()` helper at line 260-262

## Existing Pendle Hook Patterns

### PendleRouterSwapHook (lines 1-285)
Data structure (documented at lines 28-32):
```
bytes32 placeholder (0-31)
address yieldSource (32-51) - this is the pendleMarket
bool usePrevHookAmount (52)
uint256 value (53-84)
bytes txData (85+)
```
- Supports TWO selectors (lines 110-138 in `inspect()` and lines 167-231 in `_validateTxData()`):
  - `swapExactTokenForPt` - Token to PT swap
  - `swapExactPtForToken` - PT to Token swap
- Uses `USE_PREV_HOOK_AMOUNT_POSITION = 52` (line 36)
- tokenOut is determined by decoding the selector type (lines 247-260 `_decodeTokenOut()`)

### PendleRouterRedeemHook (lines 1-207)
Data structure (documented at lines 19-26):
```
uint256 amount (0-31)
address yt (32-51)
address pt (52-71)
address tokenOut (72-91)
uint256 minTokenOut (92-123)
bool usePrevHookAmount (124)
bytes TokenOutput struct (125+)
```
- Uses `USE_PREV_HOOK_AMOUNT_POSITION = 124` (line 31)
- Supports SINGLE selector: `redeemPyToToken`
- Has explicit tokenOut in data layout (offset 72)
- Validates tokenOut against SY's valid token list (lines 163-169)

## Pattern: Multiple Selector Handling

### 1inch Hook Pattern
`/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/1inch/Swap1InchHook.sol`
- Handles THREE selectors (lines 101-127 in `inspect()` and lines 143-174 in `_validateTxData()`):
  - `unoswapTo`
  - `swap`
  - `clipperSwapTo`
- Each selector has its own validation function (lines 176-260, 262-307, 309-361)
- All share the same data layout pattern

### SpectraExchangeRedeemHook
`/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/spectra/SpectraExchangeRedeemHook.sol`
- Handles TWO commands via a `command` byte in data (lines 84-108):
  - `REDEEM_IBT_FOR_ASSET`
  - `REDEEM_PT_FOR_ASSET`
- Uses a `RedeemParams` struct for decoded parameters (lines 44-52)

## Key Libraries and Interfaces

### HookDataDecoder
`/Users/cosming/1.Coding/Superform/v2-core/src/libraries/HookDataDecoder.sol`
- `extractYieldSourceOracleId(data)` - bytes32 at offset 0 (line 10-12)
- `extractYieldSource(data)` - address at offset 32 (line 14-16)

### HookSubTypes
`/Users/cosming/1.Coding/Superform/v2-core/src/libraries/HookSubTypes.sol`
- `PTYT = keccak256(bytes("PTYT"))` (line 28) - Used by both Pendle hooks

### IPendleRouterV4
`/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IPendleRouterV4.sol`
- `swapExactTokenForPt` (lines 87-97)
- `swapExactPtForToken` (lines 99-107)
- `redeemPyToToken` (lines 109-116)
- `TokenInput` struct (lines 12-18)
- `TokenOutput` struct (lines 56-62)

### IStandardizedYield
`/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IStandardizedYield.sol`
- `isValidTokenOut(token)` - Validates if token can be redeemed (line 153)
- `getTokensOut()` - Returns all valid output tokens (line 149)

## Test Patterns

**Test File Location**: `/Users/cosming/1.Coding/Superform/v2-core/test/unit/hooks/pendle/`
- `PendleRouterSwapHook.t.sol` (1357 lines)
- `PendleRouterRedeemHook.t.sol` (507 lines)
- `PendleRouterSwapHookDecode.t.sol` (131 lines)

### Test Setup Pattern (from PendleRouterSwapHook.t.sol lines 26-67):
```solidity
contract PendleRouterSwapHookTest is Helpers {
    PendleRouterSwapHook public hook;
    MockPendleRouter public pendleRouter;
    MockHook public prevHook;

    function setUp() public {
        pendleRouter = new MockPendleRouter(...);
        market = address(new MockPendleMarket(...));
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(inputToken));
        hook = new PendleRouterSwapHook(address(pendleRouter));
    }
}
```

### Test Data Creation Pattern (from PendleRouterRedeemHook.t.sol lines 481-506):
```solidity
function _createRedeemData(...) internal pure returns (bytes memory) {
    TokenOutput memory output = TokenOutput({...});
    bytes memory tokenOutput = abi.encode(output);
    return abi.encodePacked(amount_, yt_, pt_, tokenOut_, minTokenOut_, usePrevHookAmount_, tokenOutput);
}
```

## inspect() Implementation Pattern

### From PendleRouterSwapHook (lines 106-139):
```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory packed) {
    bytes calldata txData_ = data[85:];
    bytes4 selector = bytes4(txData_[0:4]);

    if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
        packed = abi.encodePacked(yieldSource, receiver, market, input.tokenIn, ...);
    } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
        packed = abi.encodePacked(yieldSource, receiver, market, output.tokenOut, ...);
    }
}
```

### From PendleRouterRedeemHook (lines 117-120):
```solidity
function inspect(bytes calldata data) external view override returns (bytes memory) {
    DecodedParams memory params = _decodeAndValidateData(data);
    return abi.encodePacked(params.yt, params.pt, params.tokenOut);
}
```

## Recommendations for PendleUnifiedHook

1. **Data Layout Strategy**:
   - Detect operation from function selector in txData (like current SwapHook pattern)
   - Keep similar data layout for smooth off-chain transition

2. **Required Selectors to Support**:
   - `swapExactTokenForPt` (Token -> PT)
   - `swapExactPtForToken` (PT -> Token)
   - `redeemPyToToken` (PT+YT -> Token)

3. **Key Files to Reference**:
   - Base structure: `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/BaseHook.sol`
   - Multi-selector pattern: `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/1inch/Swap1InchHook.sol`
   - Command pattern: `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/spectra/SpectraExchangeRedeemHook.sol`
   - TokenOut validation: `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/pendle/PendleRouterRedeemHook.sol` lines 163-169
