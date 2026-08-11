# NEAR Intents Integration — Feasibility Spec

## Metadata
- Project: v2-core
- Milestone: N/A (bridge expansion evaluation)
- Linear Issue: N/A
- Research Date: 2026-08-11
- Re-verified: 2026-08-11 (trigger #1 still not fired; bridge trust analysis added)
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved
- Decision: **DEFERRED — do not build hooks yet** (see Re-evaluation Triggers)

## Summary

We evaluated NEAR Intents (formerly "Defuse") as a candidate bridge, the way we integrated Relay. **It is not a Relay-shaped integration.** Relay works because a source hook can `approve` + deposit into a fixed, per-chain on-chain `RelayDepository` contract with a stable ABI. NEAR Intents has **no equivalent EVM entry-point contract**: its canonical settlement contract (the "Verifier") is deployed **only on NEAR** at the account `intents.near` and behaves as an internal ledger. EVM funds reach it exclusively through **external bridges** (Omni Bridge, POA Bridge, HOT Bridge) — chosen by the protocol at withdrawal time and typically funded via **API-generated per-user deposit addresses** — or through the **custodial 1Click REST API**. Solver matching is off-chain over a WebSocket bus. Consequently the `RelayAdapter + RelaySendFundsAndExecuteOnDstHook` pattern does not transfer, and any EVM integration today would inherit either an MPC bridge's trust model or a custodial swapping agent, both materially weaker than a single audited on-chain depository.

This spec records the finding, the conditions that would reopen the decision, and a sketch of what an integration would require if those conditions are met. Full cited evidence is in `research/protocol-analysis.md`; the per-bridge trust/risk analysis (Omni/POA/HOT) is in `research/bridge-trust-analysis.md`.

**Re-verification (2026-08-11):** Trigger #1 has **not** fired — `@defuse-protocol/intents-sdk` v0.78.1 (published 2026-08-06) still marks Deposits ❌ "Coming Soon" ("use bridge interfaces directly"); no fixed-ABI EVM deposit contract has shipped. The deferral stands and is **reinforced** by the bridge analysis (below).

## Key Findings

1. **Settlement is NEAR-side.** The Verifier at `intents.near` is an internal balance ledger; intents settle atomically via `execute_intents`. No EVM deployment, no `0x` address. (high confidence, primary docs)
2. **No EVM intent entry-point contract exists** analogous to Relay's Depository (`0x4cD00E387622C35bDDB9b4c962C136462338BC31`). Funds enter/exit via external bridges through per-user deposit addresses; tokens are held NEAR-side as NEP-141 / NEP-245 representations. (high confidence, unanimous verification)
3. **Solver matching is off-chain** over a WebSocket Solver/Message Bus (`wss://solver-relay-v2.chaindefuser.com/ws`), not an on-chain EVM contract. Solver liquidity is custodied NEAR-side (`add_public_key` on `intents.near`). (high confidence)
4. **Three protocol-selected bridges** move funds: Omni Bridge (`omni_bridge`), POA Bridge (`poa_bridge`), HOT Bridge (`hot_bridge`), selected by destination chain. (high confidence)
5. **Nearest EVM-callable surface is the Omni Bridge locker** — a *separate* MPC bridge product, not the intents entry-point. `approve` + `initTransfer(address,uint128,uint128,uint128,string,string) payable`. Mainnet: Ethereum `0xe00c629aFaCCb0510995A2B95560E446A24c85B9`; Base/Arbitrum/Polygon `0xd025b38762B4A4E36F0Cde483b86CB13ea00D989`. Calling it is *not* "creating an intent." (high confidence)
6. **The official `@defuse-protocol/intents-sdk` does not implement deposits** ("Coming Soon"); deposit tooling is delegated to bridge SDKs. (high confidence)
7. **1Click is custodial** — a REST API that returns a per-quote deposit address by "temporarily transferring assets to a trusted swapping agent." Non-EOA vaults cannot cleanly use its deposit-address + off-chain refund flow. (high confidence)

## Why the adapter+hook pattern does not apply

| Dimension | Relay | NEAR Intents |
|---|---|---|
| EVM entry-point | Fixed `RelayDepository` ABI | None — bridge locker or custodial API |
| Source hook maps to | `approve` + on-chain `depositErc20/Native` | Call an MPC bridge, or off-chain 1Click |
| Trust locus | One audited on-chain contract | Weakest of {Omni, POA, HOT} MPC, or a custodial agent |
| Deposit target | Static per-chain address | Dynamic per-user / per-quote address |
| Refund/finality | On-chain, attributable to `depositor` | Off-chain bridge/agent-controlled |
| Adapter+hook reuse | Direct | Not directly applicable |

A source hook needs a stable target address and ABI to build an `Execution` against. NEAR Intents offers neither for the intent itself: the deposit address is minted per quote by an off-chain API, and the only stable on-chain ABI (Omni Bridge `initTransfer`) is bridge infrastructure whose semantics ("lock into MPC bridge") are not "route through NEAR Intents' solver market."

## Decision

**Deferred.** Integrating today would mean an EVM hook either (a) calls an MPC bridge locker — inheriting that bridge's signer-set risk rather than a single audited contract — or (b) routes through the custodial 1Click API, which a smart-account vault cannot safely drive (the agent controls the deposit address; custody and refunds are off-chain). Both are strictly worse than the Relay Depository trust model, for a protocol whose distinct value (broad chain + non-EVM reach, e.g. Bitcoin/Solana) we do not currently need over Across/deBridge/Relay.

## Bridge risk (reinforces the deferral)

Because there is no on-chain EVM entry-point, EVM funds cross via one of three bridges,
**selected per route** — so the integration inherits the trust model of the *weakest bridge on
the route taken*, not an average. Full analysis + citations in `research/bridge-trust-analysis.md`.

- **Omni Bridge** — MPC/TSS (NEAR Chain Signatures), strongest of the three, but a ~8–10-provider
  permissioned set at launch; inbound EVM→NEAR also depends on Wormhole validators (~960–1066s
  finality to Ethereum/Base/Arbitrum).
- **POA Bridge — the weakest link** — an explicit permissioned Proof-of-Authority set (Defuse
  Labs), no disclosed threshold/MPC/light-client, and the **default for the widest chain set**.
- **HOT Bridge** — threshold MPC-in-TEE (EverStake/NEAR/Aurora/HAPI); audited (ToB/Hacken/Veridise)
  but exact signer count/threshold undisclosed; client-driven, non-instant deposits.
- **Refunds are service-layer**, not on-chain (1Click `refundTo` + polling); no verified trustless
  on-chain refund if an operator/API goes offline mid-transfer.
- **Decisive gap:** EVM-side contract **admin keys / upgradeability / pause controls are
  undisclosed** for all three bridges — unquantified custody risk on every route.

Versus Relay (one audited Depository, on-chain `depositor`-attributed refunds), this is a strictly
larger and less legible attack surface.

## Re-evaluation Triggers

Reopen this decision if **any** of the following becomes true:

1. **A fixed-ABI EVM deposit contract ships.** The SDK's deposit support is marked "Coming Soon." If NEAR publishes a canonical, per-chain EVM contract with a stable `deposit(...)`-style ABI that routes into the Verifier, this becomes a Relay-shaped integration — re-scope immediately.
2. **A product need for NEAR-Intents-only reach** (native Bitcoin/Solana/NEAR settlement or its specific solver liquidity) that Across/deBridge/Relay cannot serve.
3. **1Click gains on-chain / non-custodial guarantees** (e.g., an escrow contract or insurance for the custody window) usable by a non-EOA caller.

## What an integration would require *if* Trigger #1 lands (sketch, non-binding)

- Vendor interface `INearIntentsDepository` (verified against the shipped contract), mirroring `IRelayDepository`.
- `NearIntentsSendFundsAndExecuteOnDstHook` + `ApproveAnd…` source hooks, patterned on the Relay hooks (approve-0/approve/deposit/approve-0, `usePrevHookAmount` chaining).
- Per-chain config gating identical to the Aave V3 / Relay depository pattern (`nearIntentsDepositories[chainId] != address(0)`), enabled only where deployed.
- Off-chain quote/intent construction owned by SuperBundler (analogous to Relay's `/quote` `txs[]` workstream), since intent payloads and solver coordination are off-chain.
- Explicit non-goals: the custodial 1Click path and direct MPC-bridge-locker calls are **out of scope** as intent entry-points.

## Open Questions

- When native deposit support lands, will it expose an EVM-contract-callable entry-point (fixed ABI a hook can call), or remain API/deposit-address-based? This single fact determines feasibility.
- Per-bridge finality/latency and failure-refund guarantees (Omni vs POA vs HOT) for the EVM→NEAR→EVM round trip, and how they surface to an on-chain caller vs the off-chain 1Click status API.
- Each bridge's trust model (MPC signer set / validator assumptions / audits) — an EVM integration inherits the weakest bridge's risk, not a single audited depository.

## Caveats (fast-moving)

- SDK README was updated 2026-08-11; deposit tooling status can change — re-check before any build.
- The solver-relay WebSocket URL is a mutable default.
- Omni Bridge addresses are current as of the Aug 2026 `Near-One/omni-bridge` main branch; verify on-chain before any use.
