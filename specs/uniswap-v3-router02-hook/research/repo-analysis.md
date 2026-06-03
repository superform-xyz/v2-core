# Repository Analysis: Uniswap V3 Router02 Hook Patterns

## BaseHook Lifecycle
- `BaseHook.sol` (lines 18-364): `build()` wraps hook executions with `preExecute`/`postExecute`
- All swap hooks: `HookType.NONACCOUNTING`, `HookSubTypes.SWAP`
- Pattern: `_preExecute` stores initial balance, `_postExecute` computes delta

## Existing V1 Hook Structure
- `SwapUniswapV3Hook.sol`: 1 execution (swap only), 193-byte data layout
- `ApproveAndSwapUniswapV3Hook.sol`: 4 executions (approve(0), approve(amt), swap, approve(0))
- Both share `_decodeSwapParams()` helper, force `recipient = account`

## Improvements from AlgebraIntegral Hook (adopt in Router02)
- `if (tokenIn == tokenOut) revert INVALID_HOOK_DATA()` validation
- `if (amountIn == 0) revert AMOUNT_NOT_VALID()` validation
- Overflow check in `_postExecute`: `if (finalBalance < initialBalance) revert AMOUNT_NOT_VALID()`

## Config Pattern
- `ConfigBase.sol:30`: `mapping(uint64 chainId => address) uniswapV3SwapRouters`
- `ConfigCore.sol:317-334`: Per-chain address entries
- `Constants.sol:188-189`: Hook key strings

## Deployment Script (DeployV2Core.s.sol)
- `ContractAvailability` struct needs new bool
- Availability check (lines 459-465) pattern
- Bytecode check pattern (lines 1427-1443)
- Hook deployment array (lines 2677-2694)

## Bytecode Regeneration
- `script/run/regenerate_bytecode.sh`: Add contract names to `HOOK_CONTRACTS` array

## Test Structure
- Unit: `test/unit/hooks/swappers/uniswap-v3/UniswapV3UnitTests.t.sol` (943 lines)
- Integration: `test/integration/uniswap-v3/UniswapV3HookIntegrationTest.t.sol`
- Uses `MockSwapRouter`, `MockERC20`, `MockHook`
- Integration uses `MinimalBaseIntegrationTest` with Ethereum mainnet fork

## Key Data Layout Comparison
| Field | V1 Offset | Router02 Offset |
|-------|-----------|-----------------|
| tokenIn | 0 | 0 |
| tokenOut | 20 | 20 |
| fee | 40 | 40 |
| recipient | 44 | removed (forced to account) |
| deadline | 64 | removed |
| sqrtPriceLimitX96 | 96 | 44 |
| originalAmountIn | 128 | 76 |
| originalMinAmountOut | 160 | 108 |
| usePrevHookAmount | 192 | 140 |

## Files to Create
1. `src/hooks/swappers/uniswap-v3/interfaces/IV3SwapRouter.sol`
2. `src/hooks/swappers/uniswap-v3/SwapUniswapV3Router02Hook.sol`
3. `src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Router02Hook.sol`
4. `test/unit/hooks/swappers/uniswap-v3/UniswapV3Router02UnitTests.t.sol`
5. `test/integration/uniswap-v3/UniswapV3Router02HookIntegrationTest.t.sol`

## Files to Modify
1. `script/utils/ConfigBase.sol` - add mapping
2. `script/utils/ConfigCore.sol` - add addresses
3. `script/utils/Constants.sol` - add hook keys
4. `script/DeployV2Core.s.sol` - add availability + deployment
5. `script/run/regenerate_bytecode.sh` - add contract names
6. `test/utils/Constants.sol` - add MAINNET_V3_SWAP_ROUTER_02
