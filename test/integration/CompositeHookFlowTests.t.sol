// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { MockVaultBank } from "../mocks/MockVaultBank.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IGearboxFarmingPool } from "../../src/vendor/gearbox/IGearboxFarmingPool.sol";

// Superform
import { BaseTest } from "../BaseTest.t.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../src/executors/superExecutor.sol";
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { IVaultBank, IVaultBankSource, IVaultBankDestination } from "../../src/vendor/superform/IVaultBank.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { MintSuperPositionsHook } from "../../src/hooks/vaults/vault-bank/MintSuperPositionsHook.sol";
import { ERC4626YieldSourceOracle } from "../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { StakingYieldSourceOracle } from "../../src/accounting/oracles/StakingYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";

contract CompositeHookFlowTests is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    uint256 depositAmount = 1e18;

    IERC4626 public vaultInstance4626;
    IGearboxFarmingPool public gearboxStaking;

    address public underlyingETH_USDC;
    address public yieldSourceStakingAddress;
    address public yieldSource4626AddressUSDC;

    address public accountEth;
    address public accountBase;
    AccountInstance public instanceOnEth;
    AccountInstance public instanceOnBase;

    MockVaultBank public vaultBankETH;
    MockVaultBank public vaultBankBase;

    address public vaultBankAddressETH;
    address public vaultBankAddressBase;

    address public manager;
    address public feeRecipient;

    SuperLedger public superLedger;
    SuperLedgerConfiguration public config;

    SuperExecutor public superExecutorETH;
    ISuperExecutor public superExecutorETHInterface;
    SuperExecutor public superExecutorBase;
    ISuperExecutor public superExecutorBaseInterface;

    ERC4626YieldSourceOracle public oracle4626;
    StakingYieldSourceOracle public oracleStaking;

    bytes32 public yieldSourceOracleId4626;
    bytes32 public yieldSourceOracleIdStaking;
    bytes32 public yieldSourceOracleIdVaultBank;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        instanceOnEth = accountInstances[ETH];
        accountEth = instanceOnEth.account;

        underlyingETH_USDC = CHAIN_1_USDC;

        _getTokens(underlyingETH_USDC, accountEth, 1e18);

        yieldSource4626AddressUSDC = CHAIN_1_GearboxVault;
        vaultInstance4626 = IERC4626(yieldSource4626AddressUSDC);

        yieldSourceStakingAddress = CHAIN_1_GearboxStaking;
        gearboxStaking = IGearboxFarmingPool(yieldSourceStakingAddress);

        vaultBankETH = new MockVaultBank();
        vaultBankAddressETH = address(vaultBankETH);

        config = new SuperLedgerConfiguration();
        superExecutorETH = new SuperExecutor(address(config));
        superExecutorETHInterface = ISuperExecutor(address(superExecutorETH));

        address[] memory executors = new address[](1);
        executors[0] = address(superExecutorETH);

        superLedger = new SuperLedger(address(config), executors);

        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorETH), data: "" });

        oracle4626 = new ERC4626YieldSourceOracle(address(superLedger));
        oracleStaking = new StakingYieldSourceOracle(address(superLedger));

        feeRecipient = makeAddr("feeRecipient");
        manager = makeAddr("manager");

        yieldSourceOracleIdVaultBank = bytes32(keccak256("VAULT_BANK_ORACLE_ID"));

        bytes32[] memory yieldSourceOracleSalts = new bytes32[](2);
        yieldSourceOracleSalts[0] = bytes32(keccak256("4626_ORACLE_ID"));
        yieldSourceOracleSalts[1] = bytes32(keccak256("STAKING_ORACLE_ID"));

        yieldSourceOracleId4626 = keccak256(abi.encodePacked(yieldSourceOracleSalts[0], manager));
        yieldSourceOracleIdStaking = keccak256(abi.encodePacked(yieldSourceOracleSalts[1], manager));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](2);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle4626),
            feePercent: 2000, // 20%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracleStaking),
            feePercent: 1000, // 10%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });

        // Set the oracle configs
        vm.prank(manager);
        config.setYieldSourceOracles(yieldSourceOracleSalts, configs);

        vm.selectFork(FORKS[BASE]);

        // superExecutorBase = new superExecutorETH(address(config));
        // superExecutorETHInterfaceBase = ISuperExecutor(address(superExecutorBase));

        vaultBankBase = new MockVaultBank();
        vaultBankAddressBase = address(vaultBankBase);

        // instanceOnBase.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutorETH), data: "" });

        instanceOnBase = accountInstances[BASE];
        accountBase = instanceOnBase.account;
    }

    // In this test, we lock the staking shares in the VaultBank via the user calling the lockAsset function
    // and then redeem them back to the ETH chain and assert the correct fee amounts and balances
    function test_CompositeHookFlow_UserLocksAssets() public {
        vm.selectFork(FORKS[ETH]);

        // Execute 4626 vault deposit
        _execute4626DepositFlow();

        uint256 userShares = vaultInstance4626.balanceOf(accountEth);
        uint256 sharesAsAssets = vaultInstance4626.convertToAssets(userShares);

        (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee4626Vault(sharesAsAssets, userShares);

        // Stake vault shares
        _executeGearboxStakeFlow(userShares);

        uint256 userSharesStaking = gearboxStaking.balanceOf(accountEth);

        // Lock staking shares in VaultBank & bridge to another chain
        _executeVaultBankLockFlow_UserLocksAssets(userSharesStaking);

        // Asynchronous redeem back to ETH & unlock assets
        _executeVaultBankRedeemFlow_UserUnlocksAssets(userSharesStaking);

        // Withdraw from staking protocol
        _executeGearboxUnstakeFlow();

        // Redeem from 4626 vault
        _execute4626RedeemFlow(userShares);

        // Verify fee amounts from redeeming are correct
        uint256 userBalanceAfterRedeem = IERC20(underlyingETH_USDC).balanceOf(accountEth);

        assertEq(userBalanceAfterRedeem, expectedUserAssets);
        assertEq(IERC20(underlyingETH_USDC).balanceOf(feeRecipient), expectedFee);

        // Verify vault and staking balances are 0
        assertEq(vaultInstance4626.balanceOf(accountEth), 0);
        assertEq(gearboxStaking.balanceOf(accountEth), 0);
    }

    // In this test, we lock the staking shares in the VaultBank via the MintSuperPositionsHook
    // and then redeem them back to the ETH chain and assert the correct fee amounts and balances
    function test_CompositeHookFlow_SharesLocked_ViaHook() public {
        vm.selectFork(FORKS[ETH]);

        // Execute 4626 vault deposit
        _execute4626DepositFlow();

        uint256 userShares = vaultInstance4626.balanceOf(accountEth);
        uint256 sharesAsAssets = vaultInstance4626.convertToAssets(userShares);

        (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee4626Vault(sharesAsAssets, userShares);

        // Stake vault shares
        _executeGearboxStakeFlow(userShares);

        uint256 userSharesStaking = gearboxStaking.balanceOf(accountEth);

        // Lock staking shares in VaultBank & bridge to another chain
        _executeVaultBankLockFlow_ViaHook(userSharesStaking);

        // Asynchronous redeem back to ETH & unlock assets
        _executeVaultBankRedeemFlow_UserUnlocksAssets(userSharesStaking);

        // Withdraw from staking protocol
        _executeGearboxUnstakeFlow();

        // Redeem from 4626 vault
        _execute4626RedeemFlow(userShares);

        // Verify fee amounts from redeeming are correct
        uint256 userBalanceAfterRedeem = IERC20(underlyingETH_USDC).balanceOf(accountEth);

        assertEq(userBalanceAfterRedeem, expectedUserAssets);
        assertEq(IERC20(underlyingETH_USDC).balanceOf(feeRecipient), expectedFee);

        // Verify vault and staking balances are 0
        assertEq(vaultInstance4626.balanceOf(accountEth), 0);
        assertEq(gearboxStaking.balanceOf(accountEth), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Calculates the expected fee and user assets for the 4626 vault
    function _calculateExpectedFee4626Vault(
        uint256 sharesAsAssets,
        uint256 userShares
    )
        internal
        view
        returns (uint256 expectedFee, uint256 expectedUserAssets)
    {
        expectedFee = superLedger.previewFees(accountEth, yieldSource4626AddressUSDC, sharesAsAssets, userShares, 2000);
        expectedUserAssets = sharesAsAssets - expectedFee;
    }

    /// @notice Executes the 4626 vault deposit flow via hook executions
    function _execute4626DepositFlow() internal {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSource4626AddressUSDC, depositAmount, false);
        hooksData[1] = _createDeposit4626HookData(
            yieldSourceOracleId4626, yieldSource4626AddressUSDC, depositAmount, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorETH, abi.encode(entry));
        executeOp(userOpData);
    }

    /// @notice Executes the Gearbox stake flow via hook executions
    function _executeGearboxStakeFlow(uint256 userShares) internal {
        address[] memory hooksAddressesStake = new address[](1);
        hooksAddressesStake[0] = _getHookAddress(ETH, GEARBOX_APPROVE_AND_STAKE_HOOK_KEY);

        bytes[] memory hooksDataStake = new bytes[](1);
        hooksDataStake[0] = _createApproveAndGearboxStakeHookData(
            yieldSourceOracleIdStaking, yieldSourceStakingAddress, yieldSource4626AddressUSDC, userShares, false
        );

        ISuperExecutor.ExecutorEntry memory entryStake =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesStake, hooksData: hooksDataStake });
        UserOpData memory userOpDataStake = _getExecOps(instanceOnEth, superExecutorETH, abi.encode(entryStake));
        executeOp(userOpDataStake);
    }

    /// @notice Executes the VaultBank lock flow via user calling the lockAsset function
    function _executeVaultBankLockFlow_UserLocksAssets(uint256 amount) internal {
        vm.startPrank(accountEth);
        IERC20(yieldSourceStakingAddress).approve(vaultBankAddressETH, amount);

        vm.expectEmit(false, false, false, true);
        emit IVaultBankSource.SharesLocked(yieldSourceOracleIdStaking, accountEth, yieldSourceStakingAddress, amount, uint64(block.chainid), 84_532, 0);

        IVaultBank(vaultBankAddressETH).lockAsset(yieldSourceOracleIdStaking, accountEth, yieldSourceStakingAddress, address(0), amount, 84_532);
        vm.stopPrank();
    }

    /// @notice Executes the VaultBank lock flow via the MintSuperPositionsHook
    function _executeVaultBankLockFlow_ViaHook(uint256 amount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, MINT_SUPERPOSITIONS_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createMintSuperPositionsHookData(yieldSourceOracleIdStaking, yieldSourceStakingAddress, amount, false, vaultBankAddressETH, 84_532);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorETH, abi.encode(entry));

        vm.expectEmit(false, false, false, true);
        emit IVaultBankSource.SharesLocked(yieldSourceOracleIdStaking, accountEth, yieldSourceStakingAddress, amount, uint64(block.chainid), 84_532, 0);
        executeOp(userOpData);
    }

    /// @notice Executes the VaultBank redeem flow via user calling the burnSuperPosition function
    function _executeVaultBankRedeemFlow_UserUnlocksAssets(uint256 amount) internal {
        vm.selectFork(FORKS[BASE]);

        vm.prank(accountBase);
        vm.expectEmit(false, false, false, true);
        emit IVaultBank.SuperpositionsBurned(address(0), address(vaultBankBase), address(0), amount, uint64(block.chainid), 0);
        IVaultBank(vaultBankAddressBase).burnSuperPosition(amount, vaultBankAddressBase, 84_532, yieldSourceOracleIdStaking);

        vm.selectFork(FORKS[ETH]);

        vm.prank(accountEth);
        vm.expectEmit(false, false, false, true);
        emit IVaultBankSource.SharesUnlocked(yieldSourceOracleIdStaking, accountEth, yieldSourceStakingAddress, amount, uint64(block.chainid), 84_532, 0);
        IVaultBank(vaultBankAddressETH).unlockAsset(accountEth, yieldSourceStakingAddress, amount, 84_532, yieldSourceOracleIdStaking, bytes(""));
    }

    /// @notice Executes the Gearbox unstake flow via hook executions
    function _executeGearboxUnstakeFlow() internal {
        uint256 userStakingBalance = gearboxStaking.balanceOf(accountEth);

        address[] memory hooksAddressesUnstake = new address[](1);
        hooksAddressesUnstake[0] = _getHookAddress(ETH, GEARBOX_UNSTAKE_HOOK_KEY);

        bytes[] memory hooksDataUnstake = new bytes[](1);
        hooksDataUnstake[0] = _createGearboxUnstakeHookData(
            yieldSourceOracleIdStaking, yieldSourceStakingAddress, userStakingBalance, false
        );

        ISuperExecutor.ExecutorEntry memory entryUnstake =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesUnstake, hooksData: hooksDataUnstake });
        UserOpData memory userOpDataUnstake = _getExecOps(instanceOnEth, superExecutorETH, abi.encode(entryUnstake));
        executeOp(userOpDataUnstake);
    }

    /// @notice Executes the 4626 vault redeem flow via hook executions
    function _execute4626RedeemFlow(uint256 userShares) internal {
        address[] memory hooksAddressesRedeem = new address[](1);
        hooksAddressesRedeem[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksDataRedeem = new bytes[](1);
        hooksDataRedeem[0] = _createRedeem4626HookData(
            yieldSourceOracleId4626, yieldSource4626AddressUSDC, accountEth, userShares, false
        );

        ISuperExecutor.ExecutorEntry memory entryRedeem =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
        UserOpData memory userOpDataRedeem = _getExecOps(instanceOnEth, superExecutorETH, abi.encode(entryRedeem));
        executeOp(userOpDataRedeem);
    }
}
