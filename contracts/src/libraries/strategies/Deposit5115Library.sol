// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IStandardizedYield } from "../../interfaces/vendors/pendle/IStandardizedYield.sol";

library Deposit5115Library {
    function getEstimatedRewards(
        address standardizedYield,
        address tokenIn,
        uint256 amountToDeposit
    )
        external
        view
        returns (uint256 reward)
    {
        reward = IStandardizedYield(standardizedYield).previewDeposit(tokenIn, amountToDeposit);
    }
}
