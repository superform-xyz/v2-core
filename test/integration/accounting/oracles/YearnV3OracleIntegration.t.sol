// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import { ERC4626YieldSourceOracle } from "../../../../src/core/accounting/oracles/ERC4626YieldSourceOracle.sol";

import { BaseE2ETest } from "../../../BaseE2ETest.t.sol";

contract YearnYieldSourceOracleIntegration is BaseE2ETest {
    ERC4626YieldSourceOracle public oracle;
    IERC4626 public yieldSource;
    address public underlying;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        oracle = new ERC4626YieldSourceOracle();
        yieldSource = IERC4626(CHAIN_1_YearnVault);
        underlying = yieldSource.asset();
    }

    function test_YearnIntegration_getPricePerShare() public view {
        uint256 price = oracle.getPricePerShare(address(yieldSource));
        assertGt(price, 0);
    }

    function test_YearnIntegration_getPricePerShareMultiple() public view {
        address[] memory finalTargets = new address[](1);
        finalTargets[0] = address(yieldSource);
        address[] memory assets = new address[](1);
        assets[0] = address(0);
        uint256[] memory prices = oracle.getPricePerShareMultiple(finalTargets);
        assertGt(prices[0], 0);
    }
}
