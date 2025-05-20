// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/IAccessControl.sol";

/*//////////////////////////////////////////////////////////////
                                  ENUMS
    //////////////////////////////////////////////////////////////*/
/// @notice Enum representing different types of fees that can be managed
enum FeeType {
    REVENUE_SHARE,
    SUPER_VAULT_PERFORMANCE_FEE,
    SUPER_ASSET_SWAP_FEE
}
/// @title ISuperGovernor
/// @author Superform Labs
/// @notice Interface for the SuperGovernor contract
/// @dev Central registry for all deployed contracts in the Superform periphery

interface ISuperGovernor is IAccessControl {
    /*//////////////////////////////////////////////////////////////
                                  STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Structure containing Merkle root data for a hook
    struct HookMerkleRootData {
        bytes32 currentRoot; // Current active Merkle root for the hook
        bytes32 proposedRoot; // Proposed new Merkle root (zero if no proposal exists)
        uint256 effectiveTime; // Timestamp when the proposed root becomes effective
    }

    /*//////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when a function that should only be called by governor is called by someone else
    error ONLY_GOVERNOR();
    /// @notice Thrown when trying to register a contract that is already registered
    error CONTRACT_ALREADY_REGISTERED();
    /// @notice Thrown when trying to access a contract that is not registered
    error CONTRACT_NOT_FOUND();
    /// @notice Thrown when providing an invalid address (typically zero address)
    error INVALID_ADDRESS();
    /// @notice Thrown when a hook is already approved
    error HOOK_ALREADY_APPROVED();
    /// @notice Thrown when a hook is not approved but expected to be
    error HOOK_NOT_APPROVED();
    /// @notice Thrown when a fulfill requests hook is already registered
    error FULFILL_REQUESTS_HOOK_ALREADY_REGISTERED();
    /// @notice Thrown when a fulfill requests hook is not registered but expected to be
    error FULFILL_REQUESTS_HOOK_NOT_REGISTERED();
    /// @notice Thrown when provided revenue share is invalid (exceeds 100%)
    error INVALID_REVENUE_SHARE();
    /// @notice Thrown when an invalid fee value is proposed (must be <= BPS_MAX)
    error INVALID_FEE_VALUE();
    /// @notice Thrown when no proposed fee exists but one is expected
    error NO_PROPOSED_FEE(FeeType feeType);
    /// @notice Thrown when timelock period has not expired
    error TIMELOCK_NOT_EXPIRED();
    /// @notice Thrown when a validator is not registered
    error VALIDATOR_NOT_REGISTERED();
    /// @notice Thrown when a validator is already registered
    error VALIDATOR_ALREADY_REGISTERED();
    /// @notice Thrown when trying to change active PPS oracle directly
    error MUST_USE_TIMELOCK_FOR_CHANGE();
    /// @notice Thrown when a SuperBank hook Merkle root is not registered but expected to be
    error INVALID_TIMESTAMP();
    /// @notice Thrown when attempting to set an invalid quorum value (typically zero)
    error INVALID_QUORUM();
    /// @notice Thrown when no active PPS oracle is set but one is required
    error NO_ACTIVE_PPS_ORACLE();
    /// @notice Thrown when no proposed PPS oracle exists but one is expected
    error NO_PROPOSED_PPS_ORACLE();
    /// @notice Error thrown when strategist takeovers are frozen
    error STRATEGIST_TAKEOVERS_FROZEN();
    /// @notice Thrown when no proposed Merkle root exists but one is expected
    error NO_PROPOSED_MERKLE_ROOT();
    /// @notice Thrown when no proposed upkeep cost exists but one is expected
    error NO_PROPOSED_UPKEEP_COST();
    /// @notice Thrown when a relayer is not registered
    error RELAYER_NOT_REGISTERED();
    /// @notice Thrown when a relayer is already registered
    error RELAYER_ALREADY_REGISTERED();
    /// @notice Thrown when an executor is not registered
    error EXECUTOR_NOT_REGISTERED();
    /// @notice Thrown when an executor is already registered
    error EXECUTOR_ALREADY_REGISTERED();
    /// @notice Thrown when there's no pending change but one is expected
    error NO_PENDING_CHANGE();
    /// @notice Thrown when a strategist is not registered
    error STRATEGIST_NOT_REGISTERED();
    /// @notice Thrown when a strategist is already registered
    error STRATEGIST_ALREADY_REGISTERED();

    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when an address is set in the registry
    /// @param key The key used to reference the address
    /// @param value The address value

    event AddressSet(bytes32 indexed key, address indexed value);

    /// @notice Emitted when a hook is approved
    /// @param hook The address of the approved hook
    event HookApproved(address indexed hook);

    /// @notice Emitted when a hook is removed
    /// @param hook The address of the removed hook
    event HookRemoved(address indexed hook);

    /// @notice Emitted when a fulfill requests hook is registered
    /// @param hook The address of the registered fulfill requests hook
    event FulfillRequestsHookRegistered(address indexed hook);

    /// @notice Emitted when a fulfill requests hook is unregistered
    /// @param hook The address of the unregistered fulfill requests hook
    event FulfillRequestsHookUnregistered(address indexed hook);

    /// @notice Emitted when a strategist is registered
    /// @param strategist The address of the registered strategist
    event StrategistAdded(address indexed strategist);

    /// @notice Emitted when a strategist is removed
    /// @param strategist The address of the removed strategist
    event StrategistRemoved(address indexed strategist);

    /// @notice Emitted when a validator is registered
    /// @param validator The address of the registered validator
    event ValidatorAdded(address indexed validator);

    /// @notice Emitted when a validator is removed
    /// @param validator The address of the removed validator
    event ValidatorRemoved(address indexed validator);

    /// @notice Emitted when revenue share is updated
    /// @param share The new revenue share percentage
    event RevenueShareUpdated(uint256 share);

    /// @notice Emitted when a new fee is proposed
    /// @param feeType The type of fee being proposed
    /// @param value The proposed fee value (in basis points)
    /// @param effectiveTime The timestamp when the fee will be effective
    event FeeProposed(FeeType indexed feeType, uint256 value, uint256 effectiveTime);

    /// @notice Emitted when a fee is updated
    /// @param feeType The type of fee being updated
    /// @param value The new fee value (in basis points)
    event FeeUpdated(FeeType indexed feeType, uint256 value);

    /// @notice Emitted when a new SuperBank hook Merkle root is proposed
    /// @param hook The hook address for which the Merkle root is being proposed
    /// @param newRoot The new Merkle root
    /// @param effectiveTime The timestamp when the new root will be effective
    event SuperBankHookMerkleRootProposed(address indexed hook, bytes32 newRoot, uint256 effectiveTime);

    /// @notice Emitted when the SuperBank hook Merkle root is updated.
    /// @param hook The address of the hook for which the Merkle root was updated.
    /// @param newRoot The new Merkle root.
    event SuperBankHookMerkleRootUpdated(address indexed hook, bytes32 newRoot);

    /// @notice Emitted when the VaultBank hook Merkle root is proposed
    /// @param hook The hook address for which the Merkle root is being proposed
    /// @param newRoot The new Merkle root
    /// @param effectiveTime The timestamp when the new root will be effective
    event VaultBankHookMerkleRootProposed(address indexed hook, bytes32 newRoot, uint256 effectiveTime);

    /// @notice Emitted when the VaultBank hook Merkle root is updated.
    /// @param hook The address of the hook for which the Merkle root was updated.
    /// @param newRoot The new Merkle root.
    event VaultBankHookMerkleRootUpdated(address indexed hook, bytes32 newRoot);

    /// @notice Emitted when the active PPS Oracle's quorum requirement is updated
    /// @param quorum The new quorum value
    event PPSOracleQuorumUpdated(uint256 quorum);

    /// @notice Emitted when an active PPS oracle is initially set
    /// @param oracle The address of the set oracle
    event ActivePPSOracleSet(address indexed oracle);

    /// @notice Emitted when a new PPS oracle is proposed
    /// @param oracle The address of the proposed oracle
    /// @param effectiveTime The timestamp when the proposal will be effective
    event ActivePPSOracleProposed(address indexed oracle, uint256 effectiveTime);

    /// @notice Emitted when the active PPS oracle is changed
    /// @param oldOracle The address of the previous oracle
    /// @param newOracle The address of the new oracle
    event ActivePPSOracleChanged(address indexed oldOracle, address indexed newOracle);

    /// @notice Event emitted when strategist takeovers are permanently frozen
    event StrategistTakeoversFrozen();

    /// @notice Emitted when a new upkeep cost per update is proposed
    /// @param newCost The proposed upkeep cost
    /// @param effectiveTime The timestamp when the new cost will be effective
    event UpkeepCostPerUpdateProposed(uint256 newCost, uint256 effectiveTime);

    /// @notice Emitted when the upkeep cost per update is changed
    /// @param newCost The new upkeep cost
    event UpkeepCostPerUpdateChanged(uint256 newCost);

    /// @notice Emitted when a relayer is added
    /// @param relayer The address of the added relayer
    event RelayerAdded(address indexed relayer);

    /// @notice Emitted when a relayer is removed
    /// @param relayer The address of the removed relayer
    event RelayerRemoved(address indexed relayer);

    /// @notice Emitted when an executor is added
    /// @param executor The address of the added executor
    event ExecutorAdded(address indexed executor);

    /// @notice Emitted when an executor is removed
    /// @param executor The address of the removed executor
    event ExecutorRemoved(address indexed executor);

    /// @notice Emitted when a prover is set
    /// @param prover The address of the prover
    event ProverSet(address indexed prover);

    /// @notice Emitted when a change to upkeep payments status is proposed
    /// @param enabled The proposed status (enabled/disabled)
    /// @param effectiveTime The timestamp when the status change will be effective
    event UpkeepPaymentsChangeProposed(bool enabled, uint256 effectiveTime);

    /// @notice Emitted when upkeep payments status is changed
    /// @param enabled The new status (enabled/disabled)
    event UpkeepPaymentsChanged(bool enabled);

    /// @notice Emitted when a superform strategist is added
    /// @param strategist The address of the added strategist
    event SuperformStrategistAdded(address indexed strategist);

    /// @notice Emitted when a superform strategist is removed
    /// @param strategist The address of the removed strategist
    event SuperformStrategistRemoved(address indexed strategist);

    /*//////////////////////////////////////////////////////////////
                                   ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The identifier of the role that grants access to critical governance functions
    function SUPER_GOVERNOR_ROLE() external view returns (bytes32);

    /// @notice The identifier of the role that grants access to daily operations like hooks and validators
    function GOVERNOR_ROLE() external view returns (bytes32);

    /// @notice The identifier of the role that grants access to bank management functions
    function BANK_MANAGER_ROLE() external view returns (bytes32);

    /// @notice The identifier of the role that grants access to guardian functions
    function GUARDIAN_ROLE() external view returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                       CONTRACT REGISTRY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Sets an address in the registry
    /// @param key The key to associate with the address
    /// @param value The address value
    function setAddress(bytes32 key, address value) external;

    /*//////////////////////////////////////////////////////////////
                        PROVER
    //////////////////////////////////////////////////////////////*/
    /// @notice Sets the prover address
    /// @param prover_ The address of the prover
    function setProver(address prover_) external;

    /*//////////////////////////////////////////////////////////////
                        SUPER VAULT AGGREGATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Change the primary strategist for a strategy
    /// @dev Only SuperGovernor can call this function directly
    /// @param strategy_ The strategy address
    /// @param newStrategist_ The new primary strategist address
    function changePrimaryStrategist(address strategy_, address newStrategist_) external;

    /// @notice Permanently freezes all strategist takeovers globally
    function freezeStrategistTakeover() external;

    /*//////////////////////////////////////////////////////////////
                         HOOK MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a hook for use in SuperVaults
    /// @param hook The address of the hook to register
    /// @param isFulfillRequestsHook Whether the hook is a fulfill requests hook
    function registerHook(address hook, bool isFulfillRequestsHook) external;

    /// @notice Unregisters a hook from the approved list
    /// @param hook The address of the hook to unregister
    /// @param isFulfillRequestsHook Whether the hook is a fulfill requests hook
    function unregisterHook(address hook, bool isFulfillRequestsHook) external;

    /*//////////////////////////////////////////////////////////////
                        EXECUTOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Adds an executor to the approved list
    /// @param executor The address of the executor to add
    function addExecutor(address executor) external;

    /// @notice Removes an executor from the approved list
    /// @param executor The address of the executor to remove
    function removeExecutor(address executor) external;

    /*//////////////////////////////////////////////////////////////
                      RELAYER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds a relayer to the approved list
    /// @param relayer The address of the relayer to add
    function addRelayer(address relayer) external;

    /// @notice Removes a relayer from the approved list
    /// @param relayer The address of the relayer to remove
    function removeRelayer(address relayer) external;

    /*//////////////////////////////////////////////////////////////
                      VALIDATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds a validator to the approved list
    /// @param validator The address of the validator to add
    function addValidator(address validator) external;

    /// @notice Removes a validator from the approved list
    /// @param validator The address of the validator to remove
    function removeValidator(address validator) external;

    /*//////////////////////////////////////////////////////////////
                       PPS ORACLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the active PPS oracle (only if there is no active oracle yet)
    /// @param oracle Address of the PPS oracle to set as active
    function setActivePPSOracle(address oracle) external;

    /// @notice Proposes a new active PPS oracle (when there is already an active one)
    /// @param oracle Address of the PPS oracle to propose as active
    function proposeActivePPSOracle(address oracle) external;

    /// @notice Executes a previously proposed PPS oracle change after timelock has expired
    function executeActivePPSOracleChange() external;

    /// @notice Sets the quorum requirement for the active PPS Oracle
    /// @param quorum The new quorum value
    function setPPSOracleQuorum(uint256 quorum) external;

    /*//////////////////////////////////////////////////////////////
                      REVENUE SHARE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proposes a new fee value
    /// @param feeType The type of fee to propose
    /// @param value The proposed fee value (in basis points)
    function proposeFee(FeeType feeType, uint256 value) external;

    /// @notice Executes a previously proposed fee update after timelock has expired
    /// @param feeType The type of ffee to execute the update for
    function executeFeeUpdate(FeeType feeType) external;

    /*//////////////////////////////////////////////////////////////
                      UPKEEP COST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proposes a new upkeep cost per update (for PPS updates)
    /// @param newCost The proposed new upkeep cost per update
    function proposeUpkeepCostPerUpdate(uint256 newCost) external;

    /// @notice Executes a previously proposed upkeep cost change after timelock has expired
    function executeUpkeepCostPerUpdateChange() external;

    /// @notice Proposes a change to upkeep payments enabled status
    /// @param enabled The proposed enabled status
    function proposeUpkeepPaymentsChange(bool enabled) external;

    /// @notice Executes a previously proposed upkeep payments status change
    function executeUpkeepPaymentsChange() external;

    /*//////////////////////////////////////////////////////////////
                           VAULT HOOKS MGMT
    //////////////////////////////////////////////////////////////*/

    /// @notice Proposes a new Merkle root for a specific hook's allowed targets.
    /// @param hook The address of the hook to update the Merkle root for.
    /// @param proposedRoot The proposed new Merkle root.
    function proposeVaultBankHookMerkleRoot(address hook, bytes32 proposedRoot) external;

    /// @notice Executes a previously proposed Merkle root update for a specific hook if the effective time has passed.
    /// @param hook The address of the hook to execute the update for.
    function executeVaultBankHookMerkleRootUpdate(address hook) external;

    /*//////////////////////////////////////////////////////////////
                           SUPERBANK HOOKS MGMT
    //////////////////////////////////////////////////////////////*/
    /// @notice Proposes a new Merkle root for a specific hook's allowed targets.
    /// @param hook The address of the hook to update the Merkle root for.
    /// @param proposedRoot The proposed new Merkle root.
    function proposeSuperBankHookMerkleRoot(address hook, bytes32 proposedRoot) external;

    /// @notice Executes a previously proposed Merkle root update for a specific hook if the effective time has passed.
    /// @param hook The address of the hook to execute the update for.
    function executeSuperBankHookMerkleRootUpdate(address hook) external;

    /// @notice Proposes a new global hooks Merkle root
    /// @dev Only GOVERNOR_ROLE can call this function
    /// @param newRoot New Merkle root for global hooks validation
    function proposeGlobalHooksRoot(bytes32 newRoot) external;

    /// @notice Sets veto status for global hooks Merkle root
    /// @dev Only GUARDIAN_ROLE can call this function
    /// @param vetoed Whether to veto (true) or unveto (false) the global hooks root
    function setGlobalHooksRootVetoStatus(bool vetoed) external;

    /// @notice Sets veto status for a strategy-specific hooks Merkle root
    /// @dev Only GUARDIAN_ROLE can call this function
    /// @param strategy Address of the strategy to affect
    /// @param vetoed Whether to veto (true) or unveto (false) the strategy hooks root
    function setStrategyHooksRootVetoStatus(address strategy, bool vetoed) external;

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets an address from the registry
    /// @param key The key of the address to get
    /// @return The address value
    function getAddress(bytes32 key) external view returns (address);

    /// @notice Checks if strategist takeovers are frozen
    /// @return True if strategist takeovers are frozen, false otherwise
    function isStrategistTakeoverFrozen() external view returns (bool);

    /// @notice Checks if a hook is registered
    /// @param hook The address of the hook to check
    /// @return True if the hook is registered, false otherwise
    function isHookRegistered(address hook) external view returns (bool);

    /// @notice Checks if a hook is registered as a fulfill requests hook
    /// @param hook The address of the hook to check
    /// @return True if the hook is registered as a fulfill requests hook, false otherwise
    function isFulfillRequestsHookRegistered(address hook) external view returns (bool);

    /// @notice Gets all registered hooks
    /// @return An array of registered hook addresses
    function getRegisteredHooks() external view returns (address[] memory);

    /// @notice Gets all registered fulfill requests hooks
    /// @return An array of registered fulfill requests hook addresses
    function getRegisteredFulfillRequestsHooks() external view returns (address[] memory);

    /// @notice Checks if an address is an approved validator
    /// @param validator The address to check
    /// @return True if the address is an approved validator, false otherwise
    function isValidator(address validator) external view returns (bool);

    /// @notice Checks if an address has the guardian role
    /// @param guardian Address to check
    /// @return true if the address has the GUARDIAN_ROLE
    function isGuardian(address guardian) external view returns (bool);

    /// @notice Checks if an address is an approved relayer
    /// @param relayer The address to check
    /// @return True if the address is an approved relayer, false otherwise
    function isRelayer(address relayer) external view returns (bool);

    /// @notice Checks if an address is an approved executor
    /// @param executor The address to check
    /// @return True if the address is an approved executor, false otherwise
    function isExecutor(address executor) external view returns (bool);

    /// @notice Returns all registered validators
    /// @return List of validator addresses
    function getValidators() external view returns (address[] memory);

    /// @notice Gets the proposed active PPS oracle and its effective time
    /// @return proposedOracle The proposed oracle address
    /// @return effectiveTime The timestamp when the proposed oracle will become effective
    function getProposedActivePPSOracle() external view returns (address proposedOracle, uint256 effectiveTime);

    /// @notice Gets the current quorum requirement for the active PPS Oracle
    /// @return The current quorum requirement
    function getPPSOracleQuorum() external view returns (uint256);

    /// @notice Gets the active PPS oracle
    /// @return The active PPS oracle address
    function getActivePPSOracle() external view returns (address);

    /// @notice Checks if an address is the current active PPS oracle
    /// @param oracle The address to check
    /// @return True if the address is the active PPS oracle, false otherwise
    function isActivePPSOracle(address oracle) external view returns (bool);

    /// @notice Gets the current fee value for a specific fee type
    /// @param feeType The type of fee to get
    /// @return The current fee value (in basis points)
    function getFee(FeeType feeType) external view returns (uint256);

    /// @notice Gets the current upkeep cost per update for PPS updates
    /// @return The current upkeep cost per update in UP tokens
    function getUpkeepCostPerUpdate() external view returns (uint256);

    /// @notice Gets the proposed upkeep cost per update and its effective time
    /// @return proposedCost The proposed new upkeep cost
    /// @return effectiveTime The timestamp when the new cost will become effective
    function getProposedUpkeepCostPerUpdate() external view returns (uint256 proposedCost, uint256 effectiveTime);

    /// @notice Returns the current Merkle root for a specific hook's allowed targets.
    /// @param hook The address of the hook to get the Merkle root for.
    /// @return The Merkle root for the hook's allowed targets.
    function getSuperBankHookMerkleRoot(address hook) external view returns (bytes32);

    /// @notice Returns the current Merkle root for a specific hook's allowed targets.
    /// @param hook The address of the hook to get the Merkle root for.
    /// @return The Merkle root for the hook's allowed targets.
    function getVaultBankHookMerkleRoot(address hook) external view returns (bytes32);

    /// @notice Gets the proposed Merkle root and its effective time for a specific hook.
    /// @param hook The address of the hook to get the proposed Merkle root for.
    /// @return proposedRoot The proposed Merkle root.
    /// @return effectiveTime The timestamp when the proposed root will become effective.
    function getProposedSuperBankHookMerkleRoot(address hook)
        external
        view
        returns (bytes32 proposedRoot, uint256 effectiveTime);

    /// @notice Gets the proposed Merkle root and its effective time for a specific hook.
    /// @param hook The address of the hook to get the proposed Merkle root for.
    /// @return proposedRoot The proposed Merkle root.
    /// @return effectiveTime The timestamp when the proposed root will become effective.
    function getProposedVaultBankHookMerkleRoot(address hook)
        external
        view
        returns (bytes32 proposedRoot, uint256 effectiveTime);

    /// @notice Gets the prover address
    /// @return The address of the prover
    function getProver() external view returns (address);

    /// @notice Checks if upkeep payments are currently enabled
    /// @return enabled True if upkeep payments are enabled
    function isUpkeepPaymentsEnabled() external view returns (bool);

    /// @notice Gets the proposed upkeep payments status and effective time
    /// @return enabled The proposed status
    /// @return effectiveTime The timestamp when the change becomes effective
    function getProposedUpkeepPaymentsStatus() external view returns (bool enabled, uint256 effectiveTime);

    /// @notice Checks if an address is a registered superform strategist
    /// @param strategist The address to check
    /// @return isSuperform True if the address is a superform strategist
    function isSuperformStrategist(address strategist) external view returns (bool);

    /// @notice Gets the list of all superform strategists
    /// @return strategists The list of all superform strategist addresses
    function getAllSuperformStrategists() external view returns (address[] memory);

    /// @notice Gets the SUP ID
    /// @return The ID of the SUP token
    function SUP() external view returns (bytes32);

    /// @notice Gets the UP ID
    /// @return The ID of the UP token
    function UP() external view returns (bytes32);

    /// @notice Gets the Treasury ID
    /// @return The ID for the Treasury in the registry
    function TREASURY() external view returns (bytes32);

    /// @notice Gets the SuperOracle ID
    /// @return The ID for the SuperOracle in the registry
    function SUPER_ORACLE() external view returns (bytes32);

    /// @notice Gets the BLS PPS Oracle ID
    /// @return The ID for the BLS PPS Oracle in the registry
    function BLSPPSORACLE() external view returns (bytes32);

    /// @notice Gets the ECDSA PPS Oracle ID
    /// @return The ID for the ECDSA PPS Oracle in the registry
    function ECDSAPPSORACLE() external view returns (bytes32);

    /// @notice Gets the SuperVaultAggregator ID
    /// @return The ID for the SuperVaultAggregator in the registry
    function SUPER_VAULT_AGGREGATOR() external view returns (bytes32);

    /// @notice Gets the SuperBank ID
    /// @return The ID for the SuperBank in the registry
    function SUPER_BANK() external view returns (bytes32);

    /// @notice Adds a strategist to the superform strategists list
    /// @param strategist Address of the strategist to add
    function addSuperformStrategist(address strategist) external;

    /// @notice Removes a strategist from the superform strategists list
    /// @param strategist Address of the strategist to remove
    function removeSuperformStrategist(address strategist) external;
}
