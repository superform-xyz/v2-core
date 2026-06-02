# Security Analysis Report

## Metadata
- **Target:** SwapUniswapV3Router02Hook.sol, ApproveAndSwapUniswapV3Router02Hook.sol
- **Mode:** review
- **Date:** 2026-06-01
- **Contract Types Detected:** AMM/DEX swap hooks
- **Files Analyzed:** 2 (+ BaseHook, HookDataUpdater, IV3SwapRouter, V1 hooks for comparison)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 1 | Yes |
| P2 Medium | 4 | No |
| P3 Low | 5 | No |

## Verdict
**FAIL** - 1 blocking finding (P1) should be evaluated before merge.

---

## P0 Findings (Critical)

None found.

---

## P1 Findings (High)

### [P1-1] No Deadline Protection -- Transactions Executable at Any Future Time

- **File:** `SwapUniswapV3Router02Hook.sol:69-108`, `ApproveAndSwapUniswapV3Router02Hook.sol:62-126`
- **SWC:** N/A
- **Category:** MEV / Front-running / Stale Execution
- **Description:** The Router02 hooks call `exactInputSingle` directly without using SwapRouter02's `multicall(uint256 deadline, bytes[] data)` wrapper. The `ExactInputSingleParams` struct in Router02 intentionally removed the `deadline` field (unlike V1's `ISwapRouter`). The NatSpec says "deadline handled via multicall wrapper" but the hooks don't use multicall. The V1 hooks (`SwapUniswapV3Hook`) explicitly validate deadlines in `_decodeSwapParams` -- this is a regression.
- **Exploit Scenario:** A malicious bundler holds a signed UserOp. Hours/days later, when exchange rates have moved adversely (but still satisfy the stale `amountOutMinimum`), the bundler submits the transaction, extracting MEV from the user.
- **Mitigating Factor:** Superform's ERC-4337 UserOp pipeline includes timestamp validation via Merkle proof signatures, providing an outer deadline layer. SECURITY.md acknowledges "Infinite deadline transactions allowed" as an accepted risk. However, this represents a regression from V1 hooks which do enforce deadlines.
- **Vulnerable Code:**
```solidity
// Calls exactInputSingle directly -- no deadline anywhere
executions[0] = Execution({
    target: address(SWAP_ROUTER),
    value: 0,
    callData: abi.encodeCall(IV3SwapRouter.exactInputSingle, (params))
});
```
- **Secure Pattern:** Wrap the swap call in SwapRouter02's `multicall`:
```solidity
bytes memory swapCalldata = abi.encodeCall(IV3SwapRouter.exactInputSingle, (params));
bytes[] memory calls = new bytes[](1);
calls[0] = swapCalldata;
executions[0] = Execution({
    target: address(SWAP_ROUTER),
    value: 0,
    callData: abi.encodeCall(IMulticall.multicall, (deadline, calls))
});
```
Or add a deadline field to hook data and validate in `_decodeSwapParams` (matching V1 behavior).

---

## P2 Findings (Medium)

### [P2-1] Fee Tier Truncation -- uint32 to uint24 Silent Narrowing

- **File:** `SwapUniswapV3Router02Hook.sol:171`, `ApproveAndSwapUniswapV3Router02Hook.sol:188`
- **SWC:** SWC-129
- **Category:** Arithmetic / Silent Truncation
- **Description:** Fee is decoded as `uint32` then cast to `uint24`. Values >= 16,777,216 have upper 8 bits silently discarded, potentially targeting the wrong fee tier pool. Example: `0x01000BB8` (16,780,216) truncates to `3000` (0x000BB8).
- **Vulnerable Code:**
```solidity
fee = uint24(data.toUint32(40));
```
- **Secure Pattern:**
```solidity
uint32 rawFee = data.toUint32(40);
if (rawFee > type(uint24).max) revert INVALID_HOOK_DATA();
fee = uint24(rawFee);
```

### [P2-2] sqrtPriceLimitX96 Truncation -- uint256 to uint160 Silent Narrowing

- **File:** `SwapUniswapV3Router02Hook.sol:172`, `ApproveAndSwapUniswapV3Router02Hook.sol:189`
- **SWC:** N/A
- **Category:** Arithmetic / Silent Truncation
- **Description:** `sqrtPriceLimitX96` read as `uint256` and truncated to `uint160`. If upper 96 bits are non-zero, truncation could produce 0 (no price limit), removing price-dimension slippage protection entirely.
- **Vulnerable Code:**
```solidity
sqrtPriceLimitX96 = uint160(data.toUint256(44));
```
- **Secure Pattern:**
```solidity
uint256 rawSqrtPriceLimit = data.toUint256(44);
if (rawSqrtPriceLimit > type(uint160).max) revert INVALID_HOOK_DATA();
sqrtPriceLimitX96 = uint160(rawSqrtPriceLimit);
```

### [P2-3] amountOutMinimum Can Round to Zero via HookDataUpdater Scaling

- **File:** `SwapUniswapV3Router02Hook.sol:178-184`, `HookDataUpdater.sol:9-30`
- **SWC:** N/A
- **Category:** Slippage Protection Erosion
- **Description:** When `usePrevHookAmount` is true, `amountOutMinimum` is scaled proportionally via `HookDataUpdater`. With `PRECISION = 1e5`, if `amount` is much smaller than `_prevAmount`, the scaled `amountOutMinimum` can round to 0 -- providing zero sandwich protection. The hook validates `amountIn == 0` but never validates `amountOutMinimum > 0`.
- **Vulnerable Code:**
```solidity
amountOutMinimum = HookDataUpdater.getUpdatedOutputAmount(
    amountIn, originalAmountIn, originalMinAmountOut
);
// No check: if (amountOutMinimum == 0) revert ...;
```
- **Secure Pattern:**
```solidity
amountOutMinimum = HookDataUpdater.getUpdatedOutputAmount(
    amountIn, originalAmountIn, originalMinAmountOut
);
if (amountOutMinimum == 0) revert AMOUNT_NOT_VALID();
```

### [P2-4] Code Duplication -- _decodeSwapParams, _preExecute, _postExecute Fully Duplicated

- **File:** `SwapUniswapV3Router02Hook.sol:112-191`, `ApproveAndSwapUniswapV3Router02Hook.sol:129-208`
- **SWC:** N/A
- **Category:** Maintainability / Divergence Risk
- **Description:** `_decodeSwapParams` (~40 lines), `_preExecute`, and `_postExecute` are copy-pasted identically across both contracts. This follows the V1 pattern but increases risk of future divergence when one is patched but not the other. Consider extracting to a shared abstract base.

---

## P3 Findings (Low)

### [P3-1] setOutAmount Lacks Caller Restriction in BaseHook

- **File:** `BaseHook.sol:177-187`
- **Category:** Access Control
- **Description:** `setOutAmount()` is `external` and callable by anyone before `preExecute` runs (mutex check only reverts after mutexes are set). Practical risk is low: `_preExecute` overwrites `outAmount` with the balance snapshot, and the nonce-based context system makes targeting difficult.

### [P3-2] Missing @return NatSpec on _decodeSwapParams

- **File:** `SwapUniswapV3Router02Hook.sol:145-148`, `ApproveAndSwapUniswapV3Router02Hook.sol:162-165`
- **Category:** Documentation
- **Description:** Returns 6 named values but has no `@return` NatSpec tags. Missing `@dev` annotation explaining why `recipient` is hardcoded to `account`.

### [P3-3] Import Organization Missing Section Headers

- **File:** Both hooks, lines 4-11
- **Category:** Code Style
- **Description:** Other hooks (e.g., `SwapOdosV3Hook`, `BaseHook.sol`) use `// External` and `// Superform` import section headers. These hooks do not.

### [P3-4] ApproveAndSwap Missing Inline Data Layout Documentation

- **File:** `ApproveAndSwapUniswapV3Router02Hook.sol:19`
- **Category:** Documentation
- **Description:** Says `@dev data structure same as SwapUniswapV3Router02Hook` instead of including the full data layout. Makes the file harder to read in isolation.

### [P3-5] abi.encodePacked with Fixed-Size Types (Informational)

- **File:** `BaseHook.sol:289,314`
- **Category:** abi.encodePacked
- **Description:** Uses `abi.encodePacked` for key derivation with fixed-size types (`bytes32`, `address`, `uint256`). No collision risk since all types are fixed-size. Informational only.

---

## Attack Surface Summary

- **External Entry Points:** `build()` (view), `preExecute()` (account-only), `postExecute()` (account-only), `setOutAmount()` (anyone before mutex), `setExecutionContext()` (anyone), `decodeUsePrevHookAmount()` (pure), `inspect()` (pure)
- **Value Transfer Points:** Swap execution via `exactInputSingle` on SwapRouter02; approve/revoke on tokenIn (ApproveAndSwap variant only)
- **Oracle Dependencies:** None (balance-delta pattern, not oracle-based)
- **Cross-Contract Interactions:** `ISuperHookResult(prevHook).getOutAmount()` (untrusted data from previous hook), `IERC20.balanceOf()`, `IERC20.approve()`, `IV3SwapRouter.exactInputSingle()`
- **Upgrade Mechanisms:** None (immutable contracts, no proxy)

## Router02 vs V1 Comparison

| Aspect | V1 (SwapRouter) | Router02 (SwapRouter02) | Impact |
|--------|-----------------|------------------------|--------|
| Deadline | Encoded + validated | Absent | **Regression** |
| tokenIn == tokenOut | Not checked | Checked | **Improvement** |
| amountIn == 0 | Not checked | Checked | **Improvement** |
| postExecute underflow guard | Panics (no custom error) | `AMOUNT_NOT_VALID` revert | **Improvement** |
| Data layout size | 193 bytes | 141 bytes | Smaller |
| Fee/sqrtPrice truncation | Same risk | Same risk | Neutral |

## Improvements in Router02 Over V1
1. `tokenIn == tokenOut` validation prevents same-token swap confusion
2. `amountIn == 0` check prevents gas-wasting zero-amount swaps
3. `finalBalance < initialBalance` guard provides clear error vs panic
4. Smaller data layout (no redundant recipient/deadline fields)
