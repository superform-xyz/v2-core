# Repository Analysis: Uniswap V3 Hook Implementation

## Executive Summary

This document provides a comprehensive analysis of the v2-core repository patterns for implementing `SwapUniswapV3Hook` and `ApproveAndSwapUniswapV3Hook` for Hyperliquid deployment (Project X DEX - a Uni V3 fork).

---

## 1. BaseHook Contract Analysis

**File:** `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/BaseHook.sol`

### Core Interface Requirements

The `BaseHook` contract is the foundation for all hooks. Key aspects:

```solidity
abstract contract BaseHook is ISuperHook, ISuperHookSetter, ISuperHookResult, ISuperHookInspector {
    // Transient storage variables
    uint256 public transient usedShares;
    address public transient spToken;
    address public transient asset;
    uint256 public transient executionNonce;
    address public transient lastCaller;

    // Constructor params
    constructor(ISuperHook.HookType hookType_, bytes32 subType_) {
        hookType = hookType_;
        SUB_TYPE = subType_;
    }
}
```

### Required Methods to Override

1. **`_buildHookExecutions`** - Build the array of Execution structs (the core hook operations)
2. **`_preExecute`** - Called before execution, typically stores initial balance for output calculation
3. **`_postExecute`** - Called after execution, calculates and sets `outAmount`

### Build Flow Pattern

The base `build()` method automatically wraps hook executions:
```solidity
function build(...) returns (Execution[] memory executions) {
    Execution[] memory hookExecutions = _buildHookExecutions(...);
    executions = new Execution[](hookExecutions.length + 2);

    // FIRST: preExecute
    executions[0] = Execution({...preExecute...});

    // MIDDLE: hook-specific operations
    for (uint256 i = 0; i < hookExecutions.length; i++) {
        executions[i + 1] = hookExecutions[i];
    }

    // LAST: postExecute
    executions[executions.length - 1] = Execution({...postExecute...});
}
```

---

## 2. ISuperHook Interface

**File:** `/Users/cosming/1.Coding/Superform/v2-core/src/interfaces/ISuperHook.sol`

### Hook Types
```solidity
enum HookType {
    NONACCOUNTING,  // Swap hooks use this - doesn't affect accounting
    INFLOW,         // Deposits
    OUTFLOW         // Withdrawals
}
```

### Key Interfaces to Implement

1. **`ISuperHookContextAware`** - For `usePrevHookAmount` pattern
   ```solidity
   function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool);
   ```

2. **`ISuperHookInspector`** - For hook data inspection
   ```solidity
   function inspect(bytes calldata data) external view returns (bytes memory argsEncoded);
   ```

---

## 3. Existing Swapper Hook Patterns

### 3.1 SwapOdosV2Hook (Simpler Pattern)

**File:** `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/odos/SwapOdosV2Hook.sol`

**Data Structure:**
```solidity
/// @notice address inputToken = BytesLib.toAddress(data, 0);
/// @notice uint256 inputAmount = BytesLib.toUint256(data, 20);
/// @notice address inputReceiver = BytesLib.toAddress(data, 52);
/// @notice address outputToken = BytesLib.toAddress(data, 72);
/// @notice uint256 outputQuote = BytesLib.toUint256(data, 92);
/// @notice uint256 outputMin = BytesLib.toUint256(data, 124);
/// @notice bool usePrevHookAmount = _decodeBool(data, 156);
/// @notice uint256 pathDefinition_paramLength = BytesLib.toUint256(data, 157);
/// @notice bytes pathDefinition = BytesLib.slice(data, 189, pathDefinition_paramLength);
/// @notice address executor = BytesLib.toAddress(data, 189 + pathDefinition_paramLength);
/// @notice uint32 referralCode = BytesLib.toUint32(data, 189 + pathDefinition_paramLength + 20);
```

**Pattern Features:**
- Router has token approval already (tokens transferred directly to router)
- Single execution in `_buildHookExecutions`
- Uses `HookDataUpdater.getUpdatedOutputAmount()` for dynamic slippage

### 3.2 ApproveAndSwapOdosV2Hook (With Approval Pattern)

**File:** `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol`

**Key Difference: 4 Executions:**
```solidity
executions = new Execution[](4);
executions[0] = Execution({  // Approve 0 (reset)
    target: params.inputToken,
    callData: abi.encodeCall(IERC20.approve, (params.approveSpender, 0))
});
executions[1] = Execution({  // Approve amount
    target: params.inputToken,
    callData: abi.encodeCall(IERC20.approve, (params.approveSpender, params.inputAmount))
});
executions[2] = Execution({  // Swap
    target: address(ODOS_ROUTER_V2),
    callData: abi.encodeCall(IOdosRouterV2.swap, (...))
});
executions[3] = Execution({  // Approve 0 (cleanup)
    target: params.inputToken,
    callData: abi.encodeCall(IERC20.approve, (params.approveSpender, 0))
});
```

### 3.3 SwapUniswapV4Hook (Complex Pattern with Callbacks)

**File:** `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol`

**Data Structure:**
```solidity
/// @notice address currency0 = BytesLib.toAddress(data, 0);
/// @notice address currency1 = BytesLib.toAddress(data, 20);
/// @notice uint24 fee = uint24(BytesLib.toUint32(data, 40));
/// @notice int24 tickSpacing = int24(BytesLib.toUint32(data, 44));
/// @notice address hooks = BytesLib.toAddress(data, 48);
/// @notice address dstReceiver = BytesLib.toAddress(data, 68);
/// @notice uint160 sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 88));
/// @notice uint256 originalAmountIn = BytesLib.toUint256(data, 120);
/// @notice uint256 originalMinAmountOut = BytesLib.toUint256(data, 152);
/// @notice uint256 maxSlippageDeviationBps = BytesLib.toUint256(data, 184);
/// @notice bool zeroForOne = _decodeBool(data, 216);
/// @notice bool usePrevHookAmount = _decodeBool(data, 217);
/// @notice bytes additionalData = BytesLib.slice(data, 218, data.length - 218);
```

**Complex Features:**
- Implements `IUnlockCallback` for Uniswap V4's lock mechanism
- Uses transient storage for unlock data
- Dynamic slippage recalculation via `_calculateDynamicMinAmount`
- Handles both native ETH and ERC-20 tokens

### 3.4 Swap1InchHook (Transaction Data Validation Pattern)

**File:** `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/1inch/Swap1InchHook.sol`

**Data Structure:**
```solidity
/// @notice address dstToken = BytesLib.toAddress(data, 0);
/// @notice address dstReceiver = BytesLib.toAddress(data, 20);
/// @notice uint256 value = BytesLib.toUint256(data, 40);
/// @notice bool usePrevHookAmount = _decodeBool(data, 72);
/// @notice bytes txData_ = BytesLib.slice(data, 73, data.length - 73);
```

**Pattern: Validates and modifies transaction data:**
- Supports multiple selector types (unoswapTo, swap, clipperSwapTo)
- Validates receiver, destination token, amounts
- Modifies txData when `usePrevHookAmount` is true

---

## 4. Native ETH vs ERC-20 Token Handling

### Pattern from all hooks:

**_getBalance helper:**
```solidity
function _getBalance(address account, bytes memory data) private view returns (uint256) {
    address outputToken = BytesLib.toAddress(data, OFFSET);

    if (outputToken == address(0)) {
        return account.balance;  // Native ETH
    }

    return IERC20(outputToken).balanceOf(account);
}
```

**Native value in Execution:**
```solidity
executions[0] = Execution({
    target: address(ROUTER),
    value: inputToken == address(0) ? inputAmount : 0,  // ETH value
    callData: ...
});
```

---

## 5. Dynamic Slippage Recalculation

### From SwapUniswapV4Hook:

```solidity
function _calculateDynamicMinAmount(RecalculationParams memory params)
    internal
    pure
    returns (uint256 newMinAmountOut)
{
    // Calculate new minAmountOut proportionally
    newMinAmountOut = Math.mulDiv(
        params.originalMinAmountOut,
        params.actualAmountIn,
        params.originalAmountIn
    );

    // Calculate ratio deviation in basis points
    uint256 amountRatio = (params.actualAmountIn * 1e18) / params.originalAmountIn;
    uint256 ratioDeviationBps = _calculateRatioDeviationBps(amountRatio);

    if (ratioDeviationBps > params.maxSlippageDeviationBps) {
        revert EXCESSIVE_SLIPPAGE_DEVIATION(ratioDeviationBps, params.maxSlippageDeviationBps);
    }
}
```

### From HookDataUpdater Library:

**File:** `/Users/cosming/1.Coding/Superform/v2-core/src/libraries/HookDataUpdater.sol`

```solidity
function getUpdatedOutputAmount(
    uint256 amount,
    uint256 _prevAmount,
    uint256 outputAmount
) internal pure returns (uint256) {
    if (_prevAmount == 0) return outputAmount;
    if (amount != _prevAmount) {
        if (amount > _prevAmount) {
            uint256 percentIncrease = Math.mulDiv(amount - _prevAmount, PRECISION, _prevAmount);
            outputAmount = outputAmount + Math.mulDiv(outputAmount, percentIncrease, PRECISION);
        } else {
            uint256 percentDecrease = Math.mulDiv(_prevAmount - amount, PRECISION, _prevAmount);
            uint256 decreaseAmount = Math.mulDiv(outputAmount, percentDecrease, PRECISION);
            outputAmount = outputAmount - decreaseAmount;
        }
    }
    return outputAmount;
}
```

---

## 6. usePrevHookAmount Pattern

### Standard Implementation:

```solidity
uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = XX;  // Byte offset

// In _buildHookExecutions or helper:
bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
if (usePrevHookAmount) {
    inputAmount = ISuperHookResult(prevHook).getOutAmount(account);
}

// External decoder function (required by ISuperHookContextAware):
function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
    return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
}
```

---

## 7. preExecute/postExecute Flow

### Standard Pattern (from Odos hooks):

```solidity
function _preExecute(address, address account, bytes calldata data) internal override {
    // Store initial balance of output token
    _setOutAmount(_getBalance(account, data), account);
}

function _postExecute(address, address account, bytes calldata data) internal override {
    // Calculate actual output: current balance - initial balance
    _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
}
```

### Alternative Pattern (from V4 hook - more complex):

```solidity
function _preExecute(address prevHook, address account, bytes calldata data) internal override {
    // Store asset info
    (asset,) = _getTransferParams(prevHook, account, data);

    // Get initial balance
    address outputToken = _getOutputToken(data);
    address dstReceiver = data.toAddress(68);
    if (outputToken == address(0)) {
        initialBalance = dstReceiver.balance;
    } else {
        initialBalance = IERC20(outputToken).balanceOf(dstReceiver);
    }

    // Prepare unlock data for postExecute
    bytes memory unlockData = _prepareUnlockData(prevHook, account, data);
    _storeUnlockData(unlockData);
}

function _postExecute(address, address account, bytes calldata data) internal override {
    // Execute the actual swap (via callback)
    bytes memory unlockData = _loadUnlockData();
    bytes memory unlockResult = POOL_MANAGER.unlock(unlockData);
    _clearUnlockData();

    // Verify and set output
    uint256 outputAmount = abi.decode(unlockResult, (uint256));
    _setOutAmount(outputAmount, account);
}
```

---

## 8. BytesLib Usage Patterns

**File:** `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/BytesLib.sol`

### Common Functions:

```solidity
// Read address at offset
address token = BytesLib.toAddress(data, 0);        // 20 bytes
address receiver = BytesLib.toAddress(data, 20);    // next 20 bytes

// Read uint256 at offset
uint256 amount = BytesLib.toUint256(data, 40);      // 32 bytes

// Read smaller integers
uint24 fee = uint24(BytesLib.toUint32(data, 72));   // 4 bytes for uint32, cast to uint24
int24 tickSpacing = int24(int32(BytesLib.toUint32(data, 76)));

// Read boolean (using BaseHook helper)
bool flag = _decodeBool(data, 80);                  // 1 byte

// Slice variable-length data
bytes memory path = BytesLib.slice(data, 81, pathLength);
```

### Offset Calculation:
- `address` = 20 bytes
- `uint256` = 32 bytes
- `uint128` = 16 bytes
- `uint32` = 4 bytes
- `bool` = 1 byte
- `bytes32` = 32 bytes

---

## 9. HookSubTypes

**File:** `/Users/cosming/1.Coding/Superform/v2-core/src/libraries/HookSubTypes.sol`

For swap hooks, use:
```solidity
bytes32 public constant SWAP = keccak256(bytes("Swap"));
```

Constructor pattern:
```solidity
constructor(address router_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
    // ...
}
```

---

## 10. Test Patterns

**File:** `/Users/cosming/1.Coding/Superform/v2-core/test/unit/hooks/swappers/odos/OdosUnitTests.t.sol`

### Test Structure:

```solidity
contract SwapHookTest is Helpers {
    SwapHook public hook;
    MockHook public prevHook;
    MockERC20 public inputToken;
    MockERC20 public outputToken;

    function setUp() public {
        // Deploy mock tokens
        inputToken = new MockERC20("Input", "IN", 18);
        outputToken = new MockERC20("Output", "OUT", 18);

        // Deploy mock router
        router = new MockRouter();

        // Deploy hook
        hook = new SwapHook(address(router));

        // Deploy prev hook for chaining tests
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(inputToken));
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(hook.ROUTER()), address(router));
    }

    function test_Build() public view {
        bytes memory data = _buildHookData(false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // Verify execution count (hookExecutions + 2 for pre/post)
        assertEq(executions.length, EXPECTED_COUNT);
    }

    function test_PreExecute() public {
        bytes memory data = _buildHookData(false);
        outputToken.mint(account, 500);

        hook.preExecute(address(0), account, data);

        assertEq(hook.getOutAmount(account), 500);
    }

    function test_PostExecute() public {
        bytes memory data = _buildHookData(false);
        outputToken.mint(account, 500);

        hook.preExecute(address(0), account, data);
        outputToken.mint(account, 300);  // Simulate swap output
        hook.postExecute(address(0), account, data);

        assertEq(hook.getOutAmount(account), 300);  // Delta
    }

    function _buildHookData(bool usePrevious) internal view returns (bytes memory) {
        return bytes.concat(
            bytes20(inputToken),
            bytes32(inputAmount),
            // ... more fields
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            // ... more fields
        );
    }
}
```

---

## 11. Uniswap V3 SwapRouter Interface

**File:** `/Users/cosming/1.Coding/Superform/v2-core/lib/modulekit/src/integrations/interfaces/uniswap/v3/ISwapRouter.sol`

### Key Structs and Functions:

```solidity
interface ISwapRouter is IUniswapV3SwapCallback {
    // Single hop exact input
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params)
        external payable returns (uint256 amountOut);

    // Multi-hop exact input
    struct ExactInputParams {
        bytes path;                  // Encoded path: tokenIn, fee, tokenOut, fee, tokenOut...
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }
    function exactInput(ExactInputParams calldata params)
        external payable returns (uint256 amountOut);

    // Single hop exact output
    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }
    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external payable returns (uint256 amountIn);

    // Multi-hop exact output
    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }
    function exactOutput(ExactOutputParams calldata params)
        external payable returns (uint256 amountIn);
}
```

---

## 12. Recommended Implementation for SwapUniswapV3Hook

### Data Structure (Recommended):

```solidity
/// @notice address tokenIn = BytesLib.toAddress(data, 0);
/// @notice address tokenOut = BytesLib.toAddress(data, 20);
/// @notice uint24 fee = uint24(BytesLib.toUint32(data, 40));
/// @notice address recipient = BytesLib.toAddress(data, 44);
/// @notice uint256 amountIn = BytesLib.toUint256(data, 64);
/// @notice uint256 amountOutMinimum = BytesLib.toUint256(data, 96);
/// @notice uint160 sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 128));
/// @notice bool usePrevHookAmount = _decodeBool(data, 160);
/// @notice bytes path = BytesLib.slice(data, 161, data.length - 161); // Optional for multi-hop
```

**Total fixed size: 161 bytes + variable path length**

### Constructor Pattern:

```solidity
contract SwapUniswapV3Hook is BaseHook, ISuperHookContextAware {
    ISwapRouter public immutable UNISWAP_V3_ROUTER;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 160;

    constructor(address swapRouter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (swapRouter_ == address(0)) revert ADDRESS_NOT_VALID();
        UNISWAP_V3_ROUTER = ISwapRouter(swapRouter_);
    }
}
```

### ApproveAndSwapUniswapV3Hook Pattern:

Same data structure, but with 4 executions:
1. Approve 0 (reset)
2. Approve inputAmount
3. Swap
4. Approve 0 (cleanup)

---

## 13. Key Differences from V4 Hook

| Aspect | V4 Hook | V3 Hook (Recommended) |
|--------|---------|----------------------|
| Router Type | Pool Manager with unlock/callback | Direct SwapRouter call |
| Native ETH | Handled via Currency type | Handled via msg.value |
| Complexity | Very high (callbacks, transient storage) | Medium (direct calls) |
| Approval | Not needed (singleton architecture) | Needed for ERC-20 |
| Data Format | PoolKey-based | SwapParams-based |

---

## 14. Error Handling Patterns

Common errors to implement:
```solidity
error ADDRESS_NOT_VALID();          // From BaseHook
error AMOUNT_NOT_VALID();           // From BaseHook
error INSUFFICIENT_OUTPUT_AMOUNT(uint256 actual, uint256 minimum);
error INVALID_HOOK_DATA();
error INVALID_RECIPIENT();
error DEADLINE_EXPIRED();
error INVALID_PATH();
```

---

## 15. File Organization

Recommended structure:
```
src/hooks/swappers/uniswap-v3/
  - SwapUniswapV3Hook.sol
  - ApproveAndSwapUniswapV3Hook.sol

src/vendor/uniswap/v3/
  - ISwapRouter.sol  (already exists in lib/modulekit)

test/unit/hooks/swappers/uniswap-v3/
  - SwapUniswapV3Hook.t.sol
  - ApproveAndSwapUniswapV3Hook.t.sol
```

---

## 16. Implementation Checklist

### SwapUniswapV3Hook:
- [ ] Inherit from `BaseHook`, `ISuperHookContextAware`
- [ ] Implement `_buildHookExecutions` with single router call
- [ ] Implement `_preExecute` to store initial balance
- [ ] Implement `_postExecute` to calculate output delta
- [ ] Implement `decodeUsePrevHookAmount`
- [ ] Implement `inspect` for hook data inspection
- [ ] Handle native ETH vs ERC-20 in execution value
- [ ] Support `exactInputSingle` for simple swaps
- [ ] Optional: Support `exactInput` for multi-hop swaps
- [ ] Dynamic slippage recalculation using `HookDataUpdater`

### ApproveAndSwapUniswapV3Hook:
- [ ] Same as above
- [ ] Add approval executions (reset -> approve -> swap -> reset)
- [ ] 4 executions total in `_buildHookExecutions`

### Tests:
- [ ] Constructor tests (valid/invalid addresses)
- [ ] `decodeUsePrevHookAmount` tests
- [ ] `build` tests with and without `usePrevHookAmount`
- [ ] `preExecute` and `postExecute` balance tracking
- [ ] Native ETH swap tests
- [ ] ERC-20 swap tests
- [ ] `inspect` function tests
- [ ] Integration tests with forked mainnet (optional)

---

## Summary

The v2-core repository follows consistent patterns for swap hooks:

1. **Inherit BaseHook** with `HookType.NONACCOUNTING` and `HookSubTypes.SWAP`
2. **Use BytesLib** for tightly-packed data decoding
3. **Implement ISuperHookContextAware** for hook chaining with `usePrevHookAmount`
4. **Calculate output via balance delta** in `_preExecute`/`_postExecute`
5. **Use HookDataUpdater** for dynamic slippage adjustment
6. **Handle native ETH** by checking `address(0)` and using `account.balance`
7. **Approve pattern** for hooks that need token approval (reset-approve-swap-reset)

For Uniswap V3, the implementation should be simpler than V4 since it uses direct router calls instead of the complex unlock/callback pattern.
