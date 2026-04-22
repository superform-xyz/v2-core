# Repository Research: Swap Hook Patterns in Superform v2-core

## 1. Architecture and Structure

All swap hooks reside in `src/hooks/swappers/`. Each protocol gets its own subdirectory.

**Dual-hook pattern**: Every swap integration produces two contracts:
1. **`SwapXxxHook`** - assumes input token pre-approved (1 execution)
2. **`ApproveAndSwapXxxHook`** - full approval lifecycle: approve(0) -> approve(amount) -> swap -> approve(0) (4 executions)

## 2. Data Encoding (BytesLib tightly-packed)

All hooks use `BytesLib` at `src/vendor/BytesLib.sol`. Fields are contiguous at fixed byte offsets:
- `address` = 20 bytes via `BytesLib.toAddress(data, offset)`
- `uint256` = 32 bytes via `BytesLib.toUint256(data, offset)`
- `bool` = 1 byte via `_decodeBool(data, offset)`

## 3. NATIVE Token Sentinel Pattern

**KyberSwap pattern** (recommended for Uni V2):
- Constructor accepts `nativeToken_` stored as `address public immutable NATIVE`
- Deployed with `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE` for most chains
- Balance check: `if (outputToken == NATIVE) { return account.balance; }`

## 4. Variable-Length Data

KyberSwap pattern: `uint256 txDataLength` at known offset, then `BytesLib.slice(data, offset_after_length, txDataLength)`.

For Uni V2 path: `uint256 pathLength` (number of addresses) + `pathLength * 20 bytes` of packed addresses.

## 5. usePrevHookAmount Pattern

- `HookDataUpdater.getUpdatedOutputAmount()` for proportional recalculation (used by Uni V3, Odos, Spark PSM)
- `ISuperHookResult(prevHook).getOutAmount(account)` to get previous hook's output

## 6. Balance-Delta Pattern

```solidity
_preExecute:  _setOutAmount(balance_before, account)
_postExecute: _setOutAmount(balance_after - balance_before, account)
```

## 7. Constructor Pattern

```solidity
constructor(address router_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
    if (router_ == address(0)) revert ADDRESS_NOT_VALID();
    ROUTER = IRouter(router_);
}
```

## 8. Test Patterns

Located at `test/unit/hooks/swappers/<protocol>/`. Use `MockSwapRouter`, `MockERC20`, `MockHook` for prevHook testing. Hook data constructed with `bytes.concat()`.

## 9. Deployment

- Hook key constants in `script/utils/Constants.sol`
- Router addresses per chain in `ConfigCore.sol`
- Locked bytecode in `script/locked-bytecode-dev/`
- No on-chain hook registry - hooks passed directly in `ExecutorEntry.hooksAddresses[]`

## 10. inspect() Pattern

Returns `abi.encodePacked(tokenOut)` for simple hooks. Used for off-chain inspection.
