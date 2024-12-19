// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ISuperActions {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct LedgerEntry {
        uint256 amountSharesAvailableToConsume;
        uint256 price;
    }

    struct ActionLogic {
        bytes32 yieldSourceId;
        address[] hooks;
    }

    struct StrategyConfig {
        uint256 feePercent;
        address vaultShareToken;
    }

    struct YieldSourceData {
        address oracle;
        uint256[] actionIds;
    }
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NOT_AUTHORIZED();
    error INVALID_ARRAY_LENGTH();
    error ACTION_NOT_FOUND();
    error INVALID_HOOKS_LENGTH();
    error ZERO_ADDRESS_NOT_ALLOWED();
    error ACTION_ALREADY_EXISTS();
    error FEE_NOT_SET();
    error INVALID_VAULT_SHARE_TOKEN();
    error INSUFFICIENT_SHARES();
    error INVALID_PRICE();
    error YIELD_SOURCE_NOT_FOUND();
    error YIELD_SOURCE_ALREADY_EXISTS();
    error EMPTY_YIELD_SOURCE_ID();
    error INVALID_FEE_PERCENT();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event AccountingUpdated(
        address indexed user_,
        uint256 indexed actionId_,
        address indexed finalTarget_,
        bool isDeposit_,
        uint256 amountShares_,
        uint256 pps_
    );
    event BatchAccountingUpdated(
        address indexed user_,
        uint256[] actionIds_,
        address[] finalTargets_,
        bool[] isDeposits_,
        uint256[] amountsShares_,
        uint256[] pps_
    );
    event ActionRegistered(uint256 indexed actionId_, address[] hooks_, string yieldSourceId_);
    event ActionBatchRegistered(uint256[] indexed actionIds_, string[] yieldSourceIds_);
    event ActionUpdated(uint256 indexed actionId_, address[] hooks_, string yieldSourceId_);
    event ActionBatchUpdated(uint256[] indexed actionIds_, address[][] hooks_, string[] yieldSourceIds_);
    event ActionDelisted(uint256 indexed actionId_);
    event ActionBatchDelisted(uint256[] indexed actionIds_);
    event StrategyConfigSet(
        string indexed yieldSourceId, address indexed finalTarget, uint256 feePercent, address vaultShareToken
    );
    event YieldSourceRegistered(string indexed yieldSourceId_, address metadataOracle_);
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates accounting for a single action
    /// @param user_ The user address
    /// @param actionId_ The ID of the action
    /// @param finalTarget_ The target contract address
    /// @param isDeposit_ Whether this is a deposit operation
    /// @param amountShares_ The amount of shares minted or burned to update
    /// @return pps_ The price per share at which the accounting was updated
    function updateAccounting(
        address user_,
        uint256 actionId_,
        address finalTarget_,
        bool isDeposit_,
        uint256 amountShares_
    )
        external
        returns (uint256 pps_);

    /// @notice Updates accounting for multiple actions in batch
    /// @param user_ The user address
    /// @param actionIds_ Array of action IDs
    /// @param finalTargets_ Array of target contract addresses
    /// @param isDeposits_ Array of deposit flags
    /// @param amountsShares_ Array of amounts to update
    /// @return pps_ Array of prices per share at which the accounting was updated
    function batchUpdateAccounting(
        address user_,
        uint256[] memory actionIds_,
        address[] memory finalTargets_,
        bool[] memory isDeposits_,
        uint256[] memory amountsShares_
    )
        external
        returns (uint256[] memory pps_);

    /// @notice Registers a new action
    /// @param hooks_ Array of hook addresses
    /// @param yieldSourceId_ The yield source identifier
    function registerAction(
        address[] memory hooks_,
        string calldata yieldSourceId_
    )
        external
        returns (uint256 actionId_);

    /// @notice Registers multiple actions in a batch
    /// @param hooks_ Array of hook address arrays for each action
    /// @param yieldSourceIds_ Array of yield source identifiers
    function batchRegisterActions(
        address[][] memory hooks_,
        string[] calldata yieldSourceIds_
    )
        external
        returns (uint256[] memory actionIds_);

    /// @notice Updates both the oracle and hooks for an existing action
    /// @param actionId_ The ID of the action
    /// @param yieldSourceId_ The yield source identifier
    /// @param newHooks_ The new array of hook addresses
    function updateAction(uint256 actionId_, string calldata yieldSourceId_, address[] memory newHooks_) external;

    /// @notice Updates both oracle and hooks for multiple actions in a batch
    /// @param actionIds_ Array of action IDs
    /// @param yieldSourceIds_ Array of yield source identifiers
    /// @param newHooks_ Array of arrays containing new hook addresses
    function batchUpdateAction(
        uint256[] memory actionIds_,
        string[] calldata yieldSourceIds_,
        address[][] memory newHooks_
    )
        external;

    /// @notice Delists an action
    /// @param actionId_ The ID of the action to delist
    function delistAction(uint256 actionId_) external;

    /// @notice Delists multiple actions in a batch
    /// @param actionIds_ Array of action IDs to delist
    function batchDelistActions(uint256[] memory actionIds_) external;

    /// @notice Registers a new yield source
    /// @param yieldSourceId_ The yield source identifier
    /// @param metadataOracle_ The oracle address
    function registerYieldSource(string calldata yieldSourceId_, address metadataOracle_) external;

    /// @notice Registers multiple yield sources in a batch
    /// @param yieldSourceIds_ Array of yield source identifiers
    /// @param metadataOracles_ Array of oracle addresses
    function batchRegisterYieldSources(
        string[] calldata yieldSourceIds_,
        address[] calldata metadataOracles_
    )
        external;

    /// @notice Sets the strategy config for a single yield source and target pair
    /// @param yieldSourceId_ The yield source identifier
    /// @param finalTarget_ The target contract address
    /// @param feePercent_ The fee percentage
    /// @param vaultShareToken_ The vault share token address
    function setStrategyConfig(
        string calldata yieldSourceId_,
        address finalTarget_,
        uint256 feePercent_,
        address vaultShareToken_
    )
        external;

    /// @notice Sets the strategy config for multiple yield sources and target pairs in a batch
    /// @param yieldSourceIds_ Array of yield source identifiers
    /// @param finalTargets_ Array of target contract addresses
    /// @param feePercents_ Array of fee percentages
    /// @param vaultShareTokens_ Array of vault share token addresses
    function batchSetStrategyConfig(
        string[] calldata yieldSourceIds_,
        address[] memory finalTargets_,
        uint256[] memory feePercents_,
        address[] memory vaultShareTokens_
    )
        external;

    /// @notice Retrieves all action IDs associated with a specific yield source
    /// @param yieldSourceId_ The yield source identifier
    /// @return Array of action IDs
    function getActionsByYieldSource(string calldata yieldSourceId_) external view returns (uint256[] memory);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves hooks for a specific action
    /// @param actionId_ The ID of the action
    /// @return hooks_ Array of hook addresses
    function getHooksForAction(uint256 actionId_) external view returns (address[] memory hooks_);

    /// @notice Retrieves logic for a specific action
    /// @param actionId_ The ID of the action
    /// @return logic_ The action logic
    function getActionLogic(uint256 actionId_) external view returns (ActionLogic memory logic_);

    /// @notice Gets the oracle address for a specific action
    /// @param actionId_ The ID of the action
    /// @return oracle_ The oracle address
    function getOracleForAction(uint256 actionId_) external view returns (address oracle_);

    /// @notice Gets metadata for multiple strategies
    /// @param actionIds_ Array of action IDs
    /// @param finalTargets_ Array of target addresses
    /// @return result_ Array of metadata bytes
    function getStrategiesMetadata(
        uint256[] memory actionIds_,
        address[] memory finalTargets_
    )
        external
        view
        returns (bytes[] memory result_);

    /// @notice Checks if an action is active
    /// @param actionId_ The ID of the action to check
    /// @return bool indicating if the action is active
    function isActionActive(uint256 actionId_) external view returns (bool);

    /// @notice Gets accounting information for a user
    /// @param user_ The user address
    /// @param yieldSourceId_ The yield source identifier
    /// @param finalTarget_ The target contract address
    /// @return Array of ledger entries
    function getUserAccounting(
        address user_,
        string calldata yieldSourceId_,
        address finalTarget_
    )
        external
        view
        returns (LedgerEntry[] memory);

    /// @notice Get the number of unconsumed entries for a specific user, action, and target
    /// @param user_ The user address
    /// @param yieldSourceId_ The yield source identifier
    /// @param finalTarget_ The target contract address
    /// @return The number of unconsumed entries
    function getUnconsumedEntries(
        address user_,
        string calldata yieldSourceId_,
        address finalTarget_
    )
        external
        view
        returns (uint256);

    /// @notice Get the fee percentage for a specific action and target
    /// @param yieldSourceId_ The yield source identifier
    /// @param finalTarget_ The target contract address
    /// @return The strategy config
    function getStrategyConfig(
        string calldata yieldSourceId_,
        address finalTarget_
    )
        external
        view
        returns (StrategyConfig memory);
}
