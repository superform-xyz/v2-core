# Repository Analysis: Swap Hook Patterns

## Hook Architecture
- All swap hooks extend `BaseHook` with `HookType.NONACCOUNTING` + `HookSubTypes.SWAP`
- Two variants per DEX: `SwapXxxHook` (1 execution) and `ApproveAndSwapXxxHook` (4 executions)
- Approval pattern: `approve(0)` -> `approve(amount)` -> swap -> `approve(0)`
- Balance tracking via `_preExecute`/`_postExecute` (delta = final - initial)
- Hook chaining via `ISuperHookContextAware` + `usePrevHookAmount`
- Recipient forced to `account` for balance tracking
- Router interfaces in `interfaces/` subdirectory

## File Organization
```
src/hooks/swappers/<protocol>/
    SwapXxxHook.sol
    ApproveAndSwapXxxHook.sol
    interfaces/IXxxRouter.sol
test/unit/hooks/swappers/<protocol>/XxxUnitTests.t.sol
```

## Deployment Pattern
- Hook keys in `script/utils/Constants.sol` (internal) and `test/utils/Constants.sol` (public)
- Router addresses in `ConfigBase.sol` as `mapping(uint64 chainId => address)`
- Router config in `ConfigCore.sol`
- Deployment in `DeployV2Core.s.sol` via `_createSafeHookDeploymentWithArgs()`
- Availability checked per chain before deploying

## Code Conventions
- Solidity 0.8.30, Apache-2.0 license
- `using BytesLib for bytes;`
- SCREAMING_SNAKE_CASE for errors and constants
- NatSpec on all public/external functions
- Data layout documented in contract-level NatSpec
