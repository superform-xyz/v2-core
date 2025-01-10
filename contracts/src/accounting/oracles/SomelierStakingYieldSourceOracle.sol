// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { SomelierCellarStakingYieldSourceOracleLibrary } 
from 
"../../libraries/accounting/SomelierCellarStakingYieldSourceOracleLibrary.sol";

/// @title SomelierStakingYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Somelier Staking Yield
contract SomelierStakingYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() { }

    /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the price per share for a deposit into a yield source
    /// @param yieldSourceAddress The address of the yield source
    /// @return price The price per share
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256 price) {
        price = SomelierCellarStakingYieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress);
    }

    // ToDo: Implement this with the metadata library
    /// @notice Get the metadata for a yield source
    /// @return metadata The metadata
    function getYieldSourceMetadata() external pure returns (bytes memory metadata) {
        return "0x0";
    }
}
