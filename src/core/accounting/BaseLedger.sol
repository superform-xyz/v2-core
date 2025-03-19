// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
    using SafeERC20 for IERC20;

    SuperLedgerConfiguration public immutable superLedgerConfiguration;

    mapping(address user => uint256) public usersAccumulatorShares;
    mapping(address user => uint256) public usersAccumulatorCostBasis;

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address superLedgerConfiguration_) {
        if (superLedgerConfiguration_ == address(0)) revert ZERO_ADDRESS_NOT_ALLOWED();
        superLedgerConfiguration = SuperLedgerConfiguration(superLedgerConfiguration_);
    }

    modifier onlyExecutor() {
        if (_getAddress(keccak256("SUPER_EXECUTOR_ID")) != msg.sender) revert NOT_AUTHORIZED();
        _;
    }

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

    function _getAddress(bytes32 id_) internal view returns (address) {
        ISuperRegistry registry = ISuperRegistry(superLedgerConfiguration.superRegistry());
        return registry.getAddress(id_);
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    ///// AVG Implementation /////
    function _takeSnapshot(
        address user,
        uint256 amountShares,
        uint256 pps,
        uint256 decimals
    )
        internal
        virtual
    {
        usersAccumulatorShares[user] += amountShares;
        usersAccumulatorCostBasis[user] += Math.mulDiv(amountShares, pps, 10 ** decimals);

    }

    function _getOutflowProcessVolume(uint256 amountSharesOrAssets, uint256 , uint256 , uint8) internal pure virtual returns(uint256)
    {
        return amountSharesOrAssets;
    }

    function calculateCostBasisView(
        address user,
        uint256 usedShares
    )
        public
        view
        returns (uint256 costBasis)
    {
        uint256 accumulatorShares = usersAccumulatorShares[user];
        uint256 accumulatorCostBasis = usersAccumulatorCostBasis[user];

        if (usedShares > accumulatorShares) revert INSUFFICIENT_SHARES();

        costBasis = Math.mulDiv(accumulatorCostBasis, usedShares, accumulatorShares);
    }

    function _calculateCostBasis(
        address user,
        uint256 usedShares
    )
        internal
        returns (uint256 costBasis)
    {
        costBasis = calculateCostBasisView(user,
            usedShares);

        usersAccumulatorShares[user] -= usedShares;
        usersAccumulatorCostBasis[user] -= costBasis;
    }


    //////////////////// Fees ////////////////////

    function _calculateFees(
        uint256 costBasis,
        uint256 amountAssets,
        uint256 feePercent
    )
        internal
        pure
        returns (uint256 feeAmount)
    {
        uint256 profit = amountAssets > costBasis ? amountAssets - costBasis : 0;
        if (profit > 0) {
            if (feePercent == 0) revert FEE_NOT_SET();
            feeAmount = Math.mulDiv(profit, feePercent, 10_000);
        }
    }

    function previewFees(
        address user,
        uint256 amountAssets,
        uint256 usedShares,
        uint256 feePercent
    )
        public
        view
        returns (uint256 feeAmount)
    {
        uint256 costBasis = calculateCostBasisView(user,
            usedShares);
        feeAmount = _calculateFees(costBasis, amountAssets, feePercent);
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

        // Get price from oracle
        uint256 pps = IYieldSourceOracle(config.yieldSourceOracle).getPricePerShare(yieldSource);

        if (isInflow) {
            if (pps == 0) revert INVALID_PRICE();

            _takeSnapshot(
                user,
                amountSharesOrAssets,
                pps,
                IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource)
            );

            emit AccountingInflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, pps);
            return 0;
        } else {
            // Only process outflow if feePercent is not set to 0
            if (config.feePercent != 0) {

                uint256 amountAssets = _getOutflowProcessVolume(amountSharesOrAssets, usedShares, pps, IYieldSourceOracle(config.yieldSourceOracle).decimals(yieldSource));

                feeAmount = _processOutflow(user,
                    amountAssets, usedShares, config);

                emit AccountingOutflow(user, config.yieldSourceOracle, yieldSource, amountSharesOrAssets, feeAmount);
                return feeAmount;
            } else {
                emit AccountingOutflowSkipped(user, yieldSource, yieldSourceOracleId, amountSharesOrAssets);
                return 0;
            }
        }
    }

    function _processOutflow(
        address user,
        uint256 amountAssets,
        uint256 usedShares,
        ISuperLedgerConfiguration.YieldSourceOracleConfig memory config
    )
        internal
        virtual
        returns (uint256 feeAmount)
    {
        uint256 costBasis = _calculateCostBasis(user,
            usedShares);
        feeAmount = _calculateFees(costBasis, amountAssets, config.feePercent);
    }
}
