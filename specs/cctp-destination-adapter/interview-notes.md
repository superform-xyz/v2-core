# CCTP Destination Adapter — Interview Notes

**Date:** 2026-09-21
**Feature:** `src/adapters/CCTPAdapter.sol` — destination-side adapter completing the CCTP V2 cross-chain flow
**Security mode:** auto-enabled (cross-chain, on-chain, token custody)

## Origin Question: Was the CCTP destination path deliberately skipped?

**Answer: No — incidental, not deliberate.** Evidence gathered before the interview:

1. `CCTPSendHook._buildHookExecutions` already builds `hookCallData` as
   `abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)`
   (`src/hooks/bridges/cctp/CCTPSendHook.sol`), which is byte-identical to the 6-tuple
   `DebridgeAdapter._decodeMessage` decodes at `src/adapters/DebridgeAdapter.sol:158`.
   The destination message format was designed for an adapter that was never written.
2. Shipped in PR #885 (`65f8b5ab`, SUP-19679 / SUP-19617) as a source-side-only milestone.
   `specs/cctp-bridge-hooks/interview-notes.md:14-16` explicitly planned destination execution
   ("append validator signature to composeMsg for executing operations on the destination chain").
3. All CCTP tests are burn-side only — `test/integration/cctp/CCTPHooksFork.t.sol` asserts build +
   burn, never destination receipt. No destination test exists.
4. Direct precedent: `specs/stargate-compose-adapter/spec.md` was a follow-up spec "completing the
   destination-side flow for the existing StargateSendHook". CCTP is the same pattern, never followed up.
5. Hooks are live in prod (Ethereum, Base, and others per `script/output/prod/*/`) with no adapter,
   so a CCTP transfer carrying `hookCallData` today has nothing to execute it.

## Controlling Mechanic

CCTP V2 does **not** auto-execute `hookData`. `MessageTransmitterV2.receiveMessage` verifies the
attestation and mints to `mintRecipient`, then stops. Whoever relays the message is responsible for
running the hook. Consequence: the adapter must be the `mintRecipient` (it needs custody to forward
funds) and must pull the message in itself — there is no push callback like Across's
`handleV3AcrossMessage` or Stargate's `lzCompose`.

*To be verified in Phase 3 research against Circle's `evm-cctp-contracts` (`examples/CCTPHookWrapper.sol`).*

## Key Decisions

### Scope
**Adapter only.** Build `src/adapters/CCTPAdapter.sol` against the existing `CCTPSendHook` payload
format (6-tuple, same as `DebridgeAdapter`). The SDK sets `mintRecipient` and `destinationCaller` to
the destination adapter address. No hook changes, no redeploy of live hooks, no new bytecode lock on
existing contracts.

Rejected: `CCTPSendHookV2` enforcing `mintRecipient == dstAdapter` on-chain (removes SDK trust but
adds a new hook + bytecode lock + deployment index); Circle Gateway destination path (separate milestone).

### Entrypoint
**`relay(message, attestation)` — wrapper pattern**, mirroring Circle's own `CCTPHookWrapper` example.
The adapter calls `MessageTransmitterV2.receiveMessage` itself, then parses `hookData` from the same
attested message bytes in the same transaction. Rationale: the hookData provably matches what Circle
attested, and the mint + execution are atomic.

Rejected: two-step `execute(message)` after a third-party relay (adapter cannot trust unattested
message bytes without re-verifying).

### Failure Handling
**Match `StargateAdapterV2` / `RelayAdapter`.** `try/catch` around
`SUPER_DESTINATION_EXECUTOR.processBridgedExecution`; transfer tokens to the target account regardless;
expose `claimFailedTransfer()` for stranded funds. Precedent: `StargateAdapterV2.sol:357`,
`RelayAdapter.sol:222`.

Rationale: the CCTP burn is already irreversible on the source chain, so reverting the relay strands
value rather than protecting it.

### Relay Trust
**`destinationCaller` restricted to the adapter address.** Guarantees the hook runs — no third party
can mint to the adapter without executing. `relay()` itself stays permissionless, so anyone can still
submit. Cost: the SDK must know each chain's adapter address at signing time.

Rejected: `bytes32(0)` permissionless receive (a third party could mint to the adapter without
executing the hook, stranding funds until rescue).

### Amount Forwarding
**Full adapter token balance**, consistent with `StargateAdapterV2` and `RelayAdapter`. Covers the
CCTP fee delta automatically. Accepted quirk: a direct USDC donation to the adapter is swept into the
next relay — identical to existing adapter behavior.

### Fee Reconciliation
CCTP deducts `maxFee` from the transferred amount, so the account receives less than the burn amount.
**Forward the actual received balance** and let `SuperDestinationExecutor`'s existing `intentAmounts`
check decide. The SDK sets `intentAmounts` net of `maxFee`. Same contract as every other adapter.

### Version & Chain Scope
**CCTP V2 only** (V1 carries no `hookData`). Deploy on every chain where `CCTPSendHook` is already
live — Ethereum, Base, Arbitrum, Optimism, Polygon, and remaining supported chains.

### Testing Strategy
**Mock transmitter + fork.** Unit tests against a `MockMessageTransmitterV2` covering the full adapter
surface (decode, forward, executor success, executor failure, claim path). Plus a fork test that
overrides the attester set (or impersonates) to exercise the real `MessageTransmitterV2` on mainnet
state. A valid Circle attester signature cannot be produced against forked mainnet state otherwise.

## Security Notes Carried Forward

- Replay protection: handled inside `MessageTransmitterV2` via nonces — adapter adds none.
  Merkle-root replay is handled by `SuperDestinationExecutor.isMerkleRootUsed`.
- Trust model: Circle is the sole attestation root (accepted centralization, documented in
  `specs/cctp-bridge-hooks/research/evm-security.md:9`).
- Token: USDC only — no fee-on-transfer, rebasing, or missing-return-value concerns, but `SafeERC20`
  still applies for the blocklist/pausable case.
- Custody window: the adapter holds USDC for the duration of one transaction only (mint → forward).
- Donation sweeping: accepted, matches existing adapters.
- Open: whether `destinationCaller` restriction plus permissionless `relay()` introduces any griefing
  vector (e.g. relaying with a gas limit that forces the executor `try/catch` into the failure path).

## Open Questions for Research

1. Confirm CCTP V2 hook execution semantics against Circle's `evm-cctp-contracts` — is
   `CCTPHookWrapper.sol` the canonical pattern, and what exactly does it verify?
2. Exact byte offsets of `hookData` within the attested CCTP V2 message (message header + `BurnMessageV2` body).
3. `MessageTransmitterV2` address per chain — canonical/deterministic like `TokenMessengerV2`
   (`0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d`)?
4. Whether `receiveMessage` returns enough information to avoid re-parsing the message body.
5. Griefing analysis on the permissionless `relay()` + `try/catch` combination (gas-limit forced failure).
