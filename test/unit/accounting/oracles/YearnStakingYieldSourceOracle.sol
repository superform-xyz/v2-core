// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Helpers } from "../../../utils/Helpers.sol";
import { MockStakingProtocol } from "../../../mocks/MockStakingProtocol.sol";
import { YearnStakingYieldSourceOracle } from
    "../../../../src/core/accounting/oracles/YearnStakingYieldSourceOracle.sol";

contract YearnStakingYieldSourceOracleTest is Helpers {
    YearnStakingYieldSourceOracle public oracle;
    MockStakingProtocol public stakingProtocol;

    function setUp() public {
        oracle = new YearnStakingYieldSourceOracle();
        stakingProtocol = new MockStakingProtocol();
    }

    function test_getPricePerShare() public view {
        uint256 price = oracle.getPricePerShare(address(stakingProtocol));
        assertEq(price, 1e18);
    }
}
