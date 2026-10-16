// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SwapPancakeSwapHook } from "../../../src/hooks/swappers/pancakeswap/SwapPancakeSwapHook.sol";
import {
    ApproveAndSwapPancakeSwapHook
} from "../../../src/hooks/swappers/pancakeswap/ApproveAndSwapPancakeSwapHook.sol";
import { IPancakeSwapRouter } from "../../../src/vendor/pancakeswap/IPancakeSwapRouter.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockHook } from "../../mocks/MockHook.sol";

/// @dev Minimal stand-in for the PancakeSwap aggregation router. Pulls the summed `routesAmount` of the input
///      token (or requires matching msg.value for native), enforces the min-output floor, and mints 1:1 output
///      to the recipient. Lets the e2e exercise the hook's full approve -> swap -> reset + accounting flow
///      without a captured /v1/calldata sample.
contract MockPancakeSwapRouter is IPancakeSwapRouter {
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address private constant ARC_NATIVE = 0x3600000000000000000000000000000000000000;

    uint256 public lastInputAmount;
    uint256 public lastMinOutput;
    address public lastRecipient;
    uint256 public lastValue;

    function swapExactIn(
        uint256,
        BaseExactInRequest calldata request,
        uint256[] calldata routesAmount,
        RouterPath[][] calldata,
        uint256,
        address recipient
    )
        external
        payable
        override
        returns (uint256 out)
    {
        uint256 total;
        for (uint256 i; i < routesAmount.length; ++i) {
            total += routesAmount[i];
        }
        lastInputAmount = total;
        lastMinOutput = request.minOutputAmount;
        lastRecipient = recipient;
        lastValue = msg.value;

        if (_isNative(request.inputToken)) {
            require(msg.value == total, "bad value");
        } else {
            require(msg.value == 0, "unexpected value");
            IERC20(request.inputToken).transferFrom(msg.sender, address(this), total);
        }

        out = total; // 1:1
        require(out >= request.minOutputAmount, "slippage");
        if (_isNative(request.outputToken)) {
            (bool s,) = recipient.call{ value: out }("");
            require(s, "native out");
        } else {
            MockERC20(request.outputToken).mint(recipient, out);
        }
    }

    function _isNative(address t) private pure returns (bool) {
        return t == address(0) || t == NATIVE || t == ARC_NATIVE;
    }

    receive() external payable { }
}

contract PancakeSwapHookE2ETest is Test {
    bytes4 private constant SWAP_EXACT_IN = 0xedad400c;
    address private constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    MockPancakeSwapRouter private router;
    SwapPancakeSwapHook private swapHook;
    ApproveAndSwapPancakeSwapHook private approveHook;
    MockHook private prevHook;

    address private account;
    MockERC20 private inToken;
    MockERC20 private outToken;

    function setUp() public {
        account = address(this);
        router = new MockPancakeSwapRouter();
        inToken = new MockERC20("Input", "IN", 18);
        outToken = new MockERC20("Output", "OUT", 18);
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(inToken));

        swapHook = new SwapPancakeSwapHook(address(router), NATIVE, NATIVE);
        approveHook = new ApproveAndSwapPancakeSwapHook(address(router), NATIVE, NATIVE);
    }

    receive() external payable { }

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

    /// @dev External wrapper so vm.expectRevert binds to the whole batch (not just the first leg).
    function executeAllExternal(Execution[] memory ex) external {
        _executeAll(ex);
    }

    /*//////////////////////////////////////////////////////////////
                              E2E FLOWS
    //////////////////////////////////////////////////////////////*/

    function test_E2E_ApproveAndSwap_ERC20_FixedAmount() public {
        uint256 amount = 1000e18;
        inToken.mint(account, amount);

        bytes memory txData = _txData(address(inToken), address(outToken), 900e18, amount, 0, account);
        bytes memory data = _hookData(address(inToken), address(outToken), amount, 900e18, false, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        _executeAll(ex);

        assertEq(inToken.balanceOf(account), 0, "input spent");
        assertEq(outToken.balanceOf(account), amount, "output received 1:1");
        assertEq(inToken.allowance(account, address(router)), 0, "allowance reset");
        assertEq(router.lastRecipient(), account);
        assertEq(approveHook.getOutAmount(account), amount, "post-exec out accounting");
    }

    function test_E2E_PlainSwap_ERC20_WithExternalApproval() public {
        uint256 amount = 500e18;
        inToken.mint(account, amount);
        inToken.approve(address(router), amount); // plain variant assumes external approval

        bytes memory txData = _txData(address(inToken), address(outToken), 0, amount, 0, account);
        bytes memory data = _hookData(address(inToken), address(outToken), amount, 0, false, txData);

        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        _executeAll(ex);

        assertEq(outToken.balanceOf(account), amount, "output received");
        assertEq(swapHook.getOutAmount(account), amount, "out accounting");
    }

    function test_E2E_NativeInput() public {
        uint256 amount = 2 ether;
        vm.deal(account, amount);

        bytes memory txData = _txData(NATIVE, address(outToken), 0, amount, 0, account);
        bytes memory data = _hookData(NATIVE, address(outToken), amount, 0, false, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        _executeAll(ex);

        assertEq(account.balance, 0, "native spent");
        assertEq(router.lastValue(), amount, "value forwarded to router");
        assertEq(outToken.balanceOf(account), amount, "output received");
    }

    function test_E2E_UsePrevHookAmount_SingleRoute_SwapsScaledAmount() public {
        uint256 originalAmount = 1000e18;
        uint256 newAmount = 2500e18;
        prevHook.setOutAmount(newAmount, account);
        inToken.mint(account, newAmount);

        // quote built for originalAmount with minOut 900; after scaling minOut -> 2250
        bytes memory txData = _txData(address(inToken), address(outToken), 900e18, originalAmount, 0, account);
        bytes memory data = _hookData(address(inToken), address(outToken), originalAmount, 900e18, true, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        _executeAll(ex);

        assertEq(router.lastInputAmount(), newAmount, "router swapped the scaled amount");
        assertEq(router.lastMinOutput(), 2250e18, "minOut scaled proportionally");
        assertEq(outToken.balanceOf(account), newAmount, "output == scaled input (1:1)");
        assertEq(approveHook.getOutAmount(account), newAmount, "out accounting on scaled amount");
    }

    function test_E2E_NativeOutput_AccountingUsesEthBalance() public {
        uint256 amount = 300e18;
        inToken.mint(account, amount);
        vm.deal(address(router), amount); // router pays out native
        uint256 beforeBal = account.balance;

        bytes memory txData = _txData(address(inToken), NATIVE, 0, amount, 0, account);
        bytes memory data = _hookData(address(inToken), NATIVE, amount, 0, false, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        _executeAll(ex);

        assertEq(account.balance - beforeBal, amount, "native output received");
        // _getBalance native branch + _postExecute delta
        assertEq(approveHook.getOutAmount(account), amount, "out accounting via account.balance");
    }

    function test_E2E_PlainSwap_NativeOutput() public {
        uint256 amount = 120e18;
        inToken.mint(account, amount);
        inToken.approve(address(router), amount);
        vm.deal(address(router), amount);
        uint256 beforeBal = account.balance;

        bytes memory txData = _txData(address(inToken), NATIVE, 0, amount, 0, account);
        bytes memory data = _hookData(address(inToken), NATIVE, amount, 0, false, txData);

        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        _executeAll(ex);

        assertEq(account.balance - beforeBal, amount, "native output received");
        assertEq(swapHook.getOutAmount(account), amount);
    }

    /*//////////////////////////////////////////////////////////////
                    SECURITY-FOCUSED E2E
    //////////////////////////////////////////////////////////////*/

    /// @notice Native input + chaining: the forwarded value must be the RESCALED amount, and it must exactly
    ///         match the router's summed routesAmount (the router reverts on mismatch), so no stale inputAmount.
    function test_E2E_Security_NativeInput_UsePrevHookAmount_ValueMatchesRescaled() public {
        uint256 originalAmount = 1 ether;
        uint256 newAmount = 3 ether;
        prevHook.setOutAmount(newAmount, account);
        vm.deal(account, newAmount);

        bytes memory txData = _txData(NATIVE, address(outToken), 0, originalAmount, 0, account);
        bytes memory data = _hookData(NATIVE, address(outToken), originalAmount, 0, true, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        _executeAll(ex);

        assertEq(router.lastValue(), newAmount, "value forwarded == rescaled amount");
        assertEq(router.lastInputAmount(), newAmount, "routesAmount rescaled");
        assertEq(outToken.balanceOf(account), newAmount, "output received");
    }

    /// @notice Output accounting is a balance DELTA, so a positive surplus (router returns more than quoted)
    ///         is attributed correctly and a hostile/short return cannot inflate getOutAmount.
    function test_E2E_Security_OutputAccountingIsDelta() public {
        uint256 amount = 100e18;
        inToken.mint(account, amount);
        // pre-seed the account with unrelated output tokens; accounting must ignore the pre-balance
        outToken.mint(account, 777e18);

        bytes memory txData = _txData(address(inToken), address(outToken), 0, amount, 0, account);
        bytes memory data = _hookData(address(inToken), address(outToken), amount, 0, false, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        _executeAll(ex);

        assertEq(outToken.balanceOf(account), 777e18 + amount, "pre-balance untouched + swap output");
        assertEq(approveHook.getOutAmount(account), amount, "out == delta only, not total balance");
    }

    /// @notice An input-token-substitution attempt (txData pulls a different, more valuable token than the
    ///         header input) is rejected at build time; no funds are moved.
    function test_E2E_Security_InputSubstitution_Blocked() public {
        MockERC20 valuable = new MockERC20("Valuable", "VAL", 18);
        valuable.mint(account, 1_000_000e18);

        // header says swap inToken, but txData tries to pull `valuable`
        bytes memory txData = _txData(address(valuable), address(outToken), 0, 1000e18, 0, account);
        bytes memory data = _hookData(address(inToken), address(outToken), 1000e18, 0, false, txData);

        vm.expectRevert(); // INPUT_TOKEN_MISMATCH
        approveHook.build(address(prevHook), account, data);

        assertEq(valuable.balanceOf(account), 1_000_000e18, "no valuable token moved");
    }

    /// @notice After an ApproveAndSwap the router allowance is reset to zero (no lingering approval).
    function test_E2E_Security_AllowanceResetToZero() public {
        uint256 amount = 50e18;
        inToken.mint(account, amount);

        bytes memory txData = _txData(address(inToken), address(outToken), 0, amount, 0, account);
        bytes memory data = _hookData(address(inToken), address(outToken), amount, 0, false, txData);

        _executeAll(approveHook.build(address(prevHook), account, data));
        assertEq(inToken.allowance(account, address(router)), 0, "router allowance reset");
    }

    /// @notice Plain SwapHook chaining executed end-to-end (its own rescale+validate+value copy, not just build()).
    function test_E2E_PlainSwap_UsePrevHookAmount_Executed() public {
        uint256 originalAmount = 1000e18;
        uint256 newAmount = 2500e18;
        prevHook.setOutAmount(newAmount, account);
        inToken.mint(account, newAmount);
        inToken.approve(address(router), newAmount); // plain variant: external approval

        bytes memory txData = _txData(address(inToken), address(outToken), 900e18, originalAmount, 0, account);
        bytes memory data = _hookData(address(inToken), address(outToken), originalAmount, 900e18, true, txData);

        _executeAll(swapHook.build(address(prevHook), account, data));

        assertEq(router.lastInputAmount(), newAmount, "plain swap rescaled input");
        assertEq(router.lastMinOutput(), 2250e18, "minOut scaled");
        assertEq(outToken.balanceOf(account), newAmount, "output received");
        assertEq(swapHook.getOutAmount(account), newAmount);
    }

    /// @notice A router slippage failure (out < minOutputAmount) propagates — the hook does not mask it.
    function test_E2E_Security_SlippageRevertPropagates() public {
        uint256 amount = 100e18;
        inToken.mint(account, amount);
        // router pays 1:1, so minOutputAmount > amount makes the router's require(out >= min) fail
        bytes memory txData = _txData(address(inToken), address(outToken), amount + 1, amount, 0, account);
        bytes memory data = _hookData(address(inToken), address(outToken), amount, amount + 1, false, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        vm.expectRevert(bytes("slippage"));
        this.executeAllExternal(ex);
    }

    /// @notice Multi-route FIXED-amount swap executed end-to-end (summed pull + output).
    function test_E2E_MultiRoute_FixedAmount_Executed() public {
        uint256 total = 1000e18; // routesAmount = [600, 400]
        inToken.mint(account, total);

        bytes memory txData = _txDataMultiRoute(address(inToken), address(outToken), 0, 0, account);
        bytes memory data = _hookData(address(inToken), address(outToken), total, 0, false, txData);

        _executeAll(approveHook.build(address(prevHook), account, data));

        assertEq(router.lastInputAmount(), total, "summed routesAmount pulled");
        assertEq(outToken.balanceOf(account), total, "output received");
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _txDataMultiRoute(
        address src,
        address dst,
        uint256 minOut,
        uint256 feeConfig,
        address recipient
    )
        private
        view
        returns (bytes memory)
    {
        IPancakeSwapRouter.BaseExactInRequest memory req = IPancakeSwapRouter.BaseExactInRequest({
            inputToken: src,
            outputToken: dst,
            minOutputAmount: minOut,
            deadline: block.timestamp + 1
        });
        uint256[] memory routesAmount = new uint256[](2);
        routesAmount[0] = 600e18;
        routesAmount[1] = 400e18;
        IPancakeSwapRouter.RouterPath[][] memory routes = new IPancakeSwapRouter.RouterPath[][](2);
        routes[0] = new IPancakeSwapRouter.RouterPath[](1);
        routes[0][0] = _emptyRoute(src);
        routes[1] = new IPancakeSwapRouter.RouterPath[](1);
        routes[1][0] = _emptyRoute(src);
        return abi.encodeWithSelector(SWAP_EXACT_IN, uint256(1), req, routesAmount, routes, feeConfig, recipient);
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
        uint256 amount,
        uint256 feeConfig,
        address recipient
    )
        private
        view
        returns (bytes memory)
    {
        IPancakeSwapRouter.BaseExactInRequest memory req = IPancakeSwapRouter.BaseExactInRequest({
            inputToken: src,
            outputToken: dst,
            minOutputAmount: minOut,
            deadline: block.timestamp + 1
        });
        uint256[] memory routesAmount = new uint256[](1);
        routesAmount[0] = amount;
        IPancakeSwapRouter.RouterPath[][] memory routes = new IPancakeSwapRouter.RouterPath[][](1);
        routes[0] = new IPancakeSwapRouter.RouterPath[](1);
        routes[0][0] = _emptyRoute(src);
        return abi.encodeWithSelector(SWAP_EXACT_IN, uint256(1), req, routesAmount, routes, feeConfig, recipient);
    }

    function _hookData(
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
        bytes memory payload = abi.encode(txData_);
        return bytes.concat(
            bytes(new bytes(52)),
            bytes20(inputToken_),
            bytes20(outputToken_),
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(outputMin_),
            bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)),
            bytes32(payload.length),
            payload
        );
    }
}
