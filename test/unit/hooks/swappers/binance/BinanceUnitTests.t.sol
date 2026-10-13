// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { ApproveAndSwapBinanceHook } from "../../../../../src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { SwapCalldataLayout } from "../../../../../src/libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../../../src/interfaces/ISuperHookSwap.sol";
import { ISuperHook, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../../../src/interfaces/ISuperHook.sol";

import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { MockBinanceRouter } from "../../../../mocks/MockBinanceRouter.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { InternalHelpers } from "../../../../utils/InternalHelpers.sol";

/// @title BinanceUnitTests
/// @notice Unit tests for ApproveAndSwapBinanceHook against a scriptable mock router.
contract BinanceUnitTests is Helpers, InternalHelpers {
    ApproveAndSwapBinanceHook public hook;
    MockBinanceRouter public router;
    MockHook public prevHook;

    MockERC20 public inputToken;
    MockERC20 public outputToken;
    MockERC20 public secondToken;

    address public account;
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public constant MAX_INPUT = 10_000e18;
    uint256 public inputAmount = 1000e18;
    uint256 public outputMin = 850e18;
    uint256 public outputQuote = 900e18;

    bytes public txData = abi.encodeWithSelector(bytes4(keccak256("swap(bytes)")), bytes("route"));

    receive() external payable { }

    function setUp() public {
        account = address(this);

        inputToken = new MockERC20("USDT", "USDT", 18);
        outputToken = new MockERC20("AAPLB", "AAPLB", 18);
        secondToken = new MockERC20("Second", "SEC", 18);

        router = new MockBinanceRouter();
        router.configure(address(inputToken), inputAmount, address(outputToken), outputQuote);

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(inputToken));

        hook = new ApproveAndSwapBinanceHook(address(router), MAX_INPUT);

        // Fund the account with input and the router with output
        inputToken.mint(account, inputAmount);
        outputToken.mint(address(router), 1_000_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _data() internal view returns (bytes memory) {
        return _data(inputAmount, outputMin, false, address(router), txData);
    }

    function _data(
        uint256 inputAmount_,
        uint256 outputMin_,
        bool usePrev,
        address to,
        bytes memory txData_
    )
        internal
        view
        returns (bytes memory)
    {
        return _createBinanceSwapHookData(
            address(inputToken), address(outputToken), inputAmount_, outputQuote, outputMin_, usePrev, to, txData_
        );
    }

    function _dataWithTokens(address in_, address out_) internal view returns (bytes memory) {
        return
            _createBinanceSwapHookData(in_, out_, inputAmount, outputQuote, outputMin, false, address(router), txData);
    }

    function _decodeApprove(bytes memory callData) internal pure returns (address spender, uint256 amount) {
        assertEq(bytes4(callData), IERC20.approve.selector);
        (spender, amount) = abi.decode(BytesLib.slice(callData, 4, callData.length - 4), (address, uint256));
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(hook.BINANCE_ROUTER(), address(router));
        assertEq(hook.MAX_INPUT_AMOUNT(), MAX_INPUT);
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), HookSubTypes.SWAP);
        assertEq(hook.name(), "Approve and Swap Binance");
        assertEq(hook.description(), "Approves and swaps tokens via the Binance Web3 Trading API DEX router");
    }

    function test_Constructor_RevertIf_RouterZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapBinanceHook(address(0), MAX_INPUT);
    }

    function test_Constructor_RevertIf_CapZero() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        new ApproveAndSwapBinanceHook(address(router), 0);
    }

    function test_SupportsInterface_SizingInterfaces() public view {
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId));
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD - HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    function test_Build_SixExecutions_Shape() public view {
        Execution[] memory executions = hook.build(address(prevHook), account, _data());

        // pre + approve(0) + approve(inputAmount) + swap + approve(0) + post
        assertEq(executions.length, 6);
        assertEq(executions[0].target, address(hook));
        assertEq(executions[5].target, address(hook));

        (address spender0, uint256 amount0) = _decodeApprove(executions[1].callData);
        (address spender1, uint256 amount1) = _decodeApprove(executions[2].callData);
        (address spender3, uint256 amount3) = _decodeApprove(executions[4].callData);

        assertEq(executions[1].target, address(inputToken));
        assertEq(executions[2].target, address(inputToken));
        assertEq(executions[4].target, address(inputToken));
        assertEq(spender0, address(router));
        assertEq(spender1, address(router));
        assertEq(spender3, address(router));
        assertEq(amount0, 0);
        assertEq(amount1, inputAmount);
        assertEq(amount3, 0);

        assertEq(executions[3].target, address(router));
        assertEq(executions[3].callData, txData);

        for (uint256 i = 0; i < executions.length; i++) {
            assertEq(executions[i].value, 0, "every execution carries value 0");
        }
    }

    function test_Build_InputAmountEqualToCap_Allowed() public view {
        Execution[] memory executions =
            hook.build(address(prevHook), account, _data(MAX_INPUT, outputMin, false, address(router), txData));
        (, uint256 amount1) = _decodeApprove(executions[2].callData);
        assertEq(amount1, MAX_INPUT);
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD - REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_RevertIf_DataTooShort() public {
        bytes memory short = new bytes(SwapCalldataLayout.MIN_DATA_LENGTH - 1);
        vm.expectRevert(ApproveAndSwapBinanceHook.INVALID_HOOK_DATA.selector);
        hook.build(address(prevHook), account, short);
    }

    function test_Build_RevertIf_TxDataNoSelector() public {
        bytes memory data = _data(inputAmount, outputMin, false, address(router), hex"aabbcc");
        vm.expectRevert(ApproveAndSwapBinanceHook.INVALID_HOOK_DATA.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_UsePrevHookAmount() public {
        bytes memory data = _data(inputAmount, outputMin, true, address(router), txData);
        vm.expectRevert(ApproveAndSwapBinanceHook.USE_PREV_HOOK_NOT_SUPPORTED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_NativeInput_Zero() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        hook.build(address(prevHook), account, _dataWithTokens(address(0), address(outputToken)));
    }

    function test_Build_RevertIf_NativeInput_Sentinel() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        hook.build(address(prevHook), account, _dataWithTokens(NATIVE, address(outputToken)));
    }

    function test_Build_RevertIf_NativeOutput_Zero() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        hook.build(address(prevHook), account, _dataWithTokens(address(inputToken), address(0)));
    }

    function test_Build_RevertIf_NativeOutput_Sentinel() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        hook.build(address(prevHook), account, _dataWithTokens(address(inputToken), NATIVE));
    }

    function test_Build_RevertIf_SameToken() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        hook.build(address(prevHook), account, _dataWithTokens(address(inputToken), address(inputToken)));
    }

    function test_Build_RevertIf_ZeroAmount() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, _data(0, outputMin, false, address(router), txData));
    }

    function test_Build_RevertIf_AmountExceedsCap() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        hook.build(address(prevHook), account, _data(MAX_INPUT + 1, outputMin, false, address(router), txData));
    }

    function test_Build_RevertIf_OutputMinZero() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, _data(inputAmount, 0, false, address(router), txData));
    }

    function test_Build_RevertIf_RouterMismatch() public {
        address attacker = makeAddr("attackerRouter");
        vm.expectRevert(ApproveAndSwapBinanceHook.ROUTER_MISMATCH.selector);
        hook.build(address(prevHook), account, _data(inputAmount, outputMin, false, attacker, txData));
    }

    function test_Build_RevertIf_PayloadLengthOverRead() public {
        bytes memory data = _data();
        // Corrupt payloadLength (offset 189) to claim more bytes than exist
        uint256 bogus = data.length;
        assembly {
            mstore(add(add(data, 0x20), 189), bogus)
        }
        vm.expectRevert(bytes("slice_outOfBounds"));
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                            PRE / POST EXECUTE
    //////////////////////////////////////////////////////////////*/

    function test_PreExecute_SnapshotsOutputBalance() public {
        outputToken.mint(account, 500e18);
        hook.preExecute(address(0), account, _data());
        assertEq(hook.getOutAmount(account), 500e18);
    }

    function test_PostExecute_SetsReceivedAndToken() public {
        outputToken.mint(account, 500e18);
        hook.preExecute(address(0), account, _data());
        outputToken.mint(account, outputMin);
        hook.postExecute(address(0), account, _data());
        assertEq(hook.getOutAmount(account), outputMin);
        assertEq(hook.getOutToken(account), address(outputToken));
    }

    function test_PostExecute_RevertIf_MinOutNotMet() public {
        hook.preExecute(address(0), account, _data());
        outputToken.mint(account, outputMin - 1);
        vm.expectRevert(ApproveAndSwapBinanceHook.MIN_OUT_NOT_MET.selector);
        hook.postExecute(address(0), account, _data());
    }

    function test_PostExecute_RevertIf_OutputBalanceDecreased() public {
        outputToken.mint(account, 500e18);
        hook.preExecute(address(0), account, _data());
        outputToken.burn(account, 1);
        vm.expectRevert(ApproveAndSwapBinanceHook.OUTPUT_BALANCE_DECREASED.selector);
        hook.postExecute(address(0), account, _data());
    }

    function test_PostExecute_RevertIf_AllowanceNotCleared() public {
        hook.preExecute(address(0), account, _data());
        outputToken.mint(account, outputMin);
        inputToken.approve(address(router), 1);
        vm.expectRevert(ApproveAndSwapBinanceHook.ALLOWANCE_NOT_CLEARED.selector);
        hook.postExecute(address(0), account, _data());
    }

    /// @dev `setExecutionContext` is permissionless. A router that reenters it mid-batch advances the
    ///      account's context, so `getOutAmount` reads 0 from the fresh context and the pre-existing output
    ///      balance (here already >= outputMin) would pass as swap output. The hook must fail closed on its
    ///      own, without relying on the executor's `resetExecutionState` to notice.
    function test_PostExecute_RevertIf_ContextResetBetweenPreAndPost() public {
        outputToken.mint(account, outputMin + 1);
        hook.setExecutionContext(account);
        hook.preExecute(address(0), account, _data());

        hook.setExecutionContext(account); // the mid-batch reentry
        assertEq(hook.getOutAmount(account), 0, "snapshot is unreachable from the new context");

        vm.expectRevert(ApproveAndSwapBinanceHook.SNAPSHOT_NOT_TAKEN.selector);
        hook.postExecute(address(0), account, _data());
    }

    function test_PostExecute_RevertIf_NoPreExecute() public {
        outputToken.mint(account, outputMin + 1);
        vm.expectRevert(ApproveAndSwapBinanceHook.SNAPSHOT_NOT_TAKEN.selector);
        hook.postExecute(address(0), account, _data());
    }

    /*//////////////////////////////////////////////////////////////
                    FULL SEQUENCE THROUGH THE MOCK ROUTER
    //////////////////////////////////////////////////////////////*/

    function test_Sequence_Honest() public {
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt,) = _executeBatch(executions);
        assertEq(failedAt, type(uint256).max, "all six steps succeed");

        assertEq(inputToken.balanceOf(account), 0, "input spent");
        assertEq(outputToken.balanceOf(account), outputQuote, "output received");
        assertEq(inputToken.allowance(account, address(router)), 0, "allowance cleared");
        assertEq(hook.getOutAmount(account), outputQuote);
        assertEq(hook.getOutToken(account), address(outputToken));
        assertEq(router.calls(), 1);
        assertEq(router.lastSelector(), bytes4(txData));
    }

    function test_Sequence_RouterReturnsSuccessButNoOutput_RevertsMinOut() public {
        router.setMode(MockBinanceRouter.Mode.NO_OUTPUT);
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt, bytes memory ret) = _executeBatch(executions);
        assertEq(failedAt, 5, "fails at postExecute");
        assertEq(bytes4(ret), ApproveAndSwapBinanceHook.MIN_OUT_NOT_MET.selector);
    }

    function test_Sequence_RouterSendsToThirdParty_RevertsMinOut() public {
        router.setMode(MockBinanceRouter.Mode.SEND_TO_THIRD_PARTY);
        router.setThirdParty(makeAddr("thirdParty"));
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt, bytes memory ret) = _executeBatch(executions);
        assertEq(failedAt, 5);
        assertEq(bytes4(ret), ApproveAndSwapBinanceHook.MIN_OUT_NOT_MET.selector);
    }

    /// @dev The invariant that justifies the scoped approve: total input spent <= header inputAmount.
    function test_Sequence_RouterPullsMoreThanApproved_RouterCallFails() public {
        inputToken.mint(account, inputAmount); // account holds 2x, router tries to take it all
        router.setMode(MockBinanceRouter.Mode.PULL_MORE_THAN_APPROVED);
        router.setOverPull(inputAmount + 1);
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt,) = _executeBatch(executions);
        assertEq(failedAt, 3, "router call reverts on insufficient allowance");
        assertEq(inputToken.balanceOf(account), 2 * inputAmount, "nothing spent");
    }

    function test_Sequence_RouterPullsSecondToken_NoStandingAllowance_Fails() public {
        secondToken.mint(account, 1e18);
        router.setMode(MockBinanceRouter.Mode.PULL_SECOND_TOKEN);
        router.setSecondToken(address(secondToken), 1e18);
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt,) = _executeBatch(executions);
        assertEq(failedAt, 3, "router cannot pull a token it was never approved for");
        assertEq(secondToken.balanceOf(account), 1e18);
    }

    /// @dev Documents the residual: a standing allowance on ANOTHER token (e.g. a stray
    ///      ApproveERC20Hook leaf) is harvestable by the blob. The hook cannot see it; the leaf
    ///      operator must never create one for this router.
    function test_Sequence_RouterPullsSecondToken_WithStandingAllowance_Succeeds() public {
        secondToken.mint(account, 1e18);
        secondToken.approve(address(router), 1e18);
        router.setMode(MockBinanceRouter.Mode.PULL_SECOND_TOKEN);
        router.setSecondToken(address(secondToken), 1e18);
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt,) = _executeBatch(executions);
        assertEq(failedAt, type(uint256).max);
        assertEq(secondToken.balanceOf(account), 0, "second token harvested through the standing allowance");
    }

    function test_Sequence_RouterBurnsOutput_RevertsNamedError() public {
        outputToken.mint(account, 500e18);
        router.configure(address(inputToken), inputAmount, address(outputToken), 0);
        router.setMode(MockBinanceRouter.Mode.BURN_OUTPUT);
        router.setBurnAmount(100e18);
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt, bytes memory ret) = _executeBatch(executions);
        assertEq(failedAt, 5);
        assertEq(bytes4(ret), ApproveAndSwapBinanceHook.OUTPUT_BALANCE_DECREASED.selector);
    }

    function test_Sequence_RouterReturndataBomb_BatchCompletes() public {
        router.setMode(MockBinanceRouter.Mode.RETURNDATA_BOMB);
        router.setBombSize(64 * 1024);
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt,) = _executeBatch(executions);
        assertEq(failedAt, type(uint256).max, "unbounded returndata is an accepted gas cost, not a failure");
        assertEq(outputToken.balanceOf(account), outputQuote);
    }

    function test_Sequence_RouterReverts_Propagates() public {
        router.setMode(MockBinanceRouter.Mode.REVERT);
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt,) = _executeBatch(executions);
        assertEq(failedAt, 3);
    }

    /*//////////////////////////////////////////////////////////////
                                  INSPECT
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_CommitsBothTokens() public view {
        bytes memory out = hook.inspect(_data());
        assertEq(out.length, 40, "packed (inputToken, outputToken)");
        assertEq(out, abi.encodePacked(address(inputToken), address(outputToken)));
        assertEq(address(bytes20(BytesLib.slice(out, 0, 20))), address(inputToken));
        assertEq(address(bytes20(BytesLib.slice(out, 20, 20))), address(outputToken));
    }

    function test_Inspect_DiffersOnInputToken() public view {
        bytes memory base = hook.inspect(_data());
        bytes memory variant = hook.inspect(_dataWithTokens(address(secondToken), address(outputToken)));
        assertTrue(keccak256(base) != keccak256(variant));
    }

    function test_Inspect_RevertIf_DataTooShort() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.INVALID_HOOK_DATA.selector);
        hook.inspect(new bytes(SwapCalldataLayout.MIN_DATA_LENGTH - 1));
    }

    function testFuzz_Inspect_IgnoresUncommittedFields(
        uint256 amount,
        uint256 minOut,
        bool usePrev,
        address to,
        bytes memory txData_
    )
        public
        view
    {
        bytes memory base = hook.inspect(_data());
        bytes memory variant = hook.inspect(_data(amount, minOut, usePrev, to, txData_));
        assertEq(base, variant);
    }

    /*//////////////////////////////////////////////////////////////
                              ISuperHookSwap
    //////////////////////////////////////////////////////////////*/

    function test_EncodeSwapData_RoundTrip() public view {
        bytes memory payload = abi.encode(address(router), txData);
        ISuperHookSwap.SwapHeader memory header = ISuperHookSwap.SwapHeader({
            inputToken: address(inputToken),
            outputToken: address(outputToken),
            inputAmount: inputAmount,
            outputQuote: outputQuote,
            outputMin: outputMin,
            usePrevHookAmount: false
        });

        bytes memory encoded = hook.encodeSwapData(header, payload);
        assertEq(encoded, _data(), "matches the test-side builder");

        assertEq(hook.decodeInputToken(encoded), address(inputToken));
        assertEq(hook.decodeOutputToken(encoded), address(outputToken));
        assertEq(hook.decodeInputAmount(encoded), inputAmount);
        assertEq(hook.decodeOutputQuote(encoded), outputQuote);
        assertEq(hook.decodeOutputMin(encoded), outputMin);
        assertFalse(hook.decodeUsePrevHookAmount(encoded));

        (address to, bytes memory decodedTx) = abi.decode(hook.decodePayload(encoded), (address, bytes));
        assertEq(to, address(router));
        assertEq(decodedTx, txData);
    }

    function test_DecodeUsePrevHookAmount_True() public view {
        assertTrue(hook.decodeUsePrevHookAmount(_data(inputAmount, outputMin, true, address(router), txData)));
    }

    /*//////////////////////////////////////////////////////////////
                              SIZING (SIZELESS)
    //////////////////////////////////////////////////////////////*/

    function test_Sizing_Sizeless() public view {
        assertEq(hook.decodeAmounts("").length, 0);
        assertEq(hook.amountRoles("").length, 0);
        assertEq(hook.decodeAmounts(_data()).length, 0);
        assertEq(hook.amountRoles(_data()).length, 0);
    }

    function test_ReplaceCalldataAmounts_EmptyIsIdentity() public view {
        bytes memory data = _data();
        assertEq(hook.replaceCalldataAmounts(data, new uint256[](0)), data);
    }

    function test_ReplaceCalldataAmounts_RevertIf_NonEmpty() public {
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        hook.replaceCalldataAmounts(_data(), _singleAmount(1));
    }

    /*//////////////////////////////////////////////////////////////
                                   FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Build_ShortData_Reverts(uint8 len, bytes32 seed) public {
        uint256 n = uint256(len) % SwapCalldataLayout.MIN_DATA_LENGTH;
        bytes memory short = new bytes(n);
        for (uint256 i = 0; i < n; i++) {
            short[i] = seed[i % 32];
        }
        vm.expectRevert(ApproveAndSwapBinanceHook.INVALID_HOOK_DATA.selector);
        hook.build(address(prevHook), account, short);
    }

    function testFuzz_Build_AmountWithinCap(uint256 amount) public view {
        amount = bound(amount, 1, MAX_INPUT);
        Execution[] memory executions =
            hook.build(address(prevHook), account, _data(amount, outputMin, false, address(router), txData));
        (, uint256 approved) = _decodeApprove(executions[2].callData);
        assertEq(approved, amount);
    }

    function testFuzz_Build_AmountAboveCap_Reverts(uint256 amount) public {
        amount = bound(amount, MAX_INPUT + 1, type(uint256).max);
        vm.expectRevert(ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        hook.build(address(prevHook), account, _data(amount, outputMin, false, address(router), txData));
    }

    function testFuzz_ReplaceCalldataAmounts_IdentityOnAnyBytes(bytes memory anyData) public view {
        assertEq(hook.replaceCalldataAmounts(anyData, new uint256[](0)), anyData);
    }

    function test_Build_IndependentOfPrevHookAndAccount() public view {
        bytes memory data = _data();
        Execution[] memory a = hook.build(address(prevHook), account, data);
        Execution[] memory b = hook.build(address(0), makeAddrView("someoneElse"), data);
        // inner executions [1..4] are identical; [0]/[5] are pre/post whose calldata embeds the account
        for (uint256 i = 1; i < 5; i++) {
            assertEq(a[i].target, b[i].target);
            assertEq(a[i].callData, b[i].callData);
            assertEq(a[i].value, b[i].value);
        }
    }

    function makeAddrView(string memory name) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(name)))));
    }

    function test_Build_DataExactlyMinLength_PayloadEmpty_Reverts() public {
        // 221 bytes = header + a fully VALID layer 1 (both tokens, amount, minOut) with payloadLength = 0:
        // every earlier check passes and the abi.decode of an empty payload is what fails.
        bytes memory data = abi.encodePacked(
            bytes32(0),
            bytes20(address(0)),
            bytes20(address(inputToken)),
            bytes20(address(outputToken)),
            inputAmount,
            outputQuote,
            outputMin,
            false,
            uint256(0)
        );
        assertEq(data.length, SwapCalldataLayout.MIN_DATA_LENGTH);
        assertEq(hook.inspect(data), abi.encodePacked(address(inputToken), address(outputToken)), "layer 1 is valid");
        vm.expectRevert();
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                    PER-TRANSACTION CAP (repeated leaf in one batch)
    //////////////////////////////////////////////////////////////*/

    /// @dev Mirrors what SuperExecutor does around every hook entry: open a fresh execution context,
    ///      run the six steps, and (on success) reset the state so the next entry gets a new context.
    function _runAsExecutor(bytes memory data) internal returns (uint256 failedAt, bytes memory ret) {
        hook.setExecutionContext(account);
        (failedAt, ret) = _executeBatch(hook.build(address(prevHook), account, data));
        if (failedAt == type(uint256).max) hook.resetExecutionState(account);
    }

    /// @dev A Merkle leaf carries no amount, so the same leaf can be repeated in one batch. The cap must
    ///      bound the SUM, not each execution. Two runs of 6,000 against a 10,000 cap: the second must
    ///      fail at its preExecute, before any approval is granted.
    function test_TxCap_TwoExecutionsSameTx_AggregateAboveCap_RevertsAtSecondPre() public {
        uint256 half = 6000e18;
        uint256 before = inputToken.balanceOf(account);
        inputToken.mint(account, 2 * half);
        router.configure(address(inputToken), half, address(outputToken), outputQuote);
        bytes memory data = _data(half, outputMin, false, address(router), txData);

        (uint256 failedAt1,) = _runAsExecutor(data);
        assertEq(failedAt1, type(uint256).max, "first execution succeeds");
        assertEq(hook.txSpent(account), half);

        (uint256 failedAt2, bytes memory ret) = _runAsExecutor(data);
        assertEq(failedAt2, 0, "second execution fails at preExecute");
        assertEq(bytes4(ret), ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        assertEq(inputToken.balanceOf(account), before + half, "only the first execution spent");
        assertEq(inputToken.allowance(account, address(router)), 0);
    }

    function test_TxCap_TwoExecutionsSameTx_AggregateAtCap_Succeeds() public {
        uint256 half = MAX_INPUT / 2;
        uint256 before = inputToken.balanceOf(account);
        inputToken.mint(account, 2 * half);
        router.configure(address(inputToken), half, address(outputToken), outputQuote);
        bytes memory data = _data(half, outputMin, false, address(router), txData);

        (uint256 failedAt1,) = _runAsExecutor(data);
        (uint256 failedAt2,) = _runAsExecutor(data);
        assertEq(failedAt1, type(uint256).max);
        assertEq(failedAt2, type(uint256).max);
        assertEq(hook.txSpent(account), MAX_INPUT);
        assertEq(inputToken.balanceOf(account), before, "both halves spent");
    }

    /// @dev The accumulator is per account: a second account in the same tx has its own budget.
    function test_TxCap_IsPerAccount() public {
        bytes memory data = _data(MAX_INPUT, outputMin, false, address(router), txData);
        inputToken.mint(account, MAX_INPUT);
        router.configure(address(inputToken), MAX_INPUT, address(outputToken), outputQuote);
        (uint256 failedAt,) = _executeBatch(hook.build(address(prevHook), account, data));
        assertEq(failedAt, type(uint256).max);
        assertEq(hook.txSpent(account), MAX_INPUT);
        assertEq(hook.txSpent(makeAddr("otherAccount")), 0);
    }

    /// @dev A failed execution must not leave its amount counted (the batch reverts atomically in
    ///      production; here we check the accumulator only advances in preExecute, i.e. a build-time
    ///      rejection leaves it untouched).
    function test_TxCap_BuildRejectionDoesNotAccumulate() public {
        vm.expectRevert(ApproveAndSwapBinanceHook.INPUT_EXCEEDS_CAP.selector);
        hook.build(address(prevHook), account, _data(MAX_INPUT + 1, outputMin, false, address(router), txData));
        assertEq(hook.txSpent(account), 0);
    }

    /*//////////////////////////////////////////////////////////////
                PARTIAL FILLS AND RE-ENTERING FACETS (full sequence)
    //////////////////////////////////////////////////////////////*/

    /// @dev A normal token, router pulls only half of the allowance: the trailing approve(0) is what clears
    ///      the residual; without it ALLOWANCE_NOT_CLEARED would fire. Distinguishes "approve(0) clears
    ///      residual" from "the router consumed everything".
    function test_Sequence_PartialFill_TrailingApproveClearsResidual() public {
        router.setMode(MockBinanceRouter.Mode.PARTIAL_FILL);
        router.setPartialPull(inputAmount / 2);
        Execution[] memory executions = hook.build(address(prevHook), account, _data());

        // run pre + approve(0) + approve(x) + swap, then observe the residual BEFORE the trailing approve(0)
        for (uint256 i = 0; i < 4; i++) {
            (bool ok,) = executions[i].target.call(executions[i].callData);
            assertTrue(ok);
        }
        assertEq(inputToken.allowance(account, address(router)), inputAmount / 2, "residual after partial fill");
        (bool ok4,) = executions[4].target.call(executions[4].callData);
        assertTrue(ok4);
        assertEq(inputToken.allowance(account, address(router)), 0, "trailing approve(0) cleared it");
        (bool ok5,) = executions[5].target.call(executions[5].callData);
        assertTrue(ok5);
        assertEq(inputToken.balanceOf(account), inputAmount / 2);
        assertEq(hook.getOutAmount(account), outputQuote);
    }

    /// @dev Malicious facet rotates the hook's execution context mid-swap (`setExecutionContext` is
    ///      permissionless). The snapshot taken by preExecute becomes unreachable, and postExecute refuses
    ///      to compare against a context that never took one.
    function test_Sequence_RouterReentersSetExecutionContext_FailsClosed() public {
        router.setHook(address(hook));
        router.setMode(MockBinanceRouter.Mode.REENTER_SET_CONTEXT);
        outputToken.mint(account, 5000e18); // pre-existing position the forged delta would "credit"
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt, bytes memory ret) = _executeBatch(executions);
        assertEq(failedAt, 5, "postExecute is where it fails");
        assertEq(bytes4(ret), ApproveAndSwapBinanceHook.SNAPSHOT_NOT_TAKEN.selector);
    }

    /// @dev Malicious facet tries to forge the snapshot via `setOutAmount` mid-swap: BaseHook refuses while
    ///      the pre mutex is set, so the router call itself reverts.
    function test_Sequence_RouterReentersSetOutAmount_FailsAtRouterCall() public {
        router.setHook(address(hook));
        router.setMode(MockBinanceRouter.Mode.REENTER_SET_OUT_AMOUNT);
        Execution[] memory executions = hook.build(address(prevHook), account, _data());
        (uint256 failedAt, bytes memory ret) = _executeBatch(executions);
        assertEq(failedAt, 3, "router call reverts");
        assertEq(bytes4(ret), BaseHook.CANNOT_SET_OUT_AMOUNT.selector);
    }

    /*//////////////////////////////////////////////////////////////
                    TOKEN QUIRKS THROUGH THE FULL SEQUENCE
    //////////////////////////////////////////////////////////////*/

    /// @dev USDT-style: approve(non-zero) reverts while the allowance is already non-zero.
    ///      The approve(0) → approve(x) → swap → approve(0) order makes this a non-issue, including when
    ///      a stale non-zero allowance to the router pre-exists.
    function test_Sequence_USDTStyleToken_StaleAllowance_Succeeds() public {
        MockUSDTStyleERC20 usdt = new MockUSDTStyleERC20();
        usdt.mint(account, inputAmount);
        usdt.approve(address(router), 5); // stale non-zero allowance from a previous life
        router.configure(address(usdt), inputAmount, address(outputToken), outputQuote);

        bytes memory data = _createBinanceSwapHookData(
            address(usdt), address(outputToken), inputAmount, outputQuote, outputMin, false, address(router), txData
        );
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        (uint256 failedAt,) = _executeBatch(executions);
        assertEq(failedAt, type(uint256).max);
        assertEq(usdt.allowance(account, address(router)), 0);
        assertEq(outputToken.balanceOf(account), outputQuote);
    }

    /// @dev Sticky-approve: approve(spender, 0) silently no-ops. The trailing approve(0) cannot clear
    ///      the allowance, so _postExecute's ALLOWANCE_NOT_CLEARED is what catches it.
    function test_Sequence_StickyApproveToken_RevertsAllowanceNotCleared() public {
        MockStickyApproveERC20 sticky = new MockStickyApproveERC20();
        sticky.mint(account, inputAmount);
        // router pulls only half, so half the allowance survives approve(0)'s no-op
        router.configure(address(sticky), inputAmount / 2, address(outputToken), outputQuote);

        bytes memory data = _createBinanceSwapHookData(
            address(sticky), address(outputToken), inputAmount, outputQuote, outputMin, false, address(router), txData
        );
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        (uint256 failedAt, bytes memory ret) = _executeBatch(executions);
        assertEq(failedAt, 5, "postExecute catches the residual");
        assertEq(bytes4(ret), ApproveAndSwapBinanceHook.ALLOWANCE_NOT_CLEARED.selector);
    }

    /// @dev Documents family behaviour: the balance delta cannot distinguish swap output from a donation
    ///      landing between pre and post. outAmount includes it; outputMin is measured against it.
    function test_Sequence_DonationBetweenPreAndPost_CountsTowardOutAmount() public {
        router.configure(address(inputToken), inputAmount, address(outputToken), 0); // router returns nothing
        Execution[] memory executions = hook.build(address(prevHook), account, _data());

        // run pre + approvals + swap, then donate, then post
        for (uint256 i = 0; i < 5; i++) {
            (bool ok,) = executions[i].target.call(executions[i].callData);
            assertTrue(ok);
        }
        outputToken.mint(account, outputMin); // third-party donation
        (bool okPost,) = executions[5].target.call(executions[5].callData);
        assertTrue(okPost, "donation satisfies outputMin");
        assertEq(hook.getOutAmount(account), outputMin);
    }
}

/// @dev approve(x) reverts when allowance is non-zero and x is non-zero (Tether semantics)
contract MockUSDTStyleERC20 is MockERC20 {
    constructor() MockERC20("USDT-style", "USDT", 6) { }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(amount == 0 || allowance(msg.sender, spender) == 0, "USDT: reset to 0 first");
        return super.approve(spender, amount);
    }
}

/// @dev approve(spender, 0) is silently ignored
contract MockStickyApproveERC20 is MockERC20 {
    constructor() MockERC20("Sticky", "STK", 18) { }

    function approve(address spender, uint256 amount) public override returns (bool) {
        if (amount == 0) return true;
        return super.approve(spender, amount);
    }
}
