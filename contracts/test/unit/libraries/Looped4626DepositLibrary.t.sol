// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../BaseTest.t.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { VaultMock } from "../../mocks/VaultMock.sol";
import { Looped4626DepositLibrary } from "../../../src/libraries/strategies/Looped4626DepositLibrary.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract Looped4626DepositLibraryTest is BaseTest {
  VaultMock vault;
  VaultMock vault2;
  ERC20Mock asset;

  function setUp() public override {
    super.setUp();
    asset = new ERC20Mock("Asset", "ASSET", 18);
    vault = new VaultMock(
      IERC20(address(asset)),
      "Vault",
      "VAULT"
    );
    vault2 = new VaultMock(
      IERC20(address(asset)),
      "Vault2",
      "VAULT2"
    );
  }

  function test_getEstimatedRewardsSingleVault() public view {
    uint256 loops = 10;
    uint256 amountPerLoop = 100;
    uint256 rewards = Looped4626DepositLibrary.getEstimatedRewards(address(vault), loops, amountPerLoop);
    assertEq(rewards, 1000);
  }

  function test_getEstimatedRewardsMultiVault() public view {
    address[] memory vaults = new address[](2);
    vaults[0] = address(vault);
    vaults[1] = address(vault2);
    uint256 loops = 10;
    uint256 amountPerLoop = 100;
    uint256[] memory rewards = Looped4626DepositLibrary.getEstimatedRewardsMultiVault(
      vaults,
      address(asset),
      loops,
      amountPerLoop
    );
    assertEq(rewards.length, 2);
    assertEq(rewards[0], 1000);
    assertEq(rewards[1], 1000);
  }
}
