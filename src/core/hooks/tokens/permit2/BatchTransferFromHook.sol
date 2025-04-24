// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPermit2Batch } from "../../../../vendor/uniswap/permit2/IPermit2Batch.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAllowanceTransfer } from "../../../../vendor/uniswap/permit2/IAllowanceTransfer.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";

/// @title BatchTransferFromHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address from = BytesLib.toAddress(data, 0);
/// @notice         uint256 amount = BytesLib.toUint256(data, 20);
/// @notice         uint256 amountTokens = BytesLib.toUint256(data, 52);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
/// @notice         // ─── dynamic arrays ───────────────────────────────────────────────────
/// @notice         //  address[] tokens  — starts at byte 84, length = 20  * amountTokens
/// @notice         //  uint256[] amounts — starts at 84 + 20 * amountTokens,
/// @notice         //                         length = 32 * amountTokens
/// @notice         //  Each amounts[i] corresponds to tokens[i].
contract BatchTransferFromHook is BaseHook, ISuperHookContextAware {
    using SafeCast for uint256;

    error INSUFFICIENT_ALLOWANCE();
    error INSUFFICIENT_BALANCE();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public permit2;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 124;

    struct BuildHookVars {
        address from;
        address to;
        uint256 amount;
        uint256 amountTokens;
        bool usePrevHookAmount;
        address[] tokens;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address permit2_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        if (permit2_ == address(0)) revert ADDRESS_NOT_VALID();
        permit2 = permit2_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        BuildHookVars memory vars = _decodeBuildHookVars(data);

        if (vars.usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        _verifyAmount(account, data);

        // @dev no-revert-on-failure tokens are not supported
        executions = new Execution[](1);
        executions[0] = Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data);
    }

    function _postExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data) - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(bytes memory data) private view returns (uint256) {
        address token = BytesLib.toAddress(data, 0);
        address from = BytesLib.toAddress(data, 20);
        return IERC20(token).balanceOf(from);
    }

    function _decodeBuildHookVars(bytes memory data) private pure returns (BuildHookVars memory vars) {
        address token = BytesLib.toAddress(data, 0);
        address from = BytesLib.toAddress(data, 20);
        address to = BytesLib.toAddress(data, 40);
        uint256 amount = BytesLib.toUint256(data, 60);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (token == address(0)) revert ADDRESS_NOT_VALID();

        return BuildHookVars({ 
            token: token, 
            from: from, 
            to: to, 
            amount: amount,
            usePrevHookAmount: usePrevHookAmount
        });
    }

    function _createAllowanceTransferDetails(address account, bytes memory data) private view returns (AllowanceTransferDetails memory details) {
        address token = BytesLib.toAddress(data, 0);
    }

    function _verifyAmount(address account, bytes memory data) private view {
        address token = BytesLib.toAddress(data, 0);
        address from = BytesLib.toAddress(data, 20);
        uint256 amount = BytesLib.toUint256(data, 40);

        (uint160 allowance, uint48 expiration, uint48 nonce) = IPermit2Batch(permit2).allowance(from, token, account);

        if (allowance < amount) revert INSUFFICIENT_ALLOWANCE();

        uint256 balance = _getBalance(data);
        if (balance < amount) revert INSUFFICIENT_BALANCE();
    }
}