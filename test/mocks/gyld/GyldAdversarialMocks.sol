// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "../MockERC20.sol";

/*//////////////////////////////////////////////////////////////
                            FEEDS
//////////////////////////////////////////////////////////////*/

/// @notice A feed that reverts on every read, the way a paused aggregator or a proxy pointed at a dead
///         implementation would. Used to probe whether reads documented as total really are.
contract MockRevertingFeed {
    error FEED_DEAD();

    bool public revertOnDecimals;

    function setRevertOnDecimals(bool v) external {
        revertOnDecimals = v;
    }

    function latestRoundData() external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert FEED_DEAD();
    }

    function latestNav(address) external pure returns (uint256, uint256, uint256) {
        revert FEED_DEAD();
    }

    function decimals() external view returns (uint8) {
        if (revertOnDecimals) revert FEED_DEAD();
        return 8;
    }
}

/// @notice A feed that returns EMPTY returndata instead of reverting, which is what a staticcall to an
///         address with no code does. The decoder, not the callee, is what must notice.
contract MockEmptyReturnFeed {
    fallback() external {
        assembly {
            return(0, 0)
        }
    }
}

/// @notice A NAV feed reporting an answer large enough to overflow the conversion arithmetic
contract MockHugeNavFeed {
    uint8 public decimals = 8;

    function latestNav(address) external view returns (uint256, uint256, uint256) {
        return (type(uint256).max, block.timestamp, block.timestamp);
    }
}

/*//////////////////////////////////////////////////////////////
                            TOKENS
//////////////////////////////////////////////////////////////*/

/// @notice A token that charges the SENDER a tax on top of the transferred amount, so the sender's balance
///         falls by more than the amount moved. The recipient receives the full amount.
contract MockFeeOnTransferERC20 is ERC20 {
    uint256 public feeBps;
    uint8 private _decimals;

    constructor(uint8 decimals_, uint256 feeBps_) ERC20("FeeOnTransfer", "FOT") {
        _decimals = decimals_;
        feeBps = feeBps_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0) || feeBps == 0) {
            super._update(from, to, value);
            return;
        }
        uint256 fee = (value * feeBps) / 10_000;
        super._update(from, to, value);
        super._update(from, address(0), fee); // the tax is burned ON TOP: the sender loses value + fee
    }
}

/// @notice A token whose `decimals()` is absurd, so `10 ** decimals()` cannot fit in a uint256
contract MockAbsurdDecimalsERC20 {
    function decimals() external pure returns (uint8) {
        return 78;
    }
}

/// @notice A token whose `balanceOf` reverts
contract MockRevertingBalanceERC20 {
    error BALANCE_DEAD();

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function balanceOf(address) external pure returns (uint256) {
        revert BALANCE_DEAD();
    }

    function totalSupply() external pure returns (uint256) {
        revert BALANCE_DEAD();
    }
}

/*//////////////////////////////////////////////////////////////
                            VENUES
//////////////////////////////////////////////////////////////*/

/// @notice A settlement contract that reenters the hook's own lifecycle functions while filling, which is the
///         strongest thing a hostile venue can attempt: `setExecutionContext` is permissionless, and
///         `preExecute`/`postExecute` are callable by the account, which is exactly who is calling the venue.
contract MockReentrantGyldSettlement {
    enum Attack {
        NONE,
        ROTATE_CONTEXT,
        CALL_PRE_EXECUTE,
        CALL_POST_EXECUTE,
        RESET_EXECUTION_STATE
    }

    Attack public attack;
    address public hook;
    bytes public hookData;

    function configure(address hook_, Attack attack_, bytes calldata hookData_) external {
        hook = hook_;
        attack = attack_;
        hookData = hookData_;
    }

    function fill(
        bytes32,
        address taker,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256
    )
        external
    {
        IERC20(inputToken).transferFrom(msg.sender, address(this), inputAmount);

        if (attack == Attack.ROTATE_CONTEXT) {
            IHookLifecycle(hook).setExecutionContext(taker);
        } else if (attack == Attack.CALL_PRE_EXECUTE) {
            IHookLifecycle(hook).preExecute(address(0), taker, hookData);
        } else if (attack == Attack.CALL_POST_EXECUTE) {
            IHookLifecycle(hook).postExecute(address(0), taker, hookData);
        } else if (attack == Attack.RESET_EXECUTION_STATE) {
            IHookLifecycle(hook).resetExecutionState(taker);
        }

        MockERC20(outputToken).mint(msg.sender, outputAmount);
    }

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
            MockReentrantGyldSettlement.fill,
            (quoteId, taker, inputToken, outputToken, inputAmount, outputAmount, expiry)
        );
    }
}

/// @notice A settlement contract that also exposes a function having nothing to do with filling a quote.
/// @dev Exists to probe the blast radius of OPAQUE venue calldata: the hook forwards whatever bytes the leaf
///      carries to the pinned settlement address, as the account.
contract MockGyldSettlementWithExtraPowers {
    event Swept(address token, address to, uint256 amount);

    /// @notice Pulls an allowance the caller granted and sends it wherever the caller asks
    function sweep(address token, address to, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, to, amount);
        emit Swept(token, to, amount);
    }

    function fill(
        bytes32,
        address,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256
    )
        external
    {
        IERC20(inputToken).transferFrom(msg.sender, address(this), inputAmount);
        MockERC20(outputToken).mint(msg.sender, outputAmount);
    }

    function encodeSweep(address token, address to, uint256 amount) external pure returns (bytes memory) {
        return abi.encodeCall(MockGyldSettlementWithExtraPowers.sweep, (token, to, amount));
    }

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
            MockGyldSettlementWithExtraPowers.fill,
            (quoteId, taker, inputToken, outputToken, inputAmount, outputAmount, expiry)
        );
    }
}

/// @dev The slice of `BaseHook` a hostile venue could try to reach
interface IHookLifecycle {
    function setExecutionContext(address caller) external;
    function preExecute(address prevHook, address account, bytes calldata data) external;
    function postExecute(address prevHook, address account, bytes calldata data) external;
    function resetExecutionState(address caller) external;
}

/// @title MockVaultDepositingSettlement
/// @notice The R4-1 attack, as a venue: pull the input, hand it straight back by MINTING vault shares to
///         itself, and deliver dust.
/// @dev THE POINT. `validateFill` compares MEASURED balance deltas. `SuperVault.deposit` sends the asset
///      straight to the strategy and pays the depositor in shares, and it is reachable mid-leg because the
///      vault's `nonReentrant` is on the VAULT while `executeHooks` holds the STRATEGY's. So the measured
///      `inputSpent` collapses to dust and the realised-price floor becomes vacuous.
/// @dev This mock stands in for that by moving the share token's supply and returning the cash, which is
///      exactly what the real deposit does to the two things the hook observes. The hook's leg-scoped
///      commitment to `keccak256(vault, totalSupply())` is what must catch it.
contract MockVaultDepositingSettlement {
    MockERC20 public immutable VAULT_SHARES;
    uint256 public returnBps = 9999; // give back all but 1 bp of the input

    constructor(MockERC20 vaultShares_) {
        VAULT_SHARES = vaultShares_;
    }

    function setReturnBps(uint256 bps) external {
        returnBps = bps;
    }

    function fill(
        bytes32,
        address taker,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256
    )
        external
    {
        require(taker == msg.sender, "TAKER_MISMATCH");

        // 1. Pull the whole authorised input.
        IERC20(inputToken).transferFrom(msg.sender, address(this), inputAmount);

        // 2. Hand almost all of it back the way `SuperVault.deposit` would — asset to the strategy, shares
        //    minted to us. Supply moves, which is the tell.
        uint256 giveBack = (inputAmount * returnBps) / 10_000;
        IERC20(inputToken).transfer(msg.sender, giveBack);
        VAULT_SHARES.mint(address(this), giveBack);

        // 3. Deliver dust. Measured `inputSpent` is now `inputAmount - giveBack`, so without the
        //    commitment the floor computed from it is trivially satisfied.
        MockERC20(outputToken).mint(msg.sender, outputAmount / 1_000_000);
    }

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
        return abi.encodeWithSelector(
            this.fill.selector, quoteId, taker, inputToken, outputToken, inputAmount, outputAmount, expiry
        );
    }
}
