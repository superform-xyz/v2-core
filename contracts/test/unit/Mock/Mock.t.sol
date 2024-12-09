// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "test/BaseTest.t.sol";

import { TransientStorageExecutor } from "test/mocks/TransientStorageExecutor.sol";

contract Mocktsol is BaseTest {
    TransientStorageExecutor transientExecutor;

    function setUp() public override {
        super.setUp();
        transientExecutor = new TransientStorageExecutor();
    }

    function test_WhenIsValid() external pure {
        // it should not revert
        assertTrue(true);
    }

    function test_GasBenchmarkForTransientStorageExecutor() external {
        transientExecutor.execute(abi.encode(1e8));
    }

    function test_GasBenchmarkForTransientStorageExecutorNotTransient() external {
        transientExecutor.executeNotTransient(abi.encode(1e8));
    }
}
