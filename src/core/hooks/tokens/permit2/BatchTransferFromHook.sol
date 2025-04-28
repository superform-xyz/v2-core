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

/// @title BatchTransferFromHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address from = BytesLib.toAddress(data, 0);
/// @notice         uint256 arrayLength = BytesLib.toUint256(data, 20);
/// @notice         //  address[] tokens  — starts at byte 52, length = 20  * arrayLength
/// @notice         //  uint256[] amounts — starts at 52 + (20 * arrayLength),
/// @notice         //                         length = 32 * arrayLength
/// @notice         //  Each amounts[i] corresponds to tokens[i].
contract BatchTransferFromHook is BaseHook {
    using SafeCast for uint256;

    error INSUFFICIENT_ALLOWANCE();
    error INSUFFICIENT_BALANCE();
    error INVALID_ARRAY_LENGTH();

    address public permit2;

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
        address,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address from = BytesLib.toAddress(data, 0);

        if (from == address(0)) revert ADDRESS_NOT_VALID();

        uint256 arrayLength = BytesLib.toUint256(data, 20);

        address[] memory tokens = new address[](arrayLength);
        uint256[] memory amounts = new uint256[](arrayLength);

        tokens = _decodeTokenArray(data, 52, arrayLength);
        amounts = _decodeAmountArray(data, 52 + (20 * arrayLength), arrayLength);

        _verifyAmounts(account, tokens, amounts, data);

        IAllowanceTransfer.AllowanceTransferDetails[] memory details =
            _createAllowanceTransferDetails(from, account, tokens, amounts);

        // @dev no-revert-on-failure tokens are not supported
        executions = new Execution[](1);
        executions[0] =
            Execution({ target: permit2, value: 0, callData: abi.encodeCall(IPermit2Batch.transferFrom, (details)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        uint256 arrayLength = BytesLib.toUint256(data, 20);
        address[] memory tokens = _decodeTokenArray(data, 52, arrayLength);
        for (uint256 i; i < tokens.length; ++i) {
            outAmount += _getBalance(tokens[i], account);
        }
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 arrayLength = BytesLib.toUint256(data, 20);
        uint256 newAmount;
        address[] memory tokens = _decodeTokenArray(data, 52, arrayLength);
        for (uint256 i; i < tokens.length; ++i) {
            newAmount += _getBalance(tokens[i], account);
        }
        outAmount = newAmount - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(address token, address account) private view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }

    function _decodeTokenArray(
        bytes memory data,
        uint256 offset,
        uint256 length
    )
        private
        pure
        returns (address[] memory tokens)
    {   
        tokens = new address[](length);
        for (uint256 i; i < length; ++i) {
            tokens[i] = BytesLib.toAddress(data, offset + (20 * i));
        }
    }

    function _decodeAmountArray(
        bytes memory data,
        uint256 offset,
        uint256 length
    )
        private
        pure
        returns (uint256[] memory amounts)
    {   
        amounts = new uint256[](length);
        for (uint256 i; i < length; ++i) {
            amounts[i] = BytesLib.toUint256(data, offset + (32 * i));
        }
    }

    function _createAllowanceTransferDetails(
        address from,
        address account,
        address[] memory tokens,
        uint256[] memory amounts
    )
        private
        pure
        returns (IAllowanceTransfer.AllowanceTransferDetails[] memory details)
    {   
        uint256 length = tokens.length;
        details = new IAllowanceTransfer.AllowanceTransferDetails[](length);
        for (uint256 i; i < length; ++i) {
            details[i] = IAllowanceTransfer.AllowanceTransferDetails({
                from: from,
                to: account,
                token: tokens[i],
                amount: uint160(amounts[i])
            });
        }
    }

    function _verifyAmounts(
        address account,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory data
    )
        private
        view
    {   
        uint256 length = tokens.length;
        if (length != amounts.length) revert INVALID_ARRAY_LENGTH();
        address from = BytesLib.toAddress(data, 0);

        for (uint256 i; i < length; ++i) {
            address token = tokens[i];
            uint256 amount = amounts[i];

            (uint160 allowance,,) = IAllowanceTransfer(permit2).allowance(from, token, account);

            if (allowance < amount) revert INSUFFICIENT_ALLOWANCE();

            uint256 balance = IERC20(token).balanceOf(from);
            if (balance < amount) revert INSUFFICIENT_BALANCE();
        }
    }
}
