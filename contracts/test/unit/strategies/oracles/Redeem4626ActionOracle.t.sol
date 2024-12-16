// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "test/BaseTest.t.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { Mock4626Vault } from "test/mocks/Mock4626Vault.sol";
import { Redeem4626ActionOracle } from "src/strategies/oracles/Redeem4626ActionOracle.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Redeem4626ActionOracleTest is BaseTest {
  Redeem4626ActionOracle oracle;
  MockERC20 underlying;
  Mock4626Vault vault;

  function setUp() public override {
    super.setUp();

    oracle = new Redeem4626ActionOracle();
    underlying = new MockERC20("Underlying", "UND", 18);
    vault = new Mock4626Vault(IERC20(address(underlying)), "Vault", "VAULT");
  }

  function test_getRedeem4626StrategyPrice() public view {
    uint256 pricePerShare = oracle.getStrategyPrice(address(vault));
    assertEq(pricePerShare, 1e18);
  }

  function test_getRedeem4626StrategyPrices() public {
    address[] memory finalTargets = new address[](1);
    finalTargets[0] = address(vault);
    uint256[] memory prices = oracle.getStrategyPrices(finalTargets);
    assertEq(prices[0], 1e18);
  }
}
