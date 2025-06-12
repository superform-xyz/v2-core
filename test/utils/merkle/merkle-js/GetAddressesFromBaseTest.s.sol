// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../../../test/BaseTest.t.sol";
import { console } from "forge-std/console.sol";

contract GetAddressesFromBaseTest is BaseTest {
    function setUp() public override {
        // Call the BaseTest setUp which does all the deployment work
        super.setUp();
    }

    /**
     * @notice Legacy test function for forge test compatibility
     * @dev This logs addresses for the old parsing approach
     */
    function test_getAddresses() external view {
        // Simply log each address individually to avoid stack too deep
        console.log("VAULT_globalSVStrategy:", globalSVStrategy);
        console.log("VAULT_globalSVGearStrategy:", globalSVGearStrategy);
        console.log("VAULT_globalRuggableVault:", globalRuggableVault);
        console.log("HOOK_APPROVE_AND_REDEEM_4626_VAULT_HOOK:", globalMerkleHooks[0]);
        console.log("HOOK_APPROVE_AND_DEPOSIT_4626_VAULT_HOOK:", globalMerkleHooks[1]);
        console.log("HOOK_REDEEM_4626_VAULT_HOOK:", globalMerkleHooks[2]);
        console.log("HOOK_APPROVE_AND_GEARBOX_STAKE_HOOK:", globalMerkleHooks[3]);
        console.log("HOOK_GEARBOX_UNSTAKE_HOOK:", globalMerkleHooks[4]);
        console.log("BASETEST:", address(this));
    }
}
