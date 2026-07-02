// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SwapKyberSwapHook } from "../../../src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol";
import {
    ApproveAndSwapKyberSwapHook
} from "../../../src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol";
import { IMetaAggregationRouterV2 } from "../../../src/vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { Constants } from "../../utils/Constants.sol";

import "forge-std/console2.sol";

/// @title KyberSwapBaseNativeTest
/// @notice Regression test on Base fork: NATIVE (0xEeee...eE) as outputToken must track ETH balance correctly.
///         Previously reverted when address(0) was used as the native ETH sentinel.
/// @dev Requires BASE_RPC_URL environment variable
contract KyberSwapBaseNativeTest is Test, Constants {
    SwapKyberSwapHook public swapHook;
    ApproveAndSwapKyberSwapHook public approveAndSwapHook;

    // KyberSwap contracts — same address on Base as Ethereum
    address public constant KYBER_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    address public constant SCALE_HELPER = 0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant USDC = CHAIN_8453_USDC;
    address public constant WETH = CHAIN_8453_WETH;

    address public account;

    receive() external payable { }

    function setUp() public {
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY));

        account = address(this);

        swapHook = new SwapKyberSwapHook(KYBER_ROUTER, SCALE_HELPER, NATIVE);
        approveAndSwapHook = new ApproveAndSwapKyberSwapHook(KYBER_ROUTER, SCALE_HELPER, NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

    function _executeAll(Execution[] memory executions) internal {
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success, bytes memory returndata) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) {
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
        }
    }

    function _buildKyberSwapTxData(
        address srcToken,
        address dstToken,
        uint256 amount,
        uint256 minReturn,
        address callTarget_,
        address approveTarget_
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = callTarget_;

        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = amount;

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(srcToken),
            dstToken: IERC20(dstToken),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: new address[](0),
            feeAmounts: new uint256[](0),
            dstReceiver: account,
            amount: amount,
            minReturnAmount: minReturn,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: callTarget_,
            approveTarget: approveTarget_,
            clientData: "",
            desc: desc,
            targetData: ""
        });

        return abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));
    }

    function _buildSwapHookData(
        address outputToken,
        uint256 value,
        uint256 inputAmount,
        uint256 outputMin,
        bool usePrevHookAmount,
        bytes memory txData_
    )
        internal
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            bytes32(0), // yieldSourceOracleId (52-byte header part 1)
            bytes20(address(0)), // yieldSource (52-byte header part 2)
            bytes20(outputToken),
            bytes32(value),
            bytes32(inputAmount),
            bytes32(outputMin),
            usePrevHookAmount ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(txData_.length),
            txData_
        );
    }

    function _buildApproveAndSwapHookData(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputMin,
        bool usePrevHookAmount,
        bytes memory txData_
    )
        internal
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            bytes32(0), // yieldSourceOracleId (52-byte header part 1)
            bytes20(address(0)), // yieldSource (52-byte header part 2)
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputMin),
            usePrevHookAmount ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(txData_.length),
            txData_
        );
    }

    /*//////////////////////////////////////////////////////////////
             NATIVE CONSTANT VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Hooks expose the correct NATIVE sentinel
    function test_NativeConstant() public view {
        assertEq(swapHook.NATIVE(), NATIVE);
        assertEq(approveAndSwapHook.NATIVE(), NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
             SWAP HOOK — NATIVE OUTPUT BALANCE TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice SwapHook: preExecute captures ETH balance when outputToken == NATIVE
    function test_SwapHook_PreExecute_NativeOutput_Base() public {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, NATIVE, 1000e6, 0, KYBER_ROUTER, KYBER_ROUTER);
        bytes memory hookData = _buildSwapHookData(NATIVE, 0, 1000e6, 0, false, txData_);

        vm.deal(account, 5 ether);

        swapHook.preExecute(address(0), account, hookData);
        assertEq(swapHook.getOutAmount(account), 5 ether, "preExecute should capture ETH balance");
    }

    /// @notice SwapHook: postExecute computes correct ETH delta when outputToken == NATIVE
    function test_SwapHook_PostExecute_NativeOutput_Base() public {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, NATIVE, 1000e6, 0, KYBER_ROUTER, KYBER_ROUTER);
        bytes memory hookData = _buildSwapHookData(NATIVE, 0, 1000e6, 0, false, txData_);

        vm.deal(account, 5 ether);
        swapHook.preExecute(address(0), account, hookData);

        // Simulate swap: account receives 0.3 ETH
        vm.deal(account, 5.3 ether);
        swapHook.postExecute(address(0), account, hookData);

        assertEq(swapHook.getOutAmount(account), 0.3 ether, "postExecute should track ETH delta");
    }

    /*//////////////////////////////////////////////////////////////
             APPROVE AND SWAP HOOK — NATIVE OUTPUT BALANCE TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice ApproveAndSwapHook: preExecute captures ETH balance when outputToken == NATIVE
    function test_ApproveAndSwapHook_PreExecute_NativeOutput_Base() public {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, NATIVE, 1000e6, 0, KYBER_ROUTER, KYBER_ROUTER);
        bytes memory hookData = _buildApproveAndSwapHookData(USDC, NATIVE, 1000e6, 0, false, txData_);

        vm.deal(account, 2 ether);

        approveAndSwapHook.preExecute(address(0), account, hookData);
        assertEq(approveAndSwapHook.getOutAmount(account), 2 ether, "preExecute should capture ETH balance");
    }

    /// @notice ApproveAndSwapHook: postExecute computes correct ETH delta when outputToken == NATIVE
    function test_ApproveAndSwapHook_PostExecute_NativeOutput_Base() public {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, NATIVE, 1000e6, 0, KYBER_ROUTER, KYBER_ROUTER);
        bytes memory hookData = _buildApproveAndSwapHookData(USDC, NATIVE, 1000e6, 0, false, txData_);

        vm.deal(account, 2 ether);
        approveAndSwapHook.preExecute(address(0), account, hookData);

        // Simulate swap: account receives 0.5 ETH
        vm.deal(account, 2.5 ether);
        approveAndSwapHook.postExecute(address(0), account, hookData);

        assertEq(approveAndSwapHook.getOutAmount(account), 0.5 ether, "postExecute should track ETH delta");
    }

    /*//////////////////////////////////////////////////////////////
             REGRESSION: address(0) MUST NOT MATCH NATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice With address(0) as outputToken, _getBalance tries IERC20(address(0)).balanceOf()
    ///         which reverts since there's no contract at address(0).
    ///         This is the regression case: before the fix, address(0) was treated as native ETH.
    function test_SwapHook_AddressZero_IsNotNative_Base() public {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, address(0), 1000e6, 0, KYBER_ROUTER, KYBER_ROUTER);
        bytes memory hookData = _buildSwapHookData(address(0), 0, 1000e6, 0, false, txData_);

        vm.deal(account, 10 ether);

        // address(0) is not NATIVE, so _getBalance calls IERC20(address(0)).balanceOf()
        // which reverts — confirming address(0) is NOT treated as native ETH
        vm.expectRevert();
        swapHook.preExecute(address(0), account, hookData);
    }

    /// @notice ApproveAndSwapHook: address(0) as outputToken should not be treated as native ETH
    function test_ApproveAndSwapHook_AddressZero_IsNotNative_Base() public {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, address(0), 1000e6, 0, KYBER_ROUTER, KYBER_ROUTER);
        bytes memory hookData = _buildApproveAndSwapHookData(USDC, address(0), 1000e6, 0, false, txData_);

        vm.deal(account, 10 ether);

        // address(0) is not NATIVE, so _getBalance calls IERC20(address(0)).balanceOf()
        // which reverts — confirming address(0) is NOT treated as native ETH
        vm.expectRevert();
        approveAndSwapHook.preExecute(address(0), account, hookData);
    }

    /*//////////////////////////////////////////////////////////////
             BUILD EXECUTION — NATIVE VALUE FORWARDING
    //////////////////////////////////////////////////////////////*/

    /// @notice SwapHook: when value > 0 and outputToken == NATIVE, execution forwards ETH
    function test_SwapHook_Build_NativeValueForwarded_Base() public view {
        uint256 ethAmount = 1 ether;
        bytes memory txData_ = _buildKyberSwapTxData(NATIVE, USDC, ethAmount, 1000e6, KYBER_ROUTER, KYBER_ROUTER);
        bytes memory hookData = _buildSwapHookData(USDC, ethAmount, ethAmount, 1000e6, false, txData_);

        Execution[] memory executions = swapHook.build(address(0), account, hookData);

        // executions[0] = preExecute, executions[1] = swap, executions[2] = postExecute
        assertEq(executions[1].value, ethAmount, "swap execution should forward ETH value");
        assertEq(executions[1].target, KYBER_ROUTER, "swap should target KyberSwap router");
    }
}
