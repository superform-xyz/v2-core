// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Superform
import { BaseHook } from "../../../src/hooks/BaseHook.sol";

import { ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";
import { IPermit2Batch } from "../../../src/vendor/uniswap/permit2/IPermit2Batch.sol";
import { IAllowanceTransfer } from "../../../src/vendor/uniswap/permit2/IAllowanceTransfer.sol";

/// @title PermitBatchWithPermit2Hook
/// @dev data has the following structure
/// @notice         bool usePrevHookAmount = _decodeBool(data, 0);
/// @notice         uint256 indexOfAmount = BytesLib.toUint256(BytesLib.slice(data, 1, 32), 0);
/// @notice         address spender = BytesLib.toAddress(BytesLib.slice(data, 33, 20), 0);
/// @notice         uint256 sigDeadline = BytesLib.toUint256(BytesLib.slice(data, 53, 32), 0);
/// @notice         uint256 detailsCount = BytesLib.toUint256(BytesLib.slice(data, 85, 32), 0);
/// @notice         uint256 offset = 117; // Start of PermitDetails array
/// @notice         IAllowanceTransfer.PermitDetails[] details - Array of permit details, each containing:
/// @notice             address token = BytesLib.toAddress(BytesLib.slice(data, offset, 20), 0);
/// @notice             uint160 amount = uint160(BytesLib.toUint256(BytesLib.slice(data, offset + 20, 32), 0));
/// @notice             uint48 expiration = uint48(BytesLib.toUint256(BytesLib.slice(data, offset + 52, 32), 0));
/// @notice             uint48 nonce = uint48(BytesLib.toUint256(BytesLib.slice(data, offset + 84, 32), 0));
/// @notice         uint256 offset increments by 116 bytes for each PermitDetails entry.
contract PermitBatchWithPermit2Hook is BaseHook {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct BuildExecutionVars {
        bool usePrevHookAmount;
        uint256 indexOfAmount;
        uint256 detailsCount;
        uint256 offset;
        uint256 signatureOffset;
        bytes signature;
        IAllowanceTransfer.PermitBatch permitBatch;
    }

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
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        BuildExecutionVars memory vars;

        vars.usePrevHookAmount = _decodeBool(data, 0);
        vars.indexOfAmount = BytesLib.toUint256(BytesLib.slice(data, 1, 32), 0);

        vars.permitBatch.spender = BytesLib.toAddress(BytesLib.slice(data, 33, 20), 0);
        vars.permitBatch.sigDeadline = BytesLib.toUint256(BytesLib.slice(data, 53, 32), 0);

        vars.detailsCount = BytesLib.toUint256(BytesLib.slice(data, 85, 32), 0);
        vars.offset = 117; // Start of PermitDetails array

        vars.permitBatch.details = new IAllowanceTransfer.PermitDetails[](vars.detailsCount);
        for (uint256 i; i < vars.detailsCount; ++i) {
            vars.permitBatch.details[i].token = BytesLib.toAddress(BytesLib.slice(data, vars.offset, 20), 0);
            vars.permitBatch.details[i].amount =
                uint160(BytesLib.toUint256(BytesLib.slice(data, vars.offset + 20, 32), 0));
            vars.permitBatch.details[i].expiration =
                uint48(BytesLib.toUint256(BytesLib.slice(data, vars.offset + 52, 32), 0));
            vars.permitBatch.details[i].nonce =
                uint48(BytesLib.toUint256(BytesLib.slice(data, vars.offset + 84, 32), 0));
            vars.offset += 116; // Each PermitDetails struct takes 116 bytes
        }

        vars.signatureOffset = vars.offset;
        vars.signature = BytesLib.slice(data, vars.signatureOffset, data.length - vars.signatureOffset);

        if (vars.usePrevHookAmount) {
            vars.permitBatch.details[vars.indexOfAmount].amount =
                ISuperHookResult(prevHook).getOutAmount(account).toUint160();
        }

        if (vars.permitBatch.spender == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(permit2),
            value: 0,
            callData: abi.encodeCall(IPermit2Batch.permit, (account, vars.permitBatch, vars.signature))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        (,, uint256 indexOfAmount, IAllowanceTransfer.PermitBatch memory permitBatch,) =
            abi.decode(data, (address, bool, uint256, IAllowanceTransfer.PermitBatch, bytes));

        _setOutAmount(permitBatch.details[indexOfAmount].amount, account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        (,, uint256 indexOfAmount, IAllowanceTransfer.PermitBatch memory permitBatch,) =
            abi.decode(data, (address, bool, uint256, IAllowanceTransfer.PermitBatch, bytes));

        _setOutAmount(permitBatch.details[indexOfAmount].amount, account);
    }
}
