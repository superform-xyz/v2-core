// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { StakingYieldSourceOracle } from "../../../src/core/accounting/oracles/StakingYieldSourceOracle.sol";
import { IStakingVault } from "../../../src/vendor/staking/IStakingVault.sol";

import { Helpers } from "../../utils/Helpers.sol";

contract StakingYieldSourceOracleIntegration is Helpers {
    StakingYieldSourceOracle public oracle;
    IStakingVault public yieldSource;
    address public underlying;

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK);

        oracle = new StakingYieldSourceOracle();
        yieldSource = IStakingVault(CHAIN_1_FluidVault);
        underlying = yieldSource.stakingToken();
    }

    function test_StakingIntegration_getPricePerShare() public view {
        uint256 price = oracle.getPricePerShare(address(yieldSource));
        assertGt(price, 0);
    }

    function test_StakingIntegration_getPricePerShareMultiple() public view {
        address[] memory finalTargets = new address[](1);
        finalTargets[0] = address(yieldSource);
        address[] memory assets = new address[](1);
        assets[0] = address(0);
        uint256[] memory prices = oracle.getPricePerShareMultiple(finalTargets);
        assertGt(prices[0], 0);
    }
}
