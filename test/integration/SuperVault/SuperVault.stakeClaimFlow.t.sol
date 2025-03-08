// SPDX-License-Identifier: UNLICENSED
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

import { console2 } from "forge-std/console2.sol";

contract SuperVaultStakeClaimFlowTest is BaseSuperVaultTest {
    using ModuleKitHelpers for *;
    using Math for uint256;

    SuperVault gearSuperVault;
    SuperVaultEscrow escrowGearSuperVault;
    SuperVaultStrategy strategyGearSuperVault;

    address gearToken;

    // Yield sources
    IERC4626 public gearboxVault;
    IGearboxFarmingPool public gearboxFarmingPool;

    uint256 public amount;
    uint256 public constant PRECISION = 1e18;

    function setUp() public override {
        super.setUp();

        amount = 1000e6; // 1000 GEAR

        vm.selectFork(FORKS[ETH]);

        // Set up accounts
        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];
        vm.label(accountEth, "AccountETH");

        // Get USDC from fork
        asset = IERC20Metadata(existingUnderlyingTokens[ETH][USDC_KEY]);
        vm.label(address(asset), "Asset");
        console2.log("asset: ", address(asset));

        gearToken = existingUnderlyingTokens[ETH][GEAR_KEY];
        console2.log("gearToken: ", address(gearToken));
        vm.label(gearToken, "GearToken");

        // Get real yield sources from fork
        address gearboxVaultAddr = realVaultAddresses[ETH][ERC4626_VAULT_KEY][GEARBOX_VAULT_KEY][USDC_KEY];
        vm.label(gearboxVaultAddr, "GearboxVault");
        gearboxVault = IERC4626(gearboxVaultAddr);

        address gearboxStakingAddr =
            realVaultAddresses[ETH][GEARBOX_YIELD_SOURCE_ORACLE_KEY][GEARBOX_STAKING_KEY][GEAR_KEY];
        console2.log("gearboxStakingAddr: ", gearboxStakingAddr);
        vm.label(gearboxStakingAddr, "GearboxStaking");
        gearboxFarmingPool = IGearboxFarmingPool(gearboxStakingAddr);

        // Deploy vault trio with initial config
        ISuperVaultStrategy.GlobalConfig memory config = ISuperVaultStrategy.GlobalConfig({
            vaultCap: VAULT_CAP,
            superVaultCap: SUPER_VAULT_CAP,
            vaultThreshold: VAULT_THRESHOLD
        });
        bytes32 hookRoot = _getMerkleRoot();

        address depositHookAddress = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory bootstrapHooks = new address[](1);
        bootstrapHooks[0] = depositHookAddress;

        bytes[] memory bootstrapHooksData = new bytes[](1);
        bootstrapHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(gearboxVault), BOOTSTRAP_AMOUNT, false, false
        );

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
                bootstrapAmount: BOOTSTRAP_AMOUNT,
                initYieldSource: address(gearboxVault),
                initHooksRoot: hookRoot,
                initYieldSourceOracle: _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
                bootstrappingHooks: bootstrapHooks,
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
            gearboxStakingAddr,
            _getContract(ETH, GEARBOX_YIELD_SOURCE_ORACLE_KEY),
            0,
            false // addYieldSource
        );
        vm.stopPrank();

        // Set up hook root (same one as bootstrap, just to test)
        vm.startPrank(SV_MANAGER);
        strategyGearSuperVault.proposeOrExecuteHookRoot(hookRoot);
        vm.warp(block.timestamp + 7 days);
        strategyGearSuperVault.proposeOrExecuteHookRoot(bytes32(0));
        vm.stopPrank();
    }

    function test_SuperVault_StakeClaimFlow() public {
        vm.selectFork(FORKS[ETH]);

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);

        // Step 1: Request Deposit
        __requestDeposit_Gearbox_SV(amount);

        // Verify assets transferred from user to vault
        assertEq(
            asset.balanceOf(accountEth), initialUserAssets - amount, "User assets not reduced after deposit request"
        );

        // Step 2: Fulfill Deposit
        _fulfillDeposit_Gearbox_SV(amount);

        uint256 amountToStake = gearboxVault.balanceOf(address(strategyGearSuperVault));

        // Step 3: Execute Arbitrary Hooks
        _executeStakeHook(amountToStake);

        assertGt(gearboxFarmingPool.balanceOf(address(strategyGearSuperVault)), 0, "Gearbox vault balance not increased after stake");

        // Step 3: Claim Deposit
        __claimDeposit_Gearbox_SV(amount);

        // Get shares minted to user
        uint256 userShares = IERC4626(gearSuperVault).balanceOf(accountEth);

        // Record balances before redeem
        uint256 preRedeemUserAssets = asset.balanceOf(accountEth);
        uint256 feeBalanceBefore = asset.balanceOf(TREASURY);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 50 weeks);

        uint256 amountToUnStake = gearboxFarmingPool.balanceOf(address(strategyGearSuperVault));

        console2.log("ppsBeforeUnStake: ", _getSuperVaultPricePerShare());

        uint256 preUnStakeGearboxBalance = gearboxVault.balanceOf(address(strategyGearSuperVault));

        _executeUnStakeHook(amountToUnStake);

        assertGt(gearboxVault.balanceOf(address(strategyGearSuperVault)), preUnStakeGearboxBalance, "Gearbox vault balance not decreased after unstake");

        console2.log("ppsAfterUnStake: ", _getSuperVaultPricePerShare());

        // Step 4: Request Redeem
        _requestRedeem_Gearbox_SV(userShares);

        // Verify shares are escrowed
        assertEq(IERC20(gearSuperVault.share()).balanceOf(accountEth), 0, "User shares not transferred from account");
        assertEq(
            IERC20(gearSuperVault.share()).balanceOf(address(escrowGearSuperVault)),
            userShares,
            "Shares not transferred to escrow"
        );

        // Step 5: Fulfill Redeem
        _fulfillRedeem_Gearbox_SV(userShares);

        uint256 claimableAssets = gearSuperVault.maxWithdraw(accountEth);

        // Step 6: Claim Withdraw
        _claimWithdraw_Gearbox_SV(claimableAssets);
        assertEq(asset.balanceOf(accountEth), preRedeemUserAssets + claimableAssets, "User assets not increased after withdraw");
        console2.log("ppsAfter: ", _getSuperVaultPricePerShare());
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function __requestDeposit_Gearbox_SV(uint256 depositAmount) private {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(asset), address(gearSuperVault), depositAmount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(gearSuperVault), depositAmount, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
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
        fulfillHooksData[0] = _createDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), address(gearboxVault), depositAmount, false, false
        );

        vm.startPrank(STRATEGIST);
        strategyGearSuperVault.fulfillRequests(requestingUsers, fulfillHooksAddresses, fulfillHooksData, true);
        vm.stopPrank();

        (uint256 pricePerShare) = _getSuperVaultPricePerShare();
        uint256 shares = depositAmount.mulDiv(PRECISION, pricePerShare);
        userSharePricePoints[accountEth].push(SharePricePoint({ shares: shares, pricePerShare: pricePerShare }));
    }

    function __claimDeposit_Gearbox_SV(uint256 depositAmount) private {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            address(gearSuperVault),
            depositAmount,
            false,
            false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    function _executeStakeHook(uint256 amountToStake) internal {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, GEARBOX_STAKE_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(gearboxVault), address(gearboxFarmingPool), amountToStake, false);
        hooksData[1] = _createGearboxStakeHookData(
            bytes4(bytes(GEARBOX_YIELD_SOURCE_ORACLE_KEY)), address(gearboxFarmingPool), amountToStake, false, false
        );

        vm.prank(STRATEGIST);
        strategyGearSuperVault.executeHooks(hooksAddresses, hooksData);
    }

    function _requestRedeem_Gearbox_SV(uint256 shares) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, REQUEST_WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRequestWithdraw7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(gearSuperVault), shares, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function _executeUnStakeHook(uint256 amountToUnStake) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, GEARBOX_UNSTAKE_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createGearboxUnstakeHookData(
            bytes4(bytes(GEARBOX_YIELD_SOURCE_ORACLE_KEY)), address(gearboxFarmingPool), amountToUnStake, false, false
        );

        vm.prank(STRATEGIST);
        strategyGearSuperVault.executeHooks(hooksAddresses, hooksData);
    }

    function _fulfillRedeem_Gearbox_SV(uint256 shares) internal {
        /// @dev with preserve percentages based on USD value allocation
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;
        address withdrawHookAddress = _getHookAddress(ETH, WITHDRAW_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = withdrawHookAddress;

        bytes[] memory fulfillHooksData = new bytes[](1);
        fulfillHooksData[0] = _createWithdraw4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(gearboxVault),
            address(strategyGearSuperVault),
            shares,
            false,
            false
        );

        vm.startPrank(STRATEGIST);
        strategyGearSuperVault.fulfillRequests(requestingUsers, fulfillHooksAddresses, fulfillHooksData, false);
        vm.stopPrank();
    }

    function _claimWithdraw_Gearbox_SV(uint256 assets) internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createWithdraw7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(gearSuperVault),  assets, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }
}
