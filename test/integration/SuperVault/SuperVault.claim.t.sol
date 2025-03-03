// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// testing
import { BaseTest } from "../../BaseTest.t.sol";
import { BaseSuperVaultTest } from "./BaseSuperVaultTest.t.sol";

// external
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IGearboxFarmingPool } from "../../../src/vendor/gearbox/IGearboxFarmingPool.sol";

import {
    RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, AccountType, UserOpData
} from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { MerkleReader } from "../../utils/merkle/helper/MerkleReader.sol";
import { PeripheryRegistry } from "../../../src/periphery/PeripheryRegistry.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { PeripheryRegistry } from "../../../src/periphery/PeripheryRegistry.sol";
import { ISuperLedgerData } from "../../../src/core/interfaces/accounting/ISuperLedger.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperRegistry } from "../../../src/core/settings/SuperRegistry.sol";
import { SuperVaultFactory } from "../../../src/periphery/SuperVaultFactory.sol";
import { SuperVaultStrategy } from "../../../src/periphery/SuperVaultStrategy.sol";
import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";

import { ISuperVaultFactory } from "../../../src/periphery/interfaces/ISuperVaultFactory.sol";

contract SuperVaultClaimTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using Math for uint256;

    // Yield sources
    IGearboxFarmingPool public curveGearboxFarmingPool;

    uint256 public amount;

    uint256 public constant PRECISION = 1e18;

    function setUp() public override {
        super.setUp();

        amount = 1000e6; // 1000 GEAR

        vm.selectFork(FORKS[ETH]);
        accInstances = randomAccountInstances[ETH];
        assertEq(accInstances.length, ACCOUNT_COUNT);
        peripheryRegistry = PeripheryRegistry(_getContract(ETH, PERIPHERY_REGISTRY_KEY));

        // Set up accounts
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];

        accInstances = randomAccountInstances[ETH];

        // Set up super executor
        superExecutorOnEth = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));

        // Deploy factory
        factory = new SuperVaultFactory(_getContract(ETH, PERIPHERY_REGISTRY_KEY));

        // Set up roles
        SV_MANAGER = _deployAccount(MANAGER_KEY, "SV_MANAGER");
        STRATEGIST = _deployAccount(STRATEGIST_KEY, "STRATEGIST");
        EMERGENCY_ADMIN = _deployAccount(EMERGENCY_ADMIN_KEY, "EMERGENCY_ADMIN");

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][GEAR_KEY]);
        console2.log("asset", address(asset));

        address gearboxStakingAddr = realVaultAddresses[ETH][STAKING_YIELD_SOURCE_ORACLE_KEY][GEARBOX_STAKING_KEY][GEAR_KEY];
        vm.label(gearboxStakingAddr, "GearboxStaking");

        // Get real yield sources from fork
        curveGearboxFarmingPool = IGearboxFarmingPool(gearboxStakingAddr);

        // Deploy vault trio with initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: VAULT_CAP,
            superVaultCap: SUPER_VAULT_CAP,
            maxAllocationRate: ONE_HUNDRED_PERCENT,
            vaultThreshold: VAULT_THRESHOLD
        });
        bytes32 hookRoot = _getMerkleRoot();
        address stakeHookAddress = _getHookAddress(ETH, GEARBOX_STAKE_HOOK_KEY);
        console2.log("stakeHookAddress", stakeHookAddress);

        address[] memory bootstrapHooks = new address[](1);
        bootstrapHooks[0] = stakeHookAddress;

        bytes32[][] memory bootstrapHookProofs = new bytes32[][](1);
        bootstrapHookProofs[0] = _getMerkleProof(stakeHookAddress);

        bytes[] memory bootstrapHooksData = new bytes[](1);
        bootstrapHooksData[0] = _createGearboxStakeHookData(
            bytes4(bytes(GEARBOX_YIELD_SOURCE_ORACLE_KEY)), 
            address(curveGearboxFarmingPool),
            BOOTSTRAP_AMOUNT, 
            false, 
            false
        );

        vm.startPrank(SV_MANAGER);
        deal(address(asset), SV_MANAGER, BOOTSTRAP_AMOUNT * 2);
        asset.approve(address(factory), BOOTSTRAP_AMOUNT * 2);

        // Deploy vault trio
        (address vaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: address(asset),
                name: "SuperVault Gearbox",
                symbol: "svGearbox",
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                config: config,
                finalMaxAllocationRate: MAX_ALLOCATION_RATE,
                bootstrapAmount: BOOTSTRAP_AMOUNT,
                initYieldSource: address(curveGearboxFarmingPool),
                initHooksRoot: hookRoot,
                initYieldSourceOracle: _getContract(ETH, STAKING_YIELD_SOURCE_ORACLE_KEY),
                bootstrappingHooks: bootstrapHooks,
                bootstrappingHookProofs: bootstrapHookProofs,
                bootstrappingHookCalldata: bootstrapHooksData
            })
        );
        vm.label(vaultAddr, "SuperVault Gearbox");
        vm.label(strategyAddr, "SuperVaultStrategy");
        vm.label(escrowAddr, "SuperVaultEscrow");

        // Cast addresses to contract types
        vault = SuperVault(vaultAddr);
        strategy = SuperVaultStrategy(strategyAddr);
        escrow = SuperVaultEscrow(escrowAddr);

        // Add a new yield source as manager
        strategy.manageYieldSource(
            address(curveGearboxFarmingPool),
            _getContract(ETH, STAKING_YIELD_SOURCE_ORACLE_KEY),
            0,
            false // addYieldSource
        );
        vm.stopPrank();

        _setFeeConfig(100, TREASURY);

        // Set up hook root (same one as bootstrap, just to test)
        vm.startPrank(SV_MANAGER);
        strategy.proposeOrExecuteHookRoot(hookRoot);
        vm.warp(block.timestamp + 7 days);
        strategy.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();
    }

    function test_SuperVault_Claim() public {
        vm.selectFork(FORKS[ETH]);

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);

        // Step 1: Request Deposit
        _requestDeposit(amount);

        // Verify assets transferred from user to vault
        assertEq(
            asset.balanceOf(accountEth), initialUserAssets - amount, "User assets not reduced after deposit request"
        );

        // Step 2: Fulfill Deposit
        _fulfillDeposit_CRV_SV(amount);

        // Step 3: Claim Deposit
        _claimDeposit(amount);

        // Get shares minted to user
        uint256 userShares = IERC20(vault.share()).balanceOf(accountEth);
    }

    function _fulfillDeposit_CRV_SV(uint256 depositAmount) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;
        address stakeHookAddress = _getHookAddress(ETH, GEARBOX_STAKE_HOOK_KEY);
        console2.log("stakeHookAddress", stakeHookAddress);

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = stakeHookAddress;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = _getMerkleProof(stakeHookAddress);

        bytes[] memory fulfillHooksData = new bytes[](1);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createGearboxStakeHookData(
            bytes4(bytes(STAKING_YIELD_SOURCE_ORACLE_KEY)), address(curveGearboxFarmingPool), depositAmount, false, false
        );

        vm.startPrank(STRATEGIST);
        strategy.fulfillRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData, true);
        vm.stopPrank();

        (uint256 pricePerShare) = _getSuperVaultPricePerShare();
        uint256 shares = depositAmount.mulDiv(PRECISION, pricePerShare);
        userSharePricePoints[accountEth].push(SharePricePoint({ shares: shares, pricePerShare: pricePerShare }));
    }
}
