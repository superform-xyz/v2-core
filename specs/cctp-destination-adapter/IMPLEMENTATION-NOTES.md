# Implementation Notes — deviations from `technical-spec.md`

The adapter was **already implemented** on `feat/cctp-destination-adapter` before this session's spec
was written. Rather than rebuild, the branch was rebased onto `dev` and hardened against the research.
The following differ from `technical-spec.md`; the spec's version is superseded where noted.

## 1. Constructor: 3 args, not 2 — **spec superseded**
Shipped: `(messageTransmitter, tokenMessenger, usdc, superDestinationExecutor)`, with USDC as an explicit
immutable. `tokenMessenger` was added in review Round 4 (P2-2 fix, below); the deploy script passes the
chain-invariant `CCTP_V2_TOKEN_MESSENGER` constant, so it adds no per-chain config.
The spec proposed 2 args (deriving the token from `dstTokens[0]`) to preserve one CREATE2 address
across chains.

**Decision: keep 3 args as built.** The per-chain USDC immutable means per-chain adapter addresses, so
the SDK resolves the adapter per destination chain — exactly as it already does for `AcrossV3AdapterV2`
(10 addresses) and `StargateAdapterV2` (14). `ConfigCore` entries for this were already written.

## 2. Entrypoint named `receiveAndExecute`, not `relay`
Cosmetic; `receiveAndExecute` is more descriptive of the mint-then-execute sequence. No behavioral
difference.

## 3. Gas floor is a floor only — **spec corrected**
The spec called for `MIN_EXECUTION_GAS` **plus** a `{gas: G}` stipend on the executor call. A stipend
would **cap** legitimate long hook chains at G, which is a bug. Shipped: a `gasleft() >=
MIN_EXECUTION_GAS` check that reverts, then forwards all remaining gas.

Reverting (rather than proceeding into the catch) is the right behavior here: it unwinds the mint, so
the CCTP nonce is **not** consumed and the message stays retriable by a caller supplying enough gas.
`MIN_EXECUTION_GAS = 500_000`.

## 4. Executor/validator assertion is self-called — **spec corrected**
The spec sketched a plain internal `_assertDestinationTargets` that would "no-op on undecodable
sigData". That is impossible: `abi.decode` on garbage **panics**, it does not return.

Shipped: `checkDestinationTargets(bytes) external view returns (uint8)` — external solely so
`receiveAndExecute` can self-call it inside `try/catch`, mirroring `StargateAdapterV2:239-247`. It
returns a code rather than reverting, so the caller distinguishes:
- **malformed blob** → caught, ignored (funds still delivered; the executor's own signature check
  handles it)
- **explicit mismatch** → `EXECUTOR_NOT_VALID` / `VALIDATOR_NOT_VALID` revert (fail closed, message
  retriable)
- **no proof for this chain** → `MATCH_OK`, funds delivered, executor no-ops (matching
  `StargateAdapterV2`'s graceful `NoDstProofForChain`)

## 5. No `totalEscrowed` mapping
The spec carried `totalEscrowed` over from `RelayAdapter`. It exists there to stop a **caller-supplied
amount** from raiding other users' escrow. This adapter derives its amount from a measured mint delta,
so escrowed balances are structurally unreachable — `totalEscrowed` would be dead weight. The
prior implementation's NatSpec already made this argument correctly.

## 6. Delta cross-check added as specified
`minted = min(postBalance - preBalance, amount@216 - feeExecuted@312)`. Covered by
`test_CrossCheck_ClampsToAttestedAmount` and `test_CrossCheck_UsesDeltaWhenSmaller`.

## 7. Version check added as specified
`uint32` at offset 0 must equal 1; V1 messages carry no hookData and are rejected before any external
call. Covered by `test_Revert_UnsupportedMessageVersion`.

## Bytecode

`script/run/tooling/regenerate_bytecode.sh CCTPAdapter` updates only `generated-bytecode/`. The
`locked-bytecode/` and `locked-bytecode-dev/` copies were synced **manually** — as the research
documented, there is no automated path into the locked set.

⚠️ **This matters for anyone deploying:** the deploy script reads `locked-bytecode/`. Any further
change to `CCTPAdapter.sol` must be followed by regeneration **and** a manual re-sync, or a deploy will
silently ship stale bytecode. All three artifacts are currently in sync at `f2075b9a…`.

## Test status

- `test/unit/adapters/CCTPAdapterUnitTests.t.sol` — **22 passed** (13 pre-existing + 9 new)
- `test/integration/cctp/CCTPAdapterE2EFork.t.sol` — **4 passed** against real mainnet state
- `test/unit/adapters/CCTPPayloadSizeGate.t.sol` — **6 passed** (Phase 0 gate)
- All adapter suites — **113 passed**, no regressions
- `test/script/` — **5 passed**

## Still open

- The permissionless-`relay` divergence from Circle's `onlyOwner` `CCTPHookWrapper` is documented in
  contract NatSpec, but has not been through security review.
- BSC (CCTP domain 17) USDC support remains unverified — confirm before deploying there.
- Destination intents chaining a **swap** hook (1inch/Odos carry raw router calldata, far larger than
  the 125-byte model) were not measured in Phase 0. Measure before shipping that shape over CCTP.


## Round 4 (2026-09-22): non-USDC CCTP token routing (security P2-2)

**Problem.** CCTP V2 is multi-token: Circle registers each supported token per remote domain in
`TokenMinterV2`. The source hooks accept any `burnToken` (only a non-zero check,
`CCTPSendHook.sol:113`), so an SDK mistake could burn a non-USDC CCTP token with `mintRecipient = destinationCaller =
adapter`. The adapter measured only the USDC delta, hit `NOTHING_MINTED`, and — because
`destinationCaller` pins the message to this adapter — the burned funds could never be consumed by
anyone. **Round-5 correction:** this IS reachable today. Ethereum's `TokenMinterV2` has USYC linked (from BNB, domain 17; `burnLimitsPerMessage(USYC) == 7.5e13`, verified live 2026-09-22). Base is USDC-only. EURC is *not* the example: Circle routes EURC through a separate `CrossChainTokenService` that never touches `TokenMinterV2` (`getLocalToken(0, EURC_ETH) == 0` on both chains). USYC is a permissioned token, so a USYC mint into a non-allowlisted adapter reverts inside `receiveMessage` — that (self-inflicted, KYC'd-burner-only) case still strands the burn (the mint revert is confirmed on-chain via `eth_call`; the routing is proven against the real Ethereum registry in `test_Fork_Ethereum_RealRegistry_RoutesUsycToNonUsdcBranch`); accepted and documented in the Round-5 report.

**Fix.** Before `receiveMessage`, resolve the local token exactly as the transmitter's mint path does:
`TOKEN_MESSENGER.localMinter().getLocalToken(sourceDomain@4, burnToken@152)`.
- `address(0)` → `UNSUPPORTED_BURN_TOKEN()` (the transmitter's own mint would revert on the same lookup;
  nothing to rescue, but the reason is legible and the message stays unconsumed).
- `!= USDC` → `_receiveNonUsdc`: consume the message, measure THAT token's delta (donation-proof), escrow
  it to the attested `messageSender` under that token key, emit `TransferFailed` +
  `NonUsdcMintEscrowed`, no hookData decode, no execution. Claimable via the existing
  `claimFailedTransfer(token, amount)` (the mapping was already `account => token => amount`).
- `== USDC` → unchanged path. `NOTHING_MINTED` stays as a backstop.
- The minter is read through the messenger at call time (not cached) because Circle can rotate it
  (`addLocalMinter`/`removeLocalMinter`) and this adapter cannot be redeployed.
- Constructor sanity-checks `localMinter() != 0` so a wrong messenger address fails at deploy time.

**Bytecode discipline.** The vendored `ITokenMessengerV2.sol` was NOT touched — its source hash is in the
metadata of the already-deployed `CCTPSendHook`/`ApproveAndCCTPSendHook`. `localMinter()` lives in a
local interface inside the adapter; `getLocalToken` in a new `src/vendor/bridges/cctp/ITokenMinterV2.sol`.
Verified after the change: both hooks' `bytecode.object` still equal their locked artifacts.

**Tests.** Unit (6, mock minter/messenger): escrow-to-burner + claim gating + no execution; donation not
creditable; zero delta reverts; unregistered pair rejected before the transmitter (`calls == 0`); USDC
path resolves through an explicit registry key; minter rotation honored. Fork (1): a real attested
message with `burnToken` rewritten to Ethereum EURC is rejected with `UNSUPPORTED_BURN_TOKEN` against
the REAL Base messenger/minter — proving the lookup runs before attestation. The 7 pigeon E2E tests now
exercise the USDC branch through the real registry. A real non-USDC mint E2E on a mainnet fork is not possible: EURC never reaches TokenMinterV2, and USYC (the live case) is permissioned so the mint itself reverts for a non-allowlisted recipient.


## Round 5 (2026-09-22): security analysis of the Round-4 change

- **Header `recipient` pinned to `TOKEN_MESSENGER`** (`RECIPIENT_OFFSET = 76`, `RECIPIENT_MISMATCH`). Found in-round
  and independently by the researcher as the Allbridge class (Aug 2026, ~$190K): `MessageTransmitterV2.sendMessage`
  is permissionless and `receiveMessage` dispatches to ANY non-zero recipient, so Circle would attest a non-burn
  message with a BurnMessageV2-shaped, attacker-controlled body (incl. `messageSender`) and an attacker handler
  that runs inside our `receiveMessage` call. Delta measurement already made value forgery impossible (only the
  attacker's own donation could be credited), but the pin removes the attacker-callback surface, makes the
  `getLocalToken` lookup run against the same messenger that mints, and — because `TokenMessengerV2` then enforces
  `onlyRemoteTokenMessenger` — is what actually makes `messageSender` unspoofable. `sender@44` binding was also
  suggested; adjudicated redundant (Circle checks it before any mint; a wrong sender reverts with the nonce unspent).
- **Constructor binds the two Circle immutables:** `TOKEN_MESSENGER.localMessageTransmitter() == messageTransmitter_`
  and `localMinter() != 0`, else `TOKEN_MESSENGER_NOT_VALID` (scanner P3-1: a wrong-but-populated address on a
  chain where Circle's CREATE2 differs would otherwise deploy an adapter that reverts on every relay, with no admin).
- **`_resolveLocalToken` extracted** (internal view; legible `TOKEN_MESSENGER_NOT_VALID` if Circle removed the
  minter instead of an empty revert on `address(0)`); helpers made `internal` consistently; `TransferFailed` NatSpec
  now documents all four credit sites; `NOTHING_MINTED` / `ADDRESS_NOT_VALID` / `receiveAndExecute` /
  `_receiveNonUsdc` NatSpec completed; stale "@N" parenthetical removed; vendor header aligned; `forge fmt` clean.
- Tests: +2 unit (recipient pin, zero recipient), +2 constructor cases (no minter / other transmitter), +1 minter
  removed, +1 fork ordering test (recipient rewritten on a real attested burn → `RECIPIENT_MISMATCH` before
  attestation). Unit 43 · size-gate 6 · integration 46 · all adapters 134 · deploy-script 5. Bytecode regenerated
  (deployed 9021 B); hook locked bytecode verified unchanged.
- SDK notes surfaced by research (not adapter code): size destination intents against `amount − maxFee` (a fast
  transfer can legally mint as little as 1 unit) or use `TokenMessengerWithFees` (upfront fee, minted == intent);
  always set `destinationCaller = adapter` (a zero value lets anyone mint straight into the adapter, where the USDC
  becomes an unforwardable, unrescuable donation — accepted design gap, no rescue path by choice).

## Round 6 (2026-09-23): deploy-script parity + NatSpec

- `_checkCoreContracts` now encodes the 4-arg constructor for `CCTPAdapter` (it still had the 3-arg encoding
  after Round 4 — the check pass would have reported the adapter missing forever and deployed elsewhere).
  Parity regression: `test/script/DeployV2CoreCCTPAdapterArgs.t.sol`.
- Deploy block additionally requires `getLocalToken(remoteDomain, remoteUSDC) == configuration.usdcs[chainId]`
  for the canonical pair (`CCTP_DOMAIN_ETHEREUM = 0` / `CCTP_DOMAIN_BASE = 6` in Constants.sol) so a wrong
  local-USDC config cannot deploy an adapter that escrows every intent.
- NatSpec: `checkDestinationTargets` mismatch semantics; `ExecutionFailed` executor event names.

## Real-executor E2E (2026-09-23)
`test/integration/cctp/CCTPAdapterRealExecutorE2E.t.sol` — the CCTP counterpart of `RelayAdapterV2RealExecutorE2E`:
real burn/attestation through the real executor + validator (6 tests; see the security report addendum).
Gotcha: `setUp` ends on the Ethereum fork; anything that reads a Base-side contract (e.g. `validator.namespace()`
while signing) must `vm.selectFork(baseFork)` first.

## Round 7 (2026-09-23): PR #1015 review — F1/F2/I1/I2 in code, T1 tests, runbook

- `destinationCaller = 0` is accepted (F1) and a burn pinned to the adapter but minting elsewhere is passed
  through (F2); both emit `MisconfiguredMessageRelayed(kind)` — alert on it, it means the SDK produced a message
  it never should have. `ExecutionFailed` now carries the bounded 4-byte revert selector (I2).
- **Runbook — execution failed / gas-starved relay:** the USDC is already at the account and the root is unused.
  Re-drive directly: `SuperDestinationExecutor.processBridgedExecution(USDC, account, dstTokens, intentAmounts,
  "", executorCalldata, sigData)` with the payload decoded from the attested message (public). Permissionless;
  valid until the signature's `validUntil`. Pinned by `test_Real_ExecutorRevert_ReDriveDirectlyOnExecutor`.
- **Runbook — SDK sizing:** fast transfers mint `amount − feeExecuted`; size `intentAmounts` against
  `amount − maxFee` or the intent silently no-ops (`test_Real_FastTransferFee_*`).
- **Runbook — HyperEVM:** a relay needs 2M gas + `receiveMessage` overhead — above the small-block limit; relayers
  must use big blocks. Arc (5042) is not in the CCTP config block yet: verify Circle's Arc addresses against the
  deploy `require`s before enabling.
