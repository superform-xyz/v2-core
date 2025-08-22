// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import { UserOpData } from "modulekit/ModuleKit.sol";
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { IYieldSourceOracle } from "../../../src/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { ERC4626YieldSourceOracle } from "../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol";
import { ERC5115YieldSourceOracle } from "../../../src/accounting/oracles/ERC5115YieldSourceOracle.sol";
import { ERC7540YieldSourceOracle } from "../../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

// -- centrifuge mocks
import { IRoot } from "../../mocks/centrifuge/IRoot.sol";
import { ITranche } from "../../mocks/centrifuge/ITranch.sol";
import { IPoolManager } from "../../mocks/centrifuge/IPoolManager.sol";
import { IInvestmentManager } from "../../mocks/centrifuge/IInvestmentManager.sol";
import { RestrictionManagerLike } from "../../mocks/centrifuge/IRestrictionManagerLike.sol";

contract VaultFeeTests is BaseTest {
    using ModuleKitHelpers for *;
    using ExecutionLib for *;

    IStandardizedYield public vaultInstance5115ETH;
    IERC7540 public vaultInstance7540;
    IERC4626 public vaultInstance4626;

    address public rootManager;
    IRoot public root;
    IPoolManager public poolManager;
    uint64 public poolId;
    bytes16 public trancheId;
    uint128 public assetId;

    RestrictionManagerLike public restrictionManager;
    IInvestmentManager public investmentManager;

    address public underlyingETH_USDC;
    address public underlyingETH_sUSDe;

    address public yieldSource4626AddressUSDC;
    address public yieldSource7540AddressUSDC;
    address public yieldSource5115AddressSUSDe;

    address public accountEth;
    AccountInstance public instanceOnEth;

    SuperLedger public superLedger;
    SuperLedgerConfiguration public config;

    SuperExecutor public superExecutor;
    ISuperExecutor public superExecutorInterface;

    ERC4626YieldSourceOracle public oracle4626;
    ERC5115YieldSourceOracle public oracle5115;
    ERC7540YieldSourceOracle public oracle7540;

    address public manager;
    address public feeRecipient;

    bytes32 public yieldSourceOracleId4626;
    bytes32 public yieldSourceOracleId5115;
    bytes32 public yieldSourceOracleId7540;

    bytes32[] yieldSourceOracleSalts;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        instanceOnEth = accountInstances[ETH];
        accountEth = instanceOnEth.account;

        underlyingETH_USDC = CHAIN_1_USDC;
        underlyingETH_sUSDe = CHAIN_1_SUSDE;

        _getTokens(underlyingETH_USDC, accountEth, 1e16);
        _getTokens(underlyingETH_sUSDe, accountEth, 1e16);

        yieldSource4626AddressUSDC = CHAIN_1_MORPHO_VAULT;
        vaultInstance4626 = IERC4626(yieldSource4626AddressUSDC);

        yieldSource7540AddressUSDC = CHAIN_1_CENTRIFUGE_USDC;
        vaultInstance7540 = IERC7540(yieldSource7540AddressUSDC);

        rootManager = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;

        // ROOT / POOL / TRANCHE SETUP
        address share = IERC7540(yieldSource7540AddressUSDC).share();
        address mngr = ITranche(share).hook();

        restrictionManager = RestrictionManagerLike(mngr);
        vm.startPrank(RestrictionManagerLike(mngr).root());
        restrictionManager.updateMember(share, accountEth, type(uint64).max);
        vm.stopPrank();

        poolId = vaultInstance7540.poolId();
        assertEq(poolId, 4_139_607_887);
        trancheId = vaultInstance7540.trancheId();
        assertEq(trancheId, bytes16(0x97aa65f23e7be09fcd62d0554d2e9273));

        poolManager = IPoolManager(0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29);
        assetId = poolManager.assetToId(underlyingETH_USDC);
        assertEq(assetId, uint128(242_333_941_209_166_991_950_178_742_833_476_896_417));

        yieldSource5115AddressSUSDe = CHAIN_1_PENDLE_ETHENA;
        vaultInstance5115ETH = IStandardizedYield(yieldSource5115AddressSUSDe);

        config = new SuperLedgerConfiguration();
        superExecutor = new SuperExecutor(address(config));
        superExecutorInterface = ISuperExecutor(address(superExecutor));

        address[] memory executors = new address[](1);
        executors[0] = address(superExecutor);

        superLedger = new SuperLedger(address(config), executors);

        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        oracle4626 = new ERC4626YieldSourceOracle(address(superLedger));
        oracle5115 = new ERC5115YieldSourceOracle(address(superLedger));
        oracle7540 = new ERC7540YieldSourceOracle(address(superLedger));

        feeRecipient = makeAddr("feeRecipient");
        manager = makeAddr("manager");

        yieldSourceOracleSalts = new bytes32[](3);
        yieldSourceOracleSalts[0] = bytes32(keccak256("4626_ORACLE_ID"));
        yieldSourceOracleSalts[1] = bytes32(keccak256("5115_ORACLE_ID"));
        yieldSourceOracleSalts[2] = bytes32(keccak256("7540_ORACLE_ID"));

        yieldSourceOracleId4626 = keccak256(abi.encodePacked(yieldSourceOracleSalts[0], manager));
        yieldSourceOracleId5115 = keccak256(abi.encodePacked(yieldSourceOracleSalts[1], manager));
        yieldSourceOracleId7540 = keccak256(abi.encodePacked(yieldSourceOracleSalts[2], manager));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](3);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle4626),
            feePercent: 1000, // 10%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        configs[1] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle5115),
            feePercent: 1000, // 10%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        configs[2] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle7540),
            feePercent: 1000, // 10%
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });

        // Set the oracle configs
        vm.prank(manager);
        config.setYieldSourceOracles(yieldSourceOracleSalts, configs);
    }

    function test_4626VaultFees_FullRedeem() public {
        uint256 depositAmount = 1e16;

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

        uint256 userShares = vaultInstance4626.balanceOf(accountEth);
        uint256 sharesAsAssets = vaultInstance4626.convertToAssets(userShares);

        (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee4626(sharesAsAssets, userShares);

        address[] memory hooksAddressesRedeem = new address[](1);
        hooksAddressesRedeem[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksDataRedeem = new bytes[](1);
        hooksDataRedeem[0] = _createRedeem4626HookData(
            yieldSourceOracleId4626, yieldSource4626AddressUSDC, accountEth, userShares, false
        );

        ISuperExecutor.ExecutorEntry memory entry1 =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
        UserOpData memory userOpData1 = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry1));
        executeOp(userOpData1);

        uint256 userBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(accountEth);
        uint256 feeRecipientBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(feeRecipient);

        assertEq(userBalanceAfter, expectedUserAssets, "User did not receive correct assets after fee");
        assertEq(feeRecipientBalanceAfter, expectedFee, "Fee recipient did not receive correct shares");
    }

    function test_4626VaultFees_PartialRedeem_30Percent() public {
        uint256 depositAmount = 1e16;

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

        uint256 userShares = vaultInstance4626.balanceOf(accountEth);
        uint256 partialShares = (userShares * 30) / 100;
        uint256 sharesAsAssets = vaultInstance4626.convertToAssets(partialShares);

        (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee4626(sharesAsAssets, partialShares);

        address[] memory hooksAddressesRedeem = new address[](1);
        hooksAddressesRedeem[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);

        bytes[] memory hooksDataRedeem = new bytes[](1);
        hooksDataRedeem[0] = _createRedeem4626HookData(
            yieldSourceOracleId4626, yieldSource4626AddressUSDC, accountEth, partialShares, false
        );

        ISuperExecutor.ExecutorEntry memory entry1 =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
        UserOpData memory userOpData1 = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry1));
        executeOp(userOpData1);

        uint256 userBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(accountEth);
        uint256 feeRecipientBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(feeRecipient);

        assertEq(userBalanceAfter, expectedUserAssets, "User did not receive correct assets after fee");
        assertEq(feeRecipientBalanceAfter, expectedFee, "Fee recipient did not receive correct shares");
    }

    function test_4626VaultFees_MultipleSmallRedeems_TotalFeeCorrect() public {
        uint256 depositAmount = 1e16;
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
        uint256 userShares = vaultInstance4626.balanceOf(accountEth);
        uint256 totalRedeemedShares = 0;
        uint256 totalFee = 0;
        uint256 totalUserAssets = 0;
        for (uint256 i = 0; i < 3; i++) {
            uint256 redeemShares = (userShares * 10) / 100;
            uint256 sharesAsAssets = vaultInstance4626.convertToAssets(redeemShares);
            (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee4626(sharesAsAssets, redeemShares);
            address[] memory hooksAddressesRedeem = new address[](1);
            hooksAddressesRedeem[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
            bytes[] memory hooksDataRedeem = new bytes[](1);
            hooksDataRedeem[0] = _createRedeem4626HookData(
                yieldSourceOracleId4626, yieldSource4626AddressUSDC, accountEth, redeemShares, false
            );
            ISuperExecutor.ExecutorEntry memory entry1 =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
            UserOpData memory userOpData1 = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry1));
            executeOp(userOpData1);
            totalRedeemedShares += redeemShares;
            totalFee += expectedFee;
            totalUserAssets += expectedUserAssets;
            userShares -= redeemShares;
        }
        uint256 userBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(accountEth);
        uint256 feeRecipientBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(feeRecipient);
        // Calculate expected fee for total redeemed shares
        uint256 sharesAsAssetsTotal = vaultInstance4626.convertToAssets(totalRedeemedShares);
        (uint256 expectedTotalFee, uint256 expectedTotalUserAssets) =
            _calculateExpectedFee4626(sharesAsAssetsTotal, totalRedeemedShares);
        assertApproxEqAbs(feeRecipientBalanceAfter, expectedTotalFee, 1, "Total fee recipient balance incorrect");
        assertApproxEqAbs(userBalanceAfter, expectedTotalUserAssets, 1, "Total user balance incorrect");
    }

    function _setupFee50Ledger4626()
        internal
        returns (SuperLedgerConfiguration, SuperExecutor, SuperLedger, ERC4626YieldSourceOracle)
    {
        SuperLedgerConfiguration config50 = new SuperLedgerConfiguration();
        SuperExecutor superExecutor50 = new SuperExecutor(address(config50));
        address[] memory executors = new address[](1);
        executors[0] = address(superExecutor50);
        SuperLedger superLedger50 = new SuperLedger(address(config50), executors);
        ERC4626YieldSourceOracle oracle4626_50 = new ERC4626YieldSourceOracle(address(superLedger50));
        yieldSourceOracleSalts = new bytes32[](1);
        yieldSourceOracleSalts[0] = bytes32(keccak256("4626_ORACLE_ID"));
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle4626_50),
            feePercent: 5000, // 50%
            feeRecipient: feeRecipient,
            ledger: address(superLedger50)
        });
        vm.prank(manager);
        config50.setYieldSourceOracles(yieldSourceOracleSalts, configs);
        return (config50, superExecutor50, superLedger50, oracle4626_50);
    }

    function _setupFee50Ledger5115()
        internal
        returns (SuperLedgerConfiguration, SuperExecutor, SuperLedger, ERC5115YieldSourceOracle)
    {
        SuperLedgerConfiguration config50 = new SuperLedgerConfiguration();
        SuperExecutor superExecutor50 = new SuperExecutor(address(config50));
        address[] memory executors = new address[](1);
        executors[0] = address(superExecutor50);
        SuperLedger superLedger50 = new SuperLedger(address(config50), executors);
        ERC5115YieldSourceOracle oracle5115_50 = new ERC5115YieldSourceOracle(address(superLedger50));
        yieldSourceOracleSalts = new bytes32[](1);
        yieldSourceOracleSalts[0] = bytes32(keccak256("5115_ORACLE_ID"));
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle5115_50),
            feePercent: 5000, // 50%
            feeRecipient: feeRecipient,
            ledger: address(superLedger50)
        });
        vm.prank(manager);
        config50.setYieldSourceOracles(yieldSourceOracleSalts, configs);
        return (config50, superExecutor50, superLedger50, oracle5115_50);
    }

    function _setupFee50Ledger7540()
        internal
        returns (SuperLedgerConfiguration, SuperExecutor, SuperLedger, ERC7540YieldSourceOracle)
    {
        SuperLedgerConfiguration config50 = new SuperLedgerConfiguration();
        SuperExecutor superExecutor50 = new SuperExecutor(address(config50));
        address[] memory executors = new address[](1);
        executors[0] = address(superExecutor50);
        SuperLedger superLedger50 = new SuperLedger(address(config50), executors);
        ERC7540YieldSourceOracle oracle7540_50 = new ERC7540YieldSourceOracle(address(superLedger50));
        yieldSourceOracleSalts = new bytes32[](1);
        yieldSourceOracleSalts[0] = bytes32(keccak256("7540_ORACLE_ID"));
        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory configs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        configs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle7540_50),
            feePercent: 5000, // 50%
            feeRecipient: feeRecipient,
            ledger: address(superLedger50)
        });
        vm.prank(manager);
        config50.setYieldSourceOracles(yieldSourceOracleSalts, configs);
        return (config50, superExecutor50, superLedger50, oracle7540_50);
    }

    function _deposit4626(SuperExecutor superExecutor50) internal {
        uint256 depositAmount = 1e16;
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
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor50, abi.encode(entry));
        executeOp(userOpData);
    }

    function _redeem4626(SuperExecutor superExecutor50, SuperLedger superLedger50) internal {
        uint256 userShares = vaultInstance4626.balanceOf(accountEth);
        uint256 sharesAsAssets = vaultInstance4626.convertToAssets(userShares);

        SuperLedgerConfiguration.YieldSourceOracleConfig memory oracleConfig = config.getYieldSourceOracleConfig(yieldSourceOracleId4626);
        uint256 pps = IYieldSourceOracle(oracleConfig.yieldSourceOracle).getPricePerShare(yieldSource4626AddressUSDC);
        uint8 decimals = IYieldSourceOracle(oracleConfig.yieldSourceOracle).decimals(yieldSource4626AddressUSDC);
        uint256 expectedFee =
            superLedger50.previewFees(accountEth, yieldSource4626AddressUSDC, sharesAsAssets, userShares, 5000, pps, decimals);
        uint256 expectedUserAssets = sharesAsAssets - expectedFee;
        address[] memory hooksAddressesRedeem = new address[](1);
        hooksAddressesRedeem[0] = _getHookAddress(ETH, REDEEM_4626_VAULT_HOOK_KEY);
        bytes[] memory hooksDataRedeem = new bytes[](1);
        hooksDataRedeem[0] = _createRedeem4626HookData(
            yieldSourceOracleId4626, yieldSource4626AddressUSDC, accountEth, userShares, false
        );
        ISuperExecutor.ExecutorEntry memory entry1 =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
        UserOpData memory userOpData1 = _getExecOps(instanceOnEth, superExecutor50, abi.encode(entry1));
        executeOp(userOpData1);
        uint256 userBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(accountEth);
        uint256 feeRecipientBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(feeRecipient);
        assertEq(userBalanceAfter, expectedUserAssets, "User did not receive correct assets after fee");
        assertEq(feeRecipientBalanceAfter, expectedFee, "Fee recipient did not receive correct shares");
    }

    function _depositAndRedeem4626(SuperExecutor superExecutor50, SuperLedger superLedger50) internal {
        _deposit4626(superExecutor50);
        _redeem4626(superExecutor50, superLedger50);
    }

    function _deposit5115(SuperExecutor superExecutor50) internal {
        uint256 depositAmount = 1e16;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, DEPOSIT_5115_VAULT_HOOK_KEY);
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingETH_sUSDe, yieldSource5115AddressSUSDe, depositAmount, false);
        hooksData[1] = _createDeposit5115VaultHookData(
            yieldSourceOracleId5115,
            yieldSource5115AddressSUSDe,
            underlyingETH_sUSDe,
            depositAmount,
            0,
            false,
            address(0),
            0
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor50, abi.encode(entry));
        executeOp(userOpData);
    }

    function _redeem5115(SuperExecutor superExecutor50, SuperLedger superLedger50) internal {
        uint256 userShares = vaultInstance5115ETH.balanceOf(accountEth);
        uint256 sharesAsAssets = vaultInstance5115ETH.previewRedeem(underlyingETH_sUSDe, userShares);

        SuperLedgerConfiguration.YieldSourceOracleConfig memory oracleConfig = config.getYieldSourceOracleConfig(yieldSourceOracleId5115);
        uint256 pps = IYieldSourceOracle(oracleConfig.yieldSourceOracle).getPricePerShare(yieldSource5115AddressSUSDe);
        uint8 decimals = IYieldSourceOracle(oracleConfig.yieldSourceOracle).decimals(yieldSource5115AddressSUSDe);
        uint256 expectedFee =
            superLedger50.previewFees(accountEth, yieldSource5115AddressSUSDe, sharesAsAssets, userShares, 5000, pps, decimals);
        uint256 expectedUserAssets = sharesAsAssets - expectedFee;
        address[] memory hooksAddressesRedeem = new address[](1);
        hooksAddressesRedeem[0] = _getHookAddress(ETH, REDEEM_5115_VAULT_HOOK_KEY);
        bytes[] memory hooksDataRedeem = new bytes[](1);
        hooksDataRedeem[0] = _create5115RedeemHookData(
            yieldSourceOracleId5115, yieldSource5115AddressSUSDe, underlyingETH_sUSDe, userShares, 0, false
        );
        ISuperExecutor.ExecutorEntry memory entry1 =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesRedeem, hooksData: hooksDataRedeem });
        UserOpData memory userOpData1 = _getExecOps(instanceOnEth, superExecutor50, abi.encode(entry1));
        executeOp(userOpData1);
        uint256 userBalanceAfter = IERC20(underlyingETH_sUSDe).balanceOf(accountEth);
        uint256 feeRecipientBalanceAfter = IERC20(underlyingETH_sUSDe).balanceOf(feeRecipient);
        assertEq(userBalanceAfter, expectedUserAssets, "User did not receive correct assets after fee");
        assertEq(feeRecipientBalanceAfter, expectedFee, "Fee recipient did not receive correct shares");
    }

    function _depositAndRedeem5115(SuperExecutor superExecutor50, SuperLedger superLedger50) internal {
        _deposit5115(superExecutor50);
        _redeem5115(superExecutor50, superLedger50);
    }

    function _deposit7540(SuperExecutor superExecutor50) internal {
        uint256 depositAmount = 1e16;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSource7540AddressUSDC, depositAmount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            yieldSourceOracleId7540, yieldSource7540AddressUSDC, depositAmount, true
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor50, abi.encode(entry));
        executeOp(userOpData);
    }

    function _fulfillDeposit7540(SuperExecutor superExecutor50, uint256 maxDeposit) internal {
        address[] memory hooksAddressesDeposit = new address[](1);
        hooksAddressesDeposit[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksDataDeposit = new bytes[](1);
        hooksDataDeposit[0] = _createDeposit7540VaultHookData(
            yieldSourceOracleId7540, yieldSource7540AddressUSDC, maxDeposit, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entryDeposit =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesDeposit, hooksData: hooksDataDeposit });
        UserOpData memory userOpDataDeposit = _getExecOps(instanceOnEth, superExecutor50, abi.encode(entryDeposit));
        executeOp(userOpDataDeposit);
    }

    function _redeem7540(SuperExecutor superExecutor50, SuperLedger superLedger50) internal {
        uint256 userShares = IERC20(vaultInstance7540.share()).balanceOf(accountEth);
        vm.prank(accountEth);
        IERC7540(yieldSource7540AddressUSDC).requestRedeem(userShares, accountEth, accountEth);
        uint256 userExpectedAssets = vaultInstance7540.convertToAssets(userShares);
        vm.prank(rootManager);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountEth, assetId, uint128(userExpectedAssets), uint128(userShares)
        );
        uint256 maxRedeemAmount = vaultInstance7540.maxRedeem(accountEth);
        uint256 sharesAsAssets = vaultInstance7540.convertToAssets(maxRedeemAmount);

        SuperLedgerConfiguration.YieldSourceOracleConfig memory oracleConfig = config.getYieldSourceOracleConfig(yieldSourceOracleSalts[2]);
        uint256 pps = IYieldSourceOracle(oracleConfig.yieldSourceOracle).getPricePerShare(yieldSource7540AddressUSDC);
        uint8 decimals = IYieldSourceOracle(oracleConfig.yieldSourceOracle).decimals(yieldSource7540AddressUSDC);
        uint256 expectedFee =
            superLedger50.previewFees(accountEth, yieldSource7540AddressUSDC, sharesAsAssets, userShares, 5000, pps, decimals);
        uint256 expectedUserAssets = sharesAsAssets - expectedFee;
        address[] memory hooksAddressesWithdraw = new address[](1);
        hooksAddressesWithdraw[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);
        bytes[] memory hooksDataWithdraw = new bytes[](1);
        hooksDataWithdraw[0] =
            _createWithdraw7540VaultHookData(yieldSourceOracleId7540, yieldSource7540AddressUSDC, sharesAsAssets, false);
        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesWithdraw, hooksData: hooksDataWithdraw });
        UserOpData memory userOpDataWithdraw = _getExecOps(instanceOnEth, superExecutor50, abi.encode(entryWithdraw));
        executeOp(userOpDataWithdraw);
        uint256 userBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(accountEth);
        uint256 feeRecipientBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(feeRecipient);
        assertEq(userBalanceAfter, expectedUserAssets, "User did not receive correct assets after fee");
        assertEq(feeRecipientBalanceAfter, expectedFee, "Fee recipient did not receive correct shares");
    }

    function _depositAndRedeem7540(SuperExecutor superExecutor50, SuperLedger superLedger50) internal {
        _deposit7540(superExecutor50);
        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);
        vm.startPrank(rootManager);
        uint256 depositAmount = 1e16;
        uint256 userExpectedShares = vaultInstance7540.convertToShares(depositAmount);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, accountEth, assetId, uint128(depositAmount), uint128(userExpectedShares)
        );
        uint256 maxDeposit = vaultInstance7540.maxDeposit(accountEth);
        userExpectedShares = vaultInstance7540.convertToShares(maxDeposit);
        vm.stopPrank();
        _fulfillDeposit7540(superExecutor50, maxDeposit);
        _redeem7540(superExecutor50, superLedger50);
    }

    function test_4626VaultFees_FullRedeem_Fee50Percent() public {
        (, SuperExecutor superExecutor50, SuperLedger superLedger50,) = _setupFee50Ledger4626();
        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor50), data: "" });
        _depositAndRedeem4626(superExecutor50, superLedger50);
    }

    function test_5115VaultFees_FullRedeem_Fee50Percent() public {
        (, SuperExecutor superExecutor50, SuperLedger superLedger50,) = _setupFee50Ledger5115();
        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor50), data: "" });
        _depositAndRedeem5115(superExecutor50, superLedger50);
    }

    function test_7540VaultFees_FullRedeem() public {
        uint256 depositAmount = 1e16;

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSource7540AddressUSDC, depositAmount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            yieldSourceOracleId7540, yieldSource7540AddressUSDC, depositAmount, true
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);

        vm.startPrank(rootManager);

        uint256 userExpectedShares = vaultInstance7540.convertToShares(depositAmount);

        investmentManager.fulfillDepositRequest(
            poolId, trancheId, accountEth, assetId, uint128(depositAmount), uint128(userExpectedShares)
        );

        uint256 maxDeposit = vaultInstance7540.maxDeposit(accountEth);
        userExpectedShares = vaultInstance7540.convertToShares(maxDeposit);

        vm.stopPrank();

        address[] memory hooksAddressesDeposit = new address[](1);
        hooksAddressesDeposit[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksDataDeposit = new bytes[](1);
        hooksDataDeposit[0] = _createDeposit7540VaultHookData(
            yieldSourceOracleId7540, yieldSource7540AddressUSDC, maxDeposit, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entryDeposit =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesDeposit, hooksData: hooksDataDeposit });
        UserOpData memory userOpDataDeposit = _getExecOps(instanceOnEth, superExecutor, abi.encode(entryDeposit));
        executeOp(userOpDataDeposit);

        // 7540 vaults use .share() for the share token
        uint256 userShares = IERC20(vaultInstance7540.share()).balanceOf(accountEth);

        vm.prank(accountEth);
        IERC7540(yieldSource7540AddressUSDC).requestRedeem(userShares, accountEth, accountEth);

        uint256 userExpectedAssets = vaultInstance7540.convertToAssets(userShares);

        // FULFILL REDEEM
        vm.prank(rootManager);

        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountEth, assetId, uint128(userExpectedAssets), uint128(userShares)
        );

        uint256 maxRedeemAmount = vaultInstance7540.maxRedeem(accountEth);

        uint256 sharesAsAssets = vaultInstance7540.convertToAssets(maxRedeemAmount);

        (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee7540(sharesAsAssets, userShares);

        address[] memory hooksAddressesWithdraw = new address[](1);
        hooksAddressesWithdraw[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksDataWithdraw = new bytes[](1);
        hooksDataWithdraw[0] =
            _createWithdraw7540VaultHookData(yieldSourceOracleId7540, yieldSource7540AddressUSDC, sharesAsAssets, false);

        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesWithdraw, hooksData: hooksDataWithdraw });
        UserOpData memory userOpDataWithdraw = _getExecOps(instanceOnEth, superExecutor, abi.encode(entryWithdraw));
        executeOp(userOpDataWithdraw);

        uint256 userBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(accountEth);
        uint256 feeRecipientBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(feeRecipient);

        assertEq(userBalanceAfter, expectedUserAssets, "User did not receive correct assets after fee");
        assertEq(feeRecipientBalanceAfter, expectedFee, "Fee recipient did not receive correct shares");
    }

    function test_7540VaultFees_PartialRedeem_30Percent() public {
        uint256 depositAmount = 1e16;

        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSource7540AddressUSDC, depositAmount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            yieldSourceOracleId7540, yieldSource7540AddressUSDC, depositAmount, true
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry));
        executeOp(userOpData);

        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);

        vm.startPrank(rootManager);

        uint256 userExpectedShares = vaultInstance7540.convertToShares(depositAmount);

        investmentManager.fulfillDepositRequest(
            poolId, trancheId, accountEth, assetId, uint128(depositAmount), uint128(userExpectedShares)
        );

        uint256 maxDeposit = vaultInstance7540.maxDeposit(accountEth);
        userExpectedShares = vaultInstance7540.convertToShares(maxDeposit);

        vm.stopPrank();

        address[] memory hooksAddressesDeposit = new address[](1);
        hooksAddressesDeposit[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksDataDeposit = new bytes[](1);
        hooksDataDeposit[0] = _createDeposit7540VaultHookData(
            yieldSourceOracleId7540, yieldSource7540AddressUSDC, maxDeposit, false, address(0), 0
        );

        ISuperExecutor.ExecutorEntry memory entryDeposit =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesDeposit, hooksData: hooksDataDeposit });
        UserOpData memory userOpDataDeposit = _getExecOps(instanceOnEth, superExecutor, abi.encode(entryDeposit));
        executeOp(userOpDataDeposit);

        uint256 userShares = IERC20(vaultInstance7540.share()).balanceOf(accountEth);
        uint256 partialShares = (userShares * 30) / 100;

        vm.prank(accountEth);
        IERC7540(yieldSource7540AddressUSDC).requestRedeem(partialShares, accountEth, accountEth);

        uint256 userExpectedAssets = vaultInstance7540.convertToAssets(partialShares);

        // FULFILL REDEEM
        vm.prank(rootManager);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountEth, assetId, uint128(userExpectedAssets), uint128(partialShares)
        );

        uint256 maxRedeemAmount = vaultInstance7540.maxRedeem(accountEth);
        uint256 sharesAsAssets = vaultInstance7540.convertToAssets(maxRedeemAmount);

        (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee7540(sharesAsAssets, partialShares);

        address[] memory hooksAddressesWithdraw = new address[](1);
        hooksAddressesWithdraw[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksDataWithdraw = new bytes[](1);
        hooksDataWithdraw[0] =
            _createWithdraw7540VaultHookData(yieldSourceOracleId7540, yieldSource7540AddressUSDC, sharesAsAssets, false);

        ISuperExecutor.ExecutorEntry memory entryWithdraw =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesWithdraw, hooksData: hooksDataWithdraw });
        UserOpData memory userOpDataWithdraw = _getExecOps(instanceOnEth, superExecutor, abi.encode(entryWithdraw));
        executeOp(userOpDataWithdraw);

        uint256 userBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(accountEth);
        uint256 feeRecipientBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(feeRecipient);

        assertEq(userBalanceAfter, expectedUserAssets, "User did not receive correct assets after fee");
        assertEq(feeRecipientBalanceAfter, expectedFee, "Fee recipient did not receive correct shares");
    }

    function test_7540VaultFees_MultipleSmallRedeems_TotalFeeCorrect() public {
        uint256 depositAmount = 1e16;
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(underlyingETH_USDC, yieldSource7540AddressUSDC, depositAmount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(
            yieldSourceOracleId7540, yieldSource7540AddressUSDC, depositAmount, true
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry));
        executeOp(userOpData);
        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);
        vm.startPrank(rootManager);
        uint256 userExpectedShares = vaultInstance7540.convertToShares(depositAmount);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, accountEth, assetId, uint128(depositAmount), uint128(userExpectedShares)
        );
        uint256 maxDeposit = vaultInstance7540.maxDeposit(accountEth);
        userExpectedShares = vaultInstance7540.convertToShares(maxDeposit);
        vm.stopPrank();
        address[] memory hooksAddressesDeposit = new address[](1);
        hooksAddressesDeposit[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);
        bytes[] memory hooksDataDeposit = new bytes[](1);
        hooksDataDeposit[0] = _createDeposit7540VaultHookData(
            yieldSourceOracleId7540, yieldSource7540AddressUSDC, maxDeposit, false, address(0), 0
        );
        ISuperExecutor.ExecutorEntry memory entryDeposit =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesDeposit, hooksData: hooksDataDeposit });
        UserOpData memory userOpDataDeposit = _getExecOps(instanceOnEth, superExecutor, abi.encode(entryDeposit));
        executeOp(userOpDataDeposit);
        uint256 userShares = IERC20(vaultInstance7540.share()).balanceOf(accountEth);
        uint256 totalRedeemedShares = 0;
        uint256 totalFee = 0;
        uint256 totalUserAssets = 0;
        for (uint256 i = 0; i < 3; i++) {
            uint256 redeemShares = (userShares * 10) / 100;
            vm.prank(accountEth);
            IERC7540(yieldSource7540AddressUSDC).requestRedeem(redeemShares, accountEth, accountEth);
            uint256 userExpectedAssets = vaultInstance7540.convertToAssets(redeemShares);
            vm.prank(rootManager);
            investmentManager.fulfillRedeemRequest(
                poolId, trancheId, accountEth, assetId, uint128(userExpectedAssets), uint128(redeemShares)
            );
            uint256 maxRedeemAmount = vaultInstance7540.maxRedeem(accountEth);
            uint256 sharesAsAssets = vaultInstance7540.convertToAssets(maxRedeemAmount);
            (uint256 expectedFee, uint256 expectedUserAssets) = _calculateExpectedFee7540(sharesAsAssets, redeemShares);
            address[] memory hooksAddressesWithdraw = new address[](1);
            hooksAddressesWithdraw[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);
            bytes[] memory hooksDataWithdraw = new bytes[](1);
            hooksDataWithdraw[0] = _createWithdraw7540VaultHookData(
                yieldSourceOracleId7540, yieldSource7540AddressUSDC, sharesAsAssets, false
            );
            ISuperExecutor.ExecutorEntry memory entryWithdraw =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddressesWithdraw, hooksData: hooksDataWithdraw });
            UserOpData memory userOpDataWithdraw = _getExecOps(instanceOnEth, superExecutor, abi.encode(entryWithdraw));
            executeOp(userOpDataWithdraw);
            totalRedeemedShares += redeemShares;
            totalFee += expectedFee;
            totalUserAssets += expectedUserAssets;
            userShares -= redeemShares;
        }
        uint256 userBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(accountEth);
        uint256 feeRecipientBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(feeRecipient);
        uint256 sharesAsAssetsTotal = vaultInstance7540.convertToAssets(totalRedeemedShares);
        (uint256 expectedTotalFee, uint256 expectedTotalUserAssets) =
            _calculateExpectedFee7540(sharesAsAssetsTotal, totalRedeemedShares);
        assertApproxEqAbs(feeRecipientBalanceAfter, expectedTotalFee, 2, "Total fee recipient balance incorrect");
        assertApproxEqAbs(userBalanceAfter, expectedTotalUserAssets, 1, "Total user balance incorrect");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _calculateExpectedFee4626(
        uint256 sharesAsAssets,
        uint256 userShares
    )
        internal
        view
        returns (uint256 expectedFee, uint256 expectedUserAssets)
    {
        SuperLedgerConfiguration.YieldSourceOracleConfig memory oracleConfig = config.getYieldSourceOracleConfig(yieldSourceOracleId4626);
        uint256 pps = IYieldSourceOracle(oracleConfig.yieldSourceOracle).getPricePerShare(yieldSource4626AddressUSDC);
        uint8 decimals = IYieldSourceOracle(oracleConfig.yieldSourceOracle).decimals(yieldSource4626AddressUSDC);
        expectedFee = superLedger.previewFees(accountEth, yieldSource4626AddressUSDC, sharesAsAssets, userShares, 1000, pps, decimals);
        expectedUserAssets = sharesAsAssets - expectedFee;
    }

    function _calculateExpectedFee5115(
        uint256 sharesAsAssets,
        uint256 userShares
    )
        internal
        view
        returns (uint256 expectedFee, uint256 expectedUserAssets)
    {
        SuperLedgerConfiguration.YieldSourceOracleConfig memory oracleConfig = config.getYieldSourceOracleConfig(yieldSourceOracleId5115);
        uint256 pps = IYieldSourceOracle(oracleConfig.yieldSourceOracle).getPricePerShare(yieldSource5115AddressSUSDe);
        uint8 decimals = IYieldSourceOracle(oracleConfig.yieldSourceOracle).decimals(yieldSource5115AddressSUSDe);
        expectedFee = superLedger.previewFees(accountEth, yieldSource5115AddressSUSDe, sharesAsAssets, userShares, 1000, pps, decimals);
        expectedUserAssets = sharesAsAssets - expectedFee;
    }

    function _calculateExpectedFee7540(
        uint256 sharesAsAssets,
        uint256 userShares
    )
        internal
        view
        returns (uint256 expectedFee, uint256 expectedUserAssets)
    {
        SuperLedgerConfiguration.YieldSourceOracleConfig memory oracleConfig = config.getYieldSourceOracleConfig(yieldSourceOracleId7540);
        uint256 pps = IYieldSourceOracle(oracleConfig.yieldSourceOracle).getPricePerShare(yieldSource7540AddressUSDC);
        uint8 decimals = IYieldSourceOracle(oracleConfig.yieldSourceOracle).decimals(yieldSource7540AddressUSDC);
        expectedFee = superLedger.previewFees(accountEth, yieldSource7540AddressUSDC, sharesAsAssets, userShares, 1000, pps, decimals);
        expectedUserAssets = sharesAsAssets - expectedFee;
    }
}
