// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/core/interfaces/ISuperExecutor.sol";
import { IYieldSourceOracle } from "../../src/core/interfaces/accounting/IYieldSourceOracle.sol";
import { ISuperLedger } from "../../src/core/interfaces/accounting/ISuperLedger.sol";

// Vault Interfaces
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";
import { RestrictionManagerLike } from "../mocks/centrifuge/IRestrictionManagerLike.sol";
import { IRestrictionManager } from "../mocks/centrifuge/IRestrictionManager.sol";
import { IInvestmentManager } from "../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../mocks/centrifuge/IPoolManager.sol";
import { ITranche } from "../mocks/centrifuge/ITranch.sol";
import { IRoot } from "../mocks/centrifuge/IRoot.sol";

// External
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract BridgeToMultiVaultDepositAndRedeemFlow is BaseTest {
    IERC7540 public vaultInstance7540ETH;
    IERC4626 public vaultInstance4626OP;

    address public underlyingETH_USDC;
    address public underlyingOP_USDCe;

    address public underlyingBase_USDC;

    address public addressOracleOP;
    address public addressOracleETH;
    address public addressOracleBase;

    address public yieldSource7540AddressETH_USDC;
    address public yieldSource4626AddressOP_USDCe;

    address public accountBase;
    address public accountETH;
    address public accountOP;

    AccountInstance public instanceOnBase;
    AccountInstance public instanceOnETH;
    AccountInstance public instanceOnOP;

    ISuperExecutor public superExecutorOnBase;
    ISuperExecutor public superExecutorOnETH;
    ISuperExecutor public superExecutorOnOP;

    IRoot public root;
    IPoolManager public poolManager;

    ISuperLedger public superLedgerETH;
    ISuperLedger public superLedgerOP;

    IYieldSourceOracle public yieldSourceOracleETH;
    IYieldSourceOracle public yieldSourceOracleOP;

    RestrictionManagerLike public restrictionManager;
    IInvestmentManager public investmentManager;

    uint256 public balance_Base_USDC_Before;

    uint64 public poolId;
    bytes16 public trancheId;
    uint128 public assetId;

    string public constant YIELD_SOURCE_7540_ETH_USDC_KEY = "Centrifuge_7540_ETH_USDC";
    string public constant YIELD_SOURCE_ORACLE_7540_KEY = "YieldSourceOracle_7540";

    string public constant YIELD_SOURCE_4626_OP_USDCe_KEY = "YieldSource_4626_OP_USDCe";
    string public constant YIELD_SOURCE_ORACLE_4626_KEY = "YieldSourceOracle_4626";

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        _overrideSuperLedger();

        // Set up the underlying tokens
        underlyingBase_USDC = existingUnderlyingTokens[BASE][USDC_KEY];
        underlyingETH_USDC = existingUnderlyingTokens[ETH][USDC_KEY];
        underlyingOP_USDCe = existingUnderlyingTokens[OP][USDCe_KEY];

        // Set up the 7540 yield source
        yieldSource7540AddressETH_USDC =
            realVaultAddresses[ETH][ERC7540FullyAsync_KEY][CENTRIFUGE_USDC_VAULT_KEY][USDC_KEY];
        vm.label(yieldSource7540AddressETH_USDC, YIELD_SOURCE_7540_ETH_USDC_KEY);

        vaultInstance7540ETH = IERC7540(yieldSource7540AddressETH_USDC);

        addressOracleETH = _getContract(ETH, ERC7540_YIELD_SOURCE_ORACLE_KEY);
        vm.label(addressOracleETH, YIELD_SOURCE_ORACLE_7540_KEY);
        yieldSourceOracleETH = IYieldSourceOracle(addressOracleETH);

        // Set up the 4626 yield source
        yieldSource4626AddressOP_USDCe = realVaultAddresses[OP][ERC4626_VAULT_KEY][ALOE_USDC_VAULT_KEY][USDCe_KEY];

        vaultInstance4626OP = IERC4626(yieldSource4626AddressOP_USDCe);
        vm.label(yieldSource4626AddressOP_USDCe, YIELD_SOURCE_4626_OP_USDCe_KEY);

        addressOracleOP = _getContract(OP, ERC4626_YIELD_SOURCE_ORACLE_KEY);
        vm.label(addressOracleOP, YIELD_SOURCE_ORACLE_4626_KEY);
        yieldSourceOracleOP = IYieldSourceOracle(addressOracleOP);

        // Set up the accounts
        accountBase = accountInstances[BASE].account;
        accountETH = accountInstances[ETH].account;
        accountOP = accountInstances[OP].account;

        instanceOnBase = accountInstances[BASE];
        instanceOnETH = accountInstances[ETH];
        instanceOnOP = accountInstances[OP];

        // Set up the super executors
        superExecutorOnBase = ISuperExecutor(_getContract(BASE, SUPER_EXECUTOR_KEY));
        superExecutorOnETH = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        superExecutorOnOP = ISuperExecutor(_getContract(OP, SUPER_EXECUTOR_KEY));

        superLedgerETH = ISuperLedger(_getContract(ETH, SUPER_LEDGER_KEY));
        superLedgerOP = ISuperLedger(_getContract(OP, SUPER_LEDGER_KEY));

        vm.selectFork(FORKS[BASE]);
        balance_Base_USDC_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        vm.selectFork(FORKS[ETH]);

        address share = IERC7540(yieldSource7540AddressETH_USDC).share();

        ITranche(share).hook();

        address mngr = ITranche(share).hook();

        restrictionManager = RestrictionManagerLike(mngr);

        vm.startPrank(RestrictionManagerLike(mngr).root());

        restrictionManager.updateMember(share, accountETH, type(uint64).max);

        vm.stopPrank();

        poolId = vaultInstance7540ETH.poolId();
        assertEq(poolId, 4_139_607_887);
        trancheId = vaultInstance7540ETH.trancheId();
        assertEq(trancheId, bytes16(0x97aa65f23e7be09fcd62d0554d2e9273));

        poolManager = IPoolManager(0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29);

        assetId = poolManager.assetToId(underlyingETH_USDC);
        assertEq(assetId, uint128(242_333_941_209_166_991_950_178_742_833_476_896_417));
    }

    /*//////////////////////////////////////////////////////////////
                          FULL FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ETH_Bridge_Deposit_Redeem_Bridge_Back_Flow() public {
        test_Bridge_To_ETH_And_Deposit();
        _redeem_From_ETH_And_Bridge_Back_To_Base(true);
    }

    function test_ETH_Bridge_Deposit_Partial_Redeem_Bridge_Flow() public {
        test_Bridge_To_ETH_And_Deposit();
        _redeem_From_ETH_And_Bridge_Back_To_Base(false);
    }

    function test_ETH_Bridge_Deposit_Redeem_Flow_With_Warping() public {
        test_Bridge_To_ETH_And_Deposit();
        _warped_Redeem_From_ETH_And_Bridge_Back_To_Base();
    }

    function test_OP_Bridge_Deposit_Redeem_Flow() public {
        test_bridge_To_OP_And_Deposit();
        _redeem_From_OP();
    }

    function test_OP_Bridge_Deposit_Redeem_Flow_With_Warping() public {
        test_bridge_To_OP_And_Deposit();
        _warped_Redeem_From_OP();
    }

    /*//////////////////////////////////////////////////////////////
                          INDIVIDUAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Bridge_To_ETH_And_Deposit() public {
        uint256 amountPerVault = 1e8 / 2;

        // ETH IS DST
        vm.selectFork(FORKS[ETH]);

        // PREPARE ETH DATA
        address[] memory eth7540HooksAddresses = new address[](2);
        eth7540HooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        eth7540HooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory eth7540HooksData = new bytes[](2);
        eth7540HooksData[0] =
            _createApproveHookData(underlyingETH_USDC, yieldSource7540AddressETH_USDC, amountPerVault, false);
        eth7540HooksData[1] = _createRequestDeposit7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource7540AddressETH_USDC,
            accountETH,
            amountPerVault,
            true
        );

        UserOpData memory ethUserOpData = _createUserOpData(eth7540HooksAddresses, eth7540HooksData, ETH);

        // BASE IS SRC
        vm.selectFork(FORKS[BASE]);

        // PREPARE BASE DATA
        address[] memory srcHooksAddresses = new address[](2);
        srcHooksAddresses[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddresses[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksData = new bytes[](2);
        srcHooksData[0] =
            _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], amountPerVault, false);
        srcHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC,
            underlyingETH_USDC,
            amountPerVault / 2,
            amountPerVault / 2,
            ETH,
            true,
            amountPerVault,
            ethUserOpData
        );

        UserOpData memory srcUserOpData = _createUserOpData(srcHooksAddresses, srcHooksData, BASE);

        // EXECUTE ETH
        _processAcrossV3Message(BASE, ETH, executeOp(srcUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountETH);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), balance_Base_USDC_Before - amountPerVault);

        // DEPOSIT
        uint256 userShares = _execute7540DepositFlow(amountPerVault);

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);
        // pin block, check value, perform multiple deposits

        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            superLedgerETH.getLedger(accountETH, address(vaultInstance7540ETH));

        assertEq(entries.length, 1);
        assertEq(entries[0].price, pricePerShare);
        assertEq(entries[0].amountSharesAvailableToConsume, userShares);
        assertEq(unconsumedEntries, 0);
    }

    function _redeem_From_ETH_And_Bridge_Back_To_Base(bool isFullRedeem) internal {
        uint256 amountPerVault = 1e8 / 2;

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        uint256 user_Base_USDC_Balance_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        UserOpData memory baseUserOpData = _createUserOpData(new address[](0), new bytes[](0), BASE);

        vm.selectFork(FORKS[ETH]);

        uint256 userAssetsBefore = IERC20(underlyingETH_USDC).balanceOf(accountETH);

        uint256 userAssetsAfter;

        // REDEEM
        if (isFullRedeem) {
            userAssetsAfter = _execute7540RedeemFlow();
        } else {
            userAssetsAfter = _execute7540PartialRedeemFlow();
        }

        assertGt(userAssetsAfter, userAssetsBefore);

        // BRIDGE BACK
        vm.selectFork(FORKS[ETH]);

        address[] memory ethHooksAddresses = new address[](2);
        ethHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        ethHooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory ethHooksData = new bytes[](2);

        if (isFullRedeem) {
            ethHooksData[0] =
                _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], amountPerVault, false);
            ethHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
                underlyingETH_USDC,
                underlyingBase_USDC,
                amountPerVault,
                amountPerVault,
                BASE,
                true,
                amountPerVault,
                baseUserOpData
            );
        } else {
            ethHooksData[0] =
                _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], amountPerVault / 2, false);
            ethHooksData[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
                underlyingETH_USDC,
                underlyingBase_USDC,
                amountPerVault / 2,
                amountPerVault / 2,
                BASE,
                true,
                amountPerVault / 2,
                baseUserOpData
            );
        }

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);

        UserOpData memory ethUserOpData = _createUserOpData(ethHooksAddresses, ethHooksData, ETH);

        _processAcrossV3Message(ETH, BASE, executeOp(ethUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountBase);

        vm.selectFork(FORKS[BASE]);

        if (isFullRedeem) {
            assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), user_Base_USDC_Balance_Before + amountPerVault);
        } else {
            assertEq(
                IERC20(underlyingBase_USDC).balanceOf(accountBase), user_Base_USDC_Balance_Before + amountPerVault / 2
            );
        }
    }

    function test_bridge_To_OP_And_Deposit() public {
        uint256 amountPerVault = 1e8 / 2;

        // OP IS DST
        vm.selectFork(FORKS[OP]);

        uint256 previewDepositAmountOP = vaultInstance4626OP.previewDeposit(amountPerVault);

        // PREPARE OP DATA
        address[] memory opHooksAddresses = new address[](2);
        opHooksAddresses[0] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);
        opHooksAddresses[1] = _getHookAddress(OP, DEPOSIT_4626_VAULT_HOOK_KEY);

        bytes[] memory opHooksData = new bytes[](2);
        opHooksData[0] =
            _createApproveHookData(underlyingOP_USDCe, yieldSource4626AddressOP_USDCe, amountPerVault, false);
        opHooksData[1] = _createDeposit4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)), yieldSource4626AddressOP_USDCe, amountPerVault, true, false
        );

        UserOpData memory opUserOpData = _createUserOpData(opHooksAddresses, opHooksData, OP);

        // BASE IS SRC
        vm.selectFork(FORKS[BASE]);
        uint256 userBalanceBaseUSDCBefore = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        // PREPARE BASE DATA
        address[] memory srcHooksAddressesOP = new address[](2);
        srcHooksAddressesOP[0] = _getHookAddress(BASE, APPROVE_ERC20_HOOK_KEY);
        srcHooksAddressesOP[1] = _getHookAddress(BASE, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory srcHooksDataOP = new bytes[](2);
        srcHooksDataOP[0] =
            _createApproveHookData(underlyingBase_USDC, SPOKE_POOL_V3_ADDRESSES[BASE], amountPerVault, false);
        srcHooksDataOP[1] = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC,
            underlyingOP_USDCe,
            amountPerVault,
            amountPerVault,
            OP,
            true,
            amountPerVault,
            opUserOpData
        );

        UserOpData memory srcUserOpDataOP = _createUserOpData(srcHooksAddressesOP, srcHooksDataOP, BASE);

        // EXECUTE OP
        _processAcrossV3Message(BASE, OP, executeOp(srcUserOpDataOP), RELAYER_TYPE.ENOUGH_BALANCE, accountOP);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), userBalanceBaseUSDCBefore - amountPerVault);

        vm.selectFork(FORKS[OP]);
        assertEq(vaultInstance4626OP.balanceOf(accountOP), previewDepositAmountOP);
    }

    function _redeem_From_OP() internal {
        uint256 amountPerVault = 1e8 / 2;
        vm.selectFork(FORKS[OP]);

        uint256 userBalanceSharesBefore = IERC20(yieldSource4626AddressOP_USDCe).balanceOf(accountOP);

        uint256 expectedAssetOutAmount = vaultInstance4626OP.previewRedeem(userBalanceSharesBefore);

        uint256 userBalanceUnderlyingBefore = IERC20(underlyingOP_USDCe).balanceOf(accountOP);

        address[] memory opHooksAddresses = new address[](2);
        opHooksAddresses[0] = _getHookAddress(OP, WITHDRAW_4626_VAULT_HOOK_KEY);
        opHooksAddresses[1] = _getHookAddress(OP, APPROVE_ERC20_HOOK_KEY);

        bytes[] memory opHooksData = new bytes[](2);
        opHooksData[0] = _createWithdraw4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource4626AddressOP_USDCe,
            accountOP,
            userBalanceSharesBefore,
            false,
            false
        );
        opHooksData[1] = _createApproveHookData(underlyingOP_USDCe, SPOKE_POOL_V3_ADDRESSES[OP], amountPerVault, true);

        UserOpData memory opUserOpData = _createUserOpData(opHooksAddresses, opHooksData, OP);

        executeOp(opUserOpData);

        assertEq(vaultInstance4626OP.balanceOf(accountOP), 0);
        assertEq(IERC20(underlyingOP_USDCe).balanceOf(accountOP), userBalanceUnderlyingBefore + expectedAssetOutAmount);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    // Deposits the given amount of ETH into the 7540 vault
    function _execute7540DepositFlow(uint256 amountPerVault) internal returns (uint256 userShares) {
        vm.selectFork(FORKS[ETH]);

        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);

        vm.startPrank(0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC);

        uint256 userExpectedShares = vaultInstance7540ETH.convertToShares(amountPerVault);

        investmentManager.fulfillDepositRequest(
            poolId, trancheId, accountETH, assetId, uint128(amountPerVault), uint128(userExpectedShares)
        );

        uint256 maxDeposit = vaultInstance7540ETH.maxDeposit(accountETH);
        userExpectedShares = vaultInstance7540ETH.convertToShares(maxDeposit);

        vm.stopPrank();

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7575_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit7575_7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource7540AddressETH_USDC,
            accountETH,
            maxDeposit,
            false,
            false
        );

        UserOpData memory depositOpData = _createUserOpData(hooksAddresses, hooksData, ETH);

        vm.expectEmit(true, true, true, true);
        emit ISuperLedger.AccountingInflow(
            accountETH,
            addressOracleETH,
            yieldSource7540AddressETH_USDC,
            userExpectedShares,
            yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH))
        );
        executeOp(depositOpData);

        assertEq(IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH), userExpectedShares);

        userShares = IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH);
    }

    // Redeems all of the user 7540 vault shares on ETH
    function _execute7540RedeemFlow() internal returns (uint256 userAssets) {
        vm.selectFork(FORKS[ETH]);

        uint256 userShares = IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH);

        uint256 userExpectedAssets = vaultInstance7540ETH.convertToAssets(userShares);

        vm.prank(accountETH);
        IERC7540(yieldSource7540AddressETH_USDC).requestRedeem(userShares, accountETH, accountETH);

        // FULFILL REDEEM
        vm.prank(0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC);

        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountETH, assetId, uint128(userExpectedAssets), uint128(userShares)
        );

        userExpectedAssets = vaultInstance7540ETH.convertToAssets(vaultInstance7540ETH.maxRedeem(accountETH));

        address[] memory redeemHooksAddresses = new address[](1);

        redeemHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7575_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createWithdraw7575_7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource7540AddressETH_USDC,
            accountETH,
            userExpectedAssets,
            false,
            false
        );

        UserOpData memory redeemOpData = _createUserOpData(redeemHooksAddresses, redeemHooksData, ETH);

        /*
            sharesConsumed = maxRedeemAmount
            costBasis = sharesConsumed * entry.price / (10 ** decimals)
            profit = amountAssets > costBasis ? amountAssets - costBasis : 0
            feeAmount = (profit * config.feePercent) / 10_000

            sharesConsumed = 47427940
            costBasis = 47427940 * 1054230 / (10 ** 6) = 49999957
            amountAssets = 49999998
            profit = 49999998 - 49999957 = 41
            feeAmount = 41 * 100 / 10_000 = 0
        */
        uint256 expectedFee = 0;

        vm.expectEmit(true, true, true, true);
        emit ISuperLedger.AccountingOutflow(
            accountETH, addressOracleETH, yieldSource7540AddressETH_USDC, userExpectedAssets, expectedFee
        );
        executeOp(redeemOpData);

        // CHECK ACCOUNTING
        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            superLedgerETH.getLedger(accountETH, address(vaultInstance7540ETH));
        assertEq(entries.length, 1);
        assertEq(unconsumedEntries, 1);

        userAssets = IERC20(underlyingETH_USDC).balanceOf(accountETH);
    }

    // Redeems half of the user 7540 vault shares on ETH
    function _execute7540PartialRedeemFlow() internal returns (uint256 userAssets) {
        vm.selectFork(FORKS[ETH]);

        uint256 redeemAmount = IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH) / 2;

        vm.prank(accountETH);
        IERC7540(yieldSource7540AddressETH_USDC).requestRedeem(redeemAmount, accountETH, accountETH);

        uint256 userExpectedAssets = vaultInstance7540ETH.convertToAssets(redeemAmount);

        // FULFILL REDEEM
        vm.prank(0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC);

        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountETH, assetId, uint128(userExpectedAssets), uint128(redeemAmount)
        );

        uint256 maxRedeemAmount = vaultInstance7540ETH.maxRedeem(accountETH);

        userExpectedAssets = vaultInstance7540ETH.convertToAssets(maxRedeemAmount);

        address[] memory redeemHooksAddresses = new address[](1);

        redeemHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7575_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createWithdraw7575_7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource7540AddressETH_USDC,
            accountETH,
            userExpectedAssets,
            false,
            false
        );

        UserOpData memory redeemOpData = _createUserOpData(redeemHooksAddresses, redeemHooksData, ETH);

        /*
            sharesConsumed = maxRedeemAmount
            costBasis = sharesConsumed * entry.price / (10 ** decimals)
            profit = amountAssets > costBasis ? amountAssets - costBasis : 0
            feeAmount = (profit * config.feePercent) / 10_000

            sharesConsumed = 23713970
            costBasis = 23713970 * 1054230 / (10 ** 6) = 24999978
            amountAssets = 24999999
            profit = 21
            feeAmount = 21 * 100 / 10_000 = 0
        */
        uint256 expectedFee = 0;

        vm.expectEmit(true, true, true, true);
        emit ISuperLedger.AccountingOutflow(
            accountETH, addressOracleETH, yieldSource7540AddressETH_USDC, userExpectedAssets, expectedFee
        );
        executeOp(redeemOpData);

        // CHECK ACCOUNTING
        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            superLedgerETH.getLedger(accountETH, address(vaultInstance7540ETH));
        assertEq(entries.length, 1);
        assertEq(entries[0].price, yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH)));
        assertEq(entries[0].amountSharesAvailableToConsume, redeemAmount);
        assertEq(unconsumedEntries, 0);

        userAssets = IERC20(underlyingETH_USDC).balanceOf(accountETH);
    }

    function _warped_Redeem_From_ETH_And_Bridge_Back_To_Base() internal returns (uint256 userAssets) {
        vm.selectFork(FORKS[ETH]);

        vm.warp(block.timestamp + 100 days);

        uint256 userShares = IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH);

        uint256 userExpectedAssets = vaultInstance7540ETH.convertToAssets(userShares);

        vm.prank(accountETH);
        IERC7540(yieldSource7540AddressETH_USDC).requestRedeem(userShares, accountETH, accountETH);

        vm.warp(block.timestamp + 10 days);

        // FULFILL REDEEM
        vm.startPrank(0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC);

        // poolManager.updateTranchePrice(poolId, trancheId, assetId, uint128(0.1e18), uint64(block.timestamp));

        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountETH, assetId, uint128(userExpectedAssets + 20000), uint128(userShares)
        );

        vm.stopPrank();

        userExpectedAssets = vaultInstance7540ETH.convertToAssets(vaultInstance7540ETH.maxRedeem(accountETH));

        address[] memory redeemHooksAddresses = new address[](1);

        redeemHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7575_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createWithdraw7575_7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource7540AddressETH_USDC,
            accountETH,
            userExpectedAssets,
            false,
            false
        );

        UserOpData memory redeemOpData = _createUserOpData(redeemHooksAddresses, redeemHooksData, ETH);

        /*
            sharesConsumed = maxRedeemAmount
            costBasis = sharesConsumed * entry.price / (10 ** decimals)
            profit = amountAssets > costBasis ? amountAssets - costBasis : 0
            feeAmount = (profit * config.feePercent) / 10_000

            sharesConsumed = 47408977
            costBasis = 47408977 * 1054230 / (10 ** 6) = 49979965
            amountAssets = 49999998
            profit = 49999998 - 49979965 = 20023
            feeAmount = 20023 * 100 / 10_000 = 200
        */
        //uint256 expectedFee = 200;

        uint256 feeBalanceBefore = IERC20(underlyingETH_USDC).balanceOf(address(this));

        // vm.expectEmit(true, true, true, true);
        // emit ISuperLedger.AccountingOutflow(
        //     accountETH, addressOracleETH, yieldSource7540AddressETH_USDC, userExpectedAssets, expectedFee
        // );
        executeOp(redeemOpData);

        uint256 feeBalanceAfter = IERC20(underlyingETH_USDC).balanceOf(address(this));

        assertEq(feeBalanceAfter - feeBalanceBefore, 200);

        // CHECK ACCOUNTING
        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            superLedgerETH.getLedger(accountETH, address(vaultInstance7540ETH));
        assertEq(entries.length, 1);
        assertEq(unconsumedEntries, 0);

        userAssets = IERC20(underlyingETH_USDC).balanceOf(accountETH);
    }

    function _warped_Redeem_From_OP() internal {
        vm.selectFork(FORKS[OP]);

        uint256 userBalanceSharesBefore = IERC20(yieldSource4626AddressOP_USDCe).balanceOf(accountOP);

        vm.warp(block.timestamp + 150 days);

        uint256 expectedAssetOutAmount = vaultInstance4626OP.previewRedeem(userBalanceSharesBefore);

        uint256 userBalanceUnderlyingBefore = IERC20(underlyingOP_USDCe).balanceOf(accountOP);

        address[] memory opHooksAddresses = new address[](1);
        opHooksAddresses[0] = _getHookAddress(OP, WITHDRAW_4626_VAULT_HOOK_KEY);

        bytes[] memory opHooksData = new bytes[](1);
        opHooksData[0] = _createWithdraw4626HookData(
            bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource4626AddressOP_USDCe,
            accountOP,
            userBalanceSharesBefore,
            false,
            false
        );

        UserOpData memory opUserOpData = _createUserOpData(opHooksAddresses, opHooksData, OP);

        // CHECK ACCOUNTING
        uint256 feeBalanceBefore = IERC20(underlyingOP_USDCe).balanceOf(address(this));

        /**
            sharesConsumed = userBalanceSharesBefore
            costBasis = sharesConsumed * entry.price / (10 ** decimals)
            profit = amountAssets > costBasis ? amountAssets - costBasis : 0
            feeAmount = (profit * config.feePercent) / 10_000

            sharesConsumed = 48621278
            costBasis = 48621278 * 1028357 / (10 ** 6) = 50000031
            amountAssets = 50035301
            profit = 50035301 - 50000031 = 35334
            feeAmount = 35334 * 100 / 10_000 = 353
        */

        vm.expectEmit(true, true, true, true);
        emit ISuperLedger.AccountingOutflow(
            accountOP, addressOracleOP, yieldSource4626AddressOP_USDCe, expectedAssetOutAmount, 353
        );
        executeOp(opUserOpData);

        uint256 feeBalanceAfter = IERC20(underlyingOP_USDCe).balanceOf(address(this));

        assertEq(feeBalanceAfter - feeBalanceBefore, 353);

        assertEq(vaultInstance4626OP.balanceOf(accountOP), 0);
        assertEq(
            IERC20(underlyingOP_USDCe).balanceOf(accountOP),
            userBalanceUnderlyingBefore + expectedAssetOutAmount - 353
        );

        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            superLedgerOP.getLedger(accountOP, address(vaultInstance4626OP));
        assertEq(entries.length, 1);
        assertEq(entries[0].amountSharesAvailableToConsume, 0);
        assertEq(unconsumedEntries, 1);
    }

    // Creates userOpData for the given chainId
    function _createUserOpData(
        address[] memory hooksAddresses,
        bytes[] memory hooksData,
        uint64 chainId
    )
        internal
        returns (UserOpData memory)
    {
        if (chainId == ETH) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            return _getExecOps(instanceOnETH, superExecutorOnETH, abi.encode(entryToExecute));
        } else if (chainId == OP) {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            return _getExecOps(instanceOnOP, superExecutorOnOP, abi.encode(entryToExecute));
        } else {
            ISuperExecutor.ExecutorEntry memory entryToExecute =
                ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
            return _getExecOps(instanceOnBase, superExecutorOnBase, abi.encode(entryToExecute));
        }
    }

    function _overrideSuperLedger() internal {
        for (uint256 i; i < chainIds.length; ++i) {
            vm.selectFork(FORKS[chainIds[i]]);

            vm.startPrank(MANAGER);

            ISuperLedger.YieldSourceOracleConfigArgs[] memory configs =
                new ISuperLedger.YieldSourceOracleConfigArgs[](3);
            configs[0] = ISuperLedger.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes32(bytes(ERC4626_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], ERC4626_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: address(this)
            });
            configs[1] = ISuperLedger.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], ERC7540_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: address(this)
            });
            configs[2] = ISuperLedger.YieldSourceOracleConfigArgs({
                yieldSourceOracleId: bytes32(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY)),
                yieldSourceOracle: _getContract(chainIds[i], ERC5115_YIELD_SOURCE_ORACLE_KEY),
                feePercent: 100,
                feeRecipient: address(this)
            });
            ISuperLedger(_getContract(chainIds[i], SUPER_LEDGER_KEY)).setYieldSourceOracles(configs);
            vm.stopPrank();
        }
    }
}
