// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import {IYBSUtilities} from "../../interfaces/vendors/yearn/IYBSUtilities.sol";

library YearnStakingYieldSourceOracleLibrary {
  function getPricePerShare(address yieldSourceAddress) internal view returns (uint256 pricePerShare) {
    pricePerShare = IYBSUtilities(yieldSourceAddress).activeRewardAmount();
  }
}
