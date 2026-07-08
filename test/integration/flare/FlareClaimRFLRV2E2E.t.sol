// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ClaimRFLRV2Hook } from "../../../src/hooks/claim/flare/ClaimRFLRV2Hook.sol";
import { IRNat } from "../../../src/vendor/flare/IRNat.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title FlareClaimRFLRV2E2E
/// @notice Fork integration tests for ClaimRFLRV2Hook against real RNat on Flare mainnet
/// @dev Pinned to block 50_000_000 where SECOND_HOLDER has claimable rewards on project 2 (Kinetic).
///      At this block: 11 projects, month 17, ~1.4M rFLR claimable on project 2.
contract FlareClaimRFLRV2E2E is Test, Constants {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant FLARE_RPC_URL_KEY = "FLARE_RPC_URL";

    /// @dev Pinned block with known claimable state
    uint256 public constant FORK_BLOCK = 50_000_000;

    /// @dev Holder with claimable rewards at FORK_BLOCK (~1.4M on project 2/Kinetic)
    address public constant CLAIMABLE_HOLDER = 0xEd0C6079229E2d407672a117c22b62064f4a4312;


    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ClaimRFLRV2Hook public hook;
    uint256 public forkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString(FLARE_RPC_URL_KEY), FORK_BLOCK);
        hook = new ClaimRFLRV2Hook(FLARE_RNAT);
    }

    /*//////////////////////////////////////////////////////////////
                    ON-CHAIN ENUMERATION SANITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify RNat contract exposes enumeration functions correctly
    function test_onChainEnumeration_sanity() public view {
        uint256 projectCount = IRNat(FLARE_RNAT).getProjectsCount();
        assertEq(projectCount, 11, "Expected 11 projects at fork block");
        console2.log("Project count:", projectCount);

        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();
        assertEq(currentMonth, 17, "Expected month 17 at fork block");
        console2.log("Current month:", currentMonth);

        // Verify CLAIMABLE_HOLDER has rewards on project 2
        uint128 claimable = IRNat(FLARE_RNAT).getClaimableRewards(2, CLAIMABLE_HOLDER);
        assertGt(claimable, 0, "Claimable holder should have rewards on project 2");
        console2.log("Claimable on project 2:", claimable);
    }

    /*//////////////////////////////////////////////////////////////
                    BUILD - PARAMETERLESS ENUMERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Build with empty data discovers claimable projects automatically
    function test_build_discoversClaimableProjects() public view {
        Execution[] memory executions = hook.build(address(0), CLAIMABLE_HOLDER, "");

        // preExecute + claim + postExecute = 3
        assertEq(executions.length, 3, "Should have 3 executions");
        assertEq(executions[1].target, FLARE_RNAT, "Claim target should be RNAT");
        assertEq(executions[1].value, 0, "No ETH value");

        // Decode the claim calldata and verify it found project 2
        (uint256[] memory projectIds, uint256 month) = abi.decode(
            _stripSelector(executions[1].callData), (uint256[], uint256)
        );

        assertEq(month, 17, "Month should be 17");

        // Verify project 2 is in the discovered IDs
        bool foundProject2;
        for (uint256 i; i < projectIds.length; ++i) {
            console2.log("Discovered project ID:", projectIds[i]);
            if (projectIds[i] == 2) foundProject2 = true;
        }
        assertTrue(foundProject2, "Should discover project 2 (Kinetic)");
    }

    /// @notice Build and execute claim — rFLR balance increases
    function test_buildAndExecute_claimsRewards() public {
        // Get pre-claim balance
        uint256 preBal = IERC20(FLARE_RNAT).balanceOf(CLAIMABLE_HOLDER);
        console2.log("Pre-claim rFLR balance:", preBal);

        // Build executions
        Execution[] memory executions = hook.build(address(0), CLAIMABLE_HOLDER, "");

        // Set up execution context (simulates what SuperExecutor does)
        hook.setExecutionContext(CLAIMABLE_HOLDER);

        // Execute all steps as the account
        vm.startPrank(CLAIMABLE_HOLDER);
        for (uint256 i; i < executions.length; ++i) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string.concat("Execution ", vm.toString(i), " failed"));
        }
        vm.stopPrank();

        // Verify balance increased
        uint256 postBal = IERC20(FLARE_RNAT).balanceOf(CLAIMABLE_HOLDER);
        console2.log("Post-claim rFLR balance:", postBal);
        assertGt(postBal, preBal, "rFLR balance should increase after claim");

        // Verify outAmount matches the delta
        uint256 outAmount = hook.getOutAmount(CLAIMABLE_HOLDER);
        assertEq(outAmount, postBal - preBal, "outAmount should equal balance delta");
        console2.log("Claimed amount (outAmount):", outAmount);
    }

    /// @notice Double-claim produces no new rewards (idempotent)
    function test_buildAndExecute_doubleClaimIsIdempotent() public {
        // First claim
        Execution[] memory executions1 = hook.build(address(0), CLAIMABLE_HOLDER, "");
        hook.setExecutionContext(CLAIMABLE_HOLDER);

        vm.startPrank(CLAIMABLE_HOLDER);
        for (uint256 i; i < executions1.length; ++i) {
            (bool success,) = executions1[i].target.call{ value: executions1[i].value }(executions1[i].callData);
            assertTrue(success);
        }
        vm.stopPrank();

        IERC20(FLARE_RNAT).balanceOf(CLAIMABLE_HOLDER);

        // Second claim should revert (no more claimable)
        vm.expectRevert(ClaimRFLRV2Hook.NO_CLAIMABLE_REWARDS.selector);
        hook.build(address(0), CLAIMABLE_HOLDER, "");
    }

    /// @notice Address with no claimable rewards reverts
    function test_build_revertsWhenNoClaimable() public {
        address nobody = makeAddr("nobody_with_no_rewards");
        vm.expectRevert(ClaimRFLRV2Hook.NO_CLAIMABLE_REWARDS.selector);
        hook.build(address(0), nobody, "");
    }

    /*//////////////////////////////////////////////////////////////
                    INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_inspect_returnsRNat() public view {
        bytes memory result = hook.inspect("");
        assertEq(result, abi.encodePacked(FLARE_RNAT));
    }

    /*//////////////////////////////////////////////////////////////
                    HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Strips the 4-byte selector from calldata for abi.decode
    function _stripSelector(bytes memory data) internal pure returns (bytes memory) {
        bytes memory result = new bytes(data.length - 4);
        for (uint256 i = 4; i < data.length; ++i) {
            result[i - 4] = data[i];
        }
        return result;
    }
}
