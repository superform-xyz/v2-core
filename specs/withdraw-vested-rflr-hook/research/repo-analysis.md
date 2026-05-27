# Repository Analysis: WithdrawVestedRFLRHook

## Hook Architecture (BaseHook.sol)

Three-phase lifecycle: `preExecute -> hookExecutions -> postExecute`
- `_buildHookExecutions(prevHook, account, data)` — `view`, constructs Execution[] array
- `_preExecute(prevHook, account, data)` — snapshots balance, sets `asset`
- `_postExecute(prevHook, account, data)` — computes delta, stores outAmount
- Mutex protection via transient storage on pre/post execute

## Balance Delta Pattern

```solidity
// _preExecute:
asset = WFLR;
_setOutAmount(IERC20(WFLR).balanceOf(account), account);

// _postExecute:
uint256 currentBalance = IERC20(WFLR).balanceOf(account);
uint256 preBalance = getOutAmount(account);
uint256 delta = currentBalance > preBalance ? currentBalance - preBalance : 0;
_setOutAmount(delta, account);
```

## Existing WithdrawRFLRHook Pattern

- Constructor: `(address rNat_, address wflr_)` with `BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM)`
- Immutables: `RNAT`, `WFLR`
- Data layout: `[0:1] ack byte, [1:33] uint256 minOut`
- `_buildHookExecutions`: single execution calling `IRNat.withdrawAll(true)`
- Slippage: `BytesLib.toUint256(data, offset)` for minOut check

## SafeCast Usage

Standard pattern in codebase:
```solidity
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
using SafeCast for uint256;
someValue.toUint128();
```

Used in: BatchTransferFromHook, Swap1InchHook, PendlePTAmortizedOracle, MintSuperPositionsHook

## Critical Design Insight

`_buildHookExecutions` is `view` — it CAN call `IRNat.getBalancesOf(account)` to compute vested amount at build time. The zero-vested revert should happen here (earliest failure point).

## Files to Modify/Create

**New:**
- `src/hooks/claim/flare/WithdrawVestedRFLRHook.sol`
- `test/unit/hooks/claim/rflr/WithdrawVestedRFLRHookTest.t.sol`

**Modified:**
- `src/vendor/flare/IRNat.sol` — add `withdraw(uint128, bool)`
- `script/run/regenerate_bytecode.sh` — add to `RFLR_HOOK_CONTRACTS`
- `script/utils/ConstantsOtherHooks.sol` — add key constant
- `script/DeployV2OtherHooks.s.sol` — update struct + deploy function
- `script/run/deploy_v2_other_hooks_staging_prod.sh` — add to `RFLR_HOOKS` array

## Test Patterns

- Extends `Helpers` (-> `Test` + `Constants`)
- `setUp()`: `makeAddr()` for mocks, `new HookContract(...)`
- `vm.mockCall` for balanceOf, `vm.prank(account)` before pre/post execute
- `hook.setExecutionContext(account)` before calling pre/post
- `vm.expectRevert(Contract.ERROR.selector)` for revert tests
