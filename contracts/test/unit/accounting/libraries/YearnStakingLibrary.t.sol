// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Helpers } from "../../../utils/Helpers.sol";
import { YearnStakingYieldSourceOracleLibrary } from 
"../../../../src/libraries/accounting/YearnStakingYieldSourceOracleLibrary.sol";
import { MockStakingProtocol } from "../../../mocks/MockStakingProtocol.sol";

contract YearnStakingLibraryTest is Helpers {
    MockStakingProtocol public stakingProtocol;

    function setUp() public {
        stakingProtocol = new MockStakingProtocol();
    }

    function test_getYearnPricePerShare() public view {
        uint256 expectedPricePerShare = 1e18;
        uint256 pricePerShare = YearnStakingYieldSourceOracleLibrary.getPricePerShare(address(stakingProtocol));
        assertEq(pricePerShare, expectedPricePerShare);
    }
}
