/*
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IYieldSourceOracle } from "../interfaces/accounting/IYieldSourceOracle.sol";

library YieldSourceOracleLibrary {
    error ORACLE_CALL_FAILED();



    /// @notice Get the TVL of a yield source
    /// @param oracle The oracle address
    /// @param yieldSource The yield source address
    /// @return The TVL in underlying asset decimals
    function getTVL(address oracle, address yieldSource) public view returns (uint256) {
        try IYieldSourceOracle(oracle).getTVL(yieldSource) returns (uint256 tvl) {
            return tvl;
        } catch {
            revert ORACLE_CALL_FAILED();
        }
    }

    /// @notice Get the price per share of a yield source
    /// @param oracle The oracle address
    /// @param yieldSource The yield source address
    /// @return The price per share in 1e18 decimals
    function getPricePerShare(address oracle, address yieldSource) public view returns (uint256) {
        try IYieldSourceOracle(oracle).getPricePerShare(yieldSource) returns (uint256 pricePerShare) {
            return pricePerShare;
        } catch {
            revert ORACLE_CALL_FAILED();
        }
    }

    /// @notice Get the total assets of a yield source
    /// @param oracle The oracle address
    /// @param yieldSource The yield source address
    /// @return The total assets in underlying asset decimals
    function getTotalAssets(address oracle, address yieldSource) public view returns (uint256) {
        try IYieldSourceOracle(oracle).getTotalAssets(yieldSource) returns (uint256 totalAssets) {
            return totalAssets;
        } catch {
            revert ORACLE_CALL_FAILED();
        }
    }
}
*/