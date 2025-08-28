// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { HookDataUpdater } from "../../../src/libraries/HookDataUpdater.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract HookDataUpdaterTest is Test {
    using HookDataUpdater for uint256;

    function testFuzz_DecreaseAmountGreaterThanOutputAmount(
        uint256 prevAmount,
        uint256 amount,
        uint256 outputAmount
    )
        public
        pure
    {
        prevAmount = bound(prevAmount, 1, type(uint128).max); // avoid div by 0
        amount = bound(amount, 0, prevAmount); // ensure valid decrease
        outputAmount = bound(outputAmount, 0, 1e30); // some large number

        uint256 percentDecrease = Math.mulDiv(prevAmount - amount, 1e5, prevAmount);
        uint256 decreaseAmount = Math.mulDiv(outputAmount, percentDecrease, 1e5);

        assertLe(decreaseAmount, outputAmount, "decreaseAmount should never exceed outputAmount");
    }
}
