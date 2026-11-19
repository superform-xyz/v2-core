// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title GyldDeliveryReceiver
/// @author Superform Labs
/// @notice One strategy's mailbox for Gyld deliveries. Gyld mints bond tokens and pays redemption cash HERE
///         (the receiver is the strategy's whitelisted withdrawal address and the `wallet_address` of every mint
///         order), never to the strategy directly. Nothing leaves except through `GyldInTransitRegistry`, which
///         sweeps exactly what a settle acknowledges into the strategy and shrinks the matching lot in the same
///         transaction.
/// @dev WHY A SEPARATE CONTRACT. An EARLIER DESIGN (not in this codebase any more) proved "the asset arrived" by
///      reading the strategy's wallet balance against a per-lot snapshot. That balance rises for many reasons (user deposits into the SuperVault above all), so a
///      compromised reconciler could point at a user deposit and erase a claim on Gyld while the money was
///      still at Gyld; and ordinary strategy outflows pushed the balance below any baseline and blocked honest
///      settles. Funds in this contract can only have come from Gyld (or a donation, which only ever reaches the
///      strategy anyway), so what the registry can sweep is an upper bound on what Gyld delivered. The oracle does
///      NOT count this balance: the open lot is still valued, and the sweep that moves the delivery into the
///      wallet closes the lot atomically, so nothing is ever counted twice.
/// @dev Deployed by the registry in `setDestinations`; the registry is the only caller. Deliberately has no owner,
///      no upgrade path and no other function: it is a vault with one key.
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
