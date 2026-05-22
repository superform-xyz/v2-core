// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../src/libraries/HookSubTypes.sol";
import { IMorphoVaultV2 } from "../../../src/vendor/morpho/IMorphoVaultV2.sol";
import { ForceDeallocateMorphoHook } from
    "../../../src/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.sol";
import { ApproveAndForceDeallocateMorphoHook } from
    "../../../src/hooks/vaults/metamorpho/ApproveAndForceDeallocateMorphoHook.sol";
import { Constants } from "../../utils/Constants.sol";

/// @notice Minimal interface for reading Morpho Vault V2 state
interface IMorphoVaultV2Read {
    function adapters(uint256 index) external view returns (address);
    function adaptersLength() external view returns (uint256);
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function owner() external view returns (address);
}

/// @notice Minimal interface for adapter
interface IAdapter {
    function realAssets() external view returns (uint256);
}

/// @title ForceDeallocateMorphoHookE2E
/// @notice E2E integration test for ForceDeallocateMorphoHook and ApproveAndForceDeallocateMorphoHook
///         using real Morpho Vault V2 on Ethereum mainnet fork
contract ForceDeallocateMorphoHookE2E is Test, Constants {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Steakhouse Prime USDT vault (0.1% penalty, ~25.1T USDT in adapter)
    address public constant STEAKHOUSE_USDT_VAULT = 0xbeef003C68896c7D2c3c60d363e8d71a49Ab2bf9;
    address public constant STEAKHOUSE_USDT_ADAPTER = 0x1C87feac33E2AD0a81A250fA63db4B1C2687Bb05;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    /// @dev Small USDC vault with 2% penalty (max)
    address public constant MAX_PENALTY_VAULT = 0x8F84557FDb3fF273791D7F89d4b24C22e8001d4a;
    address public constant MAX_PENALTY_ADAPTER = 0xfE4836A682F2434a59199cd8E0C175A9B80E8481;

    /// @dev Alpha USDC Core V2 vault (0% penalty, ~10.8T USDC in adapter)
    address public constant ZERO_PENALTY_VAULT = 0xf1CA44EEa3A4eFFcB195A970a2f1d8553f76F9A1;
    address public constant ZERO_PENALTY_ADAPTER = 0x6040FaBB46aa4F248051C70618E97DEBD4e6f9d5;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @dev Fork block — all vaults and adapters deployed at this block
    uint256 public constant FORK_BLOCK = 25_140_000;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ForceDeallocateMorphoHook public hook;
    ApproveAndForceDeallocateMorphoHook public approveHook;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);
        hook = new ForceDeallocateMorphoHook();
        approveHook = new ApproveAndForceDeallocateMorphoHook();
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), HookSubTypes.MISC);
        assertEq(uint256(approveHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(approveHook.SUB_TYPE(), HookSubTypes.MISC);
    }

    /*//////////////////////////////////////////////////////////////
                        BASE HOOK — HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice Test forceDeallocate build + calldata on a real vault with 0.1% penalty
    function test_ForceDeallocate_SteakhouseUSDT_Build() public {
        uint256 adapterAssets = IAdapter(STEAKHOUSE_USDT_ADAPTER).realAssets();
        require(adapterAssets > 0, "Adapter has no assets");

        uint256 extractAmount = adapterAssets / 10_000;
        require(extractAmount > 0, "Extract amount too small");

        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            STEAKHOUSE_USDT_VAULT,
            STEAKHOUSE_USDT_ADAPTER,
            extractAmount,
            0, // no deadline
            10, // maxPenaltyBps = 0.1% (10 bps)
            false,
            ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3, "Should have 3 executions (pre + hook + post)");

        // Verify calldata encoding
        bytes memory expectedCalldata = abi.encodeCall(
            IMorphoVaultV2.forceDeallocate, (STEAKHOUSE_USDT_ADAPTER, "", extractAmount, account)
        );
        assertEq(executions[1].callData, expectedCalldata, "Calldata should match forceDeallocate encoding");
        assertEq(executions[1].target, STEAKHOUSE_USDT_VAULT, "Target should be vault");
        assertEq(executions[1].value, 0, "Value should be zero");
    }

    /// @notice Test full execution flow: preExecute sets outAmount, mock vault call, postExecute
    function test_ForceDeallocate_ExecutionFlow_OutAmount() public {
        address account = makeAddr("smartAccount");
        uint256 extractAmount = 1e6;

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, extractAmount, 0, 10_000, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        // Mock the vault's forceDeallocate to succeed
        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", extractAmount, account)),
            abi.encode(uint256(0)) // penaltyShares = 0
        );

        _executeAll(executions, account);

        // Verify outAmount was set by _preExecute
        uint256 outAmount = hook.getOutAmount(account);
        assertEq(outAmount, extractAmount, "outAmount should equal extracted assets");
    }

    /// @notice Test forceDeallocate build with zero penalty adapter — verify penalty check passes
    function test_ForceDeallocate_ZeroPenalty_Build() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT,
            ZERO_PENALTY_ADAPTER,
            1e6,
            0,
            0, // maxPenaltyBps = 0 (zero tolerance — passes since penalty IS zero)
            false,
            ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, ZERO_PENALTY_VAULT);
    }

    /// @notice Test full execution flow with zero penalty (mocked vault call)
    function test_ForceDeallocate_ZeroPenalty_Execute() public {
        address account = makeAddr("smartAccount");
        uint256 extractAmount = 1e6;

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, extractAmount, 0, 0, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", extractAmount, account)),
            abi.encode(uint256(0))
        );

        _executeAll(executions, account);
        assertEq(hook.getOutAmount(account), extractAmount, "outAmount should equal extracted assets");
    }

    /// @notice Test forceDeallocate build on max penalty (2%) vault
    function test_ForceDeallocate_MaxPenaltyVault_Build() public {
        uint256 adapterAssets = IAdapter(MAX_PENALTY_ADAPTER).realAssets();
        if (adapterAssets == 0) {
            console2.log("SKIP: Max penalty adapter has no assets");
            return;
        }

        uint256 extractAmount = adapterAssets > 200 ? 100 : adapterAssets / 2;
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            MAX_PENALTY_VAULT, MAX_PENALTY_ADAPTER, extractAmount, 0, 200, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, MAX_PENALTY_VAULT);

        bytes memory expectedCalldata = abi.encodeCall(
            IMorphoVaultV2.forceDeallocate, (MAX_PENALTY_ADAPTER, "", extractAmount, account)
        );
        assertEq(executions[1].callData, expectedCalldata);
    }

    /// @notice Verify execution flow with usePrevHookAmount end-to-end
    function test_ForceDeallocate_ExecutionFlow_UsePrevHookAmount() public {
        address prevHook = makeAddr("prevHook");
        address account = makeAddr("smartAccount");
        uint256 prevAmount = 5e6;

        vm.mockCall(
            prevHook,
            abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account),
            abi.encode(prevAmount)
        );

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 0, 0, 10_000, true, ""
        );

        Execution[] memory executions = hook.build(prevHook, account, data);

        // Mock vault call with prevAmount
        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", prevAmount, account)),
            abi.encode(uint256(0))
        );

        _executeAll(executions, account);
        assertEq(hook.getOutAmount(account), prevAmount, "outAmount should use prevHookAmount");
    }

    /*//////////////////////////////////////////////////////////////
                        BASE HOOK — PENALTY ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that penalty exceeding maxPenaltyBps reverts
    function test_ForceDeallocate_RevertIf_PenaltyTooHigh() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            STEAKHOUSE_USDT_VAULT,
            STEAKHOUSE_USDT_ADAPTER,
            1e6,
            0,
            5, // maxPenaltyBps = 5 (too low for 10 bps penalty)
            false,
            ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ForceDeallocateMorphoHook.PENALTY_TOO_HIGH.selector,
                10, // actual penalty in bps
                5 // max allowed
            )
        );
        hook.build(address(0), account, data);
    }

    /// @notice Test that max penalty (2%) vault works when tolerance is set correctly
    function test_ForceDeallocate_MaxPenaltyVault_WithinTolerance() public {
        uint256 adapterAssets = IAdapter(MAX_PENALTY_ADAPTER).realAssets();

        if (adapterAssets == 0) {
            console2.log("SKIP: Max penalty adapter has no assets");
            return;
        }

        address account = makeAddr("smartAccount");
        deal(MAX_PENALTY_VAULT, account, 1e18);

        bytes memory data = _encodeBaseData(
            MAX_PENALTY_VAULT,
            MAX_PENALTY_ADAPTER,
            adapterAssets / 2,
            0,
            200, // maxPenaltyBps = 200 (2% — exactly the maximum)
            false,
            ""
        );

        // Should not revert (penalty == maxPenaltyBps)
        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /// @notice Test that max penalty vault reverts with slightly lower tolerance
    function test_ForceDeallocate_MaxPenaltyVault_RevertIf_TooLow() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            MAX_PENALTY_VAULT,
            MAX_PENALTY_ADAPTER,
            1e6,
            0,
            199, // maxPenaltyBps = 199 (just below 2% = 200 bps)
            false,
            ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ForceDeallocateMorphoHook.PENALTY_TOO_HIGH.selector,
                200,
                199
            )
        );
        hook.build(address(0), account, data);
    }

    /// @notice Test penalty boundary: maxPenaltyBps exactly equal to actual penalty passes
    function test_ForceDeallocate_PenaltyExactlyEqual() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            STEAKHOUSE_USDT_VAULT,
            STEAKHOUSE_USDT_ADAPTER,
            1e6,
            0,
            10, // maxPenaltyBps = 10 (exactly equal to 10 bps penalty)
            false,
            ""
        );

        // Should NOT revert — penaltyBps == maxPenaltyBps is allowed
        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /// @notice Test penalty zero tolerance on non-zero penalty adapter reverts
    function test_ForceDeallocate_RevertIf_ZeroToleranceOnPenaltyAdapter() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            STEAKHOUSE_USDT_VAULT,
            STEAKHOUSE_USDT_ADAPTER,
            1e6,
            0,
            0, // zero tolerance, but adapter has 10 bps
            false,
            ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ForceDeallocateMorphoHook.PENALTY_TOO_HIGH.selector, 10, 0
            )
        );
        hook.build(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                        BASE HOOK — DEADLINE
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that expired deadline reverts
    function test_ForceDeallocate_RevertIf_DeadlineExpired() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT,
            ZERO_PENALTY_ADAPTER,
            1e6,
            block.timestamp - 1, // expired
            10_000,
            false,
            ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ForceDeallocateMorphoHook.EXPIRED_DEADLINE.selector,
                block.timestamp - 1,
                block.timestamp
            )
        );
        hook.build(address(0), account, data);
    }

    /// @notice Test that future deadline passes
    function test_ForceDeallocate_FutureDeadline() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT,
            ZERO_PENALTY_ADAPTER,
            1e6,
            block.timestamp + 3600, // 1 hour from now
            10_000,
            false,
            ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /// @notice Test that deadline=0 means no check
    function test_ForceDeallocate_ZeroDeadlineMeansNoCheck() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT,
            ZERO_PENALTY_ADAPTER,
            1e6,
            0, // no deadline
            10_000,
            false,
            ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /// @notice Test that deadline exactly equal to block.timestamp passes (not expired)
    function test_ForceDeallocate_DeadlineExactlyNow() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT,
            ZERO_PENALTY_ADAPTER,
            1e6,
            block.timestamp, // exactly now — NOT expired (condition is >)
            10_000,
            false,
            ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                        BASE HOOK — VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_ForceDeallocate_RevertIf_ZeroVault() public {
        bytes memory data = _encodeBaseData(address(0), makeAddr("adapter"), 1e6, 0, 10_000, false, "");

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), makeAddr("account"), data);
    }

    function test_ForceDeallocate_RevertIf_ZeroAdapter() public {
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, address(0), 1e6, 0, 10_000, false, "");

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), makeAddr("account"), data);
    }

    function test_ForceDeallocate_RevertIf_ZeroAssets() public {
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 0, 0, 10_000, false, "");

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), makeAddr("account"), data);
    }

    function test_ForceDeallocate_RevertIf_DataTooShort() public {
        bytes memory shortData = new bytes(100);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), makeAddr("account"), shortData);
    }

    /// @notice Data exactly at MIN_DATA_LENGTH (169 bytes) should work
    function test_ForceDeallocate_MinDataLength() public {
        address account = makeAddr("smartAccount");

        // Build data with empty adapterData — exactly 169 bytes
        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, 0, 10_000, false, ""
        );
        // Verify we built exactly the minimum length
        assertEq(data.length, 169, "Data should be exactly MIN_DATA_LENGTH");

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /// @notice Data at 168 bytes (one byte short) should revert
    function test_ForceDeallocate_RevertIf_DataOneByteTooShort() public {
        // 169 is MIN_DATA_LENGTH, so 168 should fail
        bytes memory shortData = new bytes(168);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), makeAddr("account"), shortData);
    }

    /*//////////////////////////////////////////////////////////////
                        BASE HOOK — usePrevHookAmount
    //////////////////////////////////////////////////////////////*/

    function test_ForceDeallocate_UsePrevHookAmount() public {
        address prevHook = makeAddr("prevHook");
        address account = makeAddr("smartAccount");
        uint256 prevAmount = 5e6;

        vm.mockCall(
            prevHook,
            abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account),
            abi.encode(prevAmount)
        );

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT,
            ZERO_PENALTY_ADAPTER,
            0, // will be replaced by prevHookAmount
            0,
            10_000,
            true,
            ""
        );

        Execution[] memory executions = hook.build(prevHook, account, data);

        // Verify the calldata uses prevAmount
        bytes memory expectedCalldata = abi.encodeCall(
            IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", prevAmount, account)
        );
        assertEq(executions[1].callData, expectedCalldata);
    }

    /// @notice usePrevHookAmount with prevHook = address(0) should revert
    function test_ForceDeallocate_RevertIf_UsePrevHookAmount_ZeroPrevHook() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT,
            ZERO_PENALTY_ADAPTER,
            1e6,
            0,
            10_000,
            true, // usePrevHookAmount = true
            ""
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    /// @notice usePrevHookAmount with zero prevHook amount should revert
    function test_ForceDeallocate_RevertIf_UsePrevHookAmount_ZeroAmount() public {
        address prevHook = makeAddr("prevHook");
        address account = makeAddr("smartAccount");

        vm.mockCall(
            prevHook,
            abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account),
            abi.encode(uint256(0))
        );

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT,
            ZERO_PENALTY_ADAPTER,
            1e6, // this gets overridden to 0
            0,
            10_000,
            true,
            ""
        );

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(prevHook, account, data);
    }

    /*//////////////////////////////////////////////////////////////
                        BASE HOOK — ADAPTER DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that non-empty adapterData is correctly passed through
    function test_ForceDeallocate_WithAdapterData() public {
        address account = makeAddr("smartAccount");
        bytes memory adapterData = abi.encodePacked(uint256(42), address(0xdead));

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT,
            ZERO_PENALTY_ADAPTER,
            1e6,
            0,
            10_000,
            false,
            adapterData
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        bytes memory expectedCalldata = abi.encodeCall(
            IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, adapterData, 1e6, account)
        );
        assertEq(executions[1].callData, expectedCalldata, "adapterData should be passed to forceDeallocate");
    }

    /// @notice Test empty adapterData results in empty bytes
    function test_ForceDeallocate_EmptyAdapterData() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, 0, 10_000, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        bytes memory expectedCalldata = abi.encodeCall(
            IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", 1e6, account)
        );
        assertEq(executions[1].callData, expectedCalldata, "Empty adapterData should produce empty bytes");
    }

    /*//////////////////////////////////////////////////////////////
                    BASE HOOK — DECODE / INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_DecodeUsePrevHookAmount_True() public view {
        bytes memory data =
            _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, 0, 10_000, true, "");
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeUsePrevHookAmount_False() public view {
        bytes memory data =
            _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, 0, 10_000, false, "");
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_Inspect() public view {
        bytes memory data =
            _encodeBaseData(STEAKHOUSE_USDT_VAULT, STEAKHOUSE_USDT_ADAPTER, 1e6, 0, 200, false, "");
        bytes memory result = hook.inspect(data);

        assertEq(result.length, 40, "Inspect should return 40 bytes (vault + adapter)");
        assertEq(BytesLib.toAddress(result, 0), STEAKHOUSE_USDT_VAULT);
        assertEq(BytesLib.toAddress(result, 20), STEAKHOUSE_USDT_ADAPTER);
    }

    /*//////////////////////////////////////////////////////////////
                APPROVE VARIANT — HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    /// @notice Test the approve variant builds 6 executions (pre + 4 hook + post)
    function test_ApproveAndForceDeallocate_Build() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: ""
        }));

        Execution[] memory executions = approveHook.build(address(0), account, data);

        // preExecute + 4 hook executions (zero-approve-action-zero) + postExecute = 6
        assertEq(executions.length, 6, "Should have 6 executions");

        // executions[1] = approve(vault, 0) — zero out
        assertEq(executions[1].target, USDC, "First approve target should be token");
        assertEq(
            executions[1].callData,
            abi.encodeCall(IERC20.approve, (ZERO_PENALTY_VAULT, 0)),
            "First approve should zero allowance"
        );

        // executions[2] = approve(vault, assets) — exact amount
        assertEq(executions[2].target, USDC, "Second approve target should be token");
        assertEq(
            executions[2].callData,
            abi.encodeCall(IERC20.approve, (ZERO_PENALTY_VAULT, 1e6)),
            "Second approve should set exact allowance"
        );

        // executions[3] = forceDeallocate
        assertEq(executions[3].target, ZERO_PENALTY_VAULT, "Action target should be vault");
        bytes memory expectedCalldata = abi.encodeCall(
            IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", 1e6, account)
        );
        assertEq(executions[3].callData, expectedCalldata, "Calldata should match");

        // executions[4] = approve(vault, 0) — cleanup
        assertEq(executions[4].target, USDC, "Cleanup approve target should be token");
        assertEq(
            executions[4].callData,
            abi.encodeCall(IERC20.approve, (ZERO_PENALTY_VAULT, 0)),
            "Cleanup approve should zero allowance"
        );
    }

    /// @notice Test approve variant full execution flow (mocked vault call)
    function test_ApproveAndForceDeallocate_Execute() public {
        uint256 extractAmount = 1e6;
        address account = makeAddr("smartAccount");
        deal(USDC, account, extractAmount * 2);

        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: extractAmount,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: ""
        }));

        Execution[] memory executions = approveHook.build(address(0), account, data);

        // Mock the vault's forceDeallocate to succeed
        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", extractAmount, account)),
            abi.encode(uint256(0))
        );

        _executeAll(executions, account);

        assertEq(approveHook.getOutAmount(account), extractAmount);

        // Verify approval was cleaned up (revoked to 0)
        uint256 allowance = IERC20(USDC).allowance(account, ZERO_PENALTY_VAULT);
        assertEq(allowance, 0, "Allowance should be zeroed after execution");
    }

    /// @notice Test approve variant penalty enforcement
    function test_ApproveAndForceDeallocate_RevertIf_PenaltyTooHigh() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: STEAKHOUSE_USDT_VAULT,
            token: USDT,
            adapter: STEAKHOUSE_USDT_ADAPTER,
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 5,
            usePrevHookAmount: false,
            adapterData: ""
        }));

        vm.expectRevert(
            abi.encodeWithSelector(
                ApproveAndForceDeallocateMorphoHook.PENALTY_TOO_HIGH.selector, 10, 5
            )
        );
        approveHook.build(address(0), account, data);
    }

    /// @notice Test approve variant validation — zero token
    function test_ApproveAndForceDeallocate_RevertIf_ZeroToken() public {
        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: address(0),
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: ""
        }));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveHook.build(address(0), makeAddr("account"), data);
    }

    /// @notice Test approve variant validation — zero vault
    function test_ApproveAndForceDeallocate_RevertIf_ZeroVault() public {
        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: address(0),
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: ""
        }));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveHook.build(address(0), makeAddr("account"), data);
    }

    /// @notice Test approve variant validation — zero adapter
    function test_ApproveAndForceDeallocate_RevertIf_ZeroAdapter() public {
        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: address(0),
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: ""
        }));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveHook.build(address(0), makeAddr("account"), data);
    }

    /// @notice Test approve variant validation — zero assets
    function test_ApproveAndForceDeallocate_RevertIf_ZeroAssets() public {
        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 0,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: ""
        }));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveHook.build(address(0), makeAddr("account"), data);
    }

    /// @notice Test approve variant deadline enforcement
    function test_ApproveAndForceDeallocate_RevertIf_DeadlineExpired() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 1e6,
            deadline: block.timestamp - 1,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: ""
        }));

        vm.expectRevert(
            abi.encodeWithSelector(
                ApproveAndForceDeallocateMorphoHook.EXPIRED_DEADLINE.selector,
                block.timestamp - 1,
                block.timestamp
            )
        );
        approveHook.build(address(0), account, data);
    }

    /// @notice Test approve variant reverts when usePrevHookAmount with prevHook = address(0)
    function test_ApproveAndForceDeallocate_RevertIf_UsePrevHookAmount_ZeroPrevHook() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: true,
            adapterData: ""
        }));

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveHook.build(address(0), account, data);
    }

    /// @notice Test approve variant usePrevHookAmount
    function test_ApproveAndForceDeallocate_UsePrevHookAmount() public {
        address prevHook = makeAddr("prevHook");
        address account = makeAddr("smartAccount");
        uint256 prevAmount = 3e6;

        vm.mockCall(
            prevHook,
            abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account),
            abi.encode(prevAmount)
        );

        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 0,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: true,
            adapterData: ""
        }));

        Execution[] memory executions = approveHook.build(prevHook, account, data);

        // forceDeallocate is executions[3] in the approve variant
        bytes memory expectedCalldata = abi.encodeCall(
            IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", prevAmount, account)
        );
        assertEq(executions[3].callData, expectedCalldata, "Should use prevHookAmount");
    }

    /// @notice Test approve variant inspect returns vault + adapter
    function test_ApproveAndForceDeallocate_Inspect() public view {
        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: STEAKHOUSE_USDT_VAULT,
            token: USDT,
            adapter: STEAKHOUSE_USDT_ADAPTER,
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 200,
            usePrevHookAmount: false,
            adapterData: ""
        }));
        bytes memory result = approveHook.inspect(data);

        assertEq(result.length, 40, "Inspect should return 40 bytes");
        assertEq(BytesLib.toAddress(result, 0), STEAKHOUSE_USDT_VAULT);
        assertEq(BytesLib.toAddress(result, 20), STEAKHOUSE_USDT_ADAPTER);
    }

    /// @notice Test approve variant decodeUsePrevHookAmount
    function test_ApproveAndForceDeallocate_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: true,
            adapterData: ""
        }));
        assertTrue(approveHook.decodeUsePrevHookAmount(data));
    }

    function test_ApproveAndForceDeallocate_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: ""
        }));
        assertFalse(approveHook.decodeUsePrevHookAmount(data));
    }

    /// @notice Test approve variant with non-empty adapterData
    function test_ApproveAndForceDeallocate_WithAdapterData() public {
        address account = makeAddr("smartAccount");
        bytes memory adapterData = abi.encodePacked(uint256(99), address(0xbeef));

        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: adapterData
        }));

        Execution[] memory executions = approveHook.build(address(0), account, data);

        bytes memory expectedCalldata = abi.encodeCall(
            IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, adapterData, 1e6, account)
        );
        assertEq(executions[3].callData, expectedCalldata, "adapterData should be passed through");
    }

    /// @notice Test approve variant data too short
    function test_ApproveAndForceDeallocate_RevertIf_DataTooShort() public {
        bytes memory shortData = new bytes(188);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveHook.build(address(0), makeAddr("account"), shortData);
    }

    /// @notice Approve variant MIN_DATA_LENGTH = 189
    function test_ApproveAndForceDeallocate_MinDataLength() public {
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: 1e6,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: ""
        }));

        assertEq(data.length, 189, "Data should be exactly MIN_DATA_LENGTH for approve variant");

        Execution[] memory executions = approveHook.build(address(0), account, data);
        assertEq(executions.length, 6);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Build_Assets(uint256 assets) public {
        assets = bound(assets, 1, 1e18);
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, assets, 0, 10_000, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    function testFuzz_Build_MaxPenaltyBps(uint256 maxPenaltyBps) public {
        // Steakhouse has 10 bps penalty, so maxPenaltyBps >= 10 should pass
        maxPenaltyBps = bound(maxPenaltyBps, 10, 10_000);
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            STEAKHOUSE_USDT_VAULT, STEAKHOUSE_USDT_ADAPTER, 1e6, 0, maxPenaltyBps, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    function testFuzz_Build_Deadline(uint256 deadline) public {
        // Only future deadlines or 0
        deadline = bound(deadline, block.timestamp, type(uint256).max);
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, deadline, 10_000, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /// @notice Fuzz: expired deadline should always revert
    function testFuzz_Build_RevertIf_DeadlineExpired(uint256 deadline) public {
        deadline = bound(deadline, 1, block.timestamp - 1);
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, deadline, 10_000, false, ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ForceDeallocateMorphoHook.EXPIRED_DEADLINE.selector,
                deadline,
                block.timestamp
            )
        );
        hook.build(address(0), account, data);
    }

    /// @notice Fuzz: penalty below max should always revert for Steakhouse (10 bps)
    function testFuzz_Build_RevertIf_PenaltyTooLow(uint256 maxPenaltyBps) public {
        maxPenaltyBps = bound(maxPenaltyBps, 0, 9);
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            STEAKHOUSE_USDT_VAULT, STEAKHOUSE_USDT_ADAPTER, 1e6, 0, maxPenaltyBps, false, ""
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ForceDeallocateMorphoHook.PENALTY_TOO_HIGH.selector, 10, maxPenaltyBps
            )
        );
        hook.build(address(0), account, data);
    }

    /// @notice Fuzz: approve variant assets
    function testFuzz_ApproveBuild_Assets(uint256 assets) public {
        assets = bound(assets, 1, 1e18);
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeApproveData(ApproveDataParams({
            vault: ZERO_PENALTY_VAULT,
            token: USDC,
            adapter: ZERO_PENALTY_ADAPTER,
            assets: assets,
            deadline: 0,
            maxPenaltyBps: 10_000,
            usePrevHookAmount: false,
            adapterData: ""
        }));

        Execution[] memory executions = approveHook.build(address(0), account, data);
        assertEq(executions.length, 6);
    }

    /// @notice Fuzz: adapterData of varying length
    function testFuzz_Build_AdapterDataLength(uint256 len) public {
        len = bound(len, 0, 256);
        address account = makeAddr("smartAccount");

        bytes memory adapterData = new bytes(len);

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, 0, 10_000, false, adapterData
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Execute all executions as account
    function _executeAll(Execution[] memory executions, address account) internal {
        vm.startPrank(account);
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call(executions[i].callData);
            assertTrue(success, string.concat("Execution ", vm.toString(i), " failed"));
        }
        vm.stopPrank();
    }

    struct BaseDataParams {
        address vault;
        address adapter;
        uint256 assets;
        uint256 deadline;
        uint256 maxPenaltyBps;
        bool usePrevHookAmount;
        bytes adapterData;
    }

    function _encodeBaseData(
        address vault,
        address adapter,
        uint256 assets,
        uint256 deadline,
        uint256 maxPenaltyBps,
        bool usePrevHookAmount,
        bytes memory adapterData
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeBaseDataFromParams(BaseDataParams({
            vault: vault,
            adapter: adapter,
            assets: assets,
            deadline: deadline,
            maxPenaltyBps: maxPenaltyBps,
            usePrevHookAmount: usePrevHookAmount,
            adapterData: adapterData
        }));
    }

    function _encodeBaseDataFromParams(BaseDataParams memory p) internal pure returns (bytes memory) {
        bytes memory head = bytes.concat(
            new bytes(32),
            abi.encodePacked(p.vault),
            abi.encodePacked(p.adapter),
            abi.encode(p.assets)
        );
        return bytes.concat(
            head,
            abi.encode(p.deadline),
            abi.encode(p.maxPenaltyBps),
            abi.encodePacked(p.usePrevHookAmount ? uint8(1) : uint8(0)),
            p.adapterData
        );
    }

    struct ApproveDataParams {
        address vault;
        address token;
        address adapter;
        uint256 assets;
        uint256 deadline;
        uint256 maxPenaltyBps;
        bool usePrevHookAmount;
        bytes adapterData;
    }

    function _encodeApproveData(ApproveDataParams memory p) internal pure returns (bytes memory) {
        bytes memory head = bytes.concat(
            new bytes(32),
            abi.encodePacked(p.vault),
            abi.encodePacked(p.token),
            abi.encodePacked(p.adapter),
            abi.encode(p.assets)
        );
        return bytes.concat(
            head,
            abi.encode(p.deadline),
            abi.encode(p.maxPenaltyBps),
            abi.encodePacked(p.usePrevHookAmount ? uint8(1) : uint8(0)),
            p.adapterData
        );
    }
}
