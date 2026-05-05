# Session 6: MetaMorpho Reallocate Hook

## Goal
Create a NONACCOUNTING hook (`MetaMorphoReallocateHook`) that calls MetaMorpho's `reallocate()` function to redistribute funds between Morpho Blue markets within a single MetaMorpho vault.

## Spec
Full spec at: `/Users/cosming/1.Coding/Superform/v2-core/specs/metamorpho-reallocate-hook/technical-spec.md`

## Implementation Plan
Full plan at: `/Users/cosming/1.Coding/Superform/v2-core/.claude/doc/MetaMorphoReallocateHook/implementation-plan.md`

## Key Design Decisions
- NONACCOUNTING hook with MISC subtype (management op, net-zero)
- Follows MarkRootAsUsedHook pattern (standard header + abi.decode on tail for MarketAllocation[])
- usePrevHookAmount replaces allocations[prevHookAmountIndex].assets with prev hook output
- New vendor interface IMetaMorpho.sol (just MarketAllocation struct + reallocate())
- No constructor args, no pre/post execute, single Execution output
- Uses abi.encodeCall for type-safe encoding

## Data Layout
```
data[0:32]  = bytes32 placeholder (oracle/yield source ID)
data[32:52] = address metaMorphoVault
data[52]    = bool usePrevHookAmount
data[53]    = uint8 prevHookAmountIndex
data[54:]   = abi.encode(MarketAllocation[])
```

## Files to Create
1. `src/vendor/morpho/IMetaMorpho.sol` - Minimal interface (MarketAllocation struct + reallocate function)
2. `src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol` - The hook
3. `test/unit/hooks/vaults/metamorpho/MetaMorphoReallocateHook.t.sol` - Unit tests

## Directories to Create
- `src/hooks/vaults/metamorpho/` (does not exist yet)
- `test/unit/hooks/vaults/metamorpho/` (does not exist yet)

## Validation Results from Research
- BytesLib.toUint8: CONFIRMED EXISTS at BytesLib.sol line 286, used by DeBridgeSendOrderAndExecuteOnDstHook
- abi.decode on calldata slice for MarketAllocation[]: CONFIRMED WORKS, pattern used by PendleRouterRedeemHook
- abi.encodeCall with dynamic arrays: CONFIRMED WORKS, pattern used by MarkRootAsUsedHook
- calldata-to-memory implicit conversion: CONFIRMED, standard Solidity behavior used throughout codebase
- No spec issues found - the spec is clean and aligned with codebase conventions

## Key Implementation Notes
- `_buildHookExecutions` must be `view` (not `pure`) because it calls `ISuperHookResult(prevHook).getOutAmount(account)`
- `inspect` is `pure` (no immutable variables accessed)
- Hook implements both `ISuperHookContextAware` (for usePrevHookAmount) and inherits `ISuperHookInspector` (from BaseHook)
- No deployment script changes needed - hook has no constructor args and no chain-specific dependencies
- Test file inherits `Helpers` (not `BaseTest`) following the unit test convention

## Reference Patterns
- `src/hooks/superform/MarkRootAsUsedHook.sol` - Variable-length array pattern (closest structural match)
- `src/hooks/vaults/7540/SetOperator7540Hook.sol` - Simple NONACCOUNTING management hook
- `src/hooks/tokens/TransferHook.sol` - usePrevHookAmount pattern with view visibility
- `src/vendor/morpho/IMorpho.sol` - Existing MarketParams struct
- `test/unit/hooks/superform/MarkRootAsUsedHook.t.sol` - Test pattern with abi.encode for dynamic arrays
- `test/unit/hooks/vaults/7540/SetOperator7540Hook.t.sol` - Test pattern for NONACCOUNTING hooks

## Status
- [x] Spec complete
- [x] superform-hook-master planning (COMPLETE - plan validated)
- [x] Implementation (3 files created)
- [x] Unit tests (13/13 pass including fuzz)
- [x] E2E integration tests (6/6 pass)
- [x] SuperVault-context e2e tests (3/3 pass)
- [x] Build verification (forge build succeeds)
- [x] 100% code coverage (17/17 lines, 21/21 statements, 4/4 branches, 3/3 functions)

## Files Created
1. `src/vendor/morpho/IMetaMorpho.sol` - MarketAllocation struct + IMetaMorpho interface
2. `src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol` - The hook contract
3. `test/unit/hooks/vaults/metamorpho/MetaMorphoReallocateHook.t.sol` - 13 unit tests
4. `test/integration/metamorpho/MetaMorphoReallocateHookE2E.t.sol` - 6 e2e integration tests

## Unit Test Results
- 13/13 tests pass (including 1 fuzz test)
- Tests cover: constructor, build (single/multi allocations), reverts (zero vault, empty allocations, OOB index), usePrevHookAmount (index 0, index 1), inspect, decodeUsePrevHookAmount, data encoding round-trip, fuzz

## E2E Integration Test Results
- 6/6 tests pass
- Uses real Steakhouse USDC MetaMorpho vault (0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB) on Ethereum mainnet fork (block 21,500,000)
- Tests cover:
  - Build with real vault address and market data
  - Reallocate: move supply between real Morpho Blue markets (1% from wstETH/USDC market to idle market)
  - No-op reallocate: keep same allocation (single market)
  - Access control: revert when non-allocator calls reallocate
  - Inspect with real data
  - Full cycle: query vault state → build hook → execute reallocate → verify supply shifted
- Key insight: must accrue interest on Morpho Blue markets before reading supply to match MetaMorpho's internal calculation during reallocate()
- Uses IMetaMorphoRead interface for vault state queries (owner, supplyQueue, supplyQueueLength)
- Impersonates vault owner (0x255c7705e8BB334DfCae438197f7C4297988085a) who has allocator privileges

## SuperVault-Context E2E Test Results
- 3/3 tests pass
- Uses real deployed SuperVault strategy (Flagship USDC, 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD) on Ethereum mainnet fork (block 23,930,000)
- Strategy is granted allocator role on MetaMorpho vault via `setIsAllocator(STRATEGY, true)`
- Mocks governance layer: isHookRegistered, validateHook (with ValidateHookArgs struct), isAnyManager
- Tests cover:
  - Reallocate through SuperVaultStrategy.executeHooks (move 1% supply between markets)
  - No-op reallocate through strategy
  - Revert when strategy lacks allocator role
- Key fix: ISuperVaultAggregator.validateHook must use ValidateHookArgs struct (not bytes) to match real contract's selector
