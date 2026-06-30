// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DepositWETHHook } from "../../../src/hooks/tokens/weth/DepositWETHHook.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title FlareDepositWFLRE2E
/// @notice Fork integration tests for DepositWETHHook deployed with WFLR address on Flare mainnet
/// @dev DepositWETHHook is generic: deploying it with WFLR calls WFLR.deposit() (same ABI as WETH.deposit()).
///      No new contract is needed — same bytecode, different constructor arg.
///      Note: vm.deal() on WFLR breaks its governance tracking (updateAtTokenTransfer), so these
///      tests use vm.deal() on native FLR and let the hook do the wrapping.
contract FlareDepositWFLRE2E is Test, Constants {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant FLARE_RPC_URL_KEY = "FLARE_RPC_URL";

    uint256 public constant WRAP_AMOUNT = 100 ether; // 100 FLR

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    DepositWETHHook public depositWFLRHook;

    address public account;
    uint256 public forkId;

    /*//////////////////////////////////////////////////////////////
                               SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString(FLARE_RPC_URL_KEY));

        account = address(this);

        // Deploy DepositWETHHook with WFLR — WFLR.deposit() has the same ABI as WETH.deposit()
        depositWFLRHook = new DepositWETHHook(FLARE_WFLR);
    }

    // Required to receive native FLR
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    function _encodeHookData(uint256 amount, bool usePrevHookAmount) internal pure returns (bytes memory) {
        return abi.encodePacked(amount, usePrevHookAmount);
    }

    /// @dev Execute all hook executions sequentially, return true if all succeed
    function _tryExecuteAll(Execution[] memory executions) internal returns (bool) {
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) return false;
        }
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                               TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice WETH immutable is set to WFLR at construction time
    function test_Constructor_WFLRAddress() public view {
        assertEq(depositWFLRHook.WETH(), FLARE_WFLR, "WETH immutable should be set to WFLR");
    }

    /// @notice Wrap 100 native FLR into 100 WFLR using an absolute amount in hook data
    function test_E2E_WrapFLR_to_WFLR_AbsoluteAmount() public {
        vm.deal(account, WRAP_AMOUNT);

        bytes memory hookData = _encodeHookData(WRAP_AMOUNT, false);

        uint256 flrBefore = account.balance;
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(account);

        Execution[] memory executions = depositWFLRHook.build(address(0), account, hookData);
        assertEq(executions.length, 3, "pre + deposit + post");

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "FLR->WFLR wrap should succeed");

        uint256 flrAfter = account.balance;
        uint256 wflrAfter = IERC20(FLARE_WFLR).balanceOf(account);

        assertEq(flrBefore - flrAfter, WRAP_AMOUNT, "native FLR should decrease by wrap amount");
        assertEq(wflrAfter - wflrBefore, WRAP_AMOUNT, "WFLR balance should increase by wrap amount");
        assertEq(depositWFLRHook.getOutAmount(account), WRAP_AMOUNT, "outAmount should equal wrapped amount");
        assertEq(depositWFLRHook.getOutToken(account), FLARE_WFLR, "outToken should be WFLR");

        console2.log("FLR wrapped:", WRAP_AMOUNT);
        console2.log("WFLR received:", wflrAfter - wflrBefore);
    }

    /// @notice usePrevHookAmount=true reads the wrap amount from the previous hook's outAmount
    /// @dev Models the hook chaining case: prevHook produces native FLR amount, DepositWFLRHook wraps it
    function test_E2E_WrapFLR_to_WFLR_UsePrevHookAmount() public {
        uint256 prevAmount = 50 ether;
        vm.deal(account, prevAmount);

        MockHook mockPrevHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, FLARE_WFLR);
        mockPrevHook.setOutAmount(prevAmount, account);

        // Amount in data (WRAP_AMOUNT) is overridden by prevHook's outAmount when usePrevHookAmount=true
        bytes memory hookData = _encodeHookData(WRAP_AMOUNT, true);

        uint256 flrBefore = account.balance;
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(account);

        Execution[] memory executions = depositWFLRHook.build(address(mockPrevHook), account, hookData);
        assertEq(executions.length, 3, "pre + deposit + post");

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "FLR->WFLR wrap via usePrevHookAmount should succeed");

        uint256 flrAfter = account.balance;
        uint256 wflrAfter = IERC20(FLARE_WFLR).balanceOf(account);

        assertEq(flrBefore - flrAfter, prevAmount, "native FLR should decrease by prevHook's outAmount");
        assertEq(wflrAfter - wflrBefore, prevAmount, "WFLR should increase by prevHook's outAmount, not hookData amount");
        assertEq(depositWFLRHook.getOutAmount(account), prevAmount, "outAmount should reflect prevHook's amount");
        assertEq(depositWFLRHook.getOutToken(account), FLARE_WFLR, "outToken should be WFLR");

        console2.log("FLR wrapped via prevHook outAmount:", prevAmount);
        console2.log("WFLR received:", wflrAfter - wflrBefore);
    }

    /// @notice build() reverts with ZERO_ETH_AMOUNT when amount is 0 and usePrevHookAmount is false
    function test_Build_RevertIf_ZeroAmount() public {
        bytes memory hookData = _encodeHookData(0, false);
        vm.expectRevert(DepositWETHHook.ZERO_ETH_AMOUNT.selector);
        depositWFLRHook.build(address(0), account, hookData);
    }
}
