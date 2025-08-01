# Security Policy
This section outlines the security policy and known limitations of the Superform V2 core protocol.

## Known Issues
The protocol includes a few accepted trade-offs and architectural decisions that integrators and users should be aware of and handle accordingly.

#### 1. Cross-Bridge replay attack
There is a low-likelihood scenario where a user's signed bridging intent may still be executed on the destination chain even after it has been canceled on the source chain.

**Prerequisites:** 

The user must still have sufficient balance on their smart account on the destination chain.

A working proof-of-concept for this issue is available in the [test/integration/attacks](./test/integration/attacks/CrossBridgeReplayAfterCancellation.t.sol) directory.

#### 2. Marking root as processed
The process of marking a root as processed is susceptible to front-running. While mitigations are in place, it may not cover all edge cases.

#### 3. Assumption of a static system
Superform assumes the system remains static between the time a user signs an intent and its execution. If key components (e.g., smart account configuration or target contracts) change during this period, it may result in unexpected behavior.

Users accept this trade-off when using the protocol.

#### 4. Hook safety assumptions
Hooks are external contracts and may not always be trustworthy. Interacting with unverified or malicious hooks can compromise user funds. Superform does not guarantee the safety of custom or third-party hooks.

#### 5. Limited ERC-7579 compatibility
Superform is tested and optimized for Nexus and Safe smart accounts. Other ERC-7579-compatible smart accounts may not function as intended and should be used with caution.

#### 6. Partial EIP 1271 compatibility
The protocol uses a fixed chain ID to enable a single signature for cross-chain execution. This makes it partially non-compliant with EIP-1271 in certain contexts.

#### 7. Cost basis caching
Superform uses a cached cost basis when a user's smart account withdraws directly from a vault. This is intended behavior. Any unpaid fees will be recovered from future interactions.

#### 8. Oracle dependency
Superform relies on vaults exposing accurate `convertToAssets()` and related functions for pricing. Misconfigured or non-compliant vaults may lead to issues such as failed deposits or withdrawals. Proper integration is essential to avoid disruptions.

#### 9. Fee skipping
There are multiple edge cases where protocol fees may be bypassed. While this is an accepted trade-off, it should be noted when designing or integrating with the system.

#### 10. One leaf per destination limitation
The destination executor supports only one leaf per destination in the Merkle root. Signing multiple leaves for the same destination may cause race conditions. While this is not expected to result in fund loss, it can cause execution conflicts.

#### 11. Infinite deadline transactions
The protocol allows signatures with no expiration. While convenient, these signatures can pose risks in certain operational contexts and should be used carefully.

#### 12. Multiple valid execution paths
Once an intent is signed, there are several valid methods to execute it — even in cases where the associated bridge transaction has not completed successfully. This provides flexibility but requires careful handling by integrators to avoid unintended consequences.








