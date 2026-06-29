// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { EthenaCooldownSharesHook } from "../../../src/hooks/vaults/ethena/EthenaCooldownSharesHook.sol";
import { EthenaUnstakeHook } from "../../../src/hooks/vaults/ethena/EthenaUnstakeHook.sol";
import { IStakedUSDeCooldown, UserCooldown } from "../../../src/vendor/ethena/IStakedUSDeCooldown.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title EthenaHooksE2E
/// @notice Fork integration tests for Ethena cooldown and unstake hooks
contract EthenaHooksE2E is Test, Constants {
    EthenaCooldownSharesHook public cooldownHook;
    EthenaUnstakeHook public unstakeHook;

    address public account;
    address public constant SUSDE = CHAIN_1_SUSDE;
    address public constant USDE = CHAIN_1_USDE;

    // sUSDe cooldown silo (where USDe goes during cooldown) — read from contract
    bytes32 public constant YIELD_SOURCE_ORACLE_ID = bytes32(0);

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK);

        account = address(this);
        cooldownHook = new EthenaCooldownSharesHook();
        unstakeHook = new EthenaUnstakeHook();
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

    /// @dev Build hook data: bytes32 oracleId + address yieldSource + uint256 shares + bool usePrevHookAmount
    function _buildCooldownData(uint256 shares) internal pure returns (bytes memory) {
        return bytes.concat(
            bytes32(YIELD_SOURCE_ORACLE_ID),
            bytes20(SUSDE),
            bytes32(shares),
            bytes1(0x00) // usePrevHookAmount = false
        );
    }

    /// @dev Build hook data: bytes32 oracleId + address yieldSource
    function _buildUnstakeData() internal pure returns (bytes memory) {
        return bytes.concat(bytes32(YIELD_SOURCE_ORACLE_ID), bytes20(SUSDE));
    }

    /*//////////////////////////////////////////////////////////////
                         COOLDOWN SHARES TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test EthenaCooldownSharesHook: deal sUSDe → cooldownShares → assert sUSDe balance decreased
    function test_EthenaCooldownShares() public {
        uint256 shares = 10e18; // 10 sUSDe
        deal(SUSDE, account, shares);

        uint256 susdeBalanceBefore = IERC20(SUSDE).balanceOf(account);
        assertEq(susdeBalanceBefore, shares, "Should have sUSDe");

        bytes memory hookData = _buildCooldownData(shares);
        Execution[] memory executions = cooldownHook.build(address(0), account, hookData);

        _executeAll(executions);

        uint256 susdeBalanceAfter = IERC20(SUSDE).balanceOf(account);
        assertLt(susdeBalanceAfter, susdeBalanceBefore, "sUSDe balance should decrease after cooldown");
        assertEq(susdeBalanceAfter, 0, "All sUSDe should be locked in cooldown");
    }

    /*//////////////////////////////////////////////////////////////
                         UNSTAKE TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test EthenaUnstakeHook: cooldown first, warp past duration → unstake → assert USDe received
    function test_EthenaUnstake() public {
        uint256 shares = 10e18;
        deal(SUSDE, account, shares);

        // Step 1: Start cooldown
        bytes memory cooldownData = _buildCooldownData(shares);
        Execution[] memory cooldownExecs = cooldownHook.build(address(0), account, cooldownData);
        _executeAll(cooldownExecs);

        // Step 2: Warp past cooldown duration (90 days for sUSDe v2)
        vm.warp(block.timestamp + 90 days + 1);

        // Step 3: Unstake
        uint256 usdeBalanceBefore = IERC20(USDE).balanceOf(account);

        bytes memory unstakeData = _buildUnstakeData();
        Execution[] memory unstakeExecs = unstakeHook.build(address(0), account, unstakeData);
        _executeAll(unstakeExecs);

        uint256 usdeBalanceAfter = IERC20(USDE).balanceOf(account);
        assertGt(usdeBalanceAfter, usdeBalanceBefore, "Should receive USDe after unstaking");
    }
}
