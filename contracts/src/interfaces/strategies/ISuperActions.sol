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
        address metadataOracle;
        address[] hooks;
    }

    struct StrategyConfig {
        uint256 feePercent;
        address vaultShareToken;
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
    event ActionDelisted(uint256 indexed actionId_);
    event ActionRegistered(uint256 indexed actionId_, address[] hooks_, address metadataOracle_);
    event ActionOracleUpdated(uint256 indexed actionId_, address metadataOracle_);
    event ActionHooksUpdated(uint256 indexed actionId_, address[] hooks_);
    event ActionBatchRegistered(uint256[] actionIds_);
    event ActionBatchDelisted(uint256[] actionIds_);
    event StrategyConfigSet(
        uint256 indexed actionId, address indexed finalTarget, uint256 feePercent, address vaultShareToken
    );
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
    /// @param metadataOracle_ The oracle address for the action
    function registerAction(address[] memory hooks_, address metadataOracle_) external returns (uint256 actionId_);

    /// @notice Registers multiple actions in a batch
    /// @param hooks_ Array of hook address arrays for each action
    /// @param metadataOracles_ Array of oracle addresses for each action
    function batchRegisterActions(
        address[][] memory hooks_,
        address[] memory metadataOracles_
    )
        external
        returns (uint256[] memory actionIds_);

    /// @notice Updates both the oracle and hooks for an existing action
    /// @param actionId_ The ID of the action
    /// @param metadataOracle_ The new oracle address
    /// @param newHooks_ The new array of hook addresses
    function updateAction(uint256 actionId_, address metadataOracle_, address[] memory newHooks_) external;

    /// @notice Updates both oracle and hooks for multiple actions in a batch
    /// @param actionIds_ Array of action IDs
    /// @param metadataOracles_ Array of new oracle addresses
    /// @param newHooks_ Array of arrays containing new hook addresses
    function batchUpdateAction(
        uint256[] memory actionIds_,
        address[] memory metadataOracles_,
        address[][] memory newHooks_
    )
        external;

    /// @notice Delists an action
    /// @param actionId_ The ID of the action to delist
    function delistAction(uint256 actionId_) external;

    /// @notice Delists multiple actions in a batch
    /// @param actionIds_ Array of action IDs to delist
    function batchDelistActions(uint256[] memory actionIds_) external;

    /// @notice Sets the strategy config for a single action and target pair
    /// @param actionId_ The ID of the action
    /// @param finalTarget_ The target contract address
    /// @param feePercent_ The fee percentage
    /// @param vaultShareToken_ The vault share token address
    function setStrategyConfig(
        uint256 actionId_,
        address finalTarget_,
        uint256 feePercent_,
        address vaultShareToken_
    )
        external;

    /// @notice Sets the strategy config for multiple actions and target pairs in a batch
    /// @param actionIds_ Array of action IDs
    /// @param finalTargets_ Array of target contract addresses
    /// @param feePercents_ Array of fee percentages
    /// @param vaultShareTokens_ Array of vault share token addresses
    function batchSetStrategyConfig(
        uint256[] memory actionIds_,
        address[] memory finalTargets_,
        uint256[] memory feePercents_,
        address[] memory vaultShareTokens_
    )
        external;
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

    /// @notice Retrieves hooks for multiple actions
    /// @param actionIds_ Array of action IDs
    /// @return hooksForActions_ Array of arrays containing hook addresses
    function getHooksForActions(uint256[] memory actionIds_)
        external
        view
        returns (address[][] memory hooksForActions_);

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
    /// @param actionId_ The ID of the action
    /// @param finalTarget_ The target contract address
    /// @return Array of ledger entries
    function getUserAccounting(
        address user_,
        uint256 actionId_,
        address finalTarget_
    )
        external
        view
        returns (LedgerEntry[] memory);

    /// @notice Get the number of unconsumed entries for a specific user, action, and target
    /// @param user_ The user address
    /// @param actionId_ The ID of the action
    /// @param finalTarget_ The target contract address
    /// @return The number of unconsumed entries
    function getUnconsumedEntries(
        address user_,
        uint256 actionId_,
        address finalTarget_
    )
        external
        view
        returns (uint256);

    /// @notice Get the fee percentage for a specific action and target
    /// @param actionId_ The ID of the action
    /// @param finalTarget_ The target contract address
    /// @return The strategy config
    function getStrategyConfig(uint256 actionId_, address finalTarget_) external view returns (StrategyConfig memory);
}
