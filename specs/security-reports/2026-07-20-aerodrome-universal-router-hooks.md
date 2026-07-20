# Security Analysis Report: Aerodrome Universal Router Hooks

## Metadata
- **Target:** `src/hooks/swappers/aerodrome/` (3 contracts + 1 vendor interface)
- **Mode:** review
- **Date:** 2026-07-20
- **Contract Types Detected:** AMM/DEX (swap hooks)
- **Files Analyzed:** 4 (+ 3 context files: BaseHook, SwapCalldataLayout, HookDataUpdater)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | - |
| P1 High | 0 | - |
| P2 Medium | 0 | - |
| P3 Low | 2 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

---

## P0 Findings (Critical)
None found.

## P1 Findings (High)
None found.

## P2 Findings (Medium)
None found.

## P3 Findings (Low)

### [P3-1] Precision Loss in Scaled `amountOutMin` via HookDataUpdater

- **File:** `BaseAerodromeUniversalRouterHook.sol:438` (via `HookDataUpdater.sol:21-26`)
- **SWC:** N/A
- **Category:** Arithmetic
- **Description:** When `usePrevHookAmount` is true, `_scaleFromPreviousHook` calls `HookDataUpdater.getUpdatedOutputAmount` which uses `PRECISION = 1e5`. Percentage changes <0.001% round to zero, meaning `amountOutMin` may not scale proportionally with `amountIn`. This results in sub-basis-point loosening of slippage protection.
- **Exploit Scenario:** An MEV bot could extract marginally more value from the looser-than-intended slippage, but the extracted amount would be negligible. Not directly exploitable in isolation.
- **Vulnerable Code:**
  ```solidity
  // HookDataUpdater.sol
  uint256 percentIncrease = Math.mulDiv(amount - _prevAmount, PRECISION, _prevAmount);
  outputAmount = outputAmount + Math.mulDiv(outputAmount, percentIncrease, PRECISION);
  ```
- **Secure Pattern:** Use direct proportional scaling: `Math.mulDiv(outputAmount, amount, _prevAmount)`.
- **Note:** This is a **system-wide** shared library pattern used by all hooks, not specific to Aerodrome. The existing test `test_PreviousHookScalingUsesRepositoryPrecisionQuantization` explicitly validates this behavior, suggesting it is intentional.

### [P3-2] Custom Error `OUTPUT_BALANCE_DECREASED` Diverges from Codebase Convention

- **File:** `BaseAerodromeUniversalRouterHook.sol:127,198`
- **SWC:** N/A
- **Category:** Logic (naming consistency)
- **Description:** The Aerodrome hook introduces `OUTPUT_BALANCE_DECREASED()` for the balance underflow guard in `_postExecute`. All other swap hooks in the repo (UniswapV3, Algebra, etc.) use the inherited `AMOUNT_NOT_VALID()` for the same check. This means off-chain error-handling code must handle two different selectors for the same failure.
- **Secure Pattern:** Use `revert AMOUNT_NOT_VALID()` for consistency, or adopt `OUTPUT_BALANCE_DECREASED` repo-wide as the new standard.
- **Note:** The custom error is arguably more descriptive. This is a style/consistency observation, not a security issue.

---

## Attack Surface Summary

### External Entry Points
| Function | Visibility | State-Modifying | Protected By |
|----------|-----------|----------------|-------------|
| `build()` | external | No (view via `_buildHookExecutions`) | ERC-7579 executor |
| `preExecute()` | external | Yes (`_setOutAmount`) | `msg.sender == account` (BaseHook) |
| `postExecute()` | external | Yes (`_setOutAmount`, `_setOutToken`) | `msg.sender == account` (BaseHook) |
| `decodeUsePrevHookAmount()` | external pure | No | None needed |
| `decodeAmounts()` | external pure | No | None needed |
| `replaceCalldataAmounts()` | external pure | No | None needed |
| `inspect()` | external pure | No | None needed |
| `encodeSwapData()` | external pure | No | None needed |
| `decode*()` methods | external pure | No | None needed |

### Value Transfer Points
- ERC20 `approve(router, amount)` via Execution array (ApproveAndSwap variant only)
- Aerodrome Universal Router `execute()` via Execution array (triggers token transfers)
- ERC20 `approve(router, 0)` via Execution array (revocation)

### Oracle Dependencies
None. Prices determined by AMM at execution time with `amountOutMin` as slippage guard.

### Cross-Contract Interactions
| Target | Call Type | Trust Level |
|--------|-----------|-------------|
| Aerodrome Universal Router | `execute()` via Execution | Immutable address, pinned runtime hash |
| Previous hook | `staticcall getOutToken/getOutAmount` | Validated return data (32 bytes, token match) |
| ERC20 tokens | `approve()`, `balanceOf()` | Standard interface |

### Upgrade Mechanisms
None. All contracts are non-upgradeable with immutable router address.

---

## EVM Security Research Highlights

### Exploit Precedent Cross-References

| Exploit | Date | Loss | Relevance | Mitigated? |
|---------|------|------|-----------|------------|
| UniswapV4Router04 calldata offset bypass | Mar 2026 | $42.6K | Non-canonical ABI encoding bypasses auth | **Yes** - `_decodeCanonicalPayload` keccak256 round-trip check |
| Uniswap Router approval abuse | Feb 2026 | $13.9K | Arbitrary payer in swap callback | **Yes** - Immutable router, exact-amount approval, revoke after swap |
| Cork Protocol hook exploit | 2025 | $11M | Missing access control on hook callbacks | **Yes** - BaseHook mutex + ERC-7579 executor gating |
| SwapNet/Aperture arbitrary call | Jan 2026 | $17M | Arbitrary call targets drain approvals | **Yes** - Fixed call target (immutable router), single function (`execute`) |
| Uniswap reentrancy (Dedaub) | Pre-deploy | $40K bounty | Multi-command reentrancy via callbacks | **Yes** - Single-command execution only |

### Key Defensive Patterns Verified
1. **Canonical payload encoding** - keccak256 round-trip prevents ABI encoding manipulation
2. **Single-command execution** - eliminates multi-command composition attacks
3. **Balance-delta accounting** - prevents output amount spoofing
4. **Temporary approval pattern** - approve(0) -> approve(amount) -> swap -> approve(0)
5. **Native ETH exclusion** - eliminates wrapping/unwrapping attack vectors
6. **Bounded path validation** - MAX_HOPS=9 prevents DoS via unbounded loops
7. **Previous hook output validation** - strict 32-byte return data + token match

### Recommendations for Follow-Up
1. **Verify Aerodrome Router reentrancy guard** - Confirm the deployed router on Base includes the reentrancy lock from the Uniswap disclosure
2. **Verify `V3SwapCallback` payer handling** - Confirm the router uses `msg.sender` as payer in callbacks, not an externally supplied parameter
3. **Off-chain slippage enforcement** - The on-chain `amountOutMin` is necessary but quality depends on the off-chain parameter-setting system

---

## Coding Standards Summary

| Area | Status |
|------|--------|
| Solidity version locked (0.8.30) | Pass |
| Explicit visibility on all functions | Pass |
| Custom errors (no require strings) | Pass |
| NatSpec on public/external functions | Pass |
| NatSpec on private/internal functions | Missing on 7 private functions (P3) |
| Import organization | Pass |
| Checks-Effects-Interactions | Pass |
| Zero-address validation | Pass |
| Interface compliance (ISuperHookSwap et al.) | Pass |
| Consistency with existing hooks | Pass (minor error naming divergence) |
| Base hook abstraction (code dedup) | Improvement over UniswapV3 pattern |

---

## Security Knowledge Sources
- **Vulnerability patterns checked:** Reentrancy, Access Control, Arithmetic, Return Values, Token Integration, Oracle, MEV, DoS, Logic, Input Validation, Cross-Contract, Gas, EIP-150 Returnbomb, Trusted Caller
- **AMM/DEX-specific patterns:** Flash loan slippage, sandwich attacks, approval races, router interaction safety, deadline validation
- **Historical exploits cross-referenced:** 5 (UniswapV4Router04, Uniswap approval abuse, Cork Protocol, SwapNet/Aperture, Uniswap reentrancy)
- **External sources consulted:** Dedaub, DARKNAVY, BlockSec, OWASP SC Top 10, Revoke.cash, ChainSecurity, DeFiScan, Cyfrin, Hacken
