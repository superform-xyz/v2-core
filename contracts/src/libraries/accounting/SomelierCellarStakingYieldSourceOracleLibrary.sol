// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ISomelierCellarStaking } from "../interfaces/vendors/somelier/ISomelierCellarStaking.sol";

/// @title SomelierCellarStakingYieldSourceOracleLibrary
/// @author Superform Labs
/// @notice This library is used to calculate the price per share for a Somelier Cellar Staking yield source
library SomelierCellarStakingYieldSourceOracleLibrary {
    /// @notice Get the price per share for a Somelier Cellar Staking yield source
    /// @param yieldSourceAddress The address of the yield source
    /// @return pricePerShare The price per share
    function getPricePerShare(address yieldSourceAddress) internal view returns (uint256 pricePerShare) {
        pricePerShare = ISomelierCellarStaking(yieldSourceAddress).rewardPerToken();
    }
}
