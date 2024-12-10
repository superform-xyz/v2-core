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
  ERC20Mock asset2;

  Looped4626DepositLibraryWrapper wrapper;

  function setUp() public override {
    super.setUp();
    asset = new ERC20Mock("Asset", "ASSET", 18);
    asset2 = new ERC20Mock("Asset2", "ASSET2", 18);
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
    wrapper = new Looped4626DepositLibraryWrapper();
  }

  function test_getEstimatedRewardsSingleVault() public view {
    uint256 loops = 10;
    uint256 amountPerLoop = 100;
    uint256 rewards = Looped4626DepositLibrary.getEstimatedRewards(
      address(vault),
      loops,
      amountPerLoop
    );
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

  function test_getEstimatedRewardsMultiVault_differentAssets() public {
    address[] memory vaults = new address[](2);
    vaults[0] = address(vault);
    VaultMock vault3 = new VaultMock(
      IERC20(address(asset2)),
      "Vault3",
      "VAULT3"
    );
    vaults[1] = address(vault3);
    vm.expectRevert(Looped4626DepositLibrary.VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET.selector);
    wrapper.getEstimatedRewardsMultiVault(
      vaults,
      address(asset2),
      100,
      10
    );
  }
}

contract Looped4626DepositLibraryWrapper {
  function getEstimatedRewards(address vault, uint256 loops, uint256 amountPerLoop) external view returns (uint256) {
    return Looped4626DepositLibrary.getEstimatedRewards(vault, loops, amountPerLoop);
  }

  function getEstimatedRewardsMultiVault(address[] memory vaults, address underlyingAsset, uint256 loops, uint256 amountPerLoop) external view returns (uint256[] memory) {
    return Looped4626DepositLibrary.getEstimatedRewardsMultiVault(vaults, underlyingAsset, loops, amountPerLoop);
  }
}

