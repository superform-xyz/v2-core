// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";
import { SuperLedgerConfiguration } from "./SuperLedgerConfiguration.sol";
import { ISuperLedger } from "../interfaces/accounting/ISuperLedger.sol";
import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../interfaces/accounting/ISuperLedgerConfiguration.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title BaseLedger
/// @author Superform Labs
/// @notice Base ledger contract for managing user ledger entries
abstract contract BaseLedger is ISuperLedger {
    SuperLedgerConfiguration public immutable superLedgerConfiguration;
    ISuperRegistry public immutable superRegistry;

    mapping(address user => mapping(address yieldSource => uint256 shares)) public usersAccumulatorShares;
    mapping(address user => mapping(address yieldSource => uint256 costBasis)) public usersAccumulatorCostBasis;

    bytes32 internal constant SUPER_EXECUTOR_ID = keccak256("SUPER_EXECUTOR_ID");

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address superLedgerConfiguration_, address superRegistry_) {
        if (superLedgerConfiguration_ == address(0) || superRegistry_ == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        superLedgerConfiguration = SuperLedgerConfiguration(superLedgerConfiguration_);
        superRegistry = ISuperRegistry(superRegistry_);
    }

    modifier onlyExecutor() {
        if (!_isExecutorAllowed(msg.sender)) revert NOT_AUTHORIZED();
        _;
    }

    /// @inheritdoc ISuperLedger
    function updateAccounting(
        address user,
        address yieldSource,
        bytes4 yieldSourceOracleId,
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
        returns (uint256 costBasis)
    {
        uint256 accumulatorShares = usersAccumulatorShares[user][yieldSource];
        uint256 accumulatorCostBasis = usersAccumulatorCostBasis[user][yieldSource];

        if (usedShares > accumulatorShares) revert INSUFFICIENT_SHARES();

        costBasis = Math.mulDiv(accumulatorCostBasis, usedShares, accumulatorShares);
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
        uint256 costBasis = calculateCostBasisView(user, yieldSourceAddress, usedShares);
        feeAmount = _calculateFees(costBasis, amountAssets, feePercent);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    function _calculateCostBasis(
        address user,
        address yieldSource,
        uint256 usedShares
    )
        internal
        returns (uint256 costBasis)
    {
        costBasis = calculateCostBasisView(user, yieldSource, usedShares);

        usersAccumulatorShares[user][yieldSource] -= usedShares;
        usersAccumulatorCostBasis[user][yieldSource] -= costBasis;
    }

    function _processOutflow(
        address user,
        address yieldSource,
        uint256 amountAssets,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    )
        internal
        virtual
        returns (uint256 feeAmount)
    {
        uint256 costBasis = _calculateCostBasis(user, yieldSource, usedShares);
        feeAmount = _calculateFees(costBasis, amountAssets, config.feePercent);
    }

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

    function _updateAccounting(
        address user,
        address yieldSource,
        bytes4 yieldSourceOracleId,
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
            return 0;
        } else {
            // Only process outflow if feePercent is not set to 0
            if (config.feePercent != 0) {
                uint256 amountAssets = _getOutflowProcessVolume(
                    amountSharesOrAssets,
                    usedShares,
                    pps,
                    IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource)
                );

                feeAmount = _processOutflow(user, yieldSource, amountAssets, usedShares, config);

                emit AccountingOutflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, feeAmount);
                return feeAmount;
            } else {
                emit AccountingOutflowSkipped(user, yieldSource, yieldSourceOracleId, amountSharesOrAssets);
                return 0;
            }
        }
    }

    function _getAddress(bytes32 id_) internal view returns (address) {
        return superRegistry.getAddress(id_);
    }

    function _isExecutorAllowed(address executor) internal view returns (bool) {
        return superRegistry.isExecutorAllowed(executor);
    }
}
