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

// Superform
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
/// @title WithdrawRFLRHookV2
/// @author Superform Labs
/// @notice Withdraws all rFLR from RNat and receives WFLR. WARNING: 50% penalty applies
///         to any locked (unvested) portion. Only fully-vested rFLR is penalty-free.
/// @dev Calls IRNat.withdrawAll(true) to receive WFLR (wrapped FLR) instead of native FLR.
///      The penalty is enforced by the RNat contract and cannot be bypassed.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         uint8 acknowledge = BytesLib.toUint8(data, 52);
/// @notice         uint256 minOut = BytesLib.toUint256(data, 53);
contract WithdrawRFLRHookV2 is BaseHook, ISuperHookInflowOutflow {
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

    /// @dev Offset of the acknowledge byte in hook data (after 52-byte strategy header)
    uint256 private constant ACK_POSITION = 52;

    /// @dev Offset of the minOut uint256 in hook data (after 52-byte strategy header)
    uint256 private constant MIN_OUT_POSITION = 53;

    /// @dev Minimum data length required for the minOut field (52 header + 1 ack + 32 uint256)
    uint256 private constant MIN_DATA_LENGTH_WITH_MIN_OUT = 85;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address rNat_, address wflr_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
        if (rNat_ == address(0) || wflr_ == address(0)) revert ADDRESS_NOT_VALID();
        RNAT = rNat_;
        WFLR = wflr_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Withdraw RFLR V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Withdraws RFLR tokens from the Flare network";
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

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
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
        _setOutToken(asset, account);
    }
}
