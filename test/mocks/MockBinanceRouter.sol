// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MockERC20 } from "./MockERC20.sol";

/// @title MockBinanceRouter
/// @notice Scriptable stand-in for the Binance DEX router (a selector-dispatch diamond that accepts
///         arbitrary calldata). Every call lands in `fallback()` and runs the configured behaviour.
/// @dev Doubles as the adversarial harness: `vm.etch` its runtime code at the pinned router on a
///      fork, then call the setters on the etched address (etch copies code only, not storage).
contract MockBinanceRouter {
    enum Mode {
        HONEST, // pull amountToPull, send amountToSend to caller
        NO_OUTPUT, // pull, send nothing
        SEND_TO_THIRD_PARTY, // pull, send output to `thirdParty`
        PULL_MORE_THAN_APPROVED, // pull `overPull` (expected to exceed the allowance)
        PULL_SECOND_TOKEN, // honest, plus pull `secondAmount` of `secondToken`
        BURN_OUTPUT, // honest, then burn `burnAmount` of tokenOut from the caller (MockERC20.burn)
        RETURNDATA_BOMB, // honest, then return `bombSize` bytes
        REVERT, // revert with a reason
        PARTIAL_FILL, // pull `partialPull` (< allowance), send amountToSend — leaves residual allowance for
        // approve(0)
        REENTER_SET_CONTEXT, // honest, but first call `hook.setExecutionContext(caller)` — rotates the hook's context
        REENTER_SET_OUT_AMOUNT // honest, but first call `hook.setOutAmount(0, caller)` — forges the snapshot
    }

    Mode public mode;
    /// @dev Hook under attack for the REENTER_* modes.
    address public hook;
    uint256 public partialPull;

    address public tokenIn;
    uint256 public amountToPull;
    address public tokenOut;
    uint256 public amountToSend;

    address public thirdParty;
    uint256 public overPull;
    address public secondToken;
    uint256 public secondAmount;
    uint256 public burnAmount;
    uint256 public bombSize;

    uint256 public calls;
    bytes4 public lastSelector;

    function configure(address tokenIn_, uint256 amountToPull_, address tokenOut_, uint256 amountToSend_) external {
        tokenIn = tokenIn_;
        amountToPull = amountToPull_;
        tokenOut = tokenOut_;
        amountToSend = amountToSend_;
    }

    function setMode(Mode mode_) external {
        mode = mode_;
    }

    function setThirdParty(address thirdParty_) external {
        thirdParty = thirdParty_;
    }

    function setOverPull(uint256 overPull_) external {
        overPull = overPull_;
    }

    function setSecondToken(address secondToken_, uint256 secondAmount_) external {
        secondToken = secondToken_;
        secondAmount = secondAmount_;
    }

    function setBurnAmount(uint256 burnAmount_) external {
        burnAmount = burnAmount_;
    }

    function setBombSize(uint256 bombSize_) external {
        bombSize = bombSize_;
    }

    function setHook(address hook_) external {
        hook = hook_;
    }

    function setPartialPull(uint256 partialPull_) external {
        partialPull = partialPull_;
    }

    receive() external payable { }

    fallback() external payable {
        calls++;
        if (msg.data.length >= 4) lastSelector = bytes4(msg.data[:4]);

        Mode m = mode;
        if (m == Mode.REVERT) revert("MockBinanceRouter: scripted revert");

        // Malicious facet: reenter the hook before touching any token. `setExecutionContext` is
        // permissionless and advances the hook's context nonce; `setOutAmount` tries to forge the snapshot.
        if (m == Mode.REENTER_SET_CONTEXT) {
            (bool ok,) = hook.call(abi.encodeWithSignature("setExecutionContext(address)", msg.sender));
            require(ok, "MockBinanceRouter: setExecutionContext reverted");
        } else if (m == Mode.REENTER_SET_OUT_AMOUNT) {
            (bool ok, bytes memory ret) =
                hook.call(abi.encodeWithSignature("setOutAmount(uint256,address)", uint256(0), msg.sender));
            if (!ok) {
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }

        uint256 pull =
            m == Mode.PULL_MORE_THAN_APPROVED ? overPull : (m == Mode.PARTIAL_FILL ? partialPull : amountToPull);
        if (pull != 0) IERC20(tokenIn).transferFrom(msg.sender, address(this), pull);

        if (m == Mode.PULL_SECOND_TOKEN && secondAmount != 0) {
            IERC20(secondToken).transferFrom(msg.sender, address(this), secondAmount);
        }

        if (m == Mode.NO_OUTPUT) return;

        address recipient = m == Mode.SEND_TO_THIRD_PARTY ? thirdParty : msg.sender;
        if (amountToSend != 0) IERC20(tokenOut).transfer(recipient, amountToSend);

        if (m == Mode.BURN_OUTPUT && burnAmount != 0) {
            MockERC20(tokenOut).burn(msg.sender, burnAmount);
        }

        if (m == Mode.RETURNDATA_BOMB) {
            uint256 size = bombSize;
            assembly {
                let ptr := mload(0x40)
                return(ptr, size)
            }
        }
    }
}
