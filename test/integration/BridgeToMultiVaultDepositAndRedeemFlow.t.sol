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
import { IERC7540 } from "../../src/core/interfaces/vendors/vaults/7540/IERC7540.sol";
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

    string public constant YIELD_SOURCE_7540_ETH_USDC_KEY = "YieldSource_7540_ETH_USDC";
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
        _full_redeem_From_ETH_And_Bridge_Back_To_Base();
    }

    function test_OP_Bridge_Deposit_Redeem_Flow() public {
        test_bridge_To_OP_And_Deposit();
        _redeem_From_OP();
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
        srcHooksData[1] 
        = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingBase_USDC, 
            underlyingETH_USDC, 
            amountPerVault / 2, 
            amountPerVault / 2, 
            ETH, 
            true, 
            amountPerVault / 2, 
            ethUserOpData
        );

        UserOpData memory srcUserOpData = _createUserOpData(srcHooksAddresses, srcHooksData, BASE);

        // EXECUTE ETH
        _processAcrossV3Message(BASE, ETH, executeOp(srcUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountETH);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), balance_Base_USDC_Before - amountPerVault);

        // DEPOSIT
        uint256 userShares = _executeDepositFlow(amountPerVault);
        assertEq(userShares, amountPerVault);

        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);

        uint256 expectedShares = amountPerVault;

        (ISuperLedger.LedgerEntry[] memory entries, uint256 unconsumedEntries) =
            superLedgerETH.getLedger(accountETH, address(vaultInstance7540ETH));

        assertEq(entries.length, 1);
        assertEq(entries[entries.length - 1].price, pricePerShare);
        assertEq(entries[entries.length - 1].amountSharesAvailableToConsume, expectedShares);
        assertEq(unconsumedEntries, 0);
    }

    function _full_redeem_From_ETH_And_Bridge_Back_To_Base() internal {
        uint256 amountPerVault = 1e8 / 2;

        // BASE IS DST
        vm.selectFork(FORKS[BASE]);

        uint256 user_Base_USDC_Balance_Before = IERC20(underlyingBase_USDC).balanceOf(accountBase);

        UserOpData memory baseUserOpData = _createUserOpData(new address[](0), new bytes[](0), BASE);

        vm.selectFork(FORKS[ETH]);

        uint256 userAssetsBefore = IERC20(underlyingETH_USDC).balanceOf(accountETH);

        // REDEEM
        uint256 userAssets = _executeRedeemFlow(amountPerVault);

        assertGt(userAssets, userAssetsBefore);


        // CHECK ACCOUNTING
        uint256 pricePerShare = yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH));
        assertNotEq(pricePerShare, 1);

        // BRIDGE BACK
        vm.selectFork(FORKS[ETH]);

        address[] memory ethHooksAddresses = new address[](2);
        ethHooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        ethHooksAddresses[1] = _getHookAddress(ETH, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY);

        bytes[] memory ethHooksData = new bytes[](2);
        ethHooksData[0] =
            _createApproveHookData(underlyingETH_USDC, SPOKE_POOL_V3_ADDRESSES[ETH], amountPerVault, false);
        ethHooksData[1] 
        = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC, 
            underlyingBase_USDC, 
            amountPerVault, 
            amountPerVault, 
            BASE, 
            true, 
            amountPerVault, 
            baseUserOpData
        );
        ethHooksData[1] 
        = _createAcrossV3ReceiveFundsAndExecuteHookData(
            underlyingETH_USDC, 
            underlyingBase_USDC, 
            amountPerVault, 
            amountPerVault, 
            BASE, 
            true, 
            amountPerVault, 
            baseUserOpData
        );

        UserOpData memory ethUserOpData = _createUserOpData(ethHooksAddresses, ethHooksData, ETH);

        _processAcrossV3Message(ETH, BASE, executeOp(ethUserOpData), RELAYER_TYPE.ENOUGH_BALANCE, accountBase);

        vm.selectFork(FORKS[BASE]);

        assertEq(IERC20(underlyingBase_USDC).balanceOf(accountBase), user_Base_USDC_Balance_Before + amountPerVault);
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
            underlyingBase_USDC, underlyingOP_USDCe, amountPerVault, amountPerVault, OP, true, amountPerVault, opUserOpData
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

    function _executeDepositFlow(uint256 amountPerVault) internal returns (uint256 userShares) {
        vm.selectFork(FORKS[ETH]);

        investmentManager = IInvestmentManager(0xE79f06573d6aF1B66166A926483ba00924285d20);

        vm.startPrank(0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC);

        investmentManager.fulfillDepositRequest(
            poolId, trancheId, accountETH, assetId, uint128(amountPerVault), uint128(amountPerVault)
        );

        vm.stopPrank();

        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7575_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createDeposit7575_7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource7540AddressETH_USDC,
            accountETH,
            amountPerVault,
            false,
            false
        );

        UserOpData memory depositOpData = _createUserOpData(hooksAddresses, hooksData, ETH);

        vm.expectEmit(true, true, true, true);
        emit ISuperLedger.AccountingInflow(
            accountETH, 
            addressOracleETH,
            yieldSource7540AddressETH_USDC, 
            amountPerVault, 
            yieldSourceOracleETH.getPricePerShare(address(vaultInstance7540ETH))
        );
        executeOp(depositOpData);

        userShares = IERC20(vaultInstance7540ETH.share()).balanceOf(accountETH);
    }

    function _executeRedeemFlow(uint256 amountPerVault) internal returns (uint256 userAssets) {
        vm.selectFork(FORKS[ETH]);

        vm.prank(accountETH);
        IERC7540(yieldSource7540AddressETH_USDC).requestRedeem(amountPerVault, accountETH, accountETH);

        // FULFILL REDEEM
        vm.prank(0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC);

        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountETH, assetId, uint128(amountPerVault), uint128(amountPerVault)
        );

        uint256 feeBalanceBefore 
        = IERC20(underlyingETH_USDC).balanceOf(address(this));

        console2.log("feeBalanceBefore", feeBalanceBefore);

        address[] memory redeemHooksAddresses = new address[](1);

        redeemHooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7575_7540_VAULT_HOOK_KEY);

        bytes[] memory redeemHooksData = new bytes[](1);
        redeemHooksData[0] = _createWithdraw7575_7540VaultHookData(
            bytes32(bytes(ERC7540_YIELD_SOURCE_ORACLE_KEY)),
            yieldSource7540AddressETH_USDC,
            accountETH,
            amountPerVault,
            false,
            false
        );

        UserOpData memory redeemOpData = _createUserOpData(redeemHooksAddresses, redeemHooksData, ETH);
        executeOp(redeemOpData);

        userAssets = IERC20(underlyingETH_USDC).balanceOf(accountETH);
    }

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
