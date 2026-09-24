# Circle Gateway Destination Adapter — Technical Specification

Status: Draft for pod-leader review · Date: 2026-09-23 · Mode: `--security` · Template: `CCTPAdapter` (PR #1015)

## 1. Overview

`src/adapters/CircleGatewayAdapter.sol` is a permissionless, ownerless, immutable destination-side adapter for
**Circle Gateway** (the unified-USDC-balance product; NOT CCTP). A relayer calls
`receiveAndExecute(attestationPayload, signature)`; the adapter calls `GatewayMinter.gatewayMint` itself, measures
the USDC minted into it, decodes the Superform 6-tuple from `TransferSpec.hookData`, forwards the USDC to the intent
account (escrow on delivery failure) and best-effort executes the signed intent through `SuperDestinationExecutor`.
It closes the gap left when the CCTP spec deferred "Circle Gateway destination path" as a separate milestone.

Key structural difference from CCTP, established by research and load-bearing for the whole design: **on Gateway the
source-side burn happens only after a successful `gatewayMint`; an attestation that expires unused (~10 minutes,
`maxBlockHeight`) restores the depositor's balance.** A revert BEFORE the mint costs the user a retry, not funds.
Therefore the adapter fails fast on every content problem before minting and only handles delivery/execution
failures after it. (Confirmation of restore-on-expiry with Circle is research Q1; the contracts and Circle's technical
guide both say so.)

## 2. Problem statement

Four Gateway hooks are deployed (`CircleGatewayWalletHook` deposit, `CircleGatewayMinterHook`, add/remove delegate).
The only destination path today is `CircleGatewayMinterHook`, which the **account itself** must execute
(`destinationCaller == account`): the user needs a destination userOp, there is no relayer path, no first-time
account creation, no `SuperDestinationExecutor`/DstProof flow, and `TransferSpec.hookData` is unused. Every other
bridge in v2-core has a destination adapter; Gateway does not.

## 3. Proposed solution

Mirror `CCTPAdapter`'s pull model with Gateway's primitives:

```
SDK builds BurnIntent/TransferSpec:  destinationRecipient = destinationCaller = adapter
                                     destinationToken = USDC, hookData = 6-tuple
user (or delegate) signs it; Circle API returns Attestation (or AttestationSet) + signature
relayer → CircleGatewayAdapter.receiveAndExecute(payload, signature)
   1. fail-fast on calldata (no external call): magic/version/lengths, minter/domain, caller/recipient rule,
      token == USDC, hookData decodes, account ∉ {0, adapter}, value != 0, set routing identical
   2. pre = USDC.balanceOf(this); GATEWAY_MINTER.gatewayMint(payload, signature); minted = post − pre
   3. clamp to Σ value (surplus credited to account), NOTHING_MINTED backstop, mark processed[specHash]
   4. DstProof targets this deployment? else deliver-only
   5. _tryTransfer(account, minted) → TransferSucceeded | escrow failedTransfers[account][USDC]
   6. gas floor 2M → try processBridgedExecution catch → ExecutionFailed(account, selector)
recoverDirectMint(payload, signature): a zero-caller spec someone pushed straight through gatewayMint
   verify Circle signer, minter says hash used, adapter says not processed, recipient == adapter, token USDC,
   decodable hookData → forward Σ value from spendable, mark processed, execute as in 4–6
claimFailedTransfer(token, amount): msg.sender's own escrow only
```

The existing `CircleGatewayMinterHook` stays as the account-driven alternative (same as Relay's direct path).

## 4. Design decisions (from interview + research; see interview-notes.md)

| Topic | Decision |
|---|---|
| Entry | Pull-driven `receiveAndExecute(bytes payload, bytes signature)`, permissionless, `nonReentrant`. |
| Failure model | **Fail fast pre-mint; escrow only post-mint.** No `sourceDepositor` escrow, no non-USDC escrow, no `HookPayloadUndecodable`. |
| Sets | `AttestationSet` accepted iff every member has recipient = caller = adapter, `destinationToken == USDC`, byte-identical `hookData`; one delta, one delivery, one execution; otherwise `ATTESTATION_SET_MIXED`. Single attestation = n = 1. Note: a set is atomic on the minter (one expired/used member reverts the whole call); the SDK may instead submit N single intents (N deliveries, executor balance-gates until the last one lands). |
| Caller/recipient (CCTP F1/F2) | `destinationCaller ∈ {adapter, 0}`; other → `DESTINATION_CALLER_MISMATCH`. `destinationRecipient != adapter`: pinned to adapter → pass-through (`gatewayMint`, `MisconfiguredMessageRelayed(2)`), unpinned → `DESTINATION_RECIPIENT_MISMATCH`. Zero caller relayed normally with `MisconfiguredMessageRelayed(1)`. |
| Token | USDC only; `destinationToken != USDC` → `UNSUPPORTED_DESTINATION_TOKEN` pre-mint (attestation expires; balance restored). |
| Recovery | `recoverDirectMint` in Phase 1 (per-spec `processed[hash]` settable only by a Circle-signed mint of that spec). |
| Constructor | `(gatewayMinter, usdc, superDestinationExecutor)`; sanity: `minter.code.length > 0`, `isTokenSupported(usdc)`; **do not require `domain() != 0`** (Ethereum = 0); cache `SUPER_DESTINATION_VALIDATOR`. Per-chain USDC → per-chain address (accepted). |
| Gas | `MIN_EXECUTION_GAS = 2_000_000` floor; bare catch + bounded 4-byte selector. |
| SuperVault / delegates | Out of scope; guardrail documented (§10). |
| Circle controls | Pause/denylist/blacklist/upgrade accepted as residuals (§9). |
| Deployment | Generic `run()` wiring + check/deploy arg-parity test; no scoped entrypoint (add later mirroring `runCCTPAdapter` if a single-contract rollout is needed). |

## 5. Wire format (single `Attestation`; from `lib/evm-gateway-contracts`, verified == live implementation)

Absolute offsets = 40 + `TRANSFER_SPEC_*_OFFSET`: attestation magic 0 (`0xff6fb334`; set = `0x1e12db71`),
maxBlockHeight 4, specLength 36 (u32), spec magic 40 (`0xca85def7`), version 44 (=1), sourceDomain 48,
destinationDomain 52, sourceContract 56, destinationContract 88, sourceToken 120, destinationToken 152,
sourceDepositor 184, destinationRecipient 216, sourceSigner 248, destinationCaller 280, value 312, salt 344,
hookDataLength 376 (u32), hookData 380. Invariants: `payload.length == 40 + specLength`,
`specLength == 340 + hookDataLength`. An `AttestationSet` = magic | n (u32 @4) | attestations @8 (each an
`Attestation` as above, variable length). Minter comparisons truncate `bytes32 → address` (low 20 bytes) — the
adapter compares the same way.

Parsing approach: use the vendored libraries (`AttestationLib.cursor` → structural validation identical to the
minter's, `TransferSpecLib` getters) on a memory copy of the payload — the exact code the minter runs, so anything
that passes here passes there (parser-differential class, CS-EVM-CCTP2-013). `getHookData()` is a `bytes29` view;
`abi.decode` it via a pure `mcopy` clone into `bytes memory` (verified snippet in research/framework-docs.md §7a).
`via_ir` is OFF in the default profile → keep locals few, scope blocks, isolate decodes in self-calls.

## 6. Contract design

### 6.1 Storage, errors, events
- Immutables: `GATEWAY_MINTER` (local `IGatewayMinter` interface: `gatewayMint`, `domain`, `isTokenSupported`,
  `isAttestationSigner`, `isTransferSpecHashUsed`, `isDenylisted`, `paused`), `USDC`, `SUPER_DESTINATION_EXECUTOR`,
  `SUPER_DESTINATION_VALIDATOR` (cached via local `IDestinationValidatorSource`).
- `mapping(address account => mapping(address token => uint256)) failedTransfers` (verbatim CCTP).
- `mapping(bytes32 specHash => bool) processed` — set by both entrypoints after a successful mint attribution.
- Errors: `ADDRESS_NOT_VALID`, `GATEWAY_MINTER_NOT_VALID`, `PAYLOAD_TOO_SHORT`, `ATTESTATION_SET_MIXED`,
  `DESTINATION_CONTRACT_MISMATCH`, `DESTINATION_DOMAIN_MISMATCH`, `DESTINATION_CALLER_MISMATCH`,
  `DESTINATION_RECIPIENT_MISMATCH`, `UNSUPPORTED_DESTINATION_TOKEN`, `ZERO_VALUE`, `HOOK_PAYLOAD_INVALID`
  (undecodable / account 0 / account == adapter), `NOTHING_MINTED`, `INSUFFICIENT_GAS`, `INVALID_SENDER`,
  `ZERO_AMOUNT`, `INSUFFICIENT_FAILED_BALANCE`, `INVALID_ATTESTATION_SIGNER`, `SPEC_NOT_MINTED`,
  `SPEC_ALREADY_PROCESSED`, `INSUFFICIENT_RECOVERABLE`. Structural errors bubble from `TransferSpecLib`.
- Events (CCTP shapes): `TransferSucceeded`, `TransferFailed` (every escrow credit), `ExecutionFailed(account,
  bytes4)`, `DestinationTargetMismatch(account, code)`, `MisconfiguredMessageRelayed(kind, mintRecipient)`,
  `FailedTransferClaimed`; new: `SpecProcessed(bytes32 indexed specHash, address indexed account, uint256 amount,
  bool recovered)` (one per member spec) for indexers.

### 6.2 `receiveAndExecute(bytes calldata payload, bytes calldata signature)` — nonReentrant
1. **Parse + fail fast (no external call except `GATEWAY_MINTER.domain()`):** length ≥ 4; magic ∈ {single, set};
   `cursor()` structural validation; for each member: `destinationContract == GATEWAY_MINTER`,
   `destinationDomain == domain()`, `value != 0`, caller rule, recipient rule, `destinationToken == USDC`; for sets:
   every member identical in caller/recipient/token and `hookData` bytes (compare `keccak256`), else
   `ATTESTATION_SET_MIXED`. Pass-through branch (all members pinned & minting elsewhere, homogeneous):
   `gatewayMint`, emit `MisconfiguredMessageRelayed(2, recipient)`, return.
2. **Decode hookData pre-mint** via `this.decodeHookPayload(hookData)` self-call; `!decoded || account ∈ {0, this}`
   → `HOOK_PAYLOAD_INVALID` (revert; attestation expires; balance restored).
3. **Mint + delta:** `pre`; `gatewayMint(payload, signature)`; `minted = post − pre`; `claimed = Σ value`;
   `if (claimed < minted) { surplus = minted − claimed; minted = claimed; }`; `minted == 0 → NOTHING_MINTED`.
   Mark `processed[specHash_i] = true` for every member (already used on the minter; prevents a later
   `recoverDirectMint` of the same spec).
4. `if (destinationCaller == 0) emit MisconfiguredMessageRelayed(1, self)`.
5. Surplus → `failedTransfers[account][USDC]` + `TransferFailed`. `checkDestinationTargets(sigData)` self-call →
   `targetsMatch` / `DestinationTargetMismatch`.
6. `_tryTransfer(account, minted)` → `TransferSucceeded` | escrow + `TransferFailed`. `emit SpecProcessed(...)`.
7. `if (!targetsMatch) return;` gas floor; `try processBridgedExecution(USDC, account, dstTokens, intentAmounts,
   initData, executorCalldata, sigData) {} catch { selector via returndatacopy; emit ExecutionFailed }`.

### 6.3 `recoverDirectMint(bytes calldata payload, bytes calldata signature)` — nonReentrant, permissionless
For specs with `destinationCaller = 0` that a third party pushed straight through `gatewayMint` (USDC minted into
the adapter, nothing forwarded). Steps: parse + the same routing checks as 6.2 step 1 but requiring
`destinationRecipient == adapter` for every member (pass-through is meaningless here); decode hookData (same rule);
`recovered = ECDSA.recover(keccak256(payload).toEthSignedMessageHash(), signature)` must satisfy
`GATEWAY_MINTER.isAttestationSigner(recovered)` else `INVALID_ATTESTATION_SIGNER`; for every member
`isTransferSpecHashUsed(hash)` else `SPEC_NOT_MINTED`, `!processed[hash]` else `SPEC_ALREADY_PROCESSED`;
`spendable = USDC.balanceOf(this) − Σ_all failedTransfers[*][USDC]` (tracked as `totalEscrowed[USDC]`);
`Σ value > spendable → INSUFFICIENT_RECOVERABLE` (never partial); mark processed; then steps 5–7 with
`minted = Σ value`, `recovered = true` in `SpecProcessed`. No expiry check (the mint already happened). Signer
rotation: if Circle removed the signer after the mint, recovery is blocked until… it is not: use
`isAttestationSigner` at recovery time — document as a residual (Circle can rotate; the stray funds then need the
old signer re-added or a redeploy). Reentrancy: same guard as `receiveAndExecute`.

### 6.4 `claimFailedTransfer(address token, uint256 amount)` — verbatim CCTP; decrements `totalEscrowed[token]`.

### 6.5 Self-calls: `decodeHookPayload(bytes calldata hookData)` and `checkDestinationTargets(bytes calldata sigData)`
— external, `msg.sender == this`, isolate `abi.decode` panics (CCTP verbatim; `decodeHookPayload` takes the hookData
slice instead of the whole message).

### 6.6 Invariants
- No per-intent state is settable by a third party: `processed[hash]` flips only after a Circle-signed mint of that
  exact spec succeeded (either in-tx or verified post-hoc). No dust-griefing slot.
- `USDC.balanceOf(adapter) ≥ totalEscrowed[USDC]` after every call; donations are never forwardable except through
  `recoverDirectMint`, which forwards only Σ value of a verified stray mint.
- Outcome of `receiveAndExecute` is a pure function of (attested bytes, chain state): front-running the relayer only
  performs the relay.
- After a successful `gatewayMint` inside this adapter, the minted USDC is always attributed (account or escrow);
  nothing after the mint reverts on content.

## 7. Attack surface analysis (checklist)

### Token risks
- [x] Fee-on-transfer/rebasing: USDC only; delta measured once around the mint (10.1/10.2)
- [x] Missing return values: `_tryTransfer` raw-word check; `claim` uses SafeERC20 (10.3)
- [x] Pausable/blacklist: USDC blacklist of adapter → mint reverts pre-hash (retriable/expires); of account → escrow; adapter blacklist freezes escrow claims — runbook (10.5, 2024-26 §10.4)
### Reentrancy
- [x] `nonReentrant` on both entrypoints and `claim`; no state writes before `gatewayMint`; `IMintableToken.mint` may be a wrapper authority (Circle-config) — guard + delta + clamp (1.1–1.5); mint-authority reentrancy test required
- [x] Read-only reentrancy: no external consumer of adapter views (1.4)
### Cross-chain / message trust
- [x] Replay: Circle `usedHashes[keccak256(spec)]`; chain via `destinationDomain`; adapter `processed` prevents relay+recover double use (16.1, 33.4)
- [x] False deposit / forged origination: none — every attestation is value-backed by a Circle-verified deposit; no permissionless origination primitive (Allbridge class absent) (33.1)
- [x] Signer trust: single ECDSA attestation signer, rotatable, fully trusted (33.2) — top trust anchor, documented
- [x] Upgradeable dependency: UUPS minter, no timelock; ABI change bricks the adapter → specs expire, balances restore, SDK migrates (11.x)
### Access control
- [x] Ownerless/immutable; permissionless entrypoints; `claim` keyed on `msg.sender`; self-calls guarded (2.1)
### DoS / gas
- [x] 2M floor (revert = hash unused, retriable); post-floor starvation → delayed execution, re-drivable; returnbomb bounded (7.4, 13.1, App. H)
### Precedent
- [x] Allbridge 2026 (absent by construction), Conduit 2026 (measure once), CS-CSpend-001/002/018, Nomad/Wormhole (N/A), Ronin/Multichain (inherited signer trust)

## 8. Failure modes and recovery (runbook)

| Situation | What happens | Recovery |
|---|---|---|
| Any pre-mint rejection (bad routing, non-USDC, undecodable hookData, mixed set, value 0) | Revert; hash unused | Attestation expires (~10 min) → balance restored → SDK re-signs a correct intent. **Monitoring must watch failed txs**, not only events. |
| Minter paused / adapter denylisted / adapter USDC-blacklisted / signer rotated | `gatewayMint` reverts pre-hash | Same expiry path; escrowed balances are NOT self-healing — keep escrow small, alert on `Denylisted/Blacklisted(adapter)`. |
| One member of a set expired/used | Whole `gatewayMint` reverts | Re-request; or SDK uses N single intents (independently retriable). |
| Account USDC-blacklisted | Escrow to account | `unBlacklist` → `claimFailedTransfer` (or `ClaimFailedTransferHook`). |
| Executor reverts (hook bug) | `ExecutionFailed(account, selector)`; funds at account; root unused | Fix hook → direct `processBridgedExecution` (permissionless) until `validUntil`. |
| Executor silent no-op (balance gate / root used / empty calldata) | No adapter event | Watch executor events (`SuperDestinationExecutorReceivedBut*`). |
| Gas starved below floor | Revert (hash unused) | Retry with more gas within the window; a relayer that keeps starving only burns its own time. |
| Wrong `initData` for a first-time account | Executor `INVALID_ACCOUNT`/`ACCOUNT_NOT_CREATED` caught; USDC at the counterfactual address | Create the account correctly (deterministic address) → funds accessible; execution needs a new signed root. Same as CCTP. |
| Zero-caller spec pushed directly through `gatewayMint` | USDC minted into adapter, nothing forwarded | `recoverDirectMint(payload, signature)` by anyone (payload is public: `AttestationUsed` + Circle API). |
| Circle re-attestation policy | Unknown (Q1) | Ask Circle; design is safe either way (funds never burned before mint). |

## 9. Accepted residuals
Circle signer compromise (unbacked mints; adapter never amplifies); minter upgrade without notice; pause/denylist
/blacklist freezing escrow; single-signature attestation (no threshold); delegates can route a depositor's balance
anywhere (Gateway's own model; the adapter cannot escalate it); pre-funded-account early execution (inherited I4);
escrow claimable only by the intent account's address on the destination; hookData backend size cap unpublished
(Q2) — measure the largest realistic 6-tuple.

## 10. SuperVault guardrail (G1 class) and SDK checklist
- Never allow-list Gateway hooks with the adapter as recipient for SuperVault managers; a `SuperVaultGatewayCapBridgeHook`
  binding recipient/caller/account is a separate periphery milestone. Note Gateway delegates can already sign burn
  intents to any recipient.
- SDK: `destinationRecipient = destinationCaller = adapter` (per-chain address lookup!), `destinationToken = USDC`,
  `destinationContract = GATEWAY_MINTER`, `destinationDomain` = chain's Gateway domain, hookData = 6-tuple with
  `intentAmounts ≤ Σ value` (no destination fee), homogeneous sets only, never pin to a denylisted adapter
  (`isDenylisted`), keep hookData minimal (cap unknown), do not target chains without an adapter deployment.

## 11. Deployment
`Constants.CIRCLE_GATEWAY_ADAPTER_KEY = "CircleGatewayAdapter"`; `ConfigCore.gatewayMinters[chainId]` (GATEWAY_MINTER
or 0) as the availability gate together with `usdcs[chainId]`; `DeployV2Core`: `CoreContracts`/`ContractAvailability`
fields, adapter list `[7]→[8]`, `potentialSkips` 48→49, gate, `_checkCoreContracts` `__checkContract(KEY, salt,
abi.encode(GATEWAY_MINTER, usdcs[chainId], superDestExecutor), env)`, deploy block with sanity
(`GATEWAY_MINTER.code.length > 0`, `isTokenSupported(usdcs[chainId])`, log `domain()`), post-deploy verifies of the
three immutables, `_populateCoreContractsFromStatus`; `regenerate_bytecode.sh` list; locked bytecode to both dirs;
`test/script/DeployV2CoreCircleGatewayAdapterArgs.t.sol` parity test (clone of the CCTP one). Chains: the 12 Gateway
mainnet domains ∩ configured USDC.

## 12. Test plan
**Unit (mock minter that parses recipient/value/token and can revert / mint a different token / re-enter):** fail-fast
matrix with "no external call happened"; recipient/caller rule ×4; set homogeneity (mixed hookData/token/recipient/
caller); fuzz `(Σvalue, minted)` clamp + surplus; `NOTHING_MINTED`; decode isolation (garbage hookData/sigData);
escrow on transfer false/non-bool/revert; claim isolation; gas floor; returnbomb; mint-authority reentrancy into both
entrypoints; `recoverDirectMint` (signer check, not-minted, already-processed after relay, shortfall revert, set
members, ordering of two stray mints); invariant `balance ≥ totalEscrowed`; parser-differential fuzz vs lib getters.
**Fork E2E (live minter proxy; prank `owner()` → `addAttestationSigner`; EIP-191 signing):** happy path; replay →
`TransferSpecHashUsed`; expiry via `vm.roll`; zero-caller relay + direct stranger mint → `recoverDirectMint`;
pass-through; set (2 sources, homogeneous) + mixed rejection; denylist/pause/USDC blacklist of adapter and account;
same-domain spec; largest hookData gas measurement.
**Real-executor E2E (real `SuperDestinationExecutor` + `SuperDestinationValidator`, cloned from
`CCTPAdapterRealExecutorE2E`):** execute + root consumed; DstProof mismatch → deliver/skip; tampered `intentAmounts`
→ `INVALID_PROOF` caught, root preserved; first-time account via `initData`; direct re-drive; stranger dust /
pre-funded early execution controls.
**Deploy:** parity test; generic check pass on Base/Ethereum read-only.

## 13. Implementation plan
1. Vendor `src/vendor/bridges/circle/IGatewayMinter.sol` (view + mint surface); adapter with 6.1–6.5; NatSpec at CCTP
   density citing this spec's decisions.
2. Unit suite + mocks; fork E2E helpers (`_spec`, `_signAttestation`, `_enrollSigner` from research §7b);
   real-executor E2E.
3. Deploy wiring + parity test; regenerate + copy locked bytecode; read-only check passes on Base/Ethereum.
4. Security rounds as for CCTP (scanner + standards + researcher), report under `specs/security-reports/`.
5. Open a PR from a branch off `dev` (the adapter depends only on `dev` + the vendored lib).

## 14. References
research/repo-analysis.md (CCTP template map, offsets, gotchas), research/framework-docs.md (lib APIs, verified
parsing + fork-signing snippets), research/best-practices.md (Circle docs, fees, sets, audits, Q1–Q9),
research/evm-security.md (patterns, precedents, tests), research/specflow-analysis.md (flows, gaps);
`src/adapters/CCTPAdapter.sol`; `lib/evm-gateway-contracts/src/{lib/*,modules/minter/Mints.sol}`;
`specs/security-reports/2026-09-21-cctp-destination-adapter.md`.
