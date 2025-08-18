// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IAcrossSpokePoolV3 } from "../../../vendor/bridges/across/IAcrossSpokePoolV3.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperSignatureStorage } from "../../../interfaces/ISuperSignatureStorage.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title AcrossSendFundsAndExecuteOnDstHook
/// @author Superform Labs
/// @dev inputAmount and outputAmount have to be predicted by the SuperBundler
/// @dev `destinationMessage` field won't contain the signature for the destination executor
/// @dev      signature is retrieved from the validator contract transient storage
/// @dev      This is needed to avoid circular dependency between merkle root which contains the signature needed to
/// sign it
/// @dev data has the following structure
/// @notice         uint256 value = BytesLib.toUint256(data, 0);
/// @notice         address recipient = BytesLib.toAddress(data, 32);
/// @notice         address inputToken = BytesLib.toAddress(data, 52);
/// @notice         address outputToken = BytesLib.toAddress(data, 72);
/// @notice         uint256 inputAmount = BytesLib.toUint256(data, 92);
/// @notice         uint256 outputAmount = BytesLib.toUint256(data, 124);
/// @notice         uint256 destinationChainId = BytesLib.toUint256(data, 156);
/// @notice         address exclusiveRelayer = BytesLib.toAddress(data, 188);
/// @notice         uint32 fillDeadlineOffset = BytesLib.toUint32(data, 208);
/// @notice         uint32 exclusivityPeriod = BytesLib.toUint32(data, 212);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 216);
/// @notice         bytes destinationMessage = BytesLib.slice(data, 217, data.length - 217);
contract AcrossSendFundsAndExecuteOnDstHook is BaseHook, ISuperHookContextAware {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable spokePoolV3;
    address private immutable _validator;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 216;

    struct AcrossV3DepositAndExecuteData {
        uint256 value;
        address recipient;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 destinationChainId;
        address exclusiveRelayer;
        uint32 fillDeadlineOffset;
        uint32 exclusivityPeriod;
        bool usePrevHookAmount;
        bytes destinationMessage;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DATA_NOT_VALID();

    constructor(address spokePoolV3_, address validator_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (spokePoolV3_ == address(0) || validator_ == address(0)) revert ADDRESS_NOT_VALID();
        spokePoolV3 = spokePoolV3_;
        _validator = validator_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
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
        if (data.length < 217) revert DATA_NOT_VALID();

        AcrossV3DepositAndExecuteData memory acrossV3DepositAndExecuteData;
        acrossV3DepositAndExecuteData.value = BytesLib.toUint256(data, 0);
        acrossV3DepositAndExecuteData.recipient = BytesLib.toAddress(data, 32);
        acrossV3DepositAndExecuteData.inputToken = BytesLib.toAddress(data, 52);
        acrossV3DepositAndExecuteData.outputToken = BytesLib.toAddress(data, 72);
        acrossV3DepositAndExecuteData.inputAmount = BytesLib.toUint256(data, 92);
        acrossV3DepositAndExecuteData.outputAmount = BytesLib.toUint256(data, 124);
        acrossV3DepositAndExecuteData.destinationChainId = BytesLib.toUint256(data, 156);
        acrossV3DepositAndExecuteData.exclusiveRelayer = BytesLib.toAddress(data, 188);
        acrossV3DepositAndExecuteData.fillDeadlineOffset = BytesLib.toUint32(data, 208);
        acrossV3DepositAndExecuteData.exclusivityPeriod = BytesLib.toUint32(data, 212);
        acrossV3DepositAndExecuteData.usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        acrossV3DepositAndExecuteData.destinationMessage = BytesLib.slice(data, 217, data.length - 217);

        if (acrossV3DepositAndExecuteData.usePrevHookAmount) {
            uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);

            // update `outputAmount` with the % `inputAmount` was updated by
            if (acrossV3DepositAndExecuteData.inputAmount > 0 && acrossV3DepositAndExecuteData.outputAmount > 0) {
                // outputAmount *= outAmount / inputAmount
                acrossV3DepositAndExecuteData.outputAmount = Math.mulDiv(
                    acrossV3DepositAndExecuteData.outputAmount, outAmount, acrossV3DepositAndExecuteData.inputAmount
                );
            }

            acrossV3DepositAndExecuteData.inputAmount = outAmount;
            if (
                acrossV3DepositAndExecuteData.inputToken
                    == address(IAcrossSpokePoolV3(spokePoolV3).wrappedNativeToken())
                    && acrossV3DepositAndExecuteData.value != 0
            ) {
                acrossV3DepositAndExecuteData.value = outAmount;
            }
        }

        if (acrossV3DepositAndExecuteData.inputAmount == 0) revert AMOUNT_NOT_VALID();

        if (acrossV3DepositAndExecuteData.recipient == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

       
        // if `destinationMessage` is present append signature to it
        if (acrossV3DepositAndExecuteData.destinationMessage.length > 0) {
            bytes memory signature = ISuperSignatureStorage(_validator).retrieveSignatureData(account);

            (
                bytes memory initData,
                bytes memory executorCalldata,
                address _account,
                address[] memory dstTokens,
                uint256[] memory intentAmounts
            ) = abi.decode(
                acrossV3DepositAndExecuteData.destinationMessage, (bytes, bytes, address, address[], uint256[])
            );
            acrossV3DepositAndExecuteData.destinationMessage =
                abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts, signature);
        }

        // build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: spokePoolV3,
            value: acrossV3DepositAndExecuteData.value,
            callData: abi.encodeCall(
                IAcrossSpokePoolV3.depositV3Now,
                (
                    account,
                    acrossV3DepositAndExecuteData.recipient,
                    acrossV3DepositAndExecuteData.inputToken,
                    acrossV3DepositAndExecuteData.outputToken,
                    acrossV3DepositAndExecuteData.inputAmount,
                    acrossV3DepositAndExecuteData.outputAmount,
                    acrossV3DepositAndExecuteData.destinationChainId,
                    acrossV3DepositAndExecuteData.exclusiveRelayer,
                    acrossV3DepositAndExecuteData.fillDeadlineOffset,
                    acrossV3DepositAndExecuteData.exclusivityPeriod,
                    acrossV3DepositAndExecuteData.destinationMessage
                )
            )
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, 32), // recipient
            BytesLib.toAddress(data, 52), // inputToken
            BytesLib.toAddress(data, 72), // outputToken
            BytesLib.toAddress(data, 188) // exclusiveRelayer
        );
    }
}
