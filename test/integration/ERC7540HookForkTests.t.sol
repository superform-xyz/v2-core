// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Non-WithId hooks
import { RequestDeposit7540VaultHook } from "../../src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import { Deposit7540VaultHook } from "../../src/hooks/vaults/7540/Deposit7540VaultHook.sol";
import { RequestRedeem7540VaultHook } from "../../src/hooks/vaults/7540/RequestRedeem7540VaultHook.sol";
import { Redeem7540VaultHook } from "../../src/hooks/vaults/7540/Redeem7540VaultHook.sol";
import { Withdraw7540VaultHook } from "../../src/hooks/vaults/7540/Withdraw7540VaultHook.sol";
import { CancelDepositRequest7540Hook } from "../../src/hooks/vaults/7540/CancelDepositRequest7540Hook.sol";
import { CancelRedeemRequest7540Hook } from "../../src/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol";
import { ClaimCancelDepositRequest7540Hook } from "../../src/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol";
import { ClaimCancelRedeemRequest7540Hook } from "../../src/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol";
import { SetOperator7540Hook } from "../../src/hooks/vaults/7540/SetOperator7540Hook.sol";
import {
    ApproveAndRequestDeposit7540VaultHook
} from "../../src/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol";

// Oracle
import { ERC7540YieldSourceOracle } from "../../src/accounting/oracles/ERC7540YieldSourceOracle.sol";

// Vendor
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";

// Centrifuge interfaces
import { RestrictionManagerLike } from "../mocks/centrifuge/IRestrictionManagerLike.sol";
import { IInvestmentManager } from "../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../mocks/centrifuge/IPoolManager.sol";
import { ITranche } from "../mocks/centrifuge/ITranch.sol";

/// @title ERC7540HookForkTests
/// @notice Fork integration tests for non-WithId ERC-7540 hooks and ERC7540YieldSourceOracle
///         using real Centrifuge vault on Ethereum mainnet
contract ERC7540HookForkTests is Test {
    function _singleAmount(uint256 amt) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = amt;
    }

    // -- Centrifuge on-chain addresses (Ethereum mainnet) --
    address constant CENTRIFUGE_USDC_VAULT = 0x1d01Ef1997d44206d839b78bA6813f60F1B3A970;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ROOT_MANAGER = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;
    address constant INVESTMENT_MANAGER = 0xE79f06573d6aF1B66166A926483ba00924285d20;
    address constant POOL_MANAGER = 0x91808B5E2F6d7483D41A681034D7c9DbB64B9E29;

    // -- Non-WithId hooks --
    RequestDeposit7540VaultHook public requestDepositHook;
    Deposit7540VaultHook public depositHook;
    RequestRedeem7540VaultHook public requestRedeemHook;
    Redeem7540VaultHook public redeemHook;
    Withdraw7540VaultHook public withdrawHook;
    CancelDepositRequest7540Hook public cancelDepositHook;
    CancelRedeemRequest7540Hook public cancelRedeemHook;
    ClaimCancelDepositRequest7540Hook public claimCancelDepositHook;
    ClaimCancelRedeemRequest7540Hook public claimCancelRedeemHook;
    SetOperator7540Hook public setOperatorHook;
    ApproveAndRequestDeposit7540VaultHook public approveAndRequestDepositHook;

    // -- Oracle --
    ERC7540YieldSourceOracle public oracle;

    // -- Centrifuge infra --
    IERC7540 public vault;
    IInvestmentManager public investmentManager;
    IPoolManager public poolManager;
    uint64 public poolId;
    bytes16 public trancheId;
    uint128 public assetId;

    // -- Test state --
    address public user;
    bytes32 public placeholder;
    bytes32 public oracleId;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), 21_929_476);

        user = makeAddr("centrifuge_user");
        placeholder = bytes32(keccak256("PLACEHOLDER"));
        oracleId = bytes32(keccak256("ORACLE_ID"));

        vault = IERC7540(CENTRIFUGE_USDC_VAULT);
        investmentManager = IInvestmentManager(INVESTMENT_MANAGER);
        poolManager = IPoolManager(POOL_MANAGER);

        poolId = vault.poolId();
        trancheId = vault.trancheId();
        assetId = poolManager.assetToId(USDC);

        // Whitelist user on Centrifuge tranche
        _whitelistUser(user);

        // Deploy hooks
        requestDepositHook = new RequestDeposit7540VaultHook();
        depositHook = new Deposit7540VaultHook();
        requestRedeemHook = new RequestRedeem7540VaultHook();
        redeemHook = new Redeem7540VaultHook();
        withdrawHook = new Withdraw7540VaultHook();
        cancelDepositHook = new CancelDepositRequest7540Hook();
        cancelRedeemHook = new CancelRedeemRequest7540Hook();
        claimCancelDepositHook = new ClaimCancelDepositRequest7540Hook();
        claimCancelRedeemHook = new ClaimCancelRedeemRequest7540Hook();
        setOperatorHook = new SetOperator7540Hook();
        approveAndRequestDepositHook = new ApproveAndRequestDeposit7540VaultHook();

        // Deploy oracle with requestId=0 (Centrifuge accumulated pattern)
        oracle = new ERC7540YieldSourceOracle(address(0), 0);
    }

    /*//////////////////////////////////////////////////////////////
                REQUEST DEPOSIT HOOK: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_RequestDeposit_RealVault() public {
        uint256 depositAmount = 1e8; // 100 USDC

        deal(USDC, user, depositAmount);

        // Approve vault
        vm.startPrank(user);
        IERC20(USDC).approve(CENTRIFUGE_USDC_VAULT, depositAmount);

        // Build and execute requestDeposit hook
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, depositAmount, false);
        Execution[] memory executions = requestDepositHook.build(address(0), user, hookData);

        (bool success,) = executions[1].target.call(executions[1].callData);
        vm.stopPrank();

        assertTrue(success, "requestDeposit failed");
        assertGt(vault.pendingDepositRequest(0, user), 0, "No pending deposit");
    }

    function test_fork_RequestDeposit_Inspect() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(1e6), false);
        bytes memory inspected = requestDepositHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect wrong");
    }

    function test_fork_RequestDeposit_DecodeAmounts() public view {
        uint256 amount = 5e7;
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, amount, false);
        assertEq(requestDepositHook.decodeAmounts(hookData)[0], amount, "decodeAmounts wrong");
    }

    function test_fork_RequestDeposit_ReplaceCalldataAmounts() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(1), false);
        uint256 newAmount = 2e8;
        bytes memory replaced = requestDepositHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(requestDepositHook.decodeAmounts(replaced)[0], newAmount, "replace failed");
    }

    function test_fork_RequestDeposit_DecodeUsePrevHookAmount_False() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(1e6), false);
        assertFalse(requestDepositHook.decodeUsePrevHookAmount(hookData));
    }

    function test_fork_RequestDeposit_DecodeUsePrevHookAmount_True() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0), true);
        assertTrue(requestDepositHook.decodeUsePrevHookAmount(hookData));
    }

    function test_fork_RequestDeposit_HookType_Nonaccounting() public view {
        assertEq(uint256(requestDepositHook.hookType()), 0, "hookType wrong");
    }

    /*//////////////////////////////////////////////////////////////
                DEPOSIT HOOK: After fulfillment
    //////////////////////////////////////////////////////////////*/

    function test_fork_Deposit_AfterFulfillment() public {
        uint256 depositAmount = 1e8;
        _fundAndRequestDeposit(depositAmount);

        // Fulfill deposit request
        uint256 expectedShares = vault.convertToShares(depositAmount);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(expectedShares)
        );

        uint256 maxDeposit = vault.maxDeposit(user);
        assertGt(maxDeposit, 0, "Nothing claimable after fulfillment");

        uint256 sharesBefore = IERC20(vault.share()).balanceOf(user);

        // Build and execute deposit hook
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxDeposit, false);
        Execution[] memory executions = depositHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "deposit failed");

        uint256 sharesAfter = IERC20(vault.share()).balanceOf(user);
        assertGt(sharesAfter, sharesBefore, "User did not receive shares");
    }

    function test_fork_Deposit_Inspect() public view {
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e6), false);
        bytes memory inspected = depositHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect wrong");
    }

    function test_fork_Deposit_DecodeAmounts() public view {
        uint256 amount = 3e7;
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, amount, false);
        assertEq(depositHook.decodeAmounts(hookData)[0], amount, "decodeAmounts wrong");
    }

    function test_fork_Deposit_HookType_Inflow() public view {
        assertEq(uint256(depositHook.hookType()), 1, "hookType wrong");
    }

    /*//////////////////////////////////////////////////////////////
            REQUEST REDEEM HOOK: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_RequestRedeem_RealVault() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "User has no shares");

        // Build and execute requestRedeem hook
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, userShares, false);
        Execution[] memory executions = requestRedeemHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "requestRedeem failed");

        assertGt(vault.pendingRedeemRequest(0, user), 0, "No pending redeem");
        assertEq(IERC20(vault.share()).balanceOf(user), 0, "Shares not locked");
    }

    function test_fork_RequestRedeem_Inspect() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(1e18), false);
        bytes memory inspected = requestRedeemHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect wrong");
    }

    function test_fork_RequestRedeem_DecodeAmounts() public view {
        uint256 shares = 5e17;
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, shares, false);
        assertEq(requestRedeemHook.decodeAmounts(hookData)[0], shares, "decodeAmounts wrong");
    }

    function test_fork_RequestRedeem_ReplaceCalldataAmounts() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(1), false);
        uint256 newShares = 7e17;
        bytes memory replaced = requestRedeemHook.replaceCalldataAmounts(hookData, _singleAmount(newShares));
        assertEq(requestRedeemHook.decodeAmounts(replaced)[0], newShares, "replace failed");
    }

    /*//////////////////////////////////////////////////////////////
            REDEEM HOOK: After fulfillment
    //////////////////////////////////////////////////////////////*/

    function test_fork_Redeem_RealVault() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);

        // Request redeem
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        // Fulfill redeem
        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );

        uint256 maxRedeem = vault.maxRedeem(user);
        assertGt(maxRedeem, 0, "Nothing to redeem");

        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        // Build and execute redeem hook
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxRedeem, false);
        Execution[] memory executions = redeemHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "redeem failed");

        assertGt(IERC20(USDC).balanceOf(user), usdcBefore, "User did not receive USDC");
        assertEq(vault.maxRedeem(user), 0, "maxRedeem not zeroed");
    }

    function test_fork_Redeem_Inspect() public view {
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e18), false);
        bytes memory inspected = redeemHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect wrong");
    }

    function test_fork_Redeem_DecodeAmounts() public view {
        uint256 shares = 4e17;
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, shares, false);
        assertEq(redeemHook.decodeAmounts(hookData)[0], shares, "decodeAmounts wrong");
    }

    function test_fork_Redeem_ReplaceCalldataAmounts() public view {
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1), false);
        uint256 newShares = 9e17;
        bytes memory replaced = redeemHook.replaceCalldataAmounts(hookData, _singleAmount(newShares));
        assertEq(redeemHook.decodeAmounts(replaced)[0], newShares, "replace failed");
    }

    function test_fork_Redeem_HookType_Outflow() public view {
        assertEq(uint256(redeemHook.hookType()), 2, "hookType wrong");
    }

    function test_fork_Redeem_RevertsOnZeroClaimable() public {
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e6), false);
        Execution[] memory executions = redeemHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertFalse(success, "Should revert when no claimable shares");
    }

    /*//////////////////////////////////////////////////////////////
            WITHDRAW HOOK: After fulfillment
    //////////////////////////////////////////////////////////////*/

    function test_fork_Withdraw_RealVault() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);

        // Request redeem
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        // Fulfill redeem
        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );

        uint256 maxWithdraw = vault.maxWithdraw(user);
        assertGt(maxWithdraw, 0, "Nothing to withdraw");

        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        // Build and execute withdraw hook
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxWithdraw, false);
        Execution[] memory executions = withdrawHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "withdraw failed");

        uint256 usdcAfter = IERC20(USDC).balanceOf(user);
        assertEq(usdcAfter - usdcBefore, maxWithdraw, "Incorrect withdraw amount");
        assertEq(vault.maxWithdraw(user), 0, "maxWithdraw not zeroed");
    }

    function test_fork_Withdraw_Inspect() public view {
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e6), false);
        bytes memory inspected = withdrawHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect wrong");
    }

    function test_fork_Withdraw_ReplaceCalldataAmounts() public view {
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1), false);
        uint256 newAmount = 5e7;
        bytes memory replaced = withdrawHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(withdrawHook.decodeAmounts(replaced)[0], newAmount, "replace failed");
    }

    function test_fork_Withdraw_HookType_Outflow() public view {
        assertEq(uint256(withdrawHook.hookType()), 2, "hookType wrong");
    }

    function test_fork_Withdraw_RevertsOnZeroClaimable() public {
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e6), false);
        Execution[] memory executions = withdrawHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertFalse(success, "Should revert when no claimable amount");
    }

    /*//////////////////////////////////////////////////////////////
            CANCEL DEPOSIT REQUEST HOOK: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_CancelDeposit_RealVault() public {
        uint256 depositAmount = 1e8;
        _fundAndRequestDeposit(depositAmount);

        assertGt(vault.pendingDepositRequest(0, user), 0, "No pending deposit to cancel");

        // Build and execute cancel deposit hook
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        Execution[] memory executions = cancelDepositHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "cancelDepositRequest failed");

        assertTrue(investmentManager.pendingCancelDepositRequest(CENTRIFUGE_USDC_VAULT, user), "Cancel not pending");
    }

    function test_fork_CancelDeposit_Inspect() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        bytes memory inspected = cancelDepositHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect wrong");
    }

    function test_fork_CancelDeposit_HookType_Nonaccounting() public view {
        assertEq(uint256(cancelDepositHook.hookType()), 0, "hookType wrong");
    }

    function test_fork_CancelDeposit_RevertsOnNoRequest() public {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        Execution[] memory executions = cancelDepositHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertFalse(success, "Should revert when no pending deposit");
    }

    /*//////////////////////////////////////////////////////////////
            CANCEL REDEEM REQUEST HOOK: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_CancelRedeem_RealVault() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "User has no shares");

        // Request redeem
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);
        assertGt(vault.pendingRedeemRequest(0, user), 0, "No pending redeem to cancel");

        // Build and execute cancel redeem hook
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        Execution[] memory executions = cancelRedeemHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "cancelRedeemRequest failed");

        assertTrue(investmentManager.pendingCancelRedeemRequest(CENTRIFUGE_USDC_VAULT, user), "Cancel not pending");
    }

    function test_fork_CancelRedeem_Inspect() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        bytes memory inspected = cancelRedeemHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect wrong");
    }

    function test_fork_CancelRedeem_RevertsOnNoRequest() public {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        Execution[] memory executions = cancelRedeemHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertFalse(success, "Should revert when no pending redeem");
    }

    /*//////////////////////////////////////////////////////////////
        CLAIM CANCEL DEPOSIT REQUEST HOOK: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_ClaimCancelDeposit_RealVault() public {
        uint256 depositAmount = 1e8;
        _fundAndRequestDeposit(depositAmount);

        // Cancel the deposit
        vm.prank(user);
        vault.cancelDepositRequest(0, user);

        // Fulfill the cancel (simulating Centrifuge chain processing)
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(depositAmount)
        );

        assertGt(investmentManager.claimableCancelDepositRequest(CENTRIFUGE_USDC_VAULT, user), 0, "Nothing claimable");

        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        // Build and execute claim cancel deposit hook
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user);
        Execution[] memory executions = claimCancelDepositHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "claimCancelDepositRequest failed");

        uint256 usdcAfter = IERC20(USDC).balanceOf(user);
        assertEq(usdcAfter - usdcBefore, depositAmount, "Incorrect claim amount");
    }

    function test_fork_ClaimCancelDeposit_Inspect() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user);
        bytes memory inspected = claimCancelDepositHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT, user), "inspect wrong");
    }

    function test_fork_ClaimCancelDeposit_IsAsyncCancelHook_Inflow() public view {
        assertEq(uint256(claimCancelDepositHook.isAsyncCancelHook()), 1, "cancel type wrong");
    }

    /*//////////////////////////////////////////////////////////////
        CLAIM CANCEL REDEEM REQUEST HOOK: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_ClaimCancelRedeem_RealVault() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "User has no shares");

        // Request and cancel redeem
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);
        vm.prank(user);
        vault.cancelRedeemRequest(0, user);

        // Fulfill the cancel
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelRedeemRequest(poolId, trancheId, user, assetId, uint128(userShares));

        assertGt(investmentManager.claimableCancelRedeemRequest(CENTRIFUGE_USDC_VAULT, user), 0, "Nothing claimable");

        uint256 sharesBefore = IERC20(vault.share()).balanceOf(user);

        // Build and execute claim cancel redeem hook
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user);
        Execution[] memory executions = claimCancelRedeemHook.build(address(0), user, hookData);

        _whitelistUser(user);
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "claimCancelRedeemRequest failed");

        uint256 sharesAfter = IERC20(vault.share()).balanceOf(user);
        assertGt(sharesAfter, sharesBefore, "User did not receive shares back");
        assertEq(sharesAfter - sharesBefore, userShares, "Shares returned mismatch");
    }

    function test_fork_ClaimCancelRedeem_Inspect() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user);
        bytes memory inspected = claimCancelRedeemHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT, user), "inspect wrong");
    }

    function test_fork_ClaimCancelRedeem_IsAsyncCancelHook_Outflow() public view {
        assertEq(uint256(claimCancelRedeemHook.isAsyncCancelHook()), 2, "cancel type wrong");
    }

    /*//////////////////////////////////////////////////////////////
            SET OPERATOR HOOK: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_SetOperator_Approve() public {
        address operator = makeAddr("operator");

        // Verify not operator before
        assertFalse(vault.isOperator(user, operator), "Should not be operator initially");

        // Build and execute setOperator hook (approve)
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, operator, true);
        Execution[] memory executions = setOperatorHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "setOperator(true) failed");

        assertTrue(vault.isOperator(user, operator), "Operator not approved");
    }

    function test_fork_SetOperator_ApproveAndRevoke() public {
        address operator = makeAddr("operator");

        // Approve
        bytes memory approveData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, operator, true);
        Execution[] memory approveExecs = setOperatorHook.build(address(0), user, approveData);
        vm.prank(user);
        (bool s1,) = approveExecs[1].target.call(approveExecs[1].callData);
        assertTrue(s1, "approve failed");
        assertTrue(vault.isOperator(user, operator), "Not approved");

        // Revoke
        bytes memory revokeData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, operator, false);
        Execution[] memory revokeExecs = setOperatorHook.build(address(0), user, revokeData);
        vm.prank(user);
        (bool s2,) = revokeExecs[1].target.call(revokeExecs[1].callData);
        assertTrue(s2, "revoke failed");
        assertFalse(vault.isOperator(user, operator), "Still operator after revoke");
    }

    function test_fork_SetOperator_Inspect() public {
        address operator = makeAddr("operator");
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, operator, true);
        bytes memory inspected = setOperatorHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect wrong");
    }

    function test_fork_SetOperator_HookType_Nonaccounting() public view {
        assertEq(uint256(setOperatorHook.hookType()), 0, "hookType wrong");
    }

    /*//////////////////////////////////////////////////////////////
            ALL HOOKS: Target real vault address
    //////////////////////////////////////////////////////////////*/

    function test_fork_AllHooks_TargetRealVault() public {
        Execution[] memory execs;

        // RequestDeposit
        bytes memory reqDepData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(1e6), false);
        execs = requestDepositHook.build(address(0), user, reqDepData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "requestDeposit target wrong");

        // Deposit (uses oracleId)
        bytes memory depData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e6), false);
        execs = depositHook.build(address(0), user, depData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "deposit target wrong");

        // RequestRedeem
        bytes memory reqRedData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(1e18), false);
        execs = requestRedeemHook.build(address(0), user, reqRedData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "requestRedeem target wrong");

        // Cancel hooks
        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        execs = cancelDepositHook.build(address(0), user, cancelData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "cancelDeposit target wrong");

        execs = cancelRedeemHook.build(address(0), user, cancelData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "cancelRedeem target wrong");

        // ClaimCancel hooks
        bytes memory claimCancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user);
        execs = claimCancelDepositHook.build(address(0), user, claimCancelData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "claimCancelDeposit target wrong");

        execs = claimCancelRedeemHook.build(address(0), user, claimCancelData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "claimCancelRedeem target wrong");

        // SetOperator
        address operator = makeAddr("operator");
        bytes memory opData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, operator, true);
        execs = setOperatorHook.build(address(0), user, opData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "setOperator target wrong");
    }

    /*//////////////////////////////////////////////////////////////
                        ORACLE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_fork_Oracle_Decimals() public view {
        // USDC has 6 decimals; Centrifuge tranche shares inherit ERC20 decimals
        uint8 dec = oracle.decimals(CENTRIFUGE_USDC_VAULT);
        // Centrifuge tranche shares typically 18 decimals
        assertGt(dec, 0, "decimals must be > 0");
    }

    function test_fork_Oracle_GetPricePerShare() public view {
        uint256 pps = oracle.getPricePerShare(CENTRIFUGE_USDC_VAULT);
        // PPS = convertToAssets(10^decimals), should be non-zero
        assertGt(pps, 0, "PPS must be > 0");
    }

    function test_fork_Oracle_GetTVL() public view {
        uint256 tvl = oracle.getTVL(CENTRIFUGE_USDC_VAULT);
        // Centrifuge USDC vault has real TVL at fork block
        assertGt(tvl, 0, "TVL must be > 0");
    }

    function test_fork_Oracle_GetShareOutput() public view {
        uint256 assets = 1e6; // 1 USDC
        uint256 shares = oracle.getShareOutput(CENTRIFUGE_USDC_VAULT, address(0), assets);
        // shares = convertToShares(1 USDC), should be ~1e18 for a fresh vault
        assertGt(shares, 0, "getShareOutput must be > 0");
    }

    function test_fork_Oracle_GetAssetOutput() public view {
        // Use oracle.decimals() to get one full share unit
        uint8 dec = oracle.decimals(CENTRIFUGE_USDC_VAULT);
        uint256 oneShare = 10 ** dec;
        uint256 assets = oracle.getAssetOutput(CENTRIFUGE_USDC_VAULT, address(0), oneShare);
        // convertToAssets(10^decimals) should equal getPricePerShare
        assertEq(assets, oracle.getPricePerShare(CENTRIFUGE_USDC_VAULT), "getAssetOutput mismatch");
    }

    function test_fork_Oracle_GetWithdrawalShareOutput_CeilRounding() public view {
        uint256 assets = 1e6; // 1 USDC
        uint256 withdrawalShares = oracle.getWithdrawalShareOutput(CENTRIFUGE_USDC_VAULT, address(0), assets);
        uint256 depositShares = oracle.getShareOutput(CENTRIFUGE_USDC_VAULT, address(0), assets);
        // Withdrawal uses ceil rounding, so shares >= deposit shares
        assertGe(withdrawalShares, depositShares, "Withdrawal shares must be >= deposit shares");
    }

    function test_fork_Oracle_GetBalanceOfOwner_AfterDeposit() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 shares = oracle.getBalanceOfOwner(CENTRIFUGE_USDC_VAULT, user);
        assertGt(shares, 0, "User should have shares after deposit");
        assertEq(shares, IERC20(vault.share()).balanceOf(user), "Oracle shares mismatch");
    }

    function test_fork_Oracle_GetBalanceOfOwner_ZeroBeforeDeposit() public view {
        uint256 shares = oracle.getBalanceOfOwner(CENTRIFUGE_USDC_VAULT, user);
        assertEq(shares, 0, "User should have 0 shares before deposit");
    }

    function test_fork_Oracle_GetTVLByOwnerOfShares_HeldShares() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 tvl = oracle.getTVLByOwnerOfShares(CENTRIFUGE_USDC_VAULT, user);
        assertGt(tvl, 0, "TVL must be > 0 after deposit");
        // TVL should approximate depositAmount (within vault rounding)
        assertApproxEqAbs(tvl, depositAmount, 1, "TVL should be ~depositAmount");
    }

    function test_fork_Oracle_GetAsyncStateBreakdown_PendingDeposit() public {
        uint256 depositAmount = 1e8;
        _fundAndRequestDeposit(depositAmount);

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, user);

        assertEq(heldValue, 0, "No held shares yet");
        assertEq(pendingRedeemValue, 0, "No pending redeem");
        assertEq(claimableRedeemValue, 0, "No claimable redeem");
        assertEq(pendingDepositValue, depositAmount, "pendingDepositValue wrong");
        assertEq(claimableDepositValue, 0, "No claimable deposit yet");
    }

    function test_fork_Oracle_GetAsyncStateBreakdown_ClaimableDeposit() public {
        uint256 depositAmount = 1e8;
        _fundAndRequestDeposit(depositAmount);

        // Fulfill deposit
        uint256 expectedShares = vault.convertToShares(depositAmount);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(expectedShares)
        );

        (,,,, uint256 claimableDepositValue) = oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, user);
        assertGt(claimableDepositValue, 0, "claimableDeposit must be > 0 after fulfillment");
        assertApproxEqAbs(claimableDepositValue, depositAmount, 1, "claimableDeposit ~= depositAmount");
    }

    function test_fork_Oracle_GetAsyncStateBreakdown_PendingRedeem() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);

        // Request redeem
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, user);

        assertEq(heldValue, 0, "Shares locked in redeem, no held");
        assertGt(pendingRedeemValue, 0, "pendingRedeemValue must be > 0");
        assertEq(claimableRedeemValue, 0, "No claimable redeem yet");
        assertEq(pendingDepositValue, 0, "No pending deposit");
        // After full deposit flow, at most 1 wei of rounding dust remains in claimable deposit
        assertLe(claimableDepositValue, 1, "No claimable deposit after full flow");
    }

    function test_fork_Oracle_GetAsyncStateBreakdown_ClaimableRedeem() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);

        // Request redeem + fulfill
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );

        (, uint256 pendingRedeemValue, uint256 claimableRedeemValue,,) =
            oracle.getAsyncStateBreakdown(CENTRIFUGE_USDC_VAULT, user);

        assertEq(pendingRedeemValue, 0, "No pending redeem after fulfillment");
        assertGt(claimableRedeemValue, 0, "claimableRedeemValue must be > 0 after fulfillment");
        // Centrifuge vault may have up to 2 wei of rounding difference on claimable redeem
        assertApproxEqAbs(claimableRedeemValue, depositAmount, 2, "claimableRedeem ~= depositAmount");
    }

    function test_fork_Oracle_GetTVLByOwnerOfShares_ZeroForFreshUser() public {
        address freshUser = makeAddr("fresh_user");
        uint256 tvl = oracle.getTVLByOwnerOfShares(CENTRIFUGE_USDC_VAULT, freshUser);
        assertEq(tvl, 0, "Fresh user TVL must be 0");
    }

    function test_fork_Oracle_RequestId_IsZero() public view {
        assertEq(oracle.REQUEST_ID(), 0, "REQUEST_ID must be 0");
    }

    /*//////////////////////////////////////////////////////////////
            FULL LIFECYCLE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Full deposit lifecycle: requestDeposit → fulfill → deposit (claim shares)
    function test_fork_FullDepositLifecycle() public {
        uint256 depositAmount = 2e8; // 200 USDC

        deal(USDC, user, depositAmount);
        assertEq(IERC20(USDC).balanceOf(user), depositAmount);

        // Step 1: requestDeposit via hook
        vm.startPrank(user);
        IERC20(USDC).approve(CENTRIFUGE_USDC_VAULT, depositAmount);
        bytes memory reqData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, depositAmount, false);
        Execution[] memory reqExecs = requestDepositHook.build(address(0), user, reqData);
        (bool s1,) = reqExecs[1].target.call(reqExecs[1].callData);
        vm.stopPrank();
        assertTrue(s1, "requestDeposit failed");
        assertGt(vault.pendingDepositRequest(0, user), 0, "No pending deposit");

        // Step 2: Fulfill (off-chain Centrifuge processing simulated)
        uint256 expectedShares = vault.convertToShares(depositAmount);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(expectedShares)
        );
        assertGt(vault.maxDeposit(user), 0, "Nothing claimable after fulfillment");

        // Step 3: deposit via hook (claim shares)
        uint256 maxDeposit = vault.maxDeposit(user);
        bytes memory depData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxDeposit, false);
        Execution[] memory depExecs = depositHook.build(address(0), user, depData);
        vm.prank(user);
        (bool s2,) = depExecs[1].target.call(depExecs[1].callData);
        assertTrue(s2, "deposit failed");

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "User should have shares");
        // Centrifuge vault may leave 1 wei of rounding dust in claimable deposit
        assertLe(vault.maxDeposit(user), 1, "maxDeposit has more than rounding dust");
    }

    /// @notice Full outflow lifecycle: deposit → requestRedeem → fulfill → redeem
    function test_fork_FullRedeemLifecycle() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        // Step 1: requestRedeem via hook
        bytes memory reqRedData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, userShares, false);
        Execution[] memory reqRedExecs = requestRedeemHook.build(address(0), user, reqRedData);
        vm.prank(user);
        (bool s1,) = reqRedExecs[1].target.call(reqRedExecs[1].callData);
        assertTrue(s1, "requestRedeem failed");
        assertGt(vault.pendingRedeemRequest(0, user), 0, "No pending redeem");

        // Step 2: Fulfill
        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );
        assertGt(vault.maxRedeem(user), 0, "Nothing redeemable after fulfillment");

        // Step 3: redeem via hook
        uint256 maxRedeem = vault.maxRedeem(user);
        bytes memory redData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxRedeem, false);
        Execution[] memory redExecs = redeemHook.build(address(0), user, redData);
        vm.prank(user);
        (bool s2,) = redExecs[1].target.call(redExecs[1].callData);
        assertTrue(s2, "redeem failed");

        assertGt(IERC20(USDC).balanceOf(user), usdcBefore, "No USDC received");
        assertEq(vault.maxRedeem(user), 0, "maxRedeem not zeroed");
    }

    /// @notice Full outflow lifecycle using withdraw hook instead of redeem
    function test_fork_FullWithdrawLifecycle() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);

        // Request redeem + fulfill
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);
        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );

        uint256 maxWithdraw = vault.maxWithdraw(user);
        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        // Withdraw via hook
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxWithdraw, false);
        Execution[] memory executions = withdrawHook.build(address(0), user, hookData);
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "withdraw failed");

        assertEq(IERC20(USDC).balanceOf(user) - usdcBefore, maxWithdraw, "Withdraw amount wrong");
        assertEq(vault.maxWithdraw(user), 0, "maxWithdraw not zeroed");
    }

    /// @notice Full cancel deposit lifecycle: requestDeposit → cancel → fulfill cancel → claim
    function test_fork_FullCancelDepositLifecycle() public {
        uint256 depositAmount = 2e8;

        deal(USDC, user, depositAmount);

        // Step 1: Request deposit
        vm.startPrank(user);
        IERC20(USDC).approve(CENTRIFUGE_USDC_VAULT, depositAmount);
        vault.requestDeposit(depositAmount, user, user);
        vm.stopPrank();
        assertEq(IERC20(USDC).balanceOf(user), 0, "USDC not transferred");

        // Step 2: Cancel via hook
        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        Execution[] memory cancelExecs = cancelDepositHook.build(address(0), user, cancelData);
        vm.prank(user);
        (bool s1,) = cancelExecs[1].target.call(cancelExecs[1].callData);
        assertTrue(s1, "cancel failed");
        assertTrue(investmentManager.pendingCancelDepositRequest(CENTRIFUGE_USDC_VAULT, user), "Cancel not pending");

        // Step 3: Fulfill cancel
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(depositAmount)
        );
        assertGt(investmentManager.claimableCancelDepositRequest(CENTRIFUGE_USDC_VAULT, user), 0, "Nothing claimable");

        // Step 4: Claim via hook
        bytes memory claimData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user);
        Execution[] memory claimExecs = claimCancelDepositHook.build(address(0), user, claimData);
        vm.prank(user);
        (bool s2,) = claimExecs[1].target.call(claimExecs[1].callData);
        assertTrue(s2, "claim failed");

        assertEq(IERC20(USDC).balanceOf(user), depositAmount, "User did not get all USDC back");
    }

    /// @notice Full cancel redeem lifecycle: deposit → requestRedeem → cancel → fulfill cancel → claim shares
    function test_fork_FullCancelRedeemLifecycle() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "No shares");

        // Step 1: Request redeem
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);
        assertEq(IERC20(vault.share()).balanceOf(user), 0, "Shares not locked");

        // Step 2: Cancel via hook
        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        Execution[] memory cancelExecs = cancelRedeemHook.build(address(0), user, cancelData);
        vm.prank(user);
        (bool s1,) = cancelExecs[1].target.call(cancelExecs[1].callData);
        assertTrue(s1, "cancel failed");

        // Step 3: Fulfill cancel
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelRedeemRequest(poolId, trancheId, user, assetId, uint128(userShares));

        // Step 4: Claim via hook
        bytes memory claimData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user);
        Execution[] memory claimExecs = claimCancelRedeemHook.build(address(0), user, claimData);
        _whitelistUser(user);
        vm.prank(user);
        (bool s2,) = claimExecs[1].target.call(claimExecs[1].callData);
        assertTrue(s2, "claim failed");

        assertEq(IERC20(vault.share()).balanceOf(user), userShares, "User did not get all shares back");
    }

    /// @notice Regression (receiver != account): a receiver holding a pre-existing real share
    ///         balance must not inflate the amount the claim hook reports. Pre-fix the hook
    ///         snapshotted the account in _preExecute but measured the receiver in _postExecute,
    ///         publishing `receiverPre + claimed - accountPre` (over-reporting by the receiver's
    ///         pre-balance) — which a downstream usePrevHookAmount consumer would move out of the
    ///         account. Post-fix it reports exactly the claimed shares.
    function test_fork_ClaimCancelRedeem_ReceiverPreBalanceDoesNotInflateReport() public {
        address receiver = makeAddr("centrifuge_receiver");
        _whitelistUser(receiver);

        // account (user) acquires shares, then seeds the receiver with a genuine pre-balance
        _fullDepositFlow(1e8);
        address share = vault.share();
        uint256 total = IERC20(share).balanceOf(user);
        uint256 receiverPre = total / 4;
        assertGt(receiverPre, 0, "need a non-zero receiver pre-balance");

        vm.prank(user);
        IERC20(share).transfer(receiver, receiverPre);
        uint256 toRedeem = IERC20(share).balanceOf(user); // == total - receiverPre

        // request redeem → cancel → fulfill cancel, so `toRedeem` shares become claimable to receiver
        vm.prank(user);
        vault.requestRedeem(toRedeem, user, user);
        assertEq(IERC20(share).balanceOf(user), 0, "shares not locked");

        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        Execution[] memory cancelExecs = cancelRedeemHook.build(address(0), user, cancelData);
        vm.prank(user);
        (bool sc,) = cancelExecs[1].target.call(cancelExecs[1].callData);
        assertTrue(sc, "cancel failed");

        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelRedeemRequest(poolId, trancheId, user, assetId, uint128(toRedeem));

        // drive the real claim through the hook: preExecute → claim (delivers to receiver) → postExecute
        bytes memory claimData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, receiver);
        Execution[] memory claimExecs = claimCancelRedeemHook.build(address(0), user, claimData);

        uint256 receiverBefore = IERC20(share).balanceOf(receiver);

        vm.prank(user);
        claimCancelRedeemHook.preExecute(address(0), user, claimData);
        vm.prank(user);
        (bool s2,) = claimExecs[1].target.call(claimExecs[1].callData);
        assertTrue(s2, "claim failed");
        vm.prank(user);
        claimCancelRedeemHook.postExecute(address(0), user, claimData);

        uint256 actuallyClaimed = IERC20(share).balanceOf(receiver) - receiverBefore;
        assertEq(actuallyClaimed, toRedeem, "sanity: receiver received the claimed shares");

        // the hook must report exactly the claimed shares, NOT receiverPre + claimed
        assertEq(
            claimCancelRedeemHook.getOutAmount(user),
            actuallyClaimed,
            "reported amount inflated by receiver pre-balance"
        );
        assertEq(claimCancelRedeemHook.getOutToken(user), share, "outToken must be the share token, not unset asset");
    }

    /*//////////////////////////////////////////////////////////////
        APPROVE AND REQUEST DEPOSIT HOOK
    //////////////////////////////////////////////////////////////*/

    /// @notice Full approve-and-requestDeposit sequence: approve(0) → approve(amount) → requestDeposit →
    /// approve(0)
    function test_fork_ApproveAndRequestDeposit_RealVault() public {
        uint256 depositAmount = 1e8; // 100 USDC

        deal(USDC, user, depositAmount);

        // Calldata: placeholder(32) | yieldSource(20) | token(20) | amount(32) | usePrevHookAmount(1)
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, USDC, depositAmount, false);
        Execution[] memory executions = approveAndRequestDepositHook.build(address(0), user, hookData);
        // build() produces: [0]=preExecute, [1]=approve(0), [2]=approve(amount), [3]=requestDeposit, [4]=approve(0),
        // [5]=postExecute

        vm.startPrank(user);
        (bool s1,) = executions[1].target.call(executions[1].callData);
        (bool s2,) = executions[2].target.call(executions[2].callData);
        (bool s3,) = executions[3].target.call(executions[3].callData);
        (bool s4,) = executions[4].target.call(executions[4].callData);
        vm.stopPrank();

        assertTrue(s1, "approve(0) failed");
        assertTrue(s2, "approve(amount) failed");
        assertTrue(s3, "requestDeposit failed");
        assertTrue(s4, "approve(0) reset failed");

        assertGt(vault.pendingDepositRequest(0, user), 0, "No pending deposit");
        // Allowance must be reset to 0 after hook sequence
        assertEq(IERC20(USDC).allowance(user, CENTRIFUGE_USDC_VAULT), 0, "Allowance not reset to 0");
    }

    function test_fork_ApproveAndRequestDeposit_Inspect() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, USDC, uint256(1e6), false);
        bytes memory inspected = approveAndRequestDepositHook.inspect(hookData);
        // inspect() returns abi.encodePacked(yieldSource, token)
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT, USDC), "inspect wrong");
    }

    function test_fork_ApproveAndRequestDeposit_DecodeAmounts() public view {
        uint256 amount = 5e7;
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, USDC, amount, false);
        assertEq(approveAndRequestDepositHook.decodeAmounts(hookData)[0], amount, "decodeAmounts wrong");
    }

    function test_fork_ApproveAndRequestDeposit_ReplaceCalldataAmounts() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, USDC, uint256(1e6), false);
        uint256 newAmount = 2e8;
        bytes memory replaced = approveAndRequestDepositHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(approveAndRequestDepositHook.decodeAmounts(replaced)[0], newAmount, "replace failed");
    }

    function test_fork_ApproveAndRequestDeposit_DecodeUsePrevHookAmount_False() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, USDC, uint256(1e6), false);
        assertFalse(approveAndRequestDepositHook.decodeUsePrevHookAmount(hookData));
    }

    function test_fork_ApproveAndRequestDeposit_DecodeUsePrevHookAmount_True() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, USDC, uint256(1e6), true);
        assertTrue(approveAndRequestDepositHook.decodeUsePrevHookAmount(hookData));
    }

    function test_fork_ApproveAndRequestDeposit_HookType_Nonaccounting() public view {
        assertEq(uint256(approveAndRequestDepositHook.hookType()), 0, "hookType should be NONACCOUNTING=0");
    }

    function test_fork_ApproveAndRequestDeposit_BuildLength() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, USDC, uint256(1e6), false);
        Execution[] memory executions = approveAndRequestDepositHook.build(address(0), user, hookData);
        // 4 internal executions + 2 (preExecute + postExecute) = 6
        assertEq(executions.length, 6, "Expected 6 executions");
    }

    function test_fork_ApproveAndRequestDeposit_PendingDepositAmount() public {
        uint256 depositAmount = 1e8;
        deal(USDC, user, depositAmount);

        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, USDC, depositAmount, false);
        Execution[] memory executions = approveAndRequestDepositHook.build(address(0), user, hookData);

        vm.startPrank(user);
        for (uint256 i = 1; i <= 4; i++) {
            (bool success,) = executions[i].target.call(executions[i].callData);
            assertTrue(success, "execution failed");
        }
        vm.stopPrank();

        assertEq(vault.pendingDepositRequest(0, user), depositAmount, "Pending deposit amount mismatch");
    }

    /*//////////////////////////////////////////////////////////////
            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_fork_ApproveAndRequestDeposit_VaryingAmounts(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1e6, 1e10); // 1 USDC to 10k USDC

        deal(USDC, user, depositAmount);
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, USDC, depositAmount, false);
        Execution[] memory executions = approveAndRequestDepositHook.build(address(0), user, hookData);

        vm.startPrank(user);
        for (uint256 i = 1; i <= 4; i++) {
            (bool success,) = executions[i].target.call(executions[i].callData);
            assertTrue(success, "execution failed");
        }
        vm.stopPrank();

        assertEq(vault.pendingDepositRequest(0, user), depositAmount, "Pending deposit wrong");
        assertEq(IERC20(USDC).allowance(user, CENTRIFUGE_USDC_VAULT), 0, "Allowance not reset");
    }

    /*//////////////////////////////////////////////////////////////
            ORIGINAL FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_fork_RequestDeposit_VaryingAmounts(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1e6, 1e10); // 1 USDC to 10k USDC

        deal(USDC, user, depositAmount);
        vm.startPrank(user);
        IERC20(USDC).approve(CENTRIFUGE_USDC_VAULT, depositAmount);

        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, depositAmount, false);
        Execution[] memory executions = requestDepositHook.build(address(0), user, hookData);
        (bool success,) = executions[1].target.call(executions[1].callData);
        vm.stopPrank();

        assertTrue(success, "requestDeposit failed");
        assertEq(vault.pendingDepositRequest(0, user), depositAmount, "Pending deposit wrong");
    }

    function testFuzz_fork_FullRedeemCycle(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1e6, 1e10);
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "No shares");

        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );

        uint256 maxRedeem = vault.maxRedeem(user);
        assertGt(maxRedeem, 0, "Nothing to redeem");

        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxRedeem, false);
        Execution[] memory executions = redeemHook.build(address(0), user, hookData);

        uint256 usdcBefore = IERC20(USDC).balanceOf(user);
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "redeem failed");

        assertGt(IERC20(USDC).balanceOf(user), usdcBefore, "No USDC received");
        assertEq(vault.maxRedeem(user), 0, "maxRedeem not zeroed");
    }

    function testFuzz_fork_FullCancelDepositCycle(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1e6, 1e10);
        _fundAndRequestDeposit(depositAmount);

        // Cancel
        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        Execution[] memory cancelExecs = cancelDepositHook.build(address(0), user, cancelData);
        vm.prank(user);
        (bool s1,) = cancelExecs[1].target.call(cancelExecs[1].callData);
        assertTrue(s1, "cancel failed");

        // Fulfill cancel
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(depositAmount)
        );

        // Claim
        bytes memory claimData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user);
        Execution[] memory claimExecs = claimCancelDepositHook.build(address(0), user, claimData);
        vm.prank(user);
        (bool s2,) = claimExecs[1].target.call(claimExecs[1].callData);
        assertTrue(s2, "claim failed");

        assertEq(IERC20(USDC).balanceOf(user), depositAmount, "Did not get all USDC back");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _whitelistUser(address account) internal {
        address share = vault.share();
        address hook = ITranche(share).hook();
        RestrictionManagerLike restrictionManager = RestrictionManagerLike(hook);
        vm.prank(restrictionManager.root());
        restrictionManager.updateMember(share, account, type(uint64).max);
    }

    function _fundAndRequestDeposit(uint256 depositAmount) internal {
        deal(USDC, user, depositAmount);
        vm.startPrank(user);
        IERC20(USDC).approve(CENTRIFUGE_USDC_VAULT, depositAmount);
        vault.requestDeposit(depositAmount, user, user);
        vm.stopPrank();
    }

    /// @dev Full deposit flow: fund → requestDeposit → fulfillDeposit → deposit (claim shares)
    function _fullDepositFlow(uint256 depositAmount) internal {
        _fundAndRequestDeposit(depositAmount);

        uint256 expectedShares = vault.convertToShares(depositAmount);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(expectedShares)
        );

        uint256 maxDeposit = vault.maxDeposit(user);
        vm.prank(user);
        vault.deposit(maxDeposit, user, user);
    }
}
