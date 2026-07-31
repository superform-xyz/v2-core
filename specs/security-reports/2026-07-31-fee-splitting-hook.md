# Security Analysis Report

## Metadata
- **Target:** `src/hooks/tokens/FeeSplittingHook.sol`
- **Mode:** review (inline critical-pattern scan + 3 parallel agents: vulnerability scanner, best-practices, external EVM research)
- **Date:** 2026-07-31
- **Contract Types Detected:** token (ERC-7579 hook module, stateless transfer builder)
- **Files Analyzed:** 1 target + context (`BaseHook.sol`, `BatchTransferHook.sol`, `TransferHook.sol`, `SuperExecutor.sol`, `SECURITY.md`, unit + integration tests)
- **Vulnerability Database:** NOTE — `/guidelines/solidity/vulnerabilities.md` and `/guidelines/solidity/coding-rules.md` are not present on this machine; analysis used SWC registry, OWASP SC Top 10 (2025), weird-erc20, ERC-7579 audit literature, and house style derived empirically from sibling hooks.

## Execution model (context for all severity calls)
`build()` is view-only and stateless; the returned `Execution[]` runs **on the user's own smart account against its own balance**; the hook address + full calldata are committed in the user's Merkle-signed intent (SuperValidator). `SuperExecutor._processHook` is `nonReentrant`, wraps with pre/post mutexes, and validates `lastCaller` post-execution. Consequently, third-party "attacker drains victim" patterns do not apply; the real surface is weird-token behavior inside the atomic batch, off-chain consumers of `inspect()`, and deploy-time configuration.

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|--------------|
| P0 Critical | 0 | — |
| P1 High | 0 | — |
| P2 Medium | 1 | No |
| P3 Low | 7 | No |

## Verdict
**PASS** — No P0 or P1 findings. Safe to proceed. P2/P3 items below are advisory; several have one-line fixes worth taking before merge.

## Remediation status (2026-07-31, same day)
- **F-1 FIXED** — build now reverts `ADDRESS_NOT_VALID` for zero/codeless `tokens[i]` on the ERC20 path (`tokens[i].code.length == 0` check). Residual: false-returning tokens with code remain undetectable at build time (codebase-wide raw-transfer stance).
- **F-3 FIXED** — `inspect()` and `_buildHookExecutions` now share `_decodeTransfers()`, which enforces `INVALID_DATA_LENGTH`, `LENGTH_MISMATCH`, and `TOO_MANY_TRANSFERS` identically in both.
- **F-4 FIXED (zero-amount leg)** — `AMOUNT_NOT_VALID` on `amounts[i] == 0`. Reverting/blocklisted receivers remain an accepted push-payment trade-off (documented, user-signed).
- **F-5 FIXED** — `_pipeMode()` overridden to `PASSTHROUGH`; previous hook's outAmount/outToken now forwarded (unit-tested via MockHook, integration-tested in the chained vault-deposit flow).
- **F-6 FIXED** — `INVALID_DATA_LENGTH` custom error for `data.length <= 52` replaces the arithmetic panic.
- **F-2 NOT APPLIED** (inspect still returns receivers only — deliberate, matches BatchTransferHook precedent). **F-7/F-8** partially addressed (new errors have NatSpec); remaining items open.
- Tests after fixes: 22 unit + 6 fork integration, all green.

---

## P0 Findings (Critical)
None found.

## P1 Findings (High)
None found.

## P2 Findings (Medium)

### [F-1] Silent fee-payment failure: unchecked `transfer` return value and no zero-address/code check on `tokens[i]`
- **File:** src/hooks/tokens/FeeSplittingHook.sol:84-88
- **SWC:** SWC-104 (Unchecked Call Return Value)
- **Category:** Token
- **Consensus:** flagged independently by all three agents (researcher argued P1; settled at P2 given SECURITY.md trade-off #8 "protocol fees may be bypassed in edge cases" and identical pattern in `BatchTransferHook`)
- **Description:** The ERC20 branch emits raw `IERC20.transfer` calldata. The account's execution checks only low-level call success — nothing decodes the returned `bool`, and nothing checks `tokens[i]` has code. Silent no-op modes: (a) false-returning tokens (ZRX/EURS-style); (b) any codeless address — including `address(0)`, since only `receivers[i]` is zero-checked, and undeployed/typo addresses — "succeeds" with empty returndata. Because the hook is NONACCOUNTING, no on-chain component verifies the fee actually moved. `TransferHook` (sibling) does validate `token != address(0)`; this hook and `BatchTransferHook` omit it.
- **Exploit Scenario:** An intent embeds a fee-split leg using a false-returning or codeless token address. The userOp executes fully; any off-chain system treating "FeeSplittingHook executed" as proof of fee payment is deceived — fees are skippable while the strategy proceeds.
- **Vulnerable Code:**
  ```solidity
  if (receivers[i] == address(0)) revert ADDRESS_NOT_VALID();
  ...
  executions[i] = Execution({
      target: tokens[i],
      value: 0,
      callData: abi.encodeCall(IERC20.transfer, (receivers[i], amounts[i]))
  });
  ```
- **Secure Pattern (minimum, build-time):**
  ```solidity
  if (receivers[i] == address(0) || tokens[i] == address(0)) revert ADDRESS_NOT_VALID();
  if (tokens[i] != NATIVE_TOKEN && tokens[i].code.length == 0) revert ADDRESS_NOT_VALID();
  ```
  Stronger option: verify receiver balance deltas in `_postExecute`, mirroring `SuperExecutorBase._performErc20FeeTransfer`. False-returning tokens remain undetectable at build time — that residual is the codebase-wide raw-transfer stance; restrict exotic tokens via off-chain policy.
- **References:** weird-erc20 (no-revert-on-failure), OWASP SC06:2025, Sherlock 2025 lend-audit #579

## P3 Findings (Low)

### [F-2] `inspect()` omits token addresses — execution *targets* escape the inspection surface
- **File:** src/hooks/tokens/FeeSplittingHook.sol:118-128
- **Category:** Logic
- **Description:** `inspect()` returns only packed `receivers[]`, but each execution's call target is `tokens[i]` (arbitrary address, fixed selector `0xa9059cbb`). Off-chain validators/UIs/allowlists consuming `inspect()` as the external-surface description see where value goes but not which contracts get called. House precedent is mixed: `BatchTransferHook` packs only `to`, but `TransferHook` packs token + to. No on-chain consumer of `inspect()` exists in `src/`.
- **Escalation condition:** if any policy layer allowlists hook interactions from `inspect()` output, treat as P2 and add `tokens[i]` immediately.
- **Secure Pattern:** pack `tokens[i]` alongside receivers (addresses only, preserving the inspector contract).

### [F-3] `inspect()` skips `LENGTH_MISMATCH` / `MAX_TRANSFERS` validation
- **File:** src/hooks/tokens/FeeSplittingHook.sol:118-128
- **Category:** Logic
- **Description:** A payload with mismatched array lengths or >50 entries inspects cleanly while `build()` always reverts — a UI can display receivers for an intent guaranteed to fail. Adversarial check performed: `inspect()` can NOT show receivers X while execution pays receivers Y — both run identical strict `abi.decode` on identical bytes, so any payload that decodes for one decodes identically for the other. Exposure is limited to misleading previews/griefing, not fund misdirection.
- **Secure Pattern:** decode all three arrays in `inspect()` and apply the same two checks as `_buildHookExecutions`.

### [F-4] Push-payment batch DoS: reverting receivers, blocklisted tokens, zero-amount legs
- **File:** src/hooks/tokens/FeeSplittingHook.sol:79-88
- **SWC:** SWC-113 (DoS with Failed Call)
- **Category:** DoS
- **Description:** All ≤50 legs execute atomically; one bad leg reverts the entire intent: (a) native receiver contract reverting in `receive()`; (b) USDC/USDT-blocklisted receiver; (c) revert-on-zero-amount tokens combined with the missing zero-amount check (an off-chain fee computation that rounds a leg to 0 bricks the intent). Receivers are fixed in the user-signed payload, so this is mostly self-inflicted — but SECURITY.md allows infinite-deadline intents, so a third-party fee receiver that later toggles into a reverting/blacklisted state permanently DoSes long-lived signed intents (griefing only; atomic revert is fail-safe).
- **Secure Pattern:** reject or skip `amounts[i] == 0` at build time; document that native fee receivers must accept plain ETH sends; keep third-party receivers as EOAs or use pull-payment escrow if the receiver set becomes open-ended.

### [F-5] Default `TRANSFORM` pipe mode leaves `outAmount = 0` — mid-chain composition footgun
- **File:** src/hooks/tokens/FeeSplittingHook.sol (no `_pipeMode`/`_postExecute` override; cf. BaseHook.sol:293-298, 347-349)
- **Category:** Logic
- **Description:** The hook never sets `outAmount`/`outToken`, so a downstream hook with `usePrevHookAmount` immediately after a fee split reads 0. The natural chain "swap → split fee → deposit remainder" silently deposits 0 or reverts. `PipeMode.PASSTHROUGH` exists in BaseHook precisely for side-effect-only hooks and auto-forwards the previous hook's output. Same behavior as `BatchTransferHook` (shared design decision), but sharper here because a fee splitter is *meant* to sit mid-chain. Caught in simulation; no fund loss (funds strand recoverable in the account).
- **Secure Pattern:**
  ```solidity
  function _pipeMode() internal pure override returns (PipeMode) { return PipeMode.PASSTHROUGH; }
  ```

### [F-6] `data.length < 52` reverts with `Panic(0x11)` instead of a custom error
- **File:** src/hooks/tokens/FeeSplittingHook.sol:67, 119
- **Category:** Logic (robustness/diagnostics only)
- **Description:** `data.length - 52` underflows under 0.8 checked arithmetic before BytesLib's own bounds guard runs; `data.length == 52` yields an empty slice that reverts in `abi.decode`. Fail-safe in all cases — no over-read, no fund impact; inherited from siblings. Opaque panic complicates debugging failed userOps.
- **Secure Pattern:** `if (data.length <= 52) revert INVALID_DATA_LENGTH();` before slicing.

### [F-7] `NATIVE_TOKEN` sentinel is an unvalidated deploy-time immutable
- **File:** src/hooks/tokens/FeeSplittingHook.sol:37-41
- **Category:** Configuration
- **Description:** If deployed with a real ERC20 address (e.g. WETH passed by a script bug), every leg for that token becomes a raw native send of `amounts[i]` wei; if `address(0)`, zero-token legs take the native path (masking part of F-1). Per-chain risk grows with multi-chain deploys (Sonic, HyperEVM recently added). `SuperExecutorBase` hardcodes the `0xEeee…` sentinel — divergence is possible.
- **Secure Pattern:** deployment-script assertion that the constructor arg equals the protocol-wide sentinel and has no code; optionally `require(_nativeToken != address(0) && _nativeToken.code.length == 0)` in the constructor.

### [F-8] Code quality (best-practices agent, consolidated)
- **File:** src/hooks/tokens/FeeSplittingHook.sol
- **Category:** Gas / Documentation
- Items:
  1. `inspect()` builds output via repeated `abi.encodePacked(out, …)` — O(n²) memory copying; preallocate `new bytes(len * 20)` and write with assembly (lines 122-127). Also unbounded there (see F-3).
  2. `LENGTH_MISMATCH` and `TOO_MANY_TRANSFERS` errors lack NatSpec (lines 29-30); BaseHook documents every error.
  3. `_buildHookExecutions` missing `/// @inheritdoc BaseHook` (line 57).
  4. `MAX_TRANSFERS` `@notice` states what, not why 50 — add a `@dev` gas/DoS rationale (lines 32-33).
  5. `_buildHookExecutions` sits under the "VIEW METHODS" banner (copied from siblings; house-consistent, informational).

---

## Informational (no severity)
- **ERC-777/1363 transfer hooks:** receiver callbacks execute mid-batch with the account mid-strategy. Hook-level reentrancy is blocked (stateless hook, BaseHook mutexes, executor `nonReentrant` + `lastCaller` check); residual is strategy-composition ordering — fee legs typically run last anyway.
- **Fee-on-transfer/rebasing tokens:** receiver gets less than `amounts[i]`; nothing on-chain breaks (NONACCOUNTING is a feature here); reconcile fees off-chain by balance delta.
- **`abi.encodePacked` in `inspect()`:** not a collision risk (fixed 20-byte elements), but a single-receiver output is byte-identical to `BatchTransferHook.inspect` output — consumers must key on hook address.
- **Duplicate receivers / duplicate (token, receiver) pairs:** allowed, benign, user-signed.
- **Return-bombing on ETH legs:** worth a one-time confirmation that the supported accounts' execution helpers don't copy unbounded returndata from plain value transfers (repo already vendors ExcessivelySafeCall elsewhere).

## Attack Surface Summary
- **External entry points:** `build` (view), `inspect`/`decodeAmounts`/`amountRoles`/`supportsInterface` (pure/view), `preExecute`/`postExecute` (BaseHook, `msg.sender == account` + mutexes), `setExecutionContext`/`resetExecutionState` (BaseHook, executor-driven).
- **Value transfer points:** the account's own balance via built executions — ERC20 `transfer` per leg, plain ETH send per native leg. The hook never custodies funds.
- **Oracle dependencies:** none.
- **Cross-contract interactions:** arbitrary `tokens[i]` targets with fixed `transfer` selector; arbitrary `receivers[i]` targets for ETH — both gated entirely by the user-signed Merkle intent.
- **Upgrade mechanisms:** none (immutable, stateless).

## Inline Critical-Pattern Scan (10/10 checked)
Reentrancy ✓ · Access control ✓ · Div-before-mul N/A · Unchecked returns ✗ (F-1) · Reentrancy guards N/A · encodePacked collisions ✓ · tx.origin ✓ · Locked pragma ✓ (0.8.30) · Returnbomb try/catch N/A · Trusted-caller/untrusted-params ✓ (payload user-signed)

## OWASP SC Top 10 (2025) mapping
SC06 Unchecked External Calls → F-1 (primary) · SC04 Input Validation → F-1/F-2 · SC10 DoS → F-4 · SC05 Reentrancy → marginal, mitigated · SC01/SC02/SC03/SC07/SC08/SC09 → not applicable.

## Test Coverage Assessment
Existing: 14 unit + 6 fork integration tests (real ERC-4337 flow) — constructor, pairwise builds (ERC20/native/mixed), both length-mismatch permutations, zero receiver, MAX_TRANSFERS boundary (50 pass / 51 revert), inspector packing, sizeless interface, 4337-revert balance rollback, composition with a real ERC4626 deposit.
Gaps: no `tokens[i] == address(0)` test (would have surfaced F-1's silent no-op); no zero-amount test; no reverting-native-receiver integration test (F-4); no fuzz tests; `inspect()` untested with mismatched/oversized arrays; pre/post wrapper positions asserted by count only.

## Security Knowledge Sources
- SWC registry; OWASP Smart Contract Top 10 (2025); d-xo/weird-erc20; OpenZeppelin PaymentSplitter/pull-over-push literature; Sherlock/C4 unchecked-transfer & zero-transfer findings; PeckShield ERC-777 analyses (imBTC/Lendf.Me); Ackee Rhinestone ERC-7579 audit; repo `SECURITY.md` trade-offs #3, #4, #5, #8, #10.
- Superform vulnerability DB (`/guidelines/solidity/vulnerabilities.md`) unavailable on this machine — flagged for re-run where present.
