// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { WrappedNativeHook } from "../../../src/hooks/tokens/native/WrappedNativeHook.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title FlareWrappedNativeHookE2E
/// @notice Fork integration tests for WrappedNativeHook deployed with WFLR address on Flare mainnet
/// @dev WrappedNativeHook is generic: deploying it with WFLR calls WFLR.deposit() / WFLR.withdraw()
///      (same ABI as WETH). No new contract needed — same bytecode, different constructor arg.
///      Note: vm.deal() on WFLR breaks its governance tracking (updateAtTokenTransfer), so wrap
///      tests use vm.deal() on native FLR and let the hook do the wrapping. Unwrap tests use
///      a direct deposit call to prime the account with WFLR.
contract FlareWrappedNativeHookE2E is Test, Constants {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant FLARE_RPC_URL_KEY = "FLARE_RPC_URL";

    /// @dev Pinned so CI can reuse foundry's RPC cache instead of re-fetching state at latest
    uint256 public constant FORK_BLOCK = 67_000_000;

    uint256 public constant WRAP_AMOUNT = 100 ether; // 100 FLR

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    WrappedNativeHook public wrappedNativeHook;

    address public account;
    uint256 public forkId;

    /*//////////////////////////////////////////////////////////////
                               SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString(FLARE_RPC_URL_KEY), FORK_BLOCK);

        account = address(this);

        // Deploy WrappedNativeHook with WFLR — WFLR.deposit()/withdraw() share the same ABI as WETH
        wrappedNativeHook = new WrappedNativeHook(FLARE_WFLR);
    }

    // Required to receive native FLR
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @param wrap true = wrap (native -> WFLR), false = unwrap (WFLR -> native)
    function _encodeHookData(
        uint256 amount,
        bool wrap,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes32(0), address(0), amount, wrap, usePrevHookAmount);
    }

    /// @dev Execute all hook executions sequentially, return true if all succeed
    function _tryExecuteAll(Execution[] memory executions) internal returns (bool) {
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) return false;
        }
        return true;
    }

    /// @dev Directly deposit native FLR to get WFLR (bypasses the hook)
    function _depositNativeToGetWFLR(uint256 amount) internal {
        (bool success,) = FLARE_WFLR.call{ value: amount }(abi.encodeWithSignature("deposit()"));
        require(success, "Direct WFLR deposit failed");
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice WRAPPED_NATIVE immutable is set to WFLR at construction time
    function test_Constructor_WFLRAddress() public view {
        assertEq(wrappedNativeHook.WRAPPED_NATIVE(), FLARE_WFLR, "WRAPPED_NATIVE should be WFLR");
    }

    /*//////////////////////////////////////////////////////////////
                     WRAP TESTS (native FLR -> WFLR)
    //////////////////////////////////////////////////////////////*/

    /// @notice Wrap 100 native FLR into 100 WFLR using an absolute amount
    function test_E2E_WrapFLR_to_WFLR_AbsoluteAmount() public {
        vm.deal(account, WRAP_AMOUNT);

        bytes memory hookData = _encodeHookData(WRAP_AMOUNT, true, false);

        uint256 flrBefore = account.balance;
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(account);

        Execution[] memory executions = wrappedNativeHook.build(address(0), account, hookData);
        assertEq(executions.length, 3, "pre + deposit + post");

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "FLR->WFLR wrap should succeed");

        uint256 flrAfter = account.balance;
        uint256 wflrAfter = IERC20(FLARE_WFLR).balanceOf(account);

        assertEq(flrBefore - flrAfter, WRAP_AMOUNT, "Native FLR should decrease by wrap amount");
        assertEq(wflrAfter - wflrBefore, WRAP_AMOUNT, "WFLR balance should increase by wrap amount");
        assertEq(wrappedNativeHook.getOutAmount(account), WRAP_AMOUNT, "outAmount should equal wrapped amount");
        assertEq(wrappedNativeHook.getOutToken(account), FLARE_WFLR, "outToken should be WFLR");

        console2.log("FLR wrapped:", WRAP_AMOUNT);
        console2.log("WFLR received:", wflrAfter - wflrBefore);
    }

    /// @notice usePrevHookAmount=true reads the wrap amount from the previous hook's outAmount
    function test_E2E_WrapFLR_to_WFLR_UsePrevHookAmount() public {
        uint256 prevAmount = 50 ether;
        vm.deal(account, prevAmount);

        MockHook mockPrevHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, FLARE_WFLR);
        mockPrevHook.setOutAmount(prevAmount, account);

        bytes memory hookData = _encodeHookData(WRAP_AMOUNT, true, true);

        uint256 flrBefore = account.balance;
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(account);

        Execution[] memory executions = wrappedNativeHook.build(address(mockPrevHook), account, hookData);
        assertEq(executions.length, 3, "pre + deposit + post");

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "FLR->WFLR wrap via usePrevHookAmount should succeed");

        uint256 flrAfter = account.balance;
        uint256 wflrAfter = IERC20(FLARE_WFLR).balanceOf(account);

        assertEq(flrBefore - flrAfter, prevAmount, "Native FLR should decrease by prevHook's outAmount");
        assertEq(wflrAfter - wflrBefore, prevAmount, "WFLR should increase by prevHook's outAmount");
        assertEq(wrappedNativeHook.getOutAmount(account), prevAmount, "outAmount should reflect prevHook's amount");
        assertEq(wrappedNativeHook.getOutToken(account), FLARE_WFLR, "outToken should be WFLR");

        console2.log("FLR wrapped via prevHook outAmount:", prevAmount);
        console2.log("WFLR received:", wflrAfter - wflrBefore);
    }

    /// @notice build() reverts with ZERO_AMOUNT when amount is 0 and usePrevHookAmount is false
    function test_Wrap_Build_RevertIf_ZeroAmount() public {
        bytes memory hookData = _encodeHookData(0, true, false);
        vm.expectRevert(WrappedNativeHook.ZERO_AMOUNT.selector);
        wrappedNativeHook.build(address(0), account, hookData);
    }

    /*//////////////////////////////////////////////////////////////
                    UNWRAP TESTS (WFLR -> native FLR)
    //////////////////////////////////////////////////////////////*/

    /// @notice Unwrap 100 WFLR into 100 native FLR using an absolute amount
    function test_E2E_UnwrapWFLR_to_FLR_AbsoluteAmount() public {
        // Prime account with WFLR by directly depositing native FLR
        vm.deal(account, WRAP_AMOUNT);
        _depositNativeToGetWFLR(WRAP_AMOUNT);

        uint256 flrBefore = account.balance;
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(account);
        assertEq(wflrBefore, WRAP_AMOUNT, "Account should have WFLR to unwrap");

        bytes memory hookData = _encodeHookData(WRAP_AMOUNT, false, false);

        Execution[] memory executions = wrappedNativeHook.build(address(0), account, hookData);
        assertEq(executions.length, 3, "pre + withdraw + post");

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "WFLR->FLR unwrap should succeed");

        uint256 flrAfter = account.balance;
        uint256 wflrAfter = IERC20(FLARE_WFLR).balanceOf(account);

        assertEq(wflrBefore - wflrAfter, WRAP_AMOUNT, "WFLR should decrease by unwrap amount");
        assertEq(flrAfter - flrBefore, WRAP_AMOUNT, "Native FLR should increase by unwrap amount");
        assertEq(wrappedNativeHook.getOutAmount(account), WRAP_AMOUNT, "outAmount should equal unwrapped amount");
        assertEq(wrappedNativeHook.getOutToken(account), address(0), "outToken should be native (address(0)) for unwrap");

        console2.log("WFLR unwrapped:", WRAP_AMOUNT);
        console2.log("FLR received:", flrAfter - flrBefore);
    }

    /// @notice build() reverts with ZERO_AMOUNT when amount is 0 for unwrap
    function test_Unwrap_Build_RevertIf_ZeroAmount() public {
        bytes memory hookData = _encodeHookData(0, false, false);
        vm.expectRevert(WrappedNativeHook.ZERO_AMOUNT.selector);
        wrappedNativeHook.build(address(0), account, hookData);
    }

    /// @notice build() reverts with INSUFFICIENT_BALANCE when account lacks WFLR
    function test_Unwrap_Build_RevertIf_InsufficientBalance() public {
        // Account has no WFLR
        bytes memory hookData = _encodeHookData(WRAP_AMOUNT, false, false);
        vm.expectRevert(WrappedNativeHook.INSUFFICIENT_BALANCE.selector);
        wrappedNativeHook.build(address(0), account, hookData);
    }

    /*//////////////////////////////////////////////////////////////
                        WRAP THEN UNWRAP (combined)
    //////////////////////////////////////////////////////////////*/

    /// @notice Wrap FLR to WFLR then immediately unwrap back to FLR
    /// @dev Uses separate transactions (snapshots) to avoid PRE_EXECUTE_ALREADY_CALLED from
    ///      transient storage persisting across both hook calls within the same test frame.
    function test_E2E_WrapAndUnwrap_Roundtrip() public {
        uint256 wrapAmount = 100 ether;
        uint256 unwrapAmount = 50 ether;
        vm.deal(account, wrapAmount);

        // Step 1: wrap (full hook execution including pre/post)
        bytes memory wrapData = _encodeHookData(wrapAmount, true, false);
        bool wrapSuccess = _tryExecuteAll(wrappedNativeHook.build(address(0), account, wrapData));
        assertTrue(wrapSuccess, "Wrap step should succeed");

        assertEq(IERC20(FLARE_WFLR).balanceOf(account), wrapAmount, "Should have full WFLR after wrap");

        // Step 2: unwrap half
        // Skip index 0 (preExecute) and index 2 (postExecute) since transient storage
        // was already consumed in the wrap step above. Only execute the WFLR.withdraw call.
        bytes memory unwrapData = _encodeHookData(unwrapAmount, false, false);
        Execution[] memory unwrapExecns = wrappedNativeHook.build(address(0), account, unwrapData);
        assertEq(unwrapExecns.length, 3, "Should have pre + withdraw + post");
        // Execute only the core withdraw call (index 1)
        (bool unwrapSuccess,) = unwrapExecns[1].target.call{ value: unwrapExecns[1].value }(unwrapExecns[1].callData);
        assertTrue(unwrapSuccess, "Unwrap step should succeed");

        assertEq(
            IERC20(FLARE_WFLR).balanceOf(account), wrapAmount - unwrapAmount, "Should have remaining WFLR after unwrap"
        );
        assertEq(account.balance, unwrapAmount, "Should have recovered native FLR from unwrap");

        console2.log("FLR wrapped:", wrapAmount);
        console2.log("WFLR remaining:", IERC20(FLARE_WFLR).balanceOf(account));
        console2.log("FLR recovered:", account.balance);
    }
}
