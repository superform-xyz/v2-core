// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ISwapRouter02
/// @author Superform Labs
/// @notice The subset of Uniswap `SwapRouter02` the Everlong hooks accept inside `multicall`.
/// @dev The Everlong Router on Katana (0x42eF97FaE7AD46d98bAf99A0e505b43B7e1C00e9) is a verified, unmodified
///      v3-periphery `SwapRouter02` with WETH9 = vbETH (0xEE7D8BCFb72bC1880D0Cf19822eB0A2e6577aB62). The Swap API
///      returns `multicall(deadline, calls)`: exact-input V3 legs paying the router (`recipient == address(2)`), one
///      sweep/unwrap tail paying the user, and a trailing `refundETH` whenever ETH is involved on either side.
///      Router constants: `CONTRACT_BALANCE = 0`, `MSG_SENDER = address(1)`, `ADDRESS_THIS = address(2)`.
///      Rejected (never forwarded): the other `multicall` variants, `exactOutput*`, the V2 swaps, `pull`, `wrapETH`,
///      `selfPermit*`, the msg.sender-implicit sweep/unwrap variants, and the approve/position-manager surface.
interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice multicall(uint256,bytes[]) == 0x5ae401dc; reverts 'Transaction too old' past `deadline`
    function multicall(uint256 deadline, bytes[] calldata data) external payable returns (bytes[] memory results);

    /// @notice exactInputSingle((address,address,uint24,address,uint256,uint256,uint160)) == 0x04e45aaf
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    /// @notice exactInput((bytes,address,uint256,uint256)) == 0xb858183f
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    /// @notice sweepToken(address,uint256,address) == 0xdf2ab5bb
    function sweepToken(address token, uint256 amountMinimum, address recipient) external payable;

    /// @notice sweepTokenWithFee(address,uint256,address,uint256,address) == 0xe0e189a0
    /// @dev `amountMinimum` is checked BEFORE the fee; recipient gets balance x (1 - feeBips/10_000); 0 < feeBips <=
    /// 100
    function sweepTokenWithFee(
        address token,
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    )
        external
        payable;

    /// @notice unwrapWETH9(uint256,address) == 0x49404b7c
    function unwrapWETH9(uint256 amountMinimum, address recipient) external payable;

    /// @notice unwrapWETH9WithFee(uint256,address,uint256,address) == 0x9b2c0a37; fee semantics as sweepTokenWithFee
    function unwrapWETH9WithFee(
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    )
        external
        payable;

    /// @notice refundETH() == 0x12210e8a; returns the router's ETH balance to msg.sender
    function refundETH() external payable;

    /// @notice The router's wrapped-native token (vbETH on Katana)
    function WETH9() external view returns (address);
}
