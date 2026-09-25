# Interview Notes — Circle Gateway destination adapter

Date: 2026-09-23 · Interviewee: Cosmin (v2-core) · Mode: `--security`

## Context established before the interview (verified in-repo / on-chain)
- `src/hooks/bridges/circle/` has four deployed hooks (Wallet deposit, Minter, Add/RemoveDelegate; prod Base
  `0x4eFf…`, `0x74D7…`, `0xEB0E…`, `0xf4C1…`). No destination adapter. The CCTP spec
  (`specs/cctp-destination-adapter/interview-notes.md:45`) explicitly deferred "Circle Gateway destination path"
  as a separate milestone — this is it.
- Today's destination model: `CircleGatewayMinterHook` calls `GatewayMinter.gatewayMint` FROM THE ACCOUNT
  (`destinationCaller == account`), i.e. the user needs a destination userOp; no relayer path, no first-time
  account creation, no `SuperDestinationExecutor`/DstProof flow; `TransferSpec.hookData` unused.
- Gateway contracts are universal proxies: `GatewayWallet 0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE`,
  `GatewayMinter 0x2222222d7164433c4C09B0b0D809a9b52C04C205`; domains = CCTP domains (Base 6, Ethereum 0);
  unpaused; `owner()` per chain can `addAttestationSigner` (fork tests can rotate the signer).
- `gatewayMint(payload, sig)` (lib/evm-gateway-contracts `modules/minter/Mints.sol`): verifies Circle's
  signature; per attestation: `maxBlockHeight` expiry; per TransferSpec: value > 0, recipient not denylisted,
  `destinationCaller == 0 || == msg.sender`, domain, `destinationContract == minter`, token supported;
  `_mint`: marks the TransferSpec hash used (one-shot), mints EXACTLY `value` to `destinationRecipient`,
  `hookData` ignored. Fees are charged at burn on the wallet side; no destination fee.
- Wire format: `Attestation` = magic(4) | maxBlockHeight(32) | specLen(4) | TransferSpec; `AttestationSet` =
  magic | n | attestations. TransferSpec offsets: magic 0, version 4, sourceDomain 8, destinationDomain 12,
  sourceContract 16, destinationContract 48, sourceToken 80, destinationToken 112, sourceDepositor 144,
  destinationRecipient 176, sourceSigner 208, destinationCaller 240, value 272, salt 304,
  hookDataLength 336, hookData 340. Lib helpers: `AttestationLib`, `TransferSpecLib` (bytes29 views).
- `test/integration/circle/CrosschainTestsGateway.t.sol` (727 lines) is SKIPPED (Sepolia RPC dead) but has
  TransferSpec/attestation signing helpers (`SignatureTestUtils` / `MultichainTestUtils` from the lib).

## Decisions

### Round 1 — architecture
| Question | Decision |
|---|---|
| Entry model | **Pull-driven, mirror CCTPAdapter.** Permissionless `receiveAndExecute(attestationPayload, signature)`: adapter calls `gatewayMint` itself, measures the USDC delta, decodes the Superform 6-tuple `(initData, executorCalldata, account, dstTokens, intentAmounts, sigData)` from `TransferSpec.hookData`, forwards to the account, best-effort executes via `SuperDestinationExecutor`. SDK sets `destinationRecipient = destinationCaller = adapter` in the burn intent the user signs. The existing minter hook remains as the account-driven alternative (not removed). |
| AttestationSet | **Single attestation only.** `ATTESTATION_SET_MAGIC` rejected before any external call. One spec = one intent = one hookData. Multi-source unification is minted separately. |
| Escrow beneficiary (undecodable hookData / account 0 / account == adapter) | **`sourceDepositor`** — the wallet debited on the source chain; attested; for a Superform-originated burn it is the user's smart account (same CREATE2 same-address assumption as CCTP's `messageSender`). NOT `sourceSigner` (may be a delegate). |

### Round 2 — failure semantics
| Question | Decision |
|---|---|
| Content-dependent failures vs `maxBlockHeight` expiry | **Never revert on content; escrow.** Same rule as CCTP: only pre-mint fail-fast checks revert (magic, version, set, recipient/caller, domain/contract, token) and those leave the hash unused. After `gatewayMint`, undecodable hookData / bad account → escrow to `sourceDepositor`; DstProof for another deployment → deliver, skip execution; executor revert → `ExecutionFailed(account, selector)`. Research to confirm whether Circle re-attests an unfulfilled burn after expiry. |
| destinationCaller / recipient | **Apply CCTP PR #1015 F1/F2 from day one:** `destinationCaller == adapter OR 0` accepted (0 cannot be prevented; rejecting it only removes the honest-relayer path), any other caller rejected; a spec pinned to the adapter but minting to another recipient is PASSED THROUGH to `gatewayMint` (never stranded); both emit `MisconfiguredMessageRelayed(kind)`. |
| Token scope | **USDC only; supported non-USDC escrowed to `sourceDepositor`** (mirror `CCTPAdapter._receiveNonUsdc`): mint, measure that token's delta, escrow, no execution. Never reject a pinned spec on token. |

### Round 3 — construction, gas, tests
| Question | Decision |
|---|---|
| Constructor | **`(gatewayMinter, usdc, superDestinationExecutor)`**; cache `SUPER_DESTINATION_VALIDATOR`; construction sanity: minter has code, `minter.domain()` set, `isTokenSupported(usdc)`. Per-chain USDC → per-chain CREATE2 address (accepted, as for CCTP). |
| Gas floor | **Same 2M `MIN_EXECUTION_GAS` floor** (revert = retriable within the expiry window; post-floor starvation recoverable by direct `processBridgedExecution`). |
| Tests | **Mainnet-fork E2E with a test attestation signer** (prank `owner()` → `addAttestationSigner`), **real-executor E2E** (execute + root consumed, DstProof mismatch, tampered intent, initData account creation, direct re-drive), **unit suite with mocks**. Circle-attested testnet run NOT required for merge (noted as outstanding, as for CCTP). |

### Round 4 — security scope, Circle controls, deployment
| Question | Decision |
|---|---|
| SuperVault / delegate exposure (G1 class) | **Out of scope; document the guardrail.** User accounts only. Never allow-list Gateway hooks with the adapter as recipient for SuperVault managers; a Gateway delegate can already sign burn intents to any recipient under Gateway's own model; a `SuperVaultGatewayCapBridgeHook` is a separate periphery milestone. |
| Circle pause / denylist | **Accept, document.** If the adapter is denylisted or the minter paused, pinned specs are stuck until Circle acts; no admin path (ownerless, immutable, like every adapter). SDK runbook: check `isDenylisted(adapter)` before pinning. |
| Deployment | **Generic `run()` wiring + check/deploy constructor-arg parity test** (like `DeployV2CoreCCTPAdapterArgs`). Scoped `runCircleGatewayAdapter` entrypoint and the "usdc configured AND minter has code" gate were NOT selected — availability follows the existing pattern (config-keyed); revisit if a single-contract rollout is needed. |

## Acceptance criteria (draft, refined in technical-spec.md)
- [ ] `receiveAndExecute(attestationPayload, signature)` is permissionless and `nonReentrant`; fail-fast checks before any external call: attestation magic (single, not set), TransferSpec version 1, `destinationContract == GATEWAY_MINTER`, `destinationDomain == minter.domain()`, `destinationCaller ∈ {adapter, 0}`, recipient rule (self → full path; other + pinned → pass-through; other + unpinned → reject).
- [ ] USDC path: delta-measured mint (`post − pre`), cross-checked against `value`; surplus credited never retained; decode isolated behind a self-call; escrow to `sourceDepositor` on undecodable / account 0 / account == adapter; DstProof mismatch → deliver, skip; 2M gas floor; bare catch with bounded 4-byte selector.
- [ ] Non-USDC supported token: measured and escrowed to `sourceDepositor`; no execution.
- [ ] `claimFailedTransfer(token, amount)` per (account, token); `ClaimFailedTransferHook`-compatible selector.
- [ ] Events: `TransferSucceeded/Failed`, `ExecutionFailed(account, selector)`, `HookPayloadUndecodable`, `DestinationTargetMismatch`, `NonUsdcMintEscrowed`, `MisconfiguredMessageRelayed(kind)`, `FailedTransferClaimed`.
- [ ] Deploy: `DeployV2Core` wiring with identical check/deploy args + parity test; locked bytecode.
- [ ] Tests: unit (fail-fast matrix, escrow paths, claim isolation, fuzz), mainnet-fork E2E with test signer, real-executor E2E incl. initData creation and direct re-drive.
- [ ] Security report rounds as for CCTP; SDK checklist (recipient = caller = adapter, USDC, hookData 6-tuple, intent sizing).

## Open questions carried into research
1. Does Circle's Gateway API re-attest a burn whose attestation expired unfulfilled? (drives how bad a stranded-but-hash-unused spec is)
2. Is there a `hookData` size limit in the attestation service / EIP-712 burn intent?
3. Denylist semantics on `gatewayMint` for `msg.sender` vs recipient — any Circle guidance for contract recipients?
4. Any Circle audit findings on GatewayMinter (attestation sets, replay, signer rotation)?
5. Which mainnet chains have Gateway live (domains), and is USDC the only supported token anywhere?

## Post-research decisions (2026-09-23, after research/*.md)

Research established that on Gateway the source-side burn happens only AFTER a successful `gatewayMint` and
an unused attestation expires (~10 min) with the depositor's balance restored (Circle technical guide; ChainSecurity
system overview; `Burns.sol`). That inverts CCTP's "revert = permanent burn" premise and reopened three decisions:

| Question | Revised decision |
|---|---|
| Failure model | **Fail fast PRE-mint; escrow only POST-mint.** Everything content-dependent is calldata and is validated before `gatewayMint`: attestation/spec magics, version, length consistency, `destinationContract`, `destinationDomain`, caller/recipient rule, `destinationToken == USDC`, decodable 6-tuple, `account ∉ {0, adapter}`. A pre-mint revert leaves the hash unused; the attestation expires and the balance is restored; the user re-signs. After the mint only delivery failure (escrow to the ACCOUNT — e.g. USDC blacklist) and execution failure (bare catch + selector) remain. **Dropped:** `sourceDepositor` escrow, `_receiveNonUsdc`, `HookPayloadUndecodable`, `NonUsdcMintEscrowed`. Dependency to confirm with Circle (research Q1): restore-on-expiry. |
| AttestationSet | **Supported with identical routing.** Accept a set iff EVERY spec has `destinationRecipient = destinationCaller = adapter`, the same `destinationToken` (USDC) and byte-identical `hookData`; measure ONE delta for the whole `gatewayMint` call, cross-check against `Σ value`, deliver once, execute once. Any other set is rejected pre-mint (`ATTESTATION_SET_MIXED`). Single attestations are the n = 1 case. |
| Direct-mint recovery | **In Phase 1:** `recoverDirectMint(attestationPayload, signature)` — for a spec with `destinationCaller = 0` that a third party pushed straight through `gatewayMint` (USDC minted into the adapter, nothing forwarded). Adapter verifies Circle's signature itself (`ECDSA.recover(keccak256(payload).toEthSignedMessageHash())` ∈ `isAttestationSigner`), requires `isTransferSpecHashUsed(hash)` on the minter and `!processed[hash]` in the adapter, recipient = adapter, token = USDC, decodable hookData; forwards `min(Σ value, spendable)` where `spendable = balanceOf(this) − Σ escrow`, marks `processed[hash]`, then executes as usual. `receiveAndExecute` also marks `processed[hash]` so a relayed spec can never be "recovered" twice. This is per-spec state, but it is only settable by a successful Circle-signed mint of that very spec — no third party can pre-consume it (the dust-griefing lesson does not apply). Needs its own security round. |

Consequences: `MisconfiguredMessageRelayed(kind = 1)` remains for zero-caller specs relayed through the adapter; the
pass-through (kind = 2) remains for pinned-but-mints-elsewhere specs; the escrow map is keyed by the intent
account only; `sourceDepositor` is no longer read.
