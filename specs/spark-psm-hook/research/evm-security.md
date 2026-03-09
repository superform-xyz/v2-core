# EVM Security Research: Spark PSM Swap Hooks

## Scope

Four Solidity hooks integrating Spark PSM3 (Peg Stability Module) into Superform v2-core:
- `SwapSparkPSMExactInHook` -- pre-approved swap, 1 execution
- `ApproveAndSwapSparkPSMExactInHook` -- approve + swap + revoke, 4 executions
- `SwapSparkPSMExactOutHook` -- pre-approved swap, 1 execution
- `ApproveAndSwapSparkPSMExactOutHook` -- approve + swap + revoke, 4 executions

PSM3 contract: `0x1601843c5E9bC251A3272907010AFa41Fa18347E` on Base.
Tokens: USDC (6 dec), USDS (18 dec), sUSDS (18 dec, ERC-4626 yield-bearing shares).

---

## 1. Vulnerability Patterns and Findings (Sorted by Risk Level)

### Finding 1: Receiver Address Not Enforced at Hook Data Boundary

- **Pattern:** Business Logic Bypass -- Receiver Parameter Ignored But Present in Data
- **Source:** Code review of all 4 hooks; analogous to OWASP SC03:2025 Logic Errors
- **Relevance:** All 4 hooks encode a `receiver` address at byte offset 104 in hook data, but the `_buildHookExecutions` function ignores it and hardcodes `account` as the receiver in the PSM call. This is correct behavior -- balance tracking via pre/post delta requires tokens to land in the account. However, the `inspect()` function in all 4 hooks returns the **unvalidated receiver from hook data** (`data.toAddress(104)`) alongside `assetOut`. If any downstream consumer of `inspect()` uses this receiver address for authorization or routing decisions, the discrepancy between what `inspect()` reports and what actually executes creates a semantic mismatch that could be exploited.
- **Risk Level:** P2 Medium
- **Mitigation:** Either remove the receiver from `inspect()` output entirely (since it is always forced to account), or have `inspect()` return the actual receiver (the account). Document clearly that the receiver field in hook data is purely ignored. Consider whether `inspect()` consumers depend on this value.

### Finding 2: HookDataUpdater Precision Loss in Cross-Decimal Chaining

- **Pattern:** Arithmetic Precision Loss / Rounding Direction Error
- **Source:** Code review of `HookDataUpdater.getUpdatedOutputAmount`; [Balancer V2 Rounding Exploit (Nov 2025, $128M)](https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/); [ChainSecurity Spark PSM Audit (Oct 2024)](https://cdn.prod.website-files.com/65d35b01a4034b72499019e8/6717c8b96db944f76d0612e3_ChainSecurity_SparkDAO_Spark_PSM_audit%201.pdf)
- **Relevance:** `HookDataUpdater` uses `PRECISION = 1e5` and `Math.mulDiv` for proportional scaling. When chaining across tokens with different decimals (e.g., USDC 6 dec to USDS 18 dec), the `percentIncrease`/`percentDecrease` calculation operates on raw integer amounts. A previous hook outputting 1,000,000 USDC (1e6 wei = $1) that feeds into a PSM hook expecting USDS amounts (1e18 wei = $1) will produce incorrect scaling because the ratio `amount / _prevAmount` treats these as the same unit. The Balancer V2 exploit demonstrated how compounded rounding errors in swap calculations can drain $128M. While the Superform hooks don't compound across 65 operations like Balancer, even a single precision loss in slippage recalculation could allow the swap to execute with an inappropriately relaxed `minAmountOut` (ExactIn) or `maxAmountIn` (ExactOut).
- **Risk Level:** P2 Medium
- **Mitigation:** When `usePrevHookAmount=true` chains across different-decimal tokens, verify that the bundler constructs the original `amount` and `slippageParam` in the correct decimal space for the current hook. The `HookDataUpdater` scaling assumes the original amount and the previous hook's output are in the same denomination. Document this constraint. Add fuzz tests specifically for USDC(6) to USDS(18) and USDS(18) to USDC(6) chaining scenarios.

### Finding 3: Transient Storage Slot Collision -- Mitigated by Design

- **Pattern:** Transient Storage Slot Reuse / EIP-1153 Misuse
- **Source:** [SIR.trading Exploit (Mar 2025, $355K)](https://research.blockscope.co/sir-protocol-exploit/); [SlowMist Analysis](https://slowmist.medium.com/fatal-residue-an-on-chain-heist-triggered-by-transient-storage-10909e4a255a); [ChainSecurity TSTORE Low-Gas Reentrancy](https://www.chainsecurity.com/blog/tstore-low-gas-reentrancy)
- **Relevance:** The SIR.trading exploit ($355K, March 30, 2025) is the canonical transient storage vulnerability. The attacker exploited raw slot reuse in `uniswapV3SwapCallback` where slot `0x01` stored both a pool address and a mint amount. By crafting a mint amount that matched a vanity address deployed via CREATE2, the attacker bypassed identity verification and drained the vault. Superform's `BaseHook` uses `keccak256(abi.encodePacked(HOOK_EXECUTION_STORAGE, context, offset))` for transient storage keys, with an auto-incrementing `executionNonce` creating unique contexts per execution. This makes the SIR.trading-style raw collision impossible. Additionally, the `preExecute`/`postExecute` mutexes prevent double-execution within a single context. However, the `executionNonce` is itself stored as `transient`, meaning it resets to 0 at the start of each transaction. If multiple hooks of the same contract are executed within one transaction, the nonce increments correctly within that tx. This is safe.
- **Risk Level:** P3 Low (mitigated)
- **Mitigation:** Current keccak256-keyed slot derivation is adequate. No action needed for the PSM hooks specifically. Continue using the existing `BaseHook` pattern.

### Finding 4: Approval Drain via Residual Allowance

- **Pattern:** Infinite/Residual Approval Exploitation
- **Source:** [Li.Fi Protocol Exploit (Jul 2024, $11.6M)](https://li.fi/knowledge-hub/incident-report-16th-july/); [SocketDotTech/Bungee Exploit (2024, $3.3M)](https://revoke.cash/exploits/lifi-2024); [ERC20 Approval Vulnerability Guide](https://scsfg.io/hackers/approvals/)
- **Relevance:** The Li.Fi exploit drained $11.6M from users who had set infinite approvals to the LiFi Diamond contract. An unvalidated `_swapData` parameter in a newly deployed facet allowed arbitrary `transferFrom` calls against those pre-existing approvals. The SocketDotTech exploit followed an identical pattern. The Spark PSM hooks use the defensive `approve(0) -> approve(exact) -> swap -> approve(0)` pattern, which ensures zero residual allowance after successful execution. On ERC-7579 batch revert, the entire transaction rolls back atomically, so no dangling approval persists. The `SwapSparkPSMExactInHook` and `SwapSparkPSMExactOutHook` (pre-approved variants) assume the caller has already approved the PSM -- this is acceptable because these hooks are designed for accounts that have set up standing approvals, and the PSM contract itself is immutable and permissionless.
- **Risk Level:** P3 Low (mitigated by approve-and-revoke pattern)
- **Mitigation:** The current implementation is correct. The 4-execution sequence (`approve(0) -> approve(exact) -> swap -> approve(0)`) is the industry-standard defensive pattern. No changes needed.

### Finding 5: ExactOut Approval Amount -- Must Approve maxAmountIn, Not amountOut

- **Pattern:** Incorrect Approval Amount for Variable-Input Swaps
- **Source:** Code review; this is a novel pattern specific to ExactOut swap semantics
- **Relevance:** In `ApproveAndSwapSparkPSMExactOutHook`, the PSM's `swapExactOut` function pulls a variable `amountIn <= maxAmountIn` from the caller. If the approval were set to `amountOut` instead of `maxAmountIn`, the swap would revert with insufficient allowance whenever the actual input exceeds the output amount (which happens in sUSDS conversions where the sUSDS rate means more input tokens are needed). The current implementation correctly approves `maxAmountIn` (line 103 of `ApproveAndSwapSparkPSMExactOutHook.sol`). When `usePrevHookAmount=true`, the scaled `maxAmountIn` from `HookDataUpdater` is used for both the approval and the swap call, which is also correct.
- **Risk Level:** P1 High (if incorrectly implemented; currently correct)
- **Mitigation:** Already correctly implemented. Add a specific unit test that verifies `executions[1]` (the approval) uses `maxAmountIn` and NOT `amountOut`. Add a fuzz test that varies the sUSDS rate to confirm the approval is always sufficient.

### Finding 6: PSM Rounding Direction Mismatch (Preview vs Actual)

- **Pattern:** Oracle/Price Precision -- Preview Function Divergence
- **Source:** [ChainSecurity Spark PSM Audit (Oct 2024)](https://www.chainsecurity.com/security-audit/spark-psm); [Spark PSM GitHub](https://github.com/sparkdotfi/spark-psm); [Spark PSM Docs](https://docs.spark.fi/dev/savings/spark-psm)
- **Relevance:** The ChainSecurity audit identified double rounding in PSM's internal `_getAsset2Value` function and noted that `totalAssets` rounds down when used as a divisor. The PSM's actual swap functions round in favor of the protocol: `swapExactIn` rounds output DOWN (user gets slightly less), `swapExactOut` rounds input UP (user pays slightly more). The `previewSwapExactIn`/`previewSwapExactOut` functions are documented to round in the same direction, but the PSM's `convertToAssets`/`convertToShares` helper functions explicitly round differently and "are meant to be used for general quoting purposes" only. If the Superform bundler uses `convertToAssets` instead of `previewSwapExactIn` to compute `minAmountOut`, the user could set a `minAmountOut` that is 1-2 wei too high, causing the swap to revert. This is a liveness issue, not a security exploit.
- **Risk Level:** P3 Low (liveness, not security)
- **Mitigation:** The bundler must use `previewSwapExactIn`/`previewSwapExactOut` (not `convertToAssets`/`convertToShares`) for computing slippage parameters, and add a 1-2 wei buffer. Document this requirement for bundler implementers.

### Finding 7: sUSDS Rate Manipulation Resistance

- **Pattern:** Oracle Manipulation / Flash Loan Price Attack
- **Source:** [OWASP SC02:2025 Price Oracle Manipulation](https://owasp.org/www-project-smart-contract-top-10/2025/en/src/SC02-price-oracle-manipulation.html); [OWASP SC07:2025 Flash Loan Attacks](https://owasp.org/www-project-smart-contract-top-10/); [Spark PSM Architecture](https://docs.spark.fi/dev/savings/spark-psm)
- **Relevance:** The sUSDS conversion rate comes from a `rateProvider` contract, which is governance-controlled and not derived from any on-chain pool or market. This means the rate cannot be manipulated via flash loans, unlike AMM-derived price oracles. The rate is monotonically increasing (sUSDS accrues yield over time), changing by approximately 1-4 basis points per day. The risk is limited to rate drift between when the user signs the intent and when the bundler executes the transaction. The `minAmountOut` (ExactIn) and `maxAmountIn` (ExactOut) slippage parameters protect against adverse rate movements.
- **Risk Level:** P3 Low (inherently resistant to manipulation)
- **Mitigation:** Current slippage parameter approach is correct. No additional oracle checks needed within the hooks.

### Finding 8: Zero Amount Propagation in Hook Chaining

- **Pattern:** Logic Error -- Zero-Value Edge Case
- **Source:** Code review of `HookDataUpdater.getUpdatedOutputAmount`; OWASP SC03:2025 Logic Errors; OWASP SC04:2025 Lack of Input Validation
- **Relevance:** When `usePrevHookAmount=true` and the previous hook's `getOutAmount(account)` returns 0, `HookDataUpdater` has the guard `if (_prevAmount == 0) return outputAmount` which returns the original slippage parameter unchanged, but `amountIn` (or `amountOut` for ExactOut) is set to 0. This means the PSM receives a swap request for 0 tokens with the original (potentially non-zero) `minAmountOut` -- which will revert because 0 input produces 0 output, below any non-zero `minAmountOut`. This is fail-safe behavior (reverts rather than producing incorrect results). However, if the original `minAmountOut` is also 0 (which the data layout permits), a 0-for-0 swap could succeed, propagating zero to the next hook in the chain. The PSM may or may not accept a 0-amount swap.
- **Risk Level:** P3 Low
- **Mitigation:** Consider whether the bundler should guard against 0-amount swaps before submitting. The on-chain behavior is fail-safe for non-zero slippage params. Add a test for the `prevAmount=0, minAmountOut=0` case.

### Finding 9: PSM Drainage Denial-of-Service

- **Pattern:** Economic Denial of Service / Liquidity Depletion
- **Source:** [ChainSecurity Spark PSM Audit -- Pocket Functionality](https://www.chainsecurity.com/security-audit/spark-psm); [Spark PSM Docs](https://docs.spark.fi/dev/savings/spark-psm)
- **Relevance:** The PSM has finite reserves of each token. A large swap could drain the PSM's reserves of a particular asset, causing subsequent swaps to revert. This is a temporary liveness issue -- the PSM is replenished by the Spark Liquidity Layer (ALM Controller). The ChainSecurity audit noted that the "pocket" mechanism can temporarily DoS withdrawals if misconfigured. This is a Spark-side operational risk, not a vulnerability in the Superform hooks.
- **Risk Level:** P3 Low (liveness, not security)
- **Mitigation:** The bundler should check PSM reserve levels before submitting swap transactions. No changes needed in the hook contracts.

### Finding 10: ERC-7579 Module Execution Context Security

- **Pattern:** Smart Account Module Trust Boundary
- **Source:** [ERC-7579 Specification](https://eips.ethereum.org/EIPS/eip-7579); [Rhinestone ERC-7579 Audit (Ackee Blockchain, Jun 2024)](https://ackee.xyz/blog/rhinestone-erc-7579-safe-adapter-audit-summary/); [ERC-7484 Registry](https://eips.ethereum.org/EIPS/eip-7484)
- **Relevance:** ERC-7579 specifies that module execution is controlled by the smart account. The hooks generate `Execution[]` arrays that are executed by the account in batch mode. Key security properties: (1) `preExecute`/`postExecute` verify `msg.sender == account`, preventing unauthorized callers from manipulating balance tracking state. (2) The `build()` function is `view` and returns execution arrays without side effects, so it cannot be exploited for state changes. (3) The hook execution is gated by SuperValidator's Merkle proof validation, which ensures only signed intents can trigger hooks. (4) Malicious hooks could revert in `preCheck`/`postCheck` to DoS the account (per ERC-7579 spec), but Superform's hook registry prevents installation of untrusted hooks.
- **Risk Level:** P3 Low (architecture provides adequate boundaries)
- **Mitigation:** Continue using the existing execution gating via SuperValidator Merkle proofs. No additional changes needed for PSM hooks.

### Finding 11: CurioDAO PSM Fork Governance Exploit -- Not Applicable

- **Pattern:** Governance Manipulation via Forked PSM Contracts
- **Source:** [CurioDAO Exploit (Mar 2024, ~$16M)](https://rekt.news/curio-rekt); [Quantstamp March 2024 Roundup](https://quantstamp.com/blog/monthly-hacks-roundup-march-2024)
- **Relevance:** CurioDAO forked MakerDAO's governance contracts (including PSM-adjacent code) without proper access control review. An attacker exploited voting power manipulation to mint ~1 billion CGT tokens. This is NOT applicable to the Superform hooks because: (1) Superform integrates with the canonical Spark PSM3, not a fork. (2) The PSM3 swap functions are permissionless -- no governance manipulation can affect swap execution. (3) The hooks do not interact with any governance or voting mechanism.
- **Risk Level:** Not Applicable
- **Mitigation:** None needed. Documented for completeness.

---

## 2. OWASP Smart Contract Top 10 (2025) Relevance Assessment

| OWASP Category | Applicable? | Assessment |
|---|---|---|
| **SC01: Access Control** | Partially | Hook execution gated by SuperValidator Merkle proofs. `preExecute`/`postExecute` verify `msg.sender == account`. PSM is permissionless. **Low risk.** |
| **SC02: Price Oracle Manipulation** | Partially | sUSDS rate from governance-controlled `rateProvider`, not flash-loan-manipulable. Slippage params protect against rate drift. **Low risk.** |
| **SC03: Logic Errors** | Yes | Key logic concern: ExactOut approval must use `maxAmountIn` not `amountOut`. Receiver must be forced to `account`. `inspect()` returns unvalidated receiver. **Medium risk -- currently implemented correctly but requires test coverage.** |
| **SC04: Input Validation** | Yes | Data length validated (`< 157` reverts). No token address validation (by design -- PSM validates). No amount range validation. **Low risk.** |
| **SC05: Reentrancy** | Yes | `nonReentrant` on `_processHook` in SuperExecutorBase. `preExecute`/`postExecute` mutexes prevent double-call. Transient storage keys are keccak256-derived. **Low risk (mitigated).** |
| **SC06: Unchecked External Calls** | No | PSM calls via `abi.encodeCall` with typed interface. Return values not checked, but ERC-7579 batch reverts on any failed execution. **Low risk.** |
| **SC07: Flash Loan Attacks** | No | sUSDS rate not derivable from pools. PSM pricing is oracle-based, not AMM-based. **Not applicable.** |
| **SC08: Integer Overflow/Underflow** | Partially | Solidity 0.8.30 has built-in overflow protection. `finalBalance - initialBalance` will revert on underflow (safe fail). `HookDataUpdater` uses `Math.mulDiv` (overflow-safe). **Low risk.** |
| **SC09: Insecure Randomness** | No | No randomness used. **Not applicable.** |
| **SC10: Denial of Service** | Partially | PSM drainage can cause swap reverts (temporary). Malicious hook data could cause reverts (but fails safe). **Low risk (liveness only).** |

---

## 3. Exploit Precedent Table

| Exploit | Date | Loss | Root Cause | Relevance to PSM Hooks | Mitigation Status |
|---|---|---|---|---|---|
| [SIR.trading](https://research.blockscope.co/sir-protocol-exploit/) | Mar 2025 | $355K | Transient storage slot collision (raw slot 0x01 reused for pool address and mint amount) | Directly relevant -- hooks use transient storage. Superform uses keccak256-keyed slots, preventing raw collision. | **Mitigated** |
| [Balancer V2](https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/) | Nov 2025 | $128M | Rounding direction error in `_upscale()` compounded across 65 batchSwap operations | Relevant precedent for rounding errors in swap contracts. PSM rounds in favor of protocol (down for ExactIn output, up for ExactOut input). | **Low risk** -- PSM rounding is documented and not compoundable |
| [Li.Fi Protocol](https://li.fi/knowledge-hub/incident-report-16th-july/) | Jul 2024 | $11.6M | Arbitrary call via unvalidated `_swapData` in newly deployed GasZipFacet, draining users with infinite approvals | Directly relevant -- hooks handle approvals. Approve-and-revoke pattern eliminates residual allowance. | **Mitigated** |
| [SocketDotTech/Bungee](https://revoke.cash/exploits/lifi-2024) | Jan 2024 | $3.3M | Incomplete input validation + infinite approvals | Same class as Li.Fi. | **Mitigated** |
| [CurioDAO](https://rekt.news/curio-rekt) | Mar 2024 | ~$16M | Voting power manipulation in forked MakerDAO governance contracts | Not applicable -- Superform uses canonical PSM3, not a fork. | **N/A** |
| [DeltaPrime](https://threesigma.xyz/blog/exploit/2024-defi-exploits-top-vulnerabilities) | 2024 | ~$6M | Unchecked `_repayAmount` parameter in `swapDebtParaSwap` | Relevant pattern -- input validation. PSM hooks validate data length but rely on PSM for amount validation. | **Low risk** -- PSM validates internally |
| [SenecaUSD](https://threesigma.xyz/blog/exploit/2024-defi-exploits-top-vulnerabilities) | 2024 | $6.5M | Arbitrary call draining approved tokens | Same class as Li.Fi. | **Mitigated** |

---

## 4. Attack Surface Map

### 4.1 Approve -> Swap -> Revoke Pattern (ApproveAndSwap hooks)

| Vector | Risk | Status |
|---|---|---|
| Approval not revoked after swap | Low | ERC-7579 batch atomicity -- either all succeed or all revert |
| ExactOut approves wrong amount | **High if wrong** | Correctly approves `maxAmountIn` (verified in code) |
| USDT-like zero-first requirement | Low | `approve(0)` as first step handles defensively |
| Front-running the approval tx | Low | Atomic batch -- no inter-transaction window |
| Residual approval on partial revert | Low | ERC-7579 batch is all-or-nothing |

### 4.2 Balance Tracking (Pre/Post Delta Pattern)

| Vector | Risk | Status |
|---|---|---|
| sUSDS rebasing between pre/post | Negligible | sUSDS is ERC-4626 shares, `balanceOf` is stable |
| External token transfer between hooks | Low | Only the account's own balance is tracked; no external interaction between preExecute and postExecute within the batch |
| Underflow on `finalBalance - initialBalance` | Low | Solidity 0.8.x panics safely on underflow |
| Receiver != account breaks tracking | **Critical if wrong** | Correctly hardcoded to `account` |
| Byte offset mismatch between pre/post | Medium | Both use `data.toAddress(20)` for assetOut -- consistent |

### 4.3 Hook Chaining (usePrevHookAmount)

| Vector | Risk | Status |
|---|---|---|
| Zero outAmount from prev hook | Low | Reverts safely with non-zero slippage params |
| Cross-decimal scaling (6 vs 18) | Medium | `HookDataUpdater` operates on raw integers -- bundler must construct data in correct decimal space |
| prevHook address spoofing | Low | Validated by SuperValidator Merkle proof |
| Circular hook chaining | Low | Execution model is sequential, not recursive |

### 4.4 PSM-Specific Risks

| Vector | Risk | Status |
|---|---|---|
| PSM drainage DoS | Low (liveness) | Temporary; replenished by Spark Liquidity Layer |
| sUSDS rate manipulation | Low | Governance-controlled, not flash-loan-manipulable |
| Preview vs actual rounding | Low (liveness) | Bundler adds 1-2 wei buffer |
| Double rounding in PSM internals | Low | ChainSecurity audit finding -- affects PSM, not hooks |
| Share inflation attack on PSM | N/A | PSM deployer responsibility, not hook concern |

---

## 5. Recommended Security Patterns

1. **Approval hygiene**: `approve(0) -> approve(exact) -> swap -> approve(0)`. For ExactOut, always approve `maxAmountIn` (NOT `amountOut`). Already implemented correctly.

2. **Receiver forced to account**: Hardcode `receiver = account` in `_buildHookExecutions`, ignore hook data receiver field. Already implemented correctly.

3. **Minimum data length**: `if (data.length < 157) revert INVALID_HOOK_DATA()` for all 4 hooks. Already implemented correctly.

4. **Address zero validation**: Constructor validates PSM address != address(0). Already implemented correctly.

5. **Consistent byte offsets**: `preExecute`, `postExecute`, and `_buildHookExecutions` all decode `assetOut` from offset 20. Already consistent across all 4 hooks.

6. **Transient storage hygiene**: Use keccak256-keyed slots with unique context per execution. Already implemented via `BaseHook` infrastructure.

7. **`inspect()` consistency**: Consider removing the unvalidated `receiver` from `inspect()` output, or documenting that it does not reflect the actual receiver used in execution. **Action item.**

---

## 6. Testing Recommendations

### Critical Invariants to Verify
1. **Receiver always account**: Decode swap calldata from `executions[0]` (or `executions[2]` for ApproveAndSwap), verify receiver == account
2. **No residual allowance**: After full execution, `allowance(account, PSM) == 0` for ApproveAndSwap hooks
3. **ExactOut approval uses maxAmountIn**: Verify `executions[1]` in `ApproveAndSwapSparkPSMExactOutHook` encodes `approve(PSM, maxAmountIn)`, not `approve(PSM, amountOut)`
4. **outAmount matches balance delta**: `getOutAmount(account) == postBalance - preBalance`
5. **Slippage respected**: If swap succeeds, output >= minAmountOut (ExactIn) or input <= maxAmountIn (ExactOut)
6. **Scaling preserves ratio**: `scaledSlippage / newAmount ~= originalSlippage / originalAmount` within PRECISION

### Fuzz Test Scenarios
- Slippage recalculation for both ExactIn and ExactOut with varying sUSDS rates
- Cross-decimal chaining: USDC(6) -> USDS(18) and USDS(18) -> USDC(6) via `usePrevHookAmount`
- ExactOut with maxAmountIn fully consumed vs partially consumed
- Zero amount from previous hook with zero and non-zero slippage params
- Large amounts near uint256 boundaries

### Edge Case Tests
- PSM revert -> verify atomic rollback, no residual approval
- `usePrevHookAmount=true, prevHook=address(0)` -> should revert gracefully
- Data length exactly 156 bytes (one byte short) -> INVALID_HOOK_DATA
- Data length exactly 157 bytes -> minimum valid
- sUSDS rate-based swap where rate changes between block.timestamp signing and execution

### Mock PSM Requirements
- Track `transferFrom` calls (verify approve ordering)
- Configurable return values for swapExactIn/swapExactOut
- Simulated token transfers to receiver
- Revert toggle for DoS testing
- Configurable sUSDS rate for rate-change scenarios

---

## 7. Summary Risk Table

| # | Finding | Risk Level | Status |
|---|---|---|---|
| 1 | `inspect()` returns unvalidated receiver | P2 Medium | **Action needed** -- consider fixing or documenting |
| 2 | HookDataUpdater precision loss in cross-decimal chaining | P2 Medium | **Needs fuzz tests** -- bundler must construct data correctly |
| 3 | Transient storage slot collision | P3 Low | Mitigated by keccak256-keyed slots |
| 4 | Approval drain via residual allowance | P3 Low | Mitigated by approve-and-revoke pattern |
| 5 | ExactOut approval must use maxAmountIn | P1 High (if wrong) | **Currently correct** -- needs explicit test |
| 6 | PSM preview vs actual rounding | P3 Low | Bundler adds buffer |
| 7 | sUSDS rate manipulation | P3 Low | Governance-controlled, not manipulable |
| 8 | Zero amount propagation | P3 Low | Fails safe with non-zero slippage |
| 9 | PSM drainage DoS | P3 Low | Liveness only, not security |
| 10 | ERC-7579 module trust boundary | P3 Low | Adequate architectural boundaries |
| 11 | CurioDAO PSM fork exploit | N/A | Not applicable -- using canonical PSM |

---

## Sources

### Audit Reports
- [ChainSecurity Spark PSM Audit (Oct 2024)](https://www.chainsecurity.com/security-audit/spark-psm) -- [Full PDF](https://cdn.prod.website-files.com/65d35b01a4034b72499019e8/6717c8b96db944f76d0612e3_ChainSecurity_SparkDAO_Spark_PSM_audit%201.pdf)
- [Rhinestone ERC-7579 Safe Adapter Audit (Ackee Blockchain, Jun 2024)](https://ackee.xyz/blog/rhinestone-erc-7579-safe-adapter-audit-summary/)

### Exploit Analyses
- [SIR Protocol Exploit -- Blockscope Research](https://research.blockscope.co/sir-protocol-exploit/)
- [SIR Exploit Analysis -- SlowMist](https://slowmist.medium.com/fatal-residue-an-on-chain-heist-triggered-by-transient-storage-10909e4a255a)
- [SIR Exploit -- DeFiHackLabs/SunSec](https://defihacklabs.substack.com/p/sir-exploit-355k-loss-vulnerability)
- [Balancer V2 Exploit -- Check Point Research](https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/)
- [Balancer Exploit -- Halborn](https://www.halborn.com/blog/post/explained-the-balancer-hack-november-2025)
- [Li.Fi Protocol Incident Report](https://li.fi/knowledge-hub/incident-report-16th-july/)
- [Li.Fi Hack Analysis -- SolidityScan](https://blog.solidityscan.com/li-fi-hack-analysis-521388128d22)
- [LiFi Protocol $9.7M Exploit -- QuillAudits](https://www.quillaudits.com/blog/hack-analysis/lifi-protocol-exploit)
- [CurioDAO Exploit -- Rekt](https://rekt.news/curio-rekt)
- [2024 Most Exploited DeFi Vulnerabilities -- Three Sigma](https://threesigma.xyz/blog/exploit/2024-defi-exploits-top-vulnerabilities)

### Security Standards and Guides
- [OWASP Smart Contract Top 10 (2025)](https://owasp.org/www-project-smart-contract-top-10/)
- [OWASP SC01: Access Control](https://owasp.org/www-project-smart-contract-top-10/2025/en/src/SC01-access-control.html)
- [OWASP SC02: Price Oracle Manipulation](https://owasp.org/www-project-smart-contract-top-10/2025/en/src/SC02-price-oracle-manipulation.html)
- [ERC-7579 Specification](https://eips.ethereum.org/EIPS/eip-7579)
- [ERC-7484 Registry Extension](https://eips.ethereum.org/EIPS/eip-7484)
- [ERC20 Approval Vulnerability Guide](https://scsfg.io/hackers/approvals/)

### Protocol Documentation
- [Spark PSM Documentation](https://docs.spark.fi/dev/savings/spark-psm)
- [Spark PSM GitHub Repository](https://github.com/sparkdotfi/spark-psm)
- [Sky Protocol Security Overview](https://developers.sky.money/security/security-measures/overview/)
- [Sky Bug Bounty -- Immunefi](https://immunefi.com/bug-bounty/sky/)

### Transient Storage Security
- [ChainSecurity: TSTORE Low-Gas Reentrancy](https://www.chainsecurity.com/blog/tstore-low-gas-reentrancy)
- [Hacken: Uniswap V4 Transient Storage Security](https://hacken.io/discover/uniswap-v4-transient-storage-security/)
- [EIP-1153 Specification](https://eips.ethereum.org/EIPS/eip-1153)
- [Verichains: EIP-1153 Security Analysis](https://blog.verichains.io/p/eip-1153-transient-storage-save-gas)
