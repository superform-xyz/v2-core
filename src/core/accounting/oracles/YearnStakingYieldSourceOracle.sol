// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { YearnStakingYieldSourceOracleLibrary } from
    "../../libraries/accounting/YearnStakingYieldSourceOracleLibrary.sol";

/// @title YearnStakingYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Yearn Staking Yield
contract YearnStakingYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                             VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the price per share for a deposit into a yield source
    /// @param yieldSourceAddress The address of the yield source
    /// @return price The price per share
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256 price) {
        price = YearnStakingYieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress);
    }
}
