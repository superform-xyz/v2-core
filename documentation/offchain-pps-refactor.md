# Refactor PRD: Off-Chain PPS for SuperVaults

## Goal and Overview

We want to **refactor** the existing on-chain price-per-share (PPS) logic in SuperVaults so that **all PPS calculations happen optimistically off-chain**. A **strategist** (vault manager) periodically **reports** a new PPS in the contract, which we use in deposit/withdraw flows. This PPS is accepted *optimistically* unless someone disputes it. If there is a dispute, the system can run a **reference calculation** (similar to the old Approach 1 logic) *only* once needed (rather than on every block).

Strategists must **stake** protocol tokens (e.g., \$UP) to be allowed to post PPS. A **challenger** who suspects fraud can raise a dispute by also staking. If the dispute adjudication system off-chain check proves the strategist’s PPS was wrong beyond a tolerance, the strategist is **slashed**. Otherwise, the challenger loses their stake (discouraging spam). Through this mechanism, we preserve trust and correctness over time while **lowering on-chain gas** for routine operations.

### Key Differences from the Original On-Chain PPS
1. **Off-Chain PPS Calculation**  
   - Previously, we calculated `totalAssets()` or price-per-share on-chain every time. Now the strategist just publishes the updated PPS, and user deposits/withdrawals consume that number in O(1) operations.
2. **New “Dispute” Mechanism**  
   - If the posted PPS is suspected to be wrong, a dispute can trigger the PPS python reference calculation. If the strategist’s posted PPS is indeed incorrect beyond a threshold, the system slashes the strategist’s stake
3. **Strategist Staking and Reputation**  
   - Only addresses meeting KYC/Reputation criteria (off-chain or governed by some identity contract) will be allowed to become strategists. They must deposit a certain stake of \$UP tokens into a staking contract. This stake is subject to slashing in the event of fraud.
4. **Circuit Breakers / Rate Limits**  
   - The contract can enforce certain bounds on how far the new PPS can deviate from the old PPS (e.g., “max 1% daily move”) or how frequently PPS can be updated (heartbeats).

---

## Required Changes and New Components

Below are the **new or modified functionalities** needed to implement the off-chain approach and dispute mechanism. Where possible, we aim to **minimize changes** to existing vault/strategy code and add a dedicated “PPS & Dispute” system that works alongside the existing deposit/withdraw infrastructure.

### 1. Off-Chain PPS Storage and Updates
- **New PPS Variable**  
  Each SuperVault (or its strategy) will store a **single pps value** (e.g., `uint256 storedPPS`), plus metadata such as the block timestamp of last update and the strategist’s address that posted it.
- **Function: `updatePPS(uint256 newPPS, uint256 calculationBlock)`**  
  - **Callable by**: Authorized strategist (i.e., address that has staked and is recognized as the manager).  
  - **Logic**:  
    1. Checks that the new PPS is being inscribed after a minimum time gap, otherwise revert (rate limit)
    2. Checks that the PPS is within reasonable bounds of change from the last stored PPS, otherwise pause the contract. This check is made with a few bips of deviation to up or down.
    3. Checks if `block.number - calculationBlock < threshold`, where threshold is a number of blocks allowed since calculation block and block.number (this threhsold is configurable) this is to avoid the strategist always providing the same PPS over time by pointing to the same block.number regardless of being very far in the past. Otherwise revert.
    4. Stores `storedPPS = newPPS`.  
    5. Emits event `PPSUpdated(oldPPs, newPPS, calculationBlock)`.  

- **PPS Usage**
  - Replace the old on-chain calls to `totalAssets()` or yield-source TVLs with a simple fetch of `storedPPS`.  

### 2. Dispute, Slashing Mechanism and Reputation system
  - **Callable by**: Any user (the "disputer") who suspects a given update of a pps is incorrect (or it's update didn't meet the hearbeat requirement), submits the block.number of its update
  in a dispute function (which gets emited in an event)
  - Disputes are handled off-chain by looking at the disputed block number
  - Requires the disputer to have a stake (e.g., `disputeStake` in \$UP tokens) into a Dispute contract.  
  - The following happens in a combination of off-chain and on-chain behaviour
       1. [Off-chain] A simulation is ran on that suspected block number. If `abs(simulatedPPS - storedPPS) / storedPPS > ppsTolerance`, the strategist is going to be queued up to be slashed
       2. [On-chain] The **Adjudicator** calls the Dispute contract.  
         - **Slash**: The strategist’s stake in the staking contract is *partially or fully* slashed and the challenger is rewarded from that slashed stake.  
         - No changes are made to the stored pps
         - Emit event `StrategistSlashed(...)`.  
       - Else, the disputer's deposit is lost (burned or distributed to the strategist) to discourage griefing.  
         - Emit event `DisputeFailed(...)`.
- **Staking Management**  
  - This contract should manage each strategist’s and disputer locked \$UP tokens.  
  - The strategist must maintain a minimum stake; if it is slashed below a threshold, they can no longer call `updatePPS`.
  - We want only **“approved” strategists** with a known identity or good track record (a registerStrategist function is called by an admin before a strategist can stake)
  - All stakers (strategists/disputers) have a 7 day unstake queue before getting their stake back. Additionally, any user with an on-going dispute cannot unstake.

### 3. Code Refactors & New Contracts
Below are the main additions:

1. Adapt existing `SuperVault` / `SuperVaultStrategy`
   - Remove direct on-chain `totalAssets()` computations.  
   - Add `uint256 storedPPS` and `updatePPS(...)`, plus a reference to SuperAdjudicator to check the strategist’s stake.  

2. **`SuperAdjudicator.sol`** 
   - A place for “KYCed” strategists to put their stake
   - Disputers do not need KYC to register, just need to put a stake.
   - Manages the staking (strategist stakes, disputer stakes).  
   - On dispute success, slash from strategist’s stake and pay the dispute.  
   - If dispute fails, slash from the dispute.  
   - Ensure strategists remain above a minimum stake to keep privileges.
   - If a dispute is raised and is successful, the adjudicator slashes the strategist

3. Change **`SuperVault / SuperVaultStrategy`** to only ERC7540AsyncRedeem
   - Make the deposit step fully synchronous:
      - Assets are transferred to the strategy
      - PPS is immediately available, mint shares to the user
   - Therefore request deposit ceases to exist, as well as cancelation of deposit requests
   - matchRequests ceases to exist as there are no requests to match

4. **Updated Test Suites**  
   - We must thoroughly test:  
     - Normal deposits/withdraw with off-chain PPS updates.  
     - PPS updates on various intervals.  
     - Dispute logic when the PPS is within tolerance vs. out of tolerance.  
     - Slashing mechanics.  
     - Re-entrancy checks for dispute flows.  
     - Pause states if the PPS leaps too far or is not updated in time.

### 4. Decentralized Adjudication System (Node‑Runner View)

**Adjudicator off-chain role**

Data ingestionn
 - Self hosted in the node (anyone can run)
   - Ingest Events via Superform Data Pipeline
   - Subscribe to vault events (e.g. PPSUpdated) streamed into ClickHouse.
   - Apply the same ETL transforms (hooks, asset‑in‑transit proofs) that Superform use.

Run the Python Reference Impl
- Pull the exact Git tag or commit hash embedded in each PPSUpdated event.
- Execute the off‑chain PPS calculation against the block snapshot (via an archive‑node RPC).

Produce & Sign Verdicts:
- Compare computed PPS to the on‑chain value.
- If discrepancy > tolerance, sign a dispute verdict; else a “validate” verdict.

Ensure Consensus & On‑Chain Settlement:
- Gossip signed verdicts to peers (via any off‑chain relay).
- A designated aggregator collects ≥ N signatures and submits the final proof to SuperAdjudicator.sol.


---

## Summary of New Functions

Below is a concise summary of the **core** new or changed functions in the vault or strategy:

1. **`updatePPS(uint256 newPPS, uint256 updateBlockNumber)`**  
   - **Access**: Strategist only (must have staked + be recognized).  
   - **Stores**: `storedPPS = newPPS`, records updateBlockNumber in the event

2. **`disputePPS(address strategy, uint256 disputeBlockNumber, uint256 disputeTxHash)`**  
   - **Access**: Any user with `challengeStake`.  
   - **Flow**:
     1. If within dispute window (a maximum of blocks in the past), this txHash is marked in dispute (and cannot be disputed by anyone else) and an event is emitted with the information being disputed (block number and hash)
     2. The adjudicator role compares the simulated PPS to the `storedPPS` for that txHash and if the disputed block number also corresponds to the hash. If difference is beyond tolerance, slash strategist. Otherwise, slash disputer. Update the status of the dispute with this information.

3. **`slashStrategist(address strategist, uint256 updatePPSTimestamp, uint256 realPPS, uint256 disputedPPS)`**  
   - **In**: Staking contract.  
   - **Invoked**: By the dispute logic if a strategist is proven to lie.  
   - **Flow**:
      1. When slashing the strategist, the amount to slash (SA) is a function of:
         - deltaT = block.timestamp - updatePPSTimestamp (The larger DeltaT, the lower the slashed amount)
         - deltaPPS = abs(realPPS - disputedPPS) (The smaller deltaPPS, the lower the slashed amount)
         When coding this, create a function that uses these two elements to determine the slashing amount off of strategist's total staked amount (and explain reasoning)
      2. Once the SA is determined, calculate the reward for the challenger, which should be min(SA, max_reward)
      3. SA is slashed from the strategist and collected by Superform and superform rewards the disputer with an equivalent amount USDC (using SuperOracle to convert)

4. **`slashDisputer(address disputer, uint256 slashAmount)`**  
   - **In**: Staking contract.  
   - **Invoked**: By the dispute logic if a strategist is proven to lie.  
   - **Flow**:
      1. When slashing the strategist, the amount to slash (SA) is a function of:
         - deltaT = block.timestamp - updatePPSTimestamp (The larger DeltaT, the lower the slashed amount)
         - deltaPPS = abs(realPPS - disputedPPS) (The smaller deltaPPS, the lower the slashed amount)
      Same logic as used for slashing the strategist
      2. No reward is given to the strategist from this slash (tokens are just collected by Superform)


Assume any other relevant configuration functions, as required.
Create always interfaces for new contracts and have any natspec, structs, errors, events or enums be placed there. Make sure to update existing interfaces

