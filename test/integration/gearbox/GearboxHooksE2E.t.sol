// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { GearboxStakeHook } from "../../../src/hooks/stake/gearbox/GearboxStakeHook.sol";
import { GearboxUnstakeHook } from "../../../src/hooks/stake/gearbox/GearboxUnstakeHook.sol";
import { ApproveAndGearboxStakeHook } from "../../../src/hooks/stake/gearbox/ApproveAndGearboxStakeHook.sol";
import { GearboxClaimRewardHook } from "../../../src/hooks/claim/gearbox/GearboxClaimRewardHook.sol";
import { IGearboxFarmingPool } from "../../../src/vendor/gearbox/IGearboxFarmingPool.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title GearboxHooksE2E
/// @notice Fork integration tests for Gearbox stake/unstake/claim hooks
contract GearboxHooksE2E is Test, Constants {
    GearboxStakeHook public stakeHook;
    GearboxUnstakeHook public unstakeHook;
    ApproveAndGearboxStakeHook public approveAndStakeHook;
    GearboxClaimRewardHook public claimHook;

    address public account;
    address public constant GEARBOX_STAKING_POOL = CHAIN_1_GEARBOX_STAKING;

    // Resolved on-chain
    address public stakingToken;
    address public rewardsToken;

    bytes32 public constant YIELD_SOURCE_ORACLE_ID = bytes32(0);

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK);

        account = address(this);
        stakeHook = new GearboxStakeHook();
        unstakeHook = new GearboxUnstakeHook();
        approveAndStakeHook = new ApproveAndGearboxStakeHook();
        claimHook = new GearboxClaimRewardHook();

        stakingToken = IGearboxFarmingPool(GEARBOX_STAKING_POOL).stakingToken();
        rewardsToken = IGearboxFarmingPool(GEARBOX_STAKING_POOL).rewardsToken();
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
            bytes20(GEARBOX_STAKING_POOL),
            bytes32(amount),
            bytes1(0x00) // usePrevHookAmount = false
        );
    }

    /// @dev Build data: bytes32 oracleId + address yieldSource + address token + uint256 amount + bool usePrevHookAmount
    function _buildApproveAndStakeData(uint256 amount) internal view returns (bytes memory) {
        return bytes.concat(
            bytes32(YIELD_SOURCE_ORACLE_ID),
            bytes20(GEARBOX_STAKING_POOL),
            bytes20(stakingToken),
            bytes32(amount),
            bytes1(0x00) // usePrevHookAmount = false
        );
    }

    /// @dev Build claim data: bytes32 placeholder + address farmingPool + address rewardToken + address account
    function _buildClaimData() internal view returns (bytes memory) {
        return bytes.concat(
            bytes32(YIELD_SOURCE_ORACLE_ID),
            bytes20(GEARBOX_STAKING_POOL),
            bytes20(rewardsToken),
            bytes20(account)
        );
    }

    /*//////////////////////////////////////////////////////////////
                         STAKE TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test GearboxStakeHook: deal dToken → pre-approve → stake → assert staked balance
    function test_GearboxStake() public {
        uint256 amount = 100e18;
        deal(stakingToken, account, amount);

        // Pre-approve the staking pool
        IERC20(stakingToken).approve(GEARBOX_STAKING_POOL, amount);

        uint256 stakedBefore = IGearboxFarmingPool(GEARBOX_STAKING_POOL).balanceOf(account);

        bytes memory hookData = _buildStakeData(amount);
        Execution[] memory executions = stakeHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 stakedAfter = IGearboxFarmingPool(GEARBOX_STAKING_POOL).balanceOf(account);
        assertGt(stakedAfter, stakedBefore, "Staked balance should increase");
        assertEq(stakedAfter - stakedBefore, amount, "Should stake exact amount");
    }

    /*//////////////////////////////////////////////////////////////
                         APPROVE AND STAKE TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test ApproveAndGearboxStakeHook: deal dToken → single-step approve+stake
    function test_ApproveAndGearboxStake() public {
        uint256 amount = 100e18;
        deal(stakingToken, account, amount);

        uint256 stakedBefore = IGearboxFarmingPool(GEARBOX_STAKING_POOL).balanceOf(account);

        bytes memory hookData = _buildApproveAndStakeData(amount);
        Execution[] memory executions = approveAndStakeHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 stakedAfter = IGearboxFarmingPool(GEARBOX_STAKING_POOL).balanceOf(account);
        assertEq(stakedAfter - stakedBefore, amount, "Should stake exact amount via approve+stake");

        // Verify no residual approval
        assertEq(IERC20(stakingToken).allowance(account, GEARBOX_STAKING_POOL), 0, "No residual approval");
    }

    /*//////////////////////////////////////////////////////////////
                         UNSTAKE TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test GearboxUnstakeHook: stake first → unstake → assert dToken returned
    function test_GearboxUnstake() public {
        uint256 amount = 100e18;
        deal(stakingToken, account, amount);

        // Stake first
        IERC20(stakingToken).approve(GEARBOX_STAKING_POOL, amount);
        bytes memory stakeData = _buildStakeData(amount);
        Execution[] memory stakeExecs = stakeHook.build(address(0), account, stakeData);
        _executeAll(stakeExecs);

        // Now unstake
        uint256 tokenBefore = IERC20(stakingToken).balanceOf(account);

        bytes memory unstakeData = _buildStakeData(amount); // same data layout for unstake
        Execution[] memory unstakeExecs = unstakeHook.build(address(0), account, unstakeData);
        _executeAll(unstakeExecs);

        uint256 tokenAfter = IERC20(stakingToken).balanceOf(account);
        assertEq(tokenAfter - tokenBefore, amount, "Should receive staking tokens back");
    }

    /*//////////////////////////////////////////////////////////////
                         CLAIM REWARD TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test GearboxClaimRewardHook: stake, warp time → claim → assert reward received
    function test_GearboxClaimReward() public {
        uint256 amount = 1000e18;
        deal(stakingToken, account, amount);

        // Stake
        IERC20(stakingToken).approve(GEARBOX_STAKING_POOL, amount);
        bytes memory stakeData = _buildStakeData(amount);
        Execution[] memory stakeExecs = stakeHook.build(address(0), account, stakeData);
        _executeAll(stakeExecs);

        // Warp time to accumulate rewards
        vm.warp(block.timestamp + 30 days);

        // Check if there are earned rewards
        uint256 earned = IGearboxFarmingPool(GEARBOX_STAKING_POOL).farmed(account);

        // Claim
        uint256 rewardBefore = IERC20(rewardsToken).balanceOf(account);

        bytes memory claimData = _buildClaimData();
        Execution[] memory claimExecs = claimHook.build(address(0), account, claimData);
        _executeAll(claimExecs);

        uint256 rewardAfter = IERC20(rewardsToken).balanceOf(account);

        // If there are earned rewards, we should receive them
        if (earned > 0) {
            assertGt(rewardAfter, rewardBefore, "Should receive reward tokens");
        }
        // At minimum, the call should not revert
    }
}
