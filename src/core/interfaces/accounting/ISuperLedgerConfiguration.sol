// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperLedgerConfiguration
/// @author Superform Labs
/// @notice Interface for the SuperLedgerConfiguration contract that manages yield source oracles
interface ISuperLedgerConfiguration {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct YieldSourceOracleConfig {
        address yieldSourceOracle;
        uint256 feePercent;
        address feeRecipient;
        address manager;
        address ledger;
    }

    struct YieldSourceOracleConfigArgs {
        bytes4 yieldSourceOracleId;
        address yieldSourceOracle;
        uint256 feePercent;
        address feeRecipient;
        address ledger;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS 
    //////////////////////////////////////////////////////////////*/
    error NOT_MANAGER();
    error ZERO_LENGTH();
    error ZERO_ID_NOT_ALLOWED();
    error INVALID_FEE_PERCENT();
    error ZERO_ADDRESS_NOT_ALLOWED();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event YieldSourceOracleConfigSet(
        bytes4 indexed yieldSourceOracleId,
        address indexed yieldSourceOracle,
        uint256 feePercent,
        address manager,
        address feeRecipient,
        address ledger
    );

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Registers hooks and sets their oracle configs in one transaction
    /// @param configs Array of oracle configurations
    function setYieldSourceOracles(YieldSourceOracleConfigArgs[] calldata configs) external;

    /// @notice Returns the configuration for a yield source oracle
    /// @param yieldSourceOracleId The yield source id
    /// @return The oracle configuration
    function getYieldSourceOracleConfig(bytes4 yieldSourceOracleId)
        external
        view
        returns (YieldSourceOracleConfig memory);

    /// @notice Returns the configurations for multiple yield source oracles
    /// @param yieldSourceOracleIds The array of yield source ids
    /// @return The array of oracle configurations
    function getYieldSourceOracleConfigs(bytes4[] calldata yieldSourceOracleIds)
        external
        view
        returns (YieldSourceOracleConfig[] memory);
}
