// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { MerkleReader } from "../../utils/merkle/helper/MerkleReader.sol";

contract SuperVaultTest is MerkleReader {
    // Core contracts
    SuperVaultFactory public factory;
    SuperVault public vault;
    SuperVaultStrategy public strategy;
    SuperVaultEscrow public escrow;

    // Roles
    address public SV_MANAGER;
    address public STRATEGIST;
    address public EMERGENCY_ADMIN;
    address public FEE_RECIPIENT;

    // Tokens and yield sources
    IERC20Metadata public asset;
    IERC4626 public morphoVault;
    IERC4626 public aaveVault;

    // Constants
    uint256 constant VAULT_CAP = 1_000_000e6; // 1M USDC
    uint256 constant SUPER_VAULT_CAP = 5_000_000e6; // 5M USDC
    uint256 constant MAX_ALLOCATION_RATE = 5000; // 50%
    uint256 constant VAULT_THRESHOLD = 100_000e6; // 100k USDC

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        // Deploy factory
        factory = new SuperVaultFactory();

        // Set up roles
        SV_MANAGER = _deployAccount(MANAGER_KEY, "SV_MANAGER");
        STRATEGIST = _deployAccount(STRATEGIST_KEY, "STRATEGIST");
        EMERGENCY_ADMIN = _deployAccount(EMERGENCY_ADMIN_KEY, "EMERGENCY_ADMIN");
        FEE_RECIPIENT = _deployAccount(FEE_RECIPIENT_KEY, "FEE_RECIPIENT");

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][USDC_KEY]);

        // Get real yield sources from fork
        morphoVault = IERC4626(0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458);
        aaveVault = IERC4626(0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6);

        // Deploy vault trio with initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: VAULT_CAP,
            superVaultCap: SUPER_VAULT_CAP,
            maxAllocationRate: MAX_ALLOCATION_RATE,
            vaultThreshold: VAULT_THRESHOLD
        });

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            address(asset), "SuperVault USDC", "svUSDC", SV_MANAGER, STRATEGIST, EMERGENCY_ADMIN, config, FEE_RECIPIENT
        );

        // Cast addresses to contract types
        vault = SuperVault(vaultAddr);
        strategy = SuperVaultStrategy(strategyAddr);
        escrow = SuperVaultEscrow(escrowAddr);

        // Add yield sources as manager
        vm.startPrank(SV_MANAGER);
        strategy.addYieldSource(address(morphoVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY));
        strategy.addYieldSource(address(aaveVault), _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY));
        vm.stopPrank();

        // Set up hook root
        bytes32 hookRoot = _getMerkleRoot();
        vm.startPrank(SV_MANAGER);
        strategy.proposeHookRoot(hookRoot);
        vm.warp(block.timestamp + 7 days);
        strategy.executeHookRootUpdate();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RequestDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Fund user1 with USDC
        deal(address(asset), user1, depositAmount);

        // Approve vault to spend USDC
        vm.startPrank(user1);
        asset.approve(address(vault), depositAmount);

        // Request deposit
        vault.requestDeposit(depositAmount, user1, user1);
        vm.stopPrank();

        // Verify state
        assertEq(strategy.pendingDepositRequest(user1), depositAmount, "Wrong pending deposit amount");
        assertEq(asset.balanceOf(address(strategy)), depositAmount, "Wrong strategy balance");
        assertEq(asset.balanceOf(user1), 0, "Wrong user balance");
    }

    function test_FulfillDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Setup deposit request
        deal(address(asset), user1, depositAmount);
        vm.startPrank(user1);
        asset.approve(address(vault), depositAmount);
        vault.requestDeposit(depositAmount, user1, user1);
        vm.stopPrank();

        // TODO: Set up hook data for deposit to Morpho
        address[] memory users = new address[](1);
        users[0] = user1;
        address[] memory hooks = new address[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        bytes[] memory hookData = new bytes[](1);

        // Fulfill deposit as strategist
        vm.startPrank(STRATEGIST);
        strategy.fulfillDepositRequests(users, hooks, proofs, hookData);
        vm.stopPrank();

        // Verify state
        assertEq(strategy.pendingDepositRequest(user1), 0, "Pending request not cleared");
        assertGt(strategy.maxMint(user1), 0, "No shares available to mint");
    }

    function test_ClaimDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC

        // Setup and fulfill deposit
        deal(address(asset), user1, depositAmount);
        vm.startPrank(user1);
        asset.approve(address(vault), depositAmount);
        vault.requestDeposit(depositAmount, user1, user1);
        vm.stopPrank();

        // TODO: Set up hook data for deposit to Morpho
        address[] memory users = new address[](1);
        users[0] = user1;
        address[] memory hooks = new address[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        bytes[] memory hookData = new bytes[](1);

        vm.startPrank(STRATEGIST);
        strategy.fulfillDepositRequests(users, hooks, proofs, hookData);
        vm.stopPrank();

        // Get claimable shares
        uint256 claimableShares = strategy.maxMint(user1);

        // Claim deposit
        vm.startPrank(user1);
        vault.deposit(depositAmount, user1, user1);
        vm.stopPrank();

        // Verify state
        assertEq(vault.balanceOf(user1), claimableShares, "Wrong share balance");
        assertEq(strategy.maxMint(user1), 0, "Shares not claimed");
    }

    /*//////////////////////////////////////////////////////////////
                        REDEEM FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RequestRedeem() public {
        // First setup a deposit and claim it
        uint256 depositAmount = 1000e6; // 1000 USDC
        deal(address(asset), user2, depositAmount);

        vm.startPrank(user2);
        asset.approve(address(vault), depositAmount);
        vault.requestDeposit(depositAmount, user2, user2);
        vm.stopPrank();

        // TODO: Set up hook data for deposit
        address[] memory users = new address[](1);
        users[0] = user2;
        address[] memory hooks = new address[](1);
        bytes32[][] memory proofs = new bytes32[][](1);
        bytes[] memory hookData = new bytes[](1);

        vm.startPrank(STRATEGIST);
        strategy.fulfillDepositRequests(users, hooks, proofs, hookData);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.deposit(depositAmount, user2, user2);

        // Now request redeem of half the shares
        uint256 redeemShares = vault.balanceOf(user2) / 2;
        vault.requestRedeem(redeemShares, user2, user2);
        vm.stopPrank();

        // Verify state
        assertEq(strategy.pendingRedeemRequest(user2), redeemShares, "Wrong pending redeem amount");
        assertEq(vault.balanceOf(address(escrow)), redeemShares, "Wrong escrow balance");
    }

    // TODO: Add remaining tests following test-plan.md
}
