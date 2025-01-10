// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { YearnStakingYieldSourceOracleLibrary } from 
"../../libraries/accounting/YearnStakingYieldSourceOracleLibrary.sol";

/// @title YearnStakingYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Yearn Staking Yield
contract YearnStakingYieldSourceOracle {
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
        price = YearnStakingYieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress);
    }

    // ToDo: Implement this with the metadata library
    /// @notice Get the metadata for a yield source
    /// @param yieldSourceAddress The address of the yield source
    /// @return metadata The metadata
    function getYieldSourceMetadata(address yieldSourceAddress) external pure returns (bytes memory metadata) {
        return "0x0";
    }
}
