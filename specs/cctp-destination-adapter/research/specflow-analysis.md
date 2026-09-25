# SpecFlow Analysis — CCTP Destination Adapter

Synthesized from repo, framework, and security research (edge-case + flow coverage).

## Primary flow (happy path)
1. Source chain: user intent → `CCTPSendHook` calls `TokenMessengerV2.depositForBurnWithHook`, `mintRecipient = destinationCaller = CCTPAdapter`, `hookData = abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)`.
2. Circle attests the message (finalized ≥2000, or fast <2000 with `maxFee`).
3. Relayer (anyone) fetches `(message, attestation)` from Iris and calls `CCTPAdapter.receiveAndExecute(message, attestation)`.
4. Adapter: fail-fast checks → `receiveMessage` (mints `amount−feeExecuted` USDC to adapter) → measure balance delta → slice `hookData = message[376:]` → decode → `_tryTransfer` delta to `account` → `try` `processBridgedExecution` → destination hooks run (e.g. deposit into vault).

## Alternate / edge flows (each must be handled)
| Flow | Expected behavior |
|---|---|
| Invalid/insufficient attestation | `receiveMessage` reverts; whole tx reverts; nonce not consumed; relayer retries later |
| Replayed message (same nonce) | `receiveMessage` reverts (`usedNonces`) — CCTP-level replay stop |
| Replayed signed intent via a different transport | `processBridgedExecution` no-ops on used Merkle root (emits `...RootUsedAlready`); USDC already delivered to account |
| Account under-funded for intent (partial bridge) | executor emits `...ReceivedButNotEnoughBalance`, returns; USDC sits in account; recoverable via later intent |
| Account has no hooks installed | executor emits `...ReceivedButNoHooks`, returns; USDC in account |
| Destination hook set reverts | adapter `try/catch` → `emit ExecutionFailed`; USDC already delivered to account (delivery not unwound) |
| `account` transfer reverts (blacklisted/paused recipient) | `_tryTransfer` fails → escrow to `failedTransfers[account][USDC]`, `emit TransferFailed`; claimable later |
| Front-run relay by a griefer | Harmless — `account` is inside the attested body; griefer only pays gas to deliver exactly what the user signed |
| `message.length < 376` (truncated/garbage) | `require` fail-fast revert before any external call |
| Pre-seeded/donated USDC in adapter | Never swept — only the measured `post − pre` delta is forwarded |
| `mintRecipient != adapter` (misconfigured send) | fail-fast revert (assert) — nothing minted to a wrong place gets forwarded |
| Fast mode (`feeExecuted > 0`) | delta already nets the fee; delivery = actual minted amount |

## Gaps surfaced → folded into acceptance criteria
- Must transfer **balance delta**, never `balanceOf(this)` or the gross `amount`.
- Must `require(message.length >= 376)` and assert `mintRecipient == address(this)` before slicing/forwarding.
- Must check `receiveMessage` bool return in addition to relying on revert.
- Must `try/catch` the executor (returnbomb-safe) so a bad hook set can't unwind correct token delivery.
- Must provide a `claimFailedTransfer` escrow path (permanent-stranding otherwise, since `destinationCaller` locks the message to the adapter).
- Offsets (header 148, hookData 376) verified against Circle `MessageV2.sol`/`BurnMessageV2.sol` — re-assert in a unit test.
