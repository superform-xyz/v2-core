// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseE2ETest } from "../../../BaseE2ETest.t.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { Mock5115Vault } from "../../../mocks/Mock5115Vault.sol";
import { ERC5115YieldSourceOracle } from "../../../../src/core/accounting/oracles/ERC5115YieldSourceOracle.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract ERC5115YieldSourceOracleTest is BaseE2ETest {
    ERC5115YieldSourceOracle oracle;
    MockERC20 underlying;
    Mock5115Vault vault;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);
        oracle = new ERC5115YieldSourceOracle(_getContract(ETH, SUPER_ORACLE_KEY));
        underlying = new MockERC20("Underlying", "UND", 18);
        vault = new Mock5115Vault(IERC20(address(underlying)), "Vault", "VAULT");
    }

    function test_getPricePerShare() public view {
        uint256 pricePerShare = oracle.getPricePerShare(address(vault));
        assertEq(pricePerShare, 1e18);
    }

    function test_getPricePerShareMultiple() public view {
        address[] memory yieldSourceAddresses = new address[](1);
        yieldSourceAddresses[0] = address(vault);
        address[] memory assets = new address[](1);
        assets[0] = address(underlying);
        uint256[] memory prices = oracle.getPricePerShareMultiple(yieldSourceAddresses);
        assertEq(prices[0], 1e18);
    }
}
