// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { FluidYieldSourceOracle } from "../../../../src/core/accounting/oracles/FluidYieldSourceOracle.sol";
import { IFluidLendingStakingRewards } from
    "../../../../src/core/interfaces/vendors/fluid/IFluidLendingStakingRewards.sol";

import { BaseE2ETest } from "../../../BaseE2ETest.t.sol";

contract FluidYieldSourceOracleIntegration is BaseE2ETest {
    FluidYieldSourceOracle public oracle;
    IFluidLendingStakingRewards public yieldSource;
    address public underlying;

    function setUp() public virtual override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        oracle = new FluidYieldSourceOracle(_getContract(ETH, SUPER_ORACLE_KEY));
        yieldSource = IFluidLendingStakingRewards(CHAIN_1_FluidVault);
        underlying = yieldSource.stakingToken();
    }

    function test_FluidIntegration_getPricePerShare() public view {
        uint256 price = oracle.getPricePerShare(address(yieldSource));
        assertGt(price, 0);
    }

    function test_FluidIntegration_getPricePerShareMultiple() public view {
        address[] memory finalTargets = new address[](1);
        finalTargets[0] = address(yieldSource);
        address[] memory assets = new address[](1);
        assets[0] = address(0);
        uint256[] memory prices = oracle.getPricePerShareMultiple(finalTargets);
        assertGt(prices[0], 0);
    }
}
