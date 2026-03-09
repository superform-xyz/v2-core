# Repository Research: Spark PSM Hook Patterns

## 1. BaseHook Architecture (NONACCOUNTING + SWAP)

**File:** `src/hooks/BaseHook.sol`

All swap hooks extend `BaseHook` with:
- **HookType:** `HookType.NONACCOUNTING`
- **SubType:** `HookSubTypes.SWAP` (`keccak256(bytes("Swap"))` at `src/libraries/HookSubTypes.sol:25`)
- **Constructor:** `BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)`

**Key lifecycle (lines 122-156):**
1. `build()` wraps hook-specific executions with `preExecute` (first) and `postExecute` (last)
2. Derived hook implements `_buildHookExecutions()`, `_preExecute()`, and `_postExecute()`
3. Transient storage used for execution state tracking (mutex, outAmount)

## 2. Balance Tracking Pattern (_preExecute / _postExecute)

Every swap hook follows:

**_preExecute** - stores initial output token balance:
```solidity
function _preExecute(address, address account, bytes calldata data) internal override {
    address tokenOut = data.toAddress(20);
    _setOutAmount(IERC20(tokenOut).balanceOf(account), account);
}
```

**_postExecute** - computes delta:
```solidity
function _postExecute(address, address account, bytes calldata data) internal override {
    address tokenOut = data.toAddress(20);
    uint256 finalBalance = IERC20(tokenOut).balanceOf(account);
    uint256 initialBalance = getOutAmount(account);
    _setOutAmount(finalBalance - initialBalance, account);
}
```

**Examples:**
- `SwapOdosV2Hook` lines 97-103
- `ApproveAndSwapOdosV2Hook` lines 129-134
- `SwapUniswapV3Hook` lines 119-132
- `ApproveAndSwapUniswapV3Hook` lines 132-143

## 3. usePrevHookAmount & HookDataUpdater

**File:** `src/libraries/HookDataUpdater.sol` (lines 9-31)

When `usePrevHookAmount` is `true`:
1. Input amount replaced with `ISuperHookResult(prevHook).getOutAmount(account)`
2. Slippage/min output scaled using `HookDataUpdater.getUpdatedOutputAmount(newAmount, originalAmount, originalOutputAmount)`
3. Uses `PRECISION = 1e5` and `Math.mulDiv`

**For ExactIn:** replaces `amountIn`, scales `minAmountOut`
**For ExactOut:** replaces `amountOut`, scales `maxAmountIn`

Each hook implements:
```solidity
function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
    return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
}
```

## 4. Approve + Revoke Pattern

From `ApproveAndSwapUniswapV3Hook` lines 86-128:

```solidity
executions = new Execution[](4);
executions[0] = /* approve(PSM, 0) */        // Reset for USDT-like tokens
executions[1] = /* approve(PSM, amountIn) */ // Set exact approval
executions[2] = /* swap call */               // The actual swap
executions[3] = /* approve(PSM, 0) */        // Cleanup approval
```

Total with BaseHook wrapping: **6 executions** (preExecute + 4 + postExecute)
Non-approve hooks: **3 executions** (preExecute + 1 swap + postExecute)

## 5. Hook Data Encoding

Data is tightly packed using `bytes.concat`, decoded using `BytesLib` at specific byte offsets. No ABI encoding.

**Proposed ExactIn PSM data layout:**
```
address assetIn       = offset 0    (20 bytes)
address assetOut      = offset 20   (20 bytes)
uint256 amountIn      = offset 40   (32 bytes)
uint256 minAmountOut  = offset 72   (32 bytes)
address receiver      = offset 104  (20 bytes)
uint256 referralCode  = offset 124  (32 bytes)
bool usePrevHookAmount = offset 156 (1 byte)
```

**Proposed ExactOut PSM data layout:**
```
address assetIn       = offset 0    (20 bytes)
address assetOut      = offset 20   (20 bytes)
uint256 amountOut     = offset 40   (32 bytes)
uint256 maxAmountIn   = offset 72   (32 bytes)
address receiver      = offset 104  (20 bytes)
uint256 referralCode  = offset 124  (32 bytes)
bool usePrevHookAmount = offset 156 (1 byte)
```

## 6. Interface Pattern

Vendor interfaces go in `src/vendor/{protocol}/`. Examples:
- `src/vendor/odos/IOdosRouterV2.sol`
- `src/vendor/pendle/IPendleRouterV4.sol`

PSM interface should be at: `src/vendor/spark/IPSM3.sol`

## 7. inspect() Function

Returns output-related address packed. For PSM: return `assetOut` address.

## 8. Constructor Pattern

```solidity
constructor(address psmAddress_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
    if (psmAddress_ == address(0)) revert ADDRESS_NOT_VALID();
    PSM = IPSM3(psmAddress_);
}
```

## 9. Deployment Scripts

In `script/DeployV2Core.s.sol`:
1. Per-chain address mapping in `ConfigBase.sol`
2. Addresses configured in `ConfigCore.sol` (or `address(0)` to skip)
3. Availability flag in `ContractAvailability` struct
4. Conditional deployment in `_deployHooksSet()`
5. Hook key constants in `script/utils/Constants.sol` (line 155+)

## 10. Test Patterns

**Key test files:** `test/unit/hooks/swappers/odos/OdosUnitTests.t.sol`, `test/unit/hooks/swappers/uniswap-v3/UniswapV3UnitTests.t.sol`

**Structure:**
1. Test contract inherits `Helpers`
2. MockRouter inline contract implementing vendor interface
3. `setUp()` creates MockERC20 tokens, MockHook (prevHook), hook contracts
4. Helper `_buildHookData(bool usePrevHookAmount)` using `bytes.concat`

**Standard tests:**
- `test_Constructor()`, `test_Constructor_RevertIf_AddressZero()`
- `test_DecodeUsePrevHookAmount()`
- `test_Build()`, `test_Build_WithPrevHookAmount()`
- `test_Build_RevertIf_InvalidHookData()`
- `test_PreExecute()`, `test_PostExecute()`
- `test_SlippageRecalculation_VerifyValues()`
- `test_Inspect()`
- `testFuzz_SlippageRecalculation()`

## 11. File Organization

```
src/hooks/swappers/spark-psm/
    SwapSparkPSMExactInHook.sol
    ApproveAndSwapSparkPSMExactInHook.sol
    SwapSparkPSMExactOutHook.sol
    ApproveAndSwapSparkPSMExactOutHook.sol

src/vendor/spark/
    IPSM3.sol

test/unit/hooks/swappers/spark-psm/
    SparkPSMExactInUnitTests.t.sol
    SparkPSMExactOutUnitTests.t.sol
```

## 12. ExactOut Considerations

For ExactOut, semantics invert:
- `amountOut` is fixed/desired output
- `maxAmountIn` is slippage protection
- `usePrevHookAmount`: prev hook output becomes `amountOut`, `maxAmountIn` scaled proportionally

Balance tracking pattern remains the same (tracks output token delta).

## 13. Recipient Handling

**CRITICAL:** Force `receiver = account` regardless of hook data (line 185 of ApproveAndSwapUniswapV3Hook). Balance tracking requires output tokens to land in the account.
