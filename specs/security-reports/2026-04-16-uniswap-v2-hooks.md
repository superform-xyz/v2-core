# Security Analysis Report

## Metadata
- **Target:** `src/hooks/swappers/uniswap-v2/SwapUniV2Hook.sol`, `ApproveAndSwapUniV2Hook.sol`, `interfaces/IUniswapV2Router.sol`
- **Mode:** review
- **Date:** 2026-04-16
- **Contract Types Detected:** AMM/DEX (Uniswap V2 swap hooks)
- **Files Analyzed:** 3 (+ 3 dependencies: BaseHook, HookDataUpdater, ISuperHook)
- **Agents Used:** Vulnerability Scanner, Best Practices, EVM Security Researcher

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 2 | Yes |
| P2 Medium | 5 | No |
| P3 Low | 7 | No |

## Verdict
**FAIL** - 2 blocking findings (P1) should be reviewed before merge.

---

## P0 Findings (Critical)

None found.

---

## P1 Findings (High - Must Fix)

### [P1-1] Missing Path Consistency Validation

- **File:** `SwapUniV2Hook.sol:199-202`, `ApproveAndSwapUniV2Hook.sol:210-213`
- **SWC:** N/A
- **Category:** Logic
- **Description:** The decoded `path[]` array is never validated against `tokenIn` and `tokenOut`. The `tokenOut` field (offset 20) drives balance-delta tracking in `_getBalance()`, while the `path[]` array drives the actual router swap. A mismatch means the hook tracks the balance of a different token than what the swap actually outputs. This corrupts `getOutAmount()` for downstream hooks using `usePrevHookAmount`.
- **Exploit Scenario:** Hook data is constructed with `tokenOut = USDC` but `path = [WETH, DAI]`. The router swaps to DAI, but balance tracking measures USDC changes. `outAmount` returns an incorrect value (likely 0 or an unrelated delta), corrupting downstream hooks. While hook data is bundler-constructed, this is a defense-in-depth gap.
- **Real-World Precedent:** SushiSwap RouteProcessor2 ($3.3M, April 2023) - missing path/pool validation allowed malicious routing.
- **Vulnerable Code:**
  ```solidity
  path = new address[](pathLength);
  for (uint256 i = 0; i < pathLength; i++) {
      path[i] = data.toAddress(169 + i * 20);
  }
  // No validation that path[0] matches tokenIn or path[last] matches tokenOut
  ```
- **Secure Pattern:**
  ```solidity
  path = new address[](pathLength);
  for (uint256 i = 0; i < pathLength; i++) {
      path[i] = data.toAddress(169 + i * 20);
  }

  // Validate path endpoints match token detection fields
  if (tokenIn == NATIVE) {
      // For native input, path[0] should be WETH (router wraps ETH)
      // Note: requires WETH immutable or router.WETH() call
  } else {
      if (path[0] != tokenIn) revert INVALID_PATH();
  }
  if (tokenOut == NATIVE) {
      // For native output, path[last] should be WETH
  } else {
      if (path[pathLength - 1] != tokenOut) revert INVALID_PATH();
  }
  ```
- **Note:** Full path validation requires knowing the WETH address. This was previously removed as "unused" from the constructor. Re-adding `WETH` immutable for path validation would be the complete fix. Alternatively, validate only the non-native case (path[0]==tokenIn when tokenIn != NATIVE, path[last]==tokenOut when tokenOut != NATIVE).

---

### [P1-2] HookDataUpdater Precision Loss Weakens Slippage Protection

- **File:** `src/libraries/HookDataUpdater.sol:21-22` (dependency, affects all hooks using `usePrevHookAmount`)
- **SWC:** N/A
- **Category:** Arithmetic
- **Description:** `getUpdatedOutputAmount` uses a two-step percentage calculation with `PRECISION = 1e5`. It first computes the percentage change as an integer truncated to 5 decimal places, then applies it to the output amount. This loses precision versus a direct `Math.mulDiv(outputAmount, amount, _prevAmount)`. The maximum relative error is ~0.001% (1e-5). For a 1000 ETH swap (~$3M), this is ~$30 of unprotected slippage, making sandwich attacks marginally more profitable. When `amount` and `_prevAmount` differ by a tiny amount, the percentage can truncate to zero, making `amountOutMin` unchanged regardless of the actual input change.
- **Exploit Scenario:** MEV bot observes a `usePrevHookAmount` transaction. The precision truncation lowers `amountOutMin` by a few basis points from the proportionally correct value. The bot sandwiches the swap, extracting value from the gap.
- **Vulnerable Code:**
  ```solidity
  uint256 percentIncrease = Math.mulDiv(amount - _prevAmount, PRECISION, _prevAmount);
  outputAmount = outputAmount + Math.mulDiv(outputAmount, percentIncrease, PRECISION);
  ```
- **Secure Pattern:**
  ```solidity
  // Direct proportional calculation avoids intermediate truncation
  outputAmount = Math.mulDiv(outputAmount, amount, _prevAmount);
  ```
- **Scope Note:** This is in a shared library, not specific to V2 hooks. Fixing it affects all hooks system-wide. Evaluate carefully before changing.

---

## P2 Findings (Medium - Should Fix)

### [P2-1] Missing `native_` Address Validation in Constructor

- **File:** `SwapUniV2Hook.sol:67-71`, `ApproveAndSwapUniV2Hook.sol:59-63`
- **SWC:** N/A
- **Category:** Access Control
- **Description:** Constructor validates `router_ != address(0)` but not `native_`. If `native_` is set to `address(0)`, any hook data with `tokenIn = address(0)` (from encoding errors) would be treated as a native ETH swap. If set to a real ERC-20 address by mistake, swaps of that token would route through native ETH functions.
- **Vulnerable Code:**
  ```solidity
  constructor(address router_, address native_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
      if (router_ == address(0)) revert ADDRESS_NOT_VALID();
      SWAP_ROUTER = IUniswapV2Router(router_);
      NATIVE = native_;
  }
  ```
- **Secure Pattern:**
  ```solidity
  constructor(address router_, address native_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
      if (router_ == address(0)) revert ADDRESS_NOT_VALID();
      if (native_ == address(0)) revert ADDRESS_NOT_VALID();
      SWAP_ROUTER = IUniswapV2Router(router_);
      NATIVE = native_;
  }
  ```

### [P2-2] No Zero-Amount Validation After Resolving `amountIn`

- **File:** `SwapUniV2Hook.sol:204-212`, `ApproveAndSwapUniV2Hook.sol:215-223`
- **SWC:** N/A
- **Category:** Logic
- **Description:** Neither hook validates `amountIn > 0` after resolving the input amount. When `usePrevHookAmount` is true and the previous hook's `getOutAmount` returns 0, the hook builds an execution with `amountIn = 0`. The V2 router reverts on zero-amount swaps, wasting gas. Additionally, `HookDataUpdater.getUpdatedOutputAmount(0, ...)` may produce `amountOutMin = 0`, disabling slippage protection.
- **Secure Pattern:**
  ```solidity
  if (usePrevHookAmount) {
      amountIn = ISuperHookResult(prevHook).getOutAmount(account);
      if (amountIn == 0) revert AMOUNT_NOT_VALID();
      amountOutMin = HookDataUpdater.getUpdatedOutputAmount(amountIn, originalAmountIn, originalMinAmountOut);
  } else {
      amountIn = originalAmountIn;
      amountOutMin = originalMinAmountOut;
  }
  ```

### [P2-3] Balance-Delta Tracking Vulnerable to External Balance Manipulation

- **File:** `SwapUniV2Hook.sol:132-141`, `ApproveAndSwapUniV2Hook.sol:143-152`
- **SWC:** N/A
- **Category:** MEV
- **Description:** The balance-delta pattern (`_preExecute` records balance, `_postExecute` computes delta) can be corrupted if other operations within the same execution batch affect the output token balance between pre and post. For native ETH output (`account.balance`), any ETH received from other sources inflates `outAmount`. Forced ETH transfers via `selfdestruct` or coinbase transactions also affect the delta.
- **Note:** This is an architectural constraint of the hook execution model, not a bug in the hooks. The same pattern exists in V3 hooks and all other swap hooks. The V3 hooks avoid this for native by rejecting native ETH entirely.
- **Mitigation:** Document that native ETH output hooks should not be chained with hooks that modify native balance. Consider adding comments noting this as a known limitation.

### [P2-4] Unbounded `pathLength` Enables Gas Griefing

- **File:** `SwapUniV2Hook.sol:195-202`, `ApproveAndSwapUniV2Hook.sol:206-213`
- **SWC:** SWC-101
- **Category:** DoS
- **Description:** `pathLength` is decoded as `uint256` with only a minimum bound (`>= 2`). A moderately large value (e.g., 500) passes validation and causes the loop to consume excessive gas. Uniswap V2 paths rarely exceed 4-5 hops in practice.
- **Secure Pattern:**
  ```solidity
  uint256 pathLength = data.toUint256(137);
  if (pathLength < 2 || pathLength > 10) revert INVALID_PATH_LENGTH();
  ```

### [P2-5] Duplicated Code Between SwapUniV2Hook and ApproveAndSwapUniV2Hook

- **File:** Both V2 hooks
- **SWC:** N/A
- **Category:** Other
- **Description:** `_decodeSwapParams`, `_getBalance`, error definitions, storage variables, and constructor logic are identical between both hooks. This mirrors the V3 pattern but increases maintenance risk - a bug fix in one must be manually replicated in the other.
- **Mitigation:** Consider extracting shared logic into a `BaseUniswapV2Hook` contract. This is a low-priority refactor that matches what the V3 hooks also need.

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Sandwich Attack Exposure (Inherent to AMM Design)
- **File:** Both hooks
- **Description:** `amountOutMin` is visible in the mempool, enabling sandwich attacks. The `usePrevHookAmount` path partially mitigates by making actual parameters harder to predict. This is inherent to public mempool AMM swaps.
- **Mitigation:** Off-chain: use private mempools (Flashbots Protect). On-chain: tighter slippage parameters.

### [P3-2] Inconsistent Naming Convention
- **File:** Contract names
- **Description:** V3 uses `SwapUniswapV3Hook` / `ApproveAndSwapUniswapV3Hook` while V2 uses `SwapUniV2Hook` / `ApproveAndSwapUniV2Hook` (abbreviated). Inconsistent for codebase navigation.

### [P3-3] Magic Number 209 Without Derivation
- **File:** `SwapUniV2Hook.sol:88`, `ApproveAndSwapUniV2Hook.sol:80`
- **Description:** `data.length < 209` has no comment explaining derivation: `169 (fixed) + 2 * 20 (min path) = 209`. Add inline comment or named constant.

### [P3-4] Unchecked Loop Counter
- **File:** `SwapUniV2Hook.sol:200`, `ApproveAndSwapUniV2Hook.sol:211`
- **Description:** Loop counter `i` can use `unchecked { ++i }` since it's bounded by `pathLength`. Saves ~30-60 gas per iteration.

### [P3-5] Missing `@return` NatSpec on `_decodeSwapParams`
- **File:** `SwapUniV2Hook.sol:162-166`, `ApproveAndSwapUniV2Hook.sol:173-177`
- **Description:** Six return values undocumented. Add `@return` tags.

### [P3-6] `@notice` Used for Developer-Facing Data Layout
- **File:** `SwapUniV2Hook.sol:19-26`
- **Description:** Byte offset documentation uses `@notice` (user-facing) instead of `@dev` (developer-facing).

### [P3-7] Missing Import Grouping Comments
- **File:** Both V2 hooks
- **Description:** Imports lack `// External` / `// Superform` grouping comments used in KyberSwap and Odos hooks.

---

## Attack Surface Summary

- **External Entry Points:** `_buildHookExecutions` (view, via SuperExecutor), `_preExecute` / `_postExecute` (via BaseHook), `decodeUsePrevHookAmount` (pure), `inspect` (pure)
- **Value Transfer Points:** Native ETH sent to router via `Execution.value` for `swapExactETHForTokens`; ERC-20 approve/transfer via encoded Execution calldata
- **Oracle Dependencies:** None (amountOutMin is off-chain sourced)
- **Cross-Contract Interactions:** `IUniswapV2Router` (3 swap functions), `IERC20.approve`, `IERC20.balanceOf`, `ISuperHookResult.getOutAmount`, `HookDataUpdater.getUpdatedOutputAmount`
- **Upgrade Mechanisms:** None (immutable contracts)

## Positive Security Observations

- Approve lifecycle correctly handles USDT-like tokens: `approve(0) -> approve(amount) -> swap -> approve(0)`
- Recipient hardcoded to `account` (prevents fund theft via arbitrary recipient)
- BaseHook provides pre/post-execute mutex via transient storage
- Solidity 0.8.30 provides checked arithmetic
- Deadline validated before building executions (fail-fast)
- Fee-on-transfer and rebasing tokens explicitly documented as unsupported
- Both hooks follow established codebase patterns (V3, KyberSwap)

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 3, 4, 6, 7, 8, 9, 10, 13, 15, 26, 31
- **evmresearch.io patterns checked:** vulnerability-patterns (AMM), exploit-analyses (SushiSwap, SIR.trading), security-patterns (reentrancy, approval)
- **External sources:** OWASP Smart Contract Top 10 (2025), SWC Registry, SushiSwap RouteProcessor2 post-mortem, SIR.trading transient storage exploit
- **Historical exploits cross-referenced:** 5 (SushiSwap $3.3M, SIR.trading $355K, sandwich attacks)
