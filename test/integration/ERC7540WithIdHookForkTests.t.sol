// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// WithId hooks
import { CancelDepositRequestWithId7540Hook } from "../../src/hooks/vaults/7540/CancelDepositRequestWithId7540Hook.sol";
import { CancelRedeemRequestWithId7540Hook } from "../../src/hooks/vaults/7540/CancelRedeemRequestWithId7540Hook.sol";
import {
    ClaimCancelDepositRequestWithId7540Hook
} from "../../src/hooks/vaults/7540/ClaimCancelDepositRequestWithId7540Hook.sol";
import {
    ClaimCancelRedeemRequestWithId7540Hook
} from "../../src/hooks/vaults/7540/ClaimCancelRedeemRequestWithId7540Hook.sol";
import { RedeemWithId7540VaultHook } from "../../src/hooks/vaults/7540/RedeemWithId7540VaultHook.sol";
import { WithdrawWithId7540VaultHook } from "../../src/hooks/vaults/7540/WithdrawWithId7540VaultHook.sol";

// Original hooks (for calldata comparison)
import { CancelDepositRequest7540Hook } from "../../src/hooks/vaults/7540/CancelDepositRequest7540Hook.sol";
import { CancelRedeemRequest7540Hook } from "../../src/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol";
import { ClaimCancelDepositRequest7540Hook } from "../../src/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol";
import { ClaimCancelRedeemRequest7540Hook } from "../../src/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol";
import { Redeem7540VaultHook } from "../../src/hooks/vaults/7540/Redeem7540VaultHook.sol";
import { Withdraw7540VaultHook } from "../../src/hooks/vaults/7540/Withdraw7540VaultHook.sol";

// Vendor
import { IERC7540 } from "../../src/vendor/vaults/7540/IERC7540.sol";
import { IERC7540CancelDeposit, IERC7540CancelRedeem } from "../../src/vendor/standards/ERC7540/IERC7540Vault.sol";

// Centrifuge interfaces
import { RestrictionManagerLike } from "../mocks/centrifuge/IRestrictionManagerLike.sol";
import { IInvestmentManager } from "../mocks/centrifuge/IInvestmentManager.sol";
import { IPoolManager } from "../mocks/centrifuge/IPoolManager.sol";
import { ITranche } from "../mocks/centrifuge/ITranch.sol";

/// @title ERC7540WithIdHookForkTests
/// @notice Fork integration tests for WithId ERC-7540 hooks using real Centrifuge vault on Ethereum mainnet
contract ERC7540WithIdHookForkTests is Test {
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

    // -- WithId hooks --
    CancelDepositRequestWithId7540Hook public cancelDepositWithIdHook;
    CancelRedeemRequestWithId7540Hook public cancelRedeemWithIdHook;
    ClaimCancelDepositRequestWithId7540Hook public claimCancelDepositWithIdHook;
    ClaimCancelRedeemRequestWithId7540Hook public claimCancelRedeemWithIdHook;
    RedeemWithId7540VaultHook public redeemWithIdHook;
    WithdrawWithId7540VaultHook public withdrawWithIdHook;

    // -- Original hooks --
    CancelDepositRequest7540Hook public cancelDepositOriginal;
    CancelRedeemRequest7540Hook public cancelRedeemOriginal;
    ClaimCancelDepositRequest7540Hook public claimCancelDepositOriginal;
    ClaimCancelRedeemRequest7540Hook public claimCancelRedeemOriginal;
    Redeem7540VaultHook public redeemOriginal;
    Withdraw7540VaultHook public withdrawOriginal;

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

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), 21_929_476);

        user = makeAddr("centrifuge_user");
        placeholder = bytes32(keccak256("PLACEHOLDER"));

        vault = IERC7540(CENTRIFUGE_USDC_VAULT);
        investmentManager = IInvestmentManager(INVESTMENT_MANAGER);
        poolManager = IPoolManager(POOL_MANAGER);

        poolId = vault.poolId();
        trancheId = vault.trancheId();
        assetId = poolManager.assetToId(USDC);

        // Whitelist user on Centrifuge tranche
        _whitelistUser(user);

        // Deploy WithId hooks
        cancelDepositWithIdHook = new CancelDepositRequestWithId7540Hook();
        cancelRedeemWithIdHook = new CancelRedeemRequestWithId7540Hook();
        claimCancelDepositWithIdHook = new ClaimCancelDepositRequestWithId7540Hook();
        claimCancelRedeemWithIdHook = new ClaimCancelRedeemRequestWithId7540Hook();
        redeemWithIdHook = new RedeemWithId7540VaultHook();
        withdrawWithIdHook = new WithdrawWithId7540VaultHook();

        // Deploy originals for comparison
        cancelDepositOriginal = new CancelDepositRequest7540Hook();
        cancelRedeemOriginal = new CancelRedeemRequest7540Hook();
        claimCancelDepositOriginal = new ClaimCancelDepositRequest7540Hook();
        claimCancelRedeemOriginal = new ClaimCancelRedeemRequest7540Hook();
        redeemOriginal = new Redeem7540VaultHook();
        withdrawOriginal = new Withdraw7540VaultHook();
    }

    /*//////////////////////////////////////////////////////////////
                    CALLDATA PARITY: WithId(0) == Original
    //////////////////////////////////////////////////////////////*/

    function test_fork_CancelDeposit_CalldataParity() public view {
        bytes memory originalData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        bytes memory withIdData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));

        Execution[] memory originalExecs = cancelDepositOriginal.build(address(0), user, originalData);
        Execution[] memory withIdExecs = cancelDepositWithIdHook.build(address(0), user, withIdData);

        assertEq(originalExecs[1].target, withIdExecs[1].target, "target mismatch");
        assertEq(originalExecs[1].callData, withIdExecs[1].callData, "calldata mismatch");
    }

    function test_fork_CancelRedeem_CalldataParity() public view {
        bytes memory originalData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT);
        bytes memory withIdData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));

        Execution[] memory originalExecs = cancelRedeemOriginal.build(address(0), user, originalData);
        Execution[] memory withIdExecs = cancelRedeemWithIdHook.build(address(0), user, withIdData);

        assertEq(originalExecs[1].target, withIdExecs[1].target, "target mismatch");
        assertEq(originalExecs[1].callData, withIdExecs[1].callData, "calldata mismatch");
    }

    function test_fork_ClaimCancelDeposit_CalldataParity() public view {
        bytes memory originalData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user);
        bytes memory withIdData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(0));

        Execution[] memory originalExecs = claimCancelDepositOriginal.build(address(0), user, originalData);
        Execution[] memory withIdExecs = claimCancelDepositWithIdHook.build(address(0), user, withIdData);

        assertEq(originalExecs[1].target, withIdExecs[1].target, "target mismatch");
        assertEq(originalExecs[1].callData, withIdExecs[1].callData, "calldata mismatch");
    }

    function test_fork_ClaimCancelRedeem_CalldataParity() public view {
        bytes memory originalData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user);
        bytes memory withIdData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(0));

        Execution[] memory originalExecs = claimCancelRedeemOriginal.build(address(0), user, originalData);
        Execution[] memory withIdExecs = claimCancelRedeemWithIdHook.build(address(0), user, withIdData);

        assertEq(originalExecs[1].target, withIdExecs[1].target, "target mismatch");
        assertEq(originalExecs[1].callData, withIdExecs[1].callData, "calldata mismatch");
    }

    /*//////////////////////////////////////////////////////////////
            CANCEL DEPOSIT REQUEST: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_CancelDepositRequestWithId_RealVault() public {
        uint256 depositAmount = 1e8; // 100 USDC

        // Fund user and request deposit
        _fundAndRequestDeposit(depositAmount);

        // Verify pending deposit exists
        uint256 pending = vault.pendingDepositRequest(0, user);
        assertGt(pending, 0, "No pending deposit to cancel");

        // Build cancel hook execution with requestId = 0 (Centrifuge default)
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));
        Execution[] memory executions = cancelDepositWithIdHook.build(address(0), user, hookData);

        // Execute cancel against real vault
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "cancelDepositRequest failed");

        // Verify cancel is pending
        bool isPendingCancel = investmentManager.pendingCancelDepositRequest(CENTRIFUGE_USDC_VAULT, user);
        assertTrue(isPendingCancel, "Cancel not pending");
    }

    /*//////////////////////////////////////////////////////////////
            CANCEL REDEEM REQUEST: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_CancelRedeemRequestWithId_RealVault() public {
        uint256 depositAmount = 1e8;

        // Full deposit flow to get shares
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "User has no shares");

        // Request redeem
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        uint256 pendingRedeem = vault.pendingRedeemRequest(0, user);
        assertGt(pendingRedeem, 0, "No pending redeem to cancel");

        // Build cancel hook execution with requestId = 0
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));
        Execution[] memory executions = cancelRedeemWithIdHook.build(address(0), user, hookData);

        // Execute cancel against real vault
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "cancelRedeemRequest failed");

        bool isPendingCancel = investmentManager.pendingCancelRedeemRequest(CENTRIFUGE_USDC_VAULT, user);
        assertTrue(isPendingCancel, "Cancel not pending");
    }

    /*//////////////////////////////////////////////////////////////
            WITHDRAW WITH ID: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_WithdrawWithId_RealVault() public {
        uint256 depositAmount = 1e8;

        // Full deposit flow
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "User has no shares");

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

        // Build withdraw hook execution with requestId = 0
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxWithdraw, false, uint256(0));
        Execution[] memory executions = withdrawWithIdHook.build(address(0), user, hookData);

        // Execute withdraw against real vault
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "withdraw failed");

        uint256 usdcAfter = IERC20(USDC).balanceOf(user);
        assertGt(usdcAfter, usdcBefore, "User did not receive USDC");
        assertEq(usdcAfter - usdcBefore, maxWithdraw, "Incorrect withdraw amount");
    }

    /*//////////////////////////////////////////////////////////////
            REDEEM WITH ID: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_RedeemWithId_RealVault() public {
        uint256 depositAmount = 1e8;

        // Full deposit flow
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "User has no shares");

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

        // Build redeem hook execution with requestId = 0
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxRedeem, false, uint256(0));
        Execution[] memory executions = redeemWithIdHook.build(address(0), user, hookData);

        // Execute redeem against real vault
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "redeem failed");

        uint256 usdcAfter = IERC20(USDC).balanceOf(user);
        assertGt(usdcAfter, usdcBefore, "User did not receive USDC");
    }

    /*//////////////////////////////////////////////////////////////
        CLAIM CANCEL DEPOSIT REQUEST: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_ClaimCancelDepositRequestWithId_RealVault() public {
        uint256 depositAmount = 1e8;

        // Fund user and request deposit
        _fundAndRequestDeposit(depositAmount);

        // Cancel the deposit request
        vm.prank(user);
        vault.cancelDepositRequest(0, user);

        // Fulfill the cancel (simulating Centrifuge chain processing)
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(depositAmount)
        );

        uint256 claimable = investmentManager.claimableCancelDepositRequest(CENTRIFUGE_USDC_VAULT, user);
        assertGt(claimable, 0, "Nothing to claim");

        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        // Build claim cancel deposit hook execution with requestId = 0
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(0));
        Execution[] memory executions = claimCancelDepositWithIdHook.build(address(0), user, hookData);

        // Execute claim against real vault
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "claimCancelDepositRequest failed");

        uint256 usdcAfter = IERC20(USDC).balanceOf(user);
        assertGt(usdcAfter, usdcBefore, "User did not receive USDC back");
        assertEq(usdcAfter - usdcBefore, depositAmount, "Incorrect claim amount");
    }

    /*//////////////////////////////////////////////////////////////
        CLAIM CANCEL REDEEM REQUEST: Real vault interaction
    //////////////////////////////////////////////////////////////*/

    function test_fork_ClaimCancelRedeemRequestWithId_RealVault() public {
        uint256 depositAmount = 1e8;

        // Full deposit flow to get shares
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "User has no shares");

        // Request redeem
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        // Cancel the redeem request
        vm.prank(user);
        vault.cancelRedeemRequest(0, user);

        // Fulfill the cancel (simulating Centrifuge chain processing)
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelRedeemRequest(poolId, trancheId, user, assetId, uint128(userShares));

        uint256 claimable = investmentManager.claimableCancelRedeemRequest(CENTRIFUGE_USDC_VAULT, user);
        assertGt(claimable, 0, "Nothing to claim");

        uint256 sharesBefore = IERC20(vault.share()).balanceOf(user);

        // Build claim cancel redeem hook execution with requestId = 0
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(0));
        Execution[] memory executions = claimCancelRedeemWithIdHook.build(address(0), user, hookData);

        // Execute claim against real vault
        _whitelistUser(user); // ensure still whitelisted for receiving shares
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "claimCancelRedeemRequest failed");

        uint256 sharesAfter = IERC20(vault.share()).balanceOf(user);
        assertGt(sharesAfter, sharesBefore, "User did not receive shares back");
    }

    /*//////////////////////////////////////////////////////////////
            BUILD TARGETS REAL VAULT ADDRESS
    //////////////////////////////////////////////////////////////*/

    function test_fork_AllHooks_TargetRealVault() public view {
        // Cancel hooks
        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));
        Execution[] memory execs;

        execs = cancelDepositWithIdHook.build(address(0), user, cancelData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "cancelDeposit target wrong");

        execs = cancelRedeemWithIdHook.build(address(0), user, cancelData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "cancelRedeem target wrong");

        // ClaimCancel hooks
        bytes memory claimCancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(0));

        execs = claimCancelDepositWithIdHook.build(address(0), user, claimCancelData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "claimCancelDeposit target wrong");

        execs = claimCancelRedeemWithIdHook.build(address(0), user, claimCancelData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "claimCancelRedeem target wrong");

        // Redeem/Withdraw hooks
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory redeemData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e6), false, uint256(0));

        execs = redeemWithIdHook.build(address(0), user, redeemData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "redeem target wrong");

        execs = withdrawWithIdHook.build(address(0), user, redeemData);
        assertEq(execs[1].target, CENTRIFUGE_USDC_VAULT, "withdraw target wrong");
    }

    /*//////////////////////////////////////////////////////////////
            NON-ZERO REQUEST ID CALLDATA VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function test_fork_NonZeroRequestId_CalldataEncoding() public view {
        uint256 nonZeroRequestId = 12_345;

        // Cancel deposit
        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, nonZeroRequestId);
        Execution[] memory execs = cancelDepositWithIdHook.build(address(0), user, cancelData);
        assertEq(
            execs[1].callData,
            abi.encodeCall(IERC7540CancelDeposit.cancelDepositRequest, (nonZeroRequestId, user)),
            "cancel deposit calldata wrong"
        );

        // Cancel redeem
        execs = cancelRedeemWithIdHook.build(address(0), user, cancelData);
        assertEq(
            execs[1].callData,
            abi.encodeCall(IERC7540CancelRedeem.cancelRedeemRequest, (nonZeroRequestId, user)),
            "cancel redeem calldata wrong"
        );

        // Claim cancel deposit
        bytes memory claimData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, nonZeroRequestId);
        execs = claimCancelDepositWithIdHook.build(address(0), user, claimData);
        assertEq(
            execs[1].callData,
            abi.encodeCall(IERC7540CancelDeposit.claimCancelDepositRequest, (nonZeroRequestId, user, user)),
            "claim cancel deposit calldata wrong"
        );

        // Claim cancel redeem
        execs = claimCancelRedeemWithIdHook.build(address(0), user, claimData);
        assertEq(
            execs[1].callData,
            abi.encodeCall(IERC7540CancelRedeem.claimCancelRedeemRequest, (nonZeroRequestId, user, user)),
            "claim cancel redeem calldata wrong"
        );
    }

    /*//////////////////////////////////////////////////////////////
            PRE/POST EXECUTE: Real vault balance deltas
    //////////////////////////////////////////////////////////////*/

    function test_fork_RedeemWithId_PrePostExecute_BalanceDelta() public {
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

        uint256 maxRedeem = vault.maxRedeem(user);
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxRedeem, false, uint256(0));

        // Pre-execute: snapshot balances
        uint256 usdcBefore = IERC20(USDC).balanceOf(user);
        uint256 claimableBefore = vault.claimableRedeemRequest(0, user);
        assertGt(claimableBefore, 0, "No claimable before redeem");

        // Build and execute
        Execution[] memory executions = redeemWithIdHook.build(address(0), user, hookData);
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "redeem failed");

        // Post-execute: verify deltas
        uint256 usdcAfter = IERC20(USDC).balanceOf(user);
        uint256 claimableAfter = vault.claimableRedeemRequest(0, user);
        assertGt(usdcAfter - usdcBefore, 0, "No USDC received");
        assertEq(claimableAfter, 0, "Claimable not fully consumed");
    }

    function test_fork_WithdrawWithId_PrePostExecute_BalanceDelta() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);

        vm.prank(user);
        vault.requestRedeem(userShares, user, user);
        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );

        uint256 maxWithdraw = vault.maxWithdraw(user);
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxWithdraw, false, uint256(0));

        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        Execution[] memory executions = withdrawWithIdHook.build(address(0), user, hookData);
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "withdraw failed");

        uint256 usdcAfter = IERC20(USDC).balanceOf(user);
        assertEq(usdcAfter - usdcBefore, maxWithdraw, "Withdraw amount mismatch");
        assertEq(vault.maxWithdraw(user), 0, "maxWithdraw not zeroed");
    }

    function test_fork_ClaimCancelDeposit_PrePostExecute_BalanceDelta() public {
        uint256 depositAmount = 5e7; // 50 USDC
        _fundAndRequestDeposit(depositAmount);

        vm.prank(user);
        vault.cancelDepositRequest(0, user);

        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(depositAmount)
        );

        uint256 usdcBefore = IERC20(USDC).balanceOf(user);
        uint256 claimable = investmentManager.claimableCancelDepositRequest(CENTRIFUGE_USDC_VAULT, user);
        assertGt(claimable, 0, "Nothing claimable");

        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(0));
        Execution[] memory executions = claimCancelDepositWithIdHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "claimCancelDeposit failed");

        uint256 usdcAfter = IERC20(USDC).balanceOf(user);
        assertEq(usdcAfter - usdcBefore, depositAmount, "Claimed amount mismatch");
    }

    function test_fork_ClaimCancelRedeem_PrePostExecute_BalanceDelta() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);
        vm.prank(user);
        vault.cancelRedeemRequest(0, user);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelRedeemRequest(poolId, trancheId, user, assetId, uint128(userShares));

        uint256 sharesBefore = IERC20(vault.share()).balanceOf(user);
        uint256 claimable = investmentManager.claimableCancelRedeemRequest(CENTRIFUGE_USDC_VAULT, user);
        assertGt(claimable, 0, "Nothing claimable");

        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(0));
        Execution[] memory executions = claimCancelRedeemWithIdHook.build(address(0), user, hookData);

        _whitelistUser(user);
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "claimCancelRedeem failed");

        uint256 sharesAfter = IERC20(vault.share()).balanceOf(user);
        assertEq(sharesAfter - sharesBefore, userShares, "Shares returned mismatch");
    }

    /*//////////////////////////////////////////////////////////////
            FULL END-TO-END FLOWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit → cancel → fulfill cancel → claim: full lifecycle with balance checks
    function test_fork_FullCancelDepositLifecycle() public {
        uint256 depositAmount = 2e8; // 200 USDC

        uint256 usdcInitial = 0;
        deal(USDC, user, depositAmount);
        assertEq(IERC20(USDC).balanceOf(user), depositAmount, "Initial USDC wrong");

        // Step 1: Request deposit
        vm.startPrank(user);
        IERC20(USDC).approve(CENTRIFUGE_USDC_VAULT, depositAmount);
        vault.requestDeposit(depositAmount, user, user);
        vm.stopPrank();
        assertEq(IERC20(USDC).balanceOf(user), usdcInitial, "USDC not transferred");
        assertGt(vault.pendingDepositRequest(0, user), 0, "No pending deposit");

        // Step 2: Cancel via WithId hook
        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));
        Execution[] memory cancelExecs = cancelDepositWithIdHook.build(address(0), user, cancelData);
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

        // Step 4: Claim via WithId hook
        bytes memory claimData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(0));
        Execution[] memory claimExecs = claimCancelDepositWithIdHook.build(address(0), user, claimData);
        vm.prank(user);
        (bool s2,) = claimExecs[1].target.call(claimExecs[1].callData);
        assertTrue(s2, "claim failed");

        // Final: user gets all USDC back
        assertEq(IERC20(USDC).balanceOf(user), depositAmount, "User did not get all USDC back");
    }

    /// @notice Deposit → get shares → request redeem → cancel → fulfill cancel → claim shares: full lifecycle
    function test_fork_FullCancelRedeemLifecycle() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        assertGt(userShares, 0, "No shares");

        // Step 1: Request redeem
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);
        assertEq(IERC20(vault.share()).balanceOf(user), 0, "Shares not locked");
        assertGt(vault.pendingRedeemRequest(0, user), 0, "No pending redeem");

        // Step 2: Cancel via WithId hook
        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));
        Execution[] memory cancelExecs = cancelRedeemWithIdHook.build(address(0), user, cancelData);
        vm.prank(user);
        (bool s1,) = cancelExecs[1].target.call(cancelExecs[1].callData);
        assertTrue(s1, "cancel failed");

        // Step 3: Fulfill cancel
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelRedeemRequest(poolId, trancheId, user, assetId, uint128(userShares));

        // Step 4: Claim via WithId hook
        bytes memory claimData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(0));
        Execution[] memory claimExecs = claimCancelRedeemWithIdHook.build(address(0), user, claimData);
        _whitelistUser(user);
        vm.prank(user);
        (bool s2,) = claimExecs[1].target.call(claimExecs[1].callData);
        assertTrue(s2, "claim failed");

        // Final: user gets all shares back
        assertEq(IERC20(vault.share()).balanceOf(user), userShares, "User did not get all shares back");
    }

    /// @notice Regression (receiver != account): a receiver holding a pre-existing real share
    ///         balance must not inflate the amount the WithId claim hook reports. Pre-fix the hook
    ///         snapshotted the account in _preExecute but measured the receiver in _postExecute,
    ///         publishing `receiverPre + claimed - accountPre`. Post-fix it reports exactly the
    ///         claimed shares and publishes the share token (not the unset inherited `asset`).
    function test_fork_ClaimCancelRedeemWithId_ReceiverPreBalanceDoesNotInflateReport() public {
        address receiver = makeAddr("centrifuge_receiver");
        _whitelistUser(receiver);

        _fullDepositFlow(1e8);
        address share = vault.share();
        uint256 total = IERC20(share).balanceOf(user);
        uint256 receiverPre = total / 4;
        assertGt(receiverPre, 0, "need a non-zero receiver pre-balance");

        vm.prank(user);
        IERC20(share).transfer(receiver, receiverPre);
        uint256 toRedeem = IERC20(share).balanceOf(user); // == total - receiverPre

        vm.prank(user);
        vault.requestRedeem(toRedeem, user, user);
        assertEq(IERC20(share).balanceOf(user), 0, "shares not locked");

        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));
        Execution[] memory cancelExecs = cancelRedeemWithIdHook.build(address(0), user, cancelData);
        vm.prank(user);
        (bool sc,) = cancelExecs[1].target.call(cancelExecs[1].callData);
        assertTrue(sc, "cancel failed");

        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelRedeemRequest(poolId, trancheId, user, assetId, uint128(toRedeem));

        // claim WithId data layout: placeholder | vault | receiver | requestId
        bytes memory claimData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, receiver, uint256(0));
        Execution[] memory claimExecs = claimCancelRedeemWithIdHook.build(address(0), user, claimData);

        uint256 receiverBefore = IERC20(share).balanceOf(receiver);

        vm.prank(user);
        claimCancelRedeemWithIdHook.preExecute(address(0), user, claimData);
        vm.prank(user);
        (bool s2,) = claimExecs[1].target.call(claimExecs[1].callData);
        assertTrue(s2, "claim failed");
        vm.prank(user);
        claimCancelRedeemWithIdHook.postExecute(address(0), user, claimData);

        uint256 actuallyClaimed = IERC20(share).balanceOf(receiver) - receiverBefore;
        assertEq(actuallyClaimed, toRedeem, "sanity: receiver received the claimed shares");

        assertEq(
            claimCancelRedeemWithIdHook.getOutAmount(user),
            actuallyClaimed,
            "reported amount inflated by receiver pre-balance"
        );
        assertEq(
            claimCancelRedeemWithIdHook.getOutToken(user), share, "outToken must be the share token, not unset asset"
        );
    }

    /// @notice Deposit → get shares → request redeem → fulfill → redeem: full outflow lifecycle
    function test_fork_FullRedeemLifecycle() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        // Request redeem
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        // Fulfill
        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );

        // Redeem via WithId hook
        uint256 maxRedeem = vault.maxRedeem(user);
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxRedeem, false, uint256(0));
        Execution[] memory executions = redeemWithIdHook.build(address(0), user, hookData);
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "redeem failed");

        // Final state checks
        uint256 usdcAfter = IERC20(USDC).balanceOf(user);
        assertGt(usdcAfter, usdcBefore, "No USDC received");
        assertEq(vault.maxRedeem(user), 0, "maxRedeem not zeroed");
        // maxWithdraw may have rounding dust (1 wei) due to Centrifuge vault's convertToAssets rounding
        assertLe(vault.maxWithdraw(user), 1, "maxWithdraw has more than rounding dust");
    }

    /*//////////////////////////////////////////////////////////////
            INSPECT AGAINST REAL VAULT
    //////////////////////////////////////////////////////////////*/

    function test_fork_Inspect_CancelDeposit_ReturnsRealVaultAddress() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(42));
        bytes memory inspected = cancelDepositWithIdHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect mismatch");
    }

    function test_fork_Inspect_CancelRedeem_ReturnsRealVaultAddress() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(42));
        bytes memory inspected = cancelRedeemWithIdHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect mismatch");
    }

    function test_fork_Inspect_ClaimCancelDeposit_ReturnsVaultAndReceiver() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(42));
        bytes memory inspected = claimCancelDepositWithIdHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT, user), "inspect mismatch");
    }

    function test_fork_Inspect_ClaimCancelRedeem_ReturnsVaultAndReceiver() public view {
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(42));
        bytes memory inspected = claimCancelRedeemWithIdHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT, user), "inspect mismatch");
    }

    function test_fork_Inspect_Redeem_ReturnsRealVaultAddress() public view {
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e6), false, uint256(42));
        bytes memory inspected = redeemWithIdHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect mismatch");
    }

    function test_fork_Inspect_Withdraw_ReturnsRealVaultAddress() public view {
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e6), false, uint256(42));
        bytes memory inspected = withdrawWithIdHook.inspect(hookData);
        assertEq(inspected, abi.encodePacked(CENTRIFUGE_USDC_VAULT), "inspect mismatch");
    }

    /*//////////////////////////////////////////////////////////////
            REPLACE CALLDATA + EXECUTE ON REAL VAULT
    //////////////////////////////////////////////////////////////*/

    function test_fork_RedeemWithId_ReplaceCalldataAmounts_ThenExecute() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );

        uint256 maxRedeem = vault.maxRedeem(user);

        // Build with dummy amount, then replace
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1), false, uint256(0));
        bytes memory replaced = redeemWithIdHook.replaceCalldataAmounts(hookData, _singleAmount(maxRedeem));

        // Verify replacement worked
        assertEq(redeemWithIdHook.decodeAmounts(replaced)[0], maxRedeem, "Amount not replaced");

        // Execute with replaced calldata
        Execution[] memory executions = redeemWithIdHook.build(address(0), user, replaced);
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "redeem with replaced amount failed");

        assertEq(vault.maxRedeem(user), 0, "maxRedeem not zeroed after replaced redeem");
    }

    function test_fork_WithdrawWithId_ReplaceCalldataAmounts_ThenExecute() public {
        uint256 depositAmount = 1e8;
        _fullDepositFlow(depositAmount);

        uint256 userShares = IERC20(vault.share()).balanceOf(user);
        vm.prank(user);
        vault.requestRedeem(userShares, user, user);

        uint256 expectedAssets = vault.convertToAssets(userShares);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillRedeemRequest(
            poolId, trancheId, user, assetId, uint128(expectedAssets), uint128(userShares)
        );

        uint256 maxWithdraw = vault.maxWithdraw(user);
        uint256 usdcBefore = IERC20(USDC).balanceOf(user);

        // Build with dummy amount, then replace
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1), false, uint256(0));
        bytes memory replaced = withdrawWithIdHook.replaceCalldataAmounts(hookData, _singleAmount(maxWithdraw));

        assertEq(withdrawWithIdHook.decodeAmounts(replaced)[0], maxWithdraw, "Amount not replaced");

        Execution[] memory executions = withdrawWithIdHook.build(address(0), user, replaced);
        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "withdraw with replaced amount failed");

        assertEq(IERC20(USDC).balanceOf(user) - usdcBefore, maxWithdraw, "Withdraw amount wrong");
    }

    /*//////////////////////////////////////////////////////////////
            DECODE AMOUNT / DECODE USE PREV HOOK AMOUNT
    //////////////////////////////////////////////////////////////*/

    function test_fork_DecodeAmounts_WithRealVaultData() public view {
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        uint256 amount = 5e7; // 50 USDC
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, amount, false, uint256(99));

        assertEq(redeemWithIdHook.decodeAmounts(hookData)[0], amount, "redeem decodeAmount wrong");
        assertEq(withdrawWithIdHook.decodeAmounts(hookData)[0], amount, "withdraw decodeAmount wrong");
        assertFalse(redeemWithIdHook.decodeUsePrevHookAmount(hookData), "redeem usePrevHook should be false");
        assertFalse(withdrawWithIdHook.decodeUsePrevHookAmount(hookData), "withdraw usePrevHook should be false");
    }

    function test_fork_DecodeUsePrevHookAmount_True() public view {
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(0), true, uint256(99));

        assertTrue(redeemWithIdHook.decodeUsePrevHookAmount(hookData), "redeem usePrevHook should be true");
        assertTrue(withdrawWithIdHook.decodeUsePrevHookAmount(hookData), "withdraw usePrevHook should be true");
    }

    /*//////////////////////////////////////////////////////////////
            MULTI-USER: Different users same vault
    //////////////////////////////////////////////////////////////*/

    function test_fork_TwoUsers_IndependentCancelDeposit() public {
        address user2 = makeAddr("centrifuge_user2");
        _whitelistUser(user2);

        uint256 amount1 = 1e8; // 100 USDC
        uint256 amount2 = 2e8; // 200 USDC

        // User 1 deposits
        _fundAndRequestDeposit(amount1);

        // User 2 deposits
        deal(USDC, user2, amount2);
        vm.startPrank(user2);
        IERC20(USDC).approve(CENTRIFUGE_USDC_VAULT, amount2);
        vault.requestDeposit(amount2, user2, user2);
        vm.stopPrank();

        // Both cancel via WithId hook
        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));

        Execution[] memory execs1 = cancelDepositWithIdHook.build(address(0), user, cancelData);
        vm.prank(user);
        (bool s1,) = execs1[1].target.call(execs1[1].callData);
        assertTrue(s1, "user1 cancel failed");

        Execution[] memory execs2 = cancelDepositWithIdHook.build(address(0), user2, cancelData);
        vm.prank(user2);
        (bool s2,) = execs2[1].target.call(execs2[1].callData);
        assertTrue(s2, "user2 cancel failed");

        // Both have pending cancels
        assertTrue(
            investmentManager.pendingCancelDepositRequest(CENTRIFUGE_USDC_VAULT, user), "user1 cancel not pending"
        );
        assertTrue(
            investmentManager.pendingCancelDepositRequest(CENTRIFUGE_USDC_VAULT, user2), "user2 cancel not pending"
        );
    }

    /*//////////////////////////////////////////////////////////////
            FUZZ: Deposit amounts on real vault
    //////////////////////////////////////////////////////////////*/

    function testFuzz_fork_CancelDeposit_VaryingAmounts(uint256 depositAmount) public {
        // Centrifuge USDC vault - reasonable deposit range
        depositAmount = bound(depositAmount, 1e6, 1e10); // 1 USDC to 10k USDC

        _fundAndRequestDeposit(depositAmount);

        uint256 pending = vault.pendingDepositRequest(0, user);
        assertGt(pending, 0, "No pending deposit");

        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));
        Execution[] memory executions = cancelDepositWithIdHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success, "cancel failed");

        assertTrue(investmentManager.pendingCancelDepositRequest(CENTRIFUGE_USDC_VAULT, user), "Cancel not pending");
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

        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, maxRedeem, false, uint256(0));
        Execution[] memory executions = redeemWithIdHook.build(address(0), user, hookData);

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
        bytes memory cancelData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));
        Execution[] memory cancelExecs = cancelDepositWithIdHook.build(address(0), user, cancelData);
        vm.prank(user);
        (bool s1,) = cancelExecs[1].target.call(cancelExecs[1].callData);
        assertTrue(s1, "cancel failed");

        // Fulfill cancel
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillCancelDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(depositAmount)
        );

        // Claim
        bytes memory claimData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, user, uint256(0));
        Execution[] memory claimExecs = claimCancelDepositWithIdHook.build(address(0), user, claimData);
        vm.prank(user);
        (bool s2,) = claimExecs[1].target.call(claimExecs[1].callData);
        assertTrue(s2, "claim failed");

        assertEq(IERC20(USDC).balanceOf(user), depositAmount, "Did not get all USDC back");
    }

    /*//////////////////////////////////////////////////////////////
            HOOK TYPE / SUB TYPE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function test_fork_HookTypes() public view {
        // Cancel hooks are NONACCOUNTING
        assertEq(uint256(cancelDepositWithIdHook.hookType()), 0, "cancelDeposit type wrong");
        assertEq(uint256(cancelRedeemWithIdHook.hookType()), 0, "cancelRedeem type wrong");
        assertEq(uint256(claimCancelDepositWithIdHook.hookType()), 0, "claimCancelDeposit type wrong");
        assertEq(uint256(claimCancelRedeemWithIdHook.hookType()), 0, "claimCancelRedeem type wrong");

        // Redeem/Withdraw hooks are OUTFLOW
        assertEq(uint256(redeemWithIdHook.hookType()), 2, "redeem type wrong");
        assertEq(uint256(withdrawWithIdHook.hookType()), 2, "withdraw type wrong");
    }

    function test_fork_AsyncCancelTypes() public view {
        // ClaimCancelDeposit is INFLOW cancelation
        assertEq(uint256(claimCancelDepositWithIdHook.isAsyncCancelHook()), 1, "claimCancelDeposit cancel type wrong");
        // ClaimCancelRedeem is OUTFLOW cancelation
        assertEq(uint256(claimCancelRedeemWithIdHook.isAsyncCancelHook()), 2, "claimCancelRedeem cancel type wrong");
    }

    /*//////////////////////////////////////////////////////////////
            REVERT CASES: Real vault reverts
    //////////////////////////////////////////////////////////////*/

    function test_fork_CancelDeposit_RevertsOnNoRequest() public {
        // Try to cancel without having a pending deposit
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));
        Execution[] memory executions = cancelDepositWithIdHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertFalse(success, "Should revert when no pending deposit");
    }

    function test_fork_CancelRedeem_RevertsOnNoRequest() public {
        // Try to cancel without having a pending redeem
        bytes memory hookData = abi.encodePacked(placeholder, CENTRIFUGE_USDC_VAULT, uint256(0));
        Execution[] memory executions = cancelRedeemWithIdHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertFalse(success, "Should revert when no pending redeem");
    }

    function test_fork_Redeem_RevertsOnZeroClaimable() public {
        // Try to redeem without having claimable shares
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e6), false, uint256(0));
        Execution[] memory executions = redeemWithIdHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertFalse(success, "Should revert when no claimable shares");
    }

    function test_fork_Withdraw_RevertsOnZeroClaimable() public {
        bytes32 oracleId = bytes32(keccak256("ORACLE_ID"));
        bytes memory hookData = abi.encodePacked(oracleId, CENTRIFUGE_USDC_VAULT, uint256(1e6), false, uint256(0));
        Execution[] memory executions = withdrawWithIdHook.build(address(0), user, hookData);

        vm.prank(user);
        (bool success,) = executions[1].target.call(executions[1].callData);
        assertFalse(success, "Should revert when no claimable amount");
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

        // Fulfill deposit
        uint256 expectedShares = vault.convertToShares(depositAmount);
        vm.prank(ROOT_MANAGER);
        investmentManager.fulfillDepositRequest(
            poolId, trancheId, user, assetId, uint128(depositAmount), uint128(expectedShares)
        );

        // Claim shares via deposit
        uint256 maxDeposit = vault.maxDeposit(user);
        vm.prank(user);
        vault.deposit(maxDeposit, user, user);
    }
}
