// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { FluidStakeHook } from "../../../src/hooks/stake/fluid/FluidStakeHook.sol";
import { FluidUnstakeHook } from "../../../src/hooks/stake/fluid/FluidUnstakeHook.sol";
import { ApproveAndFluidStakeHook } from "../../../src/hooks/stake/fluid/ApproveAndFluidStakeHook.sol";
import { FluidClaimRewardHook } from "../../../src/hooks/claim/fluid/FluidClaimRewardHook.sol";
import { IFluidLendingStakingRewards } from "../../../src/vendor/fluid/IFluidLendingStakingRewards.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title FluidHooksE2E
/// @notice Fork integration tests for Fluid stake/unstake/claim hooks
contract FluidHooksE2E is Test, Constants {
    FluidStakeHook public stakeHook;
    FluidUnstakeHook public unstakeHook;
    ApproveAndFluidStakeHook public approveAndStakeHook;
    FluidClaimRewardHook public claimHook;

    address public account;

    /// @dev CHAIN_1_FLUID_VAULT is the staking rewards contract
    address public constant FLUID_STAKING = CHAIN_1_FLUID_VAULT;

    // Resolved on-chain
    address public stakingToken;
    address public rewardsToken;

    bytes32 public constant YIELD_SOURCE_ORACLE_ID = bytes32(0);

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK);

        account = address(this);
        stakeHook = new FluidStakeHook();
        unstakeHook = new FluidUnstakeHook();
        approveAndStakeHook = new ApproveAndFluidStakeHook();
        claimHook = new FluidClaimRewardHook();

        stakingToken = IFluidLendingStakingRewards(FLUID_STAKING).stakingToken();
        rewardsToken = IFluidLendingStakingRewards(FLUID_STAKING).rewardsToken();
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                             HELPERS
    //////////////////////////////////////////////////////////////*/

    function _executeAll(Execution[] memory executions) internal {
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success, bytes memory returndata) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) {
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
        }
    }

    /// @dev Build data: bytes32 oracleId + address yieldSource + uint256 amount + bool usePrevHookAmount
    function _buildStakeData(uint256 amount) internal pure returns (bytes memory) {
        return bytes.concat(
            bytes32(YIELD_SOURCE_ORACLE_ID),
            bytes20(FLUID_STAKING),
            bytes32(amount),
            bytes1(0x00) // usePrevHookAmount = false
        );
    }

    /// @dev Build data for ApproveAndFluidStakeHook:
    ///      bytes32 oracleId + address yieldSource + address token + uint256 amount + bool usePrevHookAmount
    function _buildApproveAndStakeData(uint256 amount) internal view returns (bytes memory) {
        return bytes.concat(
            bytes32(YIELD_SOURCE_ORACLE_ID),
            bytes20(FLUID_STAKING),
            bytes20(stakingToken),
            bytes32(amount),
            bytes1(0x00) // usePrevHookAmount = false
        );
    }

    /// @dev Build claim data: bytes32 placeholder + address stakingRewards + address rewardToken + address account
    function _buildClaimData() internal view returns (bytes memory) {
        return bytes.concat(
            bytes32(YIELD_SOURCE_ORACLE_ID),
            bytes20(FLUID_STAKING),
            bytes20(rewardsToken),
            bytes20(account)
        );
    }

    /*//////////////////////////////////////////////////////////////
                         STAKE TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test FluidStakeHook: deal fToken → pre-approve → stake → assert staked balance
    function test_FluidStake() public {
        uint256 amount = 100e18;
        deal(stakingToken, account, amount);

        // Pre-approve
        IERC20(stakingToken).approve(FLUID_STAKING, amount);

        uint256 stakedBefore = IFluidLendingStakingRewards(FLUID_STAKING).balanceOf(account);

        bytes memory hookData = _buildStakeData(amount);
        Execution[] memory executions = stakeHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 stakedAfter = IFluidLendingStakingRewards(FLUID_STAKING).balanceOf(account);
        assertEq(stakedAfter - stakedBefore, amount, "Should stake exact amount");
    }

    /*//////////////////////////////////////////////////////////////
                         APPROVE AND STAKE TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test ApproveAndFluidStakeHook: deal fToken → single-step approve+stake
    function test_ApproveAndFluidStake() public {
        uint256 amount = 100e18;
        deal(stakingToken, account, amount);

        uint256 stakedBefore = IFluidLendingStakingRewards(FLUID_STAKING).balanceOf(account);

        bytes memory hookData = _buildApproveAndStakeData(amount);
        Execution[] memory executions = approveAndStakeHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 stakedAfter = IFluidLendingStakingRewards(FLUID_STAKING).balanceOf(account);
        assertEq(stakedAfter - stakedBefore, amount, "Should stake exact amount via approve+stake");

        // Verify no residual approval
        assertEq(IERC20(stakingToken).allowance(account, FLUID_STAKING), 0, "No residual approval");
    }

    /*//////////////////////////////////////////////////////////////
                         UNSTAKE TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test FluidUnstakeHook: stake first → unstake → assert fToken returned
    function test_FluidUnstake() public {
        uint256 amount = 100e18;
        deal(stakingToken, account, amount);

        // Stake first
        IERC20(stakingToken).approve(FLUID_STAKING, amount);
        bytes memory stakeData = _buildStakeData(amount);
        Execution[] memory stakeExecs = stakeHook.build(address(0), account, stakeData);
        _executeAll(stakeExecs);

        // Now unstake
        uint256 tokenBefore = IERC20(stakingToken).balanceOf(account);

        bytes memory unstakeData = _buildStakeData(amount); // same data layout
        Execution[] memory unstakeExecs = unstakeHook.build(address(0), account, unstakeData);
        _executeAll(unstakeExecs);

        uint256 tokenAfter = IERC20(stakingToken).balanceOf(account);
        assertEq(tokenAfter - tokenBefore, amount, "Should receive staking tokens back");
    }

    /*//////////////////////////////////////////////////////////////
                         CLAIM REWARD TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test FluidClaimRewardHook: stake, warp time → claim → assert reward received (or no-revert)
    function test_FluidClaimReward() public {
        uint256 amount = 1000e18;
        deal(stakingToken, account, amount);

        // Stake
        IERC20(stakingToken).approve(FLUID_STAKING, amount);
        bytes memory stakeData = _buildStakeData(amount);
        Execution[] memory stakeExecs = stakeHook.build(address(0), account, stakeData);
        _executeAll(stakeExecs);

        // Warp time to accumulate rewards
        vm.warp(block.timestamp + 30 days);

        // Check earned
        uint256 earned = IFluidLendingStakingRewards(FLUID_STAKING).earned(account);

        // Claim
        uint256 rewardBefore = IERC20(rewardsToken).balanceOf(account);

        bytes memory claimData = _buildClaimData();
        Execution[] memory claimExecs = claimHook.build(address(0), account, claimData);
        _executeAll(claimExecs);

        uint256 rewardAfter = IERC20(rewardsToken).balanceOf(account);

        if (earned > 0) {
            assertGt(rewardAfter, rewardBefore, "Should receive reward tokens");
        }
    }
}
