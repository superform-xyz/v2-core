// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Helpers} from "../../utils/Helpers.sol";

import {MockSuperPositionFactory, MockSuperPosition} from "../../mocks/MockSuperPositionFactory.sol";
import {MockERC20} from "../../mocks/MockERC20.sol";

contract SuperPositionsFactoryTest is Helpers {
    MockSuperPositionFactory public factory;

    function setUp() public {
        factory = new MockSuperPositionFactory(address(this));
    }

    // forge test --match-test testFuzz_SuperPositionFactory_UniqueSPId --fuzz-runs 10000
    // [PASS] testFuzz_SuperPositionFactory_UniqueSPId(address,bytes32,uint64,address,bytes32,uint64) (runs: 1000001, μ:
    // 10893, ~: 10893)
    // @dev test with 1M runs
    function testFuzz_SuperPositionFactory_UniqueSPId(
        address yieldSourceAddress1,
        bytes4 yieldSourceOracleId1,
        uint64 chainId1,
        address yieldSourceAddress2,
        bytes4 yieldSourceOracleId2,
        uint64 chainId2
    ) public view {
        vm.assume(
            yieldSourceAddress1 != yieldSourceAddress2 || yieldSourceOracleId1 != yieldSourceOracleId2
                || chainId1 != chainId2
        );

        uint256 spId1 = factory.getSPId(yieldSourceAddress1, yieldSourceOracleId1, chainId1);
        uint256 spId2 = factory.getSPId(yieldSourceAddress2, yieldSourceOracleId2, chainId2);

        assertFalse(spId1 == spId2);
    }

    // forge test --match-test testFuzz_SuperPositionFactory_SameSPId --fuzz-runs 10000
    // [PASS] testFuzz_SuperPositionFactory_SameSPId(address,bytes32,uint64) (runs: 1000001, μ: 10302, ~: 10302)
    // @dev test with 1M runs
    function testFuzz_SuperPositionFactory_SameSPId(
        address yieldSourceAddress,
        bytes4 yieldSourceOracleId,
        uint64 chainId
    ) public view {
        uint256 spId1 = factory.getSPId(yieldSourceAddress, yieldSourceOracleId, chainId);
        uint256 spId2 = factory.getSPId(yieldSourceAddress, yieldSourceOracleId, chainId);

        assertEq(spId1, spId2);
    }
}
