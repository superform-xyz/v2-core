// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPSM3 } from "../../src/vendor/spark/IPSM3.sol";

/// @title MockPSM3
/// @notice Mock PSM3 contract for testing Spark PSM hooks
/// @dev Simulates swapExactIn/swapExactOut by transferring tokens from/to the caller
contract MockPSM3 is IPSM3 {
    /// @notice Fixed output amount for swapExactIn (set by test)
    uint256 public exactInOutputAmount;

    /// @notice Fixed input amount consumed for swapExactOut (set by test)
    uint256 public exactOutInputAmount;

    /// @notice Toggle to force reverts
    bool public shouldRevert;

    /// @notice Set the output amount returned by swapExactIn
    function setExactInOutputAmount(uint256 amount_) external {
        exactInOutputAmount = amount_;
    }

    /// @notice Set the input amount consumed by swapExactOut
    function setExactOutInputAmount(uint256 amount_) external {
        exactOutInputAmount = amount_;
    }

    /// @notice Toggle revert behavior for DoS testing
    function setShouldRevert(bool shouldRevert_) external {
        shouldRevert = shouldRevert_;
    }

    /// @inheritdoc IPSM3
    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256,
        address receiver,
        uint256
    )
        external
        override
        returns (uint256 amountOut)
    {
        if (shouldRevert) revert("PSM3: revert");

        // Pull input tokens from caller (the smart account)
        IERC20(assetIn).transferFrom(msg.sender, address(this), amountIn);

        // Send output tokens to receiver
        amountOut = exactInOutputAmount;
        IERC20(assetOut).transfer(receiver, amountOut);
    }

    /// @inheritdoc IPSM3
    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256,
        address receiver,
        uint256
    )
        external
        override
        returns (uint256 amountIn)
    {
        if (shouldRevert) revert("PSM3: revert");

        // Pull input tokens from caller (variable amount <= maxAmountIn)
        amountIn = exactOutInputAmount;
        IERC20(assetIn).transferFrom(msg.sender, address(this), amountIn);

        // Send exact output tokens to receiver
        IERC20(assetOut).transfer(receiver, amountOut);
    }

    /// @inheritdoc IPSM3
    function previewSwapExactIn(address, address, uint256) external view override returns (uint256 amountOut) {
        return exactInOutputAmount;
    }

    /// @inheritdoc IPSM3
    function previewSwapExactOut(address, address, uint256) external view override returns (uint256 amountIn) {
        return exactOutInputAmount;
    }
}
