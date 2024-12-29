// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseTest } from "../../BaseTest.t.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Mock4626Vault } from "../../mocks/Mock4626Vault.sol";
import { Looped4626DepositLibrary } from "../../../src/libraries/strategies/Looped4626DepositLibrary.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Looped4626DepositLibraryTest is BaseTest {
    Mock4626Vault vault;
    Mock4626Vault vault2;
    MockERC20 asset;
    MockERC20 asset2;
    Looped4626DepositLibraryWrapper wrapper;

    function setUp() public override {
        super.setUp();
        asset = new MockERC20("Asset", "ASSET", 18);
        asset2 = new MockERC20("Asset2", "ASSET2", 18);
        vault = new Mock4626Vault(IERC20(address(asset)), "Vault", "V");
        vault2 = new Mock4626Vault(IERC20(address(asset)), "Vault2", "V2");
        wrapper = new Looped4626DepositLibraryWrapper();
    }

    function test_getLooped4626PricePerShareSingleVault() public view {
        uint256 loops = 10;
        uint256 rewards = Looped4626DepositLibrary.getPricePerShare(address(vault), loops);
        assertEq(rewards, 10e18);
    }

    function test_getLooped4626PricePerShares() public view {
        address[] memory vaults = new address[](2);
        vaults[0] = address(vault);
        vaults[1] = address(vault2);
        uint256[] memory rewards = wrapper.getPricePerShares(vaults, address(asset), 10);
        assertEq(rewards[0], 10e18);
        assertEq(rewards[1], 10e18);
    }

    function test_getPricePerShareMultiVault_differentUnderlyingAsset() public {
        address[] memory vaults = new address[](2);
        vaults[0] = address(vault);
        Mock4626Vault vault3 = new Mock4626Vault(IERC20(address(asset2)), "Vault3", "V3");
        vaults[1] = address(vault3);
        vm.expectRevert(Looped4626DepositLibrary.VAULTS_MUST_HAVE_SAME_UNDERLYING_ASSET.selector);
        wrapper.getPricePerShares(vaults, address(asset2), 10);
    }
}

contract Looped4626DepositLibraryWrapper {
    function getPricePerShare(address vault, uint256 loops) external view returns (uint256) {
        return Looped4626DepositLibrary.getPricePerShare(vault, loops);
    }

    function getPricePerShares(
        address[] memory vaults,
        address underlyingAsset,
        uint256 loops
    )
        external
        view
        returns (uint256[] memory)
    {
        return Looped4626DepositLibrary.getPricePerShares(vaults, underlyingAsset, loops);
    }
}
