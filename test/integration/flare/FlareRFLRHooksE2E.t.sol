// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ClaimRFLRHook } from "../../../src/hooks/claim/flare/ClaimRFLRHook.sol";
import { WithdrawRFLRHook } from "../../../src/hooks/claim/flare/WithdrawRFLRHook.sol";
import { WithdrawVestedRFLRHook } from "../../../src/hooks/claim/flare/WithdrawVestedRFLRHook.sol";
import { IRNat } from "../../../src/vendor/flare/IRNat.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title FlareRFLRHooksE2E
/// @notice Fork integration tests for ClaimRFLRHook and WithdrawRFLRHook against real RNat on Flare mainnet
/// @dev Uses SECOND_HOLDER for claim tests (has claimable rewards on project 2/Kinetic),
///      and TOP_HOLDER for withdraw tests (has large unlocked rFLR balance).
contract FlareRFLRHooksE2E is Test, Constants {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant FLARE_RPC_URL_KEY = "FLARE_RPC_URL";

    /// @dev Top rFLR holder with unlocked balance (~5.29M rFLR unlocked, 0 claimable)
    address public constant TOP_HOLDER = 0xb99a2c4C1C4F1fc27150681B740396F6CE1cBcF5;

    /// @dev Second holder with claimable rewards (~1.64M claimable on project 2/Kinetic)
    address public constant SECOND_HOLDER = 0xEd0C6079229E2d407672a117c22b62064f4a4312;

    /// @dev Active project IDs on RNat
    uint256 public constant PROJECT_SPARKDEX = 0;
    uint256 public constant PROJECT_BLAZESWAP = 1;
    uint256 public constant PROJECT_KINETIC = 2;
    uint256 public constant PROJECT_ENOSYS = 3;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ClaimRFLRHook public claimHook;
    WithdrawRFLRHook public withdrawHook;
    WithdrawVestedRFLRHook public withdrawVestedHook;

    uint256 public forkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString(FLARE_RPC_URL_KEY));

        claimHook = new ClaimRFLRHook(FLARE_RNAT);
        withdrawHook = new WithdrawRFLRHook(FLARE_RNAT, FLARE_WFLR);
        withdrawVestedHook = new WithdrawVestedRFLRHook(FLARE_RNAT, FLARE_WFLR);
    }

    /// @dev Skips the test if SECOND_HOLDER has no claimable rewards (epoch expired)
    function _skipIfNoClaimableRewards() internal {
        uint256[] memory projectIds = _allProjectIds();
        uint256 totalClaimable = _getTotalClaimable(projectIds, SECOND_HOLDER);
        if (totalClaimable == 0) {
            console2.log("SKIP: No claimable rewards for SECOND_HOLDER (rewards epoch may have expired)");
            vm.skip(true);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    CLAIM RFLR HOOK - SANITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify RNat contract responds, holder has balance, and claimable rewards exist
    function test_claimRFLR_sanity() public {
        // Verify RNat state
        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();
        assertGt(currentMonth, 0, "Current month should be > 0");
        console2.log("Current month:", currentMonth);

        // Verify SECOND_HOLDER has rFLR balance
        uint256 rnatBalance = IERC20(FLARE_RNAT).balanceOf(SECOND_HOLDER);
        assertGt(rnatBalance, 0, "Second holder should have rFLR balance");
        console2.log("Second holder rFLR balance:", rnatBalance);

        // Verify claimable rewards exist (project 2/Kinetic has rewards for SECOND_HOLDER)
        uint128 claimableKinetic = IRNat(FLARE_RNAT).getClaimableRewards(PROJECT_KINETIC, SECOND_HOLDER);
        if (claimableKinetic == 0) {
            console2.log("SKIP: No claimable rewards on Kinetic (rewards epoch may have expired)");
            vm.skip(true);
        }
        console2.log("Claimable on Kinetic:", claimableKinetic);

        (uint256 wNatBal, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(SECOND_HOLDER);
        console2.log("wNat balance:", wNatBal);
        console2.log("rNat balance:", rNatBal);
        console2.log("locked balance:", lockedBal);
    }

    /*//////////////////////////////////////////////////////////////
                    CLAIM RFLR HOOK - BUILD & EXECUTE
    //////////////////////////////////////////////////////////////*/

    /// @notice Build executions and claim rFLR with no fee, verify rFLR balance increases
    function test_claimRFLR_buildAndExecute_noFee() public {
        _skipIfNoClaimableRewards();
        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();
        uint256[] memory projectIds = _allProjectIds();

        uint256 totalClaimable = _getTotalClaimable(projectIds, SECOND_HOLDER);
        assertGt(totalClaimable, 0, "Should have claimable rewards");

        bytes memory hookData = _encodeClaimData(currentMonth, projectIds);
        Execution[] memory executions = claimHook.build(address(0), SECOND_HOLDER, hookData);

        // No fee: pre + claim + post = 3
        assertEq(executions.length, 3, "Should have 3 executions (pre + claim + post)");
        assertEq(executions[1].target, FLARE_RNAT, "Claim target should be RNat");

        uint256 rnatBefore = IERC20(FLARE_RNAT).balanceOf(SECOND_HOLDER);

        vm.startPrank(SECOND_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 claimed = IERC20(FLARE_RNAT).balanceOf(SECOND_HOLDER) - rnatBefore;
        assertGt(claimed, 0, "Should have claimed rFLR");
        console2.log("rFLR claimed:", claimed);
    }

    /// @notice Verify pre/post execute correctly tracks the rFLR balance delta
    function test_claimRFLR_prePostExecute_tracksBalance() public {
        _skipIfNoClaimableRewards();
        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();
        uint256[] memory projectIds = _allProjectIds();

        uint256 totalClaimable = _getTotalClaimable(projectIds, SECOND_HOLDER);
        assertGt(totalClaimable, 0, "Should have claimable rewards");

        bytes memory hookData = _encodeClaimData(currentMonth, projectIds);

        uint256 rnatBefore = IERC20(FLARE_RNAT).balanceOf(SECOND_HOLDER);

        // Build and execute the full hook flow (pre + claim + post)
        Execution[] memory executions = claimHook.build(address(0), SECOND_HOLDER, hookData);

        vm.startPrank(SECOND_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        // Verify the hook tracked the correct rFLR delta
        uint256 outAmount = claimHook.getOutAmount(SECOND_HOLDER);
        uint256 rnatReceived = IERC20(FLARE_RNAT).balanceOf(SECOND_HOLDER) - rnatBefore;

        assertGt(outAmount, 0, "outAmount should be > 0 after claiming");
        assertEq(outAmount, rnatReceived, "outAmount should match actual rFLR received");
        console2.log("Tracked rFLR delta:", outAmount);
        console2.log("Actual rFLR received:", rnatReceived);
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAW RFLR HOOK - SANITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify holder has rFLR balance and some is unlocked
    function test_withdrawRFLR_sanity() public view {
        uint256 rnatBalance = IERC20(FLARE_RNAT).balanceOf(TOP_HOLDER);
        assertGt(rnatBalance, 0, "Top holder should have rFLR balance");

        (uint256 wNatBal, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 unlocked = (wNatBal + rNatBal) - lockedBal;
        assertGt(unlocked, 0, "Top holder should have unlocked rFLR");

        console2.log("rFLR balance (ERC20):", rnatBalance);
        console2.log("wNat balance:", wNatBal);
        console2.log("rNat balance:", rNatBal);
        console2.log("locked balance:", lockedBal);
        console2.log("Unlocked:", unlocked);
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAW RFLR HOOK - BUILD & EXECUTE
    //////////////////////////////////////////////////////////////*/

    /// @notice Build and execute withdrawAll, verify WFLR received
    function test_withdrawRFLR_buildAndExecute() public {
        Execution[] memory executions = withdrawHook.build(address(0), TOP_HOLDER, "");

        // pre + withdrawAll + post = 3
        assertEq(executions.length, 3, "Should have 3 executions (pre + withdraw + post)");
        assertEq(executions[1].target, FLARE_RNAT, "Withdraw target should be RNat");
        assertEq(
            executions[1].callData,
            abi.encodeCall(IRNat.withdrawAll, (true)),
            "Calldata should encode withdrawAll(true)"
        );

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        assertGt(wflrReceived, 0, "Should receive WFLR from withdrawal");
        console2.log("WFLR received:", wflrReceived);
    }

    /// @notice Verify pre/post execute correctly tracks the WFLR balance delta
    function test_withdrawRFLR_prePostExecute_tracksBalance() public {
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        // Build and execute the full hook flow (pre + withdrawAll + post)
        Execution[] memory executions = withdrawHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        // Verify the hook tracked the correct WFLR delta
        uint256 outAmount = withdrawHook.getOutAmount(TOP_HOLDER);
        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;

        assertGt(outAmount, 0, "outAmount should be > 0 after withdrawal");
        assertEq(outAmount, wflrReceived, "outAmount should match actual WFLR received");
        console2.log("Tracked WFLR delta:", outAmount);
        console2.log("Actual WFLR received:", wflrReceived);
    }

    /*//////////////////////////////////////////////////////////////
                    CLAIM RFLR HOOK - INSPECT
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify inspect() returns the real RNAT address
    function test_claimRFLR_inspect_returnsRNat() public view {
        bytes memory result = claimHook.inspect("");
        assertEq(result, abi.encodePacked(FLARE_RNAT), "inspect should return RNAT address");
    }

    /// @notice Verify WithdrawRFLRHook.inspect() also returns RNAT address
    function test_withdrawRFLR_inspect_returnsRNat() public view {
        bytes memory result = withdrawHook.inspect("");
        assertEq(result, abi.encodePacked(FLARE_RNAT), "inspect should return RNAT address");
    }

    /*//////////////////////////////////////////////////////////////
                    CLAIM RFLR HOOK - VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify build reverts with INVALID_DATA_LENGTH when data is too short
    function test_claimRFLR_revertIf_dataTooShort() public {
        bytes memory shortData = abi.encodePacked(uint256(1)); // only 32 bytes, need >= 64
        vm.expectRevert(ClaimRFLRHook.INVALID_DATA_LENGTH.selector);
        claimHook.build(address(0), SECOND_HOLDER, shortData);
    }

    /// @notice Verify build reverts with EMPTY_PROJECT_IDS when projectIds array is empty
    function test_claimRFLR_revertIf_emptyProjectIds() public {
        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();
        uint256[] memory emptyIds = new uint256[](0);
        bytes memory hookData = _encodeClaimData(currentMonth, emptyIds);

        vm.expectRevert(ClaimRFLRHook.EMPTY_PROJECT_IDS.selector);
        claimHook.build(address(0), SECOND_HOLDER, hookData);
    }

    /// @notice Verify build reverts with TOO_MANY_PROJECT_IDS when exceeding max
    function test_claimRFLR_revertIf_tooManyProjectIds() public {
        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();

        // Build data with 51 project IDs (exceeds MAX_PROJECT_IDS = 50)
        bytes memory data = abi.encodePacked(currentMonth, uint256(51));
        for (uint256 i; i < 51; ++i) {
            data = abi.encodePacked(data, i);
        }

        vm.expectRevert(ClaimRFLRHook.TOO_MANY_PROJECT_IDS.selector);
        claimHook.build(address(0), SECOND_HOLDER, data);
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAW RFLR HOOK - SAFE DELTA
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify postExecute returns 0 (not revert) when WFLR balance decreases
    /// @dev Simulates a scenario where WFLR is transferred out between pre and post execute
    function test_withdrawRFLR_postExecute_zeroDeltaWhenBalanceDecreases() public {
        address testAccount = makeAddr("testAccount");

        // Give testAccount some WFLR
        deal(FLARE_WFLR, testAccount, 100 ether);

        // Set up execution context
        withdrawHook.setExecutionContext(testAccount);

        // Pre-execute: snapshots 100 WFLR
        vm.prank(testAccount);
        withdrawHook.preExecute(address(0), testAccount, "");
        assertEq(withdrawHook.getOutAmount(testAccount), 100 ether, "Pre-execute should snapshot 100 WFLR");

        // Simulate balance decrease (e.g., another hook transferred WFLR out)
        deal(FLARE_WFLR, testAccount, 50 ether);

        // Post-execute: should return 0 delta, not revert
        vm.prank(testAccount);
        withdrawHook.postExecute(address(0), testAccount, "");
        assertEq(withdrawHook.getOutAmount(testAccount), 0, "outAmount should be 0 when balance decreased");
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW RFLR HOOK - SLIPPAGE PROTECTION (Variant A)
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraw with minOut — passes when actual WFLR delta >= minOut
    function test_withdrawRFLR_withMinOut_passes() public {
        // First figure out how much WFLR we'd get from TOP_HOLDER
        (uint256 wNatBal, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 unlocked = (wNatBal + rNatBal) - lockedBal;
        assertGt(unlocked, 0, "need unlocked balance for this test");

        // Use a conservative minOut (1 wei) — should always pass
        bytes memory withdrawData = abi.encodePacked(uint8(0), uint256(1));
        Execution[] memory executions = withdrawHook.build(address(0), TOP_HOLDER, withdrawData);

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        assertGt(wflrReceived, 0, "Should receive WFLR");
        console2.log("WFLR received with minOut=1:", wflrReceived);
    }

    /// @notice Withdraw with minOut that exceeds actual yield — reverts with SLIPPAGE_EXCEEDED
    function test_withdrawRFLR_withMinOut_reverts() public {
        // Set an impossibly high minOut
        bytes memory withdrawData = abi.encodePacked(uint8(0), uint256(type(uint128).max));
        Execution[] memory executions = withdrawHook.build(address(0), TOP_HOLDER, withdrawData);

        vm.startPrank(TOP_HOLDER);

        // Execute pre + withdrawAll (these succeed)
        (bool ok1,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        assertTrue(ok1, "preExecute should succeed");

        (bool ok2,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertTrue(ok2, "withdrawAll should succeed");

        // postExecute should revert with SLIPPAGE_EXCEEDED
        (bool ok3,) = executions[2].target.call{ value: executions[2].value }(executions[2].callData);
        assertFalse(ok3, "postExecute should revert due to slippage");
        vm.stopPrank();
    }

    /// @notice Withdraw with minOut=0 in data — no slippage check (same as omitting)
    function test_withdrawRFLR_withMinOutZero_noCheck() public {
        bytes memory withdrawData = abi.encodePacked(uint8(0), uint256(0));
        Execution[] memory executions = withdrawHook.build(address(0), TOP_HOLDER, withdrawData);

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        assertGt(wflrReceived, 0, "Should receive WFLR even with minOut=0");
    }

    /// @notice Withdraw with exact minOut matching expected output
    function test_withdrawRFLR_withExactMinOut() public {
        // Snapshot: do a dry-run withdrawal to find exact output
        uint256 snapshotId = vm.snapshotState();

        Execution[] memory dryExecs = withdrawHook.build(address(0), TOP_HOLDER, "");
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        vm.startPrank(TOP_HOLDER);
        _executeAll(dryExecs);
        vm.stopPrank();

        uint256 expectedWflr = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        assertGt(expectedWflr, 0, "dry run should produce WFLR");

        // Revert to pre-withdrawal state
        vm.revertToState(snapshotId);

        // Now execute with exact minOut
        bytes memory withdrawData = abi.encodePacked(uint8(0), expectedWflr);
        Execution[] memory executions = withdrawHook.build(address(0), TOP_HOLDER, withdrawData);

        wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        assertEq(wflrReceived, expectedWflr, "should receive exact same WFLR as dry run");
    }

    /// @notice Verify backward compatibility — empty data still works on fork
    function test_withdrawRFLR_emptyData_backwardCompat() public {
        Execution[] memory executions = withdrawHook.build(address(0), TOP_HOLDER, "");

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        assertGt(wflrReceived, 0, "should receive WFLR with empty data");
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW RFLR - LOCKED-BURN PENALTY AWARENESS
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraw from a holder with locked balance — verify penalty occurs and minOut can catch it
    function test_withdrawRFLR_lockedBalance_penaltyOccurs() public {
        // SECOND_HOLDER likely has locked balance after claiming
        // First claim to ensure locked balance exists
        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();
        uint256[] memory projectIds = _allProjectIds();

        bytes memory claimData = _encodeClaimData(currentMonth, projectIds);
        Execution[] memory claimExecs = claimHook.build(address(0), SECOND_HOLDER, claimData);

        vm.startPrank(SECOND_HOLDER);
        _executeAll(claimExecs);
        vm.stopPrank();

        // Check locked balance
        (uint256 wNatBal, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(SECOND_HOLDER);
        uint256 totalBalance = wNatBal + rNatBal;
        console2.log("Total balance before withdraw:", totalBalance);
        console2.log("Locked balance:", lockedBal);

        // Withdraw with a very high minOut — if there's locked balance, penalty should cause revert
        if (lockedBal > 0) {
            // minOut = totalBalance (but penalty means we get less)
            bytes memory withdrawData = abi.encodePacked(uint8(0), totalBalance);
            Execution[] memory executions = withdrawHook.build(address(0), SECOND_HOLDER, withdrawData);

            vm.startPrank(SECOND_HOLDER);
            // Execute pre + withdrawAll
            (bool ok1,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
            assertTrue(ok1, "preExecute should succeed");
            (bool ok2,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
            assertTrue(ok2, "withdrawAll should succeed");
            // postExecute should revert — actual WFLR < totalBalance due to penalty
            (bool ok3,) = executions[2].target.call{ value: executions[2].value }(executions[2].callData);
            assertFalse(ok3, "postExecute should revert - penalty caused WFLR < minOut");
            vm.stopPrank();
        } else {
            console2.log("No locked balance - skipping penalty test (holder fully vested)");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    E2E - FULL LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Full lifecycle: claim rFLR rewards, then withdraw to WFLR
    function test_e2e_claimThenWithdraw() public {
        _skipIfNoClaimableRewards();
        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();
        uint256[] memory projectIds = _allProjectIds();

        uint256 totalClaimable = _getTotalClaimable(projectIds, SECOND_HOLDER);
        assertGt(totalClaimable, 0, "Should have claimable rewards");

        // --- Phase 1: Claim rFLR ---
        bytes memory claimData = _encodeClaimData(currentMonth, projectIds);

        uint256 rnatBefore = IERC20(FLARE_RNAT).balanceOf(SECOND_HOLDER);
        Execution[] memory claimExecs = claimHook.build(address(0), SECOND_HOLDER, claimData);

        vm.startPrank(SECOND_HOLDER);
        _executeAll(claimExecs);
        vm.stopPrank();

        uint256 rnatClaimed = IERC20(FLARE_RNAT).balanceOf(SECOND_HOLDER) - rnatBefore;
        uint256 claimOutAmount = claimHook.getOutAmount(SECOND_HOLDER);
        assertGt(rnatClaimed, 0, "Should have claimed rFLR");
        assertEq(claimOutAmount, rnatClaimed, "Claim outAmount should match actual rFLR received");
        console2.log("Phase 1 - rFLR claimed:", rnatClaimed);

        // --- Phase 2: Withdraw all rFLR to WFLR ---
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER);
        Execution[] memory withdrawExecs = withdrawHook.build(address(0), SECOND_HOLDER, "");

        vm.startPrank(SECOND_HOLDER);
        _executeAll(withdrawExecs);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER) - wflrBefore;
        uint256 withdrawOutAmount = withdrawHook.getOutAmount(SECOND_HOLDER);
        assertGt(wflrReceived, 0, "Should have received WFLR");
        assertEq(withdrawOutAmount, wflrReceived, "Withdraw outAmount should match actual WFLR received");
        console2.log("Phase 2 - WFLR received:", wflrReceived);

        // Verify rFLR balance is now 0 (all withdrawn)
        uint256 rnatAfterWithdraw = IERC20(FLARE_RNAT).balanceOf(SECOND_HOLDER);
        assertEq(rnatAfterWithdraw, 0, "rFLR balance should be 0 after withdrawAll");
        console2.log("Final rFLR balance:", rnatAfterWithdraw);
    }

    /*//////////////////////////////////////////////////////////////
           E2E - FULL LIFECYCLE WITH MINOUT SLIPPAGE PROTECTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Full lifecycle with minOut: claim → withdraw with slippage floor
    function test_e2e_claimThenWithdraw_withMinOut() public {
        _skipIfNoClaimableRewards();
        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();
        uint256[] memory projectIds = _allProjectIds();

        // --- Phase 1: Claim rFLR ---
        bytes memory claimData = _encodeClaimData(currentMonth, projectIds);
        Execution[] memory claimExecs = claimHook.build(address(0), SECOND_HOLDER, claimData);

        vm.startPrank(SECOND_HOLDER);
        _executeAll(claimExecs);
        vm.stopPrank();

        uint256 claimedAmount = claimHook.getOutAmount(SECOND_HOLDER);
        assertGt(claimedAmount, 0, "Should have claimed rFLR");
        console2.log("Claimed rFLR:", claimedAmount);

        // --- Phase 2: Withdraw with minOut = 1 (conservative floor) ---
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER);
        bytes memory withdrawData = abi.encodePacked(uint8(0), uint256(1));
        Execution[] memory withdrawExecs = withdrawHook.build(address(0), SECOND_HOLDER, withdrawData);

        vm.startPrank(SECOND_HOLDER);
        _executeAll(withdrawExecs);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER) - wflrBefore;
        assertGt(wflrReceived, 0, "Should have received WFLR");

        // WFLR may be less than claimed due to 50% penalty on locked portion
        console2.log("WFLR received (after any penalty):", wflrReceived);
        if (wflrReceived < claimedAmount) {
            console2.log("Penalty applied - WFLR < claimed rFLR");
        }
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR HOOK - SANITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify holder has vested (unlocked) rFLR balance
    function test_withdrawVestedRFLR_sanity() public view {
        (uint256 wNatBal, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 vested = rNatBal > lockedBal ? rNatBal - lockedBal : 0;

        console2.log("wNat balance:", wNatBal);
        console2.log("rNat balance:", rNatBal);
        console2.log("locked balance:", lockedBal);
        console2.log("Vested (penalty-free):", vested);

        assertGt(vested, 0, "Top holder should have vested rFLR");
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR HOOK - BUILD & EXECUTE
    //////////////////////////////////////////////////////////////*/

    /// @notice Build and execute vested-only withdrawal, verify WFLR received without penalty
    function test_withdrawVestedRFLR_buildAndExecute() public {
        (, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 expectedVested = rNatBal - lockedBal;
        assertGt(expectedVested, 0, "Need vested balance for test");

        Execution[] memory executions = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        // pre + withdraw + post = 3
        assertEq(executions.length, 3, "Should have 3 executions (pre + withdraw + post)");
        assertEq(executions[1].target, FLARE_RNAT, "Withdraw target should be RNat");

        // Verify calldata encodes withdraw(vestedAmount, true) — not withdrawAll
        bytes memory expectedCalldata =
            abi.encodeCall(IRNat.withdraw, (uint128(expectedVested), true));
        assertEq(executions[1].callData, expectedCalldata, "Should call withdraw(vested, true)");

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        assertGt(wflrReceived, 0, "Should receive WFLR from vested withdrawal");
        console2.log("WFLR received (vested only, no penalty):", wflrReceived);
    }

    /// @notice Verify pre/post execute correctly tracks the WFLR balance delta
    function test_withdrawVestedRFLR_prePostExecute_tracksBalance() public {
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        Execution[] memory executions = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 outAmount = withdrawVestedHook.getOutAmount(TOP_HOLDER);
        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;

        assertGt(outAmount, 0, "outAmount should be > 0 after vested withdrawal");
        assertEq(outAmount, wflrReceived, "outAmount should match actual WFLR received");
        console2.log("Tracked WFLR delta:", outAmount);
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - NO PENALTY VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Compare vested-only vs withdrawAll: vested hook should receive exactly the vested amount
    function test_withdrawVestedRFLR_noPenalty_comparedToWithdrawAll() public {
        (, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 vestedAmount = rNatBal - lockedBal;
        assertGt(vestedAmount, 0, "Need vested balance for test");

        // --- Vested-only withdrawal ---
        uint256 snapshotId = vm.snapshotState();

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);
        Execution[] memory vestedExecs = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        _executeAll(vestedExecs);
        vm.stopPrank();

        uint256 wflrFromVested = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;

        // After vested withdrawal, locked balance should remain intact
        (, uint256 rNatBalAfter,) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        console2.log("WFLR from vested withdrawal:", wflrFromVested);
        console2.log("rNat balance after vested withdrawal:", rNatBalAfter);

        vm.revertToState(snapshotId);

        // --- WithdrawAll for comparison ---
        wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);
        Execution[] memory allExecs = withdrawHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        _executeAll(allExecs);
        vm.stopPrank();

        uint256 wflrFromAll = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        console2.log("WFLR from withdrawAll:", wflrFromAll);

        // Vested-only should return <= withdrawAll (no penalty on vested, but withdrawAll includes locked minus penalty)
        if (lockedBal > 0) {
            // withdrawAll penalizes locked portion 50%, so it may return more or less than vested-only
            // But vested-only is guaranteed penalty-free
            console2.log("Locked balance was:", lockedBal);
            console2.log("Vested withdrawal preserved locked tokens, withdrawAll burned 50% of locked");
        }

        // The key invariant: vested withdrawal should return exactly the vested amount
        assertEq(wflrFromVested, vestedAmount, "Vested withdrawal should return exactly vestedAmount in WFLR");
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - SLIPPAGE PROTECTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Vested withdrawal with conservative minOut passes
    function test_withdrawVestedRFLR_withMinOut_passes() public {
        // minOut = 1 wei — should always pass
        bytes memory data = abi.encode(uint256(1));
        Execution[] memory executions = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        vm.startPrank(TOP_HOLDER);
        // Execute pre
        (bool ok0,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        assertTrue(ok0, "preExecute failed");
        // Execute withdraw
        (bool ok1,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertTrue(ok1, "withdraw failed");
        // Execute post with minOut data
        (bool ok2,) = address(withdrawVestedHook).call(
            abi.encodeWithSelector(withdrawVestedHook.postExecute.selector, address(0), TOP_HOLDER, data)
        );
        assertTrue(ok2, "postExecute with minOut=1 should pass");
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        assertGt(wflrReceived, 0, "Should receive WFLR");
        console2.log("WFLR received with minOut=1:", wflrReceived);
    }

    /// @notice Vested withdrawal with impossibly high minOut reverts
    function test_withdrawVestedRFLR_withMinOut_reverts() public {
        bytes memory data = abi.encode(type(uint256).max);
        Execution[] memory executions = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        // Execute pre + withdraw (succeed)
        (bool ok0,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        assertTrue(ok0, "preExecute should succeed");
        (bool ok1,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertTrue(ok1, "withdraw should succeed");

        // postExecute with impossibly high minOut should revert
        (bool ok2,) = address(withdrawVestedHook).call(
            abi.encodeWithSelector(withdrawVestedHook.postExecute.selector, address(0), TOP_HOLDER, data)
        );
        assertFalse(ok2, "postExecute should revert due to slippage");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - INSPECT
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify inspect() returns the real RNAT address
    function test_withdrawVestedRFLR_inspect_returnsRNat() public view {
        bytes memory result = withdrawVestedHook.inspect("");
        assertEq(result, abi.encodePacked(FLARE_RNAT), "inspect should return RNAT address");
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - REVERT ON ZERO VESTED
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify build reverts when account has no RNat account
    /// @dev Real RNat contract reverts with "no RNat account" for unknown addresses
    function test_withdrawVestedRFLR_revertIf_noRNatAccount() public {
        address noBalance = makeAddr("noBalance");

        vm.expectRevert("no RNat account");
        withdrawVestedHook.build(address(0), noBalance, "");
    }

    /*//////////////////////////////////////////////////////////////
              E2E - CLAIM THEN WITHDRAW VESTED (NO PENALTY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Full lifecycle: claim rFLR, then withdraw only vested portion (no penalty)
    function test_e2e_claimThenWithdrawVested() public {
        _skipIfNoClaimableRewards();
        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();
        uint256[] memory projectIds = _allProjectIds();

        // --- Phase 1: Claim rFLR ---
        bytes memory claimData = _encodeClaimData(currentMonth, projectIds);
        Execution[] memory claimExecs = claimHook.build(address(0), SECOND_HOLDER, claimData);

        vm.startPrank(SECOND_HOLDER);
        _executeAll(claimExecs);
        vm.stopPrank();

        uint256 claimedAmount = claimHook.getOutAmount(SECOND_HOLDER);
        assertGt(claimedAmount, 0, "Should have claimed rFLR");
        console2.log("Phase 1 - rFLR claimed:", claimedAmount);

        // --- Check vested vs locked ---
        (, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(SECOND_HOLDER);
        uint256 vestedAmount = rNatBal > lockedBal ? rNatBal - lockedBal : 0;
        console2.log("rNat balance:", rNatBal);
        console2.log("locked balance:", lockedBal);
        console2.log("Vested (penalty-free):", vestedAmount);

        if (vestedAmount == 0) {
            // All freshly claimed tokens are locked — build should revert
            vm.expectRevert(WithdrawVestedRFLRHook.NOTHING_TO_WITHDRAW.selector);
            withdrawVestedHook.build(address(0), SECOND_HOLDER, "");
            console2.log("Phase 2 - All claimed tokens are locked, vested withdrawal correctly reverts");
            return;
        }

        // --- Phase 2: Withdraw only vested rFLR ---
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER);
        Execution[] memory vestedExecs = withdrawVestedHook.build(address(0), SECOND_HOLDER, "");

        vm.startPrank(SECOND_HOLDER);
        _executeAll(vestedExecs);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER) - wflrBefore;
        uint256 vestedOutAmount = withdrawVestedHook.getOutAmount(SECOND_HOLDER);
        assertGt(wflrReceived, 0, "Should have received WFLR from vested withdrawal");
        assertEq(vestedOutAmount, wflrReceived, "outAmount should match actual WFLR received");
        console2.log("Phase 2 - WFLR received (vested, no penalty):", wflrReceived);

        // Locked balance should remain untouched
        (, uint256 rNatBalAfter, uint256 lockedBalAfter) = IRNat(FLARE_RNAT).getBalancesOf(SECOND_HOLDER);
        assertEq(lockedBalAfter, lockedBal, "Locked balance should be unchanged after vested withdrawal");
        console2.log("Locked balance preserved:", lockedBalAfter);
        console2.log("Remaining rNat balance:", rNatBalAfter);
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - IDEMPOTENCY
    //////////////////////////////////////////////////////////////*/

    /// @notice After vested withdrawal, a second build should revert (or return less) since vested was drained
    function test_withdrawVestedRFLR_doubleWithdraw_secondReverts() public {
        // First withdrawal — drains vested portion
        Execution[] memory execs1 = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        _executeAll(execs1);
        vm.stopPrank();

        uint256 wflrReceived1 = withdrawVestedHook.getOutAmount(TOP_HOLDER);
        assertGt(wflrReceived1, 0, "First withdrawal should produce WFLR");

        // Second build — vested portion is now 0 (locked == rNatBalance), should revert
        (, uint256 rNatBal2, uint256 lockedBal2) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        console2.log("After 1st vested withdraw - rNat:", rNatBal2, "locked:", lockedBal2);

        if (rNatBal2 <= lockedBal2) {
            vm.expectRevert(WithdrawVestedRFLRHook.NOTHING_TO_WITHDRAW.selector);
            withdrawVestedHook.build(address(0), TOP_HOLDER, "");
            console2.log("Second build correctly reverts - no more vested tokens");
        } else {
            // Edge case: some additional vesting may have unlocked between calls (unlikely in same block)
            uint256 remaining = rNatBal2 - lockedBal2;
            console2.log("Remaining vested (due to time-based unlock):", remaining);
        }
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - LOCKED BALANCE PRESERVED
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify locked balance is exactly preserved after vested-only withdrawal
    function test_withdrawVestedRFLR_lockedBalanceExactlyPreserved() public {
        (, uint256 rNatBefore, uint256 lockedBefore) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 vestedBefore = rNatBefore - lockedBefore;
        assertGt(vestedBefore, 0, "Need vested balance");
        assertGt(lockedBefore, 0, "Need locked balance for meaningful test");

        Execution[] memory executions = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        (, uint256 rNatAfter, uint256 lockedAfter) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);

        // Locked balance must be exactly the same
        assertEq(lockedAfter, lockedBefore, "Locked balance must not change");
        // rNat balance should decrease by exactly the vested amount
        assertEq(rNatAfter, rNatBefore - vestedBefore, "rNat should decrease by exactly vestedAmount");
        // After withdrawal, rNat should equal locked (nothing more to withdraw)
        assertEq(rNatAfter, lockedAfter, "rNat should equal locked after full vested withdrawal");

        console2.log("Locked before:", lockedBefore);
        console2.log("Locked after:", lockedAfter);
        console2.log("rNat before:", rNatBefore);
        console2.log("rNat after:", rNatAfter);
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - WFLR RECEIVED == VESTED AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify WFLR received is exactly equal to the computed vested amount (1:1 ratio)
    function test_withdrawVestedRFLR_wflrReceivedEqualsVestedAmount() public {
        (, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 vestedAmount = rNatBal - lockedBal;
        assertGt(vestedAmount, 0, "Need vested balance");

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        Execution[] memory executions = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;

        // 1:1 ratio — withdraw(amount, true) gives back exactly `amount` in WFLR
        assertEq(wflrReceived, vestedAmount, "WFLR received must be exactly the vested amount (1:1)");
        // outAmount tracked by hook must also match
        assertEq(withdrawVestedHook.getOutAmount(TOP_HOLDER), vestedAmount, "outAmount must match vestedAmount");
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - EXISTING WFLR BALANCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify hook correctly handles account that already has WFLR balance
    function test_withdrawVestedRFLR_accountWithExistingWFLR() public {
        // TOP_HOLDER likely has existing WFLR — verify delta is computed correctly
        uint256 existingWflr = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);
        console2.log("Existing WFLR balance:", existingWflr);

        (, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 expectedVested = rNatBal - lockedBal;

        Execution[] memory executions = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 finalWflr = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);
        uint256 delta = finalWflr - existingWflr;

        // Delta should be exactly the vested amount, regardless of existing WFLR
        assertEq(delta, expectedVested, "Delta should equal vested amount regardless of existing WFLR");
        assertEq(withdrawVestedHook.getOutAmount(TOP_HOLDER), delta, "outAmount should equal delta");
        console2.log("Final WFLR balance:", finalWflr);
        console2.log("WFLR delta:", delta);
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - EXACT MINOUT
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify slippage passes when minOut == exact vested amount
    function test_withdrawVestedRFLR_exactMinOut_passes() public {
        (, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 vestedAmount = rNatBal - lockedBal;
        assertGt(vestedAmount, 0, "Need vested balance");

        // Build and run with exact minOut matching expected output
        bytes memory data = abi.encode(vestedAmount);
        Execution[] memory executions = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);

        vm.startPrank(TOP_HOLDER);
        // pre
        (bool ok0,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        assertTrue(ok0, "preExecute failed");
        // withdraw
        (bool ok1,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertTrue(ok1, "withdraw failed");
        // post with exact minOut
        (bool ok2,) = address(withdrawVestedHook).call(
            abi.encodeWithSelector(withdrawVestedHook.postExecute.selector, address(0), TOP_HOLDER, data)
        );
        assertTrue(ok2, "postExecute with exact minOut should pass");
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        assertEq(wflrReceived, vestedAmount, "Should receive exactly vestedAmount");
    }

    /// @notice Verify slippage fails when minOut == vestedAmount + 1
    function test_withdrawVestedRFLR_minOutPlusOne_reverts() public {
        (, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 vestedAmount = rNatBal - lockedBal;
        assertGt(vestedAmount, 0, "Need vested balance");

        bytes memory data = abi.encode(vestedAmount + 1);
        Execution[] memory executions = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        (bool ok0,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        assertTrue(ok0, "preExecute should succeed");
        (bool ok1,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertTrue(ok1, "withdraw should succeed");

        // minOut = vestedAmount + 1 should fail
        (bool ok2,) = address(withdrawVestedHook).call(
            abi.encodeWithSelector(withdrawVestedHook.postExecute.selector, address(0), TOP_HOLDER, data)
        );
        assertFalse(ok2, "postExecute should revert - minOut exceeds actual by 1 wei");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - SECOND HOLDER (MIXED STATE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test vested withdrawal using SECOND_HOLDER which has a different vested/locked ratio
    function test_withdrawVestedRFLR_secondHolder() public {
        (, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(SECOND_HOLDER);
        uint256 vestedAmount = rNatBal > lockedBal ? rNatBal - lockedBal : 0;

        console2.log("SECOND_HOLDER rNat:", rNatBal);
        console2.log("SECOND_HOLDER locked:", lockedBal);
        console2.log("SECOND_HOLDER vested:", vestedAmount);

        if (vestedAmount == 0) {
            vm.expectRevert(WithdrawVestedRFLRHook.NOTHING_TO_WITHDRAW.selector);
            withdrawVestedHook.build(address(0), SECOND_HOLDER, "");
            console2.log("SECOND_HOLDER has no vested tokens - correctly reverts");
            return;
        }

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER);
        Execution[] memory executions = withdrawVestedHook.build(address(0), SECOND_HOLDER, "");

        vm.startPrank(SECOND_HOLDER);
        _executeAll(executions);
        vm.stopPrank();

        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER) - wflrBefore;
        assertEq(wflrReceived, vestedAmount, "WFLR received should equal vested amount");

        (,, uint256 lockedAfter) = IRNat(FLARE_RNAT).getBalancesOf(SECOND_HOLDER);
        assertEq(lockedAfter, lockedBal, "Locked balance must be preserved");
        console2.log("WFLR received:", wflrReceived);
        console2.log("Locked preserved:", lockedAfter);
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - CONSTRUCTOR VALIDATION ON FORK
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify constructor stores correct immutables on fork
    function test_withdrawVestedRFLR_constructorImmutables() public view {
        assertEq(withdrawVestedHook.RNAT(), FLARE_RNAT, "RNAT should be real RNat address");
        assertEq(withdrawVestedHook.WFLR(), FLARE_WFLR, "WFLR should be real WFLR address");
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - ASSET SET CORRECTLY
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify asset is set to WFLR after preExecute on fork
    function test_withdrawVestedRFLR_assetSetToWFLR() public {
        withdrawVestedHook.setExecutionContext(TOP_HOLDER);

        vm.prank(TOP_HOLDER);
        withdrawVestedHook.preExecute(address(0), TOP_HOLDER, "");

        assertEq(withdrawVestedHook.asset(), FLARE_WFLR, "asset should be WFLR after preExecute");
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED RFLR - POSTEXECUTE SAFE DELTA ON FORK
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify postExecute produces 0 delta (not revert) when WFLR balance decreases between pre and post
    function test_withdrawVestedRFLR_postExecute_zeroDeltaWhenBalanceDecreases() public {
        address testAccount = makeAddr("vestedTestAccount");

        // Give testAccount WFLR via deal
        deal(FLARE_WFLR, testAccount, 500 ether);

        withdrawVestedHook.setExecutionContext(testAccount);

        vm.prank(testAccount);
        withdrawVestedHook.preExecute(address(0), testAccount, "");
        assertEq(withdrawVestedHook.getOutAmount(testAccount), 500 ether, "Should snapshot 500 WFLR");

        // Simulate balance decrease
        deal(FLARE_WFLR, testAccount, 200 ether);

        vm.prank(testAccount);
        withdrawVestedHook.postExecute(address(0), testAccount, "");
        assertEq(withdrawVestedHook.getOutAmount(testAccount), 0, "outAmount should be 0 when balance decreased");
    }

    /*//////////////////////////////////////////////////////////////
              E2E - CLAIM THEN VESTED WITHDRAW THEN VERIFY REMAINING
    //////////////////////////////////////////////////////////////*/

    /// @notice Claim → vested withdraw → verify remaining locked can still be withdrawn via withdrawAll
    function test_e2e_claimThenVestedThenWithdrawAll() public {
        _skipIfNoClaimableRewards();
        uint256 currentMonth = IRNat(FLARE_RNAT).getCurrentMonth();
        uint256[] memory projectIds = _allProjectIds();

        // --- Phase 1: Claim rFLR ---
        bytes memory claimData = _encodeClaimData(currentMonth, projectIds);
        Execution[] memory claimExecs = claimHook.build(address(0), SECOND_HOLDER, claimData);

        vm.startPrank(SECOND_HOLDER);
        _executeAll(claimExecs);
        vm.stopPrank();

        uint256 claimedAmount = claimHook.getOutAmount(SECOND_HOLDER);
        assertGt(claimedAmount, 0, "Should have claimed rFLR");
        console2.log("Phase 1 - Claimed rFLR:", claimedAmount);

        // --- Phase 2: Vested-only withdrawal ---
        (, uint256 rNatMid, uint256 lockedMid) = IRNat(FLARE_RNAT).getBalancesOf(SECOND_HOLDER);
        uint256 vestedMid = rNatMid > lockedMid ? rNatMid - lockedMid : 0;

        if (vestedMid == 0) {
            console2.log("Phase 2 - No vested tokens, skipping vested withdrawal");
        } else {
            uint256 wflrBefore2 = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER);
            Execution[] memory vestedExecs = withdrawVestedHook.build(address(0), SECOND_HOLDER, "");

            vm.startPrank(SECOND_HOLDER);
            _executeAll(vestedExecs);
            vm.stopPrank();

            uint256 wflrFromVested = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER) - wflrBefore2;
            console2.log("Phase 2 - WFLR from vested (penalty-free):", wflrFromVested);
        }

        // --- Phase 3: WithdrawAll for remaining locked (with 50% penalty) ---
        (, uint256 rNatRemaining, uint256 lockedRemaining) = IRNat(FLARE_RNAT).getBalancesOf(SECOND_HOLDER);
        console2.log("Phase 3 - rNat remaining:", rNatRemaining, "locked:", lockedRemaining);

        if (rNatRemaining == 0) {
            console2.log("Phase 3 - No remaining balance, skipping withdrawAll");
            return;
        }

        uint256 wflrBefore3 = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER);
        Execution[] memory allExecs = withdrawHook.build(address(0), SECOND_HOLDER, "");

        vm.startPrank(SECOND_HOLDER);
        _executeAll(allExecs);
        vm.stopPrank();

        uint256 wflrFromAll = IERC20(FLARE_WFLR).balanceOf(SECOND_HOLDER) - wflrBefore3;
        console2.log("Phase 3 - WFLR from withdrawAll (with penalty):", wflrFromAll);

        // After withdrawAll, rFLR balance should be 0
        uint256 finalRNat = IERC20(FLARE_RNAT).balanceOf(SECOND_HOLDER);
        assertEq(finalRNat, 0, "rFLR should be 0 after withdrawAll");

        // withdrawAll gives less per locked token due to 50% burn
        if (lockedRemaining > 0) {
            assertLt(wflrFromAll, lockedRemaining, "withdrawAll should return < locked due to 50% penalty");
            console2.log("Penalty confirmed: received %d from %d locked", wflrFromAll, lockedRemaining);
        }
    }

    /*//////////////////////////////////////////////////////////////
              WITHDRAW VESTED vs WITHDRAWALL — QUANTIFY SAVINGS
    //////////////////////////////////////////////////////////////*/

    /// @notice Quantify WFLR savings from using vested-only withdrawal vs withdrawAll
    function test_withdrawVestedRFLR_quantifySavingsVsWithdrawAll() public {
        (, uint256 rNatBal, uint256 lockedBal) = IRNat(FLARE_RNAT).getBalancesOf(TOP_HOLDER);
        uint256 vestedAmount = rNatBal - lockedBal;
        assertGt(vestedAmount, 0, "Need vested balance");
        assertGt(lockedBal, 0, "Need locked balance for meaningful comparison");

        // --- Strategy A: Vested-only withdrawal (penalty-free) ---
        uint256 snapshotId = vm.snapshotState();

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);
        Execution[] memory vestedExecs = withdrawVestedHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        _executeAll(vestedExecs);
        vm.stopPrank();

        uint256 wflrFromVestedOnly = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;
        uint256 rNatPreserved = IERC20(FLARE_RNAT).balanceOf(TOP_HOLDER);

        vm.revertToState(snapshotId);

        // --- Strategy B: WithdrawAll (50% penalty on locked) ---
        wflrBefore = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER);
        Execution[] memory allExecs = withdrawHook.build(address(0), TOP_HOLDER, "");

        vm.startPrank(TOP_HOLDER);
        _executeAll(allExecs);
        vm.stopPrank();

        uint256 wflrFromWithdrawAll = IERC20(FLARE_WFLR).balanceOf(TOP_HOLDER) - wflrBefore;

        // --- Compare ---
        // withdrawAll gives: vested + (locked * 0.5)
        // vestedOnly gives: vested (preserving locked for future vesting)
        uint256 lockedBurned = lockedBal / 2; // 50% penalty

        console2.log("=== STRATEGY COMPARISON ===");
        console2.log("Vested amount:", vestedAmount);
        console2.log("Locked amount:", lockedBal);
        console2.log("Strategy A (vested-only) WFLR:", wflrFromVestedOnly);
        console2.log("Strategy A rFLR preserved:", rNatPreserved);
        console2.log("Strategy B (withdrawAll) WFLR:", wflrFromWithdrawAll);
        console2.log("Locked tokens burned by B:", lockedBurned);

        // Strategy B returns more WFLR now, but burns locked tokens
        assertGt(wflrFromWithdrawAll, wflrFromVestedOnly, "withdrawAll returns more immediate WFLR");
        // But Strategy A preserves locked balance for future vesting
        assertGt(rNatPreserved, 0, "Vested-only preserves locked rFLR for future");
        // The cost of using withdrawAll is the burned locked tokens
        assertEq(
            wflrFromWithdrawAll,
            wflrFromVestedOnly + (lockedBal - lockedBurned),
            "withdrawAll = vested + 50% of locked"
        );
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns all active project IDs
    function _allProjectIds() internal pure returns (uint256[] memory projectIds) {
        projectIds = new uint256[](4);
        projectIds[0] = PROJECT_SPARKDEX;
        projectIds[1] = PROJECT_BLAZESWAP;
        projectIds[2] = PROJECT_KINETIC;
        projectIds[3] = PROJECT_ENOSYS;
    }

    /// @dev Sum claimable rewards across all projects for a holder
    function _getTotalClaimable(
        uint256[] memory projectIds,
        address holder
    )
        internal
        view
        returns (uint256 total)
    {
        for (uint256 i; i < projectIds.length; ++i) {
            total += IRNat(FLARE_RNAT).getClaimableRewards(projectIds[i], holder);
        }
    }

    /// @dev Encode ClaimRFLRHook data (no fee — rFLR is non-transferable)
    function _encodeClaimData(
        uint256 month,
        uint256[] memory projectIds
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory data = abi.encodePacked(month, projectIds.length);

        for (uint256 i; i < projectIds.length; ++i) {
            data = abi.encodePacked(data, projectIds[i]);
        }

        return data;
    }

    /// @dev Execute all executions sequentially
    function _executeAll(Execution[] memory executions) internal {
        for (uint256 i; i < executions.length; ++i) {
            (bool success, bytes memory returnData) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string.concat("Execution ", vm.toString(i), " failed: ", vm.toString(returnData)));
        }
    }
}
