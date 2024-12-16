// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../BaseTest.t.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock5115Vault } from "../../mocks/Mock5115Vault.sol";
import { Deposit5115Library } from "../../../src/libraries/strategies/Deposit5115Library.sol";

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
