// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPermit2Batch } from "../../../../vendor/uniswap/permit2/IPermit2Batch.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAllowanceTransfer } from "../../../../vendor/uniswap/permit2/IAllowanceTransfer.sol";
import { ISignatureTransfer } from "../../../../vendor/uniswap/permit2/ISignatureTransfer.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

/// @title BatchTransferFromHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address from = BytesLib.toAddress(data, 0);
/// @notice         uint256 amountTokens = BytesLib.toUint256(data, 20);
/// @notice         address[] tokens = BytesLib.slice(data, 52, 20 * amountTokens);
/// @notice         uint256[] amounts = BytesLib.slice(data, 52 + 20 * amountTokens, 32 * amountTokens);
/// @notice         bytes signature = BytesLib.slice(data, 52 + 20 * amountTokens + 32 * amountTokens, 65);
contract BatchTransferFromHook is BaseHook {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error INSUFFICIENT_ALLOWANCE();
    error INSUFFICIENT_BALANCE();
    error INVALID_ARRAY_LENGTH();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable PERMIT_2;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address permit2_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        if (permit2_ == address(0)) revert ADDRESS_NOT_VALID();
        PERMIT_2 = permit2_;
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

        uint256 amountTokens = BytesLib.toUint256(data, 20);
        if (amountTokens == 0) revert INVALID_ARRAY_LENGTH();

        // Extract tokens and amounts arrays
        address[] memory tokens = _decodeTokenArray(data, 52, amountTokens);
        uint256[] memory amounts = _decodeAmountArray(data, 52 + (20 * amountTokens), amountTokens);

        // Extract signature - it's the last 65 bytes of the data
        bytes memory signature = BytesLib.slice(data, data.length - 65, 65);

        // Build permitBatch call
        IAllowanceTransfer.PermitBatch memory permit = _buildPermitBatch(
            account, // spender
            tokens,
            amounts
        );

        bytes memory callDataPermit = abi.encodeCall(IPermit2Batch.permit, (from, permit, signature));

        // Build transferFrom call
        IAllowanceTransfer.AllowanceTransferDetails[] memory details =
            _createAllowanceTransferDetails(from, account, tokens, amounts);

        bytes memory callDataTransfer = abi.encodeCall(IPermit2Batch.transferFrom, (details));

        // Create executions array with permit first, then transfer
        executions = new Execution[](2);
        executions[0] = Execution({ target: PERMIT_2, value: 0, callData: callDataPermit });
        executions[1] = Execution({ target: PERMIT_2, value: 0, callData: callDataTransfer });
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        uint256 arrayLength = BytesLib.toUint256(data, 20);
        address[] memory tokens = _decodeTokenArray(data, 52, arrayLength);
        for (uint256 i; i < arrayLength; ++i) {
            outAmount += _getBalance(tokens[i], account);
        }
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 arrayLength = BytesLib.toUint256(data, 20);
        uint256 newAmount;
        address[] memory tokens = _decodeTokenArray(data, 52, arrayLength);
        for (uint256 i; i < arrayLength; ++i) {
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
            if (tokens[i] == address(0)) {
                revert ADDRESS_NOT_VALID();
            }
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
            if (amounts[i] == 0) {
                revert AMOUNT_NOT_VALID();
            }
        }
    }

    function _createAllowanceTransferDetails(
        address from,
        address account,
        address[] memory tokens_,
        uint256[] memory amounts_
    )
        private
        pure
        returns (IAllowanceTransfer.AllowanceTransferDetails[] memory details)
    {
        uint256 length = tokens_.length;
        details = new IAllowanceTransfer.AllowanceTransferDetails[](length);
        for (uint256 i; i < length; ++i) {
            details[i] = IAllowanceTransfer.AllowanceTransferDetails({
                from: from,
                to: account,
                token: tokens_[i],
                amount: uint160(amounts_[i])
            });
        }
    }

    /// @dev Builds a Permit2 `PermitBatch` with open-ended deadlines.
    function _buildPermitBatch(
        address spender,
        address[] memory tokens_,
        uint256[] memory amounts_
    )
        private
        pure 
        returns (IAllowanceTransfer.PermitBatch memory permit)
    {
        uint256 len = tokens_.length;
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](len);

        for (uint256 i; i < len; ++i) {
            details[i] = IAllowanceTransfer.PermitDetails({
                token: tokens_[i],
                amount: uint160(amounts_[i]),
                expiration: type(uint48).max,
                nonce: 0
            });
        }

        permit = IAllowanceTransfer.PermitBatch({ details: details, spender: spender, sigDeadline: type(uint256).max });
    }
}
