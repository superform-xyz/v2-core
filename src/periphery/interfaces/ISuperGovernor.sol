// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title ISuperGovernor
/// @author Superform Labs
/// @notice Interface for the SuperGovernor contract
/// @dev Central registry for all deployed contracts in the Superform periphery
interface ISuperGovernor {
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
    /// @notice Thrown when timelock period has not expired
    error TIMELOCK_NOT_EXPIRED();
    /// @notice Thrown when a validator is not registered
    error VALIDATOR_NOT_REGISTERED();
    /// @notice Thrown when a validator is already registered
    error VALIDATOR_ALREADY_REGISTERED();
    /// @notice Thrown when a PPS oracle is not registered
    error PPS_ORACLE_NOT_REGISTERED();
    /// @notice Thrown when a PPS oracle is already registered
    error PPS_ORACLE_ALREADY_REGISTERED();
    /// @notice Thrown when strategist is already registered
    error STRATEGIST_ALREADY_REGISTERED();
    /// @notice Thrown when strategist is not registered but expected to be
    error STRATEGIST_NOT_REGISTERED();
    /// @notice Thrown when a SuperBank hook Merkle root is not registered but expected to be
    error INVALID_TIMESTAMP();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when an address is set in the registry
    /// @param key The key used to reference the address
    /// @param value The address value
    event AddressSet(bytes32 indexed key, address indexed value);

    /// @notice Emitted when an address is removed from the registry
    /// @param key The key of the removed address
    event AddressRemoved(bytes32 indexed key);

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

    /// @notice Emitted when a PPS oracle is added
    /// @param oracle Address of the PPS oracle
    event PPSOracleAdded(address indexed oracle);

    /// @notice Emitted when a PPS oracle is removed
    /// @param oracle Address of the PPS oracle
    event PPSOracleRemoved(address indexed oracle);

    /// @notice Emitted when revenue share is updated
    /// @param share The new revenue share percentage
    event RevenueShareUpdated(uint256 share);

    /// @notice Emitted when revenue share update is proposed
    /// @param share The proposed revenue share percentage
    /// @param effectiveTime The time when the update will be effective
    event RevenueShareProposed(uint256 share, uint256 effectiveTime);

    /// @notice Emitted when a new SuperBank hook Merkle root is proposed.
    /// @param hook The hook address for which the Merkle root is being proposed.
    /// @param proposedRoot The proposed new Merkle root.
    /// @param effectiveTime The timestamp when the proposed root will become effective.
    event SuperBankHookMerkleRootProposed(address indexed hook, bytes32 proposedRoot, uint256 effectiveTime);

    /// @notice Emitted when the SuperBank hook Merkle root is updated.
    /// @param hook The hook address for which the Merkle root was updated.
    /// @param newRoot The new Merkle root.
    event SuperBankHookMerkleRootUpdated(address indexed hook, bytes32 newRoot);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets an address in the registry
    /// @param key The key to associate with the address
    /// @param value The address value
    function setAddress(bytes32 key, address value) external;

    /// @notice Removes an address from the registry
    /// @param key The key of the address to remove
    function removeAddress(bytes32 key) external;

    /// @notice Gets an address from the registry
    /// @param key The key of the address to get
    /// @return The address value
    function getAddress(bytes32 key) external view returns (address);

    /// @notice Registers a hook for use in SuperVaults
    /// @param hook The address of the hook to register
    /// @param isFulfillRequestsHook Whether the hook is a fulfill requests hook
    function registerHook(address hook, bool isFulfillRequestsHook) external;

    /// @notice Unregisters a hook from the approved list
    /// @param hook The address of the hook to unregister
    /// @param isFulfillRequestsHook Whether the hook is a fulfill requests hook
    function unregisterHook(address hook, bool isFulfillRequestsHook) external;

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

    /// @notice Adds a strategist to the approved list
    /// @param strategist The address of the strategist to add
    function addStrategist(address strategist) external;

    /// @notice Removes a strategist from the approved list
    /// @param strategist The address of the strategist to remove
    function removeStrategist(address strategist) external;

    /// @notice Checks if an address is an approved strategist
    /// @param strategist The address to check
    /// @return True if the address is an approved strategist, false otherwise
    function isStrategist(address strategist) external view returns (bool);

    /// @notice Returns all registered strategists
    /// @return List of strategist addresses
    function getStrategists() external view returns (address[] memory);

    /// @notice Adds a validator to the approved list
    /// @param validator The address of the validator to add
    function addValidator(address validator) external;

    /// @notice Removes a validator from the approved list
    /// @param validator The address of the validator to remove
    function removeValidator(address validator) external;

    /// @notice Checks if an address is an approved validator
    /// @param validator The address to check
    /// @return True if the address is an approved validator, false otherwise
    function isValidator(address validator) external view returns (bool);

    /// @notice Returns all registered validators
    /// @return List of validator addresses
    function getValidators() external view returns (address[] memory);

    /// @notice Adds a PPS oracle to the registry
    /// @param oracle Address of the PPS oracle to add
    function addPPSOracle(address oracle) external;

    /// @notice Removes a PPS oracle from the registry
    /// @param oracle Address of the PPS oracle to remove
    function removePPSOracle(address oracle) external;

    /// @notice Checks if an address is a registered PPS oracle
    /// @param oracle Address to check
    /// @return True if the address is a registered PPS oracle
    function isPPSOracle(address oracle) external view returns (bool);

    /// @notice Returns all registered PPS oracles
    /// @return List of PPS oracle addresses
    function getPPSOracles() external view returns (address[] memory);

    /// @notice Proposes a new revenue share to be set after timelock
    /// @param share The share to be set (in basis points)
    function proposeRevenueShare(uint256 share) external;

    /// @notice Executes a previously proposed revenue share update after timelock
    function executeRevenueShareUpdate() external;

    /// @notice Gets the current revenue share
    /// @return The current revenue share (in basis points)
    function getRevenueShare() external view returns (uint256);

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

    /// @notice Returns the current Merkle root for a specific hook's allowed targets.
    /// @param hook The address of the hook to get the Merkle root for.
    /// @return The Merkle root for the hook's allowed targets.
    function getSuperBankHookMerkleRoot(address hook) external view returns (bytes32);

    /// @notice Proposes a new Merkle root for a specific hook's allowed targets.
    /// @param hook The address of the hook to update the Merkle root for.
    /// @param proposedRoot The proposed new Merkle root.
    /// @param delay The time delay in seconds before the new root becomes effective.
    function proposeSuperBankHookMerkleRoot(address hook, bytes32 proposedRoot, uint256 delay) external;

    /// @notice Executes a previously proposed Merkle root update for a specific hook if the effective time has passed.
    /// @param hook The address of the hook to execute the update for.
    /// @return success True if the update was executed successfully.
    function executeSuperBankHookMerkleRootUpdate(address hook) external returns (bool success);

    /// @notice Gets the proposed Merkle root and its effective time for a specific hook.
    /// @param hook The address of the hook to get the proposed Merkle root for.
    /// @return proposedRoot The proposed Merkle root.
    /// @return effectiveTime The timestamp when the proposed root will become effective.
    function getProposedSuperBankHookMerkleRoot(address hook)
        external
        view
        returns (bytes32 proposedRoot, uint256 effectiveTime);
}
