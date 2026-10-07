# Security Policy
This section outlines the security policy and known limitations of the Superform v2 core protocol.

## Known Issues
The protocol includes a few accepted trade-offs and architectural decisions that integrators and users should be aware of and handle accordingly.

#### 1. Cross-Bridge replay attack
There is a low-likelihood scenario where a user's signed bridging intent may still be executed on the destination chain even after it has been canceled on the source chain.

Given the user must still have sufficient balance on their smart account on the destination chain, this is deemed to be a non-issue as it suffices to better UX and intended behavior to simplify core actions.

#### 2. Marking root as processed
The process of marking a root as processed is susceptible to front-running. While mitigations are in place, it may not cover all edge cases.

#### 3. Assumption of a static system
Superform assumes the system remains static between the time a user signs an intent and its execution. If key components (e.g., smart account configuration or target contracts) change during this period, it may result in unexpected behavior.

Users accept this trade-off when using the protocol.

#### 4. Hook safety assumptions
Hooks are external contracts and may not always be trustworthy. Interacting with unverified or malicious hooks can compromise user funds. Superform does not guarantee the safety of custom or third-party hooks.

#### 5. Limited ERC-7579 compatibility
Superform is tested and optimized for Nexus and Safe smart accounts. Other ERC-7579-compatible smart accounts may not function as intended and should be used with caution.

#### 6. Cost basis caching
Superform uses a cached cost basis when a user's smart account withdraws directly from a vault. This is intended behavior. 

#### 7. Vault integration dependencies
Superform relies on vaults exposing accurate functions for pricing, like `convertToAssets()` in ERC-4626. Misconfigured or non-compliant vaults may lead to issues such as failed deposits or withdrawals. For vaults with timelocks, special hooks must be used before normal actions. Proper integration is essential to avoid disruptions.

#### 8. Fee skipping
There are multiple edge cases where protocol fees may be bypassed. While this is an accepted trade-off, it should be noted when designing or integrating with the system.

#### 9. One leaf per destination limitation
The destination executor supports only one leaf per destination in the Merkle root. Signing multiple leaves for the same destination may cause race conditions. While this is not expected to result in fund loss, it can cause execution conflicts.

#### 10. Infinite deadline transactions
The protocol allows signatures with no expiration. While convenient, these signatures can pose risks in certain operational contexts and should be used carefully.

#### 11. Multiple valid execution paths
Once an intent is signed, there are several valid methods to execute it, even in cases where the associated bridge transaction has not completed successfully. This provides flexibility but requires careful handling by integrators to avoid unintended consequences.

#### 12. Token decimals
Superform's yield sources and oracle calculations are designed with ERC-20 assets that use up to 18 decimals of precision in mind. Yield source assets with more than 18 decimals are considered non-standard and unsupported.

#### 13. Relay fill liveness and off-chain refunds
Relay Protocol deposits (RelaySendFundsAndExecuteOnDstHook / ApproveAndRelaySendFundsAndExecuteOnDstHook) are escrowed in Relay's depository, which has no user-side on-chain withdrawal or cancellation function. If no solver fills an order, the refund is performed by Relay's solver on the origin chain and attested by Relay's off-chain Oracle/Allocator stack. Execution safety of user funds on the destination remains anchored in Superform's destination signature and balance validation; Relay's trust stack affects liveness only. This is the same trust class as Across/deBridge relayer fill liveness.

#### 14. RelayAdapter atomic-batch assumption
The RelayAdapter is permissionless (Relay has no authenticatable destination caller). Its received-funds guard and escrow accounting prevent phantom failed-transfer credits and cross-user escrow sweeps. However, funds parked in the adapter between two separate solver transactions — a deviation from Relay's atomic txs[] batching (allowFailure = false) — are forwardable by any caller presenting a validly-signed message for their own account until the legitimate second leg lands. The SuperBundler must always request fund delivery and the adapter call as one atomic batch.
#### 15. Identity-PPS oracles must keep feePercent = 0

Identity-PPS yield-source oracles are registered with feePercent = 0. Three of them override
`getAssetOutputWithFees` to bypass the fee view on-chain: `AaveV4ReserveOracle`,
`ERC20YieldSourceOracle` and `MorphoBlueDebtOracle`.
`EulerDebtOracle` does NOT — it carries the invariant in NatSpec only ("Neither is guarded
on-chain here"), so it depends entirely on configuration; a fee-bypass backport is a candidate
hardening PR. In every case the ledger accounting path (`BaseLedger._processOutflow`) computes
fees directly from `SuperLedgerConfiguration` and is not guarded by the oracle. Because no hook
snapshots cost basis for these positions, any configured fee taxes principal as profit; pairing
such an oracle with `FlatFeeLedger` fees the full principal on every outflow. Operational
invariant: these oracle ids are registered with feePercent = 0 or not registered at all, and
never with FlatFeeLedger — this covers `AaveV4ReserveOracle` explicitly, whose registration is
asymmetric by leg. Its oracle id MUST be registered at feePercent = 0 if the idle MONEY_MARKET pair is ever
driven. NOTE THE KEY: since SUP-21254 the key that pair posts under is the MARKET key, not the SUPPLY reserve
key (the oracle resolves the former to the latter). The fee wiring is by `yieldSourceOracleId`, not by key, so
the rule is unchanged in substance — only the noun moved: `AaveV4LendHook` is `HookType.INFLOW` and `AaveV4RedeemHook` is
`HookType.OUTFLOW`, and `SuperExecutorBase` reverts `MANAGER_NOT_SET` for those hooks unless the
header's yieldSourceOracleId resolves to a configured oracle. Its DEBT keys must never be
ledger-wired at all (every LOAN hook is NONACCOUNTING). Today no Aave V4 oracleId is configured
anywhere in the deploy path, so the idle pair would revert if driven — a pre-existing gap, not a
property to rely on.
Second invariant, for every registry-keyed family: **never register the supply-side and debt-side
oracle ids of the SAME registry key against the same ledger.** `BaseLedger` accumulators are keyed
`(user, yieldSource)` with no oracle-id component, so the two legs of one position sum into a
single accumulator slot. Use one ledger per side, or register only the side being accounted.
This still applies to **Morpho Blue**, whose `MorphoBlueMarketRegistry` key is side-agnostic and
whose two legs therefore share a key. It no longer applies to **Aave V4**: `AaveV4ReserveRegistry`
binds a `Side` into the key preimage (supply keeps the legacy two-word derivation; debt is
`keccak256(abi.encode(spoke, reserveId, DEBT_KEY_DOMAIN))`), so the legs are distinct
`yieldSource` values and cannot share an accumulator slot even on one ledger. That separation is
structural, not operational — it is what lets a single `AaveV4ReserveOracle` serve both legs
through the sideless `IYieldSourceOracle` surface the `SuperYieldSourceOracle` aggregator calls. For ERC20YieldSourceOracle specifically, whoever whitelists a token as
a SuperVault yield source owns its due diligence: single canonical entry point (double-entry
tokens would be double-counted by off-chain pricing), no rebasing/fee-on-transfer mechanics with
the corporate-action convention pinned per token and confirmed with the issuer in writing (the
off-chain price feed must match that convention — balance rebase vs total-return multiplier vs
airdrops), the token's upgrade surface monitored (BSC B-tokens are BeaconProxies sharing a
single beacon, so one beacon upgrade swaps balanceOf/decimals semantics for the whole family —
monitor the beacon's implementation, not the token's EIP-1967 slot, which is empty),
blocklist/pause semantics understood, donations accounted for (balanceOf includes unsolicited
transfers; off-chain pricing should reconcile balance deltas against executed flows), decimals
<= 18, and `getTVL` (global totalSupply) never used as a pricing input.

#### 16. Aave V4 market keys: intent identity for LOAN, and the ledger key for the idle pair

`AaveV4ReserveRegistryV2` holds TWO key namespaces (SUP-21239), kept disjoint as *storage* by
`KEY_NAMESPACE_COLLISION` on all three write paths, and crossed by the oracle in exactly ONE direction
(SUP-21255):

- **NAV / accounting** — `computeReserveKey(spoke, reserveId)` (SUPPLY) and
  `computeDebtKey(spoke, reserveId)` (DEBT), stored in `_reserves`. Every per-leg NAV read is keyed by these.
- **Market** — `computeMarketKey(spoke, supplyReserveId, borrowReserveId)`, stored in `_markets`. This is the
  header `yieldSource` of the six V2 LOAN hooks AND, since SUP-21254, of the idle `AaveV4LendHook` /
  `AaveV4RedeemHook` pair. It is therefore what merkle leaves, the vault whitelist and off-chain indexing
  name.

Who reads it, precisely — the distinction that matters:

- For the **six V2 LOAN hooks** the market key is intent identity only. They are `NONACCOUNTING`, so
  `SuperExecutorBase._updateAccounting` never reads their header and a market key is never a SuperLedger key
  for them.
- For the **idle pair** the market key IS the SuperLedger key and an oracle argument: lend is INFLOW, redeem
  is OUTFLOW. `AaveV4ReserveOracle` resolves the market key to that market's COLLATERAL leg, which the idle
  decoder guarantees is the reserve the op actually moved (one calldata word feeds both `computeMarketKey`'s
  supply slot and the Spoke call). Two consequences: an UNREGISTERED market reverts the whole userOp, so the
  accounting allowlist is market-granular; and the ops invariant in item 3 below is what keeps one ledger key
  per idle position.

Operational invariants:

1. **A market key resolves ONE-DIRECTIONALLY, to the collateral leg only** (SUP-21255). Aave V4 positions
   are reserve-granular — `getUserSuppliedAssets(reserveId, owner)` takes no market parameter — so one
   reserve participates in N markets. Collateral reserves differ per market, so resolving a market key to
   its COLLATERAL leg is summable and is what the sideless `IYieldSourceOracle` reads return. The DEBT leg
   must stay unreachable from a market key: on the live Base MAG7 spoke all seven equity markets borrow the
   one USDC reserve, so market-keyed debt would report the same liability seven times, and nothing in the
   aggregator de-duplicates by underlying position. `getMarketPosition` returns both legs raw and un-netted
   for a caller that prices them; `getOwnerSnapshot` is the portfolio path and de-duplicates legs across the
   whole requested set (SUP-21256). Independent per-market reads must never be summed into a portfolio.
   This is also why Morpho Blue's side-agnostic market key is NOT a template here: Morpho stores
   `position[marketId][user]`, so the market IS its accounting unit. Aave V4's is the reserve.
   TWO RESIDUAL RULES: (a) two markets sharing a COLLATERAL reserve resolve to the same leg, so summing
   their sideless reads double counts — use the snapshot; (b) a market key is still never a SuperLedger key
   for a LOAN hook, because those hooks are NONACCOUNTING.
2. **Market registration gates execution for the idle pair, and NOT for the LOAN hooks.** No Aave V4 hook
   calls the registry; they only pin that the header equals the market key of the body. But because the idle
   pair is INFLOW / OUTFLOW, its accounting read resolves the header through the oracle, so an unregistered
   market reverts the userOp — a real, if indirect, gate. The LOAN hooks have no such gate: registering a
   market merely records its binding for off-chain consumers, and deciding which markets a vault may touch
   remains an off-chain whitelist decision.
3. **Removal order is markets, then reserve legs — and a market with a live idle position must not be
   removed at all.** A market claims exactly two of its two reserves' four legs — the collateral reserve's
   SUPPLY leg and the loan reserve's DEBT leg — and `marketRefs` refuses to deregister either while the
   market lives (`MARKET_REFERENCES_RESERVE`). Symmetrically, a leg with a pending deregistration cannot be
   claimed by a new market (`RESERVE_DEREGISTRATION_PENDING`), so the two timelocks never overlap. Taking a
   claimed leg dark would abort whole-batch reads in `getPricePerShareMultiple` / `getTVLMultiple` (which,
   unlike `getTVLByOwnerOfSharesMultiple`, DO isolate per entry).
   **UNGUARDED, OPS-ENFORCED (SUP-21254):** deregistering a market under which an account still holds an open
   IDLE position bricks that account's redeem through Superform accounting — the oracle reverts
   `RESERVE_NOT_REGISTERED` inside `_updateAccounting`, and the only exit is calling the Spoke directly,
   outside the ledger. The registry cannot see user positions, so there is no `marketRefs` analogue for this
   direction. Before proposing such a market, confirm `getBalanceOfOwner(marketKey, account)` and
   `usersAccumulatorShares(account, marketKey)` are zero for every holder; the 2-day timelock is the window
   to check in.
4. **ONE market per idle-lendable reserve: `marketRefs[computeReserveKey(spoke, supplyReserveId)] <= 1`.**
   NOT enforced on-chain — `registerMarket` will accept `(R, 0)`, `(R, 1)`, `(R, 2)` and the idle hooks
   accept any of them, giving reserve R's single idle position one ledger key per such market. `BaseLedger`
   accumulators are keyed `(user, yieldSource)` with no oracle id, so lending under one and redeeming under
   another caps `usedShares` to zero (`UsedSharesCapped`): a permanently stale accumulator, a NAV double
   count for anyone summing both keys, and a performance-fee bypass the day the `feePercent = 0` invariant in
   item 15 stops holding.
   **WHERE IT IS ACTUALLY ENFORCED, precisely.** `ConfigureAaveV4ReserveRegistry` rejects a second supply
   claim with `COLLATERAL_LEG_CLAIMED_TWICE` in three places: when registering a market
   (`_registerOneMarket`, including its already-registered branch, so a re-run cannot inherit an ambiguity),
   in `configureAll`'s final gate over every listed reserve, and in `runCheckAll`, which prints the offending
   reserves and then fails. That is a **script-level** guard: it covers this configuration process and an
   audit of its result, and it does NOT constrain a manager who calls `registerMarket` on the registry
   directly. Only the SUPPLY leg is constrained — the loan reserve's DEBT leg is shared by design (all seven
   Base equity markets borrow the one USDC reserve, refcount 7).
   The by-construction fix, if this needs to be structural, is a registry flag marking a market as the
   idle-supply market for its collateral reserve and refusing a second one; it is not taken today because it
   means redeploying and re-seeding a registry that is already live and configured.
5. **Off-chain consumers must key on `(chainId, marketKey)`.** Like the two leg derivations, the market
   preimage contains no chainId, and Aave V4 spoke addresses are not guaranteed chain-unique. On-chain this
   is harmless — the pin is evaluated on the executing chain and the signed envelope binds chainId — but any
   consumer keying a whitelist or an index on the bare 20 bytes would conflate two chains' markets.
6. **`getOwnerSnapshot` discovery is SYMMETRIC, and strict about what it cannot resolve** (SUP-21259).
   Debt is discovered by scanning every reserve of every covered spoke; supply used to arrive ONLY through
   the requested market bindings. That asymmetry meant removing the last market naming a supply reserve
   dropped its collateral from NAV while its debt kept being counted — PPS falls, or a negative-NAV guard
   rejects a snapshot that is merely incomplete. Collateral no requested market accounts for is now returned
   as its own SUPPLY-leg position, and when that leg is NOT registered the whole call reverts
   `UNCOVERED_COLLATERAL(spoke, reserveId)`: never silently omitted, never resolved through an unregistered
   key. Dedup is unchanged — a leg a requested market already contributed is not added twice.
   **COVERAGE BOUNDARY, so it is not over-read:** this protects a snapshot WHEN IT IS REQUESTED. A consumer
   whose strategy lists no Aave source at all requests no Aave snapshot, so complete-removal coverage stays a
   manager/lifecycle guarantee. Cost: one extra `getUserSuppliedAssets` staticcall per reserve per covered
   spoke, taken unconditionally because a plain idle supply reads `(false, false)` from
   `getUserReserveStatus` and would otherwise be invisible.
7. **The derivation is frozen and its leg order is significant.**
   `keccak256(abi.encode(spoke, supplyReserveId, borrowReserveId, MARKET_KEY_DOMAIN))`, lower 20 bytes. The
   ids are never sorted: "collateral A, borrow B" and "collateral B, borrow A" are different strategies and
   must stay different keys. `MARKET_KEY_DOMAIN` cannot change once any market key has been signed into a
   root.
