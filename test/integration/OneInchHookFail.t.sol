// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ISuperExecutor} from "../../src/core/interfaces/ISuperExecutor.sol";
import {UserOpData} from "modulekit/ModuleKit.sol";
import {MinimalBaseIntegrationTest} from "./MinimalBaseIntegrationTest.t.sol";
import {Address, AddressLib, ProtocolLib, I1InchAggregationRouterV6} from "../../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import {Swap1InchHook} from "../../src/core/hooks/swappers/1inch/Swap1InchHook.sol";

contract OneInchHookFail is MinimalBaseIntegrationTest {
    using AddressLib for Address;
    using ProtocolLib for Address;

    I1InchAggregationRouterV6 oneInchRouter = I1InchAggregationRouterV6(ONE_INCH_ROUTER);
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    //https://app.uniswap.org/explore/pools/ethereum/0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5
    address poolUniV2 = address(0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5);

    uint256 amount = uint256(1000 * 10**6);

    function setUp() public override {
        blockNumber = ETH_BLOCK;

        super.setUp();

        _getTokens(address(usdc), accountEth, amount);
    }

    function test_1InchHookSwapPass() public {
        //stake hook
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = address(new Swap1InchHook(address(oneInchRouter)));
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(usdc), address(oneInchRouter), amount, false);
        bytes memory unoswapData = abi.encode(
            accountEth, // receiver
            address(usdc), // fromToken
            uint256(amount), // amount
            uint256(1), // minReturn
            address(poolUniV2) // dex (uniswap pair)
        );

        bytes4 selector = I1InchAggregationRouterV6.unoswapTo.selector;
        bytes memory callData = abi.encodePacked(selector, unoswapData);
        hooksData[1] = abi.encodePacked(
            address(dai), 
            accountEth, 
            uint256(0), 
            false, //use prev hook
            callData
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({hooksAddresses: hooksAddresses, hooksData: hooksData});
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
        assertGt(dai.balanceOf(accountEth), 0);
    }

    function test_1InchHookSwapFail_DoesNotRevertAnymore() public {
        //stake hook
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = approveHook;
        hooksAddresses[1] = address(new Swap1InchHook(address(oneInchRouter)));
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = _createApproveHookData(address(usdc), address(oneInchRouter), amount, false);
        bytes memory unoswapData = abi.encode(
            accountEth, // receiver
            address(usdc), // fromToken
            uint256(amount), // amount
            uint256(1), // minReturn
            address(poolUniV2) // dex (uniswap pair)
        );

        bytes4 selector = I1InchAggregationRouterV6.unoswapTo.selector;
        bytes memory callData = abi.encodePacked(selector, unoswapData);
        hooksData[1] = abi.encodePacked(
            address(dai), 
            accountEth, 
            uint256(0), 
            true, //use prev hook
            callData
        );
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({hooksAddresses: hooksAddresses, hooksData: hooksData});
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(userOpData);
    }

}
