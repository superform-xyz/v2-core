// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {
    ApproveAndSwapOpenOceanSparkDexHook
} from "../../../src/hooks/swappers/openocean/ApproveAndSwapOpenOceanSparkDexHook.sol";
import { SwapOpenOceanSparkDexHook } from "../../../src/hooks/swappers/openocean/SwapOpenOceanSparkDexHook.sol";
import { HookDataUpdater } from "../../../src/libraries/HookDataUpdater.sol";
import { IOpenOceanCaller } from "../../../src/vendor/openocean/IOpenOceanCaller.sol";
import { IOpenOceanExchange } from "../../../src/vendor/openocean/IOpenOceanExchange.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { OpenOceanAPIParser } from "../../utils/parsers/OpenOceanAPIParser.sol";

interface IWFLR {
    function deposit() external payable;
}

contract OpenOceanHookSimulationAccount {
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
}

/// @title OpenOceanProAPIHookSimulationTest
/// @notice Fetches live OpenOcean pro quotes and simulates the Superform hook lifecycle on a Flare fork.
/// @dev Requires FFI/Surl network access and a runtime API key. Run with:
///      RUN_OPENOCEAN_PRO_HOOK_SIMULATION=true OPENOCEAN_PRO_API_KEY=... FOUNDRY_PROFILE=coverage forge test
///        --match-contract OpenOceanProAPIHookSimulationTest -vv
contract OpenOceanProAPIHookSimulationTest is Test, OpenOceanAPIParser {
    string internal constant FLARE_RPC = "https://flare-api.flare.network/ext/C/rpc";

    address internal constant OPENOCEAN_ROUTER = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;
    address internal constant OPENOCEAN_REFERRER = 0x0E24b0F342F034446Ec814281AD1a7653cBd85e9;

    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant FLR = 0x0000000000000000000000000000000000000000;
    address internal constant WFLR = 0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d;
    address internal constant SPRK = 0x657097cC15fdEc9e383dB8628B57eA4a763F2ba0;

    string internal constant ONE_TOKEN = "1000000000000000000";
    string internal constant QUOTE_SLIPPAGE = "2";
    uint256 internal constant SCALE_PERCENT = 90;
    uint256 internal constant MAX_OUTPUT_SCALE_DEVIATION = 2e16; // 2%

    SwapOpenOceanSparkDexHook internal swapHook;
    ApproveAndSwapOpenOceanSparkDexHook internal approveAndSwapHook;
    MockHook internal prevHook;
    OpenOceanHookSimulationAccount internal account;

    modifier onlyWhenEnabled() {
        if (!vm.envOr("RUN_OPENOCEAN_PRO_HOOK_SIMULATION", false)) {
            vm.skip(true);
        }
        if (bytes(_apiKey()).length == 0) {
            vm.skip(true);
        }
        _;
    }

    function setUp() public {
        vm.createSelectFork(FLARE_RPC);

        swapHook = new SwapOpenOceanSparkDexHook(OPENOCEAN_ROUTER, OPENOCEAN_REFERRER, NATIVE);
        approveAndSwapHook = new ApproveAndSwapOpenOceanSparkDexHook(OPENOCEAN_ROUTER, OPENOCEAN_REFERRER, NATIVE);
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, WFLR);
        account = new OpenOceanHookSimulationAccount();
    }

    function test_OpenOceanProAPI_SimulatesNativeSwapHookWithReturnedTxData() public onlyWhenEnabled {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanProDynamicSwap(
            _apiKey(), FLR, SPRK, ONE_TOKEN, address(account), OPENOCEAN_REFERRER, QUOTE_SLIPPAGE
        );

        _assertQuoteShape(quote, FLR);

        uint256 snapshotId = vm.snapshotState();
        uint256 fullOutputDelta = _simulateNativeQuote(quote, quote.inAmount);
        vm.revertToState(snapshotId);

        uint256 executionAmount = quote.inAmount * SCALE_PERCENT / 100;
        uint256 outputDelta = _simulateNativeQuote(quote, executionAmount);

        _assertOutputScaledByInput(fullOutputDelta, outputDelta);
    }

    function test_OpenOceanProAPI_SimulatesApproveAndSwapHookWithReturnedTxData() public onlyWhenEnabled {
        OpenOceanSwapResponse memory quote = surlCallOpenOceanProDynamicSwap(
            _apiKey(), WFLR, SPRK, ONE_TOKEN, address(account), OPENOCEAN_REFERRER, QUOTE_SLIPPAGE
        );

        _assertQuoteShape(quote, WFLR);

        uint256 snapshotId = vm.snapshotState();
        uint256 fullOutputDelta = _simulateErc20Quote(quote, quote.inAmount);
        vm.revertToState(snapshotId);

        uint256 executionAmount = quote.inAmount * SCALE_PERCENT / 100;
        uint256 outputDelta = _simulateErc20Quote(quote, executionAmount);

        _assertOutputScaledByInput(fullOutputDelta, outputDelta);
    }

    function _simulateNativeQuote(
        OpenOceanSwapResponse memory quote_,
        uint256 executionAmount_
    )
        private
        returns (uint256 outputDelta)
    {
        prevHook.setOutAmount(executionAmount_, address(account));

        bytes memory hookData =
            _swapHookData(SPRK, quote_.value, quote_.inAmount, quote_.minOutAmount, true, quote_.txData);
        Execution[] memory executions = swapHook.build(address(prevHook), address(account), hookData);
        uint256 scaledMinReturnAmount;

        {
            (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(quote_.txData);
            (
                ,
                IOpenOceanExchange.SwapDescription memory scaledDesc,
                IOpenOceanCaller.CallDescription[] memory scaledCalls
            ) = _decodeSwap(executions[1].callData);
            scaledMinReturnAmount = scaledDesc.minReturnAmount;

            _assertScaledDescription(quote_.txData, scaledDesc, executionAmount_, quote_.inAmount);
            assertEq(executions[1].target, OPENOCEAN_ROUTER, "unexpected router target");
            assertEq(executions[1].value, executionAmount_, "native execution value not scaled");
            assertEq(_sumCallValues(scaledCalls), executionAmount_, "native nested values not scaled");
            _assertCallDataUnchanged(originalCalls, scaledCalls);
        }

        vm.deal(address(account), executionAmount_);
        (IOpenOceanCaller caller,,) = _decodeSwap(quote_.txData);
        uint256 callerNativeBefore = address(caller).balance;
        uint256 callerWflrBefore = IERC20(WFLR).balanceOf(address(caller));
        uint256 outputBefore = IERC20(SPRK).balanceOf(address(account));

        uint256 hookOutAmount = account.executeHook(address(swapHook), address(prevHook), hookData);

        outputDelta = IERC20(SPRK).balanceOf(address(account)) - outputBefore;
        assertGt(outputDelta, 0, "no SPRK received");
        assertEq(hookOutAmount, outputDelta, "hook output accounting mismatch");
        assertGe(outputDelta, scaledMinReturnAmount, "actual SPRK output below scaled min return");
        assertEq(address(caller).balance - callerNativeBefore, 0, "caller retained native dust");
        assertEq(IERC20(WFLR).balanceOf(address(caller)) - callerWflrBefore, 0, "caller retained WFLR dust");
    }

    function _simulateErc20Quote(
        OpenOceanSwapResponse memory quote_,
        uint256 executionAmount_
    )
        private
        returns (uint256 outputDelta)
    {
        prevHook.setOutAmount(executionAmount_, address(account));

        bytes memory hookData =
            _approveAndSwapHookData(WFLR, SPRK, quote_.inAmount, quote_.minOutAmount, true, quote_.txData);
        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), address(account), hookData);
        uint256 scaledMinReturnAmount;

        {
            (, uint256 approvalAmount) = abi.decode(_sliceAfterSelector(executions[2].callData), (address, uint256));
            (,, IOpenOceanCaller.CallDescription[] memory originalCalls) = _decodeSwap(quote_.txData);
            (
                ,
                IOpenOceanExchange.SwapDescription memory scaledDesc,
                IOpenOceanCaller.CallDescription[] memory scaledCalls
            ) = _decodeSwap(executions[3].callData);
            scaledMinReturnAmount = scaledDesc.minReturnAmount;

            _assertScaledDescription(quote_.txData, scaledDesc, executionAmount_, quote_.inAmount);
            assertEq(executions[1].target, WFLR, "unexpected first approval target");
            assertEq(executions[2].target, WFLR, "unexpected approval target");
            assertEq(executions[3].target, OPENOCEAN_ROUTER, "unexpected router target");
            assertEq(approvalAmount, executionAmount_, "approval amount not scaled");
            assertEq(_sumCallValues(scaledCalls), 0, "ERC20 route should not carry native values");
            _assertCallsUnchanged(originalCalls, scaledCalls);
        }

        vm.deal(address(account), executionAmount_);
        account.wrapNative(WFLR, executionAmount_);

        (IOpenOceanCaller caller,,) = _decodeSwap(quote_.txData);
        uint256 inputBefore = IERC20(WFLR).balanceOf(address(account));
        uint256 callerInputBefore = IERC20(WFLR).balanceOf(address(caller));
        uint256 outputBefore = IERC20(SPRK).balanceOf(address(account));

        uint256 hookOutAmount = account.executeHook(address(approveAndSwapHook), address(prevHook), hookData);

        uint256 inputDelta = inputBefore - IERC20(WFLR).balanceOf(address(account));
        outputDelta = IERC20(SPRK).balanceOf(address(account)) - outputBefore;
        assertEq(inputDelta, executionAmount_, "router did not consume scaled WFLR amount");
        assertGt(outputDelta, 0, "no SPRK received");
        assertEq(hookOutAmount, outputDelta, "hook output accounting mismatch");
        assertGe(outputDelta, scaledMinReturnAmount, "actual SPRK output below scaled min return");
        assertEq(IERC20(WFLR).allowance(address(account), OPENOCEAN_ROUTER), 0, "allowance not reset");
        assertEq(IERC20(WFLR).balanceOf(address(caller)) - callerInputBefore, 0, "caller retained WFLR dust");
    }

    function _assertOutputScaledByInput(uint256 fullOutputDelta_, uint256 scaledOutputDelta_) private pure {
        uint256 expectedScaledOutput = fullOutputDelta_ * SCALE_PERCENT / 100;

        assertGt(fullOutputDelta_, 0, "no full-size SPRK received");
        assertLt(scaledOutputDelta_, fullOutputDelta_, "scaled output did not decrease");
        assertApproxEqRel(
            scaledOutputDelta_,
            expectedScaledOutput,
            MAX_OUTPUT_SCALE_DEVIATION,
            "scaled output not proportional to input"
        );
    }

    function _assertQuoteShape(OpenOceanSwapResponse memory quote_, address expectedInput_) private pure {
        assertEq(quote_.to, OPENOCEAN_ROUTER, "unexpected OpenOcean router");

        (IOpenOceanCaller caller, IOpenOceanExchange.SwapDescription memory desc,) = _decodeSwap(quote_.txData);
        assertTrue(address(caller) != address(0), "missing OpenOcean caller");
        assertEq(_selector(quote_.txData), IOpenOceanExchange.swap.selector, "unexpected top-level selector");
        assertEq(desc.referrer, OPENOCEAN_REFERRER, "unexpected OpenOcean referrer");
        assertTrue(_isSameToken(address(desc.srcToken), expectedInput_), "unexpected input token");
        assertEq(address(desc.dstToken), SPRK, "unexpected output token");
        assertEq(desc.amount, quote_.inAmount, "quote input mismatch");
        assertEq(desc.minReturnAmount, quote_.minOutAmount, "quote min output mismatch");
    }

    function _assertScaledDescription(
        bytes memory originalTxData_,
        IOpenOceanExchange.SwapDescription memory scaledDesc_,
        uint256 executionAmount_,
        uint256 originalAmount_
    )
        private
        pure
    {
        (, IOpenOceanExchange.SwapDescription memory originalDesc,) = _decodeSwap(originalTxData_);

        assertEq(scaledDesc_.amount, executionAmount_, "desc amount not scaled");
        assertEq(
            scaledDesc_.minReturnAmount,
            HookDataUpdater.getUpdatedOutputAmount(executionAmount_, originalAmount_, originalDesc.minReturnAmount),
            "min return not scaled"
        );
        assertEq(
            scaledDesc_.guaranteedAmount,
            HookDataUpdater.getUpdatedOutputAmount(executionAmount_, originalAmount_, originalDesc.guaranteedAmount),
            "guaranteed amount not scaled"
        );
        assertEq(scaledDesc_.referrer, OPENOCEAN_REFERRER, "referrer changed");
    }

    function _swapHookData(
        address outputToken_,
        uint256 value_,
        uint256 inputAmount_,
        uint256 outputMin_,
        bool usePrevHookAmount_,
        bytes memory txData_
    )
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            bytes20(outputToken_),
            bytes32(value_),
            bytes32(inputAmount_),
            bytes32(outputMin_),
            bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)),
            bytes32(txData_.length),
            txData_
        );
    }

    function _approveAndSwapHookData(
        address inputToken_,
        address outputToken_,
        uint256 inputAmount_,
        uint256 outputMin_,
        bool usePrevHookAmount_,
        bytes memory txData_
    )
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            bytes20(inputToken_),
            bytes20(outputToken_),
            bytes32(inputAmount_),
            bytes32(outputMin_),
            bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)),
            bytes32(txData_.length),
            txData_
        );
    }

    function _apiKey() private view returns (string memory apiKey) {
        try vm.envString("OPENOCEAN_PRO_API_KEY") returns (string memory value) {
            apiKey = value;
        } catch {
            apiKey = "";
        }
    }

    function _decodeSwap(bytes memory txData_)
        private
        pure
        returns (
            IOpenOceanCaller caller_,
            IOpenOceanExchange.SwapDescription memory desc_,
            IOpenOceanCaller.CallDescription[] memory calls_
        )
    {
        return abi.decode(
            _sliceAfterSelector(txData_),
            (IOpenOceanCaller, IOpenOceanExchange.SwapDescription, IOpenOceanCaller.CallDescription[])
        );
    }

    function _sumCallValues(IOpenOceanCaller.CallDescription[] memory calls_) private pure returns (uint256 sum) {
        for (uint256 i; i < calls_.length; ++i) {
            sum += calls_[i].value;
        }
    }

    function _assertCallsUnchanged(
        IOpenOceanCaller.CallDescription[] memory originalCalls_,
        IOpenOceanCaller.CallDescription[] memory updatedCalls_
    )
        private
        pure
    {
        _assertCallDataUnchanged(originalCalls_, updatedCalls_);
        for (uint256 i; i < updatedCalls_.length; ++i) {
            assertEq(updatedCalls_[i].value, originalCalls_[i].value, "call value changed");
        }
    }

    function _assertCallDataUnchanged(
        IOpenOceanCaller.CallDescription[] memory originalCalls_,
        IOpenOceanCaller.CallDescription[] memory updatedCalls_
    )
        private
        pure
    {
        assertEq(updatedCalls_.length, originalCalls_.length, "call length changed");
        for (uint256 i; i < updatedCalls_.length; ++i) {
            assertEq(updatedCalls_[i].target, originalCalls_[i].target, "call target changed");
            assertEq(updatedCalls_[i].gasLimit, originalCalls_[i].gasLimit, "call gas changed");
            assertEq(keccak256(updatedCalls_[i].data), keccak256(originalCalls_[i].data), "route calldata changed");
        }
    }

    function _selector(bytes memory data_) private pure returns (bytes4 selector) {
        if (data_.length < 4) return bytes4(0);
        assembly {
            selector := mload(add(data_, 0x20))
        }
    }

    function _sliceAfterSelector(bytes memory data_) private pure returns (bytes memory result) {
        result = new bytes(data_.length - 4);
        for (uint256 i; i < result.length; ++i) {
            result[i] = data_[i + 4];
        }
    }

    function _isSameToken(address tokenA_, address tokenB_) private pure returns (bool) {
        if (_isNativeToken(tokenA_) && _isNativeToken(tokenB_)) {
            return true;
        }
        return tokenA_ == tokenB_;
    }

    function _isNativeToken(address token_) private pure returns (bool) {
        return token_ == address(0) || token_ == NATIVE;
    }
}
