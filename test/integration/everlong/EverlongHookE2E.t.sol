// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SwapEverlongHook } from "../../../src/hooks/swappers/everlong/SwapEverlongHook.sol";
import { ApproveAndSwapEverlongHook } from "../../../src/hooks/swappers/everlong/ApproveAndSwapEverlongHook.sol";
import { EverlongAmountUpdater } from "../../../src/libraries/EverlongAmountUpdater.sol";
import { ISwapRouter02 } from "../../../src/vendor/everlong/ISwapRouter02.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { EverlongKatanaFixtures } from "./EverlongKatanaFixtures.sol";

/// @dev Minimal WETH9: deposit/withdraw over a MockERC20 (withdraw pays from its own ETH balance).
contract MockWETH9 is MockERC20 {
    constructor() MockERC20("Wrapped Native", "WETH9", 18) { }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool ok,) = msg.sender.call{ value: amount }("");
        require(ok, "weth: withdraw");
    }

    receive() external payable { }
}

/// @dev Reproduces the VERIFIED SwapRouter02 semantics the hooks rely on, and nothing more: `multicall` deadline gate
///      and sequential dispatch; exact-input legs that pull per leg from the caller (`pay`: wrap msg.value when
///      tokenIn == WETH9 and the balance covers it, else transferFrom(msg.sender)); `amountIn == 0` means "swap my
///      whole balance"; recipient sentinels address(1)/address(2); output = amountIn x rate / 1e18 minted (or
///      WETH9-deposited) to the resolved recipient; sweep/unwrap tails check the floor PRE-fee and pay
///      balance x (1 - feeBips/10_000) to the recipient; `refundETH`.
contract MockSwapRouter02 {
    MockWETH9 public immutable WETH9;
    uint256 public rate = 1e18;
    uint256 public legsExecuted;
    uint256 public lastValue;

    constructor(MockWETH9 weth) {
        WETH9 = weth;
    }

    function setRate(uint256 r) external {
        rate = r;
    }

    receive() external payable { }

    function multicall(uint256 deadline, bytes[] calldata calls) external payable returns (bytes[] memory results) {
        require(block.timestamp <= deadline, "Transaction too old");
        lastValue = msg.value;
        results = new bytes[](calls.length);
        for (uint256 i; i < calls.length; ++i) {
            _dispatch(calls[i]);
        }
    }

    function _dispatch(bytes calldata c) private {
        bytes4 sel = bytes4(c[:4]);
        bytes calldata body = c[4:];
        if (sel == ISwapRouter02.exactInputSingle.selector) {
            ISwapRouter02.ExactInputSingleParams memory p = abi.decode(body, (ISwapRouter02.ExactInputSingleParams));
            _swap(p.tokenIn, p.tokenOut, p.recipient, p.amountIn, p.amountOutMinimum);
        } else if (sel == ISwapRouter02.exactInput.selector) {
            ISwapRouter02.ExactInputParams memory p = abi.decode(body, (ISwapRouter02.ExactInputParams));
            address tIn = address(bytes20(_slice(p.path, 0)));
            address tOut = address(bytes20(_slice(p.path, p.path.length - 20)));
            _swap(tIn, tOut, p.recipient, p.amountIn, p.amountOutMinimum);
        } else if (sel == ISwapRouter02.sweepTokenWithFee.selector) {
            (address token, uint256 min, address rcpt, uint256 feeBips, address feeRcpt) =
                abi.decode(body, (address, uint256, address, uint256, address));
            require(feeBips > 0 && feeBips <= 100);
            uint256 bal = IERC20(token).balanceOf(address(this));
            require(bal >= min, "Insufficient token");
            uint256 fee = bal * feeBips / 10_000;
            if (fee > 0) IERC20(token).transfer(feeRcpt, fee);
            IERC20(token).transfer(rcpt, bal - fee);
        } else if (sel == ISwapRouter02.sweepToken.selector) {
            (address token, uint256 min, address rcpt) = abi.decode(body, (address, uint256, address));
            uint256 bal = IERC20(token).balanceOf(address(this));
            require(bal >= min, "Insufficient token");
            IERC20(token).transfer(rcpt, bal);
        } else if (sel == ISwapRouter02.unwrapWETH9WithFee.selector) {
            (uint256 min, address rcpt, uint256 feeBips, address feeRcpt) =
                abi.decode(body, (uint256, address, uint256, address));
            require(feeBips > 0 && feeBips <= 100);
            uint256 bal = WETH9.balanceOf(address(this));
            require(bal >= min, "Insufficient WETH9");
            WETH9.withdraw(bal);
            uint256 fee = bal * feeBips / 10_000;
            if (fee > 0) _sendEth(feeRcpt, fee);
            _sendEth(rcpt, bal - fee);
        } else if (sel == ISwapRouter02.unwrapWETH9.selector) {
            (uint256 min, address rcpt) = abi.decode(body, (uint256, address));
            uint256 bal = WETH9.balanceOf(address(this));
            require(bal >= min, "Insufficient WETH9");
            WETH9.withdraw(bal);
            _sendEth(rcpt, bal);
        } else if (sel == ISwapRouter02.refundETH.selector) {
            if (address(this).balance > 0) _sendEth(msg.sender, address(this).balance);
        } else {
            revert("mock: unsupported");
        }
    }

    function _swap(address tIn, address tOut, address recipient, uint256 amountIn, uint256 minOut) private {
        if (recipient == address(1)) recipient = msg.sender;
        else if (recipient == address(2)) recipient = address(this);
        bool contractBalance = amountIn == 0;
        if (contractBalance) {
            amountIn = IERC20(tIn).balanceOf(address(this));
        } else if (tIn == address(WETH9) && address(this).balance >= amountIn) {
            WETH9.deposit{ value: amountIn }();
        } else {
            IERC20(tIn).transferFrom(msg.sender, address(this), amountIn);
        }
        // consume the input
        IERC20(tIn).transfer(address(0xdead), amountIn);
        uint256 out = amountIn * rate / 1e18;
        require(out >= minOut, "Too little received");
        // the pool hands over tokenOut (WETH9 included); the mock WETH9 holds the ETH reserve backing withdrawals
        MockERC20(tOut).mint(recipient, out);
        ++legsExecuted;
    }

    function _sendEth(address to, uint256 amount) private {
        (bool ok,) = to.call{ value: amount }("");
        require(ok, "eth send");
    }

    function _slice(bytes memory b, uint256 start) private pure returns (bytes20 out) {
        assembly ("memory-safe") {
            out := mload(add(add(b, 0x20), start))
        }
    }
}

contract EverlongHookE2ETest is Test, EverlongKatanaFixtures {
    MockWETH9 internal weth;
    MockSwapRouter02 internal router;
    SwapEverlongHook internal swapHook;
    ApproveAndSwapEverlongHook internal approveHook;
    MockHook internal prevHook;

    address internal account;
    MockERC20 internal inToken;
    MockERC20 internal outToken;
    address internal constant THIS = address(2);
    uint256 internal constant DEADLINE = 1_800_000_000;

    uint256 internal constant IN = 1000e18;
    uint256 internal constant QUOTE = 1000e18; // 1:1 rate -> router balance before fee
    uint256 internal constant TAIL_MIN = 995e18; // Everlong's pre-fee floor (0.5% slippage)
    uint256 internal constant HEADER_MIN = 994e18; // post-fee floor the bundler signs (995 * 0.9996 = 994.6)

    receive() external payable { }

    function setUp() public {
        vm.warp(DEADLINE - 1000);
        account = address(this);
        weth = new MockWETH9();
        router = new MockSwapRouter02(weth);
        vm.deal(address(weth), 100_000 ether); // ETH reserve backing WETH9 withdrawals on native-out routes
        inToken = new MockERC20("Input", "IN", 18);
        outToken = new MockERC20("Output", "OUT", 18);
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(inToken));
        prevHook.setOutToken(address(inToken));

        swapHook = new SwapEverlongHook(address(router), address(weth), NATIVE);
        approveHook = new ApproveAndSwapEverlongHook(address(router), address(weth), NATIVE);
    }

    function _executeAll(Execution[] memory ex) internal {
        for (uint256 i = 0; i < ex.length; i++) {
            (bool ok, bytes memory ret) = ex[i].target.call{ value: ex[i].value }(ex[i].callData);
            if (!ok) {
                assembly ("memory-safe") {
                    revert(add(ret, 32), mload(ret))
                }
            }
        }
    }

    function executeAllExternal(Execution[] memory ex) external {
        _executeAll(ex);
    }

    /*//////////////////////////////////////////////////////////////
                               HAPPY PATHS
    //////////////////////////////////////////////////////////////*/

    function test_E2E_ApproveAndSwap_ERC20_Fixed_FeeIdentity() public {
        inToken.mint(account, IN);
        _executeAll(approveHook.build(address(prevHook), account, _erc20Data(IN, HEADER_MIN, false)));
        uint256 out = outToken.balanceOf(account);
        uint256 fee = outToken.balanceOf(FEE_RECIPIENT);
        assertEq(inToken.balanceOf(account), 0, "input spent exactly");
        assertEq(out + fee, QUOTE, "router balance split between account and fee recipient");
        assertEq(fee, QUOTE * FEE_BIPS / 10_000, "4 bps fee");
        assertEq(inToken.allowance(account, address(router)), 0, "allowance reset");
        assertEq(router.legsExecuted(), 3, "all three legs ran");
        assertEq(approveHook.getOutAmount(account), out, "accounting is the post-fee delta");
        _assertNoDustOnHooks();
    }

    function test_E2E_PlainSwap_ERC20_ExternalApproval() public {
        inToken.mint(account, IN);
        inToken.approve(address(router), IN);
        _executeAll(swapHook.build(address(prevHook), account, _erc20Data(IN, HEADER_MIN, false)));
        assertEq(inToken.balanceOf(account), 0);
        assertEq(outToken.balanceOf(account), QUOTE - QUOTE * FEE_BIPS / 10_000);
        _assertNoDustOnHooks();
    }

    function test_E2E_NativeInput_BothVariants() public {
        vm.deal(account, 2 * IN);
        bytes memory data =
            _hookData(NATIVE, address(outToken), IN, QUOTE, HEADER_MIN, false, _txNativeIn(IN, TAIL_MIN));
        uint256 ethBefore = account.balance;
        _executeAll(approveHook.build(address(prevHook), account, data));
        assertEq(ethBefore - account.balance, IN, "value forwarded == sum of legs, refund 0");
        assertEq(router.lastValue(), IN);
        assertEq(outToken.balanceOf(account), QUOTE - QUOTE * FEE_BIPS / 10_000);
        _executeAll(swapHook.build(address(prevHook), account, data));
        assertEq(outToken.balanceOf(account), 2 * (QUOTE - QUOTE * FEE_BIPS / 10_000));
        assertEq(address(router).balance, 0, "no ETH stranded on the router");
        _assertNoDustOnHooks();
    }

    function test_E2E_NativeOutput_BothVariants() public {
        inToken.mint(account, 2 * IN);
        bytes memory data =
            _hookData(address(inToken), NATIVE, IN, QUOTE, HEADER_MIN, false, _txNativeOut(IN, TAIL_MIN));
        uint256 ethBefore = account.balance;
        _executeAll(approveHook.build(address(prevHook), account, data));
        uint256 got = account.balance - ethBefore;
        assertEq(got, QUOTE - QUOTE * FEE_BIPS / 10_000, "native delivered post-fee");
        assertEq(FEE_RECIPIENT.balance, QUOTE * FEE_BIPS / 10_000);
        assertEq(approveHook.getOutToken(account), NATIVE);
        inToken.approve(address(router), IN);
        _executeAll(swapHook.build(address(prevHook), account, data));
        assertEq(account.balance - ethBefore, 2 * got);
    }

    function test_E2E_UsePrevHookAmount_Down95_And_Up105_BothVariants() public {
        _chained(IN * 95 / 100, address(approveHook));
        _chained(IN * 105 / 100, address(swapHook));
    }

    function _chained(uint256 actual, address hook) internal {
        inToken.mint(account, actual);
        if (hook == address(swapHook)) inToken.approve(address(router), actual);
        prevHook.setOutAmount(actual, account);
        uint256 outBefore = outToken.balanceOf(account);
        uint256 feeBefore = outToken.balanceOf(FEE_RECIPIENT);
        _executeAll(ISuperHook(hook).build(address(prevHook), account, _erc20Data(IN, HEADER_MIN, true)));
        uint256 out = outToken.balanceOf(account) - outBefore;
        uint256 fee = outToken.balanceOf(FEE_RECIPIENT) - feeBefore;
        assertEq(inToken.balanceOf(account), 0, "spent exactly the actual amount (sum of rescaled legs)");
        assertEq(out + fee, actual, "1:1 at the rescaled size");
        assertEq(fee, actual * FEE_BIPS / 10_000, "fee taken on the rescaled output");
        assertGe(out, Math.mulDiv(HEADER_MIN, actual, IN, Math.Rounding.Ceil), "scaled hook floor");
        assertEq(inToken.allowance(account, address(router)), 0);
    }

    function test_E2E_UsePrevHookAmount_NativeInput_ValueScaled() public {
        uint256 actual = IN * 9 / 10;
        vm.deal(account, actual);
        prevHook.setOutAmount(actual, account);
        prevHook.setOutToken(NATIVE);
        _executeAll(
            swapHook.build(
                address(prevHook),
                account,
                _hookData(NATIVE, address(outToken), IN, QUOTE, HEADER_MIN, true, _txNativeIn(IN, TAIL_MIN))
            )
        );
        assertEq(account.balance, 0, "exactly the scaled value was forwarded");
        assertEq(router.lastValue(), actual);
        assertEq(outToken.balanceOf(account), actual - actual * FEE_BIPS / 10_000);
    }

    /// @notice PR #1048 review P2, reproduced through both hooks: legs 1 + 999 with a nonzero minimum on the 1-wei
    ///         leg, previous hook output 1999, 1:1 venue. With the minimum scaled by the total ratio the first leg
    ///         demanded 2 for 1 wei in and the batch reverted 'Too little received'; per-leg scaling lets the route
    ///         spend and receive 1999.
    function test_E2E_UsePrevHookAmount_NonzeroLegMin_FractionalRatio() public {
        _legMinChained(address(approveHook));
        _legMinChained(address(swapHook));
    }

    function _legMinChained(address hook) internal {
        uint256 quotedIn = 1000;
        uint256 actual = 1999;
        bytes[] memory c = new bytes[](3);
        c[0] = _eisMin(address(inToken), address(outToken), 1, 1);
        c[1] = _eisMin(address(inToken), address(outToken), 999, 999);
        c[2] = _sweepFee(address(outToken), quotedIn, account);
        bytes memory data = _hookData(
            address(inToken),
            address(outToken),
            quotedIn,
            quotedIn,
            quotedIn * (10_000 - FEE_BIPS) / 10_000,
            true,
            _mc(c)
        );
        inToken.mint(account, actual);
        if (hook == address(swapHook)) inToken.approve(address(router), actual);
        prevHook.setOutAmount(actual, account);
        uint256 outBefore = outToken.balanceOf(account);
        uint256 feeBefore = outToken.balanceOf(FEE_RECIPIENT);
        _executeAll(ISuperHook(hook).build(address(prevHook), account, data));
        assertEq(inToken.balanceOf(account), 0, "spent 1999");
        assertEq(
            outToken.balanceOf(account) - outBefore + outToken.balanceOf(FEE_RECIPIENT) - feeBefore,
            actual,
            "received 1999"
        );
        assertEq(inToken.allowance(account, address(router)), 0, "allowance reset");
    }

    function _eisMin(address tIn, address tOut, uint256 amountIn, uint256 minOut) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            ISwapRouter02.exactInputSingle.selector,
            ISwapRouter02.ExactInputSingleParams(tIn, tOut, 500, THIS, amountIn, minOut, 0)
        );
    }

    /*//////////////////////////////////////////////////////////////
                                SECURITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Everlong's own floor passes (rate 0.995 -> router balance 995 == tail min) but the signed post-fee
    /// header floor does not: the account receives 995 x 0.9996 = 994.602 < 994.7.
    function test_E2E_Security_HookFloor_RevertsBelowPostFeeHeaderMin() public {
        router.setRate(0.995e18);
        inToken.mint(account, IN);
        Execution[] memory ex = approveHook.build(address(prevHook), account, _erc20Data(IN, 994.7e18, false));
        vm.expectRevert(
            abi.encodeWithSelector(ApproveAndSwapEverlongHook.INSUFFICIENT_OUTPUT_AMOUNT.selector, 994.602e18, 994.7e18)
        );
        this.executeAllExternal(ex);
        assertEq(inToken.balanceOf(account), IN, "atomic: nothing moved");
    }

    function test_E2E_Security_HookFloor_ScaledOnChainedPath() public {
        uint256 actual = IN / 2;
        router.setRate(0.995e18);
        inToken.mint(account, actual);
        prevHook.setOutAmount(actual, account);
        // required = ceil(994.7e18 / 2) = 497.35e18; received = 497.5e18 * 0.9996 = 497.301e18 -> revert
        Execution[] memory ex = approveHook.build(address(prevHook), account, _erc20Data(IN, 994.7e18, true));
        vm.expectRevert(
            abi.encodeWithSelector(
                ApproveAndSwapEverlongHook.INSUFFICIENT_OUTPUT_AMOUNT.selector, 497.301e18, 497.35e18
            )
        );
        this.executeAllExternal(ex);
    }

    function test_E2E_Security_TailFloor_Propagates() public {
        router.setRate(0.5e18);
        inToken.mint(account, IN);
        Execution[] memory ex = approveHook.build(address(prevHook), account, _erc20Data(IN, HEADER_MIN, false));
        vm.expectRevert(bytes("Insufficient token"));
        this.executeAllExternal(ex);
    }

    function test_E2E_Security_DeadlineExpired_Reverts() public {
        inToken.mint(account, IN);
        Execution[] memory ex = approveHook.build(address(prevHook), account, _erc20Data(IN, HEADER_MIN, false));
        vm.warp(DEADLINE + 1);
        vm.expectRevert(bytes("Transaction too old"));
        this.executeAllExternal(ex);
    }

    function test_E2E_Security_OutputAccountingIsDelta() public {
        outToken.mint(account, 777e18);
        inToken.mint(account, IN);
        _executeAll(approveHook.build(address(prevHook), account, _erc20Data(IN, HEADER_MIN, false)));
        assertEq(approveHook.getOutAmount(account), QUOTE - QUOTE * FEE_BIPS / 10_000);
    }

    function test_E2E_Security_Substitutions_Blocked() public {
        MockERC20 other = new MockERC20("Other", "OTH", 18);
        inToken.mint(account, IN);
        // input substitution: legs in another token than the header
        bytes memory tx_ = _txErc20(address(other), address(outToken), IN, TAIL_MIN, account);
        vm.expectRevert(ApproveAndSwapEverlongHook.INPUT_TOKEN_MISMATCH.selector);
        approveHook.build(
            address(prevHook),
            account,
            _hookData(address(inToken), address(outToken), IN, QUOTE, HEADER_MIN, false, tx_)
        );
        // leg recipient substitution (pays a third party directly, bypassing the tail)
        bytes[] memory c = new bytes[](2);
        c[0] = abi.encodeWithSelector(
            ISwapRouter02.exactInputSingle.selector,
            ISwapRouter02.ExactInputSingleParams(address(inToken), address(outToken), 500, address(0xBAD), IN, 0, 0)
        );
        c[1] = _sweepFee(address(outToken), TAIL_MIN, account);
        vm.expectRevert(EverlongAmountUpdater.INVALID_LEG_RECIPIENT.selector);
        approveHook.build(
            address(prevHook),
            account,
            _hookData(address(inToken), address(outToken), IN, QUOTE, HEADER_MIN, false, _mc(c))
        );
        // pull leg (moves the account's funds outside the swap)
        c[0] = _eis(address(inToken), address(outToken), IN);
        bytes[] memory c3 = new bytes[](3);
        c3[0] = c[0];
        c3[1] = abi.encodeWithSelector(bytes4(0xf2d5d56b), address(inToken), IN);
        c3[2] = c[1];
        vm.expectRevert(
            abi.encodeWithSelector(EverlongAmountUpdater.UNSUPPORTED_LEG_SELECTOR.selector, bytes4(0xf2d5d56b))
        );
        approveHook.build(
            address(prevHook),
            account,
            _hookData(address(inToken), address(outToken), IN, QUOTE, HEADER_MIN, false, _mc(c3))
        );
        assertEq(inToken.balanceOf(account), IN, "nothing moved");
    }

    /// @notice Security finding: a native-input path that revisits WETH9 mid-route would make the router wrap the ETH
    ///         reserved for later legs and pull WETH9 from the account instead. The library rejects the path.
    function test_E2E_Security_CyclicPath_Blocked() public {
        bytes[] memory c = new bytes[](3);
        c[0] = abi.encodeWithSelector(
            ISwapRouter02.exactInput.selector,
            ISwapRouter02.ExactInputParams(
                abi.encodePacked(
                    address(weth),
                    uint24(500),
                    address(inToken),
                    uint24(500),
                    address(weth),
                    uint24(500),
                    address(outToken)
                ),
                THIS,
                IN / 2,
                0
            )
        );
        c[1] = _eis(address(weth), address(outToken), IN / 2);
        c[2] = _sweepFee(address(outToken), TAIL_MIN, account);
        bytes[] memory withRefund = new bytes[](4);
        for (uint256 i; i < 3; ++i) {
            withRefund[i] = c[i];
        }
        withRefund[3] = abi.encodeWithSelector(ISwapRouter02.refundETH.selector);
        vm.expectRevert(EverlongAmountUpdater.INVALID_PATH.selector);
        swapHook.build(
            address(prevHook),
            account,
            _hookData(NATIVE, address(outToken), IN, QUOTE, HEADER_MIN, false, _mc(withRefund))
        );
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _assertNoDustOnHooks() private view {
        assertEq(inToken.balanceOf(address(swapHook)), 0);
        assertEq(outToken.balanceOf(address(swapHook)), 0);
        assertEq(address(swapHook).balance, 0);
        assertEq(inToken.balanceOf(address(approveHook)), 0);
        assertEq(outToken.balanceOf(address(approveHook)), 0);
        assertEq(address(approveHook).balance, 0);
        assertEq(outToken.balanceOf(address(router)), 0, "router swept everything");
    }

    function _eis(address tIn, address tOut, uint256 amountIn) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            ISwapRouter02.exactInputSingle.selector,
            ISwapRouter02.ExactInputSingleParams(tIn, tOut, 500, THIS, amountIn, 0, 0)
        );
    }

    function _sweepFee(address token, uint256 min, address rcpt) internal pure returns (bytes memory) {
        return
            abi.encodeWithSelector(ISwapRouter02.sweepTokenWithFee.selector, token, min, rcpt, FEE_BIPS, FEE_RECIPIENT);
    }

    function _mc(bytes[] memory calls) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ISwapRouter02.multicall.selector, DEADLINE, calls);
    }

    /// @dev Three legs (50 / 30 / 20, the last via a 2-hop exactInput path) + sweepTokenWithFee tail.
    function _txErc20(
        address tIn,
        address tOut,
        uint256 amountIn,
        uint256 tailMin,
        address rcpt
    )
        internal
        view
        returns (bytes memory)
    {
        bytes[] memory c = new bytes[](4);
        c[0] = _eis(tIn, tOut, amountIn / 2);
        c[1] = _eis(tIn, tOut, amountIn * 3 / 10);
        c[2] = abi.encodeWithSelector(
            ISwapRouter02.exactInput.selector,
            ISwapRouter02.ExactInputParams(
                abi.encodePacked(tIn, uint24(500), address(weth), uint24(3000), tOut),
                THIS,
                amountIn - amountIn / 2 - amountIn * 3 / 10,
                0
            )
        );
        c[3] = _sweepFee(tOut, tailMin, rcpt);
        return _mc(c);
    }

    function _txNativeIn(uint256 amountIn, uint256 tailMin) internal view returns (bytes memory) {
        bytes[] memory c = new bytes[](4);
        c[0] = _eis(address(weth), address(outToken), amountIn * 6 / 10);
        c[1] = _eis(address(weth), address(outToken), amountIn - amountIn * 6 / 10);
        c[2] = _sweepFee(address(outToken), tailMin, account);
        c[3] = abi.encodeWithSelector(ISwapRouter02.refundETH.selector);
        return _mc(c);
    }

    function _txNativeOut(uint256 amountIn, uint256 tailMin) internal view returns (bytes memory) {
        bytes[] memory c = new bytes[](4);
        c[0] = _eis(address(inToken), address(weth), amountIn * 6 / 10);
        c[1] = _eis(address(inToken), address(weth), amountIn - amountIn * 6 / 10);
        c[2] = abi.encodeWithSelector(
            ISwapRouter02.unwrapWETH9WithFee.selector, tailMin, account, FEE_BIPS, FEE_RECIPIENT
        );
        c[3] = abi.encodeWithSelector(ISwapRouter02.refundETH.selector);
        return _mc(c);
    }

    function _erc20Data(uint256 amount, uint256 headerMin, bool flag) internal view returns (bytes memory) {
        return _hookData(
            address(inToken),
            address(outToken),
            amount,
            QUOTE,
            headerMin,
            flag,
            _txErc20(address(inToken), address(outToken), amount, TAIL_MIN, account)
        );
    }
}
