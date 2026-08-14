# CCTP Destination Adapter — Interview Notes

**Date:** 2026-08-13
**Security mode:** auto-enabled (on-chain, cross-chain feature)

## Feature summary
Build the destination-side `CCTPAdapter` that completes Superform's CCTP V2 cross-chain flow. The source side already exists: `CCTPSendHook` / `ApproveAndCCTPSendHook` call `TokenMessengerV2.depositForBurnWithHook` and pack `abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)` into `hookData`. The missing piece is a destination contract that mints the USDC, extracts the payload, and drives `SuperDestinationExecutor.processBridgedExecution` — mirroring `AcrossV3Adapter` / `DebridgeAdapter` / `RelayAdapter`.

**Key structural difference vs existing adapters:** CCTP has **no push callback**. `MessageTransmitterV2.receiveMessage` only mints USDC to `mintRecipient`; it never forwards `hookData`. So the adapter must **actively pull**: a relayer calls `receiveAndExecute(bytes message, bytes attestation)`, the adapter calls `receiveMessage` itself, then acts on the payload. (Closest in spirit to `RelayAdapter`, which is solver-driven, but the adapter itself invokes the mint.)

## Decisions (interview round 1 — design)
1. **hookData source → parse from the attested message.** The adapter slices `hookData` from the raw `message` bytes it just verified via `receiveMessage`, using `BurnMessageV2` offsets. Trustless — the attestation authenticates those bytes; the relayer supplies nothing extra beyond `(message, attestation)`.
2. **destinationCaller → enforce = adapter.** Backend sets both `mintRecipient` and `destinationCaller` to the adapter (bytes32-left-padded). Only the adapter can call `receiveMessage`, so mint + hook execution are atomic in one tx; prevents a griefer minting USDC to the adapter without triggering execution (which would strand funds).
3. **Minted token → USDC-only, immutable.** Adapter holds an immutable USDC address per chain; measures its USDC balance delta from `receiveMessage` and forwards that to the account. Matches the USDC-centric CCTP hooks. (Generic Circle-token support via TokenMinter deferred.)
4. **Failure mode → leave in account, non-reverting.** Same as `DebridgeAdapter`: transfer USDC to the account first, then call `processBridgedExecution`, which emits events (`...ReceivedButNotEnoughBalance`, `...RootUsedAlready`, `...ReceivedButNoHooks`) instead of reverting. Funds sit safely in the SCA, recoverable via a later intent. Reverting is not viable anyway — `receiveMessage` consumes the CCTP nonce.

## Decisions (interview round 2 — security/ops/testing)
5. **Relayer access → permissionless.** Anyone can call `receiveAndExecute` with a valid `(message, attestation)`. Security is Circle's attestation + the executor's EIP-1271 signature and Merkle-root replay checks; `destinationCaller = adapter` already scopes the mint to this contract. No relayer allowlist to maintain.
6. **Reentrancy → stateless + `nonReentrant` guard.** Hold no mutable storage (like `DebridgeAdapter`) AND add a `ReentrancyGuard` on `receiveAndExecute`, since the executor runs arbitrary destination hooks. CEI ordering: mint → fund account → execute.
7. **Deployment → DeployV2Core adapters + config.** Add `CCTPAdapter` alongside `AcrossV3Adapter`/`DebridgeAdapter`, constructor `(messageTransmitterV2[chain], usdc[chain], superDestinationExecutor[chain])`, gated on CCTP availability. Locked bytecode + manifest like the others.
8. **Testing → fork + real transmitter, mocked attester.** Mainnet fork with the real `MessageTransmitterV2`; craft a valid CCTP V2 message with `hookData` and sign it with a controlled attester key (override the attester set via `vm`) so `receiveMessage` succeeds. Assert the full path: mint → fund account → `processBridgedExecution` runs the destination hooks + Merkle/replay behaviour. Plus unit tests for `_sliceHookData` offset correctness.

## Confirmed facts (from research this session)
- Send hook is CCTP **V2** (`ITokenMessengerV2.depositForBurnWithHook`), `src/hooks/bridges/cctp/CCTPSendHook.sol`. Signature is pulled from validator transient storage (`ISuperSignatureStorage.retrieveSignatureData`).
- `BurnMessageV2` body layout (offsets into `messageBody`): version[0:4], burnToken[4:36], mintRecipient[36:68], amount[68:100], messageSender[100:132], maxFee[132:164], expirationBlock[164:196], feeExecuted[196:228], hookDataLength[228:260], hookData[260:...].
- Destination handler interface `IMessageHandlerV2.handleReceiveFinalizedMessage/Unfinalized(sourceDomain, sender, finalityThresholdExecuted, messageBody)` is implemented by TokenMessengerV2 (mints); it does NOT forward hookData to mintRecipient.
- Executor entry: `ISuperDestinationExecutor.processBridgedExecution(tokenSent, targetAccount, dstTokens[], intentAmounts[], initData, executorCalldata, userSignatureData)`; `DebridgeAdapter` transfers funds to `account` BEFORE calling it.
- Finality: `minFinalityThreshold >= 2000` finalized, `< 2000` fast (fee via `maxFee`); adapter is agnostic.

## Open items to resolve during implementation
- Pin the exact CCTP V2 **message header** length/offsets (to locate `messageBody`) against Circle's vendored `MessageV2.sol` (body offsets confirmed; header reconstructed from memory).
- Confirm `IMessageTransmitterV2.receiveMessage(bytes,bytes) returns (bool)` signature and that it reverts (not returns false) on bad attestation — needed for the adapter's error handling.
- Per-chain addresses: `MessageTransmitterV2`, local USDC, `SuperDestinationExecutor`; and CCTP V2 chain-availability set (must match where the send hook is enabled).
- Backend/OMS must fill `mintRecipient` and `destinationCaller` with the destination adapter address (config-only; no hook Solidity change).
