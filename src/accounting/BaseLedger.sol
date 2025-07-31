// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// Superform
import { SuperLedgerConfiguration } from "./SuperLedgerConfiguration.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title BaseLedger
/// @author Superform Labs
/// @notice Base ledger contract for managing user yield accounting and fee calculations
/// @dev Implements the ISuperLedger interface to provide share tracking and yield fee accounting
///      Uses a cost basis tracking system to accurately calculate yield on user positions
///      Relies on yield source oracles to determine asset prices for accounting calculations
abstract contract BaseLedger is ISuperLedger {
    /// @notice The configuration contract that stores yield source oracle settings
    /// @dev Provides oracle addresses, fee percentages, and manager information
    SuperLedgerConfiguration public immutable superLedgerConfiguration;

    /// @notice Tracks the total shares each user has for each yield source
    /// @dev Used for calculating proportional cost basis when consuming partial positions
    mapping(address user => mapping(address yieldSource => uint256 shares)) public usersAccumulatorShares;

    /// @notice Tracks the total cost basis (in asset terms) for each user's yield source position
    /// @dev Cost basis represents the acquisition value used to determine yield for fee calculations
    mapping(address user => mapping(address yieldSource => uint256 costBasis)) public usersAccumulatorCostBasis;

    /// @notice Tracks which addresses are allowed to execute accounting operations
    /// @dev Only allowed executors can update user accounting records
    mapping(address executor => bool isAllowed) public allowedExecutors;
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructs the BaseLedger with configuration and authorized executors
    /// @dev Initializes the ledger with configuration and a list of allowed executors
    /// @param superLedgerConfiguration_ Address of the ledger configuration contract
    /// @param allowedExecutors_ Array of addresses authorized to execute accounting updates
    constructor(address superLedgerConfiguration_, address[] memory allowedExecutors_) {
        if (superLedgerConfiguration_ == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        superLedgerConfiguration = SuperLedgerConfiguration(superLedgerConfiguration_);
        uint256 len = allowedExecutors_.length;
        for (uint256 i; i < len; ++i) {
            allowedExecutors[allowedExecutors_[i]] = true;
        }
    }

    /// @notice Restricts function access to authorized executors only
    /// @dev Checks if the caller is in the allowedExecutors mapping
    modifier onlyExecutor() {
        if (!_isExecutorAllowed(msg.sender)) revert NOT_AUTHORIZED();
        _;
    }

    /// @inheritdoc ISuperLedger
    function updateAccounting(
        address user,
        address yieldSource,
        bytes32 yieldSourceOracleId,
        bool isInflow,
        uint256 amountSharesOrAssets,
        uint256 usedShares
    )
        external
        returns (uint256 feeAmount)
    {
        return _updateAccounting(user, yieldSource, yieldSourceOracleId, isInflow, amountSharesOrAssets, usedShares);
    }

    /// @inheritdoc ISuperLedger
    function calculateCostBasisView(
        address user,
        address yieldSource,
        uint256 usedShares
    )
        public
        view
        returns (uint256 costBasis, uint256 shares)
    {
        uint256 accumulatorShares = usersAccumulatorShares[user][yieldSource];
        uint256 accumulatorCostBasis = usersAccumulatorCostBasis[user][yieldSource];

        if (usedShares > accumulatorShares) {
            // take fees only for used shares
            usedShares = accumulatorShares;
        }

        costBasis = usedShares > 0 ? Math.mulDiv(accumulatorCostBasis, usedShares, accumulatorShares) : 0;
        shares = usedShares;
    }

    /// @inheritdoc ISuperLedger
    function previewFees(
        address user,
        address yieldSourceAddress,
        uint256 amountAssets,
        uint256 usedShares,
        uint256 feePercent
    )
        public
        view
        returns (uint256 feeAmount)
    {
        (uint256 costBasis,) = calculateCostBasisView(user, yieldSourceAddress, usedShares);
        feeAmount = _calculateFees(costBasis, amountAssets, feePercent);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Records share acquisition in the user's ledger
    /// @dev Updates the user's accumulator values when new shares are added
    ///      Cost basis is calculated using the current price per share
    /// @param user Address of the user receiving shares
    /// @param amountShares Amount of shares being added to the user's position
    /// @param yieldSource Address of the yield-bearing asset
    /// @param pps Current price per share of the yield source
    /// @param decimals Decimal precision of the yield source
    function _takeSnapshot(
        address user,
        uint256 amountShares,
        address yieldSource,
        uint256 pps,
        uint256 decimals
    )
        internal
        virtual
    {
        usersAccumulatorShares[user][yieldSource] += amountShares;
        usersAccumulatorCostBasis[user][yieldSource] += Math.mulDiv(amountShares, pps, 10 ** decimals);
    }

    /// @notice Determines the volume to use for outflow fee calculations
    /// @dev Can be overridden by derived contracts to implement different volume calculation strategies
    ///      In the base implementation, simply returns the input amount unchanged
    /// @param amountSharesOrAssets The amount of shares or assets being withdrawn
    /// @return The volume to use for fee calculations
    function _getOutflowProcessVolume(
        uint256 amountSharesOrAssets,
        uint256,
        uint256,
        uint8
    )
        internal
        pure
        virtual
        returns (uint256)
    {
        return amountSharesOrAssets;
    }

    /// @notice Calculates and updates the cost basis for consumed shares
    /// @dev Retrieves the cost basis for the shares being used and updates the user's accumulators
    ///      Proportionally reduces both shares and cost basis in the user's accounting records
    /// @param user Address of the user consuming shares
    /// @param yieldSource Address of the yield-bearing asset
    /// @param usedShares Amount of shares being consumed
    /// @return costBasis The calculated cost basis for the consumed shares
    function _calculateCostBasis(
        address user,
        address yieldSource,
        uint256 usedShares
    )
        internal
        returns (uint256 costBasis, uint256 updatedUsedShares)
    {
        (costBasis, updatedUsedShares) = calculateCostBasisView(user, yieldSource, usedShares);
        if (updatedUsedShares != usedShares) {
            emit UsedSharesCapped(usedShares, updatedUsedShares);
        }

        usersAccumulatorShares[user][yieldSource] -= updatedUsedShares;
        usersAccumulatorCostBasis[user][yieldSource] -= costBasis;
    }

    /// @notice Processes an outflow operation and calculates associated fees
    /// @dev Gets the cost basis for consumed shares and calculates fees on any yield generated
    ///      Updates user accounting records to reflect the share consumption
    /// @param user Address of the user withdrawing shares
    /// @param yieldSource Address of the yield-bearing asset
    /// @param amountAssets Current value of the shares in asset terms
    /// @param usedShares Amount of shares being consumed
    /// @param config Configuration for the yield source oracle
    /// @param pps Price per share of the yield source
    /// @param decimals Decimals of the yield source
    /// @return feeAmount The calculated fee amount based on yield generated
    function _processOutflow(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config,
        uint256 pps,
        uint8 decimals
    )
        internal
        virtual
        returns (uint256 feeAmount)
    {
        (uint256 costBasis, uint256 updatedUsedShares) = _calculateCostBasis(user, yieldSource, usedShares);

        /// @dev if a user performs a deposit outside superform, his shares were truncated in L87. Likewise we use the
        /// truncated shares to roll back to the original asset amount that belongs to an action done through superform
        /// core v2
        if (usedShares != updatedUsedShares) {
            amountAssets = Math.mulDiv(updatedUsedShares, pps, 10 ** decimals);
        }
        if (config.feePercent > 0) {
            feeAmount = _calculateFees(costBasis, amountAssets, config.feePercent);
        }
    }

    /// @notice Calculates performance fees based on realized profit
    /// @dev Compares current asset value to cost basis to determine profit
    ///      Applies the fee percentage to any positive profit amount
    ///      Uses basis points (10,000 = 100%) for fee percentage
    /// @param costBasis Original acquisition value of the shares
    /// @param amountAssets Current value of the shares in asset terms
    /// @param feePercent Fee percentage in basis points (e.g., 1000 = 10%)
    /// @return feeAmount The calculated fee amount based on profit
    function _calculateFees(
        uint256 costBasis,
        uint256 amountAssets,
        uint256 feePercent
    )
        internal
        pure
        virtual
        returns (uint256 feeAmount)
    {
        uint256 profit = amountAssets > costBasis ? amountAssets - costBasis : 0;
        if (profit > 0) {
            if (feePercent == 0) revert FEE_NOT_SET();
            feeAmount = Math.mulDiv(profit, feePercent, 10_000);
        }
    }

    /// @notice Core accounting function that processes inflows and outflows
    /// @dev Handles both deposit (inflow) and withdrawal (outflow) accounting:
    ///      - For inflows: Records new share acquisition with current price
    ///      - For outflows: Calculates fees based on yield and updates records
    ///      This is the central function that integrates with oracles for pricing
    ///      and tracks user positions for accurate yield calculation
    /// @param user Address of the user whose accounting is being updated
    /// @param yieldSource Address of the yield-bearing asset being processed
    /// @param yieldSourceOracleId Identifier for the oracle providing price data
    /// @param isInflow True if this is a deposit, false if withdrawal
    /// @param amountSharesOrAssets Amount of shares (for inflow) or assets (for outflow)
    /// @param usedShares Number of shares consumed (only used for outflows)
    /// @return feeAmount The calculated fee amount (zero for inflows)
    function _updateAccounting(
        address user,
        address yieldSource,
        bytes32 yieldSourceOracleId,
        bool isInflow,
        uint256 amountSharesOrAssets,
        uint256 usedShares
    )
        internal
        virtual
        onlyExecutor
        returns (uint256 feeAmount)
    {
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config =
            superLedgerConfiguration.getYieldSourceOracleConfig(yieldSourceOracleId);

        if (config.manager == address(0)) revert MANAGER_NOT_SET();
        if (config.ledger != address(this)) revert INVALID_LEDGER();

        // Get price from oracle
        uint256 pps = IYieldSourceOracle(config.yieldSourceOracle).getPricePerShare(yieldSource);
        if (pps == 0) revert INVALID_PRICE();

        if (isInflow) {
            _takeSnapshot(
                user,
                amountSharesOrAssets,
                yieldSource,
                pps,
                IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource)
            );

            emit AccountingInflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, pps);
        } else {
            uint8 decimals = IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource);
            uint256 amountAssets = _getOutflowProcessVolume(amountSharesOrAssets, usedShares, pps, decimals);

            feeAmount = _processOutflow(user, yieldSource, amountAssets, usedShares, config, pps, decimals);

            emit AccountingOutflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, feeAmount);
            return feeAmount;
        }
    }

    /// @notice Checks if an address is authorized to execute accounting operations
    /// @dev Used by the onlyExecutor modifier to validate caller permissions
    /// @param executor Address to check for executor permissions
    /// @return True if the address is an allowed executor, false otherwise
    function _isExecutorAllowed(address executor) internal view returns (bool) {
        return allowedExecutors[executor];
    }
}
