# EVM/DeFi security research — `CircleGatewayAdapter`

Source: EVM security research agent, 2026-09-23. Both internal DBs were read (`vulnerabilities.md` 4014 lines; `vulnerability-patterns-2024-2026.md` 2086 lines); Gateway sources at `569d7cef`, ChainSecurity Gateway audit (2025-07-08), Circle docs, SlowMist/shattered Allbridge write-ups. **evmresearch.io was not usable** (section paths 404) — nothing below cites it.

## The structural fact that changes the threat model versus CCTP
Verified in `Burns.sol` NatSpec ("after an equivalent amount was minted on another chain"), the ChainSecurity system overview (step 4: only once an Attestation is consumed do burnSigners sign the BurnIntent) and Circle's technical guide ("Attestation expires unused → the system increments the user's balance, restoring the debited amount"; attestations expire after ~10 minutes):

> In CCTP the USDC is destroyed *before* attestation, so any content-dependent revert is a permanent burn. In Gateway the on-chain burn happens *only after* the attestation is used; an unused attestation expires and the off-chain balance is restored. The only irreversible event is a **successful `gatewayMint`**. A pre-mint revert (or a post-mint revert that unwinds the hash marking) costs the user a ~10-minute round trip plus a fresh burn intent (new `salt`), not their funds.

The rule that carries over unchanged: **once `gatewayMint` succeeds, the minted USDC must always end up attributed** (account, or an escrow credit) — never a bare revert after the mint that could be reached repeatedly, and never a silent retention.

## 1. Relevant vulnerability patterns
| Ref | Pattern | Mapping |
|---|---|---|
| vulns §16.1, §33.4; 24-26 §5.2 | Message replay | Circle: `_checkAndMarkTransferSpecHash` on `keccak256(TransferSpec)`, `destinationDomain == domain()`, `destinationContract == minter`. Adapter adds **no** slot of its own. |
| vulns §16.2; 24-26 §5.1 | Receiver-side auth bypass (CrossCurve) | Pull model: the only trust decision is "did `gatewayMint` succeed and by how much did USDC rise". |
| vulns §33.1; 24-26 §5.3 | False deposit / signature bypass (Wormhole) | Single `ECDSA.recover` over `keccak256(payload).toEthSignedMessageHash()` against `attestationSigners`; OZ ECDSA malleability-safe. |
| vulns §33.2; 24-26 §3.3 | Signer key compromise | Attestation signer is fully trusted (audit). Compromise = unbacked mints up to FiatToken `minterAllowed`. Delta accounting never amplifies. |
| vulns §1.1/1.2/1.5, §24.8 | Reentrancy incl. mint-hook | `Mints._mint` → `IMintableToken(minter).mint` where minter = `tokenMintAuthority(token)` **or the token itself**. A wrapper authority could re-enter. `nonReentrant` on both entrypoints + delta measured tightly around `gatewayMint`. |
| vulns §7.4, §13.1; App. H.2 | Unexpected-revert DoS / gas griefing | 2M floor; below → revert (hash unused, retriable in the window); above but OOG → funds at account, root unused, re-drivable (CCTP I1). |
| App. H.1, §13.2 | Returnbomb | Bare `catch` + bounded 4-byte `returndatacopy`; `_tryTransfer` raw-word read. |
| §29.3 | try/catch decode failures | `abi.decode` panics not caught on the same frame → self-call isolation with `msg.sender == this` guards. |
| §10.3, §26.6 | Non-standard ERC-20 returns | `IMintableToken.mint` returns `bool` but **`Mints._mint` ignores it** — a mint authority returning `false` marks the hash with nothing minted; adapter `minted == 0 → revert` unwinds (safe: expiry restores balance). |
| §10.6, §24.3 | Zero address / self-transfer | `account == 0` / `== this` handled (CCTP R3 P3-1). |
| §24.6, §34.6, §35 | Admin backdoors | Ownerless & immutable; no rescue for true donations (accepted). |
| §28.3, §22.2 | Donation / inflation | Delta `post − pre` around `gatewayMint`, clamped to `min(delta, value)`; never `balanceOf(this)`; never re-measure after hooks (Conduit). |
| §14.3 | Input validation | Fail-fast set: magic `0xff6fb334` (reject set `0x1e12db71`), spec magic `0xca85def7`, version 1, length consistency, `destinationContract == GATEWAY_MINTER`, `destinationDomain == domain()`, `destinationCaller ∈ {this, 0}`, recipient rule. Use the lib constants (parser-differential class, CS-EVM-CCTP2-013). |
| 24-26 §10.4 | Blacklistable tokens | Three freeze switches on the adapter address: USDC `blacklist(adapter)`, Gateway `denylist(adapter)`, Gateway `pause()`. In-flight specs bounded by expiry; **escrowed `failedTransfers` are not**. |
| 24-26 §3.2 | Intent replay | Merkle root replay is the executor's; chain via `destinationDomain`; time via `validUntil`. |
| §11, §27.1 | Upgradeable dependency | `GatewayMinter` is UUPS, owner-upgradeable **without delay**. Fork tests must run against deployed bytecode (framework research: vendored `569d7ce` == live implementation today). |
| §25.4 | Source–destination equivalence | `sourceDepositor` is a *source-chain* address; as a destination escrow key it is correct only under the CREATE2 same-address assumption (CCTP I5). |

## 2. Exploit precedents — what transfers
| Incident | Applies? |
|---|---|
| **Allbridge 2026-08-19 (~$190K)** — permissionless `sendMessage` + attested bytes trusted for value | **Structurally absent in Gateway**: no permissionless message-origination primitive; Circle attests only a `BurnIntent` signed by an authorized signer for a `sourceDepositor` whose deposited balance the API verified and debited. Every attestation is value-backed. The three Allbridge fixes (recipient pinning, no trust in hookData for value, balance delta) remain the design. The CCTP `recipient@76` pin's analogue is `destinationContract == GATEWAY_MINTER` + `destinationRecipient == this`. |
| Attacker-authored spec naming a **victim's** account in hookData | Attacker's own deposit backs `value`; achieves only paying the victim. Executor signature is EIP-1271 against the victim's account. Replaying a victim's public sigData: root used → no-op; pre-funded account → early execution (inherited I4). Malicious `initData` bounded by `account == computedAddress`. **No new vector.** |
| **Conduit PR #1 (Sept 2026)** — re-measuring after hooks | Transfers 1:1: measure once around `gatewayMint`. |
| Nomad / Wormhole / Ronin / Multichain / Socket / LI.FI / Poly / CrossCurve / Griffin | N/A or inherited trust (single-signature attestation is the top trust anchor; CCTP V2 at least has a threshold). Never derive a call target from hookData. |
| **ChainSecurity CS-CSpend-001 (High, fixed)** — calldata-offset injection in burn-signer signature | Fixed; shows Circle treats "attestation expired unused" as a first-class state that must not lead to a burn — supports the expiry-restores-balance reading. |
| **CS-CSpend-002 (High)** — same-domain transfers moved to mint-then-burn | Same-domain specs flow through `gatewayMint` identically; extra minter check `sourceToken == destinationToken`. |
| **CS-CSpend-018 (Info)** — blacklist parking via withdraw-to-fresh-address | `claimFailedTransfer` pays `msg.sender` only; do not add a `to` parameter. |

## 3. Attack surface map
**Entrypoints:** `receiveAndExecute(bytes payload, bytes signature)` permissionless/nonReentrant (outcome = pure function of attested bytes + chain state); `claimFailedTransfer(token, amount)` nonReentrant, `msg.sender`-keyed; `decodeHookPayload` / `checkDestinationTargets` self-call only.
**Value transfer:** `gatewayMint` mints exactly `value` to `destinationRecipient` (no destination fee); `_tryTransfer(account, minted)`; `claimFailedTransfer` safeTransfer.
**External calls (immutable targets):** `GATEWAY_MINTER.gatewayMint` (UUPS proxy), `USDC.balanceOf` ×2, `USDC.transfer`, `SUPER_DESTINATION_EXECUTOR.processBridgedExecution` (behind floor, bare catch); constructor reads `domain()`, `isTokenSupported(usdc)`, `SUPER_DESTINATION_VALIDATOR()`.
**Trust:** Circle attestation signer (single ECDSA key, rotatable) — unbacked mints; minter `owner` (UUPS, no timelock) — ABI/semantics change bricks an immutable adapter (specs expire, balances restore, SDK migrates), can set `tokenMintAuthority(USDC)` to a wrapper (reentrancy/over-mint surface → guard + clamp); `denylister`/`pauser`/USDC `blacklister` — DoS on the adapter, bounded by expiry except escrowed balances; burn signers/off-chain system — restore-or-not on expiry; **Gateway delegates** — full allowance, can sign a burn intent routing the whole balance to any recipient with any hookData even after `removeDelegate` (revoked status still accepted on-chain; ERC-1271 revocations up to 5 min off-chain) — the adapter cannot escalate this; escrow to `sourceDepositor`, never `sourceSigner`; **SDK** authors the whole spec (stronger than CCTP: recipient = caller = adapter, token = USDC, no sets, 6-tuple hookData, `intentAmounts ≤ value`); relayer chooses gas only.

## 4. Recommended security patterns (CCTP counterpart in brackets)
1. Fail-fast on raw attestation bytes before any external call [CCTP steps 1/1b]: single-attestation magic (a set's signature covers the concatenation and cannot be split), spec magic, version, length consistency, `destinationContract == GATEWAY_MINTER`, `destinationDomain == domain()`, `destinationCaller ∈ {this,0}`, recipient rule, `value != 0`. Import the lib offset constants.
2. Route on `destinationToken` (spec offset 112 / absolute 152), not a registry [R4 `_resolveLocalToken`]; `!= USDC` → escrow that token to `sourceDepositor`, no execution. USDC-only on all 13 mainnet domains today.
3. Delta once, tightly around `gatewayMint`, clamped to `min(delta, value)`, surplus credited, `minted == 0 → revert NOTHING_MINTED` (safe here: hash unmarked, expiry restores).
4. Escrow-over-revert after the mint [R2 table, R3 P3-1]; beneficiary `sourceDepositor` (offset 144 / absolute 184, fixed part, readable even if hookData is garbage) — but note: since the whole spec is calldata, undecodable hookData is detectable **pre-mint** (see §7 and the decision log).
5. `destinationCaller = 0` accepted + flagged; pinned-but-mints-elsewhere passed through [F1/F2].
6. 2M floor, no stipend, bare catch + bounded selector [P2-2, I1, I2].
7. Self-call isolation for `abi.decode` [decodeHookPayload / checkDestinationTargets].
8. **No per-intent state in the adapter** [relay dust-griefing lens]; the one-shot slot is Circle's `usedHashes[keccak256(spec)]`, which no third party can pre-consume (`sourceDepositor`/`salt` are in the hash; mint must succeed to mark it).
9. `claimFailedTransfer` pays `msg.sender` only [P3-8; CS-CSpend-018].
10. Constructor binds the deployment [R5-2]: `minter.code.length > 0`, `isTokenSupported(usdc)`, cache validator. Do NOT require `domain() != 0` (Ethereum is 0).
11. Optional legibility pre-checks: `maxBlockHeight >= block.number`, `!isTransferSpecHashUsed(hash)` — UX only.
12. Do not add: sweep, owner, `to` on claim, gas stipend, post-hook re-measurement.

## 5. Protocol interaction risks
- `gatewayMint` modifiers hit the adapter address (pause, caller denylist, recipient denylist) → pinned specs revert until lifted or until expiry (~10 min) restores balances. Escrowed balances unaffected by the minter but frozen by a USDC blacklist of the adapter (freezes `claimFailedTransfer` for everyone) — runbook: keep escrow small, monitor `Blacklisted(adapter)` / `Denylisted(adapter)`.
- Payload is `bytes memory` in `gatewayMint` → one calldata copy proportional to hookData; hookData length is `uint32` on-chain, "restricted" off-chain without a published number — a Superform 6-tuple can be several KB (open question 2).
- `IMintableToken.mint` return ignored; mint authority swappable by owner → delta + clamp + guard.
- Same-domain specs are valid (mint-then-burn); escrow beneficiary is then on the same chain.
- `AttestationUsed(token, recipient, transferSpecHash, sourceDomain, sourceDepositor, sourceSigner, value)` gives indexers a per-spec id; pair with adapter events to detect zero-caller direct mints (recipient == adapter with no adapter event in the same tx).
- USDC FiatToken: `mint` is `whenNotPaused onlyMinters notBlacklisted(_to)` bounded by `minterAllowed[GatewayMinter]` (~97M on Ethereum); a blacklisted adapter or exhausted allowance reverts `gatewayMint` (hash unused).
- Executor: silent no-op paths (balance gate, root used, empty calldata) never fire `ExecutionFailed` [P3-2]; `ACCOUNT_NOT_CREATED` for a codeless account with empty initData (USDC at the counterfactual address — safe only if deterministic); `intentAmounts ≤ value` suffices (no destination fee); pre-funded accounts can have roots consumed early [I4].

## 6. Testing recommendations
**Unit/fuzz/invariant (mock minter):** fail-fast matrix (set magic, wrong spec magic, version 2, declared-length mismatches, wrong contract/domain, third-party caller, value 0) asserting no external call; recipient rule ×3; fuzz `(value, actualMinted)` → `delivered == min(minted, value)`, `delivered + surplus == minted`; `minted == 0 → NOTHING_MINTED` with hash unmarked in the mock; escrow paths (undecodable, account 0/this, transfer false/non-bool/revert) claimable only by the beneficiary; non-USDC token routing; parser-differential fuzz (adapter offsets vs `TransferSpecLib` getters); gas floor exact/ε; **mint-authority reentrancy** (re-enter `receiveAndExecute` and `claimFailedTransfer` during `mint` → guard); invariant `USDC.balanceOf(adapter) ≥ Σ failedTransfers[*][USDC]`.
**Fork E2E (live proxy, `vm.prank(owner()) → addAttestationSigner(testSigner)`):** valid pinned spec through the real executor+validator (root consumed; `AttestationUsed` + adapter events in one tx); replay → `TransferSpecHashUsed`; `vm.roll` past `maxBlockHeight` → `AttestationExpiredAtIndex`; `destinationCaller = 0` honest relay + direct EOA `gatewayMint` stranding (document); pinned + recipient = account → pass-through; AttestationSet pinned to adapter → rejected pre-call (and direct submission reverts `InvalidAttestationDestinationCaller`); denylist/pause/unpause; real USDC blacklist of adapter (mint reverts) and of account (escrow → claim); same-domain spec; DstProof mismatch; tampered `intentAmounts`; initData account creation; direct re-drive; deploy parity test; largest realistic hookData gas measurement.

## 7. Open questions for Circle
1. **Expiry semantics (blocking for failure-mode wording):** confirm expiry-unused restores the depositor's Gateway balance and the BurnIntent is never burned; can the same TransferSpec (same salt) be re-attested or is a new salt required?
2. **hookData cap** (bytes, per chain; checked on the EIP-712 burn intent or the attestation?).
3. **AttestationSet issuance:** only when multiple burn intents are submitted, or can a single intent yield a set (multi-source auto-splitting)?
4. **Denylist policy for contract recipients/callers**; does denylisting propagate to escrowed funds; notification channel?
5. **Expiry horizon per chain** (`maxBlockHeight` derived from destination block time? fixed or per request?).
6. **Mint authority:** `tokenMintAuthority(USDC)` zero on every mainnet domain; announcement before setting a wrapper?
7. **Upgrade notice** for the `gatewayMint(bytes,bytes)` ABI and v1 wire format.
8. **Deployed implementation vs public repo** tag (framework research: live == vendored `569d7ce` today).
9. **Delegate model for contract depositors:** is the TEE-validated ERC-1271 path the intended way for a smart account to sign its own burn intent (no delegate), and how are revocations reconciled with the 5-minute recency window?
