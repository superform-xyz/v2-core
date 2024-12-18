// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../../BaseTest.t.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../../mocks/Mock4626Vault.sol";
import { Looped4626DepositActionOracle } from "../../../../../src/strategies/oracles/Looped4626DepositActionOracle.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Looped4626DepositActionOracleTest is BaseTest {
  Looped4626DepositActionOracle oracle;

  Mock4626Vault vault;
  Mock4626Vault vault2;

  MockERC20 asset;
  MockERC20 asset2;

  function setUp() public override {
    super.setUp();
    asset = new MockERC20("Asset", "ASSET", 18);
    asset2 = new MockERC20("Asset2", "ASSET2", 18);
    vault = new Mock4626Vault(
      IERC20(address(asset)),
      "Vault",
      "VAULT"
    );
    vault2 = new Mock4626Vault(
      IERC20(address(asset2)),
      "Vault2",
      "VAULT2"
    );
    oracle = new Looped4626DepositActionOracle();
  }

  function test_getStrategyPrice() public view {
    uint256 price = oracle.getStrategyPrice(address(vault), 10);
    assertEq(price, 10e18);
  }

  function test_getStrategyPrices() public view {
    address[] memory vaults = new address[](2);
    vaults[0] = address(vault);
    vaults[1] = address(vault2);

    uint256[] memory loops = new uint256[](2);
    loops[0] = 10;
    loops[1] = 10;

    uint256[] memory prices = oracle.getStrategyPrices(vaults, loops);
    assertEq(prices[0], 10e18);
    assertEq(prices[1], 10e18);
  }
}
