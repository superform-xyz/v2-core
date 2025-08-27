// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

library HookDataUpdater {
    uint256 private constant PRECISION = 1e5;

    function getUpdatedOutputAmount(uint256 amount, uint256 _prevAmount, uint256 outputAmount) internal pure returns (uint256) {
        if (_prevAmount == 0) return outputAmount;
        if (amount != _prevAmount) {
            if (amount > _prevAmount) {
                uint256 percentIncrease = Math.mulDiv(amount - _prevAmount, PRECISION, _prevAmount);
                outputAmount = outputAmount + Math.mulDiv(outputAmount, percentIncrease, PRECISION);
            } else {
                uint256 percentDecrease = Math.mulDiv(_prevAmount - amount, PRECISION, _prevAmount);
                uint256 decreaseAmount = Math.mulDiv(outputAmount, percentDecrease, PRECISION);
                outputAmount = outputAmount - decreaseAmount;
            }
        }
        return outputAmount;
    }
}