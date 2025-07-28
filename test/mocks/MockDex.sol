// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MockDex
/// @notice Mock DEX contract for testing swap functionality
/// @dev This contract simulates a DEX that can swap between any two tokens
contract MockDex {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Swap(
        address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error ZERO_AMOUNT();
    error SAME_TOKEN();
    error INSUFFICIENT_BALANCE();
    error TRANSFER_FAILED();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Mock balances for the DEX (simulates infinite liquidity)
    mapping(address => uint256) public mockBalances;

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        // Initialize with some mock balances for popular tokens
        // In a real DEX this would be actual liquidity
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap tokens on the mock DEX
    /// @param token0 Address of the input token (token to swap from)
    /// @param token1 Address of the output token (token to swap to)
    /// @param amount0 Amount of input token to swap
    /// @param amount1 Amount of output token to receive
    /// @dev The rate is determined off-chain and passed as amount1
    /// @dev The contract assumes it has sufficient balance of all tokens for swapping
    function swap(address token0, address token1, uint256 amount0, uint256 amount1) external payable {
        // Validation
        if (amount0 == 0 || amount1 == 0) revert ZERO_AMOUNT();
        if (token0 == token1) revert SAME_TOKEN();
        // Note: address(0) represents ETH, so it's valid for one token to be address(0)

        // Handle native ETH swaps
        if (token0 == address(0)) {
            // Swapping ETH for token
            if (msg.value != amount0) revert INSUFFICIENT_BALANCE();

            // Transfer output token to user
            IERC20(token1).safeTransfer(msg.sender, amount1);
        } else if (token1 == address(0)) {
            // Swapping token for ETH
            IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);

            // Transfer ETH to user
            (bool success,) = msg.sender.call{ value: amount1 }("");
            if (!success) revert TRANSFER_FAILED();
        } else {
            // Swapping token for token
            IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
            IERC20(token1).safeTransfer(msg.sender, amount1);
        }

        emit Swap(msg.sender, token0, token1, amount0, amount1);
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add mock liquidity to the DEX (for testing purposes)
    /// @param token Token address to add liquidity for
    /// @param amount Amount of tokens to add
    function addMockLiquidity(address token, uint256 amount) external payable {
        if (token == address(0)) {
            // Handle ETH
            require(msg.value == amount, "MockDex: ETH amount mismatch");
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        mockBalances[token] += amount;
    }

    /// @notice Withdraw tokens from the DEX (for testing purposes)
    /// @param token Token address to withdraw
    /// @param amount Amount to withdraw
    /// @param to Address to send tokens to
    function withdraw(address token, uint256 amount, address to) external {
        if (token == address(0)) {
            (bool success,) = to.call{ value: amount }("");
            if (!success) revert TRANSFER_FAILED();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
        mockBalances[token] -= amount;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get mock balance for a token
    /// @param token Token address
    /// @return balance Mock balance
    function getMockBalance(address token) external view returns (uint256 balance) {
        return mockBalances[token];
    }

    /// @notice Allow contract to receive ETH
    receive() external payable {
        mockBalances[address(0)] += msg.value;
    }
}
