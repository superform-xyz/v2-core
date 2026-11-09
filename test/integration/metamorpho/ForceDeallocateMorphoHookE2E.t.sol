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
import { Deposit4626VaultHook } from "../../../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { Constants } from "../../utils/Constants.sol";

/// @notice Minimal interface for reading Morpho Vault V2 state
import { HookDataDecoder } from "../../../src/libraries/HookDataDecoder.sol";

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
/// @notice E2E integration test for ForceDeallocateMorphoHook
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

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), FORK_BLOCK);
        // Constructed at MORPHO'S OWN CEILING (2%), not the deploy-script value. These fixtures include
        // MAX_PENALTY_VAULT at exactly 200 bps, so a tighter cap would make the pre-existing max-penalty
        // cases revert on Inv2 rather than exercising what they were written for. The cap's own
        // behaviour is covered by the dedicated Inv2 tests below.
        hook = new ForceDeallocateMorphoHook(0.02e18);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), HookSubTypes.MISC);
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
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, extractAmount, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        // Mock the vault's forceDeallocate to succeed
        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", extractAmount, account)),
            abi.encode(uint256(0)) // penaltyShares = 0
        );

        _executeAll(executions, account);

        // outAmount is ZERO by design: forceDeallocate pays the account nothing, so publishing a
        // non-zero figure would let a successor size a real movement off a phantom receipt.
        assertEq(hook.getOutAmount(account), 0, "outAmount must be 0 - this hook produces nothing");
    }

    /// @notice SUP-21780: outToken is the vault's UNDERLYING, not the vault.
    /// @dev The old value named the vault, i.e. a token that never moves in this operation. Nothing else
    ///      in the repo asserted outToken for this hook, so the previous value was wrong and unobserved.
    function test_ForceDeallocate_OutToken_IsTheUnderlying_NotTheVault() public {
        address account = makeAddr("smartAccount");
        uint256 extractAmount = 1e6;

        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, extractAmount, false, "");
        Execution[] memory executions = hook.build(address(0), account, data);
        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", extractAmount, account)),
            abi.encode(uint256(0))
        );
        _executeAll(executions, account);

        address underlying = IMorphoVaultV2Read(ZERO_PENALTY_VAULT).asset();
        assertEq(hook.getOutToken(account), underlying, "outToken must be asset(), the token that moved");
        assertTrue(hook.getOutToken(account) != ZERO_PENALTY_VAULT, "outToken must not be the vault itself");
    }

    /// @notice THE POINT OF SUP-21780: the first word carries a real oracle id, not a zero-filled
    ///         `placeholder0`.
    /// @dev Without this, nothing on the Solidity side pins the rename the ticket exists for. The hook
    ///      itself never reads offset 0 (it is NONACCOUNTING, so `SuperExecutorBase._updateAccounting`
    ///      never consults the id either) and `inspect()` returns only (yieldSource, adapter) — so an
    ///      encoder that wrote zeros there, or wrote the id at the wrong offset, would leave every other
    ///      test in this file green. This asserts the slot is real and distinct from `yieldSource` at 32.
    function test_ForceDeallocate_OracleIdLivesAtOffsetZero() public view {
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, "");

        assertEq(
            HookDataDecoder.extractYieldSourceOracleId(data),
            TEST_ORACLE_ID,
            "offset 0 must carry the oracle id, not a zero-filled placeholder"
        );
        assertTrue(TEST_ORACLE_ID != bytes32(0), "the fixture must not be vacuous");
        assertEq(
            HookDataDecoder.extractYieldSource(data),
            ZERO_PENALTY_VAULT,
            "offset 32 must still be yieldSource, i.e. the two fields are not conflated"
        );
        assertEq(data.length, 105, "header is exactly 105 bytes");
    }

    /// @notice A NON-EMPTY adapterData tail must survive at the new offset 105, byte for byte.
    /// @dev The tail carries no length prefix, so an off-by-one in the slice would hand the adapter a
    ///      silently corrupted payload rather than fail. The old layout sliced from 169.
    function test_ForceDeallocate_AdapterDataTail_SurvivesAtNewOffset() public {
        address account = makeAddr("smartAccount");
        bytes memory tail = hex"deadbeefcafe0123";

        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, tail);
        assertEq(data.length, 105 + tail.length, "header is 105 bytes, then the raw tail");

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, tail, 1e6, account)),
            "adapterData must reach forceDeallocate unchanged"
        );
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
            MAX_PENALTY_VAULT, MAX_PENALTY_ADAPTER, extractAmount, false, ""
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
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 0, true, ""
        );

        Execution[] memory executions = hook.build(prevHook, account, data);

        // Mock vault call with prevAmount
        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", prevAmount, account)),
            abi.encode(uint256(0))
        );

        _executeAll(executions, account);
        // The hook still CONSUMES the predecessor's amount (that is what usePrevHookAmount means), but
        // it publishes zero onward so nothing can chain off it.
        assertEq(hook.getOutAmount(account), 0, "outAmount must be 0 even when sized from a prev hook");
    }

    /// @notice Test that max penalty (2%) vault works when tolerance is set correctly
    /// @notice SUP-21780: a MAX-PENALTY (2%) vault now builds and executes with no hook-side objection.
    /// @dev Renamed from `_WithinTolerance`, which no longer means anything — there is no tolerance field
    ///      to be within. What is worth pinning is the consequence of deleting it: the hook no longer
    ///      gates on the penalty at all, so the 2% case must go through. If a caller-side bound is ever
    ///      reinstated, THIS is the test that should start failing.
    function test_ForceDeallocate_MaxPenaltyVault_ExecutesWithNoHookSideBound() public {
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
            false,
            ""
        );

        // Must not revert: Morpho's own 2% ceiling is the only bound now
        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                        BASE HOOK — VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_ForceDeallocate_RevertIf_ZeroVault() public {
        bytes memory data = _encodeBaseData(address(0), makeAddr("adapter"), 1e6, false, "");

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), makeAddr("account"), data);
    }

    function test_ForceDeallocate_RevertIf_ZeroAdapter() public {
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, address(0), 1e6, false, "");

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), makeAddr("account"), data);
    }

    function test_ForceDeallocate_RevertIf_ZeroAssets() public {
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 0, false, "");

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), makeAddr("account"), data);
    }

    function test_ForceDeallocate_RevertIf_DataTooShort() public {
        bytes memory shortData = new bytes(100);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), makeAddr("account"), shortData);
    }

    /// @notice Data exactly at MIN_DATA_LENGTH (105 bytes after SUP-21780) should work
    function test_ForceDeallocate_MinDataLength() public {
        address account = makeAddr("smartAccount");

        // Build data with empty adapterData — exactly 105 bytes
        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, ""
        );
        // Verify we built exactly the minimum length
        assertEq(data.length, 105, "Data should be exactly MIN_DATA_LENGTH");

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /// @notice Data at 104 bytes (one byte short) should revert
    /// @dev THIS BOUNDARY MOVED WITH SUP-21780 AND THE OLD VALUE NO LONGER TESTS ANYTHING. It used to be
    ///      `new bytes(168)` against a 169-byte minimum. 168 is now comfortably ABOVE the 105-byte
    ///      minimum, so the length gate would pass, `yieldSource` would decode as address(0), and the test
    ///      would have gone green on `ADDRESS_NOT_VALID` — asserting a different failure than it claims.
    function test_ForceDeallocate_RevertIf_DataOneByteTooShort() public {
        // 105 is MIN_DATA_LENGTH, so 104 should fail
        bytes memory shortData = new bytes(104);

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
            0,
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
            1e6,
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
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, ""
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
            _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, true, "");
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeUsePrevHookAmount_False() public view {
        bytes memory data =
            _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, "");
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_Inspect() public view {
        bytes memory data =
            _encodeBaseData(STEAKHOUSE_USDT_VAULT, STEAKHOUSE_USDT_ADAPTER, 1e6, false, "");
        bytes memory result = hook.inspect(data);

        assertEq(result.length, 40, "Inspect should return 40 bytes (vault + adapter)");
        assertEq(BytesLib.toAddress(result, 0), STEAKHOUSE_USDT_VAULT);
        assertEq(BytesLib.toAddress(result, 20), STEAKHOUSE_USDT_ADAPTER);
    }

    /*//////////////////////////////////////////////////////////////
              NO APPROVAL NEEDED — VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice forceDeallocate succeeds without any token approval
    function test_ForceDeallocate_Execute_NoApproval() public {
        uint256 extractAmount = 1e6;
        address account = makeAddr("smartAccount");
        deal(USDC, account, extractAmount * 2);

        // Use base hook (no approval) — forceDeallocate does NOT pull tokens from user
        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, extractAmount, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        // Mock the vault's forceDeallocate to succeed
        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", extractAmount, account)),
            abi.encode(uint256(0))
        );

        _executeAll(executions, account);

        assertEq(hook.getOutAmount(account), 0, "produces nothing");
    }

    /// @notice forceDeallocate succeeds with zero allowance — proves no approval needed
    function test_ForceDeallocate_NoApprovalNeeded_ZeroAllowance() public {
        uint256 extractAmount = 1e6;
        address account = makeAddr("noApprovalAccount");

        // Confirm zero allowance before
        assertEq(IERC20(USDC).allowance(account, ZERO_PENALTY_VAULT), 0, "Allowance should be 0 before");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, extractAmount, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", extractAmount, account)),
            abi.encode(uint256(0))
        );

        _executeAll(executions, account);

        assertEq(hook.getOutAmount(account), 0, "produces nothing");
        // Allowance still zero — no approval was ever set
        assertEq(IERC20(USDC).allowance(account, ZERO_PENALTY_VAULT), 0, "Allowance should still be 0 after");
    }

    /// @notice forceDeallocate with penalty vault works without approval
    function test_ForceDeallocate_NoApprovalNeeded_WithPenalty() public {
        uint256 extractAmount = 1e6;
        address account = makeAddr("penaltyNoApproval");

        assertEq(IERC20(USDT).allowance(account, STEAKHOUSE_USDT_VAULT), 0, "Allowance should be 0 before");

        bytes memory data = _encodeBaseData(
            STEAKHOUSE_USDT_VAULT, STEAKHOUSE_USDT_ADAPTER, extractAmount, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        // Mock vault returns penalty shares burned (non-zero penalty)
        vm.mockCall(
            STEAKHOUSE_USDT_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (STEAKHOUSE_USDT_ADAPTER, "", extractAmount, account)),
            abi.encode(uint256(100)) // 100 shares burned as penalty
        );

        _executeAll(executions, account);

        assertEq(hook.getOutAmount(account), 0, "produces nothing");
        assertEq(IERC20(USDT).allowance(account, STEAKHOUSE_USDT_VAULT), 0, "Allowance should still be 0 after");
    }

    /// @notice forceDeallocate with max penalty vault works without approval
    function test_ForceDeallocate_NoApprovalNeeded_MaxPenaltyVault() public {
        uint256 adapterAssets = IAdapter(MAX_PENALTY_ADAPTER).realAssets();
        if (adapterAssets == 0) {
            console2.log("SKIP: Max penalty adapter has no assets");
            return;
        }

        uint256 extractAmount = adapterAssets > 200 ? 100 : adapterAssets / 2;
        address account = makeAddr("maxPenaltyNoApproval");

        bytes memory data = _encodeBaseData(
            MAX_PENALTY_VAULT, MAX_PENALTY_ADAPTER, extractAmount, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        vm.mockCall(
            MAX_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (MAX_PENALTY_ADAPTER, "", extractAmount, account)),
            abi.encode(uint256(500)) // shares burned as 2% penalty
        );

        _executeAll(executions, account);
        assertEq(hook.getOutAmount(account), 0, "produces nothing");
    }

    /// @notice forceDeallocate with adapterData works without approval
    function test_ForceDeallocate_NoApprovalNeeded_WithAdapterData() public {
        uint256 extractAmount = 1e6;
        address account = makeAddr("adapterDataNoApproval");
        bytes memory adapterData = hex"deadbeef";

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, extractAmount, false, adapterData
        );

        Execution[] memory executions = hook.build(address(0), account, data);

        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, adapterData, extractAmount, account)),
            abi.encode(uint256(0))
        );

        _executeAll(executions, account);
        assertEq(hook.getOutAmount(account), 0, "produces nothing");
    }


    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Build_Assets(uint256 assets) public {
        assets = bound(assets, 1, 1e18);
        address account = makeAddr("smartAccount");

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, assets, false, ""
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /// @notice Fuzz: adapterData of varying length
    function testFuzz_Build_AdapterDataLength(uint256 len) public {
        len = bound(len, 0, 256);
        address account = makeAddr("smartAccount");

        bytes memory adapterData = new bytes(len);

        bytes memory data = _encodeBaseData(
            ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, adapterData
        );

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                    LAYOUT INVARIANTS (FUZZ)
    //////////////////////////////////////////////////////////////*/

    /// @notice For ANY header values and ANY tail, build produces exactly the expected forceDeallocate
    ///         calldata. The single strongest statement that the 105-byte layout decodes correctly.
    /// @dev vault/adapter are fixed to the zero-penalty pair so Inv2 never interferes; the fields under
    ///      test are the oracle id (which must be carried but never read), the amount, and the tail.
    function testFuzz_HeaderRoundTrip_ProducesExactCalldata(bytes32 oracleId, uint96 assets, bytes memory tail)
        public
    {
        vm.assume(assets > 0);
        bytes memory data = _encodeBaseDataFromParams(
            BaseDataParams({
                oracleId: oracleId,
                vault: ZERO_PENALTY_VAULT,
                adapter: ZERO_PENALTY_ADAPTER,
                assets: assets,
                usePrevHookAmount: false,
                adapterData: tail
            })
        );
        _assertBuildMatches(data, tail, assets);
    }

    /// @dev Separate frame to keep this large test contract under the stack limit.
    function _assertBuildMatches(bytes memory data, bytes memory tail, uint256 assets) internal {
        address account = makeAddr("smartAccount");
        Execution[] memory ex = hook.build(address(0), account, data);
        assertEq(
            ex[1].callData,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, tail, assets, account)),
            "every header field decodes to the expected forceDeallocate argument"
        );
    }

    /// @notice A splice rewrites ONLY bytes 72..103. Everything else - oracle id, yieldSource, adapter,
    ///         the flag at 104 and the whole tail - is byte-identical.
    /// @dev Mirrors the repo's own pattern (AaveV4StandaloneLoanHooksV2's PreservesEveryOtherByte) and is
    ///      what proves the sized slot did not move when the layout shrank.
    function testFuzz_Replace_PreservesEveryOtherByte(
        bytes32 oracleId,
        uint96 original,
        uint96 replacement,
        bool usePrev
    )
        public
        view
    {
        bytes memory data = _encodeBaseDataFromParams(
            BaseDataParams({
                oracleId: oracleId,
                vault: ZERO_PENALTY_VAULT,
                adapter: ZERO_PENALTY_ADAPTER,
                assets: original,
                usePrevHookAmount: usePrev,
                adapterData: hex"a1b2c3"
            })
        );
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = replacement;
        bytes memory out = hook.replaceCalldataAmounts(data, amounts);

        assertEq(out.length, data.length, "length preserved");
        for (uint256 i; i < data.length; ++i) {
            if (i >= 72 && i < 104) continue; // the assets slot is the only thing that may change
            assertEq(uint8(out[i]), uint8(data[i]), "a byte outside the assets slot changed");
        }
        assertEq(hook.decodeAmounts(out)[0], replacement, "and the slot itself took the new value");
    }

    /*//////////////////////////////////////////////////////////////
                    Inv2 BOUNDARY (FUZZ)
    //////////////////////////////////////////////////////////////*/

    /// @notice For ANY cap, build succeeds exactly when the cap is at least the adapter's live rate.
    function testFuzz_Inv2_CapBoundary(uint256 capWad) public {
        capWad = bound(capWad, 1, 0.02e18);
        uint256 live = IMorphoVaultV2(STEAKHOUSE_USDT_VAULT).forceDeallocatePenalty(STEAKHOUSE_USDT_ADAPTER);
        ForceDeallocateMorphoHook h = new ForceDeallocateMorphoHook(capWad);
        bytes memory data = _encodeBaseData(STEAKHOUSE_USDT_VAULT, STEAKHOUSE_USDT_ADAPTER, 1e6, false, "");

        if (capWad >= live) {
            assertEq(h.build(address(0), makeAddr("a"), data).length, 3, "cap >= live rate must pass");
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(ForceDeallocateMorphoHook.PENALTY_ABOVE_CAP.selector, live, capWad)
            );
            h.build(address(0), makeAddr("a"), data);
        }
    }

    /// @notice The constructor accepts a cap exactly when it is in (0, MORPHO_MAX_PENALTY_WAD].
    function testFuzz_Inv2_ConstructorValidation(uint256 capWad) public {
        if (capWad != 0 && capWad <= 0.02e18) {
            assertEq(new ForceDeallocateMorphoHook(capWad).MAX_PENALTY_WAD(), capWad, "accepted");
        } else {
            vm.expectRevert(ForceDeallocateMorphoHook.INVALID_PENALTY_CAP.selector);
            new ForceDeallocateMorphoHook(capWad);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    /// @notice build emits preExecute FIRST and postExecute LAST, with the vault call between.
    /// @dev This is the BaseHook invariant that makes the hook's own checks unskippable: a build cannot
    ///      omit them, and resetExecutionState reverts INCOMPLETE_HOOK_EXECUTION unless both ran.
    function test_Build_PreExecuteFirst_PostExecuteLast() public {
        address account = makeAddr("smartAccount");
        Execution[] memory ex =
            hook.build(address(0), account, _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, ""));

        assertEq(ex.length, 3, "pre + call + post");
        assertEq(ex[0].target, address(hook), "slot 0 is the hook itself (preExecute)");
        assertEq(ex[2].target, address(hook), "slot 2 is the hook itself (postExecute)");
        assertEq(ex[1].target, ZERO_PENALTY_VAULT, "the vault call sits between them");
        assertEq(bytes4(ex[0].callData), ISuperHook.preExecute.selector, "slot 0 is preExecute");
        assertEq(bytes4(ex[2].callData), ISuperHook.postExecute.selector, "slot 2 is postExecute");
    }

    /// @notice preExecute is one-shot within an execution context.
    function test_PreExecute_IsOneShot() public {
        address account = makeAddr("smartAccount");
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, "");

        vm.startPrank(account);
        hook.setExecutionContext(account);
        hook.preExecute(address(0), account, data);
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        hook.preExecute(address(0), account, data);
        vm.stopPrank();
    }

    /// @notice resetExecutionState refuses while either mutex is unset.
    /// @dev The mechanism that makes a partial execution unrepresentable.
    function test_Reset_RequiresBothMutexes() public {
        address account = makeAddr("smartAccount");
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, "");

        vm.startPrank(account);
        hook.setExecutionContext(account);
        hook.preExecute(address(0), account, data);
        vm.expectRevert(BaseHook.INCOMPLETE_HOOK_EXECUTION.selector);
        hook.resetExecutionState(account);
        vm.stopPrank();
    }

    /// @notice A predecessor whose getOutAmount reverts fails the build rather than defaulting.
    function test_UsePrevHookAmount_RevertingPredecessor_Fails() public {
        address account = makeAddr("smartAccount");
        address prev = makeAddr("badPrevHook");
        vm.mockCallRevert(
            prev, abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account), "boom"
        );

        vm.expectRevert();
        hook.build(prev, account, _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, true, ""));
    }

    /// @notice A predecessor publishing type(uint256).max is carried through, NOT silently clamped.
    /// @dev Pinned as documentation of current behaviour: unlike BaseLoanHookV2, this hook has no
    ///      sentinel guard, so an absurd inherited amount reaches Morpho and fails there. If a guard is
    ///      ever added, this test should change deliberately rather than silently.
    function test_UsePrevHookAmount_MaxSentinel_IsNotClamped() public {
        address account = makeAddr("smartAccount");
        address prev = makeAddr("prevHook");
        vm.mockCall(
            prev,
            abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account),
            abi.encode(type(uint256).max)
        );

        Execution[] memory ex =
            hook.build(prev, account, _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, true, ""));
        assertEq(
            ex[1].callData,
            abi.encodeCall(
                IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", type(uint256).max, account)
            ),
            "the sentinel is forwarded verbatim; the venue rejects it, not the hook"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    SUP-21780 Inv2: PENALTY CEILING
    //////////////////////////////////////////////////////////////*/

    /// @notice A hook capped BELOW the adapter's live rate refuses to build or to pre-execute.
    /// @dev The adapter here charges 10 bps; the hook is capped at 5. Both the view path (`build`, what
    ///      the OMS pre-flight sees) and the authoritative on-chain path (`_preExecute`) must refuse,
    ///      because a penalty raised between simulation and execution has to be caught by the latter.
    function test_Inv2_PenaltyAboveCap_IsRefusedOnBothPaths() public {
        ForceDeallocateMorphoHook capped = new ForceDeallocateMorphoHook(0.0005e18); // 5 bps
        address account = makeAddr("smartAccount");
        bytes memory data = _encodeBaseData(STEAKHOUSE_USDT_VAULT, STEAKHOUSE_USDT_ADAPTER, 1e6, false, "");

        uint256 live = IMorphoVaultV2(STEAKHOUSE_USDT_VAULT).forceDeallocatePenalty(STEAKHOUSE_USDT_ADAPTER);
        assertGt(live, 0.0005e18, "precondition: this adapter charges more than the cap");

        vm.expectRevert(
            abi.encodeWithSelector(ForceDeallocateMorphoHook.PENALTY_ABOVE_CAP.selector, live, 0.0005e18)
        );
        capped.build(address(0), account, data);

        // And directly on the on-chain path, bypassing build entirely.
        vm.startPrank(account);
        capped.setExecutionContext(account);
        vm.expectRevert(
            abi.encodeWithSelector(ForceDeallocateMorphoHook.PENALTY_ABOVE_CAP.selector, live, 0.0005e18)
        );
        capped.preExecute(address(0), account, data);
        vm.stopPrank();
    }

    /// @notice A cap AT the adapter's live rate passes - the comparison is `>`, not `>=`.
    function test_Inv2_PenaltyExactlyAtCap_IsAllowed() public {
        uint256 live = IMorphoVaultV2(STEAKHOUSE_USDT_VAULT).forceDeallocatePenalty(STEAKHOUSE_USDT_ADAPTER);
        ForceDeallocateMorphoHook exact = new ForceDeallocateMorphoHook(live);
        address account = makeAddr("smartAccount");

        Execution[] memory ex =
            exact.build(address(0), account, _encodeBaseData(STEAKHOUSE_USDT_VAULT, STEAKHOUSE_USDT_ADAPTER, 1e6, false, ""));
        assertEq(ex.length, 3, "a cap equal to the live rate must not bind");
    }

    /// @notice A zero-penalty adapter passes under any cap.
    function test_Inv2_ZeroPenaltyAdapter_PassesUnderTheTightestCap() public {
        ForceDeallocateMorphoHook tight = new ForceDeallocateMorphoHook(1); // 1 wei of WAD
        address account = makeAddr("smartAccount");
        assertEq(
            IMorphoVaultV2(ZERO_PENALTY_VAULT).forceDeallocatePenalty(ZERO_PENALTY_ADAPTER),
            0,
            "precondition: this adapter is free"
        );
        Execution[] memory ex =
            tight.build(address(0), account, _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, ""));
        assertEq(ex.length, 3, "a free adapter is never blocked by the ceiling");
    }

    /// @notice The constructor rejects caps that could never bind or would disable the check.
    function test_Inv2_Constructor_RejectsMeaninglessCaps() public {
        vm.expectRevert(ForceDeallocateMorphoHook.INVALID_PENALTY_CAP.selector);
        new ForceDeallocateMorphoHook(0);

        vm.expectRevert(ForceDeallocateMorphoHook.INVALID_PENALTY_CAP.selector);
        new ForceDeallocateMorphoHook(0.02e18 + 1); // above Morpho's own ceiling

        // The boundary itself is valid.
        ForceDeallocateMorphoHook atCeiling = new ForceDeallocateMorphoHook(0.02e18);
        assertEq(atCeiling.MAX_PENALTY_WAD(), 0.02e18, "Morpho's ceiling is an acceptable cap");
        assertEq(atCeiling.MORPHO_MAX_PENALTY_WAD(), 0.02e18, "and is exposed for callers");
    }

    /// @notice The cap is an immutable, so it is part of the CREATE2 address.
    /// @dev This is the property that makes a Merkle leaf authorising the hook also commit to its cap,
    ///      with no extra machinery: two different caps are two different addresses.
    function test_Inv2_DifferentCaps_AreDifferentAddresses() public {
        ForceDeallocateMorphoHook a = new ForceDeallocateMorphoHook(0.001e18);
        ForceDeallocateMorphoHook b = new ForceDeallocateMorphoHook(0.002e18);
        assertTrue(address(a) != address(b), "the cap changes the deployed bytecode");
        assertEq(a.MAX_PENALTY_WAD(), 0.001e18);
        assertEq(b.MAX_PENALTY_WAD(), 0.002e18);
    }

    /// @notice Inv2 restores a probe the deleted guard provided: `build` now calls the yieldSource, so a
    ///         non-contract address fails at build rather than only later at execution.
    function test_Inv2_NonContractYieldSource_FailsAtBuild() public {
        address account = makeAddr("smartAccount");
        address notAVault = makeAddr("notAVault");
        bytes memory data = _encodeBaseData(notAVault, STEAKHOUSE_USDT_ADAPTER, 1e6, false, "");

        vm.expectRevert();
        hook.build(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                    SUP-21780: LAYOUT EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @notice A spliced payload must still BUILD, not merely decode. `replaceCalldataAmounts` is what
    ///         OMS uses to write the exit size, so its output has to survive the whole build path.
    function test_SplicedPayload_StillBuilds() public {
        address account = makeAddr("smartAccount");
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, hex"beef");

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 7e6;
        bytes memory spliced = hook.replaceCalldataAmounts(data, amounts);

        Execution[] memory executions = hook.build(address(0), account, spliced);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, hex"beef", 7e6, account)),
            "the spliced amount reaches forceDeallocate and the tail is untouched"
        );
    }

    /// @notice A one-byte tail is valid: 105 header + 1 = 106 bytes.
    function test_OneByteAdapterData_IsCarried() public {
        address account = makeAddr("smartAccount");
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, hex"7f");
        assertEq(data.length, 106, "105 + 1");

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, hex"7f", 1e6, account)),
            "a single tail byte is forwarded, not dropped"
        );
    }

    /// @notice Exactly MIN_DATA_LENGTH means an EMPTY tail, not a one-byte tail.
    /// @dev `ADAPTER_DATA_OFFSET == MIN_DATA_LENGTH`, so the branch is `data.length > 105`. This pins the
    ///      boundary from the other side: 105 bytes must produce `0x`, not a stray byte.
    function test_ExactMinLength_YieldsAnEmptyTail() public {
        address account = makeAddr("smartAccount");
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, false, "");
        assertEq(data.length, 105);

        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", 1e6, account)),
            "105 bytes means an empty adapterData"
        );
    }

    /// @notice WHAT A LEGACY 169-BYTE PAYLOAD DOES, pinned rather than left to discovery.
    /// @dev The migration hazard: the new layout accepts an old-format blob because 169 > 105. The flag
    ///      is read from byte 104 (the top byte of the old `deadline`, normally 0x00 -> false) and the
    ///      remaining 64 bytes become `adapterData`. It does NOT revert. This is why the old address must
    ///      be deregistered rather than left live alongside the new one, and why the OMS encoder cutover
    ///      has to land with the deployment. If this ever starts reverting, the layout gained a length
    ///      check and this test should be updated deliberately.
    function test_LegacyPayload_IsAcceptedAndReinterpreted() public {
        bytes memory legacy = _legacyPayload(1e6);
        assertEq(legacy.length, 169, "the superseded layout");
        assertFalse(hook.decodeUsePrevHookAmount(legacy), "byte 104 is the old deadline's top byte: 0x00");
        _assertLegacyTailBecomesAdapterData(legacy);
    }

    /// @dev Split into its own frame purely to stay under the stack limit in this large test contract.
    function _assertLegacyTailBecomesAdapterData(bytes memory legacy) internal {
        address account = makeAddr("smartAccount");
        Execution[] memory executions = hook.build(address(0), account, legacy);
        // 169 - 105 = 64 bytes: the old deadline's lower word, maxPenaltyBps, and the old flag byte.
        assertEq(
            executions[1].callData,
            abi.encodeCall(
                IMorphoVaultV2.forceDeallocate,
                (ZERO_PENALTY_ADAPTER, BytesLib.slice(legacy, 105, 64), 1e6, account)
            ),
            "the old trailing words are handed to the adapter as adapterData"
        );
    }

    /// @notice usePrevHookAmount genuinely CONSUMES a predecessor's non-zero amount.
    /// @dev The mirror of the two-leg tests below: this hook can be a consumer, it just cannot be a
    ///      producer. Both halves need pinning or a regression could break sizing in either direction.
    function test_UsePrevHookAmount_ConsumesAPredecessorsAmount() public {
        address account = makeAddr("smartAccount");
        address prev = makeAddr("prevHook");
        vm.mockCall(
            prev, abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account), abi.encode(3e6)
        );

        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, 1e6, true, "");
        Execution[] memory executions = hook.build(prev, account, data);
        assertEq(
            executions[1].callData,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", 3e6, account)),
            "the predecessor's 3e6 wins over the header's 1e6"
        );
    }

    /*//////////////////////////////////////////////////////////////
          SUP-21780: THE TWO-LEG CONTRACT IS ENFORCED, NOT DOCUMENTED
    //////////////////////////////////////////////////////////////*/

    /// @notice A SIZED SUCCESSOR CANNOT INHERIT THIS HOOK'S OUTPUT. This is the invariant that forces the
    ///         force-deallocate then redeem sequence to be two explicit legs rather than a chain.
    /// @dev Without this test the rule lives only in NatSpec and in the spec document. `outAmount = 0` is
    ///      what enforces it: every sized consumer guards `amount == 0`. Precedent for pinning it this way
    ///      is `913b93f8`, added alongside PR #1029 to prove the HyperCore chain fails downstream rather
    ///      than proceeding on a stale amount.
    /// @dev The POSITIVE CONTROL at the end is load-bearing: it proves the revert comes from the inherited
    ///      zero and not from a malformed successor payload, which is how a test like this would otherwise
    ///      pass for the wrong reason.
    function test_SUP21780_SizedSuccessor_CannotChainOffThisHook() public {
        address account = makeAddr("smartAccount");
        _publishOutputs(account, 1e6);
        assertEq(hook.getOutAmount(account), 0, "precondition: this hook published zero");

        Deposit4626VaultHook successor = new Deposit4626VaultHook();

        // usePrevHookAmount = true -> inherits 0 -> the successor's own guard trips.
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        successor.build(address(hook), account, _depositData(0, true));

        // Positive control: the same successor with an EXPLICIT amount builds fine, so the revert above
        // is attributable to the inherited zero.
        Execution[] memory ok = successor.build(address(hook), account, _depositData(1e6, false));
        assertGt(ok.length, 0, "the successor is well-formed when it carries its own amount");
    }

    /// @notice Same invariant via self-chaining, which needs no second hook type at all.
    function test_SUP21780_ChainingThisHookOffItself_FailsClosed() public {
        address account = makeAddr("smartAccount");
        _publishOutputs(account, 1e6);

        bytes memory chained = _encodeBaseDataFromParams(
            BaseDataParams({
                oracleId: TEST_ORACLE_ID,
                vault: ZERO_PENALTY_VAULT,
                adapter: ZERO_PENALTY_ADAPTER,
                assets: 0,
                usePrevHookAmount: true,
                adapterData: ""
            })
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(hook), account, chained);
    }

    /// @dev Runs the hook end to end against a mocked vault so outAmount/outToken are published.
    function _publishOutputs(address account, uint256 assets) internal {
        bytes memory data = _encodeBaseData(ZERO_PENALTY_VAULT, ZERO_PENALTY_ADAPTER, assets, false, "");
        Execution[] memory executions = hook.build(address(0), account, data);
        vm.mockCall(
            ZERO_PENALTY_VAULT,
            abi.encodeCall(IMorphoVaultV2.forceDeallocate, (ZERO_PENALTY_ADAPTER, "", assets, account)),
            abi.encode(uint256(0))
        );
        _executeAll(executions, account);
    }

    /// @dev The superseded 169-byte layout: header(104) + deadline(32) + maxPenaltyBps(32) + flag(1).
    ///      Built here so the test that consumes it stays within the stack limit.
    function _legacyPayload(uint256 assets) internal pure returns (bytes memory) {
        // Built in two steps: a single 7-argument `bytes.concat` pushes this large test contract over
        // the stack limit.
        bytes memory head = bytes.concat(
            abi.encodePacked(bytes32(0)), // old placeholder0, zero-filled by the registry
            abi.encodePacked(ZERO_PENALTY_VAULT),
            abi.encodePacked(ZERO_PENALTY_ADAPTER),
            abi.encode(assets) // same offset in both layouts
        );
        return bytes.concat(
            head,
            abi.encode(uint256(0)), // old deadline
            abi.encode(uint256(200)), // old maxPenaltyBps
            abi.encodePacked(uint8(0)) // old flag
        );
    }

    /// @dev Deposit4626VaultHook layout: oracle id at 0, yieldSource at 32, amount at 52, flag at 84.
    function _depositData(uint256 amount, bool usePrev) internal pure returns (bytes memory) {
        return bytes.concat(
            abi.encodePacked(TEST_ORACLE_ID),
            abi.encodePacked(ZERO_PENALTY_VAULT),
            abi.encode(amount),
            abi.encodePacked(usePrev ? uint8(1) : uint8(0))
        );
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

    /// @dev SUP-21780 layout: `deadline` and `maxPenaltyBps` are gone, `usePrevHookAmount` moved from
    ///      offset 168 to 104, and the raw `adapterData` tail from 169 to 105.
    struct BaseDataParams {
        bytes32 oracleId;
        address vault;
        address adapter;
        uint256 assets;
        bool usePrevHookAmount;
        bytes adapterData;
    }

    /// @dev NON-ZERO on purpose. Offset 0 used to be a zero-filled `placeholder0`; encoding a real id
    ///      there is what demonstrates the first word is carried rather than conflated with another field.
    bytes32 internal constant TEST_ORACLE_ID = bytes32(uint256(0xFEED));

    function _encodeBaseData(
        address vault,
        address adapter,
        uint256 assets,
        bool usePrevHookAmount,
        bytes memory adapterData
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeBaseDataFromParams(BaseDataParams({
            oracleId: TEST_ORACLE_ID,
            vault: vault,
            adapter: adapter,
            assets: assets,
            usePrevHookAmount: usePrevHookAmount,
            adapterData: adapterData
        }));
    }

    function _encodeBaseDataFromParams(BaseDataParams memory p) internal pure returns (bytes memory) {
        return bytes.concat(
            abi.encodePacked(p.oracleId), // 0   yieldSourceOracleId
            abi.encodePacked(p.vault), // 32  yieldSource
            abi.encodePacked(p.adapter), // 52  adapter
            abi.encode(p.assets), // 72  assets
            abi.encodePacked(p.usePrevHookAmount ? uint8(1) : uint8(0)), // 104 usePrevHookAmount
            p.adapterData // 105 raw tail, no length prefix
        );
    }
}
