# Superform v2-Contracts

This document provides technical details, reasoning behind design choices, and discussion of potential edge cases and
risks in Superform's v2-contracts.

## Overview

SuperformV2 is a chain abstracted DeFi protocol that emphasizes flexibility and composability. The protocol implements a
modular architecture that allows dynamic execution and flexible composition of user operations (userOps). This
repository contains the smart contracts powering Superform v2, including core execution logic and advanced account
abstraction via ERC7579 modules.

At a high level, Superform v2 is organized into two major parts:

- Core Contracts: These include the primary business logic, interfaces, execution routines and accounting mechanisms
- Periphery Contracts: These include a suite of products built on top of the core contracts, such as SuperVaults.

## Key Components

- Hooks: Lightweight, modular contracts that perform specific operations (e.g., token approvals, transfers) during an
  execution flow.
- SuperExecutor: Sequentially executes one or more hooks, manages transient state storage for intermediate state, and
  interacts with the SuperLedger for accounting.
- SuperLedger: Handles accounting aspects (pricing, fees) for both INFLOW and OUTFLOW hooks. These fees are taken by
  Superform.
- RBAC & SuperRegistry: Provide robust role-based access control and centralized address management for configuration
  and upgradeability.
- SuperBundler: A specialized off-chain bundler that processes ERC4337 userOps on a timed basis. It also integrates with
  a validation system (SuperMerkleValidator) to ensure secure operation.
- SuperVault: A ERC7540 compliant vault capable of allocating an asset to various yield sources using hooks and allowing
  strategists to optimize the performance of the vault.

### Repository Structure

```
src/
├── core/               # Core protocol contracts
│   ├── accounting/     # Accounting logic
│   ├── bridges/        # Bridge implementations
│   ├── executors/      # Execution logic contracts
│   ├── hooks/          # Protocol hooks
│   ├── interfaces/     # Contract interfaces
│   ├── libraries/      # Shared libraries
│   ├── paymaster/      # Native paymaster
│   ├── settings/       # Protocol settings
│   ├── utils/          # Utility contracts
│   └── validators/     # Validation contracts
└── periphery/         # Peripheral contracts such as SuperVaults
```

## Development Setup

### Prerequisites

- Foundry
- Node.js
- Git

### Installation

Clone the repository with submodules:

```bash
git clone --recursive https://github.com/superform-xyz/v2-contracts
cd v2-contracts
```

Install dependencies:

```bash
forge install
```

Copy the environment file:

```bash
cp .env.example .env
```

### Building & Testing

Build:

```bash
forge build
```

If forge build fails:

```bash
cd lib/modulekit
pnpm install
```

Note: This requires pnpm and will not work with npm. Install it using:

```bash
curl -fsSL https://get.pnpm.io/install.sh | sh -
```

### Testing

Supply your RPCS directly in the makefile and then

```bash
make ftest
```

## Technical Architecture & Concepts

### Core Components

#### Hooks

Definition & Role: Hooks are small, modular components that are triggered during various phases of an operation. They
encapsulate specific logic (for example, token approvals or transfers) and are integrated into the overall transaction
flow. If any hook fails, the entire transaction is reverted, ensuring atomicity.

Key Points for Auditors:

- Modularity & Ordering: Hooks can be arranged in any order within a user operation. Their execution order is defined by
  the build function of the SuperExecutor.
- Pre/Post Execution: Each hook can have pre-execution and post-execution functions. These functions update internal
  transient storage to maintain state between hook invocations.
- Known Considerations:
  - Complex interdependencies may arise if hooks are misconfigured.
  - Failure handling is strict (reverting the entire operation on a specific hook failure).
  - All hooks are executed within the smart account context. This is why many typical checks such as in superform v1 can
    be removed, because the assumption is that the user will agree to the ordering and the type of hooks provided and
    this choice will solely affect his account and not the entire system, such as in superform v1.
  - There is a HooksRegistry which essentially tells if a Hook is a considered a core hook or not (valid for SuperVaults
    execution). However anyone can create a hook including a malicious one. Users select which hooks to use, but
    ultimately it is up to the SuperBundler to provide the correct suggestions for users in the majority of the cases.
    More considerations on this in the SuperBundler section.

#### SuperExecutor

The SuperExecutor is responsible for executing the provided hooks, invoking pre- and post-execute functions to handle
transient state updates and ensuring that the operation's logic is correctly sequenced.

Key Points for Auditors:

- Inheritance: Inherits from ERC7579ExecutorBase to facilitate deployment on ERC7579 smart accounts.
- Accounting Integration: After hook execution, it checks hook types and calls updateAccounting on the SuperLedger when
  required.

#### Transient Storage Mechanism

Transient storage is used during the execution of a SuperExecutor transaction to temporarily hold state changes. This
mechanism allows efficient inter-hook communication without incurring high gas costs associated with permanent storage
writes.

Key Points for Auditors:

- Gas Efficiency:
  - Uses temporary, in-memory storage to avoid high SSTORE costs (5,000–20,000 gas).
- Limitations:
  - Only value types can be stored.
- Debugging is more challenging because intermediate states aren't persistently recorded.
- Design Rationale:
  - The trade-off is acceptable as it minimizes gas cost without impacting the integrity of the final state.

#### SuperLedger & Accounting

Definition & Role: The SuperLedger's implementations handles the accounting aspects of the protocol. It ensures accurate
pricing and accounting for INFLOW and OUTFLOW type hooks. The system uses a dedicated on-chain oracle system
(YieldSourceOracles) to compute the price per share for accounting.

Key Points for Auditors:

- Oracle-Based Pricing:
  - The YieldSourceOracle derives price-per-share and other relevant metadata (for off-chain purposes) for yield
    sources.
  - Hooks are passed the yieldSourceOracleId to use. It is up for the SuperBundler to suggest / enforce the correct
    yieldSourceOracleIds to use, but nothing impedes a user to pass their own yieldSourceOracleId in a hook and bypass the fee.
    This is known and accepted.
- Multiple yield source oracle and ledger implementation system:
  - Provide more flexibility to adapt to yield source types that have special needs do determine fees for Superform
    (such as Pendle's EIP5115)
  - Risks may exist if the yield source oracles provide incorrect data, which may lead to no fees being taken by
    Superform.
  - It is also important to assess if a user can ever be denied of exiting a position (due to a revert) in a certain
    state due to influences on the price per share accounting and the SuperLedger used for that yield source.
  - SuperBundler will enforce the yieldSourceOracleId to use whenever a user interacts with Superform app or API. Otherwise 
  this cannot be enforced. Each yieldSourceOracle is paired with a ledger contract which users can also specify when configuring
  the yieldSourceOracle. This is a known risk for users (fully isolated to the user's account) if not interacting through the Superform app and API and acknowledged by the team.

#### SuperOracle

Definition & Role: SuperOracle is a specialized on-chain oracle system that provides USD price information for various
assets (bases) using https://eips.ethereum.org/EIPS/eip-7726

Key Points for Auditors:

- Allows for a provider to be passed encoded in the quote to the oracle.
- Only USD as a quote is accepted (using ISO convention)
- Callees can provide provider 0 to get the average of all providers
- Important for the get functions of YieldSourceOracles that translate metadata, such as PPS and TVL, to USD terms. Can
  be used on-chain in future contracts.
- Risk Considerations (typical oracle risks):
  - Oracle manipulation risks must be considered
  - Price staleness checks should be implemented
  - Failure modes should gracefully handle oracle unavailability

#### Bridges

Definition & Role: This is a set of gateway contracts that handle the acceptance of relayed messages and trigger userOp
execution on destination chains.

Key Points for Auditors:

- Relayed message handling:
  - Both bridges expect the full intent amount to be available to continue execution on destinaton
  - The last relay to happen continues the operation
- Known and accepted cases:
  - Failure of a relay:
    - It is entirely possible for a relay to fail due to a lack of a fill by a solver. In these types of cases, the
      funds remain on source. Any funds that were relayed successfully will remain on destination and won't be bridged
      back. The assumption for the operation mode is chain abstraction/one balance, so it shouldn't matter for the user
      where the funds land.
  - Slippage loss due to bridging:
    - The user accepts the conditions the solver providers to execute the operations. All subsequent operations on
      destination are dependent on the actual value provided by the relayer. It is accepted that if the valued filled is
      substantially lower, execution continues anyway with the chained hooks (using the context awareness) and the users
      acknowledges this risk.
- Things to watch for:
  - Cancellation Scenarios:
    - User cancellations during pending bridge operations
    - Refund mechanisms when operations fail

#### SuperNativePaymaster

Definition & Role: SuperNativePaymaster is a specialized paymaster contract that wraps around the ERC4337 EntryPoint,
enabling users to pay for operations using native tokens. It's primarily used by SuperBundler for gas abstraction.

Key Points for Auditors:

- Gas Management:
  - Native token conversion for gas payments
  - Gas estimation and pricing mechanisms
  - Refund handling for unused gas
- Integration Points:
  - EntryPoint interaction patterns
  - SuperBundler dependencies
  - Failure recovery mechanisms
- Security Considerations:
  - DOS prevention
  - Gas price manipulation protection
  - Fund safety during conversions

#### SuperMerkleValidator

Definition & Role: SuperMerkleValidator is used by SuperBundler to validate operations through Merkle proof
verification. It ensures that only authorized operations are executed within the system.

Key Points for Auditors:

- Validation Process:
  - Merkle proof verification methodology
  - Validation failure handling
- Security Considerations:
  - Proof verification robustness
  - Replay attack prevention

#### SuperRegistry

SuperRegistry Definition & Role: The SuperRegistry centralizes the management of contract addresses. By using unique
identifiers, it avoids hardcoding and facilitates upgrades and modularity across the protocol. Also provides role-based access control for the protocol. It defines
roles (as bytes32 identifiers) for various operational functions such as configuration, execution, and system
monitoring.

Key Roles:

- HOOKS_MANAGER: Can add / remove hooks from the HooksRegistry and add / remove router for 1inch and Odos hooks

Key Points for Auditors:

- Modularity & Upgradeability:
  - Stores addresses for Executors, RBAC, SuperPositions, Sentinels, Bridges, and shared storage.
- Risks:
  - Misconfiguration or unauthorized modifications could lead to vulnerabilities. Proper governance around the registry
    is critical.

### Periphery Components

#### SuperVaults

Definition & Role: SuperVaults are ERC7540-compliant vaults that enable users to deposit and withdraw assets across
multiple yield sources. They implement sophisticated allocation strategies and reward mechanisms.

Key Features:

1. Yield Source Management:

   - Dynamic configuration of yield sources
   - Caps and thresholds for risk management
   - Timelock for yield source additions

2. Request Processing:

   - Deposit and withdrawal request queuing
   - Batch fulfillment by strategists
   - Request matching for gas optimization

3. Allocation Management:

   - Flexible allocation strategies
   - Hook-based execution
   - Constraint enforcement (caps, thresholds)

4. Reward Mechanisms:
   - Claim and compound functionality
   - Token swapping capabilities

Key Points for Auditors:

- State Management:
  - Request queue integrity
  - Share accounting accuracy
  - Asset tracking precision
- Security Considerations:
  - Access control implementation
  - Emergency controls
  - Hook validation
- Important cases to watch for:
  - Fee calculation accuracy
  - Rebalance accuracy
  - Guardrails to protect users/strategists against bad underlying vaults. Are they enough?
  - Unique logic around matchRequests functionality, which will have high importance to reduce gas costs to fulfill requests in Coindidence of Wants format.
  - Ensure all the above is secure in light of the existence of the escrow contract

Factory Implementation:

- Proxy pattern for gas efficiency
- Configurable parameters for new vaults
- Security measures for initialization

## SuperBundler & Account Abstraction

### SuperBundler Overview

SuperBundler is a specialized component that handles the bundling of ERC4337 userOps. Unlike typical bundlers that
immediately forward userOps, SuperBundler processes them in a timed manner, allowing for batching and optimized
execution.

Bundler Operation

- Timed Processing:
  - UserOps are processed when and where required rather than immediately upon receipt.
- Centralization Concerns:
  - Since SuperBundler controls both the userOp and validation flow, it introduces a degree of centralization. We
    acknowledge that this could be flagged by auditors.
- Mitigation: Transparency around this design choice and the availability of fallback mechanisms when operations are not
  executed through SuperBundler.

### Module Installation & Account Bootstrapping

Smart accounts that interact with Superform must install two essential ERC7579 modules:

- SuperExecutor:
  - Installs hooks and executes operations.
- SuperMerkleValidator:
  - Validates userOps against a Merkle root.
- Additional Modules:
  - Rhinestone Resource Lock Module: Used for cross-chain resource locking.
  - Rhinestone Target Executor: Executes userOps on destination chains, bypassing the entry point flow.

## Edge Cases & Known Issues

To ensure transparency and facilitate the audit process, the following points outline known issues and potential edge
cases: In an effort to preemptively address concerns that auditors might raise, we outline the following known edge
cases and limitations:

SuperBundler Centralization: 
- Risk:
  - Since SuperBundler manages both the bundling and validation of userOps, it can be seen as a centralized component. 
- Mitigation:
  - The v2-contracts design incorporates fallback paths if operations are submitted outside of SuperBundler.
  - All SuperBundler can do is execute indicated user operations, no possibilities of malicious injection. Will be submitted
  to a separate audit.

Execution Outside SuperBundler: 
- Risk:
  - If userOps are executed directly (not via SuperBundler), certain optimizations and checks might be
    bypassed. 
- Mitigation:
  - Our modules are designed to handle direct execution gracefully, but users and integrators are advised to follow best
    practices outlined in the documentation and interact via Superform app.

Inter-Hook Dependencies: 
- Risk:
  - Misordering or misconfiguration of hooks can lead to unintended state changes. 
- Mitigation:
  - The SuperExecutor's design ensures that hooks update and pass transient data in a controlled manner, with reversion on
  error to preserve state integrity.

SuperLedger Funds Separation: 
- Risk:
  - Right now assets obtained to fulfill redeem requests remain in the SuperVaultStrategy and contribute temporarily to the PPS/totalAssets. However they must not be used for fulfillDepositRequests as they are meant to be given to users who have already claimed
- Mitigation:
  - Separate these assets into a new Escrow Assets contract for users to claim?

SuperLedger Accounting: 
- Risk:
  - Any edge cases where users could be locked into a position?
  - Small rounding errors in fee calculations could be exploited over time to reduce fee paid?
- Mitigation:
  - Regarding fee loss, a small loss due to rounding is accepted.
  - Regarding being locked into a position, in serious problems with the core each yieldSourceOracle configured in SuperLedgerConfiguration can be set with a feePercent of 0 to allow users to skip the accounting calculation on exit. Aditionally, the yieldSourceOracleId can be configured to use a new ledger
  contract.

SuperExecutor module: 
- Risk:
  - Users could execute hooks by their own, without go through the SuperBundler. This could lead to an avoidance of the validator module. However, this would affect only the user and not the protocol as each action is executed in the context of the user's account. 
- Mitigation:
  - For extra safety, should we deny `target` as SuperExecutor for each hook?
