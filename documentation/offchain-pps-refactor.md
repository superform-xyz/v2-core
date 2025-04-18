# Refactor PRD: Off-Chain PPS for SuperVaults

## Goal and Overview

We want to **refactor** the existing on-chain price-per-share (PPS) logic in SuperVaults so that **all PPS calculations happen off-chain**. A **strategist** (vault manager) periodically **reports** a new PPS on-chain, which we use in deposit/withdraw flows. This PPS is accepted *optimistically* unless someone disputes it. If there is a dispute, the system can run a **reference calculation** (similar to the old Approach 1 logic) *only* once needed (rather than on every block). 

Strategists must **stake** protocol tokens (e.g., \$UP) to be allowed to post PPS. A **challenger** who suspects fraud can raise a dispute by also staking. If the on-chain reference check proves the strategist’s PPS was wrong beyond a tolerance, the strategist is **slashed**. Otherwise, the challenger loses their stake (discouraging spam). Through this mechanism, we preserve trust and correctness over time while **lowering on-chain gas** for routine operations.

### Key Differences from the Original On-Chain PPS
1. **Off-Chain PPS Calculation**  
   - Previously, we calculated `totalAssets()` or price-per-share on-chain every time. Now the strategist just publishes a number, and user deposits/withdrawals consume that number in O(1) operations.
2. **New “Dispute” Mechanism**  
   - If the posted PPS is suspected to be wrong, a dispute can trigger a reference calculation (the original multi-yield-source logic) on-chain. If the strategist’s posted PPS is indeed incorrect beyond a threshold, the system slashes the strategist’s stake and corrects the on-chain PPS.
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
    1. Checks that the new PPS is within an allowed rate-limited deviation from the old PPS (if applicable), otherwise pause the contract
    2. Checks that the PPS is within reasonable bounds of change from the last stored PPS, otherwise pause the contract
    3. Checks if `block.number - calculationBlock < threshold`, where threshold is a number of blocks allowed since calculation block and block.number
    this is to avoid the strategist always providing the same PPS over time by pointing to the same block.number regardless of being very far in the past. Otherwise 
    revert.
    4. Stores `storedPPS = newPPS`.  
    5. New dispute window for this update kicks in during which anyone can challenge this PPS (until a further update). 
    6. Emits event `PPSUpdated(oldPPs, newPPS, calculationBlock)`.  

- **PPS Usage**
  - Replace the old on-chain calls to `totalAssets()` or yield-source TVLs with a simple fetch of `storedPPS`.  

### 2. Reference Implementation for Disputes
- **`SuperVaultPPSOracle.sol` (Reference Implementation)**  
  - This contract includes a **pure/virtual** function `calculateReferencePPS(address vault)` that reproduces the *old Approach 1 logic* of summing all yield sources, evaluating oracles, etc.  
  - By default, we do **not** call this function on-chain
  - Must be flexible enough to handle different yield sources. Possibly integrated with existing `IYieldSourceOracle` calls or the aggregator approach to ensure it can reflect the same final number the off-chain strategist script would have used.

### 3. Dispute and Slashing Mechanism
  - **Callable by**: Any user (the "disputer") who suspects the current `storedPPS` is incorrect.
  - Disputes are handled off-chain by providing a valid block number and simulation (not to be implemented in solidity)
  - Requires the challenger to deposit a stake (e.g., `challengeStake` in \$UP tokens) into a Dispute contract.  
  - The following happens in a combination of off-chain and on-chain behaviour
       1. [Off-chain] If `abs(simulatedPPS - storedPPS) / storedPPS > disputeTolerance`, the strategist is going to be queued up to be slashed
       2. [On-chain] The off-chain **Adjudicator** calls the Dispute contract).  
         - **Slash**: The strategist’s stake in the staking contract is *partially or fully* slashed and the challenger is rewarded from that slashed stake.  
         - No changes are made to the stored pps
         - Emit event `StrategistSlashed(...)`.  
       - Else, the challenger’s deposit is lost (burned or distributed to the strategist) to discourage griefing.  
         - Emit event `ChallengeFailed(...)`.
- **Staking Management**  
  - We will add or extend a **staking contract** that manages each strategist’s locked \$UP tokens.  
  - The strategist must maintain a minimum stake; if it is slashed below a threshold, they can no longer call `updatePPS`. (TBD - post your thoughts)

### 4. Reputation & KYC System 
- We want only **“approved” strategists** with a known identity or good track record.  
- Implementation detail: In simplest form, we can add:  
  - A new function `registerStrategist(address who)` guarded by a “governance” or “admin” role in the Dispute contract
  - The user must stake the required amount of \$UP tokens in the staking contract.  
  - The vault or strategy contract checks “Is `who` in the list of registered strategists?” before letting them call `updatePPS`.

### 5. Circuit Breakers and Heartbeats
- **Heartbeat**: Minimal time interval between consecutive PPS updates.  
- **Deviation Threshold**: If `abs(offChainPPS - onChainPPS) / onChainPPS > X%`, forcibly require an update or freeze the vault until corrected.  
- If either condition is violated, we set a “pause” on the vault (like an emergency stop) or revert the next deposit/withdraw calls until the strategist does a correct PPS update.

### 6. Code Refactors & New Contracts
Below are the main additions:

1. Adapt existing `SuperVault` / `SuperVaultStrategy`) 
   - Remove direct on-chain `totalAssets()` computations.  
   - Add `uint256 storedPPS` and `updatePPS(...)`, plus a reference to the new staking contract to check the strategist’s stake.  
   - Add a `disputeWindow` after each PPS update.  
   - If a dispute is raised and is successful, the adjudicator slashes the strategist

2. **`SuperVaultPPSOracle.sol`** (Reference Implementation)  
   - Exposes `calculateReferencePPS(address vault) returns (uint256)`, doing the heavy yield‐source logic.  
   - Possibly modular or re-use existing aggregator code.  

3. **`SuperVaultReputationSystem.sol`** 
   - A place to store “KYCed” or “approved” addresses.  
   - Or simply an array in the main strategy contract, updated by admin.
   - Manages the staking (strategist stakes, challenger stakes).  
   - On dispute success, slash from strategist’s stake and pay the challenger.  
   - If dispute fails, slash from the challenger.  
   - Ensure strategists remain above a minimum stake to keep privileges.

4. **Updated Test Suites**  
   - We must thoroughly test:  
     - Normal deposits/withdraw with off-chain PPS updates.  
     - PPS updates on various intervals.  
     - Dispute logic when the PPS is within tolerance vs. out of tolerance.  
     - Slashing mechanics.  
     - Re-entrancy checks for dispute flows.  
     - Pause states if the PPS leaps too far or is not updated in time.

### 7. Gas and Performance Considerations
- By removing the on-chain summation of all yield sources from routine operations, *most user calls* become *vastly cheaper*.  
- The only heavy calls are `disputePPS()`, which triggers the reference logic. But those are expected to be rare, triggered only if suspicious changes are posted.  
- The cost of on-chain yield‐source enumeration is now one-off in disputes, improving scale for large strategies.

---

## Summary of New / Modified Functions

Below is a concise summary of the **core** new or changed functions in the vault or strategy:

1. **`updatePPS(uint256 newPPS)`**  
   - **Access**: Strategist only (must have staked + be recognized).  
   - **Stores**: `storedPPS = newPPS`, records timestamp, triggers dispute window.  

2. **`disputePPS(address vault)`**  
   - **Access**: Any user with `challengeStake`.  
   - **Flow**:
     1. If within dispute window, fetch `onChainPPS = SuperVaultPPSOracle.calculateReferencePPS(vault)`.  
     2. Compare to `storedPPS`. If difference is beyond tolerance, slash strategist and correct `storedPPS`. Otherwise, slash challenger.  

3. **`slashStrategist(address strategist, uint256 slashAmount)`**  
   - **In**: Staking contract.  
   - **Invoked**: By the dispute logic if a strategist is proven to lie.  

4. **`maxDeposit`, `maxWithdraw`, `deposit`, `redeem`, `executeHooks` etc.**  
   - All strategist-facing deposit/withdraw calls now do:  
     - “`shares = assets * 1e18 / storedPPS`” for deposit.  
     - “`assets = shares * storedPPS / 1e18`” for withdraw.  
   - No large yield‐source lookups or aggregator calls.  

5. **Access & Pause**  
   - If the new PPS changes beyond an allowed daily range or if the strategist fails to update within a heartbeat, the vault can be paused automatically. The on-chain code should specify a minimum delay between updates, similar to Veda’s rate-limiting approach. Variations of the PPS should be allowed in each update in the order of a few BPS up or down

---

## Example Contract Additions

**(Pseudocode / Outline)**

```solidity
contract OptimisticSuperVault is ERC4626, ReentrancyGuard {
    // The off-chain price per share
    uint256 public storedPPS;
    uint256 public lastPPSUpdateTime;
    address public strategist;
    uint256 public disputeWindowEnd;  // block.timestamp after which PPS cannot be disputed

    // Reference to the staking contract
    ISuperVaultStaking public staking;

    // Reference to the on-chain reference aggregator
    ISuperVaultPPSOracle public referenceOracle;

    // 1. Strategist updates PPS
    function updatePPS(uint256 newPPS) external onlyStrategist {
        // check staked amount >= required
        // check not too soon after last update, not beyond circuit breaker

        storedPPS = newPPS;
        lastPPSUpdateTime = block.timestamp;
        disputeWindowEnd = block.timestamp + DISPUTE_WINDOW; 

        emit PPSUpdated(msg.sender, newPPS);
    }

    // 2. Dispute function
    function disputePPS() external {
        // must be within disputeWindow
        require(block.timestamp <= disputeWindowEnd, "No longer disputable");
        // challenger stakes in staking contract, e.g. staking.lockForChallenge(msg.sender, challengeStake);

        // get the reference
        uint256 onChainPPS = referenceOracle.calculateReferencePPS(address(this));
        uint256 diff = (onChainPPS > storedPPS)
            ? onChainPPS - storedPPS : storedPPS - onChainPPS;

        if (diff * 1e18 / storedPPS > DISPUTE_TOLERANCE) {
            // Slash strategist
            staking.slashStrategist(strategist, slashAmount);
            // correct the PPS
            storedPPS = onChainPPS;
            emit PPSCorrected(onChainPPS);
        } else {
            // slash challenger
            staking.punishChallenger(msg.sender);
            emit ChallengeFailed(msg.sender);
        }
    }

    // 3. deposit / withdraw remain the same but use storedPPS
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        shares = assets * 1e18 / storedPPS;
        _mint(receiver, shares);
        // ...
    }
}
```