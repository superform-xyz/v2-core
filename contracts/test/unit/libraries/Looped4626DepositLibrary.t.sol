// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../BaseTest.t.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { Looped4626DepositLibrary } from "../../../src/libraries/strategies/Looped4626DepositLibrary.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Looped4626DepositLibraryTest is BaseTest {
  Mock4626Vault vault;
  Mock4626Vault vault2;

  MockERC20 asset;
  MockERC20 asset2;

  Looped4626DepositLibraryWrapper wrapper;

  function setUp() public override {
    super.setUp();
    asset = new MockERC20("Asset", "ASSET", 18);
    asset2 = new MockERC20("Asset2", "ASSET2", 18);
    vault = new Mock4626Vault(address(asset));
    vault2 = new Mock4626Vault(address(asset));
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
}