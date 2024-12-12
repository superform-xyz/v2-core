// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "test/BaseTest.t.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { Mock4626Vault } from "test/mocks/Mock4626Vault.sol";
import { Deposit4626Library } from "src/libraries/strategies/Deposit4626Library.sol";

contract Deposit4626LibraryTest is BaseTest {
  Mock4626Vault vault;
  MockERC20 underlying;

  function setUp() public override {
    super.setUp();

    underlying = new MockERC20("Underlying", "UND", 18);

    vault = new Mock4626Vault(address(underlying));
  }

  function test_getEstimated4626Rewards() public {
    uint256 amountToDeposit = 1000;
    uint256 expectedRewards = 1000;
    uint256 actualRewards = Deposit4626Library.getEstimatedRewards(address(vault), amountToDeposit);
    assertEq(actualRewards, expectedRewards);
  }

  function test_getEstimated4626Rewards_fuzz(uint256 amountToDeposit) public {
    amountToDeposit = _bound(amountToDeposit);
    uint256 expectedRewards = amountToDeposit;
    uint256 actualRewards = Deposit4626Library.getEstimatedRewards(address(vault), amountToDeposit);
    assertEq(actualRewards, expectedRewards);
  }
}
