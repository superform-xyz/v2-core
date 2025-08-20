// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { HookDataUpdater } from "../../../../src/libraries/HookDataUpdater.sol";


import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";


contract HookDataUpdaterHarness {
    function get(uint256 amount, uint256 prev, uint256 out) external pure returns (uint256) {
        return HookDataUpdater.getUpdatedOutputAmount(amount, prev, out);
    }
}


contract HookDataUpdaterTest is Helpers {
    HookDataUpdaterHarness internal tester;
    uint256 constant PRECISION = 1e5;

    function setUp() public {
        tester = new HookDataUpdaterHarness();
    }

    function test_NoChange_WhenAmountsEqual() public view {
        uint256 amount = 1_000;
        uint256 prev = 1_000;
        uint256 out = 42_000;

        uint256 res = tester.get(amount, prev, out);
        assertEq(res, out);
    }

    function test_Increase_WithPrevZero_DoublesOutput() public view {
        uint256 amount = 123; // any > 0
        uint256 prev = 0;
        uint256 out = 10_000;

        uint256 expected = out + Math.mulDiv(out, PRECISION, PRECISION);
        uint256 res = tester.get(amount, prev, out);
        assertEq(res, expected);
    }

     function test_Decrease_WithPrevZero_ZerosOutput() public view {
        uint256 amount = 0; 
        uint256 prev = 1;     
        uint256 out = 10_000;
        uint256 expected = 0;  // 100% decrease

        uint256 res = tester.get(amount, prev, out);
        assertEq(res, expected);
    }

    function test_Increase_Percentage_ComputedWithMulDiv() public view {
        uint256 amount = 150;  // +50% vs prev
        uint256 prev = 100;
        uint256 out = 20_000;

        uint256 percentIncrease = Math.mulDiv(amount - prev, PRECISION, prev); // 0.5 * 1e5
        uint256 expected = out + Math.mulDiv(out, percentIncrease, PRECISION);
        uint256 res = tester.get(amount, prev, out);
        assertEq(res, expected);
    }
    
    function test_Decrease_Percentage_ComputedWithMulDiv() public view {
        uint256 amount = 60;   // -40% vs prev
        uint256 prev = 100;
        uint256 out = 20_000;

        uint256 percentDecrease = Math.mulDiv(prev - amount, PRECISION, prev); // 0.4 * 1e5
        uint256 decreaseAmt = Math.mulDiv(out, percentDecrease, PRECISION);
        uint256 expected = out - decreaseAmt;

        uint256 res = tester.get(amount, prev, out);
        assertEq(res, expected);
    }

    function test_LargeIncrease_MoreThan100Percent() public {
        uint256 amount = 500;  // +400% vs prev
        uint256 prev = 100;
        uint256 out = 3;

        uint256 percentIncrease = Math.mulDiv(amount - prev, PRECISION, prev); // 4 * 1e5
        uint256 expected = out + Math.mulDiv(out, percentIncrease, PRECISION); // 3 + 12 = 15
        uint256 res = tester.get(amount, prev, out);
        assertEq(res, expected);
    }

    function test_EqualZeroAmounts_NoChange() public view {
        uint256 amount = 0;
        uint256 prev = 0;
        uint256 out = 777;

        uint256 res = tester.get(amount, prev, out);
        assertEq(res, out);
    }

    function testFuzz_NoChange_WhenEqual(uint256 x, uint256 out) public {
        uint256 res = tester.get(x, x, out);
        assertEq(res, out);
    }
    
   
    function testFuzz_Monotonicity(uint256 prev, uint256 out, uint256 a, uint256 b) public {
        // If a > b and both compared to the same prev, result(a) >= result(b)
        vm.assume(prev > 0 && prev < 1e18);
        vm.assume(a != b);
        vm.assume(out < 1e18);

        uint256 ra = tester.get(a, prev, out);
        uint256 rb = tester.get(b, prev, out);

        if (a > b) {
            assertGe(ra, rb, "Higher amount should not lead to lower output");
        } else {
            assertLe(ra, rb, "Lower amount should not lead to higher output");
        }
    }

}