// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../BaseTest.t.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { Mock5115Vault } from "../../mocks/Mock5115Vault.sol";
import { Deposit5115Library } from "../../../src/libraries/strategies/Deposit5115Library.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Deposit5115LibraryTest is BaseTest {
  ERC20Mock underlying;
  Mock5115Vault vault;

  function setUp() public override {
    super.setUp();
    underlying = new ERC20Mock("Underlying", "UND", 18);
    vault = new Mock5115Vault(
      IERC20(address(underlying)),
      "Vault",
      "VAULT"
    );
  }

  function test_getEstimated5115Rewards() public {
    uint256 expectedRewards = 1;
    uint256 actualRewards = Deposit5115Library.getEstimatedRewards(
      address(vault),
      address(underlying)
    );
    assertEq(actualRewards, expectedRewards);
  }
}
