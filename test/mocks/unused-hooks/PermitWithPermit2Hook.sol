// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Superform
import { BaseHook } from "../../../src/core/hooks/BaseHook.sol";

import { ISuperHookResult } from "../../../src/core/interfaces/ISuperHook.sol";
import { IPermit2Single } from "../../../src/vendor/uniswap/permit2/IPermit2Single.sol";
import { IAllowanceTransfer } from "../../../src/vendor/uniswap/permit2/IAllowanceTransfer.sol";

/// @title PermitWithPermit2Hook
/// @dev data has the following structure
/// @notice         address token = BytesLib.toAddress(BytesLib.slice(data, 1, 20), 0);
/// @notice         uint160 amount = uint160(BytesLib.toUint256(BytesLib.slice(data, 21, 32), 0));
/// @notice         uint48 expiration = uint48(BytesLib.toUint256(BytesLib.slice(data, 53, 32), 0));
/// @notice         uint48 nonce = uint48(BytesLib.toUint256(BytesLib.slice(data, 85, 32), 0));
/// @notice         address spender = BytesLib.toAddress(BytesLib.slice(data, 117, 20), 0);
/// @notice         uint256 sigDeadline = BytesLib.toUint256(BytesLib.slice(data, 137, 32), 0);
/// @notice         bytes signature = BytesLib.slice(data, 169, data.length - 169);
contract PermitWithPermit2Hook is BaseHook {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public permit2;

    constructor(address permit2_) BaseHook(HookType.NONACCOUNTING, "Token") {
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
        bool usePrevHookAmount = _decodeBool(data, 0);

        IAllowanceTransfer.PermitSingle memory permitSingle;
        permitSingle.details.token = BytesLib.toAddress(BytesLib.slice(data, 1, 20), 0);
        permitSingle.details.amount = uint160(BytesLib.toUint256(BytesLib.slice(data, 21, 32), 0));
        permitSingle.details.expiration = uint48(BytesLib.toUint256(BytesLib.slice(data, 53, 32), 0));
        permitSingle.details.nonce = uint48(BytesLib.toUint256(BytesLib.slice(data, 85, 32), 0));

        permitSingle.spender = BytesLib.toAddress(BytesLib.slice(data, 117, 20), 0);
        permitSingle.sigDeadline = BytesLib.toUint256(BytesLib.slice(data, 137, 32), 0);

        uint256 signatureOffset = 169;
        bytes memory signature = BytesLib.slice(data, signatureOffset, data.length - signatureOffset);

        if (usePrevHookAmount) {
            permitSingle.details.amount = ISuperHookResult(prevHook).outAmount().toUint160();
        }

        if (permitSingle.details.token == address(0) || permitSingle.spender == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(permit2),
            value: 0,
            callData: abi.encodeCall(IPermit2Single.permit, (account, permitSingle, signature))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {
        (,, IAllowanceTransfer.PermitSingle memory permitSingle,) =
            abi.decode(data, (address, bool, IAllowanceTransfer.PermitSingle, bytes));
        outAmount = permitSingle.details.amount;
    }

    function _postExecute(address, address, bytes calldata data) internal override {
        (,, IAllowanceTransfer.PermitSingle memory permitSingle,) =
            abi.decode(data, (address, bool, IAllowanceTransfer.PermitSingle, bytes));
        outAmount = permitSingle.details.amount;
    }
}
