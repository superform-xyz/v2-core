// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { console2 } from "forge-std/console2.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IGearboxFarmingPool } from "../../src/vendor/gearbox/IGearboxFarmingPool.sol";

// Superform
import { BaseTest } from "../BaseTest.t.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../src/executors/SuperExecutor.sol";
import { IVaultBank } from "../../src/vendor/superform/IVaultBank.sol";
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { MintSuperPositionsHook } from "../../src/hooks/vaults/vault-bank/MintSuperPositionsHook.sol";
import { ERC4626YieldSourceOracle } from "../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { StakingYieldSourceOracle } from "../../src/accounting/oracles/StakingYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";

contract CompositeHookFlowTests is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    uint256 depositAmount = 1e18;

    // IStandardizedYield public vaultInstance5115ETH;
    IERC4626 public vaultInstance4626;
    IGearboxFarmingPool public gearboxStaking;

    address public underlyingETH_USDC;

    address public yieldSource4626AddressUSDC;
    address public yieldSourceStakingAddress;

    address public accountEth;
    address public accountBase;

    AccountInstance public instanceOnEth;
    AccountInstance public instanceOnBase;

    address public vaultBank;

    SuperLedger public superLedger;
    SuperLedgerConfiguration public config;

    SuperExecutor public superExecutor;
    ISuperExecutor public superExecutorInterface;

    ERC4626YieldSourceOracle public oracle4626;
    StakingYieldSourceOracle public oracleStaking;

    address public manager;
    address public feeRecipient;

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

        config = new SuperLedgerConfiguration();
        superExecutor = new SuperExecutor(address(config));
        superExecutorInterface = ISuperExecutor(address(superExecutor));

        address[] memory executors = new address[](1);
        executors[0] = address(superExecutor);

        superLedger = new SuperLedger(address(config), executors);

        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

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
        vaultBank = makeAddr("vaultBank");

        instanceOnBase = accountInstances[BASE];
        accountBase = instanceOnBase.account;
    }

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
        _executeVaultBankRedeemFlow_UserUnLocksAssets(userSharesStaking, yieldSourceStakingAddress);

        // Withdraw from staking protocol
        _executeGearboxUnstakeFlow();

        // Redeem from 4626 vault
        _execute4626RedeemFlow(userShares);

        // Verify fee amounts from redeeming are co rrect
        uint256 userBalanceAfterRedeem = IERC20(underlyingETH_USDC).balanceOf(accountEth);

        assertEq(userBalanceAfterRedeem, expectedUserAssets);
        assertEq(IERC20(underlyingETH_USDC).balanceOf(feeRecipient), expectedFee);

        // Verify vault and staking balances are 0
        assertEq(vaultInstance4626.balanceOf(accountEth), 0);
        assertEq(gearboxStaking.balanceOf(accountEth), 0);
    }

    function test_CompositeHookFlow_SharesLocked_ViaPriorHook() public {
        vm.selectFork(FORKS[ETH]);

        // Execute 4626 vault deposit
        _execute4626DepositFlow();

        uint256 userShares = vaultInstance4626.balanceOf(accountEth);
        uint256 sharesAsAssets = vaultInstance4626.convertToAssets(userShares);

        (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee4626Vault(sharesAsAssets, userShares);

        // Stake vault shares
        _executeGearboxStakeFlow(userShares);

        uint256 userSharesStaking = gearboxStaking.balanceOf(accountEth);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry));
        executeOp(userOpData);
    }

    function _executeGearboxStakeFlow(uint256 userShares) internal {
        address[] memory hooksAddressesStake = new address[](1);
        hooksAddressesStake[0] = _getHookAddress(ETH, GEARBOX_APPROVE_AND_STAKE_HOOK_KEY);

        bytes[] memory hooksDataStake = new bytes[](1);
        hooksDataStake[0] = _createApproveAndGearboxStakeHookData(
            yieldSourceOracleIdStaking, yieldSourceStakingAddress, yieldSource4626AddressUSDC, userShares, false
        );

        ISuperExecutor.ExecutorEntry memory entryStake =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesStake, hooksData: hooksDataStake });
        UserOpData memory userOpDataStake = _getExecOps(instanceOnEth, superExecutor, abi.encode(entryStake));
        executeOp(userOpDataStake);
    }

    function _executeVaultBankLockFlow_UserLocksAssets(uint256 amount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(new MintSuperPositionsHook());

        address spToken = yieldSourceStakingAddress;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] =
            _createMintSuperPositionsHookData(yieldSourceOracleIdVaultBank, spToken, amount, false, vaultBank, 84_532);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry));
        executeOp(userOpData);
    }

    function _executeVaultBankRedeemFlow_UserUnLocksAssets(uint256 amount, address spToken) internal {
        vm.selectFork(FORKS[BASE]);

        vm.startPrank(accountBase);
        // IVaultBank(vaultBank).burnSuperPosition(amount, spToken, 1, yieldSourceOracleIdVaultBank);
        vm.stopPrank();

        vm.selectFork(FORKS[ETH]);
        //IVaultBank(vaultBank).unlockAsset(accountEth, spToken, amount, 84_532, yieldSourceOracleIdVaultBank, "");
        vm.stopPrank();
    }

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
        UserOpData memory userOpDataUnstake = _getExecOps(instanceOnEth, superExecutor, abi.encode(entryUnstake));
        executeOp(userOpDataUnstake);
    }

    function _execute4626RedeemFlow(uint256 userShares) internal {
        address[] memory hooksAddressesRedeem = new address[](1);
        hooksAddressesRedeem[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksDataRedeem = new bytes[](1);
        hooksDataRedeem[0] = _createRedeem4626HookData(
            yieldSourceOracleId4626, yieldSource4626AddressUSDC, accountEth, userShares, false
        );

        ISuperExecutor.ExecutorEntry memory entryRedeem =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
        UserOpData memory userOpDataRedeem = _getExecOps(instanceOnEth, superExecutor, abi.encode(entryRedeem));
        executeOp(userOpDataRedeem);
    }
}
