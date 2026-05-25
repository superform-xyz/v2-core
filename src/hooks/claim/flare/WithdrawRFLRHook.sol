// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IRNat } from "../../../vendor/flare/IRNat.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

/// @title WithdrawRFLRHook
/// @author Superform Labs
/// @notice Withdraws all rFLR from RNat and receives WFLR. WARNING: 50% penalty applies
///         to any locked (unvested) portion. Only fully-vested rFLR is penalty-free.
/// @dev Calls IRNat.withdrawAll(true) to receive WFLR (wrapped FLR) instead of native FLR.
///      The penalty is enforced by the RNat contract and cannot be bypassed.
///      data layout:
///        [0:1]   acknowledge byte — if non-zero AND lockedBalance > 0, caller explicitly
///                opts in to the locked-burn penalty (Variant B). Currently a no-op;
///                can be enabled by governance if curators need tighter protection.
///        [1:33]  uint256 minOut — minimum WFLR delta the caller will accept (Variant A).
///                If omitted (data.length < 33) or zero, no slippage check is enforced.
contract WithdrawRFLRHook is BaseHook {
    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the WFLR delta is below the caller-specified minOut
    error SLIPPAGE_EXCEEDED();

    /// @notice Thrown when the caller did not acknowledge the locked-burn penalty
    /// @dev Currently unused (Variant B is a no-op). Reserved for future activation.
    error UNVESTED_BURN_NOT_ACKNOWLEDGED();

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The IRNat contract
    address public immutable RNAT;

    /// @notice The WFLR (wrapped FLR) ERC-20 token
    address public immutable WFLR;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Offset of the acknowledge byte in hook data
    uint256 private constant ACK_POSITION = 0;

    /// @dev Offset of the minOut uint256 in hook data
    uint256 private constant MIN_OUT_POSITION = 1;

    /// @dev Minimum data length required for the minOut field (1 byte ack + 32 bytes uint256)
    uint256 private constant MIN_DATA_LENGTH_WITH_MIN_OUT = 33;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address rNat_, address wflr_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
        if (rNat_ == address(0) || wflr_ == address(0)) revert ADDRESS_NOT_VALID();
        RNAT = rNat_;
        WFLR = wflr_;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        executions = new Execution[](1);
        executions[0] = Execution({
            target: RNAT,
            value: 0,
            callData: abi.encodeCall(IRNat.withdrawAll, (true))
        });
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata) external view override returns (bytes memory) {
        return abi.encodePacked(RNAT);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev Snapshots the WFLR balance before withdrawal execution.
    ///      Variant B (locked-burn acknowledgment) check would go here if enabled.
    function _preExecute(address, address account, bytes calldata) internal override {
        asset = WFLR;
        _setOutAmount(IERC20(WFLR).balanceOf(account), account);

        // Variant B: locked-burn acknowledgment (NO-OP for now).
        // To enable, uncomment the following block:
        //
        // if (data.length >= 1) {
        //     (,, uint256 locked) = IRNat(RNAT).getBalancesOf(account);
        //     if (locked > 0) {
        //         bool ack = data[ACK_POSITION] != 0;
        //         if (!ack) revert UNVESTED_BURN_NOT_ACKNOWLEDGED();
        //     }
        // }
    }

    /// @inheritdoc BaseHook
    /// @dev outAmount is the WFLR delta (balance after withdrawal minus balance before withdrawal).
    ///      Enforces Variant A slippage check: if data contains a minOut, the delta must meet it.
    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 currentBalance = IERC20(WFLR).balanceOf(account);
        uint256 preBalance = getOutAmount(account);
        uint256 delta = currentBalance > preBalance ? currentBalance - preBalance : 0;

        // Variant A: minOut slippage check (active)
        if (data.length >= MIN_DATA_LENGTH_WITH_MIN_OUT) {
            uint256 minOut = BytesLib.toUint256(data, MIN_OUT_POSITION);
            if (minOut > 0 && delta < minOut) revert SLIPPAGE_EXCEEDED();
        }

        _setOutAmount(delta, account);
    }
}
