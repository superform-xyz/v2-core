// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseE2ETest } from "../../../BaseE2ETest.t.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Mock7540Vault } from "../../../mocks/Mock7540Vault.sol";
import { ERC7540YieldSourceOracle } from "../../../../src/core/accounting/oracles/ERC7540YieldSourceOracle.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract ERC7540YieldSourceOracleTest is BaseE2ETest {
    ERC7540YieldSourceOracle public oracle;
    MockERC20 public underlying;
    Mock7540Vault public vault;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        oracle = new ERC7540YieldSourceOracle(_getContract(ETH, SUPER_ORACLE_KEY));
        underlying = new MockERC20("Underlying", "UND", 18);
        vault = new Mock7540Vault(IERC20(address(underlying)), "Vault", "VAULT");
    }

    function test_getPricePerShare() public view {
        uint256 pricePerShare = oracle.getPricePerShare(address(vault));
        assertEq(pricePerShare, 1e18);
    }

    function test_getPricePerShareMultiple() public view {
        address[] memory finalTargets = new address[](1);
        finalTargets[0] = address(vault);
        address[] memory assets = new address[](1);
        assets[0] = address(0);
        uint256[] memory prices = oracle.getPricePerShareMultiple(finalTargets);
        assertEq(prices[0], 1e18);
    }
}
