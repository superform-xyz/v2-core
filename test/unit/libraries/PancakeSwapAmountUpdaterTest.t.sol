// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { PancakeSwapAmountUpdater } from "../../../src/libraries/PancakeSwapAmountUpdater.sol";
import { IPancakeSwapRouter } from "../../../src/vendor/pancakeswap/IPancakeSwapRouter.sol";

/// @dev Exposes the internal library so every branch is reachable from a test.
contract Harness {
    function readFields(bytes memory txData)
        external
        pure
        returns (address srcToken, address dstToken, address recipient)
    {
        return PancakeSwapAmountUpdater.readFields(txData);
    }

    function rescale(bytes memory txData, uint256 newAmount, uint256 oldAmount) external pure returns (bytes memory) {
        PancakeSwapAmountUpdater.rescaleSingleRoute(txData, newAmount, oldAmount);
        return txData;
    }
}

contract PancakeSwapAmountUpdaterTest is Test {
    bytes4 private constant SWAP_EXACT_IN = 0xedad400c;
    address private constant SRC = address(0xA11CE);
    address private constant DST = address(0xB0B);
    address private constant RCPT = address(0xCAFE);

    Harness private h;

    function setUp() public {
        h = new Harness();
    }

    /*//////////////////////////////////////////////////////////////
                              readFields
    //////////////////////////////////////////////////////////////*/

    function test_ReadFields_Success() public view {
        bytes memory txData = _txData(SRC, DST, 900, _one(1000), 0, RCPT);
        (address src, address dst, address rcpt) = h.readFields(txData);
        assertEq(src, SRC);
        assertEq(dst, DST);
        assertEq(rcpt, RCPT);
    }

    function test_ReadFields_Revert_TooShort() public {
        vm.expectRevert(PancakeSwapAmountUpdater.TXDATA_TOO_SHORT.selector);
        h.readFields(bytes.concat(abi.encodeWithSelector(SWAP_EXACT_IN), new bytes(10)));
    }

    function test_ReadFields_Revert_InvalidSelector() public {
        bytes memory txData = _txData(SRC, DST, 900, _one(1000), 0, RCPT);
        txData[0] = 0xde;
        txData[1] = 0xad;
        txData[2] = 0xbe;
        txData[3] = 0xef;
        vm.expectRevert(PancakeSwapAmountUpdater.INVALID_SELECTOR.selector);
        h.readFields(txData);
    }

    /*//////////////////////////////////////////////////////////////
                           rescaleSingleRoute
    //////////////////////////////////////////////////////////////*/

    function test_Rescale_Success_PatchesAmountAndMinOut() public view {
        bytes memory txData = _txData(SRC, DST, 900, _one(1000), 0, RCPT);
        bytes memory outData = h.rescale(txData, 2000, 1000);
        (,, uint256[] memory routesAmount, uint256 minOut) = _decode(outData);
        assertEq(routesAmount[0], 2000, "amount patched");
        assertEq(minOut, 1800, "minOut scaled");
    }

    function test_Rescale_Success_MinOutZeroStaysZero() public view {
        bytes memory txData = _txData(SRC, DST, 0, _one(1000), 0, RCPT);
        bytes memory outData = h.rescale(txData, 500, 1000);
        (,, uint256[] memory routesAmount, uint256 minOut) = _decode(outData);
        assertEq(routesAmount[0], 500);
        assertEq(minOut, 0, "zero minOut stays zero (no ZERO_MIN_RETURN)");
    }

    function test_Rescale_Revert_ZeroNewAmount() public {
        bytes memory txData = _txData(SRC, DST, 900, _one(1000), 0, RCPT);
        vm.expectRevert(PancakeSwapAmountUpdater.ZERO_AMOUNT.selector);
        h.rescale(txData, 0, 1000);
    }

    function test_Rescale_Revert_ZeroOldAmount() public {
        bytes memory txData = _txData(SRC, DST, 900, _one(1000), 0, RCPT);
        vm.expectRevert(PancakeSwapAmountUpdater.ZERO_AMOUNT.selector);
        h.rescale(txData, 1000, 0);
    }

    function test_Rescale_Revert_TooShort() public {
        vm.expectRevert(PancakeSwapAmountUpdater.TXDATA_TOO_SHORT.selector);
        h.rescale(bytes.concat(abi.encodeWithSelector(SWAP_EXACT_IN), new bytes(10)), 1, 1);
    }

    function test_Rescale_Revert_InvalidSelector() public {
        bytes memory txData = _txData(SRC, DST, 900, _one(1000), 0, RCPT);
        txData[0] = 0x00;
        vm.expectRevert(PancakeSwapAmountUpdater.INVALID_SELECTOR.selector);
        h.rescale(txData, 2000, 1000);
    }

    function test_Rescale_Revert_FeeConfig() public {
        bytes memory txData = _txData(SRC, DST, 900, _one(1000), 7, RCPT);
        vm.expectRevert(PancakeSwapAmountUpdater.FEE_CONFIG_UNSUPPORTED.selector);
        h.rescale(txData, 2000, 1000);
    }

    function test_Rescale_Revert_MultiRoute() public {
        uint256[] memory amts = new uint256[](2);
        amts[0] = 600;
        amts[1] = 400;
        bytes memory txData = _txData(SRC, DST, 900, amts, 0, RCPT);
        vm.expectRevert(PancakeSwapAmountUpdater.SINGLE_ROUTE_REQUIRED.selector);
        h.rescale(txData, 2000, 1000);
    }

    /// @dev The ZERO_MIN_RETURN guard is defensive: getUpdatedOutputAmount floors the DECREASE (not the
    ///      result), so with newAmount >= 1 a positive minOut never scales to 0. A heavy downscale of a
    ///      minOut of 1 therefore stays 1 and does NOT revert — we assert that reachable behavior.
    function test_Rescale_TinyDownscale_MinOutStaysNonZero() public view {
        bytes memory txData = _txData(SRC, DST, 1, _one(1000), 0, RCPT);
        bytes memory outData = h.rescale(txData, 1, 1000);
        (,, uint256[] memory routesAmount, uint256 minOut) = _decode(outData);
        assertEq(routesAmount[0], 1);
        assertEq(minOut, 1, "minOut floored-decrease keeps it at 1");
    }

    function test_Rescale_Revert_TooShort_RoutesAmountTruncated() public {
        // Valid single-route calldata, then truncate so the routesAmount element word is cut off.
        // Passes the 292-byte head guard but trips the post-head bounds check.
        bytes memory txData = _txData(SRC, DST, 900, _one(1000), 0, RCPT);
        require(txData.length > 300, "precondition");
        bytes memory truncated = new bytes(300); // >= 292 head, < routesAmount element end
        for (uint256 i; i < 300; i++) {
            truncated[i] = txData[i];
        }
        vm.expectRevert(PancakeSwapAmountUpdater.TXDATA_TOO_SHORT.selector);
        h.rescale(truncated, 2000, 1000);
    }

    /// @notice A routesAmount offset pointer aimed INTO the fixed head (so the element write could clobber a
    ///         validated word) is rejected — the surgical patch is non-interfering by construction.
    function test_Rescale_Revert_RoutesOffsetIntoHead() public {
        bytes memory txData = _txData(SRC, DST, 900, _one(1000), 0, RCPT);
        // slot 5 (byte 164) holds the routesAmount offset (relative to args start = byte 4). Point it at 50
        // so arrPos = 4 + 50 = 54, which is inside the 292-byte head.
        assembly {
            mstore(add(add(txData, 0x20), 164), 50)
        }
        vm.expectRevert(PancakeSwapAmountUpdater.INVALID_ROUTES_OFFSET.selector);
        h.rescale(txData, 2000, 1000);
    }

    /// @notice Fuzz the proportional rescale: amount is set exactly; minOut scales monotonically with the ratio.
    function testFuzz_Rescale_ProportionalMonotonic(uint256 newAmount, uint256 oldAmount, uint256 minOut) public view {
        newAmount = bound(newAmount, 1, 1e24);
        oldAmount = bound(oldAmount, 1, 1e24);
        minOut = bound(minOut, 0, 1e24);
        bytes memory txData = _txData(SRC, DST, minOut, _one(oldAmount), 0, RCPT);
        bytes memory outData = h.rescale(txData, newAmount, oldAmount);
        (,, uint256[] memory ra, uint256 scaled) = _decode(outData);
        assertEq(ra[0], newAmount, "amount set exactly");
        if (newAmount >= oldAmount) {
            assertGe(scaled, minOut, "upscale: minOut non-decreasing");
        } else {
            assertLe(scaled, minOut, "downscale: minOut non-increasing");
        }
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _one(uint256 a) private pure returns (uint256[] memory x) {
        x = new uint256[](1);
        x[0] = a;
    }

    function _emptyRoute(address fromToken) private pure returns (IPancakeSwapRouter.RouterPath memory p) {
        p = IPancakeSwapRouter.RouterPath({
            mixAdapters: new uint256[](0),
            assetTo: new address[](0),
            rawData: new uint256[](0),
            extraData: new bytes[](0),
            fromToken: fromToken
        });
    }

    function _txData(
        address src,
        address dst,
        uint256 minOut,
        uint256[] memory routesAmount,
        uint256 feeConfig,
        address recipient
    )
        private
        pure
        returns (bytes memory)
    {
        IPancakeSwapRouter.BaseExactInRequest memory req =
            IPancakeSwapRouter.BaseExactInRequest({ inputToken: src, outputToken: dst, minOutputAmount: minOut, deadline: 1 });
        IPancakeSwapRouter.RouterPath[][] memory routes = new IPancakeSwapRouter.RouterPath[][](routesAmount.length);
        for (uint256 i; i < routesAmount.length; i++) {
            routes[i] = new IPancakeSwapRouter.RouterPath[](1);
            routes[i][0] = _emptyRoute(src);
        }
        return abi.encodeWithSelector(SWAP_EXACT_IN, uint256(1), req, routesAmount, routes, feeConfig, recipient);
    }

    function _decode(bytes memory callData)
        private
        pure
        returns (address src, address dst, uint256[] memory routesAmount, uint256 minOut)
    {
        bytes memory args = new bytes(callData.length - 4);
        for (uint256 i = 0; i < args.length; i++) {
            args[i] = callData[i + 4];
        }
        (
            ,
            IPancakeSwapRouter.BaseExactInRequest memory req,
            uint256[] memory ra,
            ,
            ,
        ) = abi.decode(
            args,
            (
                uint256,
                IPancakeSwapRouter.BaseExactInRequest,
                uint256[],
                IPancakeSwapRouter.RouterPath[][],
                uint256,
                address
            )
        );
        return (req.inputToken, req.outputToken, ra, req.minOutputAmount);
    }
}
