// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookMinimal } from "../../../interfaces/ISuperHook.sol";
import { IPermit2Single } from "../../../interfaces/vendors/uniswap/permit2/IPermit2Single.sol";
import { IAllowanceTransfer } from "../../../interfaces/vendors/uniswap/permit2/IAllowanceTransfer.sol";

/// @title PermitWithPermit2Hook
/// @dev data has the following structure
/// TODO add structure
contract PermitWithPermit2Hook is BaseHook, ISuperHook {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public permit2;

    constructor(address registry_, address author_, address permit2_) BaseHook(registry_, author_, HookType.NONACCOUNTING) {
        if (permit2_ == address(0)) revert ADDRESS_NOT_VALID();
        permit2 = permit2_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        bool usePrevHookAmount = _decodeBool(data, 20);

        IAllowanceTransfer.PermitSingle memory permitSingle;
        permitSingle.details.token = BytesLib.toAddress(BytesLib.slice(data, 21, 20), 0);
        permitSingle.details.amount = uint160(BytesLib.toUint256(BytesLib.slice(data, 41, 32), 0));
        permitSingle.details.expiration = uint48(BytesLib.toUint256(BytesLib.slice(data, 73, 32), 0));
        permitSingle.details.nonce = uint48(BytesLib.toUint256(BytesLib.slice(data, 105, 32), 0));

        permitSingle.spender = BytesLib.toAddress(BytesLib.slice(data, 137, 20), 0);
        permitSingle.sigDeadline = BytesLib.toUint256(BytesLib.slice(data, 157, 32), 0);

        uint256 signatureOffset = 189;
        bytes memory signature = BytesLib.slice(data, signatureOffset, data.length - signatureOffset);

        if (usePrevHookAmount) {
            permitSingle.details.amount = ISuperHookMinimal(prevHook).outAmount().toUint160();
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
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external {
        (,, IAllowanceTransfer.PermitSingle memory permitSingle,) =
            abi.decode(data, (address, bool, IAllowanceTransfer.PermitSingle, bytes));
        outAmount = permitSingle.details.amount;
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external {
        (,, IAllowanceTransfer.PermitSingle memory permitSingle,) =
            abi.decode(data, (address, bool, IAllowanceTransfer.PermitSingle, bytes));
        outAmount = permitSingle.details.amount;
    }
}
