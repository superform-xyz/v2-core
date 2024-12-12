// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "test/BaseTest.t.sol";
import { ERC20Mock } from "test/mocks/ERC20Mock.sol";
import { Mock4626Vault } from "test/mocks/Mock4626Vault.sol";
import { Deposit4626ActionOracle } from "src/accounting/oracles/Deposit4626ActionOracle.sol";

contract Deposit4626ActionOracleTest is BaseTest {
  Deposit4626ActionOracle oracle;
  Mock4626Vault vault;

  function setUp() public override {
    super.setUp();

    oracle = new Deposit4626ActionOracle();
    underlying = new ERC20Mock("Underlying", "UND", 18);
    vault = new Mock4626Vault(IERC20(address(underlying)), "Vault", "VAULT");
  }

  function test_getStrategyOraclePricePerShare() public {
    uint256 pricePerShare = oracle.getStrategyOraclePricePerShare(address(vault));
    assertEq(pricePerShare, 1e18);
  }
}
