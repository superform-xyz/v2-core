# Security Analysis Report

## Metadata
- **Target:** src/hooks/hypercore/ (6 contracts) + src/vendor/hyperliquid/ (2 interfaces) — PR #985, branch feat/hypercore-hooks
- **Mode:** review
- **Date:** 2026-08-20
- **Contract Types Detected:** cross-chain execution hooks (EVM → HyperCore), token approve+deposit hook
- **Files Analyzed:** 8 (plus BaseHook.sol, SuperExecutorBase.sol, BytesLib.sol as context)
- **Vulnerability Database:** superform-specs/guidelines/solidity/vulnerabilities.md (36 sections, 300+ patterns)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | — |
| P1 High | 0 | — |
| P2 Medium | 1 | No |
| P3 Low | 8 | No |

## Remediation Status (2026-08-20, same session)
- **Fixed:** P2-1 (destination↔token consistency check added to HyperCoreSendAssetHook, HYPE band-exception documented, 3 new tests), P3-7 (`virtual` dropped from the S2 surface in BaseHyperCoreWriterHook, matching MarkRootAsUsedHook/CircleGatewayAddDelegateHook precedent), P3-9 (unused IERC165 import removed). Locked bytecode: only HyperCoreSendAssetHook changed and was regenerated; the other four re-verified byte-identical.
- **No change needed:** P3-2/3/6 (repo-wide family conventions / verified self-healing residuals), P3-8 (deployment test already asserts the cap from locked bytecode).
- **Off-chain follow-ups:** P3-4 (bundler ordering rule for deposit→CoreWriter chains), P3-5 (deadline policy on roots containing AddApiWallet).

## Verdict
**PASS** — No P0 or P1 findings. The adversarial scan verified every probe against the actual code: byte offsets reconcile exactly against every `DATA_LENGTH`, BytesLib bounds-checks all reads (including unvalidated `inspect()` paths, which revert rather than misread), the envelope encoder's `bytes3(uint24)` conversion is width-exact and big-endian, `replaceCalldataAmounts` does not exist on any CoreWriter leaf's ABI, transient-storage contexts are isolated per account and hook, and the executor's `lastCaller` check defeats context-poisoning. No exploitable third-party theft path was found.

## P0 Findings
None found.

## P1 Findings
None found.

## P2 Findings (Should Fix)

### [1] SendAsset: no consistency check between `token` index and a system-address destination
- **File:** src/hooks/hypercore/HyperCoreSendAssetHook.sol:78-88
- **SWC:** SWC-123
- **Category:** Logic / silent-failure
- **Description:** The hook's flagship use case (per its own natspec) is withdrawing to HyperEVM by targeting the token's system address (`0x20… ‖ index`), but nothing checks that a destination inside the `0x20…` band matches the `token` field in the same payload. CoreWriter cannot revert, so a mismatched pair strands the balance permanently behind a successful receipt. `inspect()` surfaces only addresses, so the token index is invisible to sign-time tooling. Independently corroborated by external research: HyperCore spot sends are final, with no recovery mechanism or escape hatch.
- **Exploit Scenario:** An intent-builder bug (or malicious frontend) pairs `token = 150` with USDC's system address. The payload looks like a normal USDC withdrawal at signing, executes green, and the tokens are credited to an address nobody controls.
- **Vulnerable Code:**
  ```solidity
  if (destination == address(0)) revert ADDRESS_NOT_VALID();
  // no destination↔token consistency check
  executions = _coreWriterExecution(
      ACTION_SEND_ASSET, abi.encode(destination, SUB_ACCOUNT, NO_DEX, NO_DEX, token, amountWei)
  );
  ```
- **Secure Pattern:**
  ```solidity
  // If destination is in the 0x20… system-address band, its low bytes must equal the token index.
  if (uint160(destination) >> 152 == 0x20) {
      if (destination != address((uint160(0x20) << 152) | uint160(token))) revert DATA_NOT_VALID();
  }
  ```
  Caveat before adopting verbatim: HYPE is a documented exception to the `0x20…‖index` derivation rule (its system address is `0x2222…2222`), so the check must either exclude HYPE's index or be encoded from a verified per-token table. PR #985 already documents this as off-chain responsibility; this finding argues the invariant is (mostly) checkable on-chain and the family's "payload correctness is the entire defence" doctrine argues for enforcing it.
- **Reference:** vulnerabilities.md §14.3, §10.6, §16

## P3 Findings (Consider Fixing)

### [2] Deposit hook `_postExecute` underflow-reverts if balance increases net during the hook
- **File:** src/hooks/hypercore/ApproveAndHyperCoreDepositHook.sol:184 — SWC-101, DoS/arithmetic
- Pre-minus-post balance diff panics if the balance rises (donation mid-tx, refund, rebase). Repo-wide convention (14 hooks identical); fail-safe revert, curated TOKEN. Griefing DoS at worst. §7.4

### [3] Deposit hook outAmount measures EVM spend, not HyperCore credit
- **File:** src/hooks/hypercore/ApproveAndHyperCoreDepositHook.sol:179-186 — token-integration
- For a fee-on-transfer TOKEN the Core credit would be less than outAmount; a chained consumer would oversize. Mitigated by curated per-token deployments — document "no FoT tokens" as a deployment invariant. §10.1

### [4] Intra-tx chaining deposit → CoreWriter action relies on unguaranteed HyperCore-side ordering
- **Files:** ApproveAndHyperCoreDepositHook + UsdClassTransferHook/SendAssetHook — cross-domain-async
- One EVM tx, but the gateway credit and the CoreWriter action settle asynchronously on Core; if the credit lands second, the action silently no-ops and the signed intent is partially executed behind a green receipt (no loss — funds stay in the user's spot balance). Needs a bundler-side ordering rule or separate intents; matches the plan-of-record's read-back doctrine. §16.3, §39

### [5] AddApiWallet creates standing 90-day authority; interacts with infinite-deadline intents
- **File:** src/hooks/hypercore/HyperCoreAddApiWalletHook.sol:88 — intent-lifetime
- A stale deadline-less signed root containing this leaf can re-enroll a rotated/compromised agent later. Recommend a bundler/validator policy requiring a deadline on any root containing this leaf. External research corroborates the risk class (2025: ~$21M loss from a compromised Hyperliquid agent key; Hyperliquid warns against re-enrolling retired addresses — nonce pruning reopens replay). §39.2

### [6] Approve return values unchecked in built executions (accepted residual)
- **File:** src/hooks/hypercore/ApproveAndHyperCoreDepositHook.sol:113-120 — SWC-104
- Verified self-healing: failed approve is caught by the deposit's transferFrom revert; exact-amount consumption leaves zero residual allowance; USDT-race handled by leading approve(0). Residual only under false-returning token + partially-consuming gateway, both pinned/trusted. §8.1, §10.5

### [7] S2 sizeless guarantee is regressible by future leaves
- **File:** src/hooks/hypercore/BaseHyperCoreWriterHook.sol:104-129 — defense-in-depth
- `_pipeMode` is deliberately non-virtual but `supportsInterface`/`decodeAmounts`/`amountRoles` are `virtual`; a future leaf could re-expose sizing. Drop `virtual` for symmetry. §15

### [8] Builder-fee cap is a pure deployment-parameter risk (already misdeployed once, 10×)
- **File:** src/hooks/hypercore/HyperCoreApproveBuilderFeeHook.sol:44-48 — deployment-config
- The decibps unit was wrong once (fixed in 563ee53f with a regression test). Cap is unverifiable on-chain; add a deploy-script assertion (100 perps / 1000 spot) and pin the deployed value per chain. Related open item from the plan of record: the same unit class also governs `GATEWAY_ARG`, where §04 of the plan (0xffffffff) contradicts the shipped constant (0) — resolve empirically before deploy.

### [9] Unused `IERC165` import
- **File:** src/hooks/hypercore/ApproveAndHyperCoreDepositHook.sol:8 — SWC-131, code quality
- Imported but never referenced (the contract doesn't override `supportsInterface`). Delete the line. §15.4

## Attack Surface Summary
- **External Entry Points:** `build`/`inspect` (view, unauthenticated — safe), `preExecute`/`postExecute` (gated `msg.sender == account`), `decodeAmounts`/`amountRoles`/`decodeUsePrevHookAmount`/`replaceCalldataAmounts` (pure, bundler-facing).
- **Value Transfer Points:** only ApproveAndHyperCoreDepositHook (TOKEN → GATEWAY, both immutables). The four CoreWriter leaves move no EVM value; they emit one call to the immutable CORE_WRITER.
- **Oracle Dependencies:** none (NONACCOUNTING; no SuperLedger participation).
- **Cross-Contract Interactions:** CoreWriter (no-validation, no-revert system contract — the defining risk, mitigated by typed leaves, exact-length pinning, byte-exact mainnet fixtures, and the off-chain read-back doctrine), the per-token deposit gateway (credits msg.sender only; no recipient parameter to abuse).
- **Upgrade Mechanisms:** none — all immutables, no admin functions, no proxies.
- **Identity binding (research-verified):** CoreWriter's actor and the gateway's credit target are both `msg.sender` = the smart account, which is the intended HyperCore master by design; the deployment test asserts TOKEN ≠ GATEWAY.

## Coding Standards Findings
One violation (finding 9, unused import). Everything else compliant: NatSpec with parser-conformant data-layout blocks, custom errors throughout, house naming/import conventions, explicit visibility, fixed pragma 0.8.30, zero-address checks on all constructor and decoded addresses, approve-bracketing identical to the ApproveAndX family, and the 64-byte agent-name cap preventing calldata gas-griefing. The duplicated `DATA_NOT_VALID` declaration is forced by inheritance and consistent with the repo's (unstandardized) data-error naming.

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 2, 3, 7, 8, 9, 10, 14, 15, 16, 20, 36, 39, 50, 51 (50/51 verified N/A: no bridge-receiver code, no try/catch)
- **External research:** Chainstack CoreWriter/bridge deep-dive, QuillAudits Hyperliquid architecture, HyperPC CoreWriter guide, OWASP SC Top 10 (2025) — SC01/SC03/SC04/SC06 relevant; SC05/SC07/SC09/SC10 not applicable to stateless encoder hooks
- **Historical exploits cross-referenced:** 2025 Hyperliquid agent-key compromise (~$21M), JELLY oracle incident (context only — not applicable to these hooks), 563ee53f internal 10× fee-cap regression
- **Coding rules validated:** full coding-rules.md pass + vulnerabilities.md §15/§36 checklist
