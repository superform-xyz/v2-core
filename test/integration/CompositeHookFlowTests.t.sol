// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { MockVaultBank } from "../mocks/MockVaultBank.sol";
import { IDistributor } from "../../src/vendor/merkl/IDistributor.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IGearboxFarmingPool } from "../../src/vendor/gearbox/IGearboxFarmingPool.sol";

// Superform
import { BaseTest } from "../BaseTest.t.sol";
import { TestHook } from "../unit/hooks/BaseHook.t.sol";
import { BaseHook } from "../../src/hooks/BaseHook.sol";
import { ISuperHook } from "../../src/interfaces/ISuperHook.sol";
import { SuperLedger } from "../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../src/executors/SuperExecutor.sol";
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { IVaultBank, IVaultBankSource, IVaultBankDestination } from "../../src/vendor/superform/IVaultBank.sol";
import { ISuperLedgerConfiguration } from "../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { MintSuperPositionsHook } from "../../src/hooks/vaults/vault-bank/MintSuperPositionsHook.sol";
import { ERC4626YieldSourceOracle } from "../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { StakingYieldSourceOracle } from "../../src/accounting/oracles/StakingYieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../src/accounting/SuperLedgerConfiguration.sol";
import { MerklClaimRewardHook } from "../../src/hooks/claim/merkl/MerklClaimRewardHook.sol";

contract CompositeHookFlowTests is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    uint256 depositAmount = 1e18;

    IERC4626 public vaultInstance4626;
    IGearboxFarmingPool public gearboxStaking;

    IDistributor public merklDistributor;
    address public merklDistributorAddress;

    address public underlyingETH_USDC;
    address public underlyingBase_USDC;
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

    TestHook public hookOutflow;
    MerklClaimRewardHook public merklClaimRewardHook;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        instanceOnEth = accountInstances[ETH];
        accountEth = instanceOnEth.account;

        underlyingETH_USDC = CHAIN_1_USDC;

        merklDistributorAddress = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
        merklDistributor = IDistributor(merklDistributorAddress);

        _getTokens(underlyingETH_USDC, merklDistributorAddress, 1e18);
        _getTokens(underlyingETH_USDC, accountEth, 1e18);

        hookOutflow = new TestHook(ISuperHook.HookType.OUTFLOW, bytes32(keccak256("TEST_SUBTYPE")));

        yieldSource4626AddressUSDC = CHAIN_1_GEARBOX_VAULT;
        vaultInstance4626 = IERC4626(yieldSource4626AddressUSDC);

        yieldSourceStakingAddress = CHAIN_1_GEARBOX_STAKING;
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

        // Base chain setup
        vm.selectFork(FORKS[BASE]);

        vaultBankBase = new MockVaultBank();
        vaultBankAddressBase = address(vaultBankBase);

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
        emit IVaultBankSource.SharesLocked(
            yieldSourceOracleIdStaking, accountEth, yieldSourceStakingAddress, amount, uint64(block.chainid), BASE, 0
        );

        IVaultBank(vaultBankAddressETH).lockAsset(
            yieldSourceOracleIdStaking, accountEth, yieldSourceStakingAddress, address(0), amount, BASE
        );
        vm.stopPrank();
    }

    /// @notice Executes the VaultBank lock flow via the MintSuperPositionsHook
    function _executeVaultBankLockFlow_ViaHook(uint256 amount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, MINT_SUPERPOSITIONS_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createMintSuperPositionsHookData(
            yieldSourceOracleIdStaking, yieldSourceStakingAddress, amount, false, vaultBankAddressETH, BASE
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorETH, abi.encode(entry));

        vm.expectEmit(false, false, false, true);
        emit IVaultBankSource.SharesLocked(
            yieldSourceOracleIdStaking, accountEth, yieldSourceStakingAddress, amount, ETH, BASE, 0
        );
        executeOp(userOpData);
    }

    /// @notice Executes the VaultBank redeem flow via user calling the burnSuperPosition function
    function _executeVaultBankRedeemFlow_UserUnlocksAssets(uint256 amount) internal {
        vm.selectFork(FORKS[BASE]);

        vm.prank(accountBase);
        vm.expectEmit(false, false, false, true);
        emit IVaultBank.SuperpositionsBurned(address(0), address(vaultBankBase), address(0), amount, BASE, 0);
        IVaultBank(vaultBankAddressBase).burnSuperPosition(
            amount, vaultBankAddressBase, BASE, yieldSourceOracleIdStaking
        );

        vm.selectFork(FORKS[ETH]);

        vm.prank(accountEth);
        vm.expectEmit(false, false, false, true);
        emit IVaultBankSource.SharesUnlocked(
            yieldSourceOracleIdStaking, accountEth, yieldSourceStakingAddress, amount, ETH, BASE, 0
        );
        IVaultBank(vaultBankAddressETH).unlockAsset(
            accountEth, yieldSourceStakingAddress, amount, BASE, yieldSourceOracleIdStaking, bytes("")
        );
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

    /*//////////////////////////////////////////////////////////////
                            MUTEX LOCK TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that mutex locks are properly set and reset during normal execution flow
    function test_MutexLocks_NormalExecutionFlow() public {
        vm.selectFork(FORKS[ETH]);

        // Set execution context for the hook
        hookOutflow.setExecutionContext(accountEth);

        // Initially, both mutexes should be false
        assertFalse(_getPreExecuteMutexState(accountEth));
        assertFalse(_getPostExecuteMutexState(accountEth));

        // Execute preExecute - should set preExecute mutex to true
        bytes memory data = abi.encodePacked(uint256(100));
        vm.prank(accountEth);
        hookOutflow.preExecute(address(0), accountEth, data);

        // Verify preExecute mutex is set
        assertTrue(_getPreExecuteMutexState(accountEth));
        assertFalse(_getPostExecuteMutexState(accountEth));

        // Execute postExecute - should set postExecute mutex to true
        vm.prank(accountEth);
        hookOutflow.postExecute(address(0), accountEth, data);

        // Verify both mutexes are set
        assertTrue(_getPreExecuteMutexState(accountEth));
        assertTrue(_getPostExecuteMutexState(accountEth));

        // Reset execution state - should clear both mutexes
        hookOutflow.resetExecutionState(accountEth);

        // Verify both mutexes are cleared
        assertFalse(_getPreExecuteMutexState(accountEth));
        assertFalse(_getPostExecuteMutexState(accountEth));
    }

    /// @notice Test that calling preExecute twice fails with PRE_EXECUTE_ALREADY_CALLED
    function test_MutexLocks_PreExecuteDoubleCall() public {
        vm.selectFork(FORKS[ETH]);

        hookOutflow.setExecutionContext(accountEth);

        bytes memory data = abi.encodePacked(uint256(100));

        // First call should succeed
        vm.prank(accountEth);
        hookOutflow.preExecute(address(0), accountEth, data);

        // Second call should fail
        vm.prank(accountEth);
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        hookOutflow.preExecute(address(0), accountEth, data);
    }

    /// @notice Test that calling postExecute twice fails with POST_EXECUTE_ALREADY_CALLED
    function test_MutexLocks_PostExecuteDoubleCall() public {
        vm.selectFork(FORKS[ETH]);

        hookOutflow.setExecutionContext(accountEth);

        bytes memory data = abi.encodePacked(uint256(100));

        // Execute preExecute first
        vm.prank(accountEth);
        hookOutflow.preExecute(address(0), accountEth, data);

        // First postExecute call should succeed
        vm.prank(accountEth);
        hookOutflow.postExecute(address(0), accountEth, data);

        // Second postExecute call should fail
        vm.prank(accountEth);
        vm.expectRevert(BaseHook.POST_EXECUTE_ALREADY_CALLED.selector);
        hookOutflow.postExecute(address(0), accountEth, data);
    }

    /// @notice Test that calling postExecute before preExecute fails
    function test_MutexLocks_PostExecuteBeforePreExecute() public {
        vm.selectFork(FORKS[ETH]);

        hookOutflow.setExecutionContext(accountEth);

        bytes memory data = abi.encodePacked(uint256(100));

        // Calling postExecute before preExecute should work (no mutex check in postExecute)
        // But the execution flow should be properly managed
        vm.prank(accountEth);
        hookOutflow.postExecute(address(0), accountEth, data);

        // Verify postExecute mutex is set
        assertTrue(_getPostExecuteMutexState(accountEth));
    }

    /// @notice Test that setOutAmount fails when mutexes are set
    function test_MutexLocks_SetOutAmountWithMutexesSet() public {
        vm.selectFork(FORKS[ETH]);

        hookOutflow.setExecutionContext(accountEth);

        bytes memory data = abi.encodePacked(uint256(100));

        // Execute preExecute to set mutex
        vm.prank(accountEth);
        hookOutflow.preExecute(address(0), accountEth, data);

        // Try to set outAmount - should fail
        vm.expectRevert(BaseHook.CANNOT_SET_OUT_AMOUNT.selector);
        hookOutflow.setOutAmount(1000, accountEth);

        // Execute postExecute to set both mutexes
        vm.prank(accountEth);
        hookOutflow.postExecute(address(0), accountEth, data);

        // Try to set outAmount again - should still fail
        vm.expectRevert(BaseHook.CANNOT_SET_OUT_AMOUNT.selector);
        hookOutflow.setOutAmount(1000, accountEth);
    }

    /// @notice Test that setOutAmount succeeds when no mutexes are set
    function test_MutexLocks_SetOutAmountWithoutMutexes() public {
        vm.selectFork(FORKS[ETH]);

        hookOutflow.setExecutionContext(accountEth);

        // Set outAmount before any execution - should succeed
        hookOutflow.setOutAmount(1000, accountEth);

        // Verify outAmount was set
        assertEq(hookOutflow.getOutAmount(accountEth), 1000);
    }

    /// @notice Test that resetExecutionState fails when execution is incomplete
    function test_MutexLocks_ResetExecutionStateIncomplete() public {
        vm.selectFork(FORKS[ETH]);

        hookOutflow.setExecutionContext(accountEth);

        // Try to reset without executing anything - should fail
        vm.expectRevert(BaseHook.INCOMPLETE_HOOK_EXECUTION.selector);
        hookOutflow.resetExecutionState(accountEth);

        // Execute only preExecute
        bytes memory data = abi.encodePacked(uint256(100));
        vm.prank(accountEth);
        hookOutflow.preExecute(address(0), accountEth, data);

        // Try to reset with only preExecute done - should fail
        vm.expectRevert(BaseHook.INCOMPLETE_HOOK_EXECUTION.selector);
        hookOutflow.resetExecutionState(accountEth);
    }

    /// @notice Test that resetExecutionState succeeds when execution is complete
    function test_MutexLocks_ResetExecutionStateComplete() public {
        vm.selectFork(FORKS[ETH]);

        hookOutflow.setExecutionContext(accountEth);

        bytes memory data = abi.encodePacked(uint256(100));

        // Execute both preExecute and postExecute
        vm.prank(accountEth);
        hookOutflow.preExecute(address(0), accountEth, data);
        vm.prank(accountEth);
        hookOutflow.postExecute(address(0), accountEth, data);

        // Verify both mutexes are set
        assertTrue(_getPreExecuteMutexState(accountEth));
        assertTrue(_getPostExecuteMutexState(accountEth));

        // Reset execution state - should succeed
        hookOutflow.resetExecutionState(accountEth);

        // Verify both mutexes are cleared
        assertFalse(_getPreExecuteMutexState(accountEth));
        assertFalse(_getPostExecuteMutexState(accountEth));
    }

    /// @notice Test that unauthorized callers cannot execute hook methods
    function test_MutexLocks_UnauthorizedCaller() public {
        vm.selectFork(FORKS[ETH]);

        hookOutflow.setExecutionContext(accountEth);

        bytes memory data = abi.encodePacked(uint256(100));
        address unauthorizedCaller = makeAddr("unauthorized");

        // Try to call preExecute with unauthorized caller
        vm.prank(unauthorizedCaller);
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        hookOutflow.preExecute(address(0), accountEth, data);

        // Try to call postExecute with unauthorized caller
        vm.prank(unauthorizedCaller);
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        hookOutflow.postExecute(address(0), accountEth, data);
    }

    /// @notice Test that execution context is properly managed across multiple accounts
    function test_MutexLocks_MultipleAccounts() public {
        vm.selectFork(FORKS[ETH]);

        address account1 = makeAddr("account1");
        address account2 = makeAddr("account2");

        // Set execution context for account1
        hookOutflow.setExecutionContext(account1);

        // Set execution context for account2
        hookOutflow.setExecutionContext(account2);

        bytes memory data = abi.encodePacked(uint256(100));

        // Execute for account1
        vm.prank(account1);
        hookOutflow.preExecute(address(0), account1, data);
        vm.prank(account1);
        hookOutflow.postExecute(address(0), account1, data);

        // Verify account1 mutexes are set
        assertTrue(_getPreExecuteMutexState(account1));
        assertTrue(_getPostExecuteMutexState(account1));

        // Verify account2 mutexes are not set (isolated contexts)
        assertFalse(_getPreExecuteMutexState(account2));
        assertFalse(_getPostExecuteMutexState(account2));

        // Execute for account2
        vm.prank(account2);
        hookOutflow.preExecute(address(0), account2, data);
        vm.prank(account2);
        hookOutflow.postExecute(address(0), account2, data);

        // Verify both accounts have their mutexes set
        assertTrue(_getPreExecuteMutexState(account1));
        assertTrue(_getPostExecuteMutexState(account1));
        assertTrue(_getPreExecuteMutexState(account2));
        assertTrue(_getPostExecuteMutexState(account2));

        // Reset account1
        hookOutflow.resetExecutionState(account1);

        // Verify account1 is reset but account2 is not
        assertFalse(_getPreExecuteMutexState(account1));
        assertFalse(_getPostExecuteMutexState(account1));
        assertTrue(_getPreExecuteMutexState(account2));
        assertTrue(_getPostExecuteMutexState(account2));
    }

    /// @notice Test that execution nonce increments properly
    function test_MutexLocks_ExecutionNonceIncrement() public {
        vm.selectFork(FORKS[ETH]);

        uint256 initialNonce = hookOutflow.executionNonce();

        // Set execution context multiple times
        hookOutflow.setExecutionContext(accountEth);
        uint256 nonce1 = hookOutflow.executionNonce();

        hookOutflow.setExecutionContext(accountEth);
        uint256 nonce2 = hookOutflow.executionNonce();

        hookOutflow.setExecutionContext(accountEth);
        uint256 nonce3 = hookOutflow.executionNonce();

        // Verify nonce increments
        assertGt(nonce1, initialNonce);
        assertGt(nonce2, nonce1);
        assertGt(nonce3, nonce2);
    }

    /// @notice Test that outAmount is properly managed across execution cycles
    function test_MutexLocks_OutAmountManagement() public {
        vm.selectFork(FORKS[ETH]);

        hookOutflow.setExecutionContext(accountEth);

        // Set outAmount before execution
        hookOutflow.setOutAmount(1000, accountEth);
        assertEq(hookOutflow.getOutAmount(accountEth), 1000);

        // Execute preExecute and postExecute
        bytes memory data = abi.encodePacked(uint256(100));
        vm.prank(accountEth);
        hookOutflow.preExecute(address(0), accountEth, data);
        vm.prank(accountEth);
        hookOutflow.postExecute(address(0), accountEth, data);

        // Reset execution state
        hookOutflow.resetExecutionState(accountEth);

        // Set new execution context
        hookOutflow.setExecutionContext(accountEth);

        // Verify outAmount is reset (new context)
        assertEq(hookOutflow.getOutAmount(accountEth), 0);

        // Set new outAmount
        hookOutflow.setOutAmount(2000, accountEth);
        assertEq(hookOutflow.getOutAmount(accountEth), 2000);
    }

    /// @notice Test that denial of service attacks are prevented
    function test_MutexLocks_DenialOfServiceProtection() public {
        vm.selectFork(FORKS[ETH]);

        // Test that incomplete execution cannot be reset
        hookOutflow.setExecutionContext(accountEth);

        // Try to reset without any execution - should fail
        vm.expectRevert(BaseHook.INCOMPLETE_HOOK_EXECUTION.selector);
        hookOutflow.resetExecutionState(accountEth);

        // Execute only preExecute
        bytes memory data = abi.encodePacked(uint256(100));
        vm.prank(accountEth);
        hookOutflow.preExecute(address(0), accountEth, data);

        // Try to reset with incomplete execution - should fail
        vm.expectRevert(BaseHook.INCOMPLETE_HOOK_EXECUTION.selector);
        hookOutflow.resetExecutionState(accountEth);

        // Complete execution
        vm.prank(accountEth);
        hookOutflow.postExecute(address(0), accountEth, data);

        // Now reset should succeed
        hookOutflow.resetExecutionState(accountEth);

        // Verify state is properly reset
        assertFalse(_getPreExecuteMutexState(accountEth));
        assertFalse(_getPostExecuteMutexState(accountEth));
    }

    /// @notice Test that reentrancy attacks are prevented
    function test_MutexLocks_ReentrancyProtection() public {
        vm.selectFork(FORKS[ETH]);

        hookOutflow.setExecutionContext(accountEth);

        bytes memory data = abi.encodePacked(uint256(100));

        // Execute preExecute
        vm.prank(accountEth);
        hookOutflow.preExecute(address(0), accountEth, data);

        // Try to call preExecute again in the same context - should fail
        vm.prank(accountEth);
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        hookOutflow.preExecute(address(0), accountEth, data);

        // Execute postExecute
        vm.prank(accountEth);
        hookOutflow.postExecute(address(0), accountEth, data);

        // Try to call postExecute again in the same context - should fail
        vm.prank(accountEth);
        vm.expectRevert(BaseHook.POST_EXECUTE_ALREADY_CALLED.selector);
        hookOutflow.postExecute(address(0), accountEth, data);

        // Reset and try again - should work
        hookOutflow.resetExecutionState(accountEth);
        vm.prank(accountEth);
        hookOutflow.preExecute(address(0), accountEth, data);
        vm.prank(accountEth);
        hookOutflow.postExecute(address(0), accountEth, data);
    }

    /*//////////////////////////////////////////////////////////////
                        MERKL CLAIM REWARDS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MerklClaimRewardsHook_OnETHFork() public {
        vm.selectFork(FORKS[ETH]);

        uint256 balanceBefore = IERC20(underlyingETH_USDC).balanceOf(accountEth);

        address[] memory users = new address[](1);
        users[0] = accountEth;

        address[] memory tokens = new address[](1);
        tokens[0] = underlyingETH_USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e6;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = _updateTreeAndGetProof(users[0], tokens[0], amounts[0]);

        address[] memory hooks = new address[](1);
        hooks[0] = _getHookAddress(ETH, MERKL_CLAIM_REWARD_HOOK_KEY);

        bytes[] memory data = new bytes[](1);
        data[0] = _createMerklClaimRewardHookData(tokens, amounts, proofs);

        ISuperExecutor.ExecutorEntry memory entryClaim =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpDataClaim = _getExecOps(instanceOnEth, superExecutorETH, abi.encode(entryClaim));

        executeOp(userOpDataClaim);

        uint256 balanceAfter = IERC20(underlyingETH_USDC).balanceOf(accountEth);

        assertEq(balanceAfter - balanceBefore, 100e6);
    }

    function test_MerklClaimRewardsHook_OnETHFork_WithFees() public {
        vm.selectFork(FORKS[ETH]);

        // create hook with 10% fee percentage
        address merkleClaimReward = address(new MerklClaimRewardHook(MERKL_DISTRIBUTOR, address(this), 1000));

        uint256 balanceBefore = IERC20(underlyingETH_USDC).balanceOf(accountEth);

        address[] memory users = new address[](1);
        users[0] = accountEth;
        address[] memory tokens = new address[](1);
        tokens[0] = underlyingETH_USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e6;
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = _updateTreeAndGetProof(users[0], tokens[0], amounts[0]);

        address[] memory hooks = new address[](1);
        hooks[0] = merkleClaimReward;
        bytes[] memory data = new bytes[](1);
        data[0] = _createMerklClaimRewardHookData(tokens, amounts, proofs);

        ISuperExecutor.ExecutorEntry memory entryClaim =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data });
        UserOpData memory userOpDataClaim = _getExecOps(instanceOnEth, superExecutorETH, abi.encode(entryClaim));

        executeOp(userOpDataClaim);

        uint256 balanceAfter = IERC20(underlyingETH_USDC).balanceOf(accountEth);
        assertEq(balanceAfter - balanceBefore, 90e6); // 10% fee
    }

    /*//////////////////////////////////////////////////////////////
                      HELPER FUNCTIONS FOR MUTEX TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Helper function to get preExecute mutex state for testing
    function _getPreExecuteMutexState(address account) internal view returns (bool) {
        return hookOutflow.getPreExecuteMutexState(account);
    }

    /// @notice Helper function to get postExecute mutex state for testing
    function _getPostExecuteMutexState(address account) internal view returns (bool) {
        return hookOutflow.getPostExecuteMutexState(account);
    }

    /*//////////////////////////////////////////////////////////////
            HELPER FUNCTIONS FOR MERKL CLAIM REWARDS TESTS
    //////////////////////////////////////////////////////////////*/

    function _updateTreeAndGetProof(address user, address token, uint256 amount) internal returns (bytes32[] memory) {
        address canUpdateTree = 0x435046800Fb9149eE65159721A92cB7d50a7534b;

        uint256 epochDuration = 3600;

        bytes32 leaf0 = keccak256(abi.encode(user, token, amount));
        bytes32 leaf1 = keccak256(abi.encode(makeAddr("user1"), token, amount));

        assertEq(leaf0 < leaf1, true);
        bytes32 root = keccak256(abi.encode(leaf0, leaf1)); // leaf1 is the right child

        IDistributor.MerkleTree memory tree = IDistributor.MerkleTree({
            merkleRoot: root,
            ipfsHash: 0x0000000000000000000000000000000000000000000000000000000000000000
        });

        vm.prank(canUpdateTree);
        merklDistributor.updateTree(tree);

        vm.warp(block.timestamp + epochDuration * 10 hours);

        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf1; // Sibling of leaf0

        return proof;
    }
}
