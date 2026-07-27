// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {
    ApproveAndSwapAerodromeUniversalRouterHook
} from "../../../../../src/hooks/swappers/aerodrome/ApproveAndSwapAerodromeUniversalRouterHook.sol";
import {
    BaseAerodromeUniversalRouterHook
} from "../../../../../src/hooks/swappers/aerodrome/BaseAerodromeUniversalRouterHook.sol";
import {
    SwapAerodromeUniversalRouterHook
} from "../../../../../src/hooks/swappers/aerodrome/SwapAerodromeUniversalRouterHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import {
    ISuperHook,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../../../src/interfaces/ISuperHook.sol";
import { ISuperHookSwap } from "../../../../../src/interfaces/ISuperHookSwap.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { IAerodromeUniversalRouter } from "../../../../../src/vendor/aerodrome/IAerodromeUniversalRouter.sol";
import { MockAerodromeUniversalRouter } from "../../../../mocks/MockAerodromeUniversalRouter.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";

contract MockAerodromePreviousResult {
    address private outputToken;
    uint256 private outputAmount;

    function setResult(address outputToken_, uint256 outputAmount_) external {
        outputToken = outputToken_;
        outputAmount = outputAmount_;
    }

    function getOutToken(address) external view returns (address) {
        return outputToken;
    }

    function getOutAmount(address) external view returns (uint256) {
        return outputAmount;
    }
}

contract EmptyAerodromePreviousResult {
    fallback() external { }
}

contract DirtyTokenAerodromePreviousResult {
    fallback() external {
        assembly ("memory-safe") {
            mstore(0, shl(160, 1))
            return(0, 32)
        }
    }
}

contract AerodromeUniversalRouterHookTest is Test {
    using BytesLib for bytes;

    uint256 private constant INPUT_AMOUNT = 1000;
    uint256 private constant OUTPUT_QUOTE = 950;
    uint256 private constant OUTPUT_MIN = 900;
    uint256 private constant DEADLINE = 10_000;

    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    MockAerodromeUniversalRouter private router;
    SwapAerodromeUniversalRouterHook private swapHook;
    ApproveAndSwapAerodromeUniversalRouterHook private approveAndSwapHook;
    MockAerodromePreviousResult private previousResult;
    MockERC20 private inputToken;
    MockERC20 private outputToken;
    address private account;

    function setUp() public {
        vm.warp(1000);
        account = address(this);
        inputToken = new MockERC20("Input", "IN", 18);
        outputToken = new MockERC20("Output", "OUT", 18);
        router = new MockAerodromeUniversalRouter();
        swapHook = new SwapAerodromeUniversalRouterHook(address(router));
        approveAndSwapHook = new ApproveAndSwapAerodromeUniversalRouterHook(address(router));
        previousResult = new MockAerodromePreviousResult();
    }

    function test_ConstructorMetadataAndInterfaces() public view {
        assertEq(address(swapHook.UNIVERSAL_ROUTER()), address(router));
        assertEq(address(approveAndSwapHook.UNIVERSAL_ROUTER()), address(router));
        assertEq(swapHook.name(), "Swap Aerodrome Universal Router");
        assertEq(approveAndSwapHook.name(), "Approve and Swap Aerodrome Universal Router");
        assertEq(uint256(swapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(swapHook.subtype(), HookSubTypes.SWAP);
        assertTrue(swapHook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertTrue(swapHook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertFalse(swapHook.supportsInterface(type(ISuperHookSwap).interfaceId));
        assertFalse(swapHook.supportsInterface(type(ISuperHookContextAware).interfaceId));
    }

    function test_ConstructorRejectsZeroRouter() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapAerodromeUniversalRouterHook(address(0));
    }

    function test_StandardSwapEncodingDecodingInspectionAndSizing() public view {
        bytes memory payload =
            abi.encode(uint8(0), DEADLINE, _classicPath(address(inputToken), address(outputToken), true));
        bytes memory data = _encodeData(
            swapHook, address(inputToken), address(outputToken), INPUT_AMOUNT, OUTPUT_QUOTE, OUTPUT_MIN, true, payload
        );

        assertEq(swapHook.decodeInputToken(data), address(inputToken));
        assertEq(swapHook.decodeOutputToken(data), address(outputToken));
        assertEq(swapHook.decodeInputAmount(data), INPUT_AMOUNT);
        assertEq(swapHook.decodeOutputQuote(data), OUTPUT_QUOTE);
        assertEq(swapHook.decodeOutputMin(data), OUTPUT_MIN);
        assertTrue(swapHook.decodeUsePrevHookAmount(data));
        assertEq(swapHook.decodePayload(data), payload);
        assertEq(swapHook.inspect(data), abi.encodePacked(address(outputToken)));

        uint256[] memory amounts = swapHook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], INPUT_AMOUNT);

        ISuperHookInflowOutflow.AmountMeta[] memory roles = swapHook.amountRoles(data);
        assertEq(roles.length, 1);
        assertEq(uint256(roles[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(roles[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));

        amounts[0] = 123_456;
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, amounts);
        assertEq(swapHook.decodeInputAmount(replaced), 123_456);
        assertEq(swapHook.decodeOutputQuote(replaced), OUTPUT_QUOTE);
        assertEq(swapHook.decodeOutputMin(replaced), OUTPUT_MIN);
        assertEq(swapHook.decodePayload(replaced), payload);
    }

    function test_SwapHookBuildsClassicRouterCall() public view {
        bytes memory path = _classicPath(address(inputToken), address(outputToken), true);
        Execution[] memory executions = swapHook.build(address(0), account, _defaultData(0, path, false));

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 0);

        (bytes memory commands, bytes[] memory inputs, uint256 deadline) = _decodeExecute(executions[1].callData);
        assertEq(uint32(IAerodromeUniversalRouter.execute.selector), uint32(0x3593564c));
        assertEq(uint32(_selector(executions[1].callData)), uint32(IAerodromeUniversalRouter.execute.selector));
        assertEq(commands, hex"08");
        assertEq(inputs.length, 1);
        assertEq(deadline, DEADLINE);
        _assertRouterInput(inputs[0], INPUT_AMOUNT, OUTPUT_MIN, path);
    }

    function test_ApproveAndSwapBuildsTemporaryDirectApprovalPlan() public view {
        bytes memory path = _slipstreamPath(address(inputToken), address(outputToken), 100);
        Execution[] memory executions = approveAndSwapHook.build(address(0), account, _defaultData(1, path, false));

        assertEq(executions.length, 6);
        _assertApproval(executions[1], 0);
        _assertApproval(executions[2], INPUT_AMOUNT);
        assertEq(executions[3].target, address(router));
        _assertApproval(executions[4], 0);

        (bytes memory commands, bytes[] memory inputs, uint256 deadline) = _decodeExecute(executions[3].callData);
        assertEq(commands, hex"00");
        assertEq(deadline, DEADLINE);
        _assertRouterInput(inputs[0], INPUT_AMOUNT, OUTPUT_MIN, path);
    }

    function test_ApproveAndSwapExecutesAndClearsAllowance() public {
        bytes memory path = _classicPath(address(inputToken), address(outputToken), false);
        bytes memory data = _defaultData(0, path, false);
        inputToken.mint(account, INPUT_AMOUNT);
        router.configure(address(inputToken), address(outputToken), 777, 0);

        Execution[] memory executions = approveAndSwapHook.build(address(0), account, data);
        _execute(executions);

        assertEq(inputToken.balanceOf(account), 0);
        assertEq(inputToken.balanceOf(address(router)), INPUT_AMOUNT);
        assertEq(outputToken.balanceOf(account), 777);
        assertEq(inputToken.allowance(account, address(router)), 0);
        assertEq(approveAndSwapHook.getOutAmount(account), 777);
        assertEq(approveAndSwapHook.getOutToken(account), address(outputToken));
        assertEq(router.lastCommands(), hex"08");
        assertEq(router.lastRecipient(), account);
        assertEq(router.lastAmountIn(), INPUT_AMOUNT);
        assertEq(router.lastAmountOutMin(), OUTPUT_MIN);
        assertEq(router.lastPackedPath(), path);
        assertTrue(router.lastPayerIsUser());
        assertFalse(router.lastIsUni());
        assertEq(router.lastDeadline(), DEADLINE);
    }

    function test_SwapExecutesWithExistingDirectAllowance() public {
        bytes memory path = _slipstreamPath(address(inputToken), address(outputToken), 0x080064);
        inputToken.mint(account, INPUT_AMOUNT);
        inputToken.approve(address(router), INPUT_AMOUNT);
        router.configure(address(inputToken), address(outputToken), 888, 0);

        Execution[] memory executions = swapHook.build(address(0), account, _defaultData(1, path, false));
        _execute(executions);

        assertEq(outputToken.balanceOf(account), 888);
        assertEq(swapHook.getOutAmount(account), 888);
        assertEq(swapHook.getOutToken(account), address(outputToken));
        assertEq(router.lastCommands(), hex"00");
    }

    function test_ClassicVolatileStableAndMultihopRoutes() public view {
        _assertBuilds(0, _classicPath(address(inputToken), address(outputToken), false), hex"08");
        _assertBuilds(0, _classicPath(address(inputToken), address(outputToken), true), hex"08");

        address[] memory tokens = new address[](3);
        tokens[0] = address(inputToken);
        tokens[1] = address(0xCAFE);
        tokens[2] = address(outputToken);
        uint8[] memory params = new uint8[](2);
        params[0] = 0;
        params[1] = 1;
        _assertBuilds(0, _classicPath(tokens, params), hex"08");
    }

    function test_SlipstreamFactorySelectorsAndMultihopRoutes() public view {
        _assertBuilds(1, _slipstreamPath(address(inputToken), address(outputToken), 100), hex"00");
        _assertBuilds(1, _slipstreamPath(address(inputToken), address(outputToken), 0x100064), hex"00");
        _assertBuilds(1, _slipstreamPath(address(inputToken), address(outputToken), 0x080064), hex"00");

        address[] memory tokens = new address[](3);
        tokens[0] = address(inputToken);
        tokens[1] = address(0xBEEF);
        tokens[2] = address(outputToken);
        uint24[] memory params = new uint24[](2);
        params[0] = 1;
        params[1] = 0x1000c8;
        _assertBuilds(1, _slipstreamPath(tokens, params), hex"00");
    }

    function test_DeadlineEqualToCurrentTimestampIsAccepted() public view {
        bytes memory path = _classicPath(address(inputToken), address(outputToken), false);
        bytes memory payload = abi.encode(uint8(0), block.timestamp, path);
        swapHook.build(
            address(0),
            account,
            _encodeData(
                swapHook,
                address(inputToken),
                address(outputToken),
                INPUT_AMOUNT,
                OUTPUT_QUOTE,
                OUTPUT_MIN,
                false,
                payload
            )
        );
    }

    function test_PreviousHookScalesUpDownSameAndUsesEffectiveApproval() public {
        bytes memory path = _classicPath(address(inputToken), address(outputToken), false);

        previousResult.setResult(address(inputToken), 2000);
        Execution[] memory up = approveAndSwapHook.build(address(previousResult), account, _defaultData(0, path, true));
        _assertApproval(up[2], 2000);
        (, bytes[] memory upInputs,) = _decodeExecute(up[3].callData);
        _assertRouterInput(upInputs[0], 2000, 1800, path);

        previousResult.setResult(address(inputToken), 500);
        Execution[] memory down = swapHook.build(address(previousResult), account, _defaultData(0, path, true));
        (, bytes[] memory downInputs,) = _decodeExecute(down[1].callData);
        _assertRouterInput(downInputs[0], 500, 450, path);

        previousResult.setResult(address(inputToken), INPUT_AMOUNT);
        Execution[] memory same = swapHook.build(address(previousResult), account, _defaultData(0, path, true));
        (, bytes[] memory sameInputs,) = _decodeExecute(same[1].callData);
        _assertRouterInput(sameInputs[0], INPUT_AMOUNT, OUTPUT_MIN, path);
    }

    function test_PreviousHookScalingUsesRepositoryPrecisionQuantization() public {
        bytes memory path = _classicPath(address(inputToken), address(outputToken), false);
        previousResult.setResult(address(inputToken), INPUT_AMOUNT + 1);

        Execution[] memory executions = swapHook.build(address(previousResult), account, _defaultData(0, path, true));
        (, bytes[] memory inputs,) = _decodeExecute(executions[1].callData);
        _assertRouterInput(inputs[0], INPUT_AMOUNT + 1, OUTPUT_MIN, path);
    }

    function test_PreviousHookRejectsAbsentEoaMalformedDirtyTokenMismatchAndZeroAmount() public {
        bytes memory data = _defaultData(0, _classicPath(address(inputToken), address(outputToken), false), true);
        address eoaPreviousHook = makeAddr("eoaPreviousHook");
        EmptyAerodromePreviousResult emptyPreviousResult = new EmptyAerodromePreviousResult();
        DirtyTokenAerodromePreviousResult dirtyTokenPreviousResult = new DirtyTokenAerodromePreviousResult();

        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_PREV_HOOK.selector);
        swapHook.build(address(0), account, data);

        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_PREV_HOOK.selector);
        swapHook.build(eoaPreviousHook, account, data);

        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_PREV_HOOK.selector);
        swapHook.build(address(emptyPreviousResult), account, data);

        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_PREV_HOOK.selector);
        swapHook.build(address(dirtyTokenPreviousResult), account, data);

        previousResult.setResult(address(outputToken), INPUT_AMOUNT);
        vm.expectRevert(BaseAerodromeUniversalRouterHook.PREV_HOOK_TOKEN_MISMATCH.selector);
        swapHook.build(address(previousResult), account, data);

        previousResult.setResult(address(inputToken), 0);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        swapHook.build(address(previousResult), account, data);
    }

    function test_RejectsMalformedOuterEnvelope() public {
        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(0), account, new bytes(220));

        bytes memory data = _defaultData(0, _classicPath(address(inputToken), address(outputToken), false), false);
        data[188] = bytes1(uint8(2));
        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(0), account, data);

        data = _defaultData(0, _classicPath(address(inputToken), address(outputToken), false), false);
        _writeWord(data, 189, data.length - 220);
        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(0), account, data);

        data = _defaultData(0, _classicPath(address(inputToken), address(outputToken), false), false);
        _writeWord(data, 189, data.length - 222);
        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(0), account, data);

        data = bytes.concat(
            _defaultData(0, _classicPath(address(inputToken), address(outputToken), false), false), bytes1(0)
        );
        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(0), account, data);
    }

    function test_RejectsNonCanonicalPayloadEncoding() public {
        bytes memory path = _classicPath(address(inputToken), address(outputToken), false);
        bytes memory payload = abi.encode(uint8(0), DEADLINE, path);

        bytes memory dirtyRoute = _copy(payload);
        dirtyRoute[30] = bytes1(uint8(1));
        _expectPayloadRevert(dirtyRoute);

        bytes memory alternateOffset = _copy(payload);
        _writeWord(alternateOffset, 64, 128);
        _expectPayloadRevert(alternateOffset);

        bytes memory wrongLength = _copy(payload);
        _writeWord(wrongLength, 96, 1);
        _expectPayloadRevert(wrongLength);

        bytes memory dirtyPadding = _copy(payload);
        dirtyPadding[128 + path.length] = bytes1(uint8(1));
        _expectPayloadRevert(dirtyPadding);

        _expectPayloadRevert(bytes.concat(payload, bytes1(0)));
        _expectPayloadRevert(new bytes(127));
    }

    function test_RejectsInvalidHeaderValues() public {
        bytes memory path = _classicPath(address(inputToken), address(outputToken), false);
        bytes memory payload = abi.encode(uint8(0), DEADLINE, path);

        _expectBuildRevert(
            BaseHook.ADDRESS_NOT_VALID.selector,
            address(0),
            _encodeData(swapHook, address(inputToken), address(outputToken), 1, 1, 1, false, payload)
        );
        _expectBuildRevert(
            BaseAerodromeUniversalRouterHook.NATIVE_TOKEN_NOT_SUPPORTED.selector,
            account,
            _encodeData(swapHook, address(0), address(outputToken), 1, 1, 1, false, payload)
        );
        _expectBuildRevert(
            BaseAerodromeUniversalRouterHook.NATIVE_TOKEN_NOT_SUPPORTED.selector,
            account,
            _encodeData(swapHook, NATIVE, address(outputToken), 1, 1, 1, false, payload)
        );
        _expectBuildRevert(
            BaseAerodromeUniversalRouterHook.NATIVE_TOKEN_NOT_SUPPORTED.selector,
            account,
            _encodeData(swapHook, address(inputToken), address(0), 1, 1, 1, false, payload)
        );
        _expectBuildRevert(
            BaseAerodromeUniversalRouterHook.SAME_INPUT_OUTPUT_TOKEN.selector,
            account,
            _encodeData(swapHook, address(inputToken), address(inputToken), 1, 1, 1, false, payload)
        );
        _expectBuildRevert(
            BaseHook.AMOUNT_NOT_VALID.selector,
            account,
            _encodeData(swapHook, address(inputToken), address(outputToken), 0, 1, 1, false, payload)
        );
        _expectBuildRevert(
            BaseAerodromeUniversalRouterHook.INVALID_OUTPUT_AMOUNTS.selector,
            account,
            _encodeData(swapHook, address(inputToken), address(outputToken), 1, 1, 0, false, payload)
        );
        _expectBuildRevert(
            BaseAerodromeUniversalRouterHook.INVALID_OUTPUT_AMOUNTS.selector,
            account,
            _encodeData(swapHook, address(inputToken), address(outputToken), 1, 9, 10, false, payload)
        );
    }

    function test_RejectsUnsupportedRouteAndExpiredDeadline() public {
        bytes memory path = _classicPath(address(inputToken), address(outputToken), false);
        _expectPayloadBuildRevert(
            BaseAerodromeUniversalRouterHook.INVALID_ROUTE_KIND.selector, abi.encode(uint8(2), DEADLINE, path)
        );
        _expectPayloadBuildRevert(
            abi.encodeWithSelector(BaseAerodromeUniversalRouterHook.EXPIRED_DEADLINE.selector, 999, block.timestamp),
            abi.encode(uint8(0), 999, path)
        );
    }

    function test_RejectsClassicPathBoundaries() public {
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_PATH_LENGTH.selector, 0, abi.encodePacked(address(inputToken))
        );
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_PATH_LENGTH.selector,
            0,
            bytes.concat(_classicPath(address(inputToken), address(outputToken), false), bytes1(0))
        );

        bytes memory badFlag = _classicPath(address(inputToken), address(outputToken), false);
        badFlag[20] = bytes1(uint8(2));
        _expectPathRevert(BaseAerodromeUniversalRouterHook.INVALID_STABLE_FLAG.selector, 0, badFlag);

        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_PATH.selector,
            0,
            _classicPath(makeAddr("wrongClassicStart"), address(outputToken), false)
        );
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_PATH.selector,
            0,
            _classicPath(address(inputToken), makeAddr("wrongClassicEnd"), false)
        );
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_PATH.selector,
            0,
            _classicPath(address(inputToken), address(inputToken), false)
        );
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.NATIVE_TOKEN_NOT_SUPPORTED.selector,
            0,
            _classicPath(address(inputToken), NATIVE, false)
        );

        address[] memory zeroMiddleTokens = new address[](3);
        zeroMiddleTokens[0] = address(inputToken);
        zeroMiddleTokens[1] = address(0);
        zeroMiddleTokens[2] = address(outputToken);
        uint8[] memory flags = new uint8[](2);
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.NATIVE_TOKEN_NOT_SUPPORTED.selector,
            0,
            _classicPath(zeroMiddleTokens, flags)
        );

        address[] memory tenHopTokens = new address[](11);
        uint8[] memory tenFlags = new uint8[](10);
        for (uint256 i; i < tenHopTokens.length; ++i) {
            tenHopTokens[i] = address(uint160(i + 1));
        }
        bytes memory tenHopPath = _classicPath(tenHopTokens, tenFlags);
        bytes memory payload = abi.encode(uint8(0), DEADLINE, tenHopPath);
        bytes memory data = _encodeData(
            swapHook, tenHopTokens[0], tenHopTokens[10], INPUT_AMOUNT, OUTPUT_QUOTE, OUTPUT_MIN, false, payload
        );
        _expectBuildRevert(BaseAerodromeUniversalRouterHook.INVALID_PAYLOAD.selector, account, data);
    }

    function test_RejectsSlipstreamPathBoundaries() public {
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_PATH_LENGTH.selector, 1, abi.encodePacked(address(inputToken))
        );
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_PATH_LENGTH.selector,
            1,
            bytes.concat(_slipstreamPath(address(inputToken), address(outputToken), 1), bytes1(0))
        );
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_POOL_PARAM.selector,
            1,
            _slipstreamPath(address(inputToken), address(outputToken), 0)
        );
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_POOL_PARAM.selector,
            1,
            _slipstreamPath(address(inputToken), address(outputToken), 0x180001)
        );
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_POOL_PARAM.selector,
            1,
            _slipstreamPath(address(inputToken), address(outputToken), 0x200001)
        );
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_PATH.selector,
            1,
            _slipstreamPath(makeAddr("wrongSlipstreamStart"), address(outputToken), 1)
        );
        _expectPathRevert(
            BaseAerodromeUniversalRouterHook.INVALID_PATH.selector,
            1,
            _slipstreamPath(address(inputToken), makeAddr("wrongSlipstreamEnd"), 1)
        );
    }

    function test_PostExecuteRejectsDecreasedOutputBalance() public {
        bytes memory path = _classicPath(address(inputToken), address(outputToken), false);
        inputToken.mint(account, INPUT_AMOUNT);
        outputToken.mint(account, 100);
        router.configure(address(inputToken), address(outputToken), 0, 1);
        Execution[] memory executions = approveAndSwapHook.build(address(0), account, _defaultData(0, path, false));

        for (uint256 i; i < executions.length - 1; ++i) {
            _executeOne(executions[i]);
        }
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        _executeOne(executions[executions.length - 1]);
    }

    function test_PublicHelpersRejectShortOrInvalidSizingData() public {
        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_HOOK_DATA.selector);
        swapHook.decodeUsePrevHookAmount(new bytes(188));

        bytes memory invalidBool = new bytes(189);
        invalidBool[188] = bytes1(uint8(2));
        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_HOOK_DATA.selector);
        swapHook.decodeUsePrevHookAmount(invalidBool);

        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_HOOK_DATA.selector);
        swapHook.decodeAmounts(new bytes(123));

        uint256[] memory amounts = new uint256[](2);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        swapHook.replaceCalldataAmounts(new bytes(124), amounts);

        amounts = new uint256[](1);
        vm.expectRevert(BaseAerodromeUniversalRouterHook.INVALID_HOOK_DATA.selector);
        swapHook.replaceCalldataAmounts(new bytes(123), amounts);
    }

    function testFuzz_StandardHeaderRoundTrip(
        address fuzzInput,
        address fuzzOutput,
        uint256 fuzzInputAmount,
        uint256 fuzzQuote,
        uint256 fuzzMinimum,
        bool fuzzUsePrevious,
        bytes memory fuzzPayload
    )
        public
        view
    {
        vm.assume(fuzzPayload.length <= 512);
        bytes memory data = _encodeData(
            swapHook, fuzzInput, fuzzOutput, fuzzInputAmount, fuzzQuote, fuzzMinimum, fuzzUsePrevious, fuzzPayload
        );

        assertEq(swapHook.decodeInputToken(data), fuzzInput);
        assertEq(swapHook.decodeOutputToken(data), fuzzOutput);
        assertEq(swapHook.decodeInputAmount(data), fuzzInputAmount);
        assertEq(swapHook.decodeOutputQuote(data), fuzzQuote);
        assertEq(swapHook.decodeOutputMin(data), fuzzMinimum);
        assertEq(swapHook.decodeUsePrevHookAmount(data), fuzzUsePrevious);
        assertEq(swapHook.decodePayload(data), fuzzPayload);
    }

    function testFuzz_AmountReplacementPreservesRemainingSwapData(uint256 replacementAmount) public view {
        bytes memory path = _slipstreamPath(address(inputToken), address(outputToken), 0x100064);
        bytes memory data = _defaultData(1, path, true);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = replacementAmount;

        bytes memory replaced = swapHook.replaceCalldataAmounts(data, amounts);

        assertEq(swapHook.decodeInputToken(replaced), address(inputToken));
        assertEq(swapHook.decodeOutputToken(replaced), address(outputToken));
        assertEq(swapHook.decodeInputAmount(replaced), replacementAmount);
        assertEq(swapHook.decodeOutputQuote(replaced), OUTPUT_QUOTE);
        assertEq(swapHook.decodeOutputMin(replaced), OUTPUT_MIN);
        assertTrue(swapHook.decodeUsePrevHookAmount(replaced));
        assertEq(swapHook.decodePayload(replaced), swapHook.decodePayload(data));
    }

    function testFuzz_ValidClassicPathsBuild(uint8 fuzzHops, uint256 salt) public view {
        uint256 hops = bound(uint256(fuzzHops), 1, 9);
        address[] memory tokens = new address[](hops + 1);
        uint8[] memory flags = new uint8[](hops);
        for (uint256 i; i < tokens.length; ++i) {
            tokens[i] = address(uint160(uint256(keccak256(abi.encode(salt, i))) | 1));
            if (i != 0 && tokens[i] == tokens[i - 1]) tokens[i] = address(uint160(uint256(uint160(tokens[i])) + 1));
        }
        for (uint256 i; i < hops; ++i) {
            flags[i] = uint8(i % 2);
        }

        bytes memory path = _classicPath(tokens, flags);
        bytes memory payload = abi.encode(uint8(0), DEADLINE, path);
        bytes memory data =
            _encodeData(swapHook, tokens[0], tokens[hops], INPUT_AMOUNT, OUTPUT_QUOTE, OUTPUT_MIN, false, payload);
        Execution[] memory executions = swapHook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    function testFuzz_ValidSlipstreamPathsBuild(uint8 fuzzHops, uint24 fuzzSpacing) public view {
        uint256 hops = bound(uint256(fuzzHops), 1, 9);
        uint24 spacing = uint24(bound(uint256(fuzzSpacing), 1, 0x07ffff));
        address[] memory tokens = new address[](hops + 1);
        uint24[] memory params = new uint24[](hops);
        for (uint256 i; i < tokens.length; ++i) {
            tokens[i] = address(uint160(i + 1));
        }
        for (uint256 i; i < hops; ++i) {
            uint24 selector = i % 3 == 0 ? 0 : (i % 3 == 1 ? uint24(0x080000) : uint24(0x100000));
            params[i] = selector | spacing;
        }

        bytes memory path = _slipstreamPath(tokens, params);
        bytes memory payload = abi.encode(uint8(1), DEADLINE, path);
        bytes memory data =
            _encodeData(swapHook, tokens[0], tokens[hops], INPUT_AMOUNT, OUTPUT_QUOTE, OUTPUT_MIN, false, payload);
        Execution[] memory executions = swapHook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    function _defaultData(
        uint8 routeKind,
        bytes memory path,
        bool usePrevious
    )
        private
        view
        returns (bytes memory)
    {
        return _encodeData(
            swapHook,
            address(inputToken),
            address(outputToken),
            INPUT_AMOUNT,
            OUTPUT_QUOTE,
            OUTPUT_MIN,
            usePrevious,
            abi.encode(routeKind, DEADLINE, path)
        );
    }

    function _encodeData(
        ISuperHookSwap hook,
        address input,
        address output,
        uint256 amount,
        uint256 quote,
        uint256 minimum,
        bool usePrevious,
        bytes memory payload
    )
        private
        pure
        returns (bytes memory)
    {
        return hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: input,
                outputToken: output,
                inputAmount: amount,
                outputQuote: quote,
                outputMin: minimum,
                usePrevHookAmount: usePrevious
            }),
            payload
        );
    }

    function _classicPath(address input, address output, bool stable) private pure returns (bytes memory) {
        return abi.encodePacked(input, bytes1(stable ? uint8(1) : uint8(0)), output);
    }

    function _classicPath(address[] memory tokens, uint8[] memory flags) private pure returns (bytes memory path) {
        require(tokens.length == flags.length + 1, "classic test path mismatch");
        path = abi.encodePacked(tokens[0]);
        for (uint256 i; i < flags.length; ++i) {
            path = abi.encodePacked(path, bytes1(flags[i]), tokens[i + 1]);
        }
    }

    function _slipstreamPath(address input, address output, uint24 poolParam) private pure returns (bytes memory) {
        return abi.encodePacked(input, poolParam, output);
    }

    function _slipstreamPath(
        address[] memory tokens,
        uint24[] memory params
    )
        private
        pure
        returns (bytes memory path)
    {
        require(tokens.length == params.length + 1, "slipstream test path mismatch");
        path = abi.encodePacked(tokens[0]);
        for (uint256 i; i < params.length; ++i) {
            path = abi.encodePacked(path, params[i], tokens[i + 1]);
        }
    }

    function _decodeExecute(bytes memory callData)
        private
        pure
        returns (bytes memory commands, bytes[] memory inputs, uint256 deadline)
    {
        return abi.decode(callData.slice(4, callData.length - 4), (bytes, bytes[], uint256));
    }

    function _assertRouterInput(
        bytes memory input,
        uint256 expectedAmount,
        uint256 expectedMinimum,
        bytes memory expectedPath
    )
        private
        view
    {
        (address recipient, uint256 amount, uint256 minimum, bytes memory path, bool payerIsUser, bool isUni) =
            abi.decode(input, (address, uint256, uint256, bytes, bool, bool));
        assertEq(recipient, account);
        assertEq(amount, expectedAmount);
        assertEq(minimum, expectedMinimum);
        assertEq(path, expectedPath);
        assertTrue(payerIsUser);
        assertFalse(isUni);
    }

    function _assertApproval(Execution memory execution, uint256 expectedAmount) private view {
        assertEq(execution.target, address(inputToken));
        assertEq(execution.value, 0);
        assertEq(uint32(_selector(execution.callData)), uint32(IERC20.approve.selector));
        (address spender, uint256 amount) =
            abi.decode(execution.callData.slice(4, execution.callData.length - 4), (address, uint256));
        assertEq(spender, address(router));
        assertEq(amount, expectedAmount);
    }

    function _assertBuilds(uint8 routeKind, bytes memory path, bytes memory expectedCommand) private view {
        Execution[] memory executions = swapHook.build(address(0), account, _defaultData(routeKind, path, false));
        (bytes memory commands, bytes[] memory inputs,) = _decodeExecute(executions[1].callData);
        assertEq(commands, expectedCommand);
        _assertRouterInput(inputs[0], INPUT_AMOUNT, OUTPUT_MIN, path);
    }

    function _expectPayloadRevert(bytes memory payload) private {
        _expectPayloadBuildRevert(BaseAerodromeUniversalRouterHook.INVALID_PAYLOAD.selector, payload);
    }

    function _expectPayloadBuildRevert(bytes memory reason, bytes memory payload) private {
        bytes memory data = _encodeData(
            swapHook, address(inputToken), address(outputToken), INPUT_AMOUNT, OUTPUT_QUOTE, OUTPUT_MIN, false, payload
        );
        vm.expectRevert(reason);
        swapHook.build(address(0), account, data);
    }

    function _expectPayloadBuildRevert(bytes4 selector, bytes memory payload) private {
        bytes memory data = _encodeData(
            swapHook, address(inputToken), address(outputToken), INPUT_AMOUNT, OUTPUT_QUOTE, OUTPUT_MIN, false, payload
        );
        vm.expectRevert(selector);
        swapHook.build(address(0), account, data);
    }

    function _expectPathRevert(bytes4 selector, uint8 routeKind, bytes memory path) private {
        _expectPayloadBuildRevert(selector, abi.encode(routeKind, DEADLINE, path));
    }

    function _expectBuildRevert(bytes4 selector, address buildAccount, bytes memory data) private {
        vm.expectRevert(selector);
        swapHook.build(address(0), buildAccount, data);
    }

    function _execute(Execution[] memory executions) private {
        for (uint256 i; i < executions.length; ++i) {
            _executeOne(executions[i]);
        }
    }

    function _executeOne(Execution memory execution) private {
        (bool success, bytes memory returnData) = execution.target.call{ value: execution.value }(execution.callData);
        if (!success) {
            assembly ("memory-safe") {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }

    function _writeWord(bytes memory data, uint256 offset, uint256 value) private pure {
        require(data.length >= offset + 32, "test write out of bounds");
        assembly ("memory-safe") {
            mstore(add(add(data, 0x20), offset), value)
        }
    }

    function _copy(bytes memory data) private pure returns (bytes memory) {
        return bytes.concat(data);
    }

    function _selector(bytes memory callData) private pure returns (bytes4 selector) {
        assembly ("memory-safe") {
            selector := mload(add(callData, 0x20))
        }
    }
}
