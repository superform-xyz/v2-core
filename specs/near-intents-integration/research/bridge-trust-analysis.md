# NEAR Intents — Bridge Trust & Risk Analysis

> Source: multi-agent deep-research pass, 2026-08-11. 103 agents, adversarially
> verified. This document hardens the DEFER decision in `../spec.md` by quantifying
> the risk an EVM integrator inherits, because NEAR Intents has no on-chain EVM
> entry-point — EVM funds move only through these three bridges. Confidence noted
> per claim; unresolved gaps flagged explicitly.

## Why this matters

An EVM integrator of NEAR Intents does not deposit into an audited on-chain contract
(as with Relay). Instead, funds cross via **one of three bridges, selected by the
protocol per route**. **You inherit the trust model of whichever bridge is used** — so
the effective security of the integration is the security of the *weakest bridge on the
route actually taken*, not an average.

## The three bridges (route ids: `omni_bridge`, `poa_bridge`, `hot_bridge`)

Confirmed in both the SDK `RouteEnum` and official docs (high, 3-0). There are also three
NEAR-internal routes not relevant to EVM.

### 1. Omni Bridge (`omni_bridge`)
- **Trust model:** MPC/TSS via **NEAR Chain Signatures** — a node network jointly signs
  NEAR→EVM withdrawals without ever reconstructing the full key; successor to the old
  light-client Rainbow Bridge. (high, 3-0)
  - ⚠️ **Caveat:** at launch the MPC set is effectively a **permissioned ~8–10 node-provider
    group** ("decentralized" is aspirational). `near/mpc` is moving toward permissionless
    staking/slashing but isn't there yet.
- **Inbound (EVM→NEAR) is weaker than outbound:** still relies on **light clients on NEAR
  plus Wormhole off-chain validators** (~60s validator step). Only NEAR→EVM gets the single
  MPC signature. So inbound trust additionally depends on the Wormhole validator set. (high, 3-0)
- **Latency:** NEAR→EVM ~30s (MPC signing stage only); inbound EVM→NEAR finality ~**960s
  (Ethereum), ~1026s (Base), ~1066s (Arbitrum)**, ~14s (Solana). First-party, not
  independently benchmarked. (high, 3-0)
- **NEAR-side contract:** `omni.bridge.near` (live, 630k+ txns). SDK requires `intents.near`
  to hold ≥0.5 NEAR storage balance for Omni withdrawals (client-side guardrail, not
  contract-enforced). (high, 3-0)

### 2. POA Bridge (`poa_bridge`) — **the weakest link**
- **Trust model:** explicit **Proof-of-Authority** — a permissioned authority-signer scheme
  via "PoA Token" + "PoA factory" contracts in `near/intents`, operated by **Defuse Labs**.
  **Not** MPC/TSS, **not** light-client. (high, 3-0)
- **Supports the widest chain set** → it is the **default/fallback for many routes**, so you
  are most likely to hit it on long-tail chains.
- ⚠️ **Signer count, threshold, and operator identities are undisclosed.** A compromise or
  collusion of the PoA authority could **forge withdrawals or censor/freeze funds in transit**.

### 3. HOT Bridge (`hot_bridge`)
- **Trust model:** threshold **MPC/TSS in TEE**, operated by HOT Labs; validators each hold
  key shares and co-sign (no single full key), honest-majority + verified-TEE assumption.
  Named validators: **EverStake, NEAR Protocol, Aurora, HAPI** — largely NEAR-ecosystem-aligned.
  (high, 3-0)
- ⚠️ **Exact signer count `n` and threshold `t` are undisclosed** (whitepaper/docs describe it
  only abstractly). (high, 3-0)
- **Audited** (component-scoped): **Trail of Bits** (HOT Protocol), **Hacken** (Omni Token
  Solidity), **Veridise** (HOT Bridge, July 2025, Rust contracts + relayer). (medium, 2-1 —
  the Trail of Bits report was attested only via the vendor's own site.)
- **Deposits are client-driven and non-instant:** `deposit()` → `waitPendingDeposit()`
  (~30s–2min, can wait indefinitely) → `finishDeposit()`. Completion depends on the client
  polling and finalizing. (high, 3-0)
- In the defuse SDK, the HOT route is a **thin wrapper around the third-party
  `@hot-labs/omni-sdk` (pinned v2.25.5) + HOT's off-chain HTTP API** — trust is delegated to
  HOT Labs' SDK/API, not independently on-chain-verifiable. (medium, 2-1)

## Comparative risk table

| | Omni | POA | HOT |
|---|---|---|---|
| Model | MPC/TSS (Chain Signatures) | **Proof-of-Authority (permissioned)** | MPC/TSS in TEE |
| Operator | ~8–10 node providers (launch) | **Defuse Labs (undisclosed set)** | HOT Labs validators (EverStake/NEAR/Aurora/HAPI) |
| Signer n / threshold t | undisclosed | **undisclosed** | undisclosed |
| Audits | not clearly documented | **none disclosed** | ToB / Hacken / Veridise (component-scoped) |
| Inbound (EVM→NEAR) trust | light clients + Wormhole validators | PoA authority | MPC + TEE + API gatekeepers |
| Chain coverage | major EVM/Solana/Bitcoin | **widest (fallback)** | 10+ EVM rollups + TON/Stellar/Cosmos |
| Trust-minimization | highest of the three | **lowest** | middle (audited but opaque params) |

## Weakest link & worst case

**POA Bridge is the weakest link** — least trust-minimized, undisclosed authority set, and the
default for the widest chain set. **Worst case for funds in transit:** compromise or collusion
of the PoA authority (or, for Omni/HOT, of ≥threshold MPC signers, the inbound Wormhole
validator set, or a TEE bypass) could **forge withdrawals or freeze/censor funds**, with only
**service-layer (not trustless on-chain) refund recourse**. (medium, 3-0)

## Failure & refund handling

Refunds are handled at the **service/API layer**, not on-chain. The **1Click API** provides
status tracking (`PENDING_DEPOSIT / PROCESSING / SUCCESS / REFUNDED / FAILED`), automatic
retries, and refund-to-address handling: the integrator supplies a `refundTo` address and
**polls**, rather than relying on an on-chain refund path. HOT additionally needs client-driven
`finishDeposit()`. There is **no verified trustless on-chain refund** if a relayer/API/operator
goes offline mid-transfer. (high, 3-0)

## Critical unresolved gap (the decisive one)

**EVM-side contract admin keys, upgradeability, and pause controls are NOT documented in any
primary source** for any of the three bridges — no docs, READMEs, or whitepapers disclose who
holds them, whether they are multisig/timelocked, or whether they can unilaterally freeze or
drain funds in transit. For an EVM integrator, **this is the single most important unanswered
custody question**, and it could not be resolved from public sources. Until it is, every route
carries **unquantified admin-key custody risk**.

> Note: a claim that the NEAR-side Controller/Key Registry contracts run "without access keys"
> (i.e., no admin upgrade key) **could not be verified (0-3)** — do not rely on it.

## Implications for the DEFER decision

This strengthens the deferral. Relay concentrates trust in **one audited on-chain Depository
with on-chain, `depositor`-attributed refunds**. NEAR Intents spreads trust across **three
bridges of varying and partly-undisclosed trust models**, with **service-layer refunds** and
**undocumented EVM admin controls** — a strictly larger and less legible attack surface, for a
protocol whose distinct reach (Bitcoin/Solana/TON) we don't currently need over
Across/deBridge/Relay.

## Watch-list (revisit triggers, in addition to spec.md #1)

- POA Bridge publishes its authority set size/operators, or is replaced by an MPC/light-client scheme.
- Bridges disclose EVM-side admin/upgrade/pause controls (multisig + timelock).
- Full audit reports (ToB/Hacken/Veridise) are published with severity/resolution details.
- A trustless on-chain refund path for stuck transfers appears.

## Sources

- https://docs.near-intents.org/integration/bridging/overview
- https://docs.near.org/chain-abstraction/omnibridge/how-it-works
- https://github.com/Near-One/omni-bridge
- https://github.com/near/intents
- https://github.com/near/mpc
- https://github.com/defuse-protocol/sdk-monorepo (bridge-sdk, intents-sdk)
- HOT Labs: `@hot-labs/omni-sdk`, hot-validation-sdk; audits — Trail of Bits, Hacken, Veridise (Jul 2025)

## Caveats (fast-moving / low-confidence)

- Signer counts/thresholds undisclosed for all three; PoA operator set undisclosed.
- Omni "decentralized MPC" is ~8–10 permissioned providers at launch; HOT validators are
  NEAR-ecosystem-aligned — independence is self-reported.
- Omni latency figures are first-party.
- Audits are component-scoped; the ToB HOT report was vendor-attested only.
- Repos/validator sets are actively evolving (`hot-validation-sdk` updated mid-2026;
  `near/mpc` moving toward permissionless staking/slashing) — re-check before any build.
