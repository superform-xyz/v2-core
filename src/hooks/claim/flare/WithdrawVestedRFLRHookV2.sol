// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
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
/// @title WithdrawVestedRFLRHookV2
/// @author Superform Labs
/// @notice Withdraws only the vested (unlocked) rFLR from RNat as WFLR. No penalty applied.
/// @dev Uses IRNat.withdraw(amount, true) instead of withdrawAll to avoid the 50% burn on locked tokens.
///      The vested amount is computed as rNatBalance - lockedBalance via getBalancesOf().
///      Vesting is time-based (rolling 12-month linear per monthly allocation) and is not
///      manipulable by third parties.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         uint256 minOut_optional = BytesLib.toUint256(data, 52);
contract WithdrawVestedRFLRHookV2 is BaseHook, ISuperHookInflowOutflow {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when there is no vested rFLR to withdraw (rNatBalance <= lockedBalance)
    error NOTHING_TO_WITHDRAW();

    /// @notice Thrown when the WFLR delta is below the caller-specified minOut
    error SLIPPAGE_EXCEEDED();

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

    /// @dev Minimum data length required for the minOut field (52 header + 32 uint256)
    uint256 private constant MIN_DATA_LENGTH_WITH_MIN_OUT = 84;

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
        return "Withdraw Vested RFLR V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Withdraws vested RFLR tokens from the Flare network";
    }


    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        (, uint256 rNatBalance, uint256 lockedBalance) = IRNat(RNAT).getBalancesOf(account);

        if (rNatBalance <= lockedBalance) revert NOTHING_TO_WITHDRAW();

        uint256 vestedAmount = rNatBalance - lockedBalance;
        uint128 withdrawAmount = vestedAmount.toUint128();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: RNAT,
            value: 0,
            callData: abi.encodeCall(IRNat.withdraw, (withdrawAmount, true))
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
    function _preExecute(address, address account, bytes calldata) internal override {
        asset = WFLR;
        _setOutAmount(IERC20(WFLR).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    /// @dev outAmount is the WFLR delta (balance after minus balance before).
    ///      Enforces minOut slippage check if provided in hook data.
    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 currentBalance = IERC20(WFLR).balanceOf(account);
        uint256 preBalance = getOutAmount(account);
        uint256 delta = currentBalance > preBalance ? currentBalance - preBalance : 0;

        if (data.length >= MIN_DATA_LENGTH_WITH_MIN_OUT) {
            uint256 minOut = BytesLib.toUint256(data, 52);
            if (minOut > 0 && delta < minOut) revert SLIPPAGE_EXCEEDED();
        }

        _setOutAmount(delta, account);
        _setOutToken(asset, account);
    }
}
