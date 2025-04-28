# Superform Periphery - Solidity Development PRD

> **Important:**  
> Engineer must keep this document **up to date** while progressing through development.  
> Mark completed tasks by filling `[ ] → [x]`.  
> **All functionality must be validated by unit tests**. This will be done after all tasks have been marked as complete and we fix current tests (we will look over all implemented features here and test them appropriately)

---

## 0. [ ] Contracts to Remove

- [ ] **Delete** `SuperAdjudicator.sol`

---

## 1. [ ] Refactor Overview

- [ ] **Refactor** `PeripheryRegistry.sol` into `SuperGovernor.sol`
- [ ] **Refactor** `SuperVaultFactory.sol` into `SuperVaultAggregator.sol`

---

## 2. [ ] General Coding Rules

- [ ] Create **dedicated interfaces** for each new contract
- [ ] Use **named errors** in CAPITAL_CASE in interfaces
- [ ] Add **events** for each state-changing external function
- [ ] Define **structs** cleanly
- [ ] Write **NatSpec comments** (`@notice`, `@param`, `@return`) for all public and external functions
- [ ] Inherit **interface properly** in contracts
- [ ] Follow **revert ERROR() pattern** instead of require
- [ ] Use **external** for user-exposed functions unless internal-only
- [ ] Constructors must initialize variables immutably where possible
- [ ] Make sure arguments to functions have variables in camelCase_ (with an ending underscore)

---

## 3. [ ] New and Updated Contracts Specification

### [ ] SuperGovernor.sol

- **Purpose:**  
    Central registry for all deployed contracts in the Superform periphery, operateable by multisig and with timelocks

- **Responsibilities:**
    - Maintain mapping of contract names/keys to addresses
    - Provide lookup functions for other contracts to resolve dependencies
    - Admin controls for adding, updating, or deprecating entries
    - Maintaining approved hooks for usage in SuperVaults
    - Maintain current approved PPS derivation method to be used and the list of allowed callers to SuperPPSAggregator.sol
    - Maintains the lists of strategists and validator (maybe these are just set here)
    - Timelocked changes and changes via governance

- **Functions (perhaps not exhaustive):**
  ```solidity
  function setContract(bytes32 key, address contractAddress) external;
  function removeContract(bytes32 key) external;
  function getContract(bytes32 key) external view returns (address);
  
  function approveHook(address hook) external; // (from curren registerHook)
  function removeHook(address hook) external; // (from curren unregisterHook)
  function isHookApproved(address hook) external view returns (bool);
  
  function addStrategist(address strategist) external;
  function removeStrategist(address strategist) external;
  function isStrategist(address strategist) external view returns (bool);
  
  function addValidator(address validator) external;
  function removeValidator(address validator) external;
  function isValidator(address validator) external view returns (bool);
  
  function setRevenueShare(uint256 share) external;
  function getRevenueShare() external view returns (uint256);
  ```

- **Notes:**
  - All `set` and `remove` functions must be **timelocked** and **governance-only**.
  - Make sure known keys are set as constants, such as TREASURY, SUPER_ORACLE, BLSPPSORACLE, ECDSAPPSORACLE, SUPER_VAULT_AGGREGATOR, UP, SUP, 

---


### [ ] sUP.sol (Staked UP Token)

- **Purpose:**  
  Staking version of the `$UP` token, allowing users to earn protocol rewards over time.  
  Is instantiated via SuperVaultAggregator with a superform controlled strategist as a SuperVault tri


- **Notes:**
  - Assume a mock $UP token for the time being (UP.sol). Later this will be replaced by the proper UP token.

---

### [ ] SuperBank.sol

- **Purpose:**  
  Distributes a part of protocol revenue to `sUP` holders each epoch.  
  Also handles optional actions like swapping revenue to `$UP`, bridging, etc.

- **Responsibilities:**
    - Perform actions with hooks:
        - Redeem underlying shares for assets
        - Swap collected revenue to $UP to increase buy pressure (on ETH)
        - Bridge any assets to to ETH (Any other chain)
    - Transfers $UP to SuperTreasury
    - Collect rewards airdropped to each VaultBank on each chain and bridge to ETH

- **Functions:**
  ```solidity
  function executeHooks(address[] memory hooks, bytes[] calldata data) external;
  function setEpochDuration(uint256 newDuration) external;
  function getUserEpochRewards(address account, uint256 epochId) external view returns (uint256);
  ```

- **Revenue Sources:**
  - [ ] 20% of performance fees from non-Superform vaults
  - [ ] 40% of swap fees from SuperAssets (after insurance)
  - [ ] Core protocol fee switch on yield
  - [ ] Protocol-owned liquidity revenues

- **Notes:**
  - **Epoch-based** rewards distribution.
  - Revenue allocation flexible via **Hooks** (swap, bridge, etc.).
  - Parameters like epoch duration and fee percentages must be **governance-controlled** via `SuperGovernor` (insert them there)

---

### [ ] SuperVaultAggregator.sol

- **Purpose:**  
    Create new SuperVault trios. Receive calls from trusted PPS oracles with different checking methods or optimized proving functions. Allows strategists to register with a KYC proof generated off-chain. Allows strategists to maintain a balance of $UP tokens with functions to deposit/withdraw that token. 

- **Responsibilities**:
    - Single source of truth of pps for all SuperVaults
    - Registry of all SuperVaults created in the system
    - Strategist’s can configure their vaults’ PPS settings for Oracle operators during SuperVault creation process and after the creation process.
    - Universal interface that all PPSOracles and SuperVaults have to conform to
    - Accept calls from trusted PPSOracles allowed via SuperGovernor.

- **Functions:**
  ```solidity
  function createVault(VaultCreationParams calldata params)
        external
        returns (address superVault, address strategy, address escrow); // preserve the function and include the functionality to configure the PPS validation settings: minUpdateInterval, maxStaleness
  /*
  For PPS update functions
  1. **Pre-Checks:**
    - Verify strategist registration and upkeep status
        - If strategist is not registered, revert the update
        - If upkeep falls below threshold, strategist enters a timer
            - During timer: pause the associated vault. Strategist cannot unpause via his role
            - If upkeep not updated on-time: other KYCed strategist or Superform can take over vault operations
        - If the update authority is a strategist approved address then he is exempt from paying upKeep in UP
    - Rate limiting: enforce minimum interval between updates (revert if too soon) to avoid burning strategist upKeep. Strategist could set this to 0
    - Staleness protection: require updates within max allowed interval. If this is violated:
        - Upkeep is not spent to pay validator
        - Validator could get slashed, unless marked to be in “maintenance period”
    2. **~~Deviation Guard:~~**
        - ~~Compare new PPS vs. last PPS; if deviation exceeds threshold, pause strategy~~
        - ~~When paused: disable deposits only. Can be unpaused by strategist~~
    3. **Execution:**
        - Update stored PPS value and timestamp
        - Emit events for off-chain indexing
  */ 
  function forwardPPS(address updateAuthority, address strategy, uint256 pps, uint256 timestamp) external;
  function batchForwardPPS(address[] calldata strategies, uint256[] calldata pps, uint256[] calldata timestamps) external;
  
  function depositUpkeep(address strategist, uint256 amount) external;
  function withdrawUpkeep(address strategist, uint256 amount) external;


  function getPPS(address strategy) external view returns (uint256 pps);

  ```

- **Notes:**
  - Strategists must register a **KYC proof** before vault creation.
  - Manage **upkeep balances** and **vault pause logic**.

---

### [ ] PPSOracle.sol

- **Purpose:**  
  Receive proven PPS updates and forward them to `SuperVaultAggregator`. Modular pieces that can work with different signature validation mechanism.

- **Responsibilities**:
    - Receive proven PPS values
    - Enforce a certain PPS Update mechanic

- **Functions:**
  ```solidity
  /*
  1. **Proof Validation:**
    - Confirm validator addresses via `ValidatorRegistry.sol`
    - Verify proof matches submitted `p`ps and `timestamp`
    - Check quorum of signed validators (initially quorum=1)
    2. **Forwarding:**
        - Send price, msg.sender and timestamp to aggregator contract
        - Msg.sender is used to detect who called updatePPS, relevant for determining wether to take upKeep or not

    **Callability:**

    - Public function; anyone with valid proof can invoke
    - Ideal for simple automation or strategist-run bot.
        - Note: this should be ran with Flashbots to avoid users snooping into mempool and watching updates
    - Strategist decides off-chain if he wants to engage in his own automation or not. If he wants, he must specify in SuperVaultAggregator authorized list of automation callers which will grant exemption from upkeep payment

    **Function:** `batchUpdatePPS(address[] memory strategies, bytes[] memory proofs, uint256[] memory ppss, uint256[] memory timestamps)`

    Same two steps as above, but when forwarding, forwards to `batchForwardPPS`

    **Callability:**

    - Public function; anyone with valid proof can invoke
    - Ideal Superform automation can call this. Strategists can still call these but they will bear the costs for the call and thus are heavily disincentivised in doing so.
    - No updateAuthority is sent on batchForwardPPS call
  */

  function updatePPS(address strategy, bytes calldata proof, uint256 pps, uint256 timestamp) external;
  function batchUpdatePPS(address[] calldata strategies, bytes[] calldata proofs, uint256[] calldata ppss, uint256[] calldata timestamps) external;
  ```

- **Notes:**
  - Validate proofs against **validator quorum**.
  - Use **msg.sender** for upkeep deductions.
  - Allowed PPSOracles are set in SuperGovernor. For now only create a sample ECDSAPPsOracle that takes in ECDSA proofs. Sample research below:

    **Production Example – [Chainlink OCR:](https://docs.chain.link/architecture-overview/off-chain-reporting)** Chainlink’s OCR protocol greatly reduced on-chain gas costs compared to earlier “Flux Monitor” designs by moving aggregation off-chain. Instead of N separate transactions (one per oracle) posting data, OCR uses one transaction carrying a batch of signed observations. The on-chain contract then loops through the signatures to check that a threshold of trusted oracles attested to the same value. For instance, if 21 oracles participate, the contract might require at least 13 valid signatures on the report. Each signature is verified via ECDSA (`ecrecover`) – an EVM precompile that costs ~3000 gas per signature. Verifying *m* signatures thus costs O(m) gas. In practice, this is manageable for moderate *m* (e.g. 20 signatures ≈ 60k gas), and far cheaper than 20 separate transactions. **Chainlink’s aggregator contract does exactly this: it validates each oracle’s signature and then records the consensus value on-chain ().** This approach supports **many operators (20+ oracles)** and is **deployed on Ethereum mainnet and various L2s** for price feeds, proving its production readiness. The **trade-off** is that on-chain cost scales linearly with the number of signers, and all signatures must be posted (increasing calldata size). Chainlink’s research notes that adopting *aggregated signatures* (multi-signatures) could make verification cost constant and allow larger oracle sets without major gas increase () – however, they currently stick to standard ECDSA due to the lack of a BLS precompile.
    **Consensus Protocol:** Internally, protocols like OCR run a lightweight Byzantine Fault Tolerant (BFT) consensus off-chain. Oracles share their observed values and digitally sign the proposed report. If enough signatures (over a threshold f+1) are collected, the report is considered authenticated (). This off-chain agreement can use rounds with a leader or a majority vote to ensure all honest nodes converge on the same value. The end result is a set of signatures on one message. This general pattern can be implemented with various consensus algorithms (PBFT, HotStuff, etc.), but OCR is designed for efficiency with a known set of N oracles and frequent reports. The important aspect is **fault tolerance**: as long as a quorum of the operators are honest and sign the correct value, a malicious minority cannot force a wrong result. They simply would refuse to sign a bad proposal, and the protocol would either select a new leader or only finalize when enough valid signatures are present (). This provides strong resilience against up to f faulty nodes (typically f < N/3 or N/2 depending on the protocol assumptions).

    **Signature Batch vs. Single Proof:** In the OCR approach (and similarly in on-chain multisig contracts), the on-chain proof is effectively a *batch of individual signatures*. All the ECDSA signatures are included in the transaction call data, or encoded in the report structure, and the contract iterates to verify each. This is not a “single cryptographic proof” but rather a bundle of proofs-of-signature. It’s compact in the sense of being one transaction, but not a single aggregated signature. However, the data can be somewhat compressed (e.g., by not repeating the message for each signature, using a bitmask for signers, etc.). Chainlink’s report format, for example, includes a list of observations and signatures, and the contract knows the set of authorized oracle addresses, so it can match signatures to oracles without sending all addresses every time ().


---
### [ ] SuperVaults trio (SuperVault.sol SuperVaultStrategy.sol SuperVaultEscroew.sol)

Largely untouched
- **Notes:**
  - Make sure the PPS is read from SuperVault aggregator
  - Insert relevant modifiers/parameter reading based on the restrictions existent in SuperVaultAggregator and SuperGovernor

---

## 4. [ ] Interfaces to Create (examples)

- [ ] `ISuperGovernor.sol`
- [ ] `ISuperBank.sol`
- [ ] `ISuperVaultAggregator.sol`
- [ ] `IPPSOracle.sol`

Each must define:
- [ ] Events
- [ ] Structs
- [ ] Errors
- [ ] Function Signatures

---

## 5. [ ] Errors to Define (in Interfaces) (EXAMPLES)

All errors must be in **CAPITAL_CASE**:

```solidity
error ONLY_GOVERNOR();
error CONTRACT_ALREADY_REGISTERED();
error CONTRACT_NOT_FOUND();
error INVALID_PROOF();
error STRATEGIST_NOT_REGISTERED();
error INSUFFICIENT_UPKEEP();
error VAULT_PAUSED();
```

---

## 6. [ ] Events to Define (in Interfaces)

Example events:

```solidity
event ContractSet(bytes32 indexed key, address indexed contractAddress);
event HookApproved(address indexed hook);
event PPSUpdated(address indexed strategy, uint256 pps, uint256 timestamp);
event StrategistRegistered(address indexed strategist);
event VaultCreated(address indexed vault, address indexed strategist);
```

---

# 📋 Development Summary Checklist

- [ ] Remove old contracts (`SuperAdjudicator.sol`)
- [ ] Refactor registries (PeripheryRegistry → SuperGovernor, SuperVaultFactory → SuperVaultAggregator)
- [ ] Implement all interfaces first
- [ ] Code contracts using interfaces
- [ ] Follow coding patterns: external, errors, events, natspec
- [ ] Write unit tests for each major flow:
  - SuperGovernor contract registry management
  - Hook management
  - Strategist KYC and upkeep in SuperVaultAggregator
  - PPS Update forwarding and verification
  - SuperBank revenue distribution and epoch management
- [ ] Update this document by checking `[x]` after validating via unit tests




Thanks for pointing that out — you're absolutely right.  
We still need to add **sUP (Staked UP token)** and **SuperBank** into the PRD!

I'll extend the document carefully while keeping the same markdown style, checkboxes, and engineering tracking flow. Here’s the updated addition you should insert into your PRD:

---

## 3. [ ] New and Updated Contracts Specification (continued)

---


---

## 4. [ ] Interfaces to Create (updated)

- [ ] `ISuperGovernor.sol`
- [ ] `ISuperVaultAggregator.sol`
- [ ] `IPPSOracle.sol`
- [ ] `ISUP.sol`
- [ ] `ISuperBank.sol`

Each must define:
- [ ] Events
- [ ] Structs
- [ ] Errors
- [ ] Function Signatures

---

## 5. [ ] Errors to Define (additional)

Add these errors for `sUP` and `SuperBank`:

```solidity
error INSUFFICIENT_BALANCE();
error ZERO_AMOUNT();
error INVALID_EPOCH();
error CLAIM_ALREADY_MADE();
```

---

## 6. [ ] Events to Define (additional)

Example events for new contracts:

```solidity
event DEPOSIT(address indexed user, uint256 amount, uint256 shares);
event WITHDRAW(address indexed user, uint256 shares, uint256 amount);
event REVENUE_RECORDED(address indexed token, uint256 amount);
event REWARDS_CLAIMED(address indexed user, uint256 epochId, uint256 rewards);
event EPOCH_DURATION_UPDATED(uint256 newDuration);
```

---

# 📋 Updated Development Summary Checklist

- [ ] Remove old contracts (`SuperAdjudicator.sol`)
- [ ] Refactor registries (PeripheryRegistry → SuperGovernor, SuperVaultFactory → SuperVaultAggregator)
- [ ] Implement all interfaces first
- [ ] Implement sUP token logic
- [ ] Implement SuperBank reward distribution logic
- [ ] Code contracts using interfaces
- [ ] Follow coding patterns: external, errors, events, natspec
- [ ] Write unit tests for each major flow:
  - SuperGovernor management
  - Strategist KYC and upkeep in SuperVaultAggregator
  - PPS Update forwarding and verification
  - sUP deposit/withdraw/claim flows
  - SuperBank revenue distribution and epoch management
- [ ] Update this document by checking `[x]` after validating via unit tests

---

Would you like me to directly **merge this addition into your active Canvas document** so you have everything perfectly unified?  
(If yes, I can also reformat the full outline slightly cleaner in the process if you'd like!) 🚀