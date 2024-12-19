// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../../BaseTest.t.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Mock5115Vault } from "../../../mocks/Mock5115Vault.sol";
import { DepositRedeem5115ActionOracle } from "../../../../src/strategies/oracles/DepositRedeem5115ActionOracle.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract DepositRedeem5115ActionOracleTest is BaseTest {
    DepositRedeem5115ActionOracle oracle;
    MockERC20 underlying;
    Mock5115Vault vault;

    function setUp() public override {
        super.setUp();
        oracle = new DepositRedeem5115ActionOracle();
        underlying = new MockERC20("Underlying", "UND", 18);
        vault = new Mock5115Vault(IERC20(address(underlying)), "Vault", "VAULT");
    }

    function test_get5115StrategyPrice() public view {
        uint256 pricePerShare = oracle.getStrategyPrice(address(vault), address(underlying));
        assertEq(pricePerShare, 1e18);
    }

    function test_get5115StrategyPrices() public view {
        address[] memory finalTargets = new address[](1);
        finalTargets[0] = address(vault);

        address[] memory assets = new address[](1);
        assets[0] = address(underlying);

        uint256[] memory prices = oracle.getStrategyPrices(assets, finalTargets);
        assertEq(prices[0], 1e18);
    }
}
