// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { UserOpData, AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BaseTest } from "../../BaseTest.t.sol";
import { SuperLedger } from "../../../src/accounting/SuperLedger.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperLedgerConfiguration } from "../../../src/interfaces/accounting/ISuperLedgerConfiguration.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { ERC7540YieldSourceOracle } from "../../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";
import { IERC7540 } from "../../../src/vendor/vaults/7540/IERC7540.sol";

import { ITranche } from "../../mocks/centrifuge/ITranch.sol";
import { IInvestmentManager } from "../../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../../mocks/centrifuge/IPoolManager.sol";
import { RestrictionManagerLike } from "../../mocks/centrifuge/IRestrictionManagerLike.sol";

/// @title ERC7540AsyncDepositWithdrawE2E
/// @notice End-to-end test for the full async ERC-7540 deposit → withdraw lifecycle.
///
/// @dev Exercises the complete protocol stack against the real Centrifuge USDC vault
///      (Ethereum mainnet, block 21_929_476). Every step executes through the SuperExecutor
///      installed on a Nexus smart account — no direct vault calls from the test.
///
/// Lifecycle:
///   Phase 1  – requestDeposit  : ApproveERC20Hook + RequestDeposit7540VaultHook (UserOp)
///   Epoch    – fulfillDeposit  : investmentManager.fulfillDepositRequest (rootManager)
///   Phase 2  – claimShares     : Deposit7540VaultHook (UserOp)
///   Phase 3  – requestRedeem   : RequestRedeem7540VaultHook (UserOp)
///   Epoch    – fulfillRedeem   : investmentManager.fulfillRedeemRequest (rootManager)
///   Phase 4  – claimAssets     : Withdraw7540VaultHook (UserOp)
///
/// Assertions cover: pending state, share receipt, ledger cost basis, fee accounting,
///   and oracle TVL breakdown at each phase transition.
contract ERC7540AsyncDepositWithdrawE2E is BaseTest {
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                             CENTRIFUGE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address constant ROOT_MANAGER = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;
    address constant INVESTMENT_MANAGER_ADDR = 0xE79f06573d6aF1B66166A926483ba00924285d20;
    address constant POOL_MANAGER_ADDR = 0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29;

    uint256 constant DEPOSIT_AMOUNT = 100e6; // 100 USDC
    uint256 constant FEE_PERCENT = 1000; // 10%

    /*//////////////////////////////////////////////////////////////
                             STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC7540 public centrifugeVault;
    IInvestmentManager public investmentManager;

    AccountInstance public instanceOnEth;
    address public accountEth;

    SuperLedgerConfiguration public config;
    SuperExecutor public superExecutor;
    SuperLedger public superLedger;
    ERC7540YieldSourceOracle public oracle7540;

    address public feeRecipient;
    address public manager;
    bytes32 public yieldSourceOracleId;

    uint64 public poolId;
    bytes16 public trancheId;
    uint128 public assetId;

    /*//////////////////////////////////////////////////////////////
                             SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        instanceOnEth = accountInstances[ETH];
        accountEth = instanceOnEth.account;

        // --- Centrifuge vault setup ---
        centrifugeVault = IERC7540(CHAIN_1_CENTRIFUGE_USDC);
        investmentManager = IInvestmentManager(INVESTMENT_MANAGER_ADDR);

        IPoolManager poolManager = IPoolManager(POOL_MANAGER_ADDR);
        poolId = centrifugeVault.poolId();
        trancheId = centrifugeVault.trancheId();
        assetId = poolManager.assetToId(CHAIN_1_USDC);

        // Whitelist smart account as a Centrifuge member (required by ERC-1404 restriction)
        address share = centrifugeVault.share();
        RestrictionManagerLike restrictionManager = RestrictionManagerLike(ITranche(share).hook());
        vm.prank(restrictionManager.root());
        restrictionManager.updateMember(share, accountEth, type(uint64).max);

        // --- Protocol stack: config → ledger → oracle ---
        feeRecipient = makeAddr("feeRecipient");
        manager = makeAddr("manager");

        config = new SuperLedgerConfiguration();
        superExecutor = new SuperExecutor(address(config));

        address[] memory executors = new address[](1);
        executors[0] = address(superExecutor);
        superLedger = new SuperLedger(address(config), executors);

        oracle7540 = new ERC7540YieldSourceOracle(address(config), 0);

        bytes32[] memory salts = new bytes32[](1);
        salts[0] = bytes32(keccak256("7540_E2E_ORACLE"));
        yieldSourceOracleId = keccak256(abi.encodePacked(salts[0], manager));

        ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[] memory oracleConfigs =
            new ISuperLedgerConfiguration.YieldSourceOracleConfigArgs[](1);
        oracleConfigs[0] = ISuperLedgerConfiguration.YieldSourceOracleConfigArgs({
            yieldSourceOracle: address(oracle7540),
            feePercent: FEE_PERCENT,
            feeRecipient: feeRecipient,
            ledger: address(superLedger)
        });
        vm.prank(manager);
        config.setYieldSourceOracles(salts, oracleConfigs);

        // Install executor on smart account
        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        // Fund smart account with USDC
        _getTokens(CHAIN_1_USDC, accountEth, DEPOSIT_AMOUNT * 2);
    }

    /*//////////////////////////////////////////////////////////////
                         FULL LIFECYCLE TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Full async deposit → withdraw lifecycle executed entirely through the SuperExecutor.
    ///         Each hook-executed step verifies vault state, oracle TVL, and smart account balances.
    function test_e2e_fullAsyncDepositWithdrawLifecycle() public {
        /*//////////////////////////////////////////////////////////////
                    PHASE 1: REQUEST DEPOSIT
        //////////////////////////////////////////////////////////////*/

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        {
            address[] memory hooksAddresses = new address[](2);
            hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
            hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

            bytes[] memory hooksData = new bytes[](2);
            hooksData[0] = _createApproveHookData(CHAIN_1_USDC, CHAIN_1_CENTRIFUGE_USDC, DEPOSIT_AMOUNT, false);
            hooksData[1] =
                _createRequestDeposit7540VaultHookData(yieldSourceOracleId, CHAIN_1_CENTRIFUGE_USDC, DEPOSIT_AMOUNT, false);

            _executeOp(hooksAddresses, hooksData);
        }

        // Assert: USDC locked in Centrifuge escrow
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(accountEth), usdcBefore - DEPOSIT_AMOUNT, "USDC not moved to escrow");
        assertEq(centrifugeVault.pendingDepositRequest(0, accountEth), DEPOSIT_AMOUNT, "Pending deposit mismatch");
        assertEq(IERC20(centrifugeVault.share()).balanceOf(accountEth), 0, "Should not have shares yet");

        // Oracle sees pending deposit, no held shares
        (uint256 held,, , uint256 pendingDep,) = oracle7540.getAsyncStateBreakdown(CHAIN_1_CENTRIFUGE_USDC, accountEth);
        assertEq(held, 0, "No held value during pending deposit");
        assertEq(pendingDep, DEPOSIT_AMOUNT, "Oracle must reflect pending deposit");

        /*//////////////////////////////////////////////////////////////
                    EPOCH 1: CENTRIFUGE FULFILLS DEPOSIT
        //////////////////////////////////////////////////////////////*/

        uint256 expectedShares = centrifugeVault.convertToShares(DEPOSIT_AMOUNT);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, accountEth, assetId, uint128(DEPOSIT_AMOUNT), uint128(expectedShares)
        );

        uint256 maxDeposit = centrifugeVault.maxDeposit(accountEth);
        assertGt(maxDeposit, 0, "No claimable deposit after epoch");
        assertEq(centrifugeVault.pendingDepositRequest(0, accountEth), 0, "Pending deposit not cleared by epoch");

        // Oracle sees claimable deposit (not yet claimed by user)
        (,, , uint256 pendingDep2, uint256 claimableDep) =
            oracle7540.getAsyncStateBreakdown(CHAIN_1_CENTRIFUGE_USDC, accountEth);
        assertEq(pendingDep2, 0, "Pending deposit must clear after epoch");
        assertGt(claimableDep, 0, "Oracle must see claimable deposit after epoch");

        /*//////////////////////////////////////////////////////////////
                    PHASE 2: CLAIM SHARES (Deposit7540VaultHook)
        //////////////////////////////////////////////////////////////*/

        {
            address[] memory hooksAddresses = new address[](1);
            hooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

            bytes[] memory hooksData = new bytes[](1);
            hooksData[0] =
                _createDeposit7540VaultHookData(yieldSourceOracleId, CHAIN_1_CENTRIFUGE_USDC, maxDeposit, false, address(0), 0);

            _executeOp(hooksAddresses, hooksData);
        }

        uint256 userShares = IERC20(centrifugeVault.share()).balanceOf(accountEth);
        assertGt(userShares, 0, "No shares received after deposit claim");
        assertLe(centrifugeVault.claimableDepositRequest(0, accountEth), 1, "Claimable deposit should be 0 or 1 dust from rounding");

        // SuperLedger has recorded cost basis (deposit inflow)
        uint256 ledgerCostBasis = superLedger.usersAccumulatorCostBasis(accountEth, CHAIN_1_CENTRIFUGE_USDC);
        assertGt(ledgerCostBasis, 0, "Ledger must record cost basis after deposit");

        // Oracle: all value in held shares, no pending/claimable
        (uint256 heldAfterDeposit,, ,  ,) = oracle7540.getAsyncStateBreakdown(CHAIN_1_CENTRIFUGE_USDC, accountEth);
        assertEq(heldAfterDeposit, centrifugeVault.convertToAssets(userShares), "Held value must equal convertToAssets(shares)");
        assertApproxEqAbs(oracle7540.getTVLByOwnerOfShares(CHAIN_1_CENTRIFUGE_USDC, accountEth), heldAfterDeposit, 1, "TVL ~= held value (1 unit claimable deposit dust may remain)");

        /*//////////////////////////////////////////////////////////////
                    PHASE 3: REQUEST REDEEM
        //////////////////////////////////////////////////////////////*/

        {
            address[] memory hooksAddresses = new address[](1);
            hooksAddresses[0] = _getHookAddress(ETH, REQUEST_REDEEM_7540_VAULT_HOOK_KEY);

            bytes[] memory hooksData = new bytes[](1);
            hooksData[0] =
                _createRequestRedeem7540VaultHookData(yieldSourceOracleId, CHAIN_1_CENTRIFUGE_USDC, userShares, false);

            _executeOp(hooksAddresses, hooksData);
        }

        assertEq(IERC20(centrifugeVault.share()).balanceOf(accountEth), 0, "Shares must move to escrow on requestRedeem");
        assertEq(centrifugeVault.pendingRedeemRequest(0, accountEth), userShares, "Pending redeem must equal all shares");

        // Oracle: value migrated from held → pendingRedeem
        (uint256 heldAfterReq, uint256 pendingRedeem,, ,) =
            oracle7540.getAsyncStateBreakdown(CHAIN_1_CENTRIFUGE_USDC, accountEth);
        assertEq(heldAfterReq, 0, "No held value after requestRedeem");
        assertEq(pendingRedeem, centrifugeVault.convertToAssets(userShares), "Pending redeem = convertToAssets(shares)");

        /*//////////////////////////////////////////////////////////////
                    EPOCH 2: CENTRIFUGE FULFILLS REDEEM
        //////////////////////////////////////////////////////////////*/

        uint256 expectedAssets = centrifugeVault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountEth, assetId, uint128(expectedAssets), uint128(userShares)
        );

        uint256 maxWithdraw = centrifugeVault.maxWithdraw(accountEth);
        assertGt(maxWithdraw, 0, "No claimable assets after redeem epoch");
        assertEq(centrifugeVault.pendingRedeemRequest(0, accountEth), 0, "Pending redeem not cleared by epoch");

        // Oracle: value migrated from pendingRedeem → claimableRedeem
        (, uint256 pendingRedeem2, uint256 claimableRedeem,, ) =
            oracle7540.getAsyncStateBreakdown(CHAIN_1_CENTRIFUGE_USDC, accountEth);
        assertEq(pendingRedeem2, 0, "Pending redeem must clear after epoch");
        assertApproxEqAbs(claimableRedeem, maxWithdraw, 1, "Oracle claimable redeem = vault.maxWithdraw() (+/-1 rounding)");

        /*//////////////////////////////////////////////////////////////
                    PHASE 4: CLAIM ASSETS (Withdraw7540VaultHook)
        //////////////////////////////////////////////////////////////*/

        uint256 usdcBeforeWithdraw = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        {
            address[] memory hooksAddresses = new address[](1);
            hooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

            bytes[] memory hooksData = new bytes[](1);
            hooksData[0] = _createWithdraw7540VaultHookData(yieldSourceOracleId, CHAIN_1_CENTRIFUGE_USDC, maxWithdraw, false);

            _executeOp(hooksAddresses, hooksData);
        }

        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        uint256 feeCollected = IERC20(CHAIN_1_USDC).balanceOf(feeRecipient);

        // User received USDC minus protocol fee
        assertGt(usdcAfter, usdcBeforeWithdraw, "User must receive USDC after withdraw");
        assertGt(feeCollected, 0, "Fee recipient must receive performance fee");
        assertApproxEqAbs(usdcAfter - usdcBeforeWithdraw + feeCollected, maxWithdraw, 1, "User assets + fee must equal maxWithdraw (+/-1 rounding)");

        // Vault position fully closed
        assertEq(centrifugeVault.maxWithdraw(accountEth), 0, "maxWithdraw must be 0 after full withdraw");
        assertEq(centrifugeVault.pendingRedeemRequest(0, accountEth), 0, "No residual pending redeem");
        assertEq(IERC20(centrifugeVault.share()).balanceOf(accountEth), 0, "No residual shares");

        // Oracle: all components 0 (position fully closed), allow 1 unit claimable deposit dust from rounding
        (uint256 f1, uint256 f2, uint256 f3, uint256 f4, uint256 f5) =
            oracle7540.getAsyncStateBreakdown(CHAIN_1_CENTRIFUGE_USDC, accountEth);
        assertLe(f1 + f2 + f3 + f4 + f5, 1, "Oracle TVL must be 0 after full withdraw (1 unit dust allowed)");
        assertLe(oracle7540.getTVLByOwnerOfShares(CHAIN_1_CENTRIFUGE_USDC, accountEth), 1, "getTVLByOwnerOfShares must be 0 (1 unit dust allowed)");
    }

    /*//////////////////////////////////////////////////////////////
                    PARTIAL REDEEM VARIANT
    //////////////////////////////////////////////////////////////*/

    /// @notice Same lifecycle but only redeems 50% of shares, verifying partial position tracking.
    function test_e2e_partialRedeem() public {
        // Full deposit phase (reuse Phase 1 + Epoch 1 + Phase 2)
        _phaseRequestDeposit(DEPOSIT_AMOUNT);
        _epochFulfillDeposit(DEPOSIT_AMOUNT);
        _phaseClaimShares(centrifugeVault.maxDeposit(accountEth));

        uint256 totalShares = IERC20(centrifugeVault.share()).balanceOf(accountEth);
        uint256 halfShares = totalShares / 2;

        // Phase 3: request redeem of half
        _phaseRequestRedeem(halfShares);
        assertEq(centrifugeVault.pendingRedeemRequest(0, accountEth), halfShares);
        // Other half still held
        assertEq(IERC20(centrifugeVault.share()).balanceOf(accountEth), totalShares - halfShares);

        // Epoch 2: fulfill partial redeem
        uint256 expectedAssets = centrifugeVault.convertToAssets(halfShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, accountEth, assetId, uint128(expectedAssets), uint128(halfShares)
        );

        // Oracle: half in held, half in claimableRedeem
        (uint256 heldVal,, uint256 claimableRedeemVal,, ) = oracle7540.getAsyncStateBreakdown(CHAIN_1_CENTRIFUGE_USDC, accountEth);
        assertApproxEqAbs(heldVal, centrifugeVault.convertToAssets(totalShares - halfShares), 1, "Held value = remaining shares");
        assertEq(claimableRedeemVal, centrifugeVault.maxWithdraw(accountEth), "Claimable = maxWithdraw");

        // Phase 4: claim partial assets
        uint256 maxWithdraw = centrifugeVault.maxWithdraw(accountEth);
        _phaseWithdraw(maxWithdraw);

        // Still has remaining shares
        assertGt(IERC20(centrifugeVault.share()).balanceOf(accountEth), 0, "Must still have remaining shares");
        assertGt(IERC20(CHAIN_1_USDC).balanceOf(accountEth), 0, "Must have received USDC for partial redeem");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL PHASE HELPERS
    //////////////////////////////////////////////////////////////*/

    function _phaseRequestDeposit(uint256 amount) internal {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
        hooksAddresses[1] = _getHookAddress(ETH, REQUEST_DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(CHAIN_1_USDC, CHAIN_1_CENTRIFUGE_USDC, amount, false);
        hooksData[1] = _createRequestDeposit7540VaultHookData(yieldSourceOracleId, CHAIN_1_CENTRIFUGE_USDC, amount, false);

        _executeOp(hooksAddresses, hooksData);
    }

    function _epochFulfillDeposit(uint256 depositAmount) internal {
        uint256 shares = centrifugeVault.convertToShares(depositAmount);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, accountEth, assetId, uint128(depositAmount), uint128(shares)
        );
    }

    function _phaseClaimShares(uint256 maxDeposit) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, DEPOSIT_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] =
            _createDeposit7540VaultHookData(yieldSourceOracleId, CHAIN_1_CENTRIFUGE_USDC, maxDeposit, false, address(0), 0);

        _executeOp(hooksAddresses, hooksData);
    }

    function _phaseRequestRedeem(uint256 shares) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, REQUEST_REDEEM_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createRequestRedeem7540VaultHookData(yieldSourceOracleId, CHAIN_1_CENTRIFUGE_USDC, shares, false);

        _executeOp(hooksAddresses, hooksData);
    }

    function _phaseWithdraw(uint256 amount) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = _getHookAddress(ETH, WITHDRAW_7540_VAULT_HOOK_KEY);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createWithdraw7540VaultHookData(yieldSourceOracleId, CHAIN_1_CENTRIFUGE_USDC, amount, false);

        _executeOp(hooksAddresses, hooksData);
    }

    function _executeOp(address[] memory hooksAddresses, bytes[] memory hooksData) internal {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutor, abi.encode(entry));
        executeOp(userOpData);
    }
}
