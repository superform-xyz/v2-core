// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { FluidClaimRewardHook } from "../../../../../src/core/hooks/claim/fluid/FluidClaimRewardHook.sol";

contract MockFluidStakingRewards {
    address public rewardToken;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function getReward() external {
        IERC20(rewardToken).transfer(msg.sender, 1 ether);
    }
}

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract MockBaseLedger {
    mapping(address => uint256) public balances;

    function updateBalance(address user, uint256 amount) external {
        balances[user] += amount;
    }
}

contract FluidClaimRewardHookPoC is Test {
    FluidClaimRewardHook hook;
    MockFluidStakingRewards stakingRewards;
    MockERC20 rewardToken;
    MockERC20 fakeToken;
    MockBaseLedger ledger;
    address account = address(0x0000000000000000000000000000000000000001);
    address attacker = address(0x0000000000000000000000000000000000000002);

    function setUp() public {
        rewardToken = new MockERC20();
        fakeToken = new MockERC20();
        stakingRewards = new MockFluidStakingRewards(address(rewardToken));
        hook = new FluidClaimRewardHook();
        ledger = new MockBaseLedger();

        // Mint tokens
        rewardToken.mint(address(this), 2 ether);
        rewardToken.mint(account, 1 ether);
        rewardToken.mint(address(stakingRewards), 1 ether);
        fakeToken.mint(account, 100 ether);
    }

    function testMismatchedRewardToken() public {
        // Craft malicious data
        bytes memory data = abi.encodePacked(address(stakingRewards), address(fakeToken), account);

        hook.setExecutionContext(address(this));
        // Execute reward claim
        Execution[] memory executions = hook.build(address(0), address(0), data);
        vm.prank(account);
        (bool success,) = executions[1].target.call(executions[1].callData);
        require(success, "Reward claim failed");

        // Check inflated outAmount
        uint256 outAmount = hook.outAmount();
        //assertEq(outAmount, 100 ether, "Inflated outAmount");
        // ^ fixed
        assertEq(outAmount, 0, "amount is not inflated");

        // Simulate ledger update
        ledger.updateBalance(account, outAmount);
        // assertEq(ledger.balances(account), 100 ether, "Ledger allows overdraw");
        // ^ fixed
    }
}
