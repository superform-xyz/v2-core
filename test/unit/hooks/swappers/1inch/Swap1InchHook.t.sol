// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Swap1InchHook } from "../../../../../src/core/hooks/swappers/1inch/Swap1InchHook.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import "../../../../../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract MockUniswapPair {
    address public token0;
    address public token1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
}

contract MockCurvePair {
    address coin;

    constructor(address _coin) {
        coin = _coin;
    }

    function get() external view returns (address) {
        return address(this);
    }

    function base_coins(uint256) external view returns (address) {
        return coin;
    }

    function coins(int128) external view returns (address) {
        return coin;
    }

    function coins(uint256) external view returns (address) {
        return coin;
    }

    function underlying_coins(int128) external view returns (address) {
        return coin;
    }

    function underlying_coins(uint256) external view returns (address) {
        return coin;
    }
}

contract Executor {
    function execute(address) external payable returns (int256) {
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        IERC20(DAI).transfer(msg.sender, 100e18);
        return 100e18;
    }
}

contract Swap1InchHookTest is Helpers {
    Swap1InchHook public hook;

    address dstToken;
    address dstReceiver;
    address srcToken;
    uint256 value;
    bytes txData;
    address mockPair;
    address mockRouter;
    address mockCurvePair;

    receive() external payable { }

    function setUp() public {
        MockERC20 _mockSrcToken = new MockERC20("Source Token", "SRC", 18);
        srcToken = address(_mockSrcToken);

        MockERC20 _mockDstToken = new MockERC20("Destination Token", "DST", 18);
        dstToken = address(_mockDstToken);

        dstReceiver = makeAddr("dstReceiver");
        value = 1000;

        // Create a mock pair that will be used in the unoswap test
        mockPair = address(new MockUniswapPair(srcToken, dstToken));

        // Create a mock curve pair that will be used in the unoswap test
        mockCurvePair = address(new MockCurvePair(dstToken));

        // Create a mock router for testing
        mockRouter = makeAddr("mockRouter");

        hook = new Swap1InchHook(mockRouter);
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(hook.aggregationRouter()), mockRouter);
    }

    function test_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(Swap1InchHook.ZERO_ADDRESS.selector);
        new Swap1InchHook(address(0));
    }

    function test_Build_GenericSwap_MsgValueZeroWhenUsePrevHookAmount() public view {
        address account = address(this);

        // 1.  Craft a SwapDescription that *expects* native ETH in .amount
        //     (we set amount = 0 because the hook will overwrite it with prevHook.getOutAmount(address(this)))
        address NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        I1InchAggregationRouterV6.SwapDescription memory desc = I1InchAggregationRouterV6.SwapDescription({
            srcToken: IERC20(NATIVE), // swapping native coin
            dstToken: IERC20(dstToken), // receive some ERC-20
            srcReceiver: payable(account),
            dstReceiver: payable(account),
            amount: 0, // will be overridden
            minReturnAmount: 1,
            flags: 0 // no partial fill
         });

        // 2.  Pack the 1inch `swap()` calldata
        bytes memory swapCalldata = abi.encode(
            address(0), // executor (ignored)
            desc,
            bytes(""), // permit
            bytes("") // extra data
        );
        bytes memory callData = abi.encodePacked(I1InchAggregationRouterV6.swap.selector, swapCalldata);

        // 3.  Full hook payload: [dstToken][dstReceiver][value=0][usePrev=1][callData]
        bytes memory hookData = abi.encodePacked(
            bytes20(dstToken), // dstToken (an ERC-20)
            bytes20(account), // dstReceiver
            uint256(1), //  static “value” field is ZERO (the bug)
            bytes1(0x01), // usePrevHookAmount = true
            callData
        );

        // 4.  Call build(); this contract itself acts as the previous hook and returns 1_000
        Execution[] memory execs = hook.build(address(this), account, hookData);

        // 5.  Assertions – test passes and demonstrates the bug
        assertEq(execs.length, 3, "should emit exactly one Execution");
        assertEq(execs[1].value, 1000, "value is zero even though usePrevHookAmount == true (should be 1_000)");
    }

    function test_decodeUsePrevHookAmount() public view {
        bytes memory hookData = _buildCurveHookData(0, false, dstReceiver, 1000, 100, false);
        assertEq(hook.decodeUsePrevHookAmount(hookData), false);

        hookData = _buildCurveHookData(0, false, dstReceiver, 1000, 100, true);
        assertEq(hook.decodeUsePrevHookAmount(hookData), true);
    }

    function test_Build_RevertIf_CalldataIsNotValid() public {
        bytes memory data = abi.encodePacked(dstToken, dstReceiver, value, false, bytes4(0xaaaaaaaa));
        vm.expectRevert(Swap1InchHook.INVALID_SELECTOR.selector);
        hook.build(address(0), address(this), data);
    }

    function test_Build_Unoswap_Uniswap() public {
        address account = address(this);

        bytes memory hookData = _buildUnoswapUniswap(dstReceiver, srcToken, 1000, 100);
        vm.mockCall(mockPair, abi.encodeWithSignature("token0()"), abi.encode(srcToken));
        vm.mockCall(mockPair, abi.encodeWithSignature("token1()"), abi.encode(dstToken));

        Execution[] memory executions = hook.build(address(0), account, hookData);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);

        vm.mockCall(mockPair, abi.encodeWithSignature("token0()"), abi.encode(dstToken));
        vm.mockCall(mockPair, abi.encodeWithSignature("token1()"), abi.encode(srcToken));
        hook.build(address(0), account, hookData);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);
    }

    function test_Build_Unoswap_Curve() public {
        uint8 selectorOffset = 0;
        address account = address(this);

        bytes memory hookData = _buildCurveHookData(selectorOffset, false, dstReceiver, 1000, 100, false);
        Execution[] memory executions = hook.build(address(0), account, hookData);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);
        assertEq(executions[1].value, 0);

        selectorOffset = 4;
        hookData = _buildCurveHookData(selectorOffset, false, dstReceiver, 1000, 100, false);
        executions = hook.build(address(0), account, hookData);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);
        assertEq(executions[1].value, 0);

        selectorOffset = 8;
        hookData = _buildCurveHookData(selectorOffset, false, dstReceiver, 1000, 100, false);
        executions = hook.build(address(0), account, hookData);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);
        assertEq(executions[1].value, 0);

        selectorOffset = 12;
        hookData = _buildCurveHookData(selectorOffset, false, dstReceiver, 1000, 100, false);
        executions = hook.build(address(0), account, hookData);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);
        assertEq(executions[1].value, 0);

        selectorOffset = 16;
        hookData = _buildCurveHookData(selectorOffset, false, dstReceiver, 1000, 100, false);
        executions = hook.build(address(0), account, hookData);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);
        assertEq(executions[1].value, 0);

        selectorOffset = 16;
        hookData = _buildCurveHookData(selectorOffset, false, dstReceiver, 1000, 100, true);
        executions = hook.build(address(this), account, hookData);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);
        assertEq(executions[1].value, 0);

        selectorOffset = 16;
        hookData = _buildCurveHookData(selectorOffset, true, dstReceiver, 1000, 100, false);
        vm.expectRevert(Swap1InchHook.INVALID_DESTINATION_TOKEN.selector);
        executions = hook.build(address(0), account, hookData);

        selectorOffset = 0;
        hookData = _buildCurveHookData(selectorOffset, false, address(this), 1000, 100, false);
        vm.expectRevert(Swap1InchHook.INVALID_RECEIVER.selector);
        executions = hook.build(address(0), account, hookData);

        selectorOffset = 0;
        hookData = _buildCurveHookData(selectorOffset, false, dstReceiver, 1000, 0, false);
        vm.expectRevert(Swap1InchHook.INVALID_OUTPUT_AMOUNT.selector);
        executions = hook.build(address(0), account, hookData);

        selectorOffset = 0;
        hookData = _buildCurveHookData(selectorOffset, false, dstReceiver, 0, 100, false);
        vm.expectRevert(Swap1InchHook.INVALID_INPUT_AMOUNT.selector);
        executions = hook.build(address(0), account, hookData);
    }

    function test_UnoSwap_inspect() public view {
        bytes memory data = _buildCurveHookData(0, false, dstReceiver, 1000, 100, false);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_PreExecute() public {
        MockERC20 token = new MockERC20("Test Token", "TT", 18);
        token.mint(dstReceiver, 500);

        bytes memory data = abi.encodePacked(address(token), dstReceiver, uint256(0));

        hook.preExecute(address(0), address(this), data);

        assertEq(hook.getOutAmount(address(this)), 500);
    }

    function test_PostExecute() public {
        MockERC20 token = new MockERC20("Test Token", "TT", 18);
        token.mint(dstReceiver, 500);

        bytes memory data = abi.encodePacked(address(token), dstReceiver, uint256(0));

        hook.preExecute(address(0), address(this), data);

        token.mint(dstReceiver, 300);

        hook.postExecute(address(0), address(this), data);

        assertEq(hook.getOutAmount(address(this)), 300);
    }

    function test_Build_Swap() public {
        address account = address(this);
        bytes memory hookData = _buildGenericSwapData(0, dstToken, dstReceiver, 1000, 100, false);
        Execution[] memory executions = hook.build(address(0), account, hookData);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);

        hookData = _buildGenericSwapData(0, dstToken, dstReceiver, 0, 100, false);
        vm.expectRevert(Swap1InchHook.INVALID_INPUT_AMOUNT.selector);
        executions = hook.build(address(0), account, hookData);

        hookData = _buildGenericSwapData(0, dstToken, dstReceiver, 1000, 0, false);
        vm.expectRevert(Swap1InchHook.INVALID_OUTPUT_AMOUNT.selector);
        executions = hook.build(address(0), account, hookData);

        hookData = _buildGenericSwapData(0, dstToken, address(this), 1000, 100, false);
        vm.expectRevert(Swap1InchHook.INVALID_RECEIVER.selector);
        executions = hook.build(address(0), account, hookData);

        hookData = _buildGenericSwapData(0, address(this), dstReceiver, 1000, 100, false);
        vm.expectRevert(Swap1InchHook.INVALID_DESTINATION_TOKEN.selector);
        executions = hook.build(address(0), account, hookData);

        hookData = _buildGenericSwapData(1, dstToken, dstReceiver, 1000, 100, false);
        vm.expectRevert(Swap1InchHook.PARTIAL_FILL_NOT_ALLOWED.selector);
        executions = hook.build(address(0), account, hookData);

        hookData = _buildGenericSwapData(0, dstToken, dstReceiver, 1000, 100, true);
        executions = hook.build(address(this), account, hookData);
    }

    function test_GenericSwap_inspect() public view {
        bytes memory data = _buildGenericSwapData(0, dstToken, dstReceiver, 1000, 100, false);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_Build_ClipperSwap() public {
        address account = address(this);

        bytes memory hookData = _buildClipperData(1000, 100, dstReceiver, dstToken, false);
        Execution[] memory executions = hook.build(address(0), account, hookData);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);

        hookData = _buildClipperData(0, 100, dstReceiver, dstToken, false);
        vm.expectRevert(Swap1InchHook.INVALID_INPUT_AMOUNT.selector);
        hook.build(address(0), account, hookData);

        hookData = _buildClipperData(1000, 0, dstReceiver, dstToken, false);
        vm.expectRevert(Swap1InchHook.INVALID_OUTPUT_AMOUNT.selector);
        hook.build(address(0), account, hookData);

        hookData = _buildClipperData(1000, 100, dstReceiver, address(this), false);
        vm.expectRevert(Swap1InchHook.INVALID_DESTINATION_TOKEN.selector);
        hook.build(address(0), account, hookData);

        hookData = _buildClipperData(1000, 100, dstReceiver, dstToken, true);
        executions = hook.build(address(this), account, hookData);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockRouter);
    }

    function test_ClipperSwap_inspect() public view {
        bytes memory data = _buildClipperData(1000, 100, dstReceiver, dstToken, false);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_inspect_invalidSelector() public {
        bytes memory data = _buildInvalidData(1000, 100, dstReceiver, dstToken, false);
        vm.expectRevert(Swap1InchHook.INVALID_SELECTOR.selector);
        hook.inspect(data);
    }

    function _buildInvalidData(
        uint256 _amount,
        uint256 _minAmount,
        address _dstReceiver,
        address _dstToken,
        bool usePrev
    )
        private
        view
        returns (bytes memory)
    {
        bytes memory clipperData = abi.encode(
            address(0), // exchange
            _dstReceiver, // receiver
            bytes32(0), // srcToken
            IERC20(_dstToken), // dstToken
            _amount, // amount
            _minAmount, // minReturnAmount
            0, // goodUntil
            bytes32(0), // bytes32 r,
            bytes32(0) // bytes32 vs
        );
        bytes4 selector = bytes4(0);
        bytes memory callData = abi.encodePacked(selector, clipperData);
        return abi.encodePacked(dstToken, dstReceiver, value, usePrev, callData);
    }

    function _buildClipperData(
        uint256 _amount,
        uint256 _minAmount,
        address _dstReceiver,
        address _dstToken,
        bool usePrev
    )
        private
        view
        returns (bytes memory)
    {
        bytes memory clipperData = abi.encode(
            address(0), // exchange
            _dstReceiver, // receiver
            bytes32(0), // srcToken
            IERC20(_dstToken), // dstToken
            _amount, // amount
            _minAmount, // minReturnAmount
            0, // goodUntil
            bytes32(0), // bytes32 r,
            bytes32(0) // bytes32 vs
        );
        bytes4 selector = I1InchAggregationRouterV6.clipperSwapTo.selector;
        bytes memory callData = abi.encodePacked(selector, clipperData);
        return abi.encodePacked(dstToken, dstReceiver, value, usePrev, callData);
    }

    function _buildInvalidSelectorData() private view returns (bytes memory) {
        bytes memory clipperData = abi.encode(
            address(0), // exchange
            dstReceiver, // receiver
            bytes32(0), // srcToken
            IERC20(dstToken), // dstToken
            1000, // amount
            100, // minReturnAmount
            0, // goodUntil
            bytes32(0), // bytes32 r,
            bytes32(0) // bytes32 vs
        );
        bytes4 selector = I1InchAggregationRouterV6.clipperSwapTo.selector;
        bytes memory callData = abi.encodePacked(selector, clipperData);
        return abi.encodePacked(dstToken, dstReceiver, value, false, callData);
    }

    function getOutAmount(address) external pure returns (uint256) {
        return 1000;
    }

    // Swap1InchHook.t.sol
    function testOrion_IncorrectOutAmountForGenericSwaps() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY));

        // Deploy hook
        Swap1InchHook testHook = new Swap1InchHook(mockRouter);

        address payable destinationReceiver = payable(address(0));
        Executor executor = new Executor();
        // We configure destination receiver to be address(0), signaling 1inch that swap receiver should
        // be msg.sender.
        address AGGREGATION_ROUTER = 0x111111125421cA6dc452d289314280a0f8842A65;
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        deal(USDC, address(this), 100e6); // deal USDC tokens to this contract
        deal(DAI, address(executor), 100e18); // deal DAI tokens to executor

        IERC20(USDC).approve(AGGREGATION_ROUTER, type(uint256).max);

        I1InchAggregationRouterV6.SwapDescription memory desc = I1InchAggregationRouterV6.SwapDescription({
            srcToken: IERC20(USDC), // USDC
            dstToken: IERC20(DAI), // DAI
            srcReceiver: payable(this),
            dstReceiver: destinationReceiver,
            amount: 10e6,
            minReturnAmount: 1, // avoid revert due to 0 amount
            flags: 0
        });
        bytes memory swapData = abi.encode(
            address(executor), // executor
            desc,
            bytes(""), // permit
            bytes("") // data
        );

        bytes4 selector = I1InchAggregationRouterV6.swap.selector;
        bytes memory callData = abi.encodePacked(selector, swapData);
        bytes memory hookData = abi.encodePacked(IERC20(DAI), destinationReceiver, uint256(0), false, callData);

        // Trigger preexecute
        testHook.preExecute(address(0), address(this), hookData);

        uint256 accountBalanceBeforeExecution = IERC20(DAI).balanceOf(address(this));

        // Mimic hook execution by performing a swap. This swap will transfer 100e18 dai to the receiver.
        // Note that we set the dstReceiver to address(0) in the `desc` data. However, 1inch will detect
        // this and transfer tokens to the caller, in this case this contract (which acts as the account).
        bytes memory data;
        I1InchAggregationRouterV6(AGGREGATION_ROUTER).swap(IAggregationExecutor(address(executor)), desc, data);

        // Trigger postexecute to see outAmount
        testHook.postExecute(address(0), address(this), hookData);

        // Outcome: Although the account actually obtained the tokens, the `outAmount` does not reflect that, as it
        // queried
        // the balance of address(0).
        // not anymore after the fix ->
        assertEq(testHook.getOutAmount(address(this)), 100e18);
        assertEq(IERC20(DAI).balanceOf(address(this)) - accountBalanceBeforeExecution, 100e18);
    }

    //----------- PRIVATE ------------
    function _encodeAddressWithProtocol(
        address actualAddress,
        uint8 selectorOffset,
        uint8 dstTokenIndex,
        bool unwrapWeth
    )
        internal
        pure
        returns (Address)
    {
        uint256 result = uint256(uint160(actualAddress)); // Put base address in low 160 bits

        // Set Curve protocol (value = 2) in bits 253–255
        result |= uint256(ProtocolLib.Protocol.Curve) << 253;

        // Set dstTokenIndex in bits 216–223
        result |= uint256(dstTokenIndex) << 216;

        // Set selectorOffset in bits 208–215
        result |= uint256(selectorOffset) << 208;

        // Set WETH_UNWRAP_FLAG (bit 252) if requested
        if (unwrapWeth) {
            result |= 1 << 252;
        }

        return Address.wrap(result);
    }

    function _buildCurveHookData(
        uint8 selectorOffset,
        bool unwrapWeth,
        address _swapReceiver,
        uint256 amount,
        uint256 minAmount,
        bool usePrev
    )
        private
        view
        returns (bytes memory)
    {
        uint8 dstTokenIndex = 0;
        Address dex = _encodeAddressWithProtocol(mockCurvePair, selectorOffset, dstTokenIndex, unwrapWeth);
        bytes memory unoswapData = abi.encode(
            _swapReceiver, // receiver
            srcToken, // fromToken
            amount, // amount
            minAmount, // minReturn
            dex // dex (uniswap pair)
        );

        bytes4 selector = I1InchAggregationRouterV6.unoswapTo.selector;
        bytes memory callData = abi.encodePacked(selector, unoswapData);
        return abi.encodePacked(dstToken, dstReceiver, uint256(0), usePrev, callData);
    }

    function _buildUnoswapUniswap(
        address _dstReceiver,
        address _srcToken,
        uint256 _amount,
        uint256 _minAmount
    )
        private
        view
        returns (bytes memory)
    {
        bytes memory unoswapData = abi.encode(
            _dstReceiver, // receiver
            _srcToken, // fromToken
            _amount, // amount
            _minAmount, // minReturn
            mockPair // dex (uniswap pair)
        );

        bytes4 selector = I1InchAggregationRouterV6.unoswapTo.selector;
        bytes memory callData = abi.encodePacked(selector, unoswapData);
        return abi.encodePacked(dstToken, dstReceiver, uint256(0), false, callData);
    }

    function _buildGenericSwapData(
        uint256 _flags,
        address _dstToken,
        address _receiver,
        uint256 _amount,
        uint256 _minAmount,
        bool usePrev
    )
        private
        view
        returns (bytes memory)
    {
        I1InchAggregationRouterV6.SwapDescription memory desc = I1InchAggregationRouterV6.SwapDescription({
            srcToken: IERC20(srcToken),
            dstToken: IERC20(_dstToken),
            srcReceiver: payable(this),
            dstReceiver: payable(_receiver),
            amount: _amount,
            minReturnAmount: _minAmount,
            flags: _flags
        });
        bytes memory swapData = abi.encode(
            address(0), // executor
            desc,
            bytes(""), // permit
            bytes("") // data
        );
        bytes4 selector = I1InchAggregationRouterV6.swap.selector;
        bytes memory callData = abi.encodePacked(selector, swapData);
        return abi.encodePacked(dstToken, dstReceiver, uint256(0), usePrev, callData);
    }
}
