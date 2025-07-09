// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// Superform
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../../interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ISuperLedger } from "../../interfaces/accounting/ISuperLedger.sol";

/// @title AbstractYieldSourceOracle
/// @author Superform Labs
/// @notice Abstract base contract that implements common functionality for yield source oracles
/// @dev Provides implementations for batch methods to reduce redundancy across concrete oracles
///      Concrete oracle implementations must extend this class and implement the abstract methods
///      The oracle pattern separates price/yield discovery from the core accounting system
abstract contract AbstractYieldSourceOracle is IYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Immutable address of the SuperLedgerConfiguration contract
    address public immutable superLedgerConfiguration;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor to set the SuperLedgerConfiguration address
    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract
    constructor(address superLedgerConfiguration_) {
        superLedgerConfiguration = superLedgerConfiguration_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IYieldSourceOracle
    function decimals(address yieldSourceAddress) external view virtual returns (uint8);

    /// @inheritdoc IYieldSourceOracle
    function getShareOutput(
        address yieldSourceAddress,
        address assetIn,
        uint256 assetsIn
    )
        external
        view
        virtual
        returns (uint256);

    /// @inheritdoc IYieldSourceOracle
    function getAssetOutput(
        address yieldSourceAddress,
        address assetOut,
        uint256 sharesIn
    )
        public
        view
        virtual
        returns (uint256);

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view virtual returns (uint256);

    /// @inheritdoc IYieldSourceOracle
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        virtual
        returns (uint256);

    /// @inheritdoc IYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view virtual returns (uint256);

    /// @inheritdoc IYieldSourceOracle
    function getAssetOutputWithFees(
        bytes32 yieldSourceOracleId,
        address yieldSourceAddress,
        address assetOut,
        address user,
        uint256 usedShares
    )
        external
        view
        virtual
        returns (uint256)
    {
        // Get base asset output without fees
        uint256 assetOutput = getAssetOutput(yieldSourceAddress, assetOut, usedShares);

        try ISuperLedgerConfiguration(superLedgerConfiguration).getYieldSourceOracleConfig(yieldSourceOracleId)
        returns (ISuperLedgerConfiguration.YieldSourceOracleConfig memory config) {
            // Configuration found, calculate fees if applicable
            if (config.feePercent > 0 && config.ledger != address(0)) {
                // Calculate fees using the associated ledger
                uint256 feeAmount = ISuperLedger(config.ledger).previewFees(
                    user, yieldSourceAddress, assetOutput, usedShares, config.feePercent
                );

                // Add fees to the asset output (opposite of BaseLedger which subtracted)
                return assetOutput + feeAmount;
            }

            // Valid config but no fees, return base asset output
            return assetOutput;
        } catch {
            // Configuration not found or invalid, return asset output without fees
            return assetOutput;
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory pricesPerShare)
    {
        uint256 length = yieldSourceAddresses.length;
        pricesPerShare = new uint256[](length);

        // Iterate through all yield sources and get individual prices
        for (uint256 i = 0; i < length; ++i) {
            pricesPerShare[i] = getPricePerShare(yieldSourceAddresses[i]);
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        external
        view
        virtual
        returns (uint256);

    /// @inheritdoc IYieldSourceOracle
    function getTVLByOwnerOfSharesMultiple(
        address[] memory yieldSourceAddresses,
        address[][] memory ownersOfShares
    )
        external
        view
        returns (uint256[][] memory userTvls)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != ownersOfShares.length) revert ARRAY_LENGTH_MISMATCH();

        userTvls = new uint256[][](length);

        // Process each yield source
        for (uint256 i = 0; i < length; ++i) {
            address yieldSource = yieldSourceAddresses[i];
            address[] memory owners = ownersOfShares[i];
            uint256 ownersLength = owners.length;

            userTvls[i] = new uint256[](ownersLength);

            // For each yield source, process each owner
            for (uint256 j = 0; j < ownersLength; ++j) {
                uint256 userTvl = getTVLByOwnerOfShares(yieldSource, owners[j]);
                userTvls[i][j] = userTvl;
            }
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function getTVLMultiple(address[] memory yieldSourceAddresses) external view returns (uint256[] memory tvls) {
        uint256 length = yieldSourceAddresses.length;
        tvls = new uint256[](length);

        // Get TVL for each yield source
        for (uint256 i = 0; i < length; ++i) {
            tvls[i] = getTVL(yieldSourceAddresses[i]);
        }
    }

    /// @inheritdoc IYieldSourceOracle
    function isValidUnderlyingAsset(
        address,
        /**
         * yieldSourceAddress
         */
        address
    )
        /**
         * expectedUnderlying
         */
        public
        view
        virtual
        returns (bool)
    {
        return true;
    }

    /// @inheritdoc IYieldSourceOracle
    function isValidUnderlyingAssets(
        address[] memory yieldSourceAddresses,
        address[] memory expectedUnderlying
    )
        external
        view
        virtual
        returns (bool[] memory isValid)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != expectedUnderlying.length) revert ARRAY_LENGTH_MISMATCH();

        isValid = new bool[](length);
        for (uint256 i; i < length; ++i) {
            isValid[i] = isValidUnderlyingAsset(yieldSourceAddresses[i], expectedUnderlying[i]);
        }
    }
}
