// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseE2ETest } from "../../../BaseE2ETest.t.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../../mocks/Mock4626Vault.sol";
import { ERC4626YieldSourceOracle } from "../../../../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract ERC4626YieldSourceOracleTest is BaseE2ETest {
    ERC4626YieldSourceOracle public oracle;
    MockERC20 public underlying;
    Mock4626Vault public vault;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        oracle = new ERC4626YieldSourceOracle(_getContract(ETH, SUPER_ORACLE_KEY));
        underlying = new MockERC20("Underlying", "UND", 18);
        vault = new Mock4626Vault(IERC20(address(underlying)), "Vault", "VAULT");
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
