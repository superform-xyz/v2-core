// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperLedgerData
/// @author Superform Labs
/// @notice Interface for the SuperLedgerData contract that manages ledger data
interface ISuperLedgerData {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct LedgerEntry {
        uint256 amountSharesAvailableToConsume;
        uint256 price;
    }

    struct Ledger {
        LedgerEntry[] entries;
        uint256 unconsumedEntries;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AccountingInflow(
        address indexed user,
        address indexed yieldSourceOracle,
        address indexed yieldSource,
        uint256 amount,
        uint256 pps
    );
    event AccountingOutflow(
        address indexed user,
        address indexed yieldSourceOracle,
        address indexed yieldSource,
        uint256 amount,
        uint256 feeAmount
    );

    event AccountingOutflowSkipped(
        address indexed user, address indexed yieldSource, bytes32 indexed yieldSourceOracleId, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error HOOK_NOT_FOUND();
    error INSUFFICIENT_SHARES();
    error INVALID_PRICE();
    error FEE_NOT_SET();
    error INVALID_FEE_PERCENT();
    error ZERO_ADDRESS_NOT_ALLOWED();
    error NOT_AUTHORIZED();
    error NOT_MANAGER();
    error MANAGER_NOT_SET();
    error ZERO_LENGTH();
    error ZERO_ID_NOT_ALLOWED();
}

/// @title ISuperHookRegistry
/// @notice Interface for the SuperHookRegistry contract that manages yield source hooks and their accounting
interface ISuperLedger is ISuperLedgerData {
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Updates accounting for a user's yield source interaction
    /// @param user The user address
    /// @param yieldSource The yield source address
    /// @param yieldSourceOracleId The yield source id
    /// @param isInflow Whether this is an inflow (true) or outflow (false)
    /// @param amountSharesOrAssets The amount of shares or assets
    /// @param usedShares The amount of shares used by the OUTFLOW hook (0 for INFLOWS)
    /// @return feeAmount The amount of fee to be collected in the asset being withdrawn (only for outflows)
    function updateAccounting(
        address user,
        address yieldSource,
        bytes4 yieldSourceOracleId,
        bool isInflow,
        uint256 amountSharesOrAssets,
        uint256 usedShares
    )
        external
        returns (uint256 feeAmount);

    function previewFees(
        address user,
    // TODO: Remove
//        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        uint256 feePercent
    )
        external
        view
        returns (uint256);
}
