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

import { ModuleKitHelpers, AccountInstance, AccountType, UserOpData } from "modulekit/ModuleKit.sol";

// superform
import { SuperVault } from "../../../src/periphery/SuperVault.sol";
import { SuperVaultEscrow } from "../../../src/periphery/SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "../../../src/periphery/interfaces/ISuperVaultStrategy.sol";
import { ISuperLedgerConfiguration } from "../../../src/core/interfaces/accounting/ISuperLedgerConfiguration.sol";
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

        vm.startPrank(SV_MANAGER);

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
                superVaultCap: SUPER_VAULT_CAP
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
            address(gearboxVault),
            _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            false
        );
        strategyGearSuperVault.manageYieldSource(
            gearboxStakingAddr,
            _getContract(ETH, GEARBOX_YIELD_SOURCE_ORACLE_KEY),
            0,
            false, // addYieldSource
            false
        );
        vm.stopPrank();

        // Set up hook root (same one as bootstrap, just to test)
        vm.startPrank(SV_MANAGER);
        strategyGearSuperVault.proposeOrExecuteHookRoot(hookRootPerChain[ETH]);
        vm.warp(block.timestamp + 7 days);
        strategyGearSuperVault.proposeOrExecuteHookRoot(bytes32(0));

        strategyGearSuperVault.proposeVaultFeeConfigUpdate(100, TREASURY);
        vm.warp(block.timestamp + 1 weeks);
        strategyGearSuperVault.executeVaultFeeConfigUpdate();
        vm.stopPrank();

        vm.startPrank(MANAGER);
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracleId: bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSourceOracle: _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY),
            feePercent: 0,
            feeRecipient: TREASURY,
            ledger: _getContract(ETH, SUPER_LEDGER_KEY)
        });
        ISuperLedgerConfiguration(_getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY)).proposeYieldSourceOracleConfig(
            configs
        );
        vm.warp(block.timestamp + 2 weeks);
        bytes4[] memory yieldSourceOracleIds = new bytes4[](1);
        yieldSourceOracleIds[0] = bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY));
        ISuperLedgerConfiguration(_getContract(ETH, SUPER_LEDGER_CONFIGURATION_KEY))
            .acceptYieldSourceOracleConfigProposal(yieldSourceOracleIds);
        vm.stopPrank();
    }

    function test_SuperVault_StakeClaimFlow() public {
        vm.selectFork(FORKS[ETH]);

        vm.startPrank(SV_MANAGER);
        strategyGearSuperVault.updateSuperVaultCap(type(uint256).max);
        vm.stopPrank();

        // Record initial balances
        uint256 initialUserAssets = asset.balanceOf(accountEth);
        uint256 feeBalanceBefore = asset.balanceOf(TREASURY);

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

        assertGt(
            gearboxFarmingPool.balanceOf(address(strategyGearSuperVault)),
            0,
            "Gearbox vault balance not increased after stake"
        );

        // Step 3: Claim Deposit
        __claimDeposit_Gearbox_SV(amount);

        // Get shares minted to user
        uint256 userShares = IERC4626(gearSuperVault).balanceOf(accountEth);

        // Record balances before redeem
        uint256 preRedeemUserAssets = asset.balanceOf(accountEth);

        // Fast forward time to simulate yield on underlying vaults
        vm.warp(block.timestamp + 60 weeks);

        console2.log("ppsBeforeUnStake: ", _getGearSuperVaultPricePerShare());

        uint256 preUnStakeGearboxBalance = gearboxVault.balanceOf(address(strategyGearSuperVault));

        uint256 amountToUnStake = gearboxFarmingPool.balanceOf(address(strategyGearSuperVault));

        _executeUnStakeHook(amountToUnStake);

        assertGt(
            gearboxVault.balanceOf(address(strategyGearSuperVault)),
            preUnStakeGearboxBalance,
            "Gearbox vault balance not decreased after unstake"
        );

        console2.log("ppsAfterUnStake: ", _getGearSuperVaultPricePerShare());

        // Step 4: Request Redeem
        _requestRedeem_Gearbox_SV(userShares);

        // Verify shares are escrowed
        assertEq(IERC20(gearSuperVault.share()).balanceOf(accountEth), 0, "User shares not transferred from account");
        assertEq(
            IERC20(gearSuperVault.share()).balanceOf(address(escrowGearSuperVault)),
            userShares,
            "Shares not transferred to escrow"
        );

        (uint256 recipientFee, uint256 superformFee) =
            _deriveSuperVaultFees(userShares, _getGearSuperVaultPricePerShare());

        // Step 5: Fulfill Redeem
        _fulfillRedeem_Gearbox_SV();

        uint256 totalFee = recipientFee + superformFee;
        console2.log("totalFee: ", totalFee);
        console2.log("feeBalanceBefore: ", feeBalanceBefore);
        console2.log("asset.balanceOf(TREASURY): ", asset.balanceOf(TREASURY));
        console2.log("recipientFee: ", recipientFee);
        console2.log("superformFee: ", superformFee);

        uint256 claimableAssets = gearSuperVault.maxWithdraw(accountEth);

        // Step 6: Claim Withdraw
        _claimWithdraw_Gearbox_SV(claimableAssets);

        _assertFeeDerivation(totalFee, feeBalanceBefore, asset.balanceOf(TREASURY));

        assertEq(
            asset.balanceOf(accountEth),
            preRedeemUserAssets + claimableAssets,
            "User assets not increased after withdraw"
        );
        console2.log("ppsAfter: ", _getGearSuperVaultPricePerShare());
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function __requestDeposit_Gearbox_SV(uint256 depositAmount) private {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_AND_REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndRequestDeposit7540HookData(
            address(gearSuperVault),
            address(asset),
            depositAmount,
            false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

    function _fulfillDeposit_Gearbox_SV(uint256 depositAmount) internal {
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;

        address depositHookAddress = _getHookAddress(ETH, APPROVE_AND_DEPOSIT_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = depositHookAddress;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = _getMerkleProof(depositHookAddress);

        bytes[] memory fulfillHooksData = new bytes[](1);
        // allocate up to the max allocation rate in the two Vaults
        fulfillHooksData[0] = _createApproveAndDeposit4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(gearboxVault),
            address(asset),
            depositAmount,
            false,
            false
        );

        uint256[] memory minAssetsOrSharesOut = new uint256[](1);
        minAssetsOrSharesOut[0] = gearboxVault.convertToShares(depositAmount);

        vm.startPrank(STRATEGIST);
        strategyGearSuperVault.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: requestingUsers,
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                hookProofs: _getMerkleProofsForAddresses(fulfillHooksAddresses),
                expectedAssetsOrSharesOut: minAssetsOrSharesOut
            })
        );
        vm.stopPrank();

        (uint256 pricePerShare) = _getGearSuperVaultPricePerShare();
        uint256 shares = depositAmount.mulDiv(PRECISION, pricePerShare);

        _trackDeposit(accountEth, shares, depositAmount);
    }

    function __claimDeposit_Gearbox_SV(uint256 depositAmount) private {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createDeposit7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(gearSuperVault), depositAmount, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    function _executeStakeHook(uint256 amountToStake) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, GEARBOX_APPROVE_AND_STAKE_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createApproveAndGearboxStakeHookData(
            bytes4(bytes(GEARBOX_YIELD_SOURCE_ORACLE_KEY)),
            address(gearboxFarmingPool),
            address(gearboxVault),
            amountToStake,
            false,
            false
        );

        vm.prank(STRATEGIST);
        strategyGearSuperVault.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                hookProofs: _getMerkleProofsForAddresses(hooksAddresses),
                expectedAssetsOrSharesOut: new uint256[](1)
            })
        );
    }

    function _requestRedeem_Gearbox_SV(uint256 shares) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, REQUEST_REDEEM_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRequestRedeem7540VaultHookData(
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
        strategyGearSuperVault.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: new address[](0),
                hooks: hooksAddresses,
                hookCalldata: hooksData,
                hookProofs: _getMerkleProofsForAddresses(hooksAddresses),
                expectedAssetsOrSharesOut: new uint256[](1)
            })
        );
    }

    function _fulfillRedeem_Gearbox_SV() internal {
        /// @dev with preserve percentages based on USD value allocation
        address[] memory requestingUsers = new address[](1);
        requestingUsers[0] = accountEth;
        address withdrawHookAddress = _getHookAddress(ETH, APPROVE_AND_REDEEM_4626_VAULT_HOOK_KEY);

        address[] memory fulfillHooksAddresses = new address[](1);
        fulfillHooksAddresses[0] = withdrawHookAddress;

        uint256 shares = strategyGearSuperVault.pendingRedeemRequest(accountEth);

        bytes[] memory fulfillHooksData = new bytes[](1);
        fulfillHooksData[0] = _createApproveAndRedeem4626HookData(
            bytes4(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            address(gearboxVault),
            address(gearboxVault),
            address(strategyGearSuperVault),
            shares,
            false,
            false
        );

        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        uint256 assets = gearSuperVault.convertToAssets(shares);
        uint256 underlyingShares = gearboxVault.previewDeposit(assets);
        expectedAssetsOrSharesOut[0] = underlyingShares;

        vm.startPrank(STRATEGIST);
        strategyGearSuperVault.executeHooks(
            ISuperVaultStrategy.ExecuteArgs({
                users: requestingUsers,
                hooks: fulfillHooksAddresses,
                hookCalldata: fulfillHooksData,
                hookProofs: _getMerkleProofsForAddresses(fulfillHooksAddresses),
                expectedAssetsOrSharesOut: expectedAssetsOrSharesOut
            })
        );
        vm.stopPrank();
    }

    function _claimWithdraw_Gearbox_SV(uint256 assets) internal {
        address[] memory claimHooksAddresses = new address[](1);
        claimHooksAddresses[0] = _getHookAddress(ETH, APPROVE_AND_WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory claimHooksData = new bytes[](1);
        claimHooksData[0] = _createApproveAndWithdraw7540VaultHookData(
            bytes4(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)), address(gearSuperVault), vault.share(), assets, false, false
        );

        ISuperExecutor.ExecutorEntry memory claimEntry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: claimHooksAddresses, hooksData: claimHooksData });
        UserOpData memory claimUserOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(claimEntry));
        executeOp(claimUserOpData);
    }

    function _getGearSuperVaultPricePerShare() internal view returns (uint256 pricePerShare) {
        uint256 totalSupplyAmount = gearSuperVault.totalSupply();
        if (totalSupplyAmount == 0) {
            // For first deposit, set initial PPS to 1 unit in price decimals
            pricePerShare = PRECISION;
        } else {
            // Calculate current PPS in price decimals
            (uint256 totalAssetsVault,) = strategyGearSuperVault.totalAssets();
            pricePerShare = totalAssetsVault.mulDiv(PRECISION, totalSupplyAmount, Math.Rounding.Floor);
        }
    }
}
