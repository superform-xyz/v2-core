// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "../MockERC20.sol";

/// @notice Gyld settlement stand-in. Deliberately configurable to misbehave, because the hook's whole job is
///         to survive a venue that does the wrong thing: over-pulling, seizing, under-delivering, delivering
///         nothing, or honouring a replayed quote.
contract MockGyldSettlement {
    error QUOTE_ALREADY_USED();
    error QUOTE_EXPIRED_AT_VENUE();
    error TAKER_MISMATCH();
    error VENUE_PAUSED();

    bool public paused;
    mapping(bytes32 quoteId => bool used) public quoteUsed;

    /// @dev Pull more input than the quote says via `transferFrom`. Should fail on the hook's scoped allowance.
    uint256 public overPullBps;
    /// @dev Destroy extra input straight out of the taker's balance, the way an issuer with seize or burn
    ///      powers could. This is the route that reaches `INPUT_OVERSPENT`, since the hook's scoped approval
    ///      makes the `transferFrom` route unreachable.
    uint256 public seizeExtra;
    /// @dev Deliver less output than the quote says
    uint256 public underDeliverBps;
    /// @dev Take the input and deliver nothing at all, without reverting
    bool public deliverNothing;
    /// @dev Honour a replayed quote id instead of rejecting it (requirement R1 violated)
    bool public allowReplay;

    function setPaused(bool v) external {
        paused = v;
    }

    function setOverPullBps(uint256 v) external {
        overPullBps = v;
    }

    function setSeizeExtra(uint256 v) external {
        seizeExtra = v;
    }

    function setUnderDeliverBps(uint256 v) external {
        underDeliverBps = v;
    }

    function setDeliverNothing(bool v) external {
        deliverNothing = v;
    }

    function setAllowReplay(bool v) external {
        allowReplay = v;
    }

    /// @notice The happy-path fill. `taker` is validated against `msg.sender`, which is requirement R2: the
    ///         payer and the recipient are the calling account, never an operator and never the hook.
    function fill(
        bytes32 quoteId,
        address taker,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 expiry
    )
        external
    {
        if (paused) revert VENUE_PAUSED();
        if (!allowReplay && quoteUsed[quoteId]) revert QUOTE_ALREADY_USED();
        if (block.timestamp > expiry) revert QUOTE_EXPIRED_AT_VENUE();
        if (taker != msg.sender) revert TAKER_MISMATCH();
        quoteUsed[quoteId] = true;

        uint256 pull = inputAmount + (inputAmount * overPullBps) / 10_000;
        IERC20(inputToken).transferFrom(msg.sender, address(this), pull);
        if (seizeExtra != 0) MockERC20(inputToken).burn(msg.sender, seizeExtra);

        if (deliverNothing) return;

        uint256 deliver = outputAmount - (outputAmount * underDeliverBps) / 10_000;
        _deliver(outputToken, deliver);
    }

    /// @dev Inventory first, mint as a fallback. A real token's `mint` is permissioned, so a fork test funds
    ///      this venue and the output is transferred; a unit test against `MockERC20` funds nothing and the
    ///      mint path stands in for the venue's book.
    function _deliver(address outputToken, uint256 amount) private {
        if (IERC20(outputToken).balanceOf(address(this)) >= amount) {
            IERC20(outputToken).transfer(msg.sender, amount);
        } else {
            MockERC20(outputToken).mint(msg.sender, amount);
        }
    }

    /// @notice Encodes a `fill` call the hook forwards verbatim as opaque venue calldata
    function encodeFill(
        bytes32 quoteId,
        address taker,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 expiry
    )
        external
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            MockGyldSettlement.fill, (quoteId, taker, inputToken, outputToken, inputAmount, outputAmount, expiry)
        );
    }
}
