// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IPermit2 } from "../../../vendor/uniswap/permit2/IPermit2.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IPermit2Batch } from "../../../vendor/uniswap/permit2/IPermit2Batch.sol";
import { IAllowanceTransfer } from "../../../vendor/uniswap/permit2/IAllowanceTransfer.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

/// @title BatchTransferFromHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice     address from = BytesLib.toAddress(data, 0);
/// @notice     uint256 tokensLength = BytesLib.toUint256(data, 20);
/// @notice     uint256 sigDeadline = BytesLib.toUint256(data, 52);
/// @notice     bytes tokens = BytesLib.slice(data, 84, 20 * tokensLength);
/// @notice     bytes amounts = BytesLib.slice(data, 84 + 20 * tokensLength, 32 * tokensLength);
/// @notice     bytes nonces = BytesLib.slice(data, 84 + 20 * tokensLength + 32 * tokensLength, 48 * tokensLength);
/// @notice     bytes signature = BytesLib.slice(data, 84 + 20 * tokensLength + 32 * tokensLength + 48 * tokensLength,
/// 65);
contract BatchTransferFromHook is BaseHook {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
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

    /// @dev Local variables struct to avoid stack too deep error
    struct BuildExecutionVars {
        address from;
        uint256 tokensLength;
        uint256 sigDeadline;
        bytes tokensData;
        bytes amountsData;
        bytes noncesData;
        bytes signature;
        IAllowanceTransfer.PermitDetails[] details;
        IAllowanceTransfer.PermitBatch permitBatch;
        IAllowanceTransfer.AllowanceTransferDetails[] transferDetails;
    }

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        BuildExecutionVars memory vars;

        vars.from = BytesLib.toAddress(data, 0);
        if (vars.from == address(0)) revert ADDRESS_NOT_VALID();

        vars.tokensLength = BytesLib.toUint256(data, 20);
        if (vars.tokensLength == 0) revert INVALID_ARRAY_LENGTH();

        vars.sigDeadline = BytesLib.toUint256(data, 52);

        // Extract tokens and amounts as raw bytes
        vars.tokensData = BytesLib.slice(data, 84, 20 * vars.tokensLength);
        vars.amountsData = BytesLib.slice(data, 84 + (20 * vars.tokensLength), 32 * vars.tokensLength);
        vars.noncesData =
            BytesLib.slice(data, 84 + (20 * vars.tokensLength) + (32 * vars.tokensLength), 6 * vars.tokensLength);

        vars.signature = BytesLib.slice(data, data.length - 65, 65);

        // Create 2 executions - one for batch permit and one for batch transfer
        executions = new Execution[](2);

        // First execution: Create a batch permit call
        // Create PermitBatch structure
        vars.details = new IAllowanceTransfer.PermitDetails[](vars.tokensLength);

        for (uint256 i; i < vars.tokensLength; i++) {
            address token = BytesLib.toAddress(vars.tokensData, i * 20);
            uint256 amount = BytesLib.toUint256(vars.amountsData, i * 32);
            bytes memory nonceSlice = BytesLib.slice(vars.noncesData, i * 6, 6);
            uint48 nonce = uint48(uint256(bytes32(nonceSlice)) >> 208);

            if (token == address(0)) revert ADDRESS_NOT_VALID();
            if (amount == 0) revert AMOUNT_NOT_VALID();

            vars.details[i] = IAllowanceTransfer.PermitDetails({
                token: token,
                amount: amount.toUint160(),
                expiration: vars.sigDeadline.toUint48(),
                nonce: nonce
            });
        }

        vars.permitBatch =
            IAllowanceTransfer.PermitBatch({ details: vars.details, spender: account, sigDeadline: vars.sigDeadline });

        // Create permit call
        bytes memory permitCallData =
            abi.encodeCall(IPermit2Batch.permit, (vars.from, vars.permitBatch, vars.signature));

        executions[0] = Execution({ target: PERMIT_2, value: 0, callData: permitCallData });

        // Second execution: Create a batch transferFrom call
        vars.transferDetails =
            _createAllowanceTransferDetails(vars.from, account, vars.tokensData, vars.amountsData, vars.tokensLength);

        // Use IPermit2Batch.transferFrom selector which takes AllowanceTransferDetails[] as parameter
        bytes memory transferCallData = abi.encodeCall(IPermit2Batch.transferFrom, (vars.transferDetails));

        executions[1] = Execution({ target: PERMIT_2, value: 0, callData: transferCallData });

        return executions;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        uint256 tokensLength = BytesLib.toUint256(data, 20);
        bytes memory tokensData = BytesLib.slice(data, 84, 20 * tokensLength);
        address[] memory tokens = new address[](tokensLength);
        for (uint256 i; i < tokensLength; i++) {
            tokens[i] = BytesLib.toAddress(tokensData, i * 20);
        }
        bytes memory packed = abi.encodePacked(BytesLib.toAddress(data, 0)); //from
        for (uint256 i; i < tokensLength; ++i) {
            packed = abi.encodePacked(packed, tokens[i]);
        }
        return packed;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata) internal override { }

    function _postExecute(address, address, bytes calldata) internal override { }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
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
                amount: amount.toUint160()
            });
        }
        return details;
    }
}
