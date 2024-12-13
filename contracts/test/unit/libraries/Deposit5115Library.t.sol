// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "test/BaseTest.t.sol";
import { Helpers } from "test/utils/Helpers.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { Mock5115Vault } from "test/mocks/Mock5115Vault.sol";
import { IStandardizedYield } from "interfaces/vendors/pendle/IStandardizedYield.sol";
import { Deposit5115Library } from "libraries/strategies/Deposit5115Library.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Deposit5115LibraryTest is BaseTest {
  MockERC20 underlying;
  Mock5115Vault vault;

  function setUp() public override {
    super.setUp();
    underlying = new MockERC20("Underlying", "UND", 18);
    vault = new Mock5115Vault(
      IERC20(address(underlying)),
      "Vault",
      "VAULT"
    );
  }
}
