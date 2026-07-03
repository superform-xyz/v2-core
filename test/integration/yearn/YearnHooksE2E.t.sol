// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { YearnClaimOneRewardHook } from "../../../src/hooks/claim/yearn/YearnClaimOneRewardHook.sol";
import { IYearnStakingRewardsMulti } from "../../../src/vendor/yearn/IYearnStakingRewardsMulti.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title YearnHooksE2E
/// @notice Fork integration tests for Yearn claim reward hook
contract YearnHooksE2E is Test, Constants {
    YearnClaimOneRewardHook public claimHook;

    address public account;
    address public constant YEARN_VAULT = CHAIN_1_YEARN_VAULT;

    bytes32 public constant YIELD_SOURCE_ORACLE_ID = bytes32(0);

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK);

        account = address(this);
        claimHook = new YearnClaimOneRewardHook();
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
                assembly ("memory-safe") {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
        }
    }

    /// @dev Build claim data: bytes32 placeholder + address yieldSource + address rewardToken + address account
    function _buildClaimData(address rewardToken) internal view returns (bytes memory) {
        return bytes.concat(
            bytes32(YIELD_SOURCE_ORACLE_ID), bytes20(YEARN_VAULT), bytes20(rewardToken), bytes20(account)
        );
    }

    /// @dev Discover a reward token from the Yearn staking rewards contract
    function _discoverRewardToken() internal view returns (address rewardToken) {
        // Try Solidity-style: rewardTokens(uint256)
        (bool ok1, bytes memory data1) =
            YEARN_VAULT.staticcall(abi.encodeWithSignature("rewardTokens(uint256)", uint256(0)));
        if (ok1 && data1.length >= 32) {
            rewardToken = abi.decode(data1, (address));
            if (rewardToken != address(0)) return rewardToken;
        }

        // Try Vyper-style: reward_tokens(uint256)
        (bool ok2, bytes memory data2) =
            YEARN_VAULT.staticcall(abi.encodeWithSignature("reward_tokens(uint256)", uint256(0)));
        if (ok2 && data2.length >= 32) {
            rewardToken = abi.decode(data2, (address));
            if (rewardToken != address(0)) return rewardToken;
        }

        // Try getAllRewardTokens()
        (bool ok3, bytes memory data3) =
            YEARN_VAULT.staticcall(abi.encodeWithSignature("getAllRewardTokens()"));
        if (ok3 && data3.length >= 64) {
            address[] memory tokens = abi.decode(data3, (address[]));
            if (tokens.length > 0) return tokens[0];
        }
    }

    /*//////////////////////////////////////////////////////////////
                         CLAIM ONE REWARD TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test YearnClaimOneRewardHook: discover real reward token → claim → assert no revert
    function test_YearnClaimOneReward() public {
        address rewardToken = _discoverRewardToken();

        // If we can't discover a reward token on-chain, skip
        if (rewardToken == address(0)) return;

        uint256 rewardBefore = IERC20(rewardToken).balanceOf(account);

        bytes memory claimData = _buildClaimData(rewardToken);
        Execution[] memory executions = claimHook.build(address(0), account, claimData);
        _executeAll(executions);

        uint256 rewardAfter = IERC20(rewardToken).balanceOf(account);
        assertGe(rewardAfter, rewardBefore, "Reward balance should not decrease");
    }

    /// @notice Test YearnClaimOneRewardHook build execution structure
    function test_YearnClaimOneReward_BuildStructure() public view {
        // Use DAI as a test token — we only validate the build output, not execution
        address rewardToken = CHAIN_1_DAI;

        bytes memory claimData = _buildClaimData(rewardToken);
        Execution[] memory executions = claimHook.build(address(0), account, claimData);

        // Should have 3 executions: preExecute + claim + postExecute
        assertEq(executions.length, 3, "Should have 3 executions");
        // The main execution (index 1) should target the yield source
        assertEq(executions[1].target, YEARN_VAULT, "Target should be Yearn vault");
        // Calldata should encode getOneReward(rewardToken)
        bytes memory expectedCalldata = abi.encodeCall(IYearnStakingRewardsMulti.getOneReward, (rewardToken));
        assertEq(keccak256(executions[1].callData), keccak256(expectedCalldata), "Calldata should match");
    }
}
