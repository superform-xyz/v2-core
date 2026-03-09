# Spark PSM Hook - Interview Notes

**Date:** 2026-03-09
**Feature:** SwapSparkPSM hooks for Sky.money PSM integration

## Context

Sky PSM (Peg Stability Module) is the main venue for USDS<>USDC swaps on mainnet and Base. Standard DEX pools lack sufficient liquidity for this purpose. The hooks enable Superform to route swaps through PSM before/after vault operations (e.g., Morpho vault deposits).

**PSM Contract (Base):** `0x1601843c5e9bc251a3272907010afa41fa18347e`
**Target Vault:** Sky.money Morpho USDC Risk Capital vault on Ethereum

## Decisions

### 1. Hook Count & Types
**Decision:** Create 4 hooks:
- `SwapSparkPSMExactInHook` - swapExactIn, assumes pre-approved
- `ApproveAndSwapSparkPSMExactInHook` - approve + swapExactIn + revoke
- `SwapSparkPSMExactOutHook` - swapExactOut, assumes pre-approved
- `ApproveAndSwapSparkPSMExactOutHook` - approve + swapExactOut + revoke

### 2. Deployment Chains
**Decision:** Deploy wherever PSM is available. Deployment scripts use address(0) to skip chains without PSM.

### 3. Referral Code
**Decision:** Passed as parameter in hook data (flexible, matches Odos pattern).

### 4. Use Case Flow
**Decision:** Hooks only handle the swap step. Deposit/withdrawal are handled by separate hooks in the chain.

### 5. ExactOut Amount Handling
**Decision:** Mirror the ExactIn pattern. Use `HookDataUpdater.getUpdatedOutputAmount` to scale `maxAmountIn` proportionally when `usePrevHookAmount` is true. For ExactOut, the "out" amount is fixed, "in" amount (max) is the variable/slippage parameter.

### 6. Token Support
**Decision:** Support all three tokens: USDC, USDS, sUSDS. The PSM handles rate logic internally (1:1 for USDC/USDS, oracle-based for sUSDS). No token validation in hook - let PSM revert on invalid tokens.

### 7. Security Mode
**Auto-enabled** - on-chain feature touching token swaps and external contract interaction.

## PSM Interface

```solidity
function swapExactIn(
    address assetIn,
    address assetOut,
    uint256 amountIn,
    uint256 minAmountOut,
    address receiver,
    uint256 referralCode
) external returns (uint256 amountOut);

function swapExactOut(
    address assetIn,
    address assetOut,
    uint256 amountOut,
    uint256 maxAmountIn,
    address receiver,
    uint256 referralCode
) external returns (uint256 amountIn);
```

## Existing Patterns Reference
- `SwapOdosV2Hook` / `ApproveAndSwapOdosV2Hook` - Odos router integration
- `SwapUniswapV3Hook` / `ApproveAndSwapUniswapV3Hook` - Uniswap V3 integration
- All follow: BaseHook(NONACCOUNTING, SWAP), _preExecute/_postExecute balance tracking, usePrevHookAmount chaining
