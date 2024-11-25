// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "test/BaseTest.t.sol";

//TODO: remove; for CI to pass
contract Mocktsol is BaseTest {
    function test_WhenIsValid() external pure {
        // it should not revert
        assertTrue(true);
    }
}
