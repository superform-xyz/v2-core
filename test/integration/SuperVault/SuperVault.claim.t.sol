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

    SuperVault gearSuperVault;
    SuperVaultEscrow escrowGearSuperVault;
    SuperVaultStrategy strategyGearSuperVault;

    // Yield sources
    IGearboxFarmingPool public curveGearboxFarmingPool;
    IERC4626 public gearboxVault;

    uint256 public amount;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant GEAR_SUPERVAULT_ALLOCATION_RATE = 10_000; // 100%

    function setUp() public override {
        super.setUp();

        console2.log("------setUp Gearbox Claim Test");

        amount = 1000e6; // 1000 GEAR

        vm.selectFork(FORKS[ETH]);

        accInstances = randomAccountInstances[ETH];
        assertEq(accInstances.length, ACCOUNT_COUNT);
        peripheryRegistry = PeripheryRegistry(_getContract(ETH, PERIPHERY_REGISTRY_KEY));

        // Set up accounts
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];

        vm.label(accountEth, "AccountETH");

        deal(address(asset), accountEth, 1000e18);

        accInstances = randomAccountInstances[ETH];

        vm.label(SV_MANAGER, "SV_MANAGER");
        vm.label(STRATEGIST, "STRATEGIST");
        vm.label(address(factory), "Factory");

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][USDC_KEY]);
        console2.log("asset: ", address(asset));

        // Get real yield sources from fork
        address gearboxVaultAddr = realVaultAddresses[ETH][ERC4626_VAULT_KEY][GEARBOX_VAULT_KEY][USDC_KEY];
        console2.log("----gearboxVaultAddr: ", gearboxVaultAddr);
        gearboxVault = IERC4626(gearboxVaultAddr);
        vm.label(gearboxVaultAddr, "GearboxVault");

        address gearboxStakingAddr 
        = realVaultAddresses[ETH][GEARBOX_YIELD_SOURCE_ORACLE_KEY][GEARBOX_STAKING_KEY][GEAR_KEY];
        vm.label(gearboxStakingAddr, "GearboxStaking");

        // Deploy vault trio with initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: VAULT_CAP,
            superVaultCap: SUPER_VAULT_CAP,
            maxAllocationRate: ONE_HUNDRED_PERCENT,
            vaultThreshold: VAULT_THRESHOLD
        });
        bytes32 hookRoot = _getMerkleRoot();

        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);
        address stakeHookAddress = _getHookAddress(ETH, GEARBOX_STAKE_HOOK_KEY);
        console2.log("stakeHookAddress: ", stakeHookAddress);

        address[] memory bootstrapHooks = new address[](1);
        bootstrapHooks[0] = depositHookAddress;
        //bootstrapHooks[1] = stakeHookAddress;

        bytes32[][] memory bootstrapHookProofs = new bytes32[][](1);
        bootstrapHookProofs[0] = _getMerkleProof(depositHookAddress);
        //bootstrapHookProofs[1] = _getMerkleProof(stakeHookAddress);

        bytes[] memory bootstrapHooksData = new bytes[](1);
        bootstrapHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), 
            address(gearboxVault),
            BOOTSTRAP_AMOUNT, 
            false, 
            false
        );
        // bootstrapHooksData[1] = _createGearboxStakeHookData(
        //     bytes4(bytes(GEARBOX_YIELD_SOURCE_ORACLE_KEY)), 
        //     address(curveGearboxFarmingPool),
        //     BOOTSTRAP_AMOUNT, 
        //     false, 
        //     false
        // );

        vm.startPrank(SV_MANAGER);
        deal(address(asset), SV_MANAGER, BOOTSTRAP_AMOUNT * 2);
        asset.approve(address(factory), BOOTSTRAP_AMOUNT * 2);

        // Deploy vault trio
        (address gearSuperVaultAddr, address strategyAddr, address escrowAddr) = factory.createVault(
            ISuperVaultFactory.VaultCreationParams({
                asset: address(asset),
                name: "SuperVault Gearbox",
                symbol: "svGearbox",
                manager: SV_MANAGER,
                strategist: STRATEGIST,
                emergencyAdmin: EMERGENCY_ADMIN,
                feeRecipient: TREASURY,
                config: config,
                finalMaxAllocationRate: GEAR_SUPERVAULT_ALLOCATION_RATE,
                bootstrapAmount: BOOTSTRAP_AMOUNT,
                initYieldSource: address(gearboxVault),
                initHooksRoot: hookRoot,
                initYieldSourceOracle: _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
                bootstrappingHooks: bootstrapHooks,
                bootstrappingHookProofs: bootstrapHookProofs,
                bootstrappingHookCalldata: bootstrapHooksData
            })
        );
        vm.label(gearSuperVaultAddr, "GearSuperVault");
        vm.label(strategyAddr, "GearSuperVaultStrategy");
        vm.label(escrowAddr, "GearSuperVaultEscrow");

        // Cast addresses to contract types
        gearSuperVault = SuperVault(gearSuperVaultAddr);
        escrowGearSuperVault = SuperVaultEscrow(escrowAddr);
        strategyGearSuperVault = SuperVaultStrategy(strategyAddr);

        // Add a new yield source as manager
        strategyGearSuperVault.manageYieldSource(
            address(gearboxStakingAddr),
            _getContract(ETH, GEARBOX_YIELD_SOURCE_ORACLE_KEY),
            0,
            false // addYieldSource
        );
        vm.stopPrank();

        _setFeeConfig(100, TREASURY);

        // Set up hook root (same one as bootstrap, just to test)
        vm.startPrank(SV_MANAGER);
        strategyGearSuperVault.proposeOrExecuteHookRoot(hookRoot);
        vm.warp(block.timestamp + 7 days);
        strategyGearSuperVault.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();
    }

    function test_SuperVault_Claim() public {
        vm.selectFork(FORKS[ETH]);

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);

        // Step 1: Request Deposit
        __requestDeposit_Gearbox_SV(instanceOnEth, amount);

        // Verify assets transferred from user to vault
        assertEq(
            asset.balanceOf(accountEth), initialUserAssets - amount, "User assets not reduced after deposit request"
        );

        // Step 2: Fulfill Deposit
        _fulfillDeposit_Gearbox_SV(amount);

        // Step 3: Claim Deposit
        __claimDeposit_Gearbox_SV(instanceOnEth, amount);

        // Get shares minted to user
        uint256 userShares = IERC20(vault.share()).balanceOf(accountEth);
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function __requestDeposit_Gearbox_SV(AccountInstance memory accInst, uint256 depositAmount) private {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(asset), address(gearSuperVault), depositAmount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(gearSuperVault), accInst.account, depositAmount, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function _fulfillDeposit_Gearbox_SV(uint256 depositAmount) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;
        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = _getMerkleProof(depositHookAddress);

        bytes[] memory fulfillHooksData = new bytes[](1);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createGearboxStakeHookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(gearboxVault), depositAmount, false, false
        );

        vm.startPrank(STRATEGIST);
        strategyGearSuperVault.fulfillRequests(requestingUsers, fulfillHooksAddresses, proofs, fulfillHooksData, true);
        vm.stopPrank();

        (uint256 pricePerShare) = _getSuperVaultPricePerShare();
        uint256 shares = depositAmount.mulDiv(PRECISION, pricePerShare);
        userSharePricePoints[accountEth].push(SharePricePoint({ shares: shares, pricePerShare: pricePerShare }));
    }

    function __claimDeposit_Gearbox_SV(AccountInstance memory accInst, uint256 depositAmount) private {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(gearSuperVault), accInst.account, depositAmount, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(accInst, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }
}
