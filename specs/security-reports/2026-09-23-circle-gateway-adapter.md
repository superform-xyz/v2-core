# Security Analysis Report — CircleGatewayAdapter

## Metadata
- **Target:** `src/adapters/CircleGatewayAdapter.sol`, `src/vendor/bridges/circle/IGatewayMinter.sol` (branch `feat/circle-gateway-adapter`)
- **Mode:** review (inline scan + vulnerability scanner + coding-standards + external research agents)
- **Date:** 2026-09-23 (Round 1)
- **Contract Types Detected:** Bridge (permissionless, pull-driven cross-chain destination adapter)
- **Files Analyzed:** 2 (context: `Mints.sol`, `AttestationLib.sol`, `TransferSpecLib.sol`, `CCTPAdapter.sol`, `SuperDestinationExecutor.sol`, technical spec, all three test suites)
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits) at `superform-specs/guidelines/solidity/`
- **Spec:** `specs/circle-gateway-destination-adapter/technical-spec.md`

## Summary
| Severity | Count (raw) | Fixed in this round | Blocks Merge |
|----------|-------------|---------------------|-------------|
| P0 Critical | 0 | – | Yes |
| P1 High | 0 | – | Yes |
| P2 Medium | 3 | 3 | No |
| P3 Low | 8 | 8 (1 accepted as-is, documented) | No |

## Verdict
**PASS** — no P0/P1. All three P2s and every P3 were fixed before this report was finalised; the post-fix suites
are green (unit 55, live-minter fork 11, real-executor fork 9, deploy parity 3; repo-wide unit run 1730/1730).

## Inline critical-pattern scan
| # | Pattern | Status |
|---|---------|--------|
| 1 | Reentrancy | PASS — `receiveAndExecute`, `recoverDirectMint`, `claimFailedTransfer` are `nonReentrant`; all adapter state is final before the executor call |
| 2 | Access control | PASS — permissionless by design; self-call helpers gated by `msg.sender == address(this)`; claim keyed on `msg.sender` |
| 3 | Division before multiplication | PASS — no arithmetic division |
| 4 | Unchecked return values | PASS — `_tryTransfer` reads the raw bool word; `gatewayMint` reverts bubble; mint verified by balance delta + `NOTHING_MINTED` |
| 5 | Missing reentrancy guards | PASS |
| 6 | `abi.encodePacked` collisions | PASS — none |
| 7 | `tx.origin` | PASS — none |
| 8 | Floating pragma | PASS — `pragma solidity 0.8.30` |
| 9 | Returnbomb / EIP-150 | PASS — bare `catch`, `returndatacopy(0,0,4)` guarded by `returndatasize() > 3` |
| 10 | Trusted caller, untrusted params | PASS — the payload is Circle-signed; every content check runs BEFORE the mint; `hookData` is depositor-authored and re-validated by the executor's own signature/merkle checks |

## P0 Findings
None found.

## P1 Findings
None found.

## P2 Findings (all fixed)

### [R1-F1] Duplicate member specs in one payload were double-attributed by `recoverDirectMint`
- **File:** `src/adapters/CircleGatewayAdapter.sol` (`recoverDirectMint` verification loop vs `_deliverAndExecute` marking)
- **SWC:** N/A · **Category:** Logic / duplicate entry (vulnerabilities.md §25.3, §33.4)
- **Description:** `_parse` did not dedupe `specHashes`; `recoverDirectMint` checked `isTransferSpecHashUsed && !processed` for every member and only marked `processed` afterwards. A set `{S, S}` passed both checks and forwarded `2 × value(S)` from `spendable`, i.e. from OTHER users' un-recovered stray mints. The minter is immune to the same bytes (it marks as it iterates); this was the one input on which the adapter was weaker than the minter. Reproduced by the scanner against the unit mock.
- **Exploit Scenario:** Attacker stray-mints their own zero-caller spec S; a victim's stray spec T is also sitting in the adapter; attacker obtains a set `{S, S}` (requires Circle to sign a duplicate — off-chain policy unverified, Q1) and recovers 2×; T's recovery then reverts `INSUFFICIENT_RECOVERABLE`.
- **Fix:** `_parse` rejects any repeated spec hash with the new `ATTESTATION_SET_DUPLICATE` (O(n²) over a tiny n), so BOTH entrypoints refuse duplicates before any effect. Test: `test_Set_DuplicateMember_Rejected` (relay rejected pre-mint with zero minter calls; recovery rejected; the single-spec recovery attributes exactly once and leaves the other stray funds untouched).

### [R1-F2] Signer check in `recoverDirectMint` was redundant and stranded funds on Circle signer rotation
- **File:** `src/adapters/CircleGatewayAdapter.sol` (`recoverDirectMint`)
- **SWC:** N/A · **Category:** Logic / unnecessary trust dependency
- **Description:** `isTransferSpecHashUsed(keccak256(spec))` on the minter is written only inside `gatewayMint`, after Circle's signature was verified, and the hash binds recipient, token, value, salt and `hookData` (hence the `account`). A forged payload has a different hash and fails `SPEC_NOT_MINTED`; a used-and-unprocessed hash is therefore a strictly stronger witness than re-recovering the EIP-191 signer. The extra check added no security but introduced a permanent-loss failure mode: once Circle rotates its attestation signer (`removeAttestationSigner`, owner-only, no delay), stray funds could never be recovered from an immutable, ownerless contract.
- **Fix:** `recoverDirectMint(bytes calldata attestationPayload)` — the signature parameter, `ECDSA`/`MessageHashUtils` imports, `INVALID_ATTESTATION_SIGNER` and `IGatewayMinter.isAttestationSigner` were removed. Recovery is now driveable by anyone from a payload reconstructed out of the public direct-mint calldata (any `maxBlockHeight`). Tests: `test_Recover_AnyCallerWithReconstructedPayload`, `test_Recover_Revert_ForgedAccount_NotMinted`, fork `test_Fork_ZeroCallerStrayMint_Recovered` (forged spec with the same salt → `SPEC_NOT_MINTED` on the real minter; reconstructed wrapper from a random caller succeeds). **Deviation from the technical spec's §6.3** (which asked for the signer check) — accepted on the strength of the analysis above; the residual is now only "a minter upgrade changes `isTransferSpecHashUsed` semantics", which was already accepted.

### [R1-F3] `SpecProcessed.value` did not carry the member's value
- **File:** `src/adapters/CircleGatewayAdapter.sol` (`_deliverAndExecute`)
- **Category:** Event semantics / indexing
- **Description:** The event was documented as the spec's value but emitted the delivered total on member 0 and 0 on every other member, so indexers joining on the minter's `AttestationUsed.transferSpecHash` saw mismatches for every set.
- **Fix:** `Parsed.values[]` is filled in `_parse` (the value was already read there) and emitted per member; NatSpec states that the delivered total is carried by `TransferSucceeded` / `TransferFailed` and can be lower on an anomalous under-mint. The `processed` write and the emit now share one loop.

## P3 Findings (all addressed)
| # | Finding | Resolution |
|---|---------|------------|
| R1-P3-1 | `recoverDirectMint` docs said "zero-caller only" while the code (correctly) accepts any non-adapter caller | NatSpec rewritten; `Parsed.destinationCaller` doc updated; new test `test_Recover_ThirdPartyPinnedCaller_Recovered` makes the behaviour intentional |
| R1-P3-2 | `DESTINATION_RECIPIENT_MISMATCH` doc covered only one of two throw sites | Doc lists both |
| R1-P3-3 | `_viewToBytes` rationale ("clone is view") was not the real constraint | Doc now states the mcopy gas / aligned-FMP reasons and the verified TypedMemView FMP behaviour |
| R1-P3-4 | Internal helpers thinner on `@param`/`@return` than the CCTPAdapter baseline | Tags added on `_deliverAndExecute`, `_decodeOrRevert`, `_tryTransfer`, `_isTrueWord`, `_viewToBytes` |
| R1-P3-5 | `IGatewayMinter` declared unused members (`isDenylisted`, `paused`, `isAttestationSigner`) and `bytes memory` params | Trimmed to `gatewayMint` (calldata), `domain`, `isTokenSupported`, `isTransferSpecHashUsed`, with `@param`/`@return` |
| R1-P3-6 | Two passes over `specHashes`; double memory read in the recovery loop | Merged loop; hoisted `bytes32 h` |
| R1-P3-7 | Single-letter `Parsed memory a` | Renamed `parsed` |
| R1-P3-8 | Lattice #216 class (plain relay consumes hooked message) | Already mitigated by `recoverDirectMint` + 2M floor + `MisconfiguredMessageRelayed(1)`; SDK rule: always pin `destinationCaller = adapter` |

## Considered and excluded (trust-model / already-mitigated)
- **Set homogeneity** — caller/recipient/token truncated exactly as the minter (`_bytes32ToAddress`) plus `keccak(hookData)`; members differing in depositor/value/salt/source domain only add value to the same signed intent; sets are Circle-signed as a whole.
- **Clamp / surplus** — balances measured strictly around `gatewayMint` (no callback in FiatToken `mint`); under-mint forwards the true delta; over-mint credits the account; zero delta unwinds the mint.
- **`spendable = balance − totalEscrowed`** — cannot underflow: every escrow credit is backed by USDC that stayed in the adapter, every claim decrements both; donations are never forwardable (need a used-but-unprocessed hash).
- **`processed` before transfer/execution** — the only post-mint revert is `INSUFFICIENT_GAS`, which unwinds the whole tx (mint included); `_tryTransfer` cannot revert. Gas-starving the escrow path on the `!targetsMatch` early return is infeasible under EIP-150 (the 1/64 remainder cannot pay two fresh SSTOREs).
- **Reentrancy** — three `nonReentrant` entrypoints; hooks re-entering revert into the executor's own revert (tested); `view` self-call helpers hold no state.
- **USDC blacklist / pause of the adapter itself** — freezes escrow claims; documented residual (same as CCTPAdapter). Shared-recipient compliance blast radius is a Circle-policy question (added to open questions; monitor `Denylisted(adapter)` / `Blacklisted(adapter)` as P1 alerts).
- **Single attestation signer (Kelp DAO class)** — inherited from Circle; the delta clamp prevents amplification; recommend off-chain mint≈burn invariant monitoring.
- **EIP-191 without domain separator** — chain binding via `destinationDomain`, checked by the minter and by `_parse`; the adapter no longer recovers signatures at all.
- **Arbitrum `maxBlockHeight` = L1 height** — the adapter does no expiry math; only test/monitoring guidance.
- **Destination reorg after mint** — mint/transfer/execution are atomic; indexer guidance only.
- **Memory-expansion on large payloads** (ChainSecurity §8.4) — payer is the payload author; the 2M floor is measured after the copies; relayers size gas to hookData.
- **`mcopy`** — `evm_version = "prague"`; `_viewToBytes` word-aligns the free-memory pointer; the library paths used never touch it.

## Attack Surface Summary
- **External entry points:** `receiveAndExecute(bytes,bytes)`, `recoverDirectMint(bytes)`, `claimFailedTransfer(address,uint256)` (all permissionless / self-keyed); `decodeHookPayload`, `checkDestinationTargets` (self-call only).
- **Value transfer points:** `GATEWAY_MINTER.gatewayMint` (mints USDC to the adapter), `_tryTransfer` to the account, `claimFailedTransfer` to `msg.sender`.
- **Oracle dependencies:** none.
- **Cross-contract interactions:** GatewayMinter (UUPS proxy, Circle-owned: `gatewayMint`, `domain`, `isTokenSupported`, `isTransferSpecHashUsed`), USDC (FiatToken), SuperDestinationExecutor (`processBridgedExecution`, bare try/catch).
- **Upgrade mechanisms:** none in the adapter (immutable, ownerless); the minter is owner-upgradeable (accepted residual).

## Coding Standards Findings
`forge fmt --check` clean, `forge lint` clean. Findings R1-F3 and R1-P3-1..7 above came from the coding-standards agent and are resolved. Constants are `private` while their values leak through events/return codes — consistent with the merged CCTPAdapter, left as-is.

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 8, 10, 13, 15, 16, 20, 25.3, 29.3, 33, 36, 46.4, App. H; plus §50/§51 (permissionless relay / returnbomb)
- **External:** Circle Gateway technical guide + contract interfaces + supported blockchains; ChainSecurity Circle Gateway audit (2025-07-08) §6–8; OWASP SC Top 10 (2025) — SC01/03/04/05/06/08/10 mapped; exploit corpus: Kelp DAO (Apr 2026), Across Solana relayer (Jul 2026), Hyperbridge (Apr 2026), CrossCurve (Jan 2026), Allbridge (Aug 2026), Lattice #216. evmresearch.io: index only, section pages 404 (not usable).
- **Coding rules validated:** NatSpec, events, custom errors, naming, imports, assembly documentation, gas (Section 13).

## Open questions for Circle (carried + sharpened)
Q1 re-attestation after expiry / duplicate-intent signing policy; Q2 hookData cap; Q3 AttestationSet issuance; Q4 denylist policy for contract recipients and where `sourceDepositor` screening happens; Q5 upgrade/pause/signer-rotation notice.

---

# Round 2 — post-fix re-analysis (2026-09-23)

## Metadata
- **Target:** same two files after the Round 1 fixes (`recoverDirectMint(bytes)` signature-free, `ATTESTATION_SET_DUPLICATE`, `Parsed.values[]`)
- **Mode:** review (inline scan + vulnerability scanner + coding-standards + targeted external research)

## Summary
| Severity | Count (raw) | Fixed in this round | Blocks Merge |
|----------|-------------|---------------------|-------------|
| P0 Critical | 0 | – | Yes |
| P1 High | 0 | – | Yes |
| P2 Medium | 1 (documentation) | 1 | No |
| P3 Low | 11 (incl. 6 test-quality) | 9 fixed, 2 accepted as-is | No |

## Verdict
**PASS** — no P0/P1/P2 code findings. All three Round 1 fixes were independently verified as correct (the scanner
reproduced every attack composition against the signature-free recovery; the researcher confirmed the witness on
the vendored code, upstream `master`, and the live minter implementation bytecode). Post-fix suites: unit 57,
live-minter fork 13, real-executor fork 9, deploy parity 3.

## Round 1 fixes verified
| Fix | Verdict |
|---|---|
| R1-F1 duplicate rejection | Correct — `_parse` compares each hash against every earlier member; both entrypoints go through it before any external call. The real minter reverts `TransferSpecHashUsed` on the second identical member itself (fork test `test_Fork_DuplicateSet_RejectedByAdapterAndMinter`), so the adapter's rejection can never block a mintable payload. |
| R1-F2 signature-free recovery | Correct — `TransferSpecHashes` is written only by `Mints._mint` inside `gatewayMint`, after the signature check; no initializer/admin/migration path writes it (vendored `569d7ce`, upstream `master` byte-identical for `Mints`/`TransferSpecHashes`/libs, live impl `0xc2ff…51b1` bytecode == vendored artifact modulo the UUPS `__self` immutable). The hashed preimage is the exact canonical spec slice (magic, version, both domains/contracts/tokens, depositor, recipient, signer, caller, value, salt, hookData); no encoding ambiguity. Attack compositions reproduced and rejected: mixed recipient set, F2 pass-through spec, relayed spec re-wrapped, dirty-high-byte twin, hook stray-minting mid-relay, escrow siphon. |
| R1-F3 per-member value | Correct — `values[i]` and `specHashes[i]` share the index; emitted in the single marking loop. |

## P2 (documentation — fixed)
### [R2-F1] `HOOK_PAYLOAD_INVALID` / `UNSUPPORTED_DESTINATION_TOKEN` NatSpec claimed "no funds at risk" at the recovery throw site, and the stranded-stray-mint residual was undocumented
- Raised by both the scanner (R2-P3-1) and the coding-standards agent (as P2). A spec NOT pinned to this adapter can be minted directly into it by anyone; if its hookData is unusable (undecodable, account 0 / this) or its token is not USDC, `recoverDirectMint` reverts forever and the value stays in the ownerless contract. Self-inflicted by construction: the SDK pins `destinationCaller = adapter` (making the direct-mint path unreachable) and only the depositor authors hookData.
- **Decision:** documented as an accepted residual (contract-level NatSpec + both error docs) rather than adding an escrow-to-`sourceDepositor` fallback, which would widen the trust surface for a self-harm-only case. Revisit if Circle ever issues attestations with third-party-authored hookData.

## P3 (fixed)
| # | Finding | Resolution |
|---|---------|------------|
| R2-P3-1 | Contract header still said "zero-caller" for the widened recovery class | Fixed |
| R2-P3-2 | Header used `signature` for both the user's SignatureData and Circle's attestation signature | 6-tuple now reads `sigData` |
| R2-P3-3 | `_viewToBytes` doc: "never touch the FMP" imprecise (`cursor` allocates a struct through solc) | Reworded: library paths only allocate through solc and otherwise read |
| R2-P3-4 | `DestinationTargetMismatch` lacked `@param` tags | Added (codes 1/2) |
| R2-P3-5 | Empty AttestationSet rejected only incidentally (`DESTINATION_RECIPIENT_MISMATCH` on a zeroed parse) | New `ATTESTATION_SET_EMPTY` in `_parse`; unit test on both entrypoints |
| R2-P3-6 | Cosmetic NatSpec continuation indentation (two lines) | Fixed |
| R2-T1 | Dead test code after the interface trim (`IERC20`/`TypedMemView` imports, `isDenylisted` mapping in the mock) | Removed |
| R2-T2 | Coverage gaps: under-mint event values, recover-set per-member events, non-adjacent duplicate `{S,T,S}`, empty set, mismatch codes 1/2 | Tests added / tightened |
| R2-T3/T4 | Fork assertions looser than their names (duplicate set vs the real minter; `INVALID_PROOF` selector; mismatch code; blacklist execution outcome) | Tightened. Note: the blacklist case surfaces `ExecutionFailed` (the real executor validates account + signature before its balance gate), not a silent no-op — the test doc was corrected accordingly |
| R2-T6 | Gas-floor tests are budget-sensitive | Assumption documented inline |

## P3 (accepted as-is)
- **`GATEWAY_MINTER.domain()` read live per parse instead of an immutable** — ~2.6k gas per relay; kept live to match CCTPAdapter's live `localMinter()` read and avoid assuming Circle never re-initialises the proxy.
- **Inline `msg.sender != address(this)` guards instead of an `onlySelf` modifier; `p` next to `parsed`; `Parsed` type name** — baseline-consistent with CCTPAdapter; not changed.

## Research residuals (informational, no code change)
- **Mint-authority edge:** `Mints._mint` marks the hash and then ignores the bool of `IMintableToken.mint`. Today USDC is minted by FiatToken itself (`tokenMintAuthority(USDC) == 0`, verified live on Base in `test_Fork_WitnessSemantics_UsedHashImpliesMinted`), whose `mint` reverts on failure and unwinds the mark. If Circle ever set a non-reverting mint authority, "used" would no longer imply "USDC arrived" and a recovery could be paid from another stray mint (bounded by `spendable`). Monitor `MintAuthorityChanged` / `Upgraded` on the minter.
- **TransferSpec v2:** a minter upgrade accepting a new spec version would make the adapter revert pre-mint (safe for relays; a v2 spec direct-minted into the adapter would be unrecoverable). Same class as the accepted upgrade residual.
- **Precedent scan (Nomad default-value aliasing, LayerZero V1 nonce-before-execute, Across `FillStatus` intermediate state, Wormhole signer bypass):** none transfer — the witness requires an explicit `true`, is written in the same frame as the mint with no try/catch, is a bool with no intermediate state, and is only as strong as Circle's own signer check (whose failure costs Circle, not the adapter's users).

## Attack Surface Summary (unchanged from Round 1 except)
- `recoverDirectMint(bytes)` — no signature input; authorization is the minter's used-hash record.
- New pre-mint revert: `ATTESTATION_SET_EMPTY`.

## Security Knowledge Sources (Round 2 additions)
- Vendored `TransferSpecHashes.sol`, `Mints.sol`, `GatewayMinter.sol`, `GatewayCommon.sol` initializers; upstream `circlefin/evm-gateway-contracts` master + `CHANGELOG.md` (1.1.0–1.3.0 are wallet-side only); live implementation bytecode comparison on Ethereum/Base/Arbitrum; Circle Gateway technical guide and `/v1/transfer` API reference; Nomad Replica post-fix source; LayerZero V1 `Endpoint.sol`; Across `V3SpokePoolInterface.sol`; OWASP SC Top 10 (2025) SC06/SC10.

---

# Round 3 — deployment wiring, tests, artifacts, submodule (2026-09-24)

## Metadata
- **Target:** the delta since Round 2 — `script/DeployV2Core.s.sol`, `script/utils/{ConfigCore,ConfigBase,Constants}.sol`, `script/run/tooling/regenerate_bytecode.sh`, the three `CircleGatewayAdapter.json` artifacts, all six test files (incl. the new `CircleGatewayAdapterPigeonE2E.t.sol`), and the `lib/pigeon` bump. The adapter's deployed bytecode is byte-identical to Round 2 (`out/` == both locked dirs == generated).
- **Mode:** review (inline + deployment-wiring scanner + test-quality scanner)

## Summary
| Severity | Count (raw) | Fixed | Blocks Merge |
|----------|-------------|-------|-------------|
| P0 / P1 | 0 | – | Yes |
| P2 | 4 (2 deploy-test, 2 test-quality) | 4 | No |
| P3 | ~14 | 8 fixed, rest accepted below | No |

## Verdict
**PASS.** Post-fix: unit 59, live-minter fork 16, real-executor fork 10, pigeon E2E 8, deploy-script suites 10/10. `forge fmt --check` clean.

## Inline
- Adapter unchanged since Round 2 (bytecode equality across `out/`, `locked-bytecode`, `locked-bytecode-dev`, `generated-bytecode`).
- `lib/pigeon` bump `acfe28c → 2196ff7` is purely additive: `src/circle-gateway/*`, `test/CircleGateway.t.sol`, README rows; no other helper touched. The helper was reviewed separately (`pigeon/specs/security-reports/2026-09-24-circle-gateway-helper.md`). The commit is on `origin/feat/circle-helper`, not yet on pigeon `main`.

## Deployment wiring
Every CCTPAdapter wiring touchpoint has a Gateway counterpart (import, struct fields, adapter list `[7]→[8]`, `potentialSkips` 48→49, availability gate, check pass, config validation, status population, deploy block with liveness + `isTokenSupported(usdc)` + post-deploy immutables incl. `SUPER_DESTINATION_VALIDATOR != 0`, exported key, salt, regenerate list). Config table: minter on the 9 verified chains, `address(0)` elsewhere; every enabled chain has a `usdcs` entry; Linea is the only USDC+CCTP chain without a minter (pinned by the gate test). Artifacts: three JSONs byte-identical, compiler `0.8.30`, optimizer 200, `prague`, no via-IR, `bytecodeHash=none` — identical settings to `CCTPAdapter.json`; no link references; 4 immutable references (constructor-set). Scoped entrypoint intentionally absent (interview decision): the generic `run()` deploys it and no scoped entrypoint touches it.

### [R3-F1] (P2, fixed) Parity test pinned the check pass to the test's own encoding, not the deploy block's
An arg-order swap in the deploy block would have stayed green. **Fix:** one shared encoder `_circleGatewayCtorArgs(chainId, executor)` is now used by BOTH the check pass and the deploy pass, and the test pins that encoder to the ABI order `(gatewayMinter, usdc, executor)` and to the recorded check-pass CREATE2 address.

### [R3-F2] (P2, fixed) "prod artifact present" test was vacuous
A CREATE2 address is never zero, so `deployAddress(...) != 0` passed even for a missing artifact (probe: a nonexistent contract name still yielded an address). **Fix:** the harness exposes `__checkBytecodeExists`; the test asserts existence for env 0/1/2, that the check is falsifiable, and that locked and locked-dev creation code are identical.

## Tests
### [R3-F3] (P2, fixed) Real-validator suite never exercised a forged signer
The tampered-intent test fails at the merkle proof, before signature recovery, so a validator accepting any ECDSA signer would have passed. **Fix:** `test_Real_ForgedSigner_DeliversButRejected_RootPreserved` — valid proof, root signed by a stranger → real validator recovers the wrong signer → executor `INVALID_SIGNATURE` caught → funds delivered, nothing executed, root preserved.

### [R3-F4] (P2, fixed) Returnbomb test was unfalsifiable
A 100 KB bomb under the ~1B test gas limit passes even with a `catch (bytes memory)` regression, and the test never asserted `ExecutionFailed`. **Fix:** 800 KB bomb with a 3.0M gas cap (executor can produce it, adapter cannot copy it) and the `Error(string)` selector asserted, proving the bomb reached the adapter.

### P3 fixed
- `FailedTransferClaimed` asserted; claim isolation (a stranger cannot claim the account's escrow).
- Domain-0 constructor test now relays through the domain-0 adapter (the constructor never reads `domain()`; `_parse` does).
- Blacklist real-executor test asserts the exact caught selector (`ACCOUNT_NOT_CREATED`: the executor validates the account before its balance gate) and its NatSpec was corrected.
- Reentrancy into `recoverDirectMint` from a hook (same guard) covered.
- Two stray mints for two accounts recovered in either order; adapter ends empty.
- Fork: F2 pass-through (kind 2) on the real minter; mixed set rejected pre-mint with every member unused; FiatToken blacklist of the ADAPTER (distinct from the Gateway denylist) unwinds the mint inside `gatewayMint` and the same attestation relays after unblacklisting.

### P3 accepted as-is
- Absolute balance assertions on `makeAddr` accounts on live forks, unpinned forks, duplicated mocks/helpers across the three fork suites, the `_hook` dstToken hardcode in the Ethereum fork test, the OOG-style test's nonsense gas figure — all consistent with the sibling CCTP suites; no bug can hide behind them.
- Not added: parser-differential fuzz, `(Σvalue, minted)` fuzz beyond the fixed under/over-mint points, an invariant handler for `balance >= totalEscrowed`; the unreachable-on-real-minter paths (`NOTHING_MINTED`, surplus, `INSUFFICIENT_RECOVERABLE`) stay unit-only by construction.

## Coverage after Round 3
Every custom error and every event of the adapter is exercised by at least one test; `MisconfiguredMessageRelayed` kinds 1 and 2 and `DestinationTargetMismatch` code 1 are covered on the real minter, code 2 in unit. Mock-vs-real divergences (signature ignored, expiry ignored, token support not enforced, pause/denylist modelled as flags) are each closed by a live-minter fork test or are unreachable through the adapter's pre-mint checks.
