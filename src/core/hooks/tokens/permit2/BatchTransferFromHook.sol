// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPermit2 } from "../../../../vendor/uniswap/permit2/IPermit2.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IPermit2Batch } from "../../../../vendor/uniswap/permit2/IPermit2Batch.sol";
import { IAllowanceTransfer } from "../../../../vendor/uniswap/permit2/IAllowanceTransfer.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

/// @title BatchTransferFromHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice     address from = BytesLib.toAddress(data, 0);
/// @notice     uint256 amountTokens = BytesLib.toUint256(data, 20);
/// @notice     uint256 sigDeadline = BytesLib.toUint256(data, 52);
/// @notice     address[] tokens = BytesLib.slice(data, 84, 20 * amountTokens);
/// @notice     uint256[] amounts = BytesLib.slice(data, 84 + 20 * amountTokens, 32 * amountTokens);
/// @notice     bytes signature = BytesLib.slice(data, 84 + 20 * amountTokens + 32 * amountTokens, 65);
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
    IPermit2 public immutable PERMIT_2_INTERFACE;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address permit2_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        if (permit2_ == address(0)) revert ADDRESS_NOT_VALID();
        PERMIT_2 = permit2_;
        PERMIT_2_INTERFACE = IPermit2(permit2_);
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

        uint256 sigDeadline = BytesLib.toUint256(data, 52);

        // Extract tokens and amounts as raw bytes
        bytes memory tokensData = BytesLib.slice(data, 84, 20 * amountTokens);
        bytes memory amountsData = BytesLib.slice(data, 84 + (20 * amountTokens), 32 * amountTokens);

        bytes memory signature = BytesLib.slice(data, data.length - 65, 65);

        // Create 2 executions - one for batch permit and one for batch transfer
        executions = new Execution[](2);

        // First execution: Create a batch permit call
        // Create PermitBatch structure
        IAllowanceTransfer.PermitDetails[] memory details = new IAllowanceTransfer.PermitDetails[](amountTokens);

        for (uint256 i; i < amountTokens; i++) {
            address token = BytesLib.toAddress(tokensData, i * 20);
            uint256 amount = BytesLib.toUint256(amountsData, i * 32);

            if (token == address(0)) revert ADDRESS_NOT_VALID();
            if (amount == 0) revert AMOUNT_NOT_VALID();

            details[i] = IAllowanceTransfer.PermitDetails({
                token: token,
                amount: uint160(amount),
                expiration: uint48(block.timestamp + 2 weeks),
                nonce: uint48(0)
            });
        }

        IAllowanceTransfer.PermitBatch memory permitBatch =
            IAllowanceTransfer.PermitBatch({ details: details, spender: account, sigDeadline: sigDeadline });

        // Create permit call
        bytes memory permitCallData = abi.encodeCall(IPermit2Batch.permit, (from, permitBatch, signature));

        executions[0] = Execution({ target: PERMIT_2, value: 0, callData: permitCallData });

        // Second execution: Create a batch transferFrom call
        IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails =
            _createAllowanceTransferDetails(from, account, tokensData, amountsData, amountTokens);

        // Use IPermit2Batch.transferFrom selector which takes AllowanceTransferDetails[] as parameter
        bytes memory transferCallData = abi.encodeCall(IPermit2Batch.transferFrom, (transferDetails));

        executions[1] = Execution({ target: PERMIT_2, value: 0, callData: transferCallData });

        return executions;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        uint256 arrayLength = BytesLib.toUint256(data, 20);
        bytes memory tokensData = BytesLib.slice(data, 84, 20 * arrayLength);

        for (uint256 i; i < arrayLength; ++i) {
            address token = BytesLib.toAddress(tokensData, i * 20);
            outAmount += _getBalance(token, account);
        }
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        uint256 arrayLength = BytesLib.toUint256(data, 20);
        uint256 newAmount;
        bytes memory tokensData = BytesLib.slice(data, 84, 20 * arrayLength);

        for (uint256 i; i < arrayLength; ++i) {
            address token = BytesLib.toAddress(tokensData, i * 20);
            newAmount += _getBalance(token, account);
        }
        outAmount = newAmount - outAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getBalance(address token, address account) private view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }

    function _createAllowanceTransferDetails(
        address from,
        address account,
        bytes memory tokensData,
        bytes memory amountsData,
        uint256 length
    )
        private
        pure
        returns (IAllowanceTransfer.AllowanceTransferDetails[] memory details)
    {
        details = new IAllowanceTransfer.AllowanceTransferDetails[](length);
        for (uint256 i; i < length; ++i) {
            address token = BytesLib.toAddress(tokensData, i * 20);
            uint256 amount = BytesLib.toUint256(amountsData, i * 32);

            details[i] = IAllowanceTransfer.AllowanceTransferDetails({
                from: from,
                to: account,
                token: token,
                amount: uint160(amount)
            });
        }
        return details;
    }
}
