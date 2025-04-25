// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import { BaseTest } from "../BaseTest.t.sol";
import { console } from "forge-std/console.sol";

contract EOAOnrampOfframpTest is BaseTest {
    function setUp() public override {
        super.setUp();

        console.log(_getHookAddress(ETH, BATCH_TRANSFER_FROM_HOOK_KEY));
    }
}