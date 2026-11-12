// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { SushiSwapAmountUpdater } from "../../../src/libraries/SushiSwapAmountUpdater.sol";
import { IRedSnwapper } from "../../../src/vendor/sushiswap/IRedSnwapper.sol";
import { IRouteProcessor7 } from "../../../src/vendor/sushiswap/IRouteProcessor7.sol";
import { SushiKatanaFixtures } from "../../integration/sushiswap/SushiKatanaFixtures.sol";

/// @dev Exposes the internal library so every branch is reachable from a test.
contract Harness {
    function readFields(bytes memory txData) external pure returns (SushiSwapAmountUpdater.Fields memory) {
        return SushiSwapAmountUpdater.readFields(txData);
    }

    function rescale(bytes memory txData, uint256 newAmount) external pure returns (bytes memory) {
        SushiSwapAmountUpdater.rescale(txData, newAmount);
        return txData;
    }
}

contract SushiSwapAmountUpdaterTest is Test, SushiKatanaFixtures {
    address private constant TOKEN_IN = address(0xA11CE);
    address private constant TOKEN_OUT = address(0xB0B);
    address private constant RCPT = address(0xCAFE);
    address private constant EXECUTOR = address(0xE0E0);

    Harness private h;

    function setUp() public {
        h = new Harness();
    }

    /*//////////////////////////////////////////////////////////////
                           SELECTORS / OFFSETS
    //////////////////////////////////////////////////////////////*/

    function test_Selectors_PinnedToVendorInterfaces() public pure {
        assertEq(IRedSnwapper.snwap.selector, bytes4(0x5f3bd1c8));
        assertEq(IRouteProcessor7.processRoute.selector, bytes4(0x6be92b89));
        assertEq(SushiSwapAmountUpdater.SNWAP_SELECTOR, IRedSnwapper.snwap.selector);
        assertEq(SushiSwapAmountUpdater.PROCESS_ROUTE_SELECTOR, IRouteProcessor7.processRoute.selector);
    }

    /// @dev The live Katana sample decodes at the documented offsets.
    function test_Offsets_MatchLiveSample() public view {
        bytes memory d = TX_USDC_KAT;
        assertEq(_word(d, 36), QUOTE_USDC_KAT_IN, "outer amountIn");
        assertEq(_word(d, 132), OUTER_MIN_USDC_KAT, "outer min");
        assertEq(address(uint160(_word(d, 164))), ROUTE_PROCESSOR, "executor");
        assertEq(_word(d, 196), 224, "executorData offset");
        assertEq(_word(d, 228), 388, "executorData length");
        assertEq(bytes4(bytes32(_word(d, 260))), bytes4(0x6be92b89), "inner selector");
        assertEq(_word(d, 296), QUOTE_USDC_KAT_IN, "inner amountIn");
        assertEq(_word(d, 360), QUOTE_USDC_KAT_OUT, "inner min == unslippaged quote");
        assertEq(address(uint160(_word(d, 392))), API_SENDER, "inner to");
        assertEq(_word(d, 424), 256, "route offset");
        assertEq(_word(d, 456), 1, "takeSurplus");
        assertEq(_word(d, 488), 0, "referralCode");
        assertEq(_word(d, 520), 81, "route length");

        SushiSwapAmountUpdater.Fields memory f = h.readFields(d);
        assertEq(f.tokenIn, VB_USDC);
        assertEq(f.tokenOut, KAT);
        assertEq(f.recipient, API_SENDER);
        assertEq(f.amountIn, QUOTE_USDC_KAT_IN);
        assertEq(f.amountOutMin, OUTER_MIN_USDC_KAT);
        assertEq(f.executor, ROUTE_PROCESSOR);
    }

    function test_AllLiveSamples_Validate() public view {
        h.readFields(TX_USDC_KAT);
        h.readFields(TX_NATIVE_IN_USDC);
        h.readFields(TX_USDC_NATIVE_OUT);
        h.readFields(TX_USDC_WETH_MULTI);
    }

    /*//////////////////////////////////////////////////////////////
                              readFields
    //////////////////////////////////////////////////////////////*/

    function test_ReadFields_Success() public view {
        SushiSwapAmountUpdater.Fields memory f = h.readFields(_tx(1000, 900, 950, hex"deadbeef"));
        assertEq(f.tokenIn, TOKEN_IN);
        assertEq(f.amountIn, 1000);
        assertEq(f.recipient, RCPT);
        assertEq(f.tokenOut, TOKEN_OUT);
        assertEq(f.amountOutMin, 900);
        assertEq(f.executor, EXECUTOR);
    }

    function test_ReadFields_Revert_TooShort() public {
        vm.expectRevert(SushiSwapAmountUpdater.TXDATA_TOO_SHORT.selector);
        h.readFields(bytes.concat(abi.encodeWithSelector(IRedSnwapper.snwap.selector), new bytes(10)));
    }

    function test_ReadFields_Revert_InvalidSelector() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        d[0] = 0xde;
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_SELECTOR.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_SnwapMultipleSelector() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        (d[0], d[1], d[2], d[3]) = (bytes1(0xd3), bytes1(0x37), bytes1(0x21), bytes1(0xa5));
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_SELECTOR.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_InnerSelector_TransferValueVariant() public {
        // processRouteWithTransferValueInput(address,uint256,address,uint256,address,uint256,address,bytes,bool,uint32)
        bytes memory inner = abi.encodeWithSelector(
            bytes4(0x9cbd7f62), address(0xFEE), 5, TOKEN_IN, 1000, TOKEN_OUT, 950, RCPT, hex"", true, uint32(0)
        );
        bytes memory d = _outer(1000, 900, inner);
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_INNER_SELECTOR.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_InnerTooShort() public {
        bytes memory d = _outer(1000, 900, abi.encodeWithSelector(IRouteProcessor7.processRoute.selector, TOKEN_IN));
        vm.expectRevert(SushiSwapAmountUpdater.TXDATA_TOO_SHORT.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_ExecutorDataOffsetIntoHead() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        _write(d, 196, 50);
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_EXECUTOR_DATA_OFFSET.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_ExecutorDataOffsetPastEnd() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        _write(d, 196, type(uint256).max - 10);
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_EXECUTOR_DATA_OFFSET.selector);
        h.readFields(d);
        _write(d, 196, d.length + 1);
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_EXECUTOR_DATA_OFFSET.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_ExecutorDataLengthOverruns() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        _write(d, 228, _word(d, 228) + 32);
        vm.expectRevert(SushiSwapAmountUpdater.TXDATA_TOO_SHORT.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_ExecutorDataLengthWordTruncated() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        _write(d, 196, d.length - 10); // in-range offset, but the 32-byte length word would overrun
        vm.expectRevert(SushiSwapAmountUpdater.TXDATA_TOO_SHORT.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_RouteLengthWordTruncated() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        uint256 innerLen = _word(d, 228);
        _write(d, 424, innerLen - 20); // 4 + off >= 260 but the length word overruns executorData
        vm.expectRevert(SushiSwapAmountUpdater.TXDATA_TOO_SHORT.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_RouteOffsetIntoInnerHead() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        _write(d, 424, 100); // 4 + 100 < 260
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_ROUTE_OFFSET.selector);
        h.readFields(d);
        _write(d, 424, type(uint256).max);
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_ROUTE_OFFSET.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_RouteTruncated() public {
        bytes memory d = _tx(1000, 900, 950, hex"deadbeef");
        _write(d, 520, 1000); // route length overruns executorData
        vm.expectRevert(SushiSwapAmountUpdater.TXDATA_TOO_SHORT.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_InnerTokenMismatch() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        _write(d, 264, uint160(address(0xBAD)));
        vm.expectRevert(SushiSwapAmountUpdater.INNER_TOKEN_MISMATCH.selector);
        h.readFields(d);
        d = _tx(1000, 900, 950, hex"");
        _write(d, 328, uint160(address(0xBAD)));
        vm.expectRevert(SushiSwapAmountUpdater.INNER_TOKEN_MISMATCH.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_InnerAmountMismatch() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        _write(d, 296, 999);
        vm.expectRevert(SushiSwapAmountUpdater.INNER_AMOUNT_MISMATCH.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_InnerRecipientMismatch() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        _write(d, 392, uint160(address(0xBAD)));
        vm.expectRevert(SushiSwapAmountUpdater.INNER_RECIPIENT_MISMATCH.selector);
        h.readFields(d);
    }

    function test_ReadFields_Revert_ZeroAmountIn() public {
        bytes memory d = _tx(0, 900, 950, hex"");
        vm.expectRevert(SushiSwapAmountUpdater.ZERO_AMOUNT.selector);
        h.readFields(d);
    }

    /*//////////////////////////////////////////////////////////////
                                rescale
    //////////////////////////////////////////////////////////////*/

    function test_Rescale_PatchesFourWords_RouteUntouched() public view {
        bytes memory route = hex"01a1ce9d34f0000101deadbeef";
        bytes memory d = _tx(1000, 900, 950, route);
        bytes32 routeHashBefore = keccak256(_routeOf(d));
        uint256 lenBefore = d.length;

        bytes memory out = h.rescale(d, 2000);
        assertEq(out.length, lenBefore, "length unchanged");
        assertEq(_word(out, 36), 2000, "outer amount");
        assertEq(_word(out, 132), 1800, "outer min");
        assertEq(_word(out, 296), 2000, "inner amount");
        assertEq(_word(out, 360), 1900, "inner min (cap)");
        assertEq(keccak256(_routeOf(out)), routeHashBefore, "route untouched");
        // untouched words
        assertEq(address(uint160(_word(out, 4))), TOKEN_IN);
        assertEq(address(uint160(_word(out, 68))), RCPT);
        assertEq(address(uint160(_word(out, 164))), EXECUTOR);
        assertEq(_word(out, 456), 1, "takeSurplus");
        assertEq(_word(out, 488), 7, "referralCode");
    }

    function test_Rescale_Up_And_Down() public view {
        bytes memory out = h.rescale(_tx(1000, 900, 950, hex""), 950);
        assertEq(_word(out, 36), 950);
        assertEq(_word(out, 132), 855);
        assertEq(_word(out, 360), 903); // ceil(950*950/1000) = ceil(902.5)

        out = h.rescale(_tx(1000, 900, 950, hex""), 1050);
        assertEq(_word(out, 132), 945);
        assertEq(_word(out, 360), 998); // ceil(997.5)

        out = h.rescale(_tx(1000, 900, 950, hex""), 3000);
        assertEq(_word(out, 132), 2700);
        assertEq(_word(out, 360), 2850);
    }

    function test_Rescale_SameAmount_IsNoop() public view {
        bytes memory d = _tx(1000, 900, 950, hex"aa");
        bytes memory out = h.rescale(d, 1000);
        assertEq(keccak256(out), keccak256(_tx(1000, 900, 950, hex"aa")));
    }

    function test_Rescale_TinyDownscale_MinsStayNonZero() public view {
        bytes memory out = h.rescale(_tx(1000, 1, 1, hex""), 1);
        assertEq(_word(out, 132), 1);
        assertEq(_word(out, 360), 1);
    }

    function test_Rescale_LiveSample_MatchesProbe() public view {
        // Values from the Katana fork probe at 95% / 105% of the vbUSDC -> KAT quote.
        bytes memory out = h.rescale(bytes.concat(TX_USDC_KAT), 95_000_000);
        assertEq(_word(out, 36), 95_000_000);
        assertEq(_word(out, 296), 95_000_000);
        assertEq(_word(out, 132), Math.mulDiv(OUTER_MIN_USDC_KAT, 95, 100, Math.Rounding.Ceil));
        assertEq(_word(out, 360), Math.mulDiv(QUOTE_USDC_KAT_OUT, 95, 100, Math.Rounding.Ceil));
        out = h.rescale(bytes.concat(TX_USDC_KAT), 105_000_000);
        assertEq(_word(out, 132), Math.mulDiv(OUTER_MIN_USDC_KAT, 105, 100, Math.Rounding.Ceil));
        assertEq(_word(out, 360), Math.mulDiv(QUOTE_USDC_KAT_OUT, 105, 100, Math.Rounding.Ceil));
    }

    function test_Rescale_Revert_ZeroNewAmount() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        vm.expectRevert(SushiSwapAmountUpdater.ZERO_AMOUNT.selector);
        h.rescale(d, 0);
    }

    function test_Rescale_Revert_ZeroEmbeddedAmount() public {
        bytes memory d = _tx(0, 900, 950, hex"");
        vm.expectRevert(SushiSwapAmountUpdater.ZERO_AMOUNT.selector);
        h.rescale(d, 10);
    }

    function test_Rescale_Revert_InvalidPayloadFailsClosed() public {
        bytes memory d = _tx(1000, 900, 950, hex"");
        _write(d, 392, uint160(address(0xBAD)));
        vm.expectRevert(SushiSwapAmountUpdater.INNER_RECIPIENT_MISMATCH.selector);
        h.rescale(d, 500);
    }

    function testFuzz_Rescale_Proportional(
        uint128 oldAmount,
        uint128 newAmount,
        uint128 outerMin,
        uint128 innerMin
    )
        public
        view
    {
        vm.assume(oldAmount > 0 && newAmount > 0);
        bytes memory out = h.rescale(_tx(oldAmount, outerMin, innerMin, hex"01"), newAmount);
        assertEq(_word(out, 36), newAmount);
        assertEq(_word(out, 296), newAmount);
        assertEq(_word(out, 132), Math.mulDiv(outerMin, newAmount, oldAmount, Math.Rounding.Ceil));
        assertEq(_word(out, 360), Math.mulDiv(innerMin, newAmount, oldAmount, Math.Rounding.Ceil));
        if (outerMin > 0) assertGt(_word(out, 132), 0, "positive outer min never collapses");
        if (innerMin > 0) assertGt(_word(out, 360), 0, "positive inner min never collapses");
    }

    function testFuzz_Rescale_NonInterference(bytes memory route, uint128 newAmount) public view {
        vm.assume(newAmount > 0 && newAmount != 1000);
        bytes memory before = _tx(1000, 900, 950, route);
        bytes memory out = h.rescale(_tx(1000, 900, 950, route), newAmount);
        assertEq(out.length, before.length);
        for (uint256 i; i < out.length; ++i) {
            if (_inPatchedWord(i)) continue;
            assertEq(out[i], before[i], "untouched byte changed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                                helpers
    //////////////////////////////////////////////////////////////*/

    function _inner(uint256 amountIn, uint256 innerMin, bytes memory route) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IRouteProcessor7.processRoute.selector,
            TOKEN_IN,
            amountIn,
            TOKEN_OUT,
            innerMin,
            RCPT,
            route,
            true,
            uint32(7)
        );
    }

    function _outer(uint256 amountIn, uint256 outerMin, bytes memory inner) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IRedSnwapper.snwap.selector, TOKEN_IN, amountIn, RCPT, TOKEN_OUT, outerMin, EXECUTOR, inner
        );
    }

    function _tx(
        uint256 amountIn,
        uint256 outerMin,
        uint256 innerMin,
        bytes memory route
    )
        internal
        pure
        returns (bytes memory)
    {
        return _outer(amountIn, outerMin, _inner(amountIn, innerMin, route));
    }

    /// @dev The four patched 32-byte words: outer amountIn/min at 36/132, nested amountIn/min at 296/360.
    function _inPatchedWord(uint256 i) internal pure returns (bool) {
        return (i >= 36 && i < 68) || (i >= 132 && i < 164) || (i >= 296 && i < 328) || (i >= 360 && i < 392);
    }

    function _routeOf(bytes memory d) internal pure returns (bytes memory) {
        uint256 routeLen = _word(d, 520);
        bytes memory r = new bytes(routeLen);
        for (uint256 i; i < routeLen; ++i) {
            r[i] = d[552 + i];
        }
        return r;
    }
}
