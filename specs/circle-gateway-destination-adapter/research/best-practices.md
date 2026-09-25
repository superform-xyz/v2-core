# Circle Gateway "mint-and-execute" adapter: external best-practices research

Scope: destination-side adapter set as `TransferSpec.destinationRecipient` and `destinationCaller`, calling
`GatewayMinter.gatewayMint(attestationPayload, signature)`, measuring the minted USDC delta, decoding an
application payload from `hookData`, funding a smart account and executing a signed intent. Single attestation
per call; post-mint failures escrow instead of reverting.

Research date: 2026-09-23. Confidence legend: **confirmed** (official doc or contract source), **partially**
(inferred / secondary source), **not found**.

Primary sources used
- Contract source: `lib/evm-gateway-contracts` (local pin 569d7ce, 2025-07-21) diffed against `origin/HEAD`
  (v1.3.0, 2026/06). `GatewayMinter`/`Mints.sol` are functionally unchanged between the two (only
  `renounceOwnership()` disabled), so all minter semantics below hold for what is deployed.
- Circle docs: https://developers.circle.com/gateway/references/technical-guide,
  https://developers.circle.com/gateway/concepts/technical-guide,
  https://developers.circle.com/gateway/references/contract-addresses,
  https://developers.circle.com/gateway/references/supported-blockchains,
  https://developers.circle.com/gateway/references/fees,
  https://developers.circle.com/gateway/references/contract-interfaces-and-events,
  https://developers.circle.com/api-reference/gateway/all/create-transfer-attestation,
  https://developers.circle.com/api-reference/gateway/all/get-transfer-by-id
- ChainSecurity audit (2025-07-08): https://6778953.fs1.hubspotusercontent-na1.net/hubfs/6778953/CCTP/[Public]%20[ChainSecurity]%20Circle_Gateway_audit.pdf
- On-chain reads (Base, Arbitrum public RPCs, 2026-09-23) of the mainnet minter/wallet.

---

## 1. TransferSpec, attestation flow, expiry semantics

### 1.1 TransferSpec / Attestation wire format
- **Fact.** `TransferSpec` is a fixed-layout big-endian struct: magic `0xca85def7` (4) | version (4) |
  sourceDomain (4) | destinationDomain (4) | sourceContract (32) | destinationContract (32) | sourceToken (32) |
  destinationToken (32) | sourceDepositor (32) | destinationRecipient (32) | sourceSigner (32) |
  destinationCaller (32, "May be 0, to allow any caller") | value (32) | salt (32) | hookDataLength (4, offset 336) |
  hookData (offset 340). `keccak256(encodedSpec)` is the cross-chain id and replay key; "repeated transfers with
  identical parameters must use a different `salt`".
- **Fact.** `Attestation` = magic `0xff6fb334` (4) | maxBlockHeight (32) | specLength (4) | spec (offset 40).
  `AttestationSet` = magic `0x1e12db71` (4) | count (4) | concatenated attestations (offset 8).
  `gatewayMint` accepts either; it validates the whole payload's signature first, then iterates.
- **Fact.** A `BurnIntentSet` can hold up to 16 intents (EVM), one per source domain; the API then returns an
  **AttestationSet**, one attestation per source domain, each with its own `TransferSpec` (own `value`, own
  `hookData`).
- Source: `src/lib/TransferSpec.sol`, `src/lib/Attestations.sol`, `src/lib/BurnIntents.sol`; technical guide.
- Confidence: **confirmed**.
- Implication: the adapter can parse `hookData` from calldata **before** calling `gatewayMint`
  (`payload[40+340 : 40+340+len]` for a single attestation). Rejecting sets means a transfer that draws from
  more than one source chain cannot use the adapter; see recommendation R2.

### 1.2 What `gatewayMint` checks (per attestation)
- **Fact.** Order: `whenNotPaused`; `notDenylisted(msg.sender)`; ECDSA recover over
  `toEthSignedMessageHash(keccak256(attestationPayload))` must be a registered `attestationSigners[...]`;
  `maxBlockHeight >= block.number`; `value > 0`; `destinationRecipient` not denylisted;
  `destinationCaller == 0 || destinationCaller == msg.sender`; destinationDomain == minter domain;
  destinationContract == minter; destinationToken supported; (same-domain only) sourceToken == destinationToken;
  then `_checkAndMarkTransferSpecHash(specHash)` and `IMintableToken(minter).mint(recipient, value)`; emits
  `AttestationUsed(token, recipient, transferSpecHash, sourceDomain, sourceDepositor, sourceSigner, value)`.
- **Fact.** `hookData` is never read by the minter. Public views available to integrators:
  `isTransferSpecHashUsed(bytes32)`, `isAttestationSigner(address)`, `isDenylisted(address)`,
  `isTokenSupported(address)`, `paused()`, `domain()`.
- Source: `src/modules/minter/Mints.sol`, `src/modules/common/*.sol`.
- Confidence: **confirmed**.
- Implication: the minter gives the adapter everything it needs for pre-flight checks and a permissionless
  "stray direct mint" recovery path (R6) without trusting any input.

### 1.3 Attestation request and validity window
- **Fact.** `POST /v1/transfer` takes signed burn intents / sets; response (HTTP 201) carries `transferId`,
  `attestation` (bytes), `signature`, `fees` (FeeSummary), `expirationBlock`. Query params:
  `maxAttestationSize` (reject if payload exceeds N bytes) and `enableForwarder`. Forwarded requests may omit
  `attestation`/`signature`; fetch via `GET /v1/transfer/{id}` (`attestation.payload`, `attestation.signature`,
  `expirationBlock`; `status` in {pending, confirmed, finalized, failed, expired}, `failureReason`).
- **Fact.** "Attestations expire after 10 minutes." Backend checks the burn intent expiry is "at least the
  wallet's `withdrawalDelay` from the current block". On Arbitrum, `maxBlockHeight` is in **L1 block height**
  (Arbitrum `block.number` returns L1 height). On-chain `withdrawalDelay`: Base 302,400 blocks (~7d at 2s),
  Arbitrum 50,400 (~7d at 12s L1) — consistent.
- Source: create-transfer-attestation API ref; get-transfer-by-id API ref; technical guide; cast reads.
- Confidence: **confirmed** (10-minute figure is doc prose, on-chain enforcement is `maxBlockHeight` only).
- Implication: the adapter must not re-implement expiry; relayers must submit well inside ~10 min. ChainSecurity
  note 8.2: the window is block-based, so slow block production stretches it.

### 1.4 Expiry unfulfilled: balance return / re-request / when the burn happens
- **Fact (docs table, concepts/technical-guide).** Off-chain ledger responses:
  "Transfer request (attestation issued)" -> "Decrement balance"; "AttestationUsed event" -> "Submit burn intents
  to source chains"; "Attestation expires unused" -> "Increment balance"; "WithdrawInitiated event" -> "Decrement
  balance".
- **Fact (contracts).** The source-side burn is executed only by Circle's burn signer via
  `GatewayWallet.gatewayBurn` after the mint (`AttestationUsed`). `gatewayBurn` marks the same transferSpecHash,
  so a spec can never be burned twice. A burn intent that was never minted has no on-chain footprint.
- **Partially.** Whether Circle will re-issue an attestation for the *same signed BurnIntent* (same salt/spec
  hash) after expiry, versus requiring a fresh intent with a new salt, is **not documented**. On-chain nothing
  prevents it (hash unused). Docs only say the balance is re-credited and a user "can re-request".
- Source: https://developers.circle.com/gateway/concepts/technical-guide; `Burns.sol`.
- Confidence: balance return **confirmed**; re-issue policy **not found** -> open question Q1.
- Implication (major): unlike CCTP, a **revert anywhere in the adapter's tx is fund-safe**: the mint is undone,
  the spec hash stays unused, and the user's unified balance is re-credited on expiry. Escrow-not-revert is a
  UX/latency choice for post-mint failures, not a fund-safety necessity. Pre-mint validation failures should
  simply revert (R3).

## 2. hookData size/format, contracts as recipient, integrator examples

- **Fact.** On-chain the only bound is `hookData.length <= type(uint32).max` (`TransferSpecLib`). Audit note 8.3
  lists as an *assumed backend check* that "the length of the hook data in TransferSpec is restricted to ensure
  the execution of BurnIntent does not consume large amounts of gas" -- the concrete limit is not published.
  The API exposes client-side `maxAttestationSize`.
- **Fact.** Circle's own guidance on composition: "To atomically compose this mint with other onchain actions,
  use a multi-call contract" and "Use `destinationCaller` for composed mint flows where only a specific caller
  should be able to use the attestation ... to prevent front-running a mint when it's intended to be composed
  with other actions in the same transaction." `hookData`: "Arbitrary bytes that may be used for onchain
  composition". No format prescribed; quickstarts, the practical-guide blog, the `circlefin/skills` use-gateway
  skill and the Arc Unified Balance Kit all set `hookData: "0x"`.
- **Not found.** No Circle example or named third-party integrator using non-empty `hookData` or a contract as
  `destinationRecipient`; no statement that the API rejects contract recipients (EVM). Solana guidance only says
  the recipient must be a USDC token account.
- Sources: technical guide; https://www.circle.com/blog/a-practical-guide-to-building-with-circle-gateway;
  https://github.com/circlefin/skills/blob/master/plugins/circle/skills/use-gateway/SKILL.md;
  https://www.arc.io/blog/from-gateway-primitives-to-unified-balance-kit-methods; audit 8.3.
- Confidence: **partially** (contract bound confirmed; backend bound and recipient policy not found).
- Implication: keep the payload compact and self-describing (version byte + ABI tuple); ask Circle for the
  backend cap (Q2) and confirm contract recipients are accepted on EVM (Q3); test on testnet with a
  representative payload size before mainnet.

## 3. Fees

- **Fact (contracts).** Fees are taken **on the burn side only**. `Burns._processSingleBurnIntent` reduces the
  depositor's balance by `value + fee`, transfers `totalFee` to `feeRecipient`, burns the rest. The minter mints
  exactly `spec.value` to `destinationRecipient`. So the minted `value` is **gross** relative to the spec and the
  fee is an *additional* debit on the source unified balance. If the depositor cannot cover `value + fee`, the
  burn value is prioritised over the fee (`InsufficientBalance` event, "should never happen").
- **Fact (fee model).** `gatewayBurn(calldataBytes, signature)`: `calldataBytes = abi.encode(intents[],
  signatures[], fees[][])` signed by a registered `burnSigners[...]`; each `fees[i][j] <= intent.maxFee` is
  enforced on-chain. The user signs `maxFee` inside the EIP-712 `BurnIntent`; Circle picks the actual fee.
  (Audit 6.1 High, fixed: the original msg.data-slicing signature check allowed injecting foreign intents / zero
  fees.)
- **Fact (docs).** Cross-chain transfer fee 0.005% (0.5 bp) "deducted from your unified USDC balance at the time
  of burn"; per-chain gas fee ($0.001 Sei/Unichain ... $1.00 Ethereum); forwarding service $0.05 + gas;
  minimum `maxFee` $0.06; formula `maxFee >= gas fee + forwarding fee + amount * 0.00005`; same-chain transfers
  pay gas fee only.
- Sources: `Burns.sol`; https://developers.circle.com/gateway/references/fees.
- Confidence: **confirmed**.
- Implication: under normal conditions `delta == spec.value`. Still measure the delta (R4) and treat
  `delta != value` as an anomaly (escrow, do not forward `value`).

## 4. Mainnet availability, addresses, tokens, domains

- **Fact.** Mainnet EVM: GatewayWallet `0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE`, GatewayMinter
  `0x2222222d7164433c4C09B0b0D809a9b52C04C205`, identical on every mainnet EVM chain (CREATE2; README documents
  prefixes 0x7777777/0x2222222 mainnet, 0x0077777/0x0022222 testnet). Testnet: wallet
  `0x0077777d7EBA4688BDeF3E311b846F25870A19B9`, minter `0x0022222ABE238Cc2C7Bb1f21003F0a260052475B`.
- **Fact.** Live chains/domains: Ethereum 0, Avalanche 1, OP 2, Arbitrum 3, Base 6, Polygon PoS 7, Unichain 10,
  Sonic 13, World Chain 14, Sei 16, HyperEVM 19, Arc 26; Solana domain 5 (non-EVM, different program ids).
  "Gateway uses the same domain identifiers as CCTP." Token: USDC only ("subset of blockchains where USDC is
  natively issued").
- **Fact (on-chain 2026-09-23).** Base minter `domain()==6`, `paused()==false`, Base USDC supported;
  Arbitrum minter `domain()==3`, not paused. Minter `owner()` differs per chain (Base
  `0xF1237f985D146D8AeC106c742Ec6D8C4A98bB788`, Arbitrum `0xCa01392083523DF0629208d15ac8719237Fd9ADd`) --
  presumably Circle multisigs, not verified.
- Sources: contract-addresses and supported-blockchains docs; cast reads; README.
- Confidence: **confirmed** (address/domain list), owner identity **partially**.
- Implication: one adapter bytecode + one config (minter, USDC) per chain; use CCTP domain ids as-is.
  Note that the mainnet mint/wallet **owner can upgrade without delay** (audit trust model) -- treat the minter
  as an upgradeable dependency and do not hard-code ABI assumptions beyond the documented interface.

## 5. Denylist, pausing, signer rotation

- **Fact.** `gatewayMint` reverts if `msg.sender` (the adapter) **or** `destinationRecipient` (the adapter) is
  denylisted, or if the minter is paused. The Gateway denylist is separate from the USDC token blacklist
  (audit 8.1). Denylister role is a single address settable by owner; "compromised, it can cause
  denial-of-service by denylisting core contracts" (audit trust model). Attestation signers are a
  `mapping(address => bool)` mutated by `addAttestationSigner`/`removeAttestationSigner` (owner only) with
  events; "This approach facilitates the rotation of accounts" (audit 2.3). Circle publishes no signer address
  and no rotation notice process.
- **Not found.** Any Circle guidance for integrators whose contract is denylisted, or an appeals process.
- Sources: `Denylist.sol`, `Pausing.sol`, `Mints.sol`; audit 2.5/8.1.
- Confidence: **confirmed** (mechanics); guidance **not found** -> Q4, Q5.
- Implication: a denylisted or paused adapter cannot mint; in-flight attestations expire and balances are
  re-credited (no fund loss), but it is a full outage for the route. Do not cache signer addresses; verify
  attestations only via the minter's `isAttestationSigner` view (used in R6). Keep a non-Gateway fallback
  route in the source-side hook.

## 6. Audits

- **Fact.** ChainSecurity, 2025-07-08, 3 versions (f24a7d1 -> ca774f1 -> 5b5446f); 0 critical, 2 high,
  0 medium, 7 low, 7 informational, all corrected or spec-changed. Relevant items:
  - 6.1 High (fixed): burn-side calldata injection via msg.data slicing -- now `gatewayBurn` signs an explicit
    `calldataBytes` argument.
  - 6.2 High (spec changed): same-chain transfers violated non-custodial property; refactored to mint-then-burn.
  - 8.2 Note: attestation validity is block-height based; slow blocks stretch the window past the burn intent's.
  - 8.3 Note: hookData length and length-field correctness are **backend** responsibilities.
  - 7.1 Info: `_bytes32ToAddress` truncates high bytes (non-canonical) -- a `bytes32` with garbage in the top 12
    bytes still maps to the same address.
  - README warning: TypedMemView leaves dirty memory; newly allocated memory may not be zero.
  - No findings on attestation sets, replay (`TransferSpecHashes`), or `destinationCaller`.
- **Not found.** Any public audit of v1.1-v1.3 (ERC-1271 allowlist, batches, TEE signer). `CHANGELOG.md`
  upstream lists the releases but no audit links.
- Source: audit PDF; `origin/HEAD:CHANGELOG.md`.
- Confidence: **confirmed** for v1.0; later versions **not found** -> Q6.
- Implication: when the adapter checks `destinationRecipient`/`destinationCaller` from the spec it should
  compare the full `bytes32` to `bytes32(uint256(uint160(address(this))))`, not the truncated address, to be
  stricter than the minter.

## 7. Comparable attested-mint + hook integrations

### 7.1 CCTP V2 hooks (Circle)
- **Fact.** "CCTP does not implement hook execution in the core protocol. Instead, hooks are treated as opaque
  metadata"; integrators "implement custom recovery or error-handling strategies if hook execution fails".
  Same posture as Gateway.
- Superform's own `src/adapters/CCTPAdapter.sol` (PR #1015, merged 2026-09-23) is the house reference: pull-driven
  permissionless `receiveAndExecute`, `destinationCaller = adapter`, pre/post USDC delta (never `balanceOf`),
  isolated self-call decode of hookData, escrow to the attested sender on undecodable payload, fund account
  first then execute, `MIN_EXECUTION_GAS = 2_000_000` floor, bare `catch` reading only 4 bytes of returndata,
  `claimFailedTransfer` for escrow.
- Source: https://developers.circle.com/cctp/technical-guide; local CCTPAdapter.

### 7.2 Allbridge forged-message incident (2026-08-19, ~$190k)
- **Fact.** Root causes (SlowMist): the receiver did not verify the message `sender` equalled the remote
  TokenMessenger nor that `recipient` equalled Circle's TokenMessengerV2, and "did not check whether the Router's
  USDC balance had actually increased before accounting, and directly trusted the amount contained in the
  message". Attacker used `MessageTransmitterV2.sendMessage` to get a *genuinely attested* message with no burn.
- Sources: https://slowmist.medium.com/a-cross-chain-attack-spanning-one-month-analysis-of-the-allbridge-hack-32a6183bce08 (summary via
  https://www.kucoin.com/news/flash/slow-mist-reveals-allbridge-cross-chain-bridge-attack-details-fake-cctp-messages-flash-loans-and-insufficient-minting-verification).
- Implication: never credit `spec.value`; credit the measured mint delta. Gateway has no generic
  `sendMessage`, but the same discipline defends against minter upgrades/mint-authority changes.

### 7.3 Hook-bypass via permissionless relay (Lattice issue #216)
- **Fact.** With `destinationCaller = 0`, "anyone can relay a message ... the USDC is minted and the CCTP nonce
  is consumed, but the hook never runs"; proposed fixes: refuse unpinned hooked messages, OOG post-check so the
  nonce stays live, escape hatch for the attested recipient, and require `destinationCaller` = the hook executor.
- Source: https://github.com/dadadave80/lattice/issues/216.
- Implication: for Gateway the analogue is someone calling `GatewayMinter.gatewayMint` directly with an
  attestation whose `destinationCaller == 0` and `destinationRecipient == adapter`: USDC lands in the adapter
  with no execution. The adapter cannot stop that call; it can only (a) require the source side to pin
  `destinationCaller`, and (b) provide a permissionless recovery for such stray mints (R6).

### 7.4 Across MulticallHandler / custom handlers
- **Fact.** `handleV3AcrossMessage` decodes `Instructions{calls, fallbackRecipient}`; if a fallback is set, calls
  are attempted via self-call and on failure `CallsFailed` is emitted and **all leftover tokens are drained to
  `fallbackRecipient`**; without a fallback the handler reverts and the fill fails (deposit later expires and
  refunds on origin). Extra execution gas is priced into `inputAmount - outputAmount`.
- Sources: https://github.com/across-protocol/contracts/blob/master/contracts/handlers/MulticallHandler.sol;
  https://docs.across.to/introduction/embedded-actions.
- Implication: escrow/fallback-recipient on failure is the industry norm; Across can afford revert-on-failure
  because deposits refund -- Gateway also refunds (via expiry), CCTP does not.

### 7.5 LayerZero composers
- **Fact.** Tokens are delivered to the composer in `lzReceive`; `lzCompose` runs in a separate tx and, on
  revert, "any user can simply retry"; recommended: validate `msg.sender == endpoint` and `from == oApp`, size
  compose gas explicitly, keep one action per message. Known failure class: OOG *before* the
  `excessivelySafeCall` guard blocks the channel (C4 Maia findings).
- Sources: https://docs.layerzero.network/v2/developers/evm/composer/overview;
  https://github.com/code-423n4/2023-09-maia-findings/issues/354;
  https://github.com/windhustler/Interoperability-Protocol-Security-Checklist/blob/main/audit-checklists/LayerZeroV2.md.
- Implication: separate "funds delivered" from "intent executed"; make the execution leg independently
  re-drivable; enforce a gas floor *before* the guarded call.

### 7.6 Bounded revert data / gas floors
- **Fact.** ExcessivelySafeCall README: a callee can "returnbomb" the caller by returning/reverting huge data;
  cap copied returndata (e.g. 32 bytes / 4-byte selector). EIP-150 forwards at most 63/64 of remaining gas, so a
  `gasleft()` floor before the guarded call is the only way to prevent a relayer from starving the inner call
  into the catch branch deterministically.
- Source: `lib/ExcessivelySafeCall/README.md`; house pattern in CCTPAdapter.

---

## Prioritised design recommendations

R1. **Pre-mint, validate everything that is in calldata, and revert on failure.** Parse the attestation from
    calldata: magic must be `0xff6fb334` (reject `0x1e12db71` sets unless R2 is adopted); spec magic/version;
    `destinationRecipient` and `destinationCaller` bytes32-equal to `address(this)` (full 32 bytes);
    `destinationToken == USDC`; `destinationContract == minter`; `hookData` decodable (isolated self-call);
    intent targets match this deployment. A revert here has zero side effects -- the attestation stays valid
    until expiry and the balance is re-credited afterwards. Optionally pre-check
    `minter.isTransferSpecHashUsed(hash)` and `minter.paused()` for legible errors.

R2. **Decide explicitly on AttestationSets.** Rejecting sets blocks any transfer whose unified balance is drawn
    from more than one source chain (the core Gateway value proposition). Either (a) support sets by iterating
    every attestation, requiring identical `destinationRecipient`/`destinationCaller`/`destinationToken` and a
    single canonical `hookData` (e.g. only index 0 non-empty, or all `keccak256(hookData)` equal), summing the
    delta; or (b) keep single-attestation and make the source-side builder always produce one-domain intents,
    documenting the restriction. (a) is recommended for MVP+1; (b) is acceptable for MVP if documented.

R3. **Post-mint, never revert; escrow.** After `gatewayMint` succeeds the spec hash is consumed on-chain. Fund the
    account first, then try/catch the executor with a `gasleft()` floor (reuse `MIN_EXECUTION_GAS = 2_000_000`
    and the 4-byte selector capture from CCTPAdapter). Note the difference from CCTP: because pre-mint reverts
    are safe, the only post-mint failures left are executor reverts/OOG, which leave USDC with the account.

R4. **Credit the measured delta, not `spec.value`.** `pre/post balanceOf(this)` around `gatewayMint`; treat
    `delta == 0` as revert (pre-mint safe) and `delta != value` as an anomaly to escrow rather than forward.
    Never forward `balanceOf(this)` (donations and escrow liabilities live there).

R5. **Escrow recipient: the decoded intent account, not `sourceDepositor`.** `sourceDepositor` is an address
    on the *source* chain's wallet contract; for smart-account depositors it may not exist or be controlled on
    the destination chain (CREATE2 salts, Safe versions, chain-specific factories). Since R1 guarantees
    `hookData` decodes before minting, the account is always available post-mint. Keep `sourceDepositor` only
    as a last-resort key for R6 recoveries where no hookData exists, and expose `claimFailedTransfer` keyed by
    (recipient, token).

R6. **Permissionless recovery for direct mints (hook bypass).** If an unpinned attestation
    (`destinationCaller == 0`) is redeemed directly on the minter, USDC arrives at the adapter without
    execution. Add `recoverDirectMint(attestationPayload, signature)`: recover the signer, require
    `minter.isAttestationSigner(signer)`, `minter.isTransferSpecHashUsed(specHash) == true`, recipient == this,
    hash **not** in the adapter's own processed set, then credit escrow (to decoded account, else
    `sourceDepositor`) bounded by `balanceOf(this) - totalEscrowLiabilities`. Record every hash the adapter
    processes so this cannot double-credit. Emit `AttestationUsed`-linkable events (`transferSpecHash`).

R7. **Pin `destinationCaller` at the source.** The source-side hook/builder must set
    `destinationCaller = adapter` and `destinationRecipient = adapter`; the adapter should still refuse
    unpinned attestations (R1) so relayers cannot race the mint. Provide a non-Gateway fallback route in case
    the adapter is denylisted or the minter paused (section 5).

R8. **Idempotency and observability keyed by `transferSpecHash`.** Store processed hashes; emit
    `Delivered/Escrowed/ExecutionFailed(transferSpecHash, account, amount, selector)`. This matches Circle's
    cross-chain identifier and the `AttestationUsed`/`GatewayBurned` events for off-chain reconciliation.

R9. **Payload hygiene.** Version byte + ABI tuple; enforce a maximum `hookData` length in the adapter
    (e.g. 4-8 KiB) and in the off-chain builder; request `maxAttestationSize` from the API; benchmark
    `gatewayMint` + execution gas with the largest payload on testnet (Sepolia minter
    `0x0022222ABE238Cc2C7Bb1f21003F0a260052475B`).

R10. **Do not depend on `block.number` semantics or cached signers.** Arbitrum reports L1 block height; the
    minter owns expiry and signer sets. Treat the minter as an owner-upgradeable dependency (no timelock) and
    monitor `Paused`, `Denylisted(adapter)`, `AttestationSignerRemoved`, `Upgraded` events.

R11. **Source side for smart accounts.** ERC-1271 burn intents require Circle's contract-signer allowlist
     (CHANGELOG 1.1.0/1.3.0); otherwise the smart account must `addDelegate` an EOA signer on the
     GatewayWallet. Plan this before the adapter ships.

## Open questions for Circle

Q1. After an attestation expires unused, will `/v1/transfer` re-issue for the *same* signed BurnIntent
    (same salt / transferSpecHash), or must the client sign a fresh intent with a new salt? Is there a cooldown
    before the ledger re-credits ("Attestation expires unused -> Increment balance")?
Q2. What is the backend maximum for `hookData` length (audit note 8.3 says it is restricted) and the maximum
    encoded attestation size? Is there a fee/gas surcharge for large hookData?
Q3. Are smart contracts accepted as `destinationRecipient` and `destinationCaller` on EVM without allowlisting?
    Any compliance screening applied to contract recipients?
Q4. Denylist policy: under what circumstances would Circle denylist an integrator contract, is there notice, and
    what is the remediation path? Would a denylisting of the adapter as `destinationRecipient` also block
    already-issued attestations (yes on-chain -- confirm the backend re-credits them on expiry)?
Q5. Attestation signer rotation: is there an advance-notice channel, and are old signers kept valid for the
    10-minute window so in-flight attestations still mint?
Q6. Are there audits for contract versions 1.1.0-1.3.0 (ERC-1271 allowlist, `Batches`, TEE
    `contractSignatureSigner`) and are the mainnet proxies currently on 1.3.0 on every chain?
Q7. Does the Circle Forwarding Service (`enableForwarder=true`) support attestations whose
    `destinationCaller` is a third-party contract (i.e. will it call our adapter rather than `gatewayMint`
    directly)? If not, our relayer must be the sole submitter.
Q8. Contract-signer allowlist process for Superform smart accounts (Nexus/Safe-7579) to sign burn intents via
    ERC-1271, and whether the TEE re-signing adds latency to `/v1/transfer`.
Q9. Any plan to add tokens other than USDC (EURC) to Gateway, which would change the "USDC-only" assumption in
    the adapter's token checks?
