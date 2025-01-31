// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { IPermit2Batch } from "../../../interfaces/vendors/uniswap/permit2/IPermit2Batch.sol";
import { IAllowanceTransfer } from "../../../interfaces/vendors/uniswap/permit2/IAllowanceTransfer.sol";

/// @title PermitBatchWithPermit2Hook
/// @dev data has the following structure
/// TODO add structure
contract PermitBatchWithPermit2Hook is BaseHook, ISuperHook {
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
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        bool usePrevHookAmount = _decodeBool(data, 0);
        uint256 indexOfAmount = BytesLib.toUint256(BytesLib.slice(data, 1, 32), 0);

        IAllowanceTransfer.PermitBatch memory permitBatch;
        permitBatch.spender = BytesLib.toAddress(BytesLib.slice(data, 33, 20), 0);
        permitBatch.sigDeadline = BytesLib.toUint256(BytesLib.slice(data, 53, 32), 0);

        uint256 detailsCount = BytesLib.toUint256(BytesLib.slice(data, 85, 32), 0);
        uint256 offset = 117; // Start of PermitDetails array

        permitBatch.details = new IAllowanceTransfer.PermitDetails[](detailsCount);
        for (uint256 i = 0; i < detailsCount; ) {
            permitBatch.details[i].token = BytesLib.toAddress(BytesLib.slice(data, offset, 20), 0);
            permitBatch.details[i].amount = uint160(BytesLib.toUint256(BytesLib.slice(data, offset + 20, 32), 0));
            permitBatch.details[i].expiration = uint48(BytesLib.toUint256(BytesLib.slice(data, offset + 52, 32), 0));
            permitBatch.details[i].nonce = uint48(BytesLib.toUint256(BytesLib.slice(data, offset + 84, 32), 0));
            offset += 116; // Each PermitDetails struct takes 116 bytes

            unchecked { ++i; }
        }

        uint256 signatureOffset = offset;
        bytes memory signature = BytesLib.slice(data, signatureOffset, data.length - signatureOffset);

        if (usePrevHookAmount) {
            permitBatch.details[indexOfAmount].amount = ISuperHookResult(prevHook).outAmount().toUint160();
        }

        if (permitBatch.spender == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(permit2),
            value: 0,
            callData: abi.encodeCall(IPermit2Batch.permit, (account, permitBatch, signature))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external {
        (,, uint256 indexOfAmount, IAllowanceTransfer.PermitBatch memory permitBatch,) =
            abi.decode(data, (address, bool, uint256, IAllowanceTransfer.PermitBatch, bytes));

        outAmount = permitBatch.details[indexOfAmount].amount;
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external {
        (,, uint256 indexOfAmount, IAllowanceTransfer.PermitBatch memory permitBatch,) =
            abi.decode(data, (address, bool, uint256, IAllowanceTransfer.PermitBatch, bytes));

        outAmount = permitBatch.details[indexOfAmount].amount;
    }
}
