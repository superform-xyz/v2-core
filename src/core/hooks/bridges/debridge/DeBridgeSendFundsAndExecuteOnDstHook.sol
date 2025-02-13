// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../libraries/BytesLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { IDeBridgeGate } from "../../../interfaces/vendors/bridges/debridge/IDeBridgeGate.sol";

/// @title DeBridgeSendFundsAndExecuteOnDstHook
/// @dev data has the following structure
/// @notice         uint256 value = BytesLib.toUint256(BytesLib.slice(data, 0, 32), 0);
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
/// @notice         address inputToken = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         uint256 inputAmount = BytesLib.toUint256(BytesLib.slice(data, 72, 32), 0);
/// @notice         uint256 chainIdTo = BytesLib.toUint256(BytesLib.slice(data, 104, 32), 0);
/// @notice         uint32 referralCode = BytesLib.toUint32(BytesLib.slice(data, 136, 4), 0);
/// @notice         bool useAssetFee = _decodeBool(data, 140);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 141);
/// @notice         uint256 autoParamsLength = BytesLib.toUint256(BytesLib.slice(data, 142, 32), 0);
/// @notice         bytes autoParams = BytesLib.slice(data, 174, autoParamsLength);
/// @notice         bytes permit = BytesLib.slice(data, 174 + autoParamsLength, data.length - 174 - autoParamsLength;
/// @dev inputAmount and outputAmount have to be predicted by the SuperBundler
contract DeBridgeSendFundsAndExecuteOnDstHook is BaseHook, ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable deBridgeGate;

    struct DeBridgeDepositAndExecuteData {
        uint256 value;
        address account;
        address inputToken;
        uint256 inputAmount;
        uint256 chainIdTo;
        uint32 referralCode;
        bool useAssetFee;
        bool usePrevHookAmount;
        uint256 autoParamsLength;
        bytes autoParams;
        /**
         * autoParams structure:
         *     {
         *         uint256 executionFee // = 0 for a manual claim flow
         *         uint256 flags
         *         bytes fallbackAddress
         *         bytes data
         *     }
         */
        bytes permit;
    }

    constructor(
        address registry_,
        address author_,
        address deBridgeGate_
    )
        BaseHook(registry_, author_, HookType.NONACCOUNTING)
    {
        if (deBridgeGate_ == address(0)) revert ADDRESS_NOT_VALID();
        deBridgeGate = deBridgeGate_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        uint256 offset;
        DeBridgeDepositAndExecuteData memory deBridgeDepositAndExecuteData;
        deBridgeDepositAndExecuteData.value = BytesLib.toUint256(BytesLib.slice(data, offset, 32), 0);
        offset += 32;
        deBridgeDepositAndExecuteData.account = BytesLib.toAddress(BytesLib.slice(data, offset, 20), 0);
        offset += 20;
        deBridgeDepositAndExecuteData.inputToken = BytesLib.toAddress(BytesLib.slice(data, offset, 20), 0);
        offset += 20;
        deBridgeDepositAndExecuteData.inputAmount = BytesLib.toUint256(BytesLib.slice(data, offset, 32), 0);
        offset += 32;
        deBridgeDepositAndExecuteData.chainIdTo = BytesLib.toUint256(BytesLib.slice(data, offset, 32), 0);
        offset += 32;
        deBridgeDepositAndExecuteData.referralCode = BytesLib.toUint32(BytesLib.slice(data, offset, 4), 0);
        offset += 4;
        deBridgeDepositAndExecuteData.useAssetFee = _decodeBool(data, offset);
        offset += 1;
        deBridgeDepositAndExecuteData.usePrevHookAmount = _decodeBool(data, offset);
        offset += 1;
        deBridgeDepositAndExecuteData.autoParamsLength = BytesLib.toUint256(BytesLib.slice(data, offset, 32), 0);
        offset += 32;
        deBridgeDepositAndExecuteData.autoParams = BytesLib.slice(data, offset, data.length - offset);
        offset += deBridgeDepositAndExecuteData.autoParamsLength;
        deBridgeDepositAndExecuteData.permit = BytesLib.slice(data, offset, data.length - offset);

        if (deBridgeDepositAndExecuteData.usePrevHookAmount) {
            deBridgeDepositAndExecuteData.inputAmount = ISuperHookResult(prevHook).outAmount();
        }

        // checks
        if (deBridgeDepositAndExecuteData.inputAmount == 0) revert AMOUNT_NOT_VALID();

        // build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: deBridgeGate,
            value: deBridgeDepositAndExecuteData.value,
            callData: abi.encodeCall(
                IDeBridgeGate.send,
                (
                    deBridgeDepositAndExecuteData.inputToken,
                    deBridgeDepositAndExecuteData.inputAmount,
                    deBridgeDepositAndExecuteData.chainIdTo,
                    abi.encodePacked(deBridgeDepositAndExecuteData.account),
                    deBridgeDepositAndExecuteData.permit,
                    deBridgeDepositAndExecuteData.useAssetFee,
                    deBridgeDepositAndExecuteData.referralCode,
                    deBridgeDepositAndExecuteData.autoParams
                )
            )
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address, bytes memory) external view onlyExecutor { }

    /// @inheritdoc ISuperHook
    function postExecute(address, address, bytes memory) external view onlyExecutor { }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getDeBridgeGatewayExecutor() private view returns (address) {
        return superRegistry.getAddress(keccak256("DEBRIDGE_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_ID"));
    }
}
