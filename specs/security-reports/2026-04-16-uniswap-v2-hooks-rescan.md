# Security Analysis Report (Re-Scan)

## Metadata
- **Target:** `src/hooks/swappers/uniswap-v2/SwapUniswapV2Hook.sol`, `ApproveAndSwapUniswapV2Hook.sol`
- **Mode:** review
- **Date:** 2026-04-16
- **Contract Types Detected:** AMM/DEX (Uniswap V2 swap hooks)
- **Files Analyzed:** 2 (+ 3 dependencies: BaseHook, HookDataUpdater, ISuperHook)
- **Agents Used:** Vulnerability Scanner, Best Practices, EVM Security Researcher
- **Previous Scan:** `specs/security-reports/2026-04-16-uniswap-v2-hooks.md`

## Previous Fixes Verified

All fixes from the prior scan have been verified as properly implemented:

| Prior Finding | Status | Verification |
|---------------|--------|-------------|
| P1-1: Missing path consistency validation | FIXED | Path endpoint validation at lines 225-226 / 244-245 |
| P2-2: No zero-amount validation (usePrevHookAmount) | FIXED | `amountIn == 0` check at line 231 / 250 |
| P2-4: Unbounded pathLength gas griefing | FIXED | `MAX_PATH_LENGTH = 10` with bounds check at line 214 / 233 |
| P3-2: Inconsistent naming | FIXED | Renamed to `SwapUniswapV2Hook` / `ApproveAndSwapUniswapV2Hook` |
| P3-3: Magic number 209 | FIXED | Derivation comment at line 99 in both files |
| P3-5: Missing @return NatSpec | FIXED | All 6 return values documented on `_decodeSwapParams` |
| P3-7: Missing import grouping | FIXED | `// External`, `// Vendor`, `// Superform` comments present |

No regressions introduced by the fixes.

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 3 | No |
| P3 Low | 4 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

---

## P0 Findings (Critical)

None found.

---

## P1 Findings (High)

None found.

---

## P2 Findings (Medium - Should Fix)

### [P2-1] Code Duplication Between SwapUniswapV2Hook and ApproveAndSwapUniswapV2Hook

- **File:** Both V2 hooks
- **SWC:** N/A
- **Category:** Other
- **Description:** ~80% of code is identical between both hooks: all state variables, errors, constructor, `_decodeSwapParams` (57 lines), `_preExecute`, `_postExecute`, `decodeUsePrevHookAmount`, `inspect`, and `_getBalance`. Only `_buildHookExecutions` differs (1 execution vs 1-or-4 with approvals).
- **Codebase Pattern Note:** This is an **accepted codebase convention**. The V3 hooks, KyberSwap hooks, and Odos hooks all follow the same pattern — each hook is a self-contained, independently deployable unit. This avoids diamond/multiple-inheritance complexity and makes each hook independently auditable.
- **Mitigation:** No change required for consistency. If the team considers refactoring, a `BaseUniswapV2Hook` abstract contract could eliminate ~120 lines, but this would break the established pattern.

### [P2-2] Balance-Delta Tracking Vulnerable to External Balance Manipulation

- **File:** `SwapUniswapV2Hook.sol:144-153`, `ApproveAndSwapUniswapV2Hook.sol:163-172`
- **SWC:** N/A
- **Category:** MEV
- **Description:** The balance-delta pattern (`_preExecute` records balance, `_postExecute` computes delta) can be inflated if other operations affect the output token balance between pre and post. For native ETH output (`account.balance`), forced ETH via `selfdestruct` or coinbase transfers also inflate the delta. An inflated `outAmount` propagates via `usePrevHookAmount` to downstream hooks.
- **Codebase Pattern Note:** This is an **architectural constraint** of the hook execution model. The same pattern exists in V3, KyberSwap, and all other swap hooks. BaseHook's transient storage mutex limits the window but doesn't eliminate the risk.
- **Real-World Precedent:** Uniswap V4 hook audit findings flagged similar "unsettled delta" manipulation risks.
- **Mitigation:** Document as known limitation. Ensure hook ordering within batch executions is validated off-chain to prevent interference.

### [P2-3] HookDataUpdater Precision Loss Weakens Slippage Protection

- **File:** `src/libraries/HookDataUpdater.sol:21-22` (dependency)
- **SWC:** N/A
- **Category:** Arithmetic
- **Description:** `getUpdatedOutputAmount` uses `PRECISION = 1e5` for percentage calculations. When `amount` is very small relative to `_prevAmount`, the computed `amountOutMin` can round to zero, creating a swap with no slippage protection — a sandwich attack vector. Maximum relative error is ~0.001% (1e-5).
- **Scope Note:** This is a shared library used by 14+ deployed hooks. Cannot be modified without system-wide impact. Carried forward from prior scan per user decision.
- **Mitigation:** Consider adding `if (amountOutMin == 0) revert AMOUNT_NOT_VALID();` after the `HookDataUpdater` call as a safety net in the V2 hooks specifically.

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Missing `native_` Address Validation in Constructor

- **File:** `SwapUniswapV2Hook.sol:78-82`, `ApproveAndSwapUniswapV2Hook.sol:78-82`
- **Category:** Logic
- **Description:** Constructor validates `router_ != address(0)` but not `native_`. If `native_` is `address(0)`, any uninitialized token address field would be treated as a native swap.
- **Codebase Pattern Note:** KyberSwap hooks also don't validate `nativeToken_`. Some chains use `address(0)` as native sentinel (e.g., Odos). Accepted codebase pattern.

### [P3-2] NatSpec Uses `@dev` for Data Layout Instead of `@notice`

- **File:** `SwapUniswapV2Hook.sol:23-31`, `ApproveAndSwapUniswapV2Hook.sol:23-31`
- **Category:** Other
- **Description:** The V2 hooks use `@dev` tags for data structure documentation, while V3, KyberSwap, and Odos hooks use `@notice`. Minor NatSpec inconsistency. Also has a trailing colon in "structure:" that other hooks omit.

### [P3-3] Sandwich Attack Exposure Amplified by Multi-Hop Paths

- **File:** Both hooks
- **Category:** MEV
- **Description:** `MAX_PATH_LENGTH = 10` allows up to 10-hop swaps. Each intermediate pool is independently sandwichable, and cumulative slippage can exceed `amountOutMin` protection (which only covers the final output). Legitimate V2 swaps rarely exceed 3 hops.
- **Real-World Precedent:** EigenPhi data shows 72,000+ sandwich attacks in 30 days on Ethereum, primarily targeting multi-hop V2 swaps.
- **Mitigation:** Consider reducing `MAX_PATH_LENGTH` to 4. Document that multi-hop paths exponentially increase MEV exposure.

### [P3-4] Fee-on-Transfer Token Restriction is Documentation-Only

- **File:** Both hooks (NatSpec line 32-33)
- **Category:** Token
- **Description:** "Fee-on-transfer tokens are NOT supported" is documented but not enforced on-chain. If a fee-on-transfer token is used as `tokenIn`, the router receives fewer tokens than `amountIn`, likely causing a revert. No fund loss risk, but no fail-fast hook-level error.
- **Mitigation:** Acceptable if off-chain system (SuperBundler) prevents routing fee-on-transfer tokens through these hooks.

---

## Attack Surface Summary

- **External Entry Points:** `build()` (view, via SuperExecutor), `preExecute` / `postExecute` (via BaseHook), `decodeUsePrevHookAmount` (pure), `inspect` (pure)
- **Value Transfer Points:** Native ETH sent to router via `Execution.value` for `swapExactETHForTokens`; ERC-20 approve/transfer via encoded Execution calldata
- **Oracle Dependencies:** None (amountOutMin is off-chain sourced)
- **Cross-Contract Interactions:** `IUniswapV2Router` (3 swap functions), `IERC20.approve`, `IERC20.balanceOf`, `ISuperHookResult.getOutAmount`, `HookDataUpdater.getUpdatedOutputAmount`
- **Upgrade Mechanisms:** None (immutable contracts)

## Positive Security Observations

- All prior P1 findings resolved — path endpoint validation now enforced
- Zero-amount check prevents corrupted `usePrevHookAmount` chaining
- Path length bounded by `MAX_PATH_LENGTH = 10` — prevents gas griefing
- Approve lifecycle correctly handles USDT-like tokens: `approve(0) -> approve(amount) -> swap -> approve(0)`
- Recipient hardcoded to `account` (prevents fund theft via arbitrary recipient)
- BaseHook provides pre/post-execute mutex via transient storage
- Solidity 0.8.30 provides checked arithmetic with safe `unchecked` loop counter
- Deadline validated before building executions (fail-fast)
- Fee-on-transfer and rebasing tokens explicitly documented as unsupported
- Both hooks follow established codebase patterns (V3, KyberSwap, Odos)
- Import grouping, NatSpec, and naming conventions all consistent

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 3, 4, 6, 7, 8, 9, 10, 13, 15, 26, 31
- **evmresearch.io patterns checked:** vulnerability-patterns (AMM, approval, reentrancy), exploit-analyses (SushiSwap, SIR.trading, Dexible, LI.FI), security-patterns (CEI, approval lifecycle)
- **External sources:** OWASP Smart Contract Top 10 (2025/2026), SWC Registry, SushiSwap RouteProcessor2 post-mortem, Uniswap V4 hooks audit findings, Solidity transient storage compiler bug advisory
- **Historical exploits cross-referenced:** 8 (SushiSwap $3.3M, SIR.trading $355K, Dexible $1.53M, LI.FI $11.6M, SwapNet/Matcha $16.8M, STA/Balancer $500K, Balancer V2 rounding, sandwich attacks)
