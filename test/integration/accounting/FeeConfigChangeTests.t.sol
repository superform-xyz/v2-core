// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

contract FeeConfigChangeTests is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    address public underlying;

    IERC4626 public vaultInstance;
    address public yieldSourceAddress;

    SuperLedgerConfiguration public configSuperLedger;

    SuperLedger public superLedger;
    ISuperExecutor public superExecutor;

    AccountInstance public instanceOnEth;
    address public accountEth;

    address public executor1;
    address public executor2;
    address public manager;
    address public feeRecipient;

    // Use a constant salt and a derived ID
    bytes32 internal constant TEST_ORACLE_SALT = bytes32(keccak256("TEST_ORACLE_ID"));
    bytes32 public yieldSourceOracleId;
    ERC4626YieldSourceOracle public oracle;

    address public oracleAddress;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        accountEth = accountInstances[ETH].account;
        instanceOnEth = accountInstances[ETH];

        executor1 = makeAddr("executor1");
        executor2 = makeAddr("executor2");
        manager = makeAddr("manager");
        feeRecipient = makeAddr("feeRecipient");

        underlying = CHAIN_1_USDC;

        yieldSourceAddress = CHAIN_1_MorphoVault;
        vaultInstance = IERC4626(yieldSourceAddress);

        configSuperLedger = new SuperLedgerConfiguration();
        superExecutor = new SuperExecutor(address(configSuperLedger));

        // Deploy your own SuperExecutor and SuperLedger
        // (deploy executor first so you can add it to allowedExecutors)
        address[] memory allowedExecutors = new address[](1);
        allowedExecutors[0] = address(superExecutor);
        superLedger = new SuperLedger(address(configSuperLedger), allowedExecutors);

        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        // Derive the ID with the manager
        yieldSourceOracleId = keccak256(abi.encodePacked(TEST_ORACLE_SALT, manager));

        bytes32[] memory yieldSourceOracleSalts = new bytes32[](1);
        yieldSourceOracleSalts[0] = TEST_ORACLE_SALT;

        oracleAddress = _getContract(ETH, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        oracle = ERC4626YieldSourceOracle(oracleAddress);

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: oracleAddress,
            feePercent: 0,
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        vm.prank(manager);
        configSuperLedger.setYieldSourceOracles(yieldSourceOracleSalts, configs);
    }

    function test_FeeConfigChange_FromZero() public {
        // User deposits with fee = 0
        uint256 depositAmount = 1e16;

        _getTokens(underlying, accountEth, depositAmount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, depositAmount, false);
        hooksData[1] = _createDeposit4626HookData(
            yieldSourceOracleId, 
            yieldSourceAddress,
            depositAmount,
            false,
            address(0),
            0
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        // Propose and accept a new config with fee = 2000 (20%)
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 2000, // 20%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = yieldSourceOracleId;
        vm.prank(manager);
        configSuperLedger.proposeYieldSourceOracleConfig(ids, configs);

        // Fast forward timelock
        vm.warp(block.timestamp + 1 weeks);
        vm.prank(manager);
        configSuperLedger.acceptYieldSourceOracleConfigProposal(ids);

        // User redeems all shares
        uint256 feeRecipientBalanceBefore = IERC20(underlying).balanceOf(feeRecipient);

        uint256 userShares = vaultInstance.balanceOf(accountEth);
        uint256 sharesAsAssets = vaultInstance.convertToAssets(userShares);

        (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee20Percent(sharesAsAssets, userShares);

        address[] memory hooksAddressesRedeem = new address[](1);
        hooksAddressesRedeem[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksDataRedeem = new bytes[](1);
        hooksDataRedeem[0] =
            _createRedeem4626HookData(yieldSourceOracleId, yieldSourceAddress, accountEth, userShares, false);

        ISuperExecutor.ExecutorEntry memory entry1 =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
        UserOpData memory userOpData1 = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry1));
        executeOp(userOpData1);

        uint256 userBalanceAfter = IERC20(underlying).balanceOf(accountEth);

        assertEq(userBalanceAfter, expectedUserAssets, "User did not receive correct assets after fee");
        uint256 feeRecipientBalance = IERC20(underlying).balanceOf(feeRecipient) - feeRecipientBalanceBefore;
        assertEq(feeRecipientBalance, expectedFee, "Fee recipient did not receive correct shares");
    }

    function test_FeeConfigChange_From10Percent() public {
        // Propose and accept a new config with fee = 1000 (10%)
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs1 =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs1[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 1000, // 10%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        bytes32[] memory ids1 = new bytes32[](1);
        ids1[0] = yieldSourceOracleId;
        vm.prank(manager);
        configSuperLedger.proposeYieldSourceOracleConfig(ids1, configs1);

        // Fast forward timelock
        vm.warp(block.timestamp + 1 weeks);
        vm.prank(manager);
        configSuperLedger.acceptYieldSourceOracleConfigProposal(ids1);

        // User deposits with fee = 10%
        uint256 depositAmount = 1e16;

        _getTokens(underlying, accountEth, depositAmount);

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlying, yieldSourceAddress, depositAmount, false);
        hooksData[1] =
            _createDeposit4626HookData(yieldSourceOracleId, yieldSourceAddress, depositAmount, false, address(0), 0);

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        vm.warp(block.timestamp + 1 weeks);

        // Propose and accept a new config with fee = 1200 (12%)
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle),
            feePercent: 1200, // 12%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = yieldSourceOracleId;
        vm.prank(manager);
        configSuperLedger.proposeYieldSourceOracleConfig(ids, configs);

        // Fast forward timelock
        vm.warp(block.timestamp + 1 weeks);
        vm.prank(manager);
        configSuperLedger.acceptYieldSourceOracleConfigProposal(ids);

        // User redeems all shares
        uint256 feeRecipientBalanceBefore = IERC20(underlying).balanceOf(feeRecipient);
        uint256 userShares = vaultInstance.balanceOf(accountEth);
        uint256 sharesAsAssets = vaultInstance.convertToAssets(userShares);

        (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee(sharesAsAssets, userShares);

        address[] memory hooksAddressesRedeem = new address[](1);
        hooksAddressesRedeem[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksDataRedeem = new bytes[](1);
        hooksDataRedeem[0] =
            _createRedeem4626HookData(yieldSourceOracleId, yieldSourceAddress, accountEth, userShares, false);

        ISuperExecutor.ExecutorEntry memory entry1 =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
        UserOpData memory userOpData1 = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry1));
        executeOp(userOpData1);

        uint256 userBalanceAfter = IERC20(underlying).balanceOf(accountEth);
        uint256 feeRecipientBalanceAfter = IERC20(underlying).balanceOf(feeRecipient);

        assertEq(userBalanceAfter, expectedUserAssets, "User did not receive correct assets after fee");
        uint256 feeRecipientBalance = feeRecipientBalanceAfter - feeRecipientBalanceBefore;
        assertEq(feeRecipientBalance, expectedFee, "Fee recipient did not receive correct shares");
    }

    function _calculateExpectedFee(uint256 sharesAsAssets, uint256 userShares)
        internal
        view
        returns (uint256 expectedFee, uint256 expectedUserAssets)
    {
        expectedFee = superLedger.previewFees(accountEth, yieldSourceAddress, sharesAsAssets, userShares, 1200);
        expectedUserAssets = sharesAsAssets - expectedFee;
    }

    function _calculateExpectedFee20Percent(uint256 sharesAsAssets, uint256 userShares)
        internal
        view
        returns (uint256 expectedFee, uint256 expectedUserAssets)
    {
        expectedFee = superLedger.previewFees(accountEth, yieldSourceAddress, sharesAsAssets, userShares, 2000);
        expectedUserAssets = sharesAsAssets - expectedFee;
    }
}
