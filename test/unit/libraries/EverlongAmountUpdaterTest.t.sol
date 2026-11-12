// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { EverlongAmountUpdater } from "../../../src/libraries/EverlongAmountUpdater.sol";
import { ISwapRouter02 } from "../../../src/vendor/everlong/ISwapRouter02.sol";
import { EverlongKatanaFixtures } from "../../integration/everlong/EverlongKatanaFixtures.sol";

/// @dev Exposes the internal library so every branch is reachable from a test.
contract Harness {
    function readFields(bytes memory txData, address weth9)
        external
        pure
        returns (EverlongAmountUpdater.Fields memory)
    {
        return EverlongAmountUpdater.readFields(txData, weth9);
    }

    function rescale(bytes memory txData, address weth9, uint256 newAmount) external pure returns (bytes memory) {
        return EverlongAmountUpdater.rescale(txData, weth9, newAmount);
    }
}

contract EverlongAmountUpdaterTest is Test, EverlongKatanaFixtures {
    address private constant TOKEN_IN = address(0xA11CE);
    address private constant TOKEN_OUT = address(0xB0B);
    address private constant MID = address(0xC0DE);
    address private constant RCPT = address(0xCAFE);
    address private constant FEE_RCPT = address(0xFEE);
    address private constant THIS = address(2);
    uint256 private constant DEADLINE = 1_800_000_000;

    Harness private h;

    function setUp() public {
        h = new Harness();
    }

    /*//////////////////////////////////////////////////////////////
                           SELECTORS / LIVE SAMPLES
    //////////////////////////////////////////////////////////////*/

    function test_Selectors_PinnedToVendorInterface() public pure {
        assertEq(EverlongAmountUpdater.MULTICALL_SELECTOR, bytes4(0x5ae401dc));
        assertEq(EverlongAmountUpdater.EXACT_INPUT_SINGLE_SELECTOR, bytes4(0x04e45aaf));
        assertEq(EverlongAmountUpdater.EXACT_INPUT_SELECTOR, bytes4(0xb858183f));
        assertEq(EverlongAmountUpdater.SWEEP_TOKEN_SELECTOR, bytes4(0xdf2ab5bb));
        assertEq(EverlongAmountUpdater.SWEEP_TOKEN_WITH_FEE_SELECTOR, bytes4(0xe0e189a0));
        assertEq(EverlongAmountUpdater.UNWRAP_WETH9_SELECTOR, bytes4(0x49404b7c));
        assertEq(EverlongAmountUpdater.UNWRAP_WETH9_WITH_FEE_SELECTOR, bytes4(0x9b2c0a37));
        assertEq(EverlongAmountUpdater.REFUND_ETH_SELECTOR, bytes4(0x12210e8a));
    }

    function test_ReadFields_LiveSamples() public view {
        EverlongAmountUpdater.Fields memory f = h.readFields(TX_USDC_KAT, WETH9);
        assertEq(f.tokenIn, VB_USDC);
        assertEq(f.tokenOut, KAT);
        assertEq(f.totalIn, QUOTE_USDC_KAT_IN);
        assertEq(f.tailMin, TAIL_MIN_USDC_KAT);
        assertEq(f.recipient, API_RECIPIENT);
        assertEq(f.feeBips, FEE_BIPS);
        assertEq(f.feeRecipient, FEE_RECIPIENT);
        assertFalse(f.nativeOut);
        assertFalse(f.hasRefund);
        assertEq(f.deadline, DEADLINE_USDC_KAT);
        assertEq(f.swapLegs, 3);

        f = h.readFields(TX_NATIVE_IN_USDC, WETH9);
        assertEq(f.tokenIn, WETH9);
        assertEq(f.tokenOut, VB_USDC);
        assertEq(f.totalIn, QUOTE_NATIVE_USDC_IN);
        assertEq(f.tailMin, TAIL_MIN_NATIVE_USDC);
        assertTrue(f.hasRefund);
        assertFalse(f.nativeOut);
        assertEq(f.swapLegs, 6);

        f = h.readFields(TX_USDC_NATIVE_OUT, WETH9);
        assertEq(f.tokenIn, VB_USDC);
        assertEq(f.tokenOut, WETH9);
        assertEq(f.totalIn, QUOTE_USDC_NATIVE_IN);
        assertEq(f.tailMin, TAIL_MIN_USDC_NATIVE);
        assertTrue(f.nativeOut);
        assertTrue(f.hasRefund);
        assertEq(f.swapLegs, 2);

        f = h.readFields(TX_KAT_USDC, WETH9);
        assertEq(f.tokenIn, KAT);
        assertEq(f.tokenOut, VB_USDC);
        assertEq(f.totalIn, QUOTE_KAT_USDC_IN);
        assertEq(f.tailMin, TAIL_MIN_KAT_USDC);
        assertEq(f.feeBips, FEE_BIPS);
        assertEq(f.deadline, DEADLINE_KAT_USDC);
        assertEq(f.swapLegs, 4);
    }

    /// @dev The API output is canonical ABI: a 2x rescale re-encodes every call and keeps the exact byte length, and
    ///      rescaling back to the original amount reproduces the original bytes exactly (2x / 1/2 is exact under
    ///      floor/ceil). Same-amount rescale returns the original bytes without touching them.
    function test_Reencode_RoundTrip_AllSamples() public view {
        bytes[4] memory raws = [TX_USDC_KAT, TX_NATIVE_IN_USDC, TX_USDC_NATIVE_OUT, TX_KAT_USDC];
        uint256[4] memory ins = [QUOTE_USDC_KAT_IN, QUOTE_NATIVE_USDC_IN, QUOTE_USDC_NATIVE_IN, QUOTE_KAT_USDC_IN];
        for (uint256 i; i < 4; ++i) {
            assertEq(keccak256(h.rescale(raws[i], WETH9, ins[i])), keccak256(raws[i]), "same amount: untouched");
            bytes memory up = h.rescale(raws[i], WETH9, 2 * ins[i]);
            assertEq(up.length, raws[i].length, "re-encode keeps the canonical length");
            assertTrue(keccak256(up) != keccak256(raws[i]), "2x actually changed the bytes");
            assertEq(h.readFields(up, WETH9).totalIn, 2 * ins[i]);
            assertEq(keccak256(h.rescale(up, WETH9, ins[i])), keccak256(raws[i]), "2x then 1/2 reproduces the original");
        }
    }

    /// @dev Values from the Katana fork probe (2026-11-12): tail mins at 95 / 105 / 150 %.
    function test_Rescale_LiveSample_MultiSplit_MatchesProbe() public view {
        bytes memory out = h.rescale(TX_USDC_KAT, WETH9, 95_000_000);
        EverlongAmountUpdater.Fields memory f = h.readFields(out, WETH9);
        assertEq(f.totalIn, 95_000_000, "sum exact");
        assertEq(f.tailMin, 28_790_691_722_315_338_643_762);
        assertEq(f.deadline, DEADLINE_USDC_KAT);
        assertEq(f.recipient, API_RECIPIENT);
        assertEq(f.feeBips, FEE_BIPS);
        (, bytes[] memory calls) = abi.decode(_body(out), (uint256, bytes[]));
        // legs 0 and 1 floor-scaled, leg 2 takes the remainder
        assertEq(_legAmount(calls[0]), uint256(83_398_339) * 95 / 100);
        assertEq(_legAmount(calls[1]), uint256(10_301_030) * 95 / 100);
        assertEq(_legAmount(calls[2]), 95_000_000 - uint256(83_398_339) * 95 / 100 - uint256(10_301_030) * 95 / 100);

        assertEq(
            h.readFields(h.rescale(TX_USDC_KAT, WETH9, 105_000_000), WETH9).tailMin, 31_821_290_850_980_111_132_579
        );
        assertEq(
            h.readFields(h.rescale(TX_USDC_KAT, WETH9, 150_000_000), WETH9).tailMin, 45_458_986_929_971_587_332_255
        );
        assertEq(h.readFields(h.rescale(TX_NATIVE_IN_USDC, WETH9, 0.9e18), WETH9).tailMin, 1_824_943_333);
        assertEq(h.readFields(h.rescale(TX_USDC_NATIVE_OUT, WETH9, 110_000_000), WETH9).tailMin, 53_476_027_237_795_096);
        assertTrue(h.readFields(h.rescale(TX_USDC_NATIVE_OUT, WETH9, 110_000_000), WETH9).hasRefund, "refund kept");
    }

    /*//////////////////////////////////////////////////////////////
                                readFields
    //////////////////////////////////////////////////////////////*/

    function test_ReadFields_Success_SingleLegSweepFee() public view {
        EverlongAmountUpdater.Fields memory f =
            h.readFields(_mc(_calls2(_eis(1000, 0), _sweepFee(TOKEN_OUT, 900, RCPT))), WETH9);
        assertEq(f.tokenIn, TOKEN_IN);
        assertEq(f.tokenOut, TOKEN_OUT);
        assertEq(f.totalIn, 1000);
        assertEq(f.tailMin, 900);
        assertEq(f.recipient, RCPT);
        assertEq(f.feeBips, 4);
        assertEq(f.feeRecipient, FEE_RCPT);
        assertEq(f.swapLegs, 1);
    }

    function test_ReadFields_Success_NoFeeTails() public view {
        EverlongAmountUpdater.Fields memory f =
            h.readFields(_mc(_calls2(_eis(1000, 0), _sweep(TOKEN_OUT, 900, RCPT))), WETH9);
        assertEq(f.feeBips, 0);
        assertEq(f.feeRecipient, address(0));
        bytes[] memory c = new bytes[](3);
        c[0] = _eisTo(TOKEN_IN, WETH9, 1000, 0);
        c[1] = _unwrap(900, RCPT);
        c[2] = _refund();
        f = h.readFields(_mc(c), WETH9);
        assertTrue(f.nativeOut);
        assertTrue(f.hasRefund);
        assertEq(f.feeBips, 0);
    }

    function test_Revert_TooShort() public {
        vm.expectRevert(EverlongAmountUpdater.TXDATA_TOO_SHORT.selector);
        h.readFields(hex"5ae401dc0000", WETH9);
    }

    function test_Revert_OuterSelector_MulticallNoDeadline_And_Blockhash() public {
        bytes[] memory c = _calls2(_eis(1000, 0), _sweepFee(TOKEN_OUT, 900, RCPT));
        bytes memory d = abi.encodeWithSelector(bytes4(0xac9650d8), c);
        vm.expectRevert(EverlongAmountUpdater.INVALID_SELECTOR.selector);
        h.readFields(d, WETH9);
        d = abi.encodeWithSelector(bytes4(0x1f0464d1), bytes32(0), c);
        vm.expectRevert(EverlongAmountUpdater.INVALID_SELECTOR.selector);
        h.readFields(d, WETH9);
    }

    function test_Revert_MalformedAbi() public {
        bytes memory d = bytes.concat(
            bytes4(0x5ae401dc), bytes32(DEADLINE), bytes32(uint256(0x40)), bytes32(uint256(5)), new bytes(32)
        );
        vm.expectRevert();
        h.readFields(d, WETH9);
    }

    function test_Revert_EmptyCalls() public {
        bytes memory d = _mc(new bytes[](0));
        vm.expectRevert(EverlongAmountUpdater.EMPTY_CALLS.selector);
        h.readFields(d, WETH9);
    }

    function test_Revert_UnsupportedSelectors_Representatives() public {
        bytes4[9] memory bad = [
            bytes4(0x5023b4df), // exactOutputSingle
            bytes4(0x09b81346), // exactOutput
            bytes4(0x472b43f3), // V2 swapExactTokensForTokens
            bytes4(0x42712a67), // V2 swapTokensForExactTokens
            bytes4(0xf3995c67), // selfPermit
            bytes4(0xf2d5d56b), // pull
            bytes4(0x1c58db4f), // wrapETH
            bytes4(0x571ac8b0), // approveMax
            bytes4(0xb3a2af13) // callPositionManager
        ];
        for (uint256 i; i < bad.length; ++i) {
            bytes[] memory c = new bytes[](3);
            c[0] = _eis(1000, 0);
            c[1] = abi.encodeWithSelector(bad[i], TOKEN_IN, uint256(1), uint256(2), RCPT);
            c[2] = _sweepFee(TOKEN_OUT, 900, RCPT);
            bytes memory d = _mc(c);
            vm.expectRevert(abi.encodeWithSelector(EverlongAmountUpdater.UNSUPPORTED_LEG_SELECTOR.selector, bad[i]));
            h.readFields(d, WETH9);
        }
    }

    function test_Revert_ImplicitRecipientTails() public {
        bytes memory d = _mc(
            _calls2(
                _eis(1000, 0), abi.encodeWithSelector(bytes4(0x3068c554), TOKEN_OUT, uint256(900), uint256(4), FEE_RCPT)
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(EverlongAmountUpdater.UNSUPPORTED_LEG_SELECTOR.selector, bytes4(0x3068c554))
        );
        h.readFields(d, WETH9);
        d = _mc(
            _calls2(
                _eisTo(TOKEN_IN, WETH9, 1000, 0),
                abi.encodeWithSelector(bytes4(0xd4ef38de), uint256(900), uint256(4), FEE_RCPT)
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(EverlongAmountUpdater.UNSUPPORTED_LEG_SELECTOR.selector, bytes4(0xd4ef38de))
        );
        h.readFields(d, WETH9);
    }

    function test_Revert_LegRecipientNotAddressThis() public {
        address[3] memory rcpts = [RCPT, address(1), EVERLONG_ROUTER];
        for (uint256 i; i < rcpts.length; ++i) {
            bytes memory d =
                _mc(_calls2(_eisFull(TOKEN_IN, TOKEN_OUT, rcpts[i], 1000, 0), _sweepFee(TOKEN_OUT, 900, RCPT)));
            vm.expectRevert(EverlongAmountUpdater.INVALID_LEG_RECIPIENT.selector);
            h.readFields(d, WETH9);
        }
    }

    function test_Revert_ContractBalanceLeg() public {
        bytes memory d = _mc(_calls2(_eis(0, 0), _sweepFee(TOKEN_OUT, 900, RCPT)));
        vm.expectRevert(EverlongAmountUpdater.ZERO_LEG_AMOUNT.selector);
        h.readFields(d, WETH9);
    }

    function test_Revert_LegTokenMismatch() public {
        bytes[] memory c = new bytes[](3);
        c[0] = _eis(500, 0);
        c[1] = _eisTo(MID, TOKEN_OUT, 500, 0);
        c[2] = _sweepFee(TOKEN_OUT, 900, RCPT);
        bytes memory d = _mc(c);
        vm.expectRevert(EverlongAmountUpdater.LEG_TOKEN_MISMATCH.selector);
        h.readFields(d, WETH9);
        c[1] = _eisTo(TOKEN_IN, MID, 500, 0);
        d = _mc(c);
        vm.expectRevert(EverlongAmountUpdater.LEG_TOKEN_MISMATCH.selector);
        h.readFields(d, WETH9);
    }

    function test_Revert_PathInvalid() public {
        bytes memory d =
            _mc(_calls2(_ei(abi.encodePacked(TOKEN_IN, uint24(500)), 1000, 0), _sweepFee(TOKEN_OUT, 900, RCPT)));
        vm.expectRevert(EverlongAmountUpdater.INVALID_PATH.selector);
        h.readFields(d, WETH9);
        d = _mc(
            _calls2(
                _ei(abi.encodePacked(TOKEN_IN, uint24(500), TOKEN_OUT, uint8(1)), 1000, 0),
                _sweepFee(TOKEN_OUT, 900, RCPT)
            )
        );
        vm.expectRevert(EverlongAmountUpdater.INVALID_PATH.selector);
        h.readFields(d, WETH9);
    }

    function test_Revert_PathTokenMismatch() public {
        // path tokenIn differs from the single leg's tokenIn
        bytes[] memory c = new bytes[](3);
        c[0] = _eis(500, 0);
        c[1] = _ei(abi.encodePacked(MID, uint24(500), TOKEN_OUT), 500, 0);
        c[2] = _sweepFee(TOKEN_OUT, 900, RCPT);
        bytes memory d = _mc(c);
        vm.expectRevert(EverlongAmountUpdater.LEG_TOKEN_MISMATCH.selector);
        h.readFields(d, WETH9);
        c[1] = _ei(abi.encodePacked(TOKEN_IN, uint24(500), MID), 500, 0);
        d = _mc(c);
        vm.expectRevert(EverlongAmountUpdater.LEG_TOKEN_MISMATCH.selector);
        h.readFields(d, WETH9);
    }

    function test_Revert_MissingTail() public {
        bytes[] memory c = new bytes[](1);
        c[0] = _eis(1000, 0);
        bytes memory d = _mc(c);
        vm.expectRevert(EverlongAmountUpdater.MISSING_TAIL.selector);
        h.readFields(d, WETH9);
        // tail with no legs before it is an ordering fault
        c[0] = _sweepFee(TOKEN_OUT, 900, RCPT);
        d = _mc(c);
        vm.expectRevert(EverlongAmountUpdater.INVALID_LEG_ORDER.selector);
        h.readFields(d, WETH9);
    }

    function test_Revert_TwoTails_And_SwapAfterTail() public {
        bytes[] memory c = new bytes[](3);
        c[0] = _eis(1000, 0);
        c[1] = _sweepFee(TOKEN_OUT, 900, RCPT);
        c[2] = _sweepFee(TOKEN_OUT, 900, RCPT);
        bytes memory d = _mc(c);
        vm.expectRevert(EverlongAmountUpdater.DUPLICATE_TAIL.selector);
        h.readFields(d, WETH9);
        c[2] = _eis(1, 0);
        d = _mc(c);
        vm.expectRevert(EverlongAmountUpdater.INVALID_LEG_ORDER.selector);
        h.readFields(d, WETH9);
    }

    function test_Revert_TailTokenMismatch_And_UnwrapOnNonWeth() public {
        bytes memory d = _mc(_calls2(_eis(1000, 0), _sweepFee(MID, 900, RCPT)));
        vm.expectRevert(EverlongAmountUpdater.TAIL_TOKEN_MISMATCH.selector);
        h.readFields(d, WETH9);
        d = _mc(_calls2(_eis(1000, 0), _unwrapFee(900, RCPT)));
        vm.expectRevert(EverlongAmountUpdater.TAIL_TOKEN_MISMATCH.selector);
        h.readFields(d, WETH9);
    }

    function test_Revert_TailRecipientSentinel() public {
        address[3] memory bad = [address(0), address(1), address(2)];
        for (uint256 i; i < bad.length; ++i) {
            bytes memory d = _mc(_calls2(_eis(1000, 0), _sweepFee(TOKEN_OUT, 900, bad[i])));
            vm.expectRevert(EverlongAmountUpdater.INVALID_TAIL_RECIPIENT.selector);
            h.readFields(d, WETH9);
        }
    }

    function test_Revert_RefundNotLast_Or_BeforeTail() public {
        bytes[] memory c = new bytes[](3);
        c[0] = _eis(1000, 0);
        c[1] = _refund();
        c[2] = _sweepFee(TOKEN_OUT, 900, RCPT);
        bytes memory d = _mc(c);
        vm.expectRevert(EverlongAmountUpdater.INVALID_LEG_ORDER.selector);
        h.readFields(d, WETH9);
        bytes[] memory c4 = new bytes[](4);
        c4[0] = _eis(1000, 0);
        c4[1] = _sweepFee(TOKEN_OUT, 900, RCPT);
        c4[2] = _refund();
        c4[3] = _refund();
        d = _mc(c4);
        vm.expectRevert(EverlongAmountUpdater.INVALID_LEG_ORDER.selector);
        h.readFields(d, WETH9);
    }

    /// @dev Security finding: a path that revisits the leg's tokenIn (WETH9 on native routes) makes the router wrap the
    ///      ETH reserved for later legs and pull the account's WETH9 through a standing allowance. Rejected outright,
    ///      as is revisiting tokenOut and a leg whose endpoints are the same token.
    function test_Revert_PathRevisitsEndpoint() public {
        bytes memory cyc = _mc(
            _calls2(
                _ei(
                    abi.encodePacked(TOKEN_IN, uint24(500), MID, uint24(500), TOKEN_IN, uint24(500), TOKEN_OUT), 1000, 0
                ),
                _sweepFee(TOKEN_OUT, 900, RCPT)
            )
        );
        vm.expectRevert(EverlongAmountUpdater.INVALID_PATH.selector);
        h.readFields(cyc, WETH9);
        bytes memory cycOut = _mc(
            _calls2(
                _ei(
                    abi.encodePacked(TOKEN_IN, uint24(500), TOKEN_OUT, uint24(500), MID, uint24(500), TOKEN_OUT),
                    1000,
                    0
                ),
                _sweepFee(TOKEN_OUT, 900, RCPT)
            )
        );
        vm.expectRevert(EverlongAmountUpdater.INVALID_PATH.selector);
        h.readFields(cycOut, WETH9);
        bytes memory same = _mc(_calls2(_eisTo(TOKEN_IN, TOKEN_IN, 1000, 0), _sweepFee(TOKEN_IN, 900, RCPT)));
        vm.expectRevert(EverlongAmountUpdater.INVALID_PATH.selector);
        h.readFields(same, WETH9);
        // a legitimate 2-hop through a distinct intermediate still passes
        h.readFields(
            _mc(
                _calls2(
                    _ei(abi.encodePacked(TOKEN_IN, uint24(500), MID, uint24(500), TOKEN_OUT), 1000, 0),
                    _sweepFee(TOKEN_OUT, 900, RCPT)
                )
            ),
            WETH9
        );
    }

    function test_Revert_PriceLimitSet() public {
        bytes memory leg = abi.encodeWithSelector(
            ISwapRouter02.exactInputSingle.selector,
            ISwapRouter02.ExactInputSingleParams(TOKEN_IN, TOKEN_OUT, 500, THIS, 1000, 0, uint160(1))
        );
        bytes memory d = _mc(_calls2(leg, _sweepFee(TOKEN_OUT, 900, RCPT)));
        vm.expectRevert(EverlongAmountUpdater.INVALID_PRICE_LIMIT.selector);
        h.readFields(d, WETH9);
    }

    function test_Revert_FeeAboveCap_BothTails() public {
        bytes memory d = _mc(
            _calls2(
                _eis(1000, 0),
                abi.encodeWithSelector(
                    ISwapRouter02.sweepTokenWithFee.selector, TOKEN_OUT, uint256(900), RCPT, uint256(11), FEE_RCPT
                )
            )
        );
        vm.expectRevert(EverlongAmountUpdater.FEE_TOO_HIGH.selector);
        h.readFields(d, WETH9);
        d = _mc(
            _calls2(
                _eisTo(TOKEN_IN, WETH9, 1000, 0),
                abi.encodeWithSelector(
                    ISwapRouter02.unwrapWETH9WithFee.selector, uint256(900), RCPT, uint256(11), FEE_RCPT
                )
            )
        );
        vm.expectRevert(EverlongAmountUpdater.FEE_TOO_HIGH.selector);
        h.readFields(d, WETH9);
        // exactly the cap is accepted
        h.readFields(
            _mc(
                _calls2(
                    _eis(1000, 0),
                    abi.encodeWithSelector(
                        ISwapRouter02.sweepTokenWithFee.selector, TOKEN_OUT, uint256(900), RCPT, uint256(10), FEE_RCPT
                    )
                )
            ),
            WETH9
        );
    }

    /// @dev `weth9 == address(0)` (the pure sizing path) skips ONLY the unwrap-tail identity check.
    function test_Weth9Zero_SkipsOnlyUnwrapIdentity() public {
        bytes memory d = _mc(_calls2(_eis(1000, 0), _unwrapFee(900, RCPT))); // tokenOut != WETH9
        vm.expectRevert(EverlongAmountUpdater.TAIL_TOKEN_MISMATCH.selector);
        h.readFields(d, WETH9);
        EverlongAmountUpdater.Fields memory f = h.readFields(d, address(0));
        assertTrue(f.nativeOut);
        // every other rule still applies with address(0)
        bytes memory bad = _mc(_calls2(_eis(0, 0), _unwrapFee(900, RCPT)));
        vm.expectRevert(EverlongAmountUpdater.ZERO_LEG_AMOUNT.selector);
        h.readFields(bad, address(0));
    }

    function test_Rescale_NoFeeTails() public view {
        bytes memory out = h.rescale(_mc(_calls2(_eis(1000, 0), _sweep(TOKEN_OUT, 900, RCPT))), WETH9, 500);
        EverlongAmountUpdater.Fields memory f = h.readFields(out, WETH9);
        assertEq(f.totalIn, 500);
        assertEq(f.tailMin, 450);
        assertEq(f.feeBips, 0);
        assertEq(f.recipient, RCPT);
        bytes[] memory c = new bytes[](3);
        c[0] = _eisTo(TOKEN_IN, WETH9, 1000, 0);
        c[1] = _unwrap(900, RCPT);
        c[2] = _refund();
        out = h.rescale(_mc(c), WETH9, 1500);
        f = h.readFields(out, WETH9);
        assertEq(f.totalIn, 1500);
        assertEq(f.tailMin, 1350);
        assertTrue(f.nativeOut);
        assertTrue(f.hasRefund);
    }

    /*//////////////////////////////////////////////////////////////
                                 rescale
    //////////////////////////////////////////////////////////////*/

    function test_Rescale_SingleLeg_UpDown() public view {
        bytes memory d = _mc(_calls2(_eis(1000, 7), _sweepFee(TOKEN_OUT, 900, RCPT)));
        EverlongAmountUpdater.Fields memory f = h.readFields(h.rescale(d, WETH9, 950), WETH9);
        assertEq(f.totalIn, 950);
        assertEq(f.tailMin, 855);
        (, bytes[] memory calls) = abi.decode(_body(h.rescale(d, WETH9, 950)), (uint256, bytes[]));
        ISwapRouter02.ExactInputSingleParams memory s =
            abi.decode(_body(calls[0]), (ISwapRouter02.ExactInputSingleParams));
        assertEq(s.amountIn, 950);
        assertEq(s.amountOutMinimum, 7); // ceil(7 * 0.95) = 7
        assertEq(s.recipient, THIS);
        f = h.readFields(h.rescale(d, WETH9, 3000), WETH9);
        assertEq(f.totalIn, 3000);
        assertEq(f.tailMin, 2700);
    }

    function test_Rescale_MultiLeg_SumExact_RemainderOnLast() public view {
        bytes[] memory c = new bytes[](4);
        c[0] = _eis(333, 0);
        c[1] = _ei(abi.encodePacked(TOKEN_IN, uint24(500), MID, uint24(3000), TOKEN_OUT), 333, 0);
        c[2] = _eis(334, 0);
        c[3] = _sweepFee(TOKEN_OUT, 900, RCPT);
        bytes memory out = h.rescale(_mc(c), WETH9, 1001);
        (, bytes[] memory calls) = abi.decode(_body(out), (uint256, bytes[]));
        assertEq(_legAmount(calls[0]), 333); // floor(333 * 1001 / 1000) = 333
        assertEq(_legAmount(calls[1]), 333);
        assertEq(_legAmount(calls[2]), 1001 - 666, "remainder on the last swap leg");
        assertEq(h.readFields(out, WETH9).totalIn, 1001);
        assertEq(h.readFields(out, WETH9).tailMin, 901); // ceil(900.9)
        // the exactInput path is untouched
        ISwapRouter02.ExactInputParams memory p = abi.decode(_body(calls[1]), (ISwapRouter02.ExactInputParams));
        assertEq(p.path, abi.encodePacked(TOKEN_IN, uint24(500), MID, uint24(3000), TOKEN_OUT));
    }

    function test_Rescale_Revert_ZeroNewAmount_And_LegGoesToZero() public {
        bytes memory d = _mc(_calls2(_eis(1000, 0), _sweepFee(TOKEN_OUT, 900, RCPT)));
        vm.expectRevert(EverlongAmountUpdater.ZERO_AMOUNT.selector);
        h.rescale(d, WETH9, 0);
        bytes[] memory c = new bytes[](3);
        c[0] = _eis(1, 0);
        c[1] = _eis(999, 0);
        c[2] = _sweepFee(TOKEN_OUT, 900, RCPT);
        d = _mc(c);
        vm.expectRevert(EverlongAmountUpdater.ZERO_LEG_AMOUNT.selector);
        h.rescale(d, WETH9, 1);
    }

    function test_Rescale_TinyDownscale_TailMinStaysNonZero() public view {
        bytes memory d = _mc(_calls2(_eis(1000, 0), _sweepFee(TOKEN_OUT, 1, RCPT)));
        assertEq(h.readFields(h.rescale(d, WETH9, 1), WETH9).tailMin, 1);
    }

    function test_Rescale_FailsClosedOnInvalidPayload() public {
        bytes memory d = _mc(_calls2(_eis(1000, 0), _sweepFee(MID, 900, RCPT)));
        vm.expectRevert(EverlongAmountUpdater.TAIL_TOKEN_MISMATCH.selector);
        h.rescale(d, WETH9, 500);
    }

    function testFuzz_Rescale_SumExact(uint8 legsRaw, uint64 seed, uint128 newRaw) public view {
        uint256 legs = bound(uint256(legsRaw), 1, 8);
        bytes[] memory c = new bytes[](legs + 1);
        uint256 total;
        for (uint256 i; i < legs; ++i) {
            uint256 a = 1 + (uint256(keccak256(abi.encode(seed, i))) % 1e12);
            // alternate single-pool and 2-hop legs so both re-encoders are fuzzed
            c[i] = i % 2 == 0
                ? _eis(a, 0)
                : _ei(abi.encodePacked(TOKEN_IN, uint24(500), MID, uint24(3000), TOKEN_OUT), a, 0);
            total += a;
        }
        c[legs] = _sweepFee(TOKEN_OUT, total * 99 / 100, RCPT);
        // upscales (and equal) never produce a zero leg; downscales are covered by the fuzz below
        uint256 newAmount = bound(uint256(newRaw), total, type(uint112).max);
        bytes memory out = h.rescale(_mc(c), WETH9, newAmount);
        (, bytes[] memory calls) = abi.decode(_body(out), (uint256, bytes[]));
        uint256 sum;
        for (uint256 i; i < legs; ++i) {
            uint256 a = _legAmount(calls[i]);
            assertGt(a, 0, "no zero leg");
            sum += a;
        }
        assertEq(sum, newAmount, "sum exact");
        assertEq(
            h.readFields(out, WETH9).tailMin,
            Math.mulDiv(total * 99 / 100, newAmount, total, Math.Rounding.Ceil),
            "tail ceil"
        );
    }

    /// @dev Downscales: either every leg stays >= 1 and the sum is exact, or the library reverts ZERO_LEG_AMOUNT
    ///      exactly when some non-last leg floors to zero.
    function testFuzz_Rescale_Downscale_SumExactOrZeroLegRevert(uint64 a0, uint64 a1, uint64 newRaw) public {
        uint256 l0 = bound(uint256(a0), 1, 1e12);
        uint256 l1 = bound(uint256(a1), 1, 1e12);
        uint256 total = l0 + l1;
        uint256 newAmount = bound(uint256(newRaw), 1, total);
        bytes[] memory c = new bytes[](3);
        c[0] = _eis(l0, 0);
        c[1] = _eis(l1, 0);
        c[2] = _sweepFee(TOKEN_OUT, total / 2, RCPT);
        bytes memory d = _mc(c);
        bool legZero = Math.mulDiv(l0, newAmount, total) == 0;
        if (legZero) {
            vm.expectRevert(EverlongAmountUpdater.ZERO_LEG_AMOUNT.selector);
            h.rescale(d, WETH9, newAmount);
            return;
        }
        bytes memory out = h.rescale(d, WETH9, newAmount);
        (, bytes[] memory calls) = abi.decode(_body(out), (uint256, bytes[]));
        assertEq(_legAmount(calls[0]) + _legAmount(calls[1]), newAmount, "sum exact");
        assertGt(_legAmount(calls[1]), 0, "remainder leg never zero");
    }

    /*//////////////////////////////////////////////////////////////
                                 helpers
    //////////////////////////////////////////////////////////////*/

    function _eis(uint256 amountIn, uint256 minOut) internal pure returns (bytes memory) {
        return _eisFull(TOKEN_IN, TOKEN_OUT, THIS, amountIn, minOut);
    }

    function _eisTo(address tIn, address tOut, uint256 amountIn, uint256 minOut) internal pure returns (bytes memory) {
        return _eisFull(tIn, tOut, THIS, amountIn, minOut);
    }

    function _eisFull(
        address tIn,
        address tOut,
        address rcpt,
        uint256 amountIn,
        uint256 minOut
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            ISwapRouter02.exactInputSingle.selector,
            ISwapRouter02.ExactInputSingleParams(tIn, tOut, 500, rcpt, amountIn, minOut, 0)
        );
    }

    function _ei(bytes memory path, uint256 amountIn, uint256 minOut) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            ISwapRouter02.exactInput.selector, ISwapRouter02.ExactInputParams(path, THIS, amountIn, minOut)
        );
    }

    function _sweepFee(address token, uint256 min, address rcpt) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ISwapRouter02.sweepTokenWithFee.selector, token, min, rcpt, uint256(4), FEE_RCPT);
    }

    function _sweep(address token, uint256 min, address rcpt) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ISwapRouter02.sweepToken.selector, token, min, rcpt);
    }

    function _unwrapFee(uint256 min, address rcpt) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ISwapRouter02.unwrapWETH9WithFee.selector, min, rcpt, uint256(4), FEE_RCPT);
    }

    function _unwrap(uint256 min, address rcpt) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ISwapRouter02.unwrapWETH9.selector, min, rcpt);
    }

    function _refund() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ISwapRouter02.refundETH.selector);
    }

    function _calls2(bytes memory a, bytes memory b) internal pure returns (bytes[] memory c) {
        c = new bytes[](2);
        c[0] = a;
        c[1] = b;
    }

    function _mc(bytes[] memory calls) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ISwapRouter02.multicall.selector, DEADLINE, calls);
    }

    function _body(bytes memory d) internal pure returns (bytes memory out) {
        out = new bytes(d.length - 4);
        for (uint256 i; i < out.length; ++i) {
            out[i] = d[i + 4];
        }
    }

    function _legAmount(bytes memory c) internal pure returns (uint256) {
        bytes4 sel;
        assembly ("memory-safe") {
            sel := mload(add(c, 0x20))
        }
        if (sel == ISwapRouter02.exactInputSingle.selector) {
            return abi.decode(_body(c), (ISwapRouter02.ExactInputSingleParams)).amountIn;
        }
        return abi.decode(_body(c), (ISwapRouter02.ExactInputParams)).amountIn;
    }
}
