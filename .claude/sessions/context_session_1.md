# Session Context: Uniswap V3 Hook Implementation

## Overview
Created and implemented Uniswap V3 hooks to support v2-periphery deployment on Hyperliquid, which uses Project X (a Uniswap V3 fork).

## Status: COMPLETE
- Date: 2026-02-03
- Phase: Implementation Complete (including SuperVault integration tests)

## Key Decisions Made
1. **V3 not V4**: Project X on Hyperliquid is a Uniswap V3 fork (confirmed via https://github.com/hl-x-org/v3-core)
2. **Two hook variants**: SwapUniswapV3Hook + ApproveAndSwapUniswapV3Hook (following Odos pattern)
3. **Native ETH handling**: Manual chaining with DepositWETHHook/WithdrawWETHHook
4. **Slippage formula**: HookDataUpdater pattern (simple proportional recalculation)
5. **Fee validation**: No validation - let router handle (flexibility for different chains)
6. **Data format**: BytesLib packed (225 bytes total)
7. **Router config**: Immutable constructor parameter

## Files Created
```
specs/uniswap-v3-hook/
├── spec.md              - Pod leader approval spec
├── technical-spec.md    - Detailed technical specification with code
├── interview-notes.md   - Interview transcript and decisions
└── research/
    ├── repo-analysis.md     - Codebase patterns analysis
    ├── best-practices.md    - External best practices
    ├── framework-docs.md    - Uniswap V3 documentation
    └── specflow-analysis.md - User flow and gap analysis
```

## Implementation Summary

### SwapUniswapV3Hook
- Assumes tokens pre-approved to router
- Single execution: exactInputSingle call
- Gas: ~130k

### ApproveAndSwapUniswapV3Hook
- 4 executions: approve(0) -> approve(amount) -> swap -> approve(0)
- Gas: ~180k

### Data Structure (225 bytes)
```
tokenIn           (0-19)    - address
tokenOut          (20-39)   - address
fee               (40-43)   - uint32 (read as uint24)
recipient         (44-63)   - address
deadline          (64-95)   - uint256
sqrtPriceLimitX96 (96-127)  - uint256 (cast to uint160)
originalAmountIn  (128-159) - uint256
originalMinAmountOut (160-191) - uint256
_reserved         (192-223) - uint256
usePrevHookAmount (224)     - bool
```

## Implementation Complete (2026-02-02 to 2026-02-03)

### Files Created
**Core Hooks:**
- `src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol` - Minimal hook (1 execution)
- `src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.sol` - Full approval lifecycle (4 executions)
- `src/hooks/swappers/uniswap-v3/interfaces/ISwapRouter.sol` - SwapRouter interface

**Tests:**
- `test/unit/hooks/swappers/uniswap-v3/UniswapV3UnitTests.t.sol` - 28 unit tests
- `test/integration/uniswap-v3/UniswapV3HookIntegrationTest.t.sol` - 7 integration tests via SuperExecutor
- `test/integration/uniswap-v3/UniswapV3SuperVaultIntegrationTest.t.sol` - 7 integration tests via MockSuperVaultStrategy.executeHooks

**Supporting Files:**
- `test/mocks/MockSuperVaultStrategy.sol` - Mock to simulate SuperVault's executeHooks method
- `specs/uniswap-v3-hook/knowledge/new-feature-uniswap-v3-hooks.md` - Knowledge documentation

### Data Structure (Final: 193 bytes)
Note: Reduced from 225 bytes by removing `_reserved` field.
```
tokenIn           (0-19)    - address
tokenOut          (20-39)   - address
fee               (40-43)   - uint32 (read as uint24)
recipient         (44-63)   - address
deadline          (64-95)   - uint256
sqrtPriceLimitX96 (96-127)  - uint256 (cast to uint160)
originalAmountIn  (128-159) - uint256
originalMinAmountOut (160-191) - uint256
usePrevHookAmount (192)     - bool
```

### MockSuperVaultStrategy (Added 2026-02-03)
Simplified mock to test hooks via `executeHooks` method without needing full v2-periphery setup:
- Mimics SuperVaultStrategy._processSingleHookExecution flow
- Supports hook chaining (prevHook parameter)
- Verifies minimum output (slippage protection)
- Tests cover: USDC↔WETH swaps, fee tiers, hook chaining, slippage reverts, outAmount tracking

### Test Results
- 28 unit tests: PASS
- 7 SuperExecutor integration tests: PASS
- 7 MockSuperVaultStrategy integration tests: PASS
- **Total: 42 tests passing**

## Key References
- Project X GitHub: https://github.com/hl-x-org/v3-core
- Existing V4 hook: src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol
- Odos hook pattern: src/hooks/swappers/odos/SwapOdosV2Hook.sol
- ISwapRouter: lib/modulekit/src/integrations/interfaces/uniswap/v3/ISwapRouter.sol
- SuperVault reference: v2-periphery/src/SuperVault/SuperVaultStrategy.sol

---

# Session Context: YoYieldSourceOracle Implementation

## Overview
Implemented YoYieldSourceOracle - an oracle for Yo Vaults with async redemption support. Yo Vaults use an address-based accumulator pattern (different from ERC-7540's request ID pattern).

## Status: COMPLETE
- Date: 2026-02-23
- Branch: feat/yo-oracle-sv-1412
- Phase: Implementation Complete + Knowledge Documented

## Key Decisions Made
1. **Interface pattern**: Address-based accumulator - `pendingRedeemRequest(owner)` returns `(assets, shares)`
2. **PPS Stability Formula**: `yo_position_value = held_value + pending_assets`
3. **Minimal interface**: Only methods needed by oracle (7 functions)
4. **Ceil rounding**: `getWithdrawalShareOutput` uses `Math.Rounding.Ceil` to favor vault

## Files Created
```
src/vendor/yo/IYoVault.sol                       - Yo Vault interface (7 functions)
src/accounting/oracles/YoYieldSourceOracle.sol   - Main oracle implementation
test/mocks/MockYoVault.sol                       - Mock with testing helpers
test/unit/accounting/YoYieldSourceOracle.t.sol   - 25 unit tests
script/DeployYoYieldSourceOracle.s.sol           - Deployment script
specs/yo-oracle/knowledge/new-feature-yo-yield-source-oracle.md - Knowledge docs
```

## Implementation Summary

### Core TVL Calculation
```solidity
function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares)
    public view override returns (uint256)
{
    IYoVault vault = IYoVault(yieldSourceAddress);
    uint256 heldShares = vault.balanceOf(ownerOfShares);
    uint256 heldValue = heldShares > 0 ? vault.convertToAssets(heldShares) : 0;
    (uint256 pendingAssets,) = vault.pendingRedeemRequest(ownerOfShares);
    return heldValue + pendingAssets;
}
```

### Bugs Fixed During Implementation
1. **balanceOf override conflict**: ERC20 and IYoVault both define balanceOf - fixed with explicit `override(ERC20, IYoVault)`
2. **test_getTVL ERC20 allowance**: simulateDeposit required approval - added `setTotalAssets()` helper instead

## Test Results
- 25 unit tests: PASS
- 308 total oracle tests: PASS (no regressions)

## Integration Testing Complete (2026-02-23)

**Real Yo Vaults tested on Base fork:**
| Vault | Address | Decimals | PPS | TVL |
|-------|---------|----------|-----|-----|
| yoETH | 0x3A43AEC53490CB9Fa922847385D82fe25d0E9De7 | 18 | 1.078 ETH | 6,206 ETH |
| yoBTC | 0xbCbc8cb4D1e8ED048a6276a5E94A3e952660BcbC | 8 | 1.014 BTC | 109.8 BTC |
| yoUSD | 0x0000000f2eB9f69274678c76222B35eEc7588a65 | 6 | 1.068 USD | $28.9M |

**19 integration tests pass:**
- Interface compatibility verified for all 3 vaults
- Oracle methods (decimals, PPS, TVL, share/asset output) match direct vault calls
- `pendingRedeemRequest(owner)` returns `(assets, shares)` as expected
- Ceil rounding verified for withdrawal share calculation
- **Deposit tests**: Fresh address deposits, TVL tracking verified
- **Multiple deposits**: TVL accumulates correctly
- **Multiple users**: Independent TVL tracking verified
- **Share/TVL relationship**: Confirmed TVL = convertToAssets(shares) + pending

**Deposit Test Results:**
```
yoETH: deposit 1 ETH → TVL: 999999999999999999 (accurate)
yoUSD: deposit 1000 USDC → TVL: 999999999 (accurate)
Multiple deposits: 1 + 2 ETH → TVL: 2999999999999999999
```

**Files added:**
- `test/integration/oracles/YoYieldSourceOracleIntegration.t.sol` - 19 integration tests
- `test/utils/Constants.sol` - Added CHAIN_8453_YO_ETH/BTC/USD_VAULT constants

## Deployment Integration Complete (2026-02-23)

**Bytecode Generation:**
- Added `YoYieldSourceOracle` to `ORACLE_CONTRACTS` array in `script/run/regenerate_bytecode.sh`
- Generated bytecode: `script/generated-bytecode/YoYieldSourceOracle.json` (77KB)
- Ready for deployment via `deploy_v2_staging_prod.sh`

**Deployment Script:**
- `script/DeployYoYieldSourceOracle.s.sol` - Standalone deployment script

**To deploy:**
```bash
./script/run/deploy_v2_staging_prod.sh
# Or regenerate bytecode only:
./script/run/regenerate_bytecode.sh YoYieldSourceOracle
```

## Next Steps (Future)
- Production deployment after additional review
