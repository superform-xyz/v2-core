// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { ERC7540YieldSourceOracleLibrary } from "../../libraries/accounting/ERC7540YieldSourceOracleLibrary.sol";

/// @title ERC7540YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for synchronous deposit and redeem 7540 Vaults
contract ERC7540YieldSourceOracle is IYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the TVL of a yield source
    /// @param yieldSourceAddress The address of the yield source
    /// @param ownerOfShares The address of the owner of the shares
    /// @return tvl The TVL of the yield source
    function getTVL(address yieldSourceAddress, address ownerOfShares) public view returns (uint256 tvl) {
        tvl = ERC7540YieldSourceOracleLibrary.getTVL(yieldSourceAddress, ownerOfShares);
    }

    /// @notice Get the price per share for a deposit into a yield source
    /// @param yieldSourceAddress The address of the yield source
    /// @return price The price per share
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256 price) {
        price = ERC7540YieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress);
    }

    /// @notice Get the price per share for a deposit into multiple yield sources
    /// @param yieldSourceAddresses The addresses of the yield sources
    /// @return prices The price per share per yield source
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory prices)
    {
        prices = ERC7540YieldSourceOracleLibrary.getPricePerShareMultiple(yieldSourceAddresses);
    }
}
