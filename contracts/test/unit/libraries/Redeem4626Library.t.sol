// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../BaseTest.t.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { Deposit4626Library } from "../../../src/libraries/strategies/Deposit4626Library.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Deposit4626LibraryTest is BaseTest {
  Mock4626Vault vault;
  MockERC20 underlying;

  function setUp() public override {
    super.setUp();

    underlying = new MockERC20("Underlying", "UND", 18);

    vault = new Mock4626Vault(
      IERC20(address(underlying)),
      "Vault",
      "VAULT"
    );
  }

  function test_getPricePerShare() public {
    uint256 expectedPricePerShare = 1e18;
    uint256 actualPricePerShare = Deposit4626Library.getPricePerShare(address(vault));
    assertEq(actualPricePerShare, expectedPricePerShare);
  }

  function test_getPricePerShareMultiVault() public {
    address[] memory finalTargets = new address[](1);
    finalTargets[0] = address(vault);

    uint256[] memory expectedPricePerShares = new uint256[](1);
    expectedPricePerShares[0] = 1e18;
    
    uint256[] memory actualPricePerShares = Deposit4626Library.getPricePerShareMultiVault(finalTargets, address(underlying));
    assertEq(actualPricePerShares[0], expectedPricePerShares[0]);
  }
}
