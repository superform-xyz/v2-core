// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { SwapCalldataLayout } from "../../../../../src/libraries/SwapCalldataLayout.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { ISuperHookSwap } from "../../../../../src/interfaces/ISuperHookSwap.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { ApproveAndTradeGyldBondHook } from "../../../../../src/hooks/swappers/gyld/ApproveAndTradeGyldBondHook.sol";
import { GyldBondRegistry } from "../../../../../src/accounting/oracles/GyldBondRegistry.sol";

import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../../mocks/MockAggregator.sol";
import { MockGyldSettlement } from "../../../../mocks/gyld/MockGyldSettlement.sol";

/// @title GyldSwapEncodingConformanceTest
/// @notice Pins `ApproveAndTradeGyldBondHook` to the Layer 1 swap calldata standard declared by
///         `SwapCalldataLayout` and `ISuperHookSwap`, field by field and byte by byte.
/// @dev THERE IS NO REPO-WIDE SWAP-LAYOUT CONFORMANCE SUITE. `HookSizingInterface.t.sol` pins the sizing
///      interfaces across the whole fleet, but nothing pins the swap byte layout, so each swapper's
///      conformance rests on having been written by copying a peer. This suite checks the Gyld hook against
///      the LIBRARY CONSTANTS rather than against hardcoded numbers, so a change to the standard surfaces
///      here instead of silently desynchronising the hook from the off-chain encoder.
contract GyldSwapEncodingConformanceTest is Test {
    ApproveAndTradeGyldBondHook internal hook;
    GyldBondRegistry internal registry;
    MockGyldSettlement internal settlement;

    MockERC20 internal bond;
    MockERC20 internal cash;
    MockAggregator internal navFeed;

    address internal admin = address(0xA11CE);

    /// @dev Sentinels chosen so a field read at the wrong offset cannot coincidentally match.
    address internal constant SENTINEL_IN = address(0x1111111111111111111111111111111111111111);
    address internal constant SENTINEL_OUT = address(0x2222222222222222222222222222222222222222);
    uint256 internal constant SENTINEL_AMOUNT = 0x33;
    uint256 internal constant SENTINEL_QUOTE = 0x44;
    uint256 internal constant SENTINEL_MIN = 0x55;

    function setUp() public {
        vm.warp(1_800_000_000);
        bond = new MockERC20("Gyld Bond", "GB", 18);
        cash = new MockERC20("Vault Bridge USDC", "vbUSDC", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(1e8);

        registry = new GyldBondRegistry(admin);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.cashToken = address(cash);
        cfg.navFeed = address(navFeed);
        cfg.maxObservationAge = 2 days;
        cfg.maxPublicationAge = 2 hours;
        vm.prank(admin);
        registry.registerInstrument(cfg);

        settlement = new MockGyldSettlement();
        hook = new ApproveAndTradeGyldBondHook(address(settlement), address(registry), type(uint128).max);
    }

    function _header(bool usePrev) internal pure returns (ISuperHookSwap.SwapHeader memory) {
        return ISuperHookSwap.SwapHeader({
            inputToken: SENTINEL_IN,
            outputToken: SENTINEL_OUT,
            inputAmount: SENTINEL_AMOUNT,
            outputQuote: SENTINEL_QUOTE,
            outputMin: SENTINEL_MIN,
            usePrevHookAmount: usePrev
        });
    }

    /*//////////////////////////////////////////////////////////////
                   THE ENCODER WRITES THE DECLARED LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @dev Every field must land at the offset the LIBRARY declares, verified by slicing the encoder's
    ///      output rather than by trusting the hook's own decoders. If the encoder and the decoders were
    ///      consistently wrong, a decoder round-trip would still pass; this cannot.
    function test_EncodeSwapData_WritesEveryFieldAtTheDeclaredOffset() public view {
        bytes memory payload = hex"aabbccdd";
        bytes memory data = hook.encodeSwapData(_header(false), payload);

        // Layer 0: the strategy header must be exactly HEADER_SIZE zero bytes.
        for (uint256 i; i < SwapCalldataLayout.HEADER_SIZE; ++i) {
            assertEq(uint8(data[i]), 0, "Layer 0 must be zero-filled");
        }

        assertEq(BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET), SENTINEL_IN, "inputToken@52");
        assertEq(BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), SENTINEL_OUT, "outputToken@72");
        assertEq(BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET), SENTINEL_AMOUNT, "amount@92");
        assertEq(BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET), SENTINEL_QUOTE, "quote@124");
        assertEq(BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET), SENTINEL_MIN, "min@156");
        assertEq(uint8(data[SwapCalldataLayout.USE_PREV_HOOK_OFFSET]), 0, "usePrevHookAmount@188");
        assertEq(
            BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET), payload.length, "payloadLength@189"
        );
        assertEq(BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payload.length), payload, "payload@221");
    }

    /// @dev The one-byte bool must be exactly 1 when true, not merely non-zero at some other position.
    function test_EncodeSwapData_UsePrevHookAmountIsOneByteAtOffset188() public view {
        bytes memory data = hook.encodeSwapData(_header(true), "");
        assertEq(uint8(data[SwapCalldataLayout.USE_PREV_HOOK_OFFSET]), 1, "true encodes as 0x01");
        assertTrue(hook.decodeUsePrevHookAmount(data), "and decodes as true");
    }

    /// @dev Total length must be exactly MIN_DATA_LENGTH plus the payload, so the standard's derived
    ///      constant and the encoder cannot drift apart.
    function test_EncodeSwapData_LengthIsMinDataLengthPlusPayload() public view {
        assertEq(hook.encodeSwapData(_header(false), "").length, SwapCalldataLayout.MIN_DATA_LENGTH);
        assertEq(hook.encodeSwapData(_header(false), hex"aabbccdd").length, SwapCalldataLayout.MIN_DATA_LENGTH + 4);
        bytes memory big = new bytes(1024);
        assertEq(hook.encodeSwapData(_header(false), big).length, SwapCalldataLayout.MIN_DATA_LENGTH + 1024);
    }

    /// @dev The declared offsets must be internally consistent: each field must start where the previous one
    ///      ends. This pins the STANDARD, so a change to the library is caught here too.
    function test_LayoutConstantsAreContiguous() public pure {
        assertEq(SwapCalldataLayout.INPUT_TOKEN_OFFSET, SwapCalldataLayout.HEADER_SIZE, "input follows header");
        assertEq(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET, SwapCalldataLayout.INPUT_TOKEN_OFFSET + 20);
        assertEq(SwapCalldataLayout.INPUT_AMOUNT_OFFSET, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET + 20);
        assertEq(SwapCalldataLayout.OUTPUT_QUOTE_OFFSET, SwapCalldataLayout.INPUT_AMOUNT_OFFSET + 32);
        assertEq(SwapCalldataLayout.OUTPUT_MIN_OFFSET, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET + 32);
        assertEq(SwapCalldataLayout.USE_PREV_HOOK_OFFSET, SwapCalldataLayout.OUTPUT_MIN_OFFSET + 32);
        assertEq(SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET, SwapCalldataLayout.USE_PREV_HOOK_OFFSET + 1);
        assertEq(SwapCalldataLayout.PAYLOAD_DATA_OFFSET, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET + 32);
        assertEq(SwapCalldataLayout.MIN_DATA_LENGTH, SwapCalldataLayout.PAYLOAD_DATA_OFFSET);
        assertEq(SwapCalldataLayout.AMOUNT_POSITION, SwapCalldataLayout.INPUT_AMOUNT_OFFSET, "sizing alias");
    }

    /*//////////////////////////////////////////////////////////////
               THE DECODERS READ THE SAME OFFSETS, INDEPENDENTLY
    //////////////////////////////////////////////////////////////*/

    /// @dev Build the data by hand from the library constants, then assert each decoder returns its own
    ///      field. A decoder reading a neighbouring offset would pick up a different sentinel.
    function test_Decoders_ReadTheDeclaredOffsets() public view {
        bytes memory payload = hex"deadbeef";
        bytes memory data = abi.encodePacked(
            new bytes(SwapCalldataLayout.HEADER_SIZE),
            bytes20(SENTINEL_IN),
            bytes20(SENTINEL_OUT),
            SENTINEL_AMOUNT,
            SENTINEL_QUOTE,
            SENTINEL_MIN,
            false,
            payload.length,
            payload
        );
        assertEq(data.length, SwapCalldataLayout.MIN_DATA_LENGTH + payload.length, "hand-built length");

        assertEq(hook.decodeInputToken(data), SENTINEL_IN);
        assertEq(hook.decodeOutputToken(data), SENTINEL_OUT);
        assertEq(hook.decodeInputAmount(data), SENTINEL_AMOUNT);
        assertEq(hook.decodeOutputQuote(data), SENTINEL_QUOTE);
        assertEq(hook.decodeOutputMin(data), SENTINEL_MIN);
        assertEq(hook.decodePayload(data), payload);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    /// @dev The encoder's output must be consumable by the hook's own decoders AND by `build()`, which is
    ///      what makes `encodeSwapData` usable as the off-chain encoder rather than documentation.
    function test_EncoderOutputIsBuildable() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory venue = settlement.encodeFill(
            keccak256("q"), address(this), address(cash), address(bond), 1000e6, 1000e18, deadline
        );
        bytes memory payload = abi.encode(deadline, venue);

        bytes memory data = hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: address(cash),
                outputToken: address(bond),
                inputAmount: 1000e6,
                outputQuote: 1000e18,
                outputMin: 1000e18,
                usePrevHookAmount: false
            }),
            payload
        );

        assertEq(hook.decodePayload(data), payload, "payload survives the round trip");
        hook.build(address(0), address(this), data); // the encoder's output is executable
    }

    /*//////////////////////////////////////////////////////////////
                      FAMILY CONVENTIONS, PINNED
    //////////////////////////////////////////////////////////////*/

    /// @dev `ISuperHookSwap` is NOT an ERC-165-advertised interface anywhere in the fleet; the Aerodrome
    ///      suite asserts the same `assertFalse`. Advertising it would be the deviation.
    function test_ISuperHookSwapIsNotAdvertisedViaErc165() public view {
        assertFalse(hook.supportsInterface(type(ISuperHookSwap).interfaceId));
    }

    /// @dev A SWAP-subtype hook must declare `HookSubTypes.SWAP`, which is how the OMS routes a leaf to the
    ///      swap encoder in the first place.
    function test_SubTypeIsSwap() public view {
        assertEq(hook.SUB_TYPE(), HookSubTypes.SWAP);
    }

    /// @dev Data shorter than MIN_DATA_LENGTH must be rejected before any fixed-offset read, so no decoder
    ///      can read past the end. Checked at the exact boundary.
    function test_RejectsDataShorterThanMinDataLength() public {
        vm.expectRevert(ApproveAndTradeGyldBondHook.INVALID_HOOK_DATA.selector);
        hook.build(address(0), address(this), new bytes(SwapCalldataLayout.MIN_DATA_LENGTH - 1));
        // And `inspect` carries its own length check, since the validator calls it independently of `build`.
        vm.expectRevert(ApproveAndTradeGyldBondHook.INVALID_HOOK_DATA.selector);
        hook.inspect(new bytes(SwapCalldataLayout.MIN_DATA_LENGTH - 1));
    }

    /// @dev KNOWN, DELIBERATE DEVIATION FROM THE MAJORITY, pinned so it is a decision rather than a
    ///      surprise. Most swappers treat `outputQuote` as informational and never constrain it: the
    ///      Binance E2E suite passes 0 for it. This hook requires `outputQuote >= outputMin` and
    ///      `outputMin != 0`, which follows `BaseAerodromeUniversalRouterHook`'s
    ///      `if (originalAmountOutMin == 0 || outputQuote < originalAmountOutMin) revert` precedent.
    ///      CONSEQUENCE FOR THE OFF-CHAIN ENCODER: a builder that leaves `outputQuote` at zero, as is
    ///      legitimate for Binance, produces leaves this hook REJECTS. The OMS must populate both fields.
    function test_Deviation_OutputQuoteIsConstrainedUnlikeMostPeers() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory payload = abi.encode(deadline, hex"deadbeef");

        // outputQuote = 0 with a real outputMin: accepted by Binance-style hooks, refused here.
        bytes memory quoteZero = hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: address(cash),
                outputToken: address(bond),
                inputAmount: 1000e6,
                outputQuote: 0,
                outputMin: 1000e18,
                usePrevHookAmount: false
            }),
            payload
        );
        vm.expectRevert(ApproveAndTradeGyldBondHook.QUOTE_BELOW_MIN.selector);
        hook.build(address(0), address(this), quoteZero);

        // outputMin = 0 is also refused: slippage protection is not opt-out, as on Aerodrome.
        bytes memory minZero = hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: address(cash),
                outputToken: address(bond),
                inputAmount: 1000e6,
                outputQuote: 1000e18,
                outputMin: 0,
                usePrevHookAmount: false
            }),
            payload
        );
        vm.expectRevert(ApproveAndTradeGyldBondHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(0), address(this), minZero);
    }

    /// @dev And the second deliberate deviation: `usePrevHookAmount` is ENCODABLE (the standard's bool is
    ///      written faithfully) but REJECTED at build, because a venue-signed quote cannot absorb a resized
    ///      amount. The flag must still decode correctly so the executor's own inspection agrees.
    function test_Deviation_UsePrevHookAmountEncodesButIsRejected() public {
        bytes memory payload = abi.encode(block.timestamp + 1 hours, hex"deadbeef");
        bytes memory data = hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: address(cash),
                outputToken: address(bond),
                inputAmount: 1000e6,
                outputQuote: 1000e18,
                outputMin: 1000e18,
                usePrevHookAmount: true
            }),
            payload
        );
        assertTrue(hook.decodeUsePrevHookAmount(data), "the standard's flag round-trips");
        vm.expectRevert(ApproveAndTradeGyldBondHook.USE_PREV_HOOK_NOT_SUPPORTED.selector);
        hook.build(address(0), address(this), data);
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev For ANY header and payload, the encoder's output decodes back to exactly what went in. This is
    ///      the property the off-chain encoder depends on.
    function testFuzz_EncodeDecodeRoundTrip(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputQuote,
        uint256 outputMin,
        bool usePrev,
        bytes calldata payload
    )
        public
        view
    {
        vm.assume(payload.length < 4000);
        bytes memory data = hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: inputToken,
                outputToken: outputToken,
                inputAmount: inputAmount,
                outputQuote: outputQuote,
                outputMin: outputMin,
                usePrevHookAmount: usePrev
            }),
            payload
        );

        assertEq(data.length, SwapCalldataLayout.MIN_DATA_LENGTH + payload.length);
        assertEq(hook.decodeInputToken(data), inputToken);
        assertEq(hook.decodeOutputToken(data), outputToken);
        assertEq(hook.decodeInputAmount(data), inputAmount);
        assertEq(hook.decodeOutputQuote(data), outputQuote);
        assertEq(hook.decodeOutputMin(data), outputMin);
        assertEq(hook.decodeUsePrevHookAmount(data), usePrev);
        assertEq(hook.decodePayload(data), payload);
        // `inspect` commits exactly the token pair, which is the leaf identity for every swapper.
        assertEq(hook.inspect(data), abi.encodePacked(inputToken, outputToken));
    }
}
