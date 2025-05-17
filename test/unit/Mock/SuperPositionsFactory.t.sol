// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Helpers } from "../../utils/Helpers.sol";

import { MockSuperPositionFactory, MockSuperPosition } from "../../mocks/MockSuperPositionFactory.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

contract SuperPositionsFactoryTest is Helpers {
    MockSuperPositionFactory public factory;

    function setUp() public {
        factory = new MockSuperPositionFactory(address(this));
    }

    function test_WhenIsValid() external pure {
        // it should not revert
        assertTrue(true);
    }

    function test_WhenMintSuperPosition_18decimals() external {
        MockERC20 asset18Decimals = new MockERC20("Mock Asset", "MA", 18);

        address asset = address(asset18Decimals);
        address yieldSourceAddress = address(this);
        bytes4 yieldSourceOracleId = bytes4(0x12345678);
        uint64 chainId = 1;
        address receiver = address(factory);
        uint256 amount = SMALL;

        MockSuperPosition sp = MockSuperPosition(
            factory.mintSuperPosition(chainId, yieldSourceAddress, yieldSourceOracleId, asset, receiver, amount)
        );
        assertEq(sp.balanceOf(receiver), amount);
        assertEq(sp.totalSupply(), amount);
        assertEq(sp.decimals(), asset18Decimals.decimals());

        assertEq(factory.spCount(), 1);
        assertEq(factory.isSP(address(sp)), true);
        uint256 computedSpId = factory.getSPId(yieldSourceAddress, yieldSourceOracleId, chainId);
        assertEq(computedSpId, sp.id());
    }

    function test_WhenMintSuperPosition_6decimals() external {
        MockERC20 asset6Decimals = new MockERC20("Mock Asset", "MA", 6);

        address asset = address(asset6Decimals);
        address yieldSourceAddress = address(this);
        bytes4 yieldSourceOracleId = bytes4(0x12345678);
        uint64 chainId = 1;
        address receiver = address(factory);
        uint256 amount = 1e6;

        MockSuperPosition sp = MockSuperPosition(
            factory.mintSuperPosition(chainId, yieldSourceAddress, yieldSourceOracleId, asset, receiver, amount)
        );
        assertEq(sp.balanceOf(receiver), amount);
        assertEq(sp.totalSupply(), amount);
        assertEq(sp.decimals(), asset6Decimals.decimals());

        assertEq(factory.spCount(), 1);
        assertEq(factory.isSP(address(sp)), true);
        uint256 computedSpId = factory.getSPId(yieldSourceAddress, yieldSourceOracleId, chainId);
        assertEq(computedSpId, sp.id());
    }
}
