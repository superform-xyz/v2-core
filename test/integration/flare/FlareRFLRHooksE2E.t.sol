// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ClaimRFLRHook } from "../../../src/hooks/claim/flare/ClaimRFLRHook.sol";
import { WithdrawRFLRHook } from "../../../src/hooks/claim/flare/WithdrawRFLRHook.sol";
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

    uint256 public forkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString(FLARE_RPC_URL_KEY));

        claimHook = new ClaimRFLRHook(FLARE_RNAT);
        withdrawHook = new WithdrawRFLRHook(FLARE_RNAT, FLARE_WFLR);
    }

    /*//////////////////////////////////////////////////////////////
                    CLAIM RFLR HOOK - SANITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify RNat contract responds, holder has balance, and claimable rewards exist
    function test_claimRFLR_sanity() public view {
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
        assertGt(claimableKinetic, 0, "Second holder should have claimable rewards on Kinetic");
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
                    E2E - FULL LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Full lifecycle: claim rFLR rewards, then withdraw to WFLR
    function test_e2e_claimThenWithdraw() public {
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
