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

Identity-PPS yield-source oracles (EulerDebtOracle, ERC20YieldSourceOracle, and family) bypass
the fee view on-chain, but the ledger accounting path (`BaseLedger._processOutflow`) computes
fees directly from `SuperLedgerConfiguration` and is not guarded by the oracle. Because no hook
snapshots cost basis for these positions, any configured fee taxes principal as profit; pairing
such an oracle with `FlatFeeLedger` fees the full principal on every outflow. Operational
invariant: these oracle ids are registered with feePercent = 0 or not registered at all, and
never with FlatFeeLedger. For ERC20YieldSourceOracle specifically, whoever whitelists a token as
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
