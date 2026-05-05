# User Flow Analysis & Gap Identification: PendleUnifiedHook

## User Flow Overview

### Flow 1: Redeem PT+YT to Direct SY Output Token (No Swap Routing)
1. User has PT and YT tokens in their smart account
2. Hook validates tokenOut is in SY's valid output tokens list
3. Hook approves PT and YT to Pendle router
4. Hook calls `redeemPyToToken` with `swapData.swapType == SwapType.NONE`
5. tokenOut balance tracked via pre/post execute

### Flow 2: Redeem PT+YT to Any Token (With Swap Routing)
1. User has PT and YT tokens
2. Hook validates **tokenRedeemSy** (not tokenOut) is in SY's valid output tokens list
3. Hook validates `swapData.extRouter != address(0)`
4. Hook approves PT and YT to Pendle router
5. Pendle router: Redeem PT+YT → SY → tokenRedeemSy → swap to tokenOut

### Flow 3: Swap Token to PT (Purchase PT)
1. User has tokenIn (ERC20 or native ETH)
2. Hook validates receiver, market, minPtOut, approx params
3. If tokenIn is native ETH: set execValue = netTokenIn
4. Hook calls `swapExactTokenForPt`

### Flow 4: Swap PT to Token
1. User has PT
2. Hook validates receiver, market, exactPtIn, minTokenOut
3. Hook calls `swapExactPtForToken`

### Flow 5: Chained Hook Operations (usePrevHookAmount = true)
1. Previous hook outputs PT+YT
2. PendleUnifiedHook fetches amount from transient storage
3. Executes with dynamically fetched amount

## Flow Permutations Matrix

| Flow | Token Type | Swap Routing | Native ETH | usePrevHookAmount |
|------|------------|--------------|------------|-------------------|
| Redeem (no swap) | ERC20 output | No | No | False/True |
| Redeem (with swap) | Any ERC20 | Yes | No | False/True |
| Token → PT | ERC20 input | Optional | No | False/True |
| Token → PT | Native ETH input | Optional | Yes | False/True |
| PT → Token | ERC20 output | Optional | No | False/True |

## Critical Questions (Already Resolved in Interview)

### Q1: Data Format
**Decision:** Selector-specific format with common header + raw Pendle router calldata
**Keep similar to current hooks for smooth off-chain transition**

### Q2: tokenRedeemSy Validation Logic
**Decision:** When `swapData.swapType != SwapType.NONE`:
- Validate `tokenRedeemSy` against `SY.isValidTokenOut()`
- Validate `swapData.extRouter != address(0)`

When `swapData.swapType == SwapType.NONE`:
- Validate `tokenOut` against `SY.isValidTokenOut()` (current behavior)

### Q3: External Router Validation
**Decision:** Non-zero check only for `swapData.extRouter`

### Q4: Native ETH Support
**Decision:** Handle ETH where Pendle allows it
- SwapHook currently supports ETH input
- Maintain existing behavior

### Q5: Inspect Function Format
**Decision:** Keep simple with fixed data only for Merkle tree compatibility
- Follow current hooks' pattern
- Include yield source, receiver, market, fixed token addresses

## Key Implementation Notes

### tokenRedeemSy Validation Fix (Core Bug Fix)
```solidity
// When swap routing is used
if (output.swapData.swapType != SwapType.NONE) {
    // Validate tokenRedeemSy (intermediate token), NOT tokenOut
    if (!IStandardizedYield(SY).isValidTokenOut(output.tokenRedeemSy))
        revert TOKEN_REDEEM_SY_NOT_VALID();
    if (output.swapData.extRouter == address(0))
        revert INVALID_EXT_ROUTER();
} else {
    // Direct redemption - validate tokenOut
    if (!IStandardizedYield(SY).isValidTokenOut(output.tokenOut))
        revert TOKEN_OUT_NOT_LISTED();
}
```

### Data Layout Strategy
Keep similar to current SwapHook for smooth transition:
```
bytes32 placeholder (0-31) - yieldSourceOracleId
address yieldSource (32-51) - market or YT address
bool usePrevHookAmount (52)
uint256 value (53-84)
bytes txData (85+) - raw Pendle router calldata with selector
```

### Selector Detection
Detect operation from function selector in txData:
- `swapExactTokenForPt.selector`
- `swapExactPtForToken.selector`
- `redeemPyToToken.selector`

## Testing Requirements

### Must Maintain
- All existing test cases from PendleRouterSwapHook.t.sol
- All existing test cases from PendleRouterRedeemHook.t.sol

### Must Add
- Redeem with swap routing (tokenOut != tokenRedeemSy)
- tokenRedeemSy validation (was previously blocked)
- Integration with SuperVault executeHooks
- Fuzzing for amounts and parameters

## Deprecation Notes
- Mark PendleRouterRedeemHook as @deprecated
- Mark PendleRouterSwapHook as @deprecated
- Reference PendleUnifiedHook in deprecation notice
