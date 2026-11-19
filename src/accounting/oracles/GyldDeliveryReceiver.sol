// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title GyldDeliveryReceiver
/// @author Superform Labs
/// @notice One strategy's mailbox for Gyld deliveries: its whitelisted withdrawal address and the `wallet_address`
///         of its mint orders. Only `GyldInTransitRegistry` can move funds out, and only into the strategy, as the
///         sweep of a settle that shrinks the matching lot in the same transaction.
/// @dev Funds here can only have come from Gyld (or a donation that ends in the strategy anyway), so the balance is
///      an upper bound on what Gyld delivered, and the oracle never values it: no delivery is counted twice.
///      Deployed by the registry with the strategy's destinations; no owner, no upgrade path, one function.
contract GyldDeliveryReceiver {
    using SafeERC20 for IERC20;

    error ONLY_REGISTRY();
    error ZERO_ADDRESS();

    /// @notice The in-transit registry that created this receiver and alone may move funds out of it
    address public immutable REGISTRY;
    /// @notice The strategy every sweep pays
    address public immutable STRATEGY;

    constructor(address strategy_) {
        if (strategy_ == address(0)) revert ZERO_ADDRESS();
        REGISTRY = msg.sender;
        STRATEGY = strategy_;
    }

    /// @notice Move `amount` of `token` to the strategy. Registry only; the registry calls it from a settle.
    function sweep(address token, uint256 amount) external {
        if (msg.sender != REGISTRY) revert ONLY_REGISTRY();
        IERC20(token).safeTransfer(STRATEGY, amount);
    }

    /// @notice What Gyld has delivered here and no settle has acknowledged yet
    function balance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
