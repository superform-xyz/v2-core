// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../libraries/BytesLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
import { IAcrossSpokePoolV3 } from "../../../interfaces/vendors/bridges/across/IAcrossSpokePoolV3.sol";
import { IAcrossV3Interpreter } from "../../../interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";


/// @title AcrossSendFundsAndExecuteOnDstHook
/// @dev data has the following structure
/// @notice         uint256 value = BytesLib.toUint256(BytesLib.slice(data, 0, 32), 0);
/// @notice         address recipient = BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
/// @notice         address inputToken = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         address outputToken = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
/// @notice         uint256 inputAmount = BytesLib.toUint256(BytesLib.slice(data, 92, 32), 0);
/// @notice         uint256 outputAmount = BytesLib.toUint256(BytesLib.slice(data, 124, 32), 0);
/// @notice         uint256 destinationChainId = BytesLib.toUint256(BytesLib.slice(data, 156, 32), 0);
/// @notice         address exclusiveRelayer = BytesLib.toAddress(BytesLib.slice(data, 188, 20), 0);
/// @notice         uint32 fillDeadlineOffset = BytesLib.toUint32(BytesLib.slice(data, 208, 4), 0);
/// @notice         uint32 exclusivityPeriod = BytesLib.toUint32(BytesLib.slice(data, 212, 4), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 216);
/// @notice         bytes message = BytesLib.slice(data, 217, data.length - 217);
/// @dev inputAmount and outputAmount have to be predicted by the SuperBundler
contract AcrossSendFundsAndExecuteOnDstHook is BaseHook, ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable spokePoolV3;
    uint64 public immutable sourceChainId;

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
        bytes message;
    }

    constructor(
        address registry_,
        address author_,
        address spokePoolV3_
    )
        BaseHook(registry_, author_, HookType.NONACCOUNTING)
    {
        if (spokePoolV3_ == address(0)) revert ADDRESS_NOT_VALID();
        spokePoolV3 = spokePoolV3_;
        sourceChainId = uint64(block.chainid);
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
        AcrossV3DepositAndExecuteData memory acrossV3DepositAndExecuteData;
        acrossV3DepositAndExecuteData.value = BytesLib.toUint256(BytesLib.slice(data, 0, 32), 0);
        acrossV3DepositAndExecuteData.recipient = BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
        acrossV3DepositAndExecuteData.inputToken = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
        acrossV3DepositAndExecuteData.outputToken = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
        acrossV3DepositAndExecuteData.inputAmount = BytesLib.toUint256(BytesLib.slice(data, 92, 32), 0);
        acrossV3DepositAndExecuteData.outputAmount = BytesLib.toUint256(BytesLib.slice(data, 124, 32), 0);
        acrossV3DepositAndExecuteData.destinationChainId = BytesLib.toUint256(BytesLib.slice(data, 156, 32), 0);
        acrossV3DepositAndExecuteData.exclusiveRelayer = BytesLib.toAddress(BytesLib.slice(data, 188, 20), 0);
        acrossV3DepositAndExecuteData.fillDeadlineOffset = BytesLib.toUint32(BytesLib.slice(data, 208, 4), 0);
        acrossV3DepositAndExecuteData.exclusivityPeriod = BytesLib.toUint32(BytesLib.slice(data, 212, 4), 0);
        acrossV3DepositAndExecuteData.usePrevHookAmount = _decodeBool(data, 216);
        acrossV3DepositAndExecuteData.message = BytesLib.slice(data, 217, data.length - 217);

        if (acrossV3DepositAndExecuteData.usePrevHookAmount) {
            acrossV3DepositAndExecuteData.inputAmount = ISuperHookResult(prevHook).outAmount();
        }

        if (acrossV3DepositAndExecuteData.inputAmount == 0) revert AMOUNT_NOT_VALID();

        if (acrossV3DepositAndExecuteData.recipient == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        // build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: spokePoolV3,
            value: acrossV3DepositAndExecuteData.value,
            callData: abi.encodeCall(
                IAcrossSpokePoolV3.depositV3Now,
                (
                    _getAcrossGatewayExecutor(), // assume it has the same address on all chains
                    acrossV3DepositAndExecuteData.recipient,
                    acrossV3DepositAndExecuteData.inputToken,
                    acrossV3DepositAndExecuteData.outputToken,
                    acrossV3DepositAndExecuteData.inputAmount,
                    acrossV3DepositAndExecuteData.outputAmount,
                    acrossV3DepositAndExecuteData.destinationChainId,
                    acrossV3DepositAndExecuteData.exclusiveRelayer,
                    acrossV3DepositAndExecuteData.fillDeadlineOffset,
                    acrossV3DepositAndExecuteData.exclusivityPeriod,
                    acrossV3DepositAndExecuteData.message
                )
            )
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory) external view onlyExecutor { }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory) external view onlyExecutor { }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getAcrossGatewayExecutor() private view returns (address) {
        return superRegistry.getAddress(superRegistry.ACROSS_RECEIVE_FUNDS_AND_EXECUTE_GATEWAY_ID());
    }
}
