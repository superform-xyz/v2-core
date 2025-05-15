// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPermit2Batch } from "../../../../vendor/uniswap/permit2/IPermit2Batch.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAllowanceTransfer } from "../../../../vendor/uniswap/permit2/IAllowanceTransfer.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

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
contract BatchTransferFromHook is BaseHook, ISuperHookInspector {
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
    address public immutable permit2;

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

        IAllowanceTransfer.AllowanceTransferDetails[] memory details =
            _createAllowanceTransferDetails(from, account, tokens, amounts);

        // @dev no-revert-on-failure tokens are not supported
        executions = new Execution[](1);
        executions[0] =
            Execution({ target: permit2, value: 0, callData: abi.encodeCall(IPermit2Batch.transferFrom, (details)) });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external view returns(address target, address[] memory args) {
        target = address(permit2);
        uint256 permitArrayLength = BytesLib.toUint256(data, 20);
        uint256 argsLen = permitArrayLength + 2; // from, to & tokens[]
        args = new address[](argsLen);
        args[0] = BytesLib.toAddress(data, 0);
        args[1] = tempAcc;
        
        address[] memory tokens = _decodeTokenArray(data, 52, permitArrayLength);
        for (uint256 i; i < permitArrayLength; ++i) {
            args[i + 2] = tokens[i];
        }
    }

    /// @inheritdoc ISuperHookInspector
    function beneficiaryArgs(bytes calldata) external pure returns (uint8[] memory idxs) {
        idxs = new uint8[](1);
        idxs[0] = 1;
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
        tempAcc = account;
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
}
