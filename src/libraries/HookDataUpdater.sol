// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

library HookDataUpdater {
    uint256 private constant PRECISION = 1e5;

    function getUpdatedOutputAmount(uint256 amount, uint256 _prevAmount, uint256 outputAmount) internal pure returns (uint256) {
        if (amount != _prevAmount) {
            if (amount > _prevAmount) {
                uint256 percentIncrease = _prevAmount > 0 ? Math.mulDiv(amount - _prevAmount, PRECISION, _prevAmount) : PRECISION;
                outputAmount = outputAmount + Math.mulDiv(outputAmount, percentIncrease, PRECISION);
            } else {
                uint256 percentDecrease = _prevAmount > 0 ? Math.mulDiv(_prevAmount - amount, PRECISION, _prevAmount) : PRECISION;
                uint256 decreaseAmount = Math.mulDiv(outputAmount, percentDecrease, PRECISION);
                if (decreaseAmount > outputAmount) {
                    outputAmount = 0;
                } else {
                    outputAmount = outputAmount - decreaseAmount;
                }
            }
        }
        return outputAmount;
    }
}