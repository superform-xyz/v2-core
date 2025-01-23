// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import "forge-std/Test.sol";

import { ISuperCollectiveVault } from "../../../src/interfaces/vault/ISuperCollectiveVault.sol";
import { SuperCollectiveVault } from "../../../src/superPositions/SuperCollectiveVault.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

import { BaseTest } from "../../BaseTest.t.sol";

contract SuperCollectiveVaultTest is BaseTest {
    SuperCollectiveVault public vault;
    MockERC20 public token;

    address executor = address(0x123);
    address manager = address(0x456);
    address user = address(0x789);

    function setUp() public override {
        super.setUp();
        
        vm.selectFork(FORKS[ETH]);

        // Deploy mock token and vault
        token = new MockERC20("Mock Token", "MKT", 18);
        vault = SuperCollectiveVault(_getContract(ETH, "SuperCollectiveVault"));
    }

    function testVault_LockTokens(uint256 amount) public {
        amount = bound(amount, SMALL, LARGE);
        _getTokens(address(token), address(user), amount);

        _resetCaller(user);
        token.approve(address(vault), amount);
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vault.lock(user, address(token), amount);

        assertEq(vault.viewLockedAmount(user, address(token)), amount);

        vm.stopPrank();
    }

    function testVault_UnlockTokens(uint256 amount) public {
        amount = bound(amount, SMALL, LARGE);
        _getTokens(address(token), address(user), amount);

        _resetCaller(user);
        token.approve(address(vault), amount);
        _resetCaller(_getContract(ETH, "SuperExecutor"));
        vault.lock(user, address(token), amount);
        assertEq(vault.viewLockedAmount(user, address(token)), amount);

        _resetCaller(address(this));
        vault.unlock(user, address(token), amount);

        assertEq(vault.viewLockedAmount(user, address(token)), 0);
    }

    function testVault_UpdateMerkleRoot() public {
        bytes32 newMerkleRoot = keccak256(abi.encodePacked("new_root"));

        assertEq(vault.isMerkleRootRegistered(newMerkleRoot), false);

        _resetCaller(address(user));
        vm.expectRevert(ISuperCollectiveVault.NOT_AUTHORIZED.selector);
        vault.updateMerkleRoot(newMerkleRoot, true);

        _resetCaller(address(this));
        vault.updateMerkleRoot(newMerkleRoot, true);

        assertEq(vault.isMerkleRootRegistered(newMerkleRoot), true);
    }
}