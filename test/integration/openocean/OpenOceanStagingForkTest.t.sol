// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SwapOpenOceanHook } from "../../../src/hooks/swappers/openocean/SwapOpenOceanHook.sol";
import {
    ApproveAndSwapOpenOceanHook
} from "../../../src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol";
import { IOpenOceanCaller } from "../../../src/vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../../../src/vendor/openocean/IOpenOceanExchange.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";
import { SwapCalldataLayout } from "../../../src/libraries/SwapCalldataLayout.sol";

interface IWFLR {
    function deposit() external payable;
}

/// @notice Minimal account that can call hooks and execute returned operations
contract ForkTestAccount {
    error EXECUTION_FAILED(uint256 index, bytes returnData);

    receive() external payable { }

    function wrapNative(address wrappedNative_, uint256 amount_) external {
        IWFLR(wrappedNative_).deposit{ value: amount_ }();
    }

    function executeHook(
        address hook_,
        address prevHook_,
        bytes calldata data_
    )
        external
        returns (uint256 outAmount)
    {
        ISuperHook(hook_).setExecutionContext(address(this));
        Execution[] memory executions = ISuperHook(hook_).build(prevHook_, address(this), data_);

        for (uint256 i; i < executions.length; ++i) {
            (bool success, bytes memory returnData) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) revert EXECUTION_FAILED(i, returnData);
        }

        ISuperHook(hook_).resetExecutionState(address(this));
        outAmount = ISuperHookResult(hook_).getOutAmount(address(this));
    }

    /// @notice Call build() only (no execution) to verify data decoding succeeds
    /// @dev Leaves execution context set; caller should use vm.snapshotState/revertToState
    function buildOnly(
        address hook_,
        address prevHook_,
        bytes calldata data_
    )
        external
        returns (Execution[] memory)
    {
        ISuperHook(hook_).setExecutionContext(address(this));
        return ISuperHook(hook_).build(prevHook_, address(this), data_);
    }
}

/// @title OpenOceanStagingForkTest
/// @notice Tests the DEPLOYED staging OpenOcean hooks on a Flare fork to verify payload encoding.
/// @dev Run: forge test --match-contract OpenOceanStagingForkTest -vvv
contract OpenOceanStagingForkTest is Test {
    string internal constant FLARE_RPC = "https://flare-api.flare.network/ext/C/rpc";

    // Deployed staging addresses on Flare
    SwapOpenOceanHook internal constant SWAP_HOOK =
        SwapOpenOceanHook(0x5a63D68Ac167bD5e8E02676C8FfdFf14669a87EB);
    ApproveAndSwapOpenOceanHook internal constant APPROVE_SWAP_HOOK =
        ApproveAndSwapOpenOceanHook(0xB0E29f98c54A1FCe144b9ED0e0De690381556830);

    address internal constant OPENOCEAN_ROUTER = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;
    address internal constant OPENOCEAN_REFERRER = 0x0E24b0F342F034446Ec814281AD1a7653cBd85e9;

    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant WFLR = 0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d;
    address internal constant SPRK = 0x657097cC15fdEc9e383dB8628B57eA4a763F2ba0;

    // A known OpenOcean caller on Flare (the aggregation executor)
    address internal constant OO_CALLER = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;

    ForkTestAccount internal account;

    function setUp() public {
        vm.createSelectFork(FLARE_RPC);
        account = new ForkTestAccount();
    }

    // ─── SwapOpenOceanHook ───────────────────────────────────────────────

    /// @notice Verify that build() succeeds when payload = abi.encode(txData)
    function test_SwapHook_BuildSucceeds_WithAbiEncodedPayload() public {
        bytes memory txData = _buildMockSwapTxData(address(0), SPRK, 1 ether, 900e18);
        bytes memory hookData = _buildSwapHookData(
            address(0), // inputToken (native)
            SPRK, // outputToken
            1 ether, // inputAmount
            900e18, // outputQuote
            900e18, // outputMin
            false, // usePrevHookAmount
            abi.encode(txData) // payload = abi.encode(txData)
        );

        // Should NOT revert - the hook decodes abi.encode(txData) via abi.decode(payload, (bytes))
        uint256 snap = vm.snapshotState();
        Execution[] memory executions = account.buildOnly(address(SWAP_HOOK), address(0), hookData);
        assertGt(executions.length, 0, "should produce executions");
        vm.revertToState(snap);
    }

    /// @notice Verify that build() REVERTS when payload = raw txData (not abi-encoded)
    function test_SwapHook_BuildReverts_WithRawPayload() public {
        bytes memory txData = _buildMockSwapTxData(address(0), SPRK, 1 ether, 900e18);
        bytes memory hookData = _buildSwapHookData(
            address(0), // inputToken (native)
            SPRK, // outputToken
            1 ether, // inputAmount
            900e18, // outputQuote
            900e18, // outputMin
            false, // usePrevHookAmount
            txData // payload = raw txData (NOT abi-encoded) - should fail
        );

        // Should REVERT - abi.decode(rawTxData, (bytes)) is invalid
        uint256 snap = vm.snapshotState();
        vm.expectRevert();
        account.buildOnly(address(SWAP_HOOK), address(0), hookData);
        vm.revertToState(snap);
    }

    // ─── ApproveAndSwapOpenOceanHook ─────────────────────────────────────

    /// @notice Verify that build() succeeds when payload = abi.encode(txData)
    function test_ApproveAndSwapHook_BuildSucceeds_WithAbiEncodedPayload() public {
        bytes memory txData = _buildMockSwapTxData(WFLR, SPRK, 1 ether, 900e18);
        bytes memory hookData = _buildSwapHookData(
            WFLR, // inputToken
            SPRK, // outputToken
            1 ether, // inputAmount
            900e18, // outputQuote
            900e18, // outputMin
            false, // usePrevHookAmount
            abi.encode(txData) // payload = abi.encode(txData)
        );

        uint256 snap = vm.snapshotState();
        Execution[] memory executions = account.buildOnly(address(APPROVE_SWAP_HOOK), address(0), hookData);
        assertGt(executions.length, 0, "should produce executions");
        vm.revertToState(snap);
    }

    /// @notice Verify that build() REVERTS when payload = raw txData (not abi-encoded)
    function test_ApproveAndSwapHook_BuildReverts_WithRawPayload() public {
        bytes memory txData = _buildMockSwapTxData(WFLR, SPRK, 1 ether, 900e18);
        bytes memory hookData = _buildSwapHookData(
            WFLR, // inputToken
            SPRK, // outputToken
            1 ether, // inputAmount
            900e18, // outputQuote
            900e18, // outputMin
            false, // usePrevHookAmount
            txData // payload = raw txData (NOT abi-encoded)
        );

        uint256 snap = vm.snapshotState();
        vm.expectRevert();
        account.buildOnly(address(APPROVE_SWAP_HOOK), address(0), hookData);
        vm.revertToState(snap);
    }

    // ─── Full E2E: native swap via deployed SwapOpenOceanHook ────────────

    /// @notice End-to-end: fund account with FLR, swap via deployed hook, receive SPRK
    function test_SwapHook_E2E_NativeSwapOnDeployedHook() public {
        uint256 inputAmount = 100 ether;

        // Build a real OpenOcean swap txData for native FLR → SPRK
        // Use the router as the caller (standard for Flare OO)
        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](0);
        IOpenOceanExchange.SwapDescription memory desc = IOpenOceanExchange.SwapDescription({
            srcToken: IERC20(address(0)),
            dstToken: IERC20(SPRK),
            srcReceiver: payable(OO_CALLER),
            dstReceiver: payable(address(account)),
            amount: inputAmount,
            minReturnAmount: 1,
            guaranteedAmount: 1,
            flags: 0,
            referrer: OPENOCEAN_REFERRER,
            permit: ""
        });
        bytes memory txData =
            abi.encodePacked(IOpenOceanExchange.swap.selector, abi.encode(IOpenOceanCaller(OO_CALLER), desc, calls));

        bytes memory hookData = _buildSwapHookData(
            address(0), SPRK, inputAmount, 1, 1, false, abi.encode(txData)
        );

        // Fund the account
        vm.deal(address(account), inputAmount);

        uint256 sprkBefore = IERC20(SPRK).balanceOf(address(account));

        // Execute — this may revert due to empty calls array / liquidity,
        // but the DATA DECODING must succeed. If it reverts, it should be
        // from the router execution, not from abi.decode in the hook.
        try account.executeHook(address(SWAP_HOOK), address(0), hookData) returns (uint256 outAmount) {
            uint256 sprkAfter = IERC20(SPRK).balanceOf(address(account));
            assertGt(sprkAfter - sprkBefore, 0, "no SPRK received");
            assertEq(outAmount, sprkAfter - sprkBefore, "hook output mismatch");
        } catch (bytes memory reason) {
            // If it reverts, it must be from router execution (index 0), NOT from data decoding
            // The ForkTestAccount wraps execution failures with EXECUTION_FAILED(index, returnData)
            bytes4 executionFailedSelector = ForkTestAccount.EXECUTION_FAILED.selector;
            bytes4 actualSelector;
            assembly {
                actualSelector := mload(add(reason, 32))
            }
            assertEq(
                actualSelector,
                executionFailedSelector,
                "revert was NOT from execution - likely payload decoding failed"
            );
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────

    /// @notice Build hook data with the standard 10-field swap header
    function _buildSwapHookData(
        address inputToken_,
        address outputToken_,
        uint256 inputAmount_,
        uint256 outputQuote_,
        uint256 outputMin_,
        bool usePrevHookAmount_,
        bytes memory payload_
    )
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            bytes32(0), // [0..31]   placeholder0
            bytes20(address(0)), // [32..51]  placeholder1
            bytes20(inputToken_), // [52..71]  inputToken
            bytes20(outputToken_), // [72..91]  outputToken
            bytes32(inputAmount_), // [92..123] inputAmount
            bytes32(outputQuote_), // [124..155] outputQuote
            bytes32(outputMin_), // [156..187] outputMin
            bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), // [188] usePrevHookAmount
            bytes32(payload_.length), // [189..220] payloadLength
            payload_ // [221..]   payload
        );
    }

    /// @notice Build a mock OpenOcean swap txData with proper function signature
    function _buildMockSwapTxData(
        address srcToken_,
        address dstToken_,
        uint256 amount_,
        uint256 minReturn_
    )
        private
        view
        returns (bytes memory)
    {
        IOpenOceanExchange.SwapDescription memory desc = IOpenOceanExchange.SwapDescription({
            srcToken: IERC20(srcToken_),
            dstToken: IERC20(dstToken_),
            srcReceiver: payable(OO_CALLER),
            dstReceiver: payable(address(account)),
            amount: amount_,
            minReturnAmount: minReturn_,
            guaranteedAmount: minReturn_,
            flags: 0,
            referrer: OPENOCEAN_REFERRER,
            permit: ""
        });

        IOpenOceanCaller.CallDescription[] memory calls = new IOpenOceanCaller.CallDescription[](0);

        return abi.encodePacked(
            IOpenOceanExchange.swap.selector, abi.encode(IOpenOceanCaller(OO_CALLER), desc, calls)
        );
    }
}
