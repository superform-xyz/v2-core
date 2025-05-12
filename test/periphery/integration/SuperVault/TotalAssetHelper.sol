// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// External
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Core Interfaces
import { IYieldSourceOracle } from "../../../../src/core/interfaces/accounting/IYieldSourceOracle.sol";

// Periphery Interfaces
import { ISuperVaultStrategy } from "../../../../src/periphery/interfaces/ISuperVaultStrategy.sol";

/// @title TotalAssetHelper
/// @author SuperForm Labs
/// @notice Helper contract for calculating totalAssets of a SuperVault strategy
/// @dev Used for testing purposes to retrieve totalAssets by querying active yield sources
contract TotalAssetHelper {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Struct to hold TVL information for a yield source
    struct YieldSourceTVL {
        address source;
        uint256 tvl;
    }

    /*//////////////////////////////////////////////////////////////
                             PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate the total assets of a SuperVault strategy
    /// @param strategy Address of the SuperVaultStrategy contract
    /// @return totalAssets_ Total assets held by the strategy across all yield sources
    /// @return sourceTVLs Breakdown of TVL by yield source
    function totalAssets(address strategy)
        external
        view
        returns (uint256 totalAssets_, YieldSourceTVL[] memory sourceTVLs)
    {
        // Get all yield sources from the strategy
        address[] memory yieldSourcesList = _getYieldSourcesList(strategy);
        uint256 length = yieldSourcesList.length;

        // Initialize array to track TVLs
        sourceTVLs = new YieldSourceTVL[](length);
        uint256 activeSourceCount;

        // Hack to get total free assets. Assumes nothing is manually transferred to the vault
        // off chain this must be tracked via *Handled events in Strategy
        (, address asset,) = ISuperVaultStrategy(strategy).getVaultInfo();

        totalAssets_ += IERC20(asset).balanceOf(strategy);

        // Calculate total assets by summing TVLs across all active yield sources
        for (uint256 i; i < length; ++i) {
            address source = yieldSourcesList[i];

            // Check if the yield source is active
            if (_isYieldSourceActive(strategy, source)) {
                // Calculate base TVL (assets held in the yield source)
                uint256 baseTvl = _getTvlByOwnerOfShares(strategy, source);

                // Update total and add to breakdown
                totalAssets_ += baseTvl;
                sourceTVLs[activeSourceCount++] = YieldSourceTVL({ source: source, tvl: baseTvl });
            }
        }

        // Resize array if needed to remove empty entries
        if (activeSourceCount < length) {
            assembly {
                mstore(sourceTVLs, activeSourceCount)
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the list of yield sources for a strategy
    /// @param strategy Address of the SuperVaultStrategy contract
    /// @return List of yield source addresse
    function _getYieldSourcesList(address strategy) internal view returns (address[] memory) {
        try ISuperVaultStrategy(strategy).getYieldSourcesList() returns (
            address[] memory source, ISuperVaultStrategy.YieldSource[] memory
        ) {
            return source;
        } catch {
            return new address[](0);
        }
    }

    /// @notice Check if a yield source is active
    /// @param strategy Address of the SuperVaultStrategy contract
    /// @param source Address of the yield source
    /// @return Whether the yield source is active
    function _isYieldSourceActive(address strategy, address source) internal view returns (bool) {
        try ISuperVaultStrategy(strategy).getYieldSource(source) returns (
            ISuperVaultStrategy.YieldSource memory yieldSource
        ) {
            return yieldSource.isActive;
        } catch {
            return false;
        }
    }

    /// @notice Get information about a yield source
    /// @param strategy Address of the SuperVaultStrategy contract
    /// @param source Address of the yield source
    /// @return oracle Address of the yield source oracle
    /// @return isActive Whether the yield source is active
    function _getYieldSourceInfo(
        address strategy,
        address source
    )
        internal
        view
        returns (address oracle, bool isActive)
    {
        try ISuperVaultStrategy(strategy).getYieldSource(source) returns (
            ISuperVaultStrategy.YieldSource memory yieldSource
        ) {
            return (yieldSource.oracle, yieldSource.isActive);
        } catch {
            return (address(0), false);
        }
    }

    /// @notice Get the TVL for a yield source by owner of shares
    /// @param strategy Address of the SuperVaultStrategy contract
    /// @param source Address of the yield source
    /// @return TVL of the yield source
    function _getTvlByOwnerOfShares(address strategy, address source) internal view returns (uint256) {
        (address oracle,) = _getYieldSourceInfo(strategy, source);
        if (oracle == address(0)) return 0;

        try IYieldSourceOracle(oracle).getTVLByOwnerOfShares(source, strategy) returns (uint256 tvl) {
            return tvl;
        } catch {
            return 0;
        }
    }
}
