// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Helpers } from "../../../utils/Helpers.sol";
import { MockStakingProtocol } from "../../../mocks/MockStakingProtocol.sol";
import { SomelierStakingYieldSourceOracle } from "../../../../src/accounting/oracles/SomelierStakingYieldSourceOracle.sol";

contract SomelierStakingYieldSourceOracleTest is Helpers {
    SomelierStakingYieldSourceOracle public oracle;
    MockStakingProtocol public stakingProtocol;

    function setUp() public {
        oracle = new SomelierStakingYieldSourceOracle();
        stakingProtocol = new MockStakingProtocol();
    }

    function test_getPricePerShare() public view {
        uint256 price = oracle.getPricePerShare(address(stakingProtocol));
        assertEq(price, 1e18);
    }
}
