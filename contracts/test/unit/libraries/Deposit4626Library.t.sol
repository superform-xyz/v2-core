// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../BaseTest.t.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { VaultMock } from "../../mocks/VaultMock.sol";
import { Deposit4626Library } from "../../../src/libraries/strategies/Deposit4626Library.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Deposit4626LibraryTest is BaseTest {
  VaultMock vault;
  ERC20Mock underlying;

  function setUp() public override {
    super.setUp();

    underlying = new ERC20Mock("Underlying", "UND", 18);

    vault = new VaultMock(
      IERC20(address(underlying)),
      "Vault",
      "VAULT"
    );
  }

  function test_getEstimatedRewards() public {
    uint256 amountToDeposit = 1000;
    uint256 expectedRewards = 1000;
    uint256 actualRewards = Deposit4626Library.getEstimatedRewards(address(vault), amountToDeposit);
    assertEq(actualRewards, expectedRewards);
  }
}
