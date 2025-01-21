// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Helpers } from "../../../utils/Helpers.sol";
import { MockStakingProtocol } from "../../../mocks/MockStakingProtocol.sol";
import { SomelierCellarStakingYieldSourceOracleLibrary } from
    "../../../../src/libraries/accounting/SomelierCellarStakingYieldSourceOracleLibrary.sol";

contract SomelierStakingLibraryTest is Helpers {
    MockStakingProtocol public stakingProtocol;

    function setUp() public {
        stakingProtocol = new MockStakingProtocol();
    }

    function test_getSomelierPricePerShare() public view {
        uint256 pricePerShare = SomelierCellarStakingYieldSourceOracleLibrary.getPricePerShare(address(stakingProtocol));
        assertEq(pricePerShare, 1e18);
    }
}
