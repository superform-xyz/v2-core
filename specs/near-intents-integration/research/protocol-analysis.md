# NEAR Intents — Protocol Analysis (Research)

> Source: multi-agent deep-research pass, 2026-08-11. 93 agents, 13 primary sources
> fetched, 25 falsifiable claims extracted, 24 confirmed via 3-vote adversarial
> verification, 1 refuted. All load-bearing sources are primary (official docs,
> GitHub, npm). Confidence noted per section.

## 1. Architecture & trust model

NEAR Intents (formerly **Defuse**) is an intent-based settlement network built **on
NEAR**. The flow is **Express → Solve → Settle**:

- **Express:** a user/agent signs a desired outcome (e.g. "swap X for ≥ Y").
- **Solve:** solvers/market-makers are matched **off-chain** through a WebSocket
  **Solver/Message Bus** (default `wss://solver-relay-v2.chaindefuser.com/ws`). The Bus
  broadcasts quote requests, collects signed responses, waits ~3000ms, then submits
  settlement.
- **Settle:** the **Verifier** contract executes the signed intents atomically via
  `execute_intents`, as a net-zero P2P balance update.

**Verifier ("the on-chain settlement layer"):** deployed **only on NEAR** at the account
**`intents.near`**. It "operates as an internal ledger, tracking token balances for all
participants." There is **no EVM deployment and no testnet deployment**. The `near/intents`
repo is Rust/NEAR only (no Solidity). Solver liquidity is custodied NEAR-side: reserves are
deposited to `intents.near` and the solver public key is registered via `add_public_key`.

**Where trust sits:** (a) the NEAR Verifier for settlement correctness; (b) the off-chain
Solver Bus for matching/liveness; (c) the **bridge** used to move value on/off EVM chains —
this is the dominant risk for an EVM integrator (see §4–5).

Confidence: **high** (unanimous 3-0 across `docs.near-intents.org/integration/verifier-contract`,
`docs.near.org/chain-abstraction/intents/overview`, `github.com/near/intents`).

## 2. THE KEY QUESTION — EVM integration surface

**There is NO canonical, integrator-facing EVM smart contract analogous to Relay's
Depository** that an EVM smart account/hook calls to create or deposit into an intent.

- EVM funds reach NEAR Intents **only by being bridged** to the NEAR-side Verifier.
- Tokens are held NEAR-side as **NEP-141** (fungible) / **NEP-245** (multi-token)
  representations (e.g. `nep141:base-0x833589fcd6...omft.near` = Base USDC via PoA;
  `nep245:v2_1.omni.hot.tg:...` = Polygon USDC via HOT).
- "Actual movement of tokens to external chains occurs only on withdrawal through token
  bridges." Deposits are typically funded via **API-generated per-user deposit addresses**,
  not a fixed contract.
- The chain/address-support docs list supported networks but publish **no EVM deposit
  contract addresses, ABIs, or verifier addresses**.
- The official `@defuse-protocol/intents-sdk` marks **Deposits ❌ ("Coming Soon")**:
  "Deposit functionality is not yet implemented in this SDK. Currently, use bridge
  interfaces directly."

Confidence: **high** (unanimous 3-0; adversarial search for a Relay-Depository analogue
found none).

### Nearest EVM-callable contracts (bridge infra — NOT an intent entry-point)

NEAR's **Omni Bridge** (a *separate* MPC bridge product):

- Interface: `approve` then
  `initTransfer(address tokenAddress, uint128 amount, uint128 fee, uint128 nativeFee, string recipient, string message) payable`
- Mainnet lockers:
  - Ethereum: `0xe00c629aFaCCb0510995A2B95560E446A24c85B9`
  - Base / Arbitrum / Polygon: `0xd025b38762B4A4E36F0Cde483b86CB13ea00D989`
- Flow: lock/burn on source → MPC signs → destination finalizes.

**Load-bearing caveat:** the `Near-One/omni-bridge` repo makes **no mention of NEAR Intents**
or the verifier/solver model — it is a standalone MPC bridge. Calling `initTransfer` is
**not** "creating an intent." Do not present it as the canonical NEAR Intents entry-point.

Confidence: **high** (addresses + signature verified verbatim via two independent fetches;
the "these are bridge, not intent entry-point" scoping passed 2-1 adversarial).

## 3. Supported chains & assets

- **16 EVM chains** (per docs header; scrape enumerated 15 — minor doc inconsistency):
  Ethereum, Base, Arbitrum, Optimism, Polygon, BNB Chain, Avalanche, Gnosis, Aurora,
  Scroll, Bera, Monad, XLayer, Plasma, ADI — plus non-EVM (Solana, Bitcoin).
- EVM addresses: standard `0x`-prefixed 42-char, **ERC-191** signing.
- Assets represented NEAR-side as NEP-141 / NEP-245.

Confidence: **high**.

## 4. Solver / settlement, custody, failure handling (integrator view)

- **Bridges (protocol-selected by destination chain):** Omni Bridge (`omni_bridge`),
  POA Bridge (`poa_bridge`), HOT Bridge (`hot_bridge`).
- **Solver matching:** off-chain WebSocket bus (above); solvers hold liquidity NEAR-side.
- **1Click distribution channel** (primary integrator-facing path): a REST API
  (`GET` supported tokens, `POST /v0/quote` → unique deposit address, status tracking) that
  "abstracts the complexity of intent creation, solver coordination, and transaction
  execution." **It is custodial:** "temporarily transferring assets to a trusted swapping
  agent that coordinates with Market Makers." Failure states include `PENDING_DEPOSIT`,
  `PROCESSING`, `SUCCESS`, `INCOMPLETE_DEPOSIT`, `REFUNDED`, `FAILED` (refund handling is
  off-chain, agent-mediated).

Confidence: **high**.

## 5. Security considerations & concrete risks vs a Relay-style deposit

- **Bridge risk dominates.** An EVM→NEAR→EVM round trip inherits the **weakest of
  {Omni, POA, HOT}** MPC/validator assumptions — not a single audited on-chain contract.
- **Dynamic deposit addresses.** Per-quote/per-user addresses (via API) mean a hook cannot
  bind to a stable target; the address is attested off-chain.
- **Custodial window (1Click).** The swapping agent controls the deposit address and the
  custody/refund flow; a non-EOA vault cannot cleanly prove/attribute refunds on-chain.
- **No on-chain refund attribution** comparable to Relay's `depositor`-pinned refunds.

Net: the trust and custody model is materially different — and, for our use, worse — than a
single audited Depository deposit.

## 6. Direct comparison to Relay

A Relay-style EVM `adapter + hook` (`RelayAdapter` + `RelaySendFundsAndExecuteOnDstHook`)
that `approve`s + deposits into a fixed on-chain Depository is **not directly transferable**:
no equivalent EVM intent-deposit contract exists. An EVM hook would instead have to (a) call
an external bridge locker (Omni `initTransfer`) to move funds to the NEAR Verifier, or (b)
call the custodial 1Click REST API for a per-quote deposit address. Both shift trust to
bridge/MPC operators or a custodial agent, changing security, custody, finality, and refund
handling relative to Relay.

## Refuted claim (recorded for honesty)

- ✗ "EVM/cross-chain assets are moved to NEAR via a separate PoA bridge, **not via an EVM
  contract an integrator calls directly**." — Refuted 1-2. Bridge deposit flows *can* involve
  EVM-side contract calls (e.g. Omni locker); the accurate statement is that those calls are
  **bridge infrastructure, not a NEAR-Intents intent entry-point**.

## Sources (all primary unless noted)

- https://docs.near-intents.org/integration/verifier-contract/introduction
- https://docs.near-intents.org/near-intents/market-makers/verifier/introduction
- https://docs.near-intents.org/integration/bridging/overview
- https://docs.near-intents.org/near-intents/chain-address-support
- https://docs.near-intents.org/near-intents/integration/distribution-channels/1click-api
- https://docs.near-intents.org/near-intents/market-makers/bus
- https://docs.near.org/chain-abstraction/intents/overview
- https://docs.near.org/chain-abstraction/omnibridge/how-it-works
- https://github.com/near/intents
- https://github.com/defuse-protocol/near-intents-amm-solver
- https://github.com/Near-One/omni-bridge  (EVM addresses + `initTransfer` ABI)
- https://github.com/Near-One/bridge-sdk-js
- https://github.com/near-examples/near-intents-agent-example
- https://www.npmjs.com/package/@defuse-protocol/intents-sdk  (Deposits ❌ "Coming Soon")
- https://www.npmjs.com/package/@defuse-protocol/bridge-sdk
- https://github.com/hot-dao/omni-sdk
- (blog, non-load-bearing) leodex.io, bybit.com

## Caveats

- Deposit tooling is explicitly "Coming Soon" in the intents-SDK (README pushed 2026-08-11);
  a native/EVM-facing deposit surface could appear and **change the conclusion** — re-check
  the SDK before any build.
- The solver-relay WebSocket URL is a mutable default.
- Omni Bridge addresses are current as of the Aug 2026 main branch; bridges upgrade —
  verify on-chain before integrating.
- `eth.bridge.near` is historically Rainbow Bridge but is labeled Omni in the SDK; and the
  chain-support header says "16 EVM chains" while the scrape enumerated 15.
