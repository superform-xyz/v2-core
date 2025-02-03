// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Helpers } from "../../../utils/Helpers.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockStakingProtocol } from "../../../mocks/MockStakingProtocol.sol";
import { FluidYieldSourceOracle } from
    "../../../../src/core/accounting/oracles/FluidYieldSourceOracle.sol";

contract FluidYieldSourceOracleTest is Helpers {
    FluidYieldSourceOracle public oracle;
    MockERC20 public underlying;
    MockStakingProtocol public stakingProtocol;

    function setUp() public {
        oracle = new FluidYieldSourceOracle();
        underlying = new MockERC20("Underlying", "UND", 18);
        stakingProtocol = new MockStakingProtocol(address(underlying));
    }

    function test_getPricePerShare() public view {
        uint256 price = oracle.getPricePerShare(address(stakingProtocol));
        assertEq(price, 1e18);
    }

    function test_getPricePerShareMultiple() public view {
        address[] memory finalTargets = new address[](1);
        finalTargets[0] = address(stakingProtocol);
        uint256[] memory prices = oracle.getPricePerShareMultiple(finalTargets, address(underlying));
        assertEq(prices[0], 1e18);
    }
}
