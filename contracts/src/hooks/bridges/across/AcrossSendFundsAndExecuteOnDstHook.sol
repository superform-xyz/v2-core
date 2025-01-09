// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";

import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
import { IAcrossSpokePoolV3 } from "../../../interfaces/vendors/bridges/across/IAcrossSpokePoolV3.sol";
import { IAcrossV3Interpreter } from "../../../interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

/// @title AcrossSendFundsAndExecuteOnDstHook
/// @dev data has the following structure
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         uint256 value = BytesLib.toUint256(BytesLib.slice(data, 20, 32), 0);
/// @notice         address recipient = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
/// @notice         address inputToken = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
/// @notice         address outputToken = BytesLib.toAddress(BytesLib.slice(data, 92, 20), 0);
/// @notice         uint256 inputAmount = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
/// @notice         uint256 outputAmount = BytesLib.toUint256(BytesLib.slice(data, 144, 32), 0);
/// @notice         uint256 destinationChainId = BytesLib.toUint256(BytesLib.slice(data, 176, 32), 0);
/// @notice         address exclusiveRelayer = BytesLib.toAddress(BytesLib.slice(data, 208, 20), 0);
/// @notice         uint32 fillDeadline = BytesLib.toUint32(BytesLib.slice(data, 228, 4), 0);
/// @notice         uint32 exclusivityDeadline = BytesLib.toUint32(BytesLib.slice(data, 232, 4), 0);
/// @notice         bytes message = BytesLib.slice(data, 236, data.length - 236);
contract AcrossSendFundsAndExecuteOnDstHook is BaseHook, ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable spokePoolV3;

    struct AcrossV3DepositAndExecuteData {
        uint256 value;
        address recipient;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 destinationChainId;
        address exclusiveRelayer;
        uint32 fillDeadline;
        uint32 exclusivityDeadline;
        bytes message;
    }

    uint64 public immutable sourceChainId;

    constructor(
        address registry_,
        address author_,
        address spokePoolV3_
    )
        BaseHook(registry_, author_, HookType.NONACCOUNTING)
    {
        if (spokePoolV3_ == address(0)) revert ADDRESS_NOT_VALID();
        spokePoolV3 = spokePoolV3_;
        sourceChainId = block.chainid;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(address, bytes memory data) external view override returns (Execution[] memory executions) {
        address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        AcrossV3DepositAndExecuteData memory acrossV3DepositAndExecuteData;
        acrossV3DepositAndExecuteData.value = BytesLib.toUint256(BytesLib.slice(data, 20, 32), 0);
        acrossV3DepositAndExecuteData.recipient = BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
        acrossV3DepositAndExecuteData.inputToken = BytesLib.toAddress(BytesLib.slice(data, 72, 20), 0);
        acrossV3DepositAndExecuteData.outputToken = BytesLib.toAddress(BytesLib.slice(data, 92, 20), 0);
        acrossV3DepositAndExecuteData.inputAmount = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
        acrossV3DepositAndExecuteData.outputAmount = BytesLib.toUint256(BytesLib.slice(data, 144, 32), 0);
        acrossV3DepositAndExecuteData.destinationChainId = BytesLib.toUint256(BytesLib.slice(data, 176, 32), 0);
        acrossV3DepositAndExecuteData.exclusiveRelayer = BytesLib.toAddress(BytesLib.slice(data, 208, 20), 0);
        acrossV3DepositAndExecuteData.fillDeadline = BytesLib.toUint32(BytesLib.slice(data, 228, 4), 0);
        acrossV3DepositAndExecuteData.exclusivityDeadline = BytesLib.toUint32(BytesLib.slice(data, 232, 4), 0);
        acrossV3DepositAndExecuteData.message = BytesLib.slice(data, 236, data.length - 236);

        // assume it has the same address on all chains
        address _dstContract = _getAcrossGatewayExecutor();
        if (acrossV3DepositAndExecuteData.recipient == address(0) || _dstContract == address(0)) {
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
                    _dstContract,
                    acrossV3DepositAndExecuteData.recipient,
                    acrossV3DepositAndExecuteData.inputToken,
                    acrossV3DepositAndExecuteData.outputToken,
                    acrossV3DepositAndExecuteData.inputAmount,
                    acrossV3DepositAndExecuteData.outputAmount,
                    acrossV3DepositAndExecuteData.destinationChainId,
                    acrossV3DepositAndExecuteData.exclusiveRelayer,
                    acrossV3DepositAndExecuteData.fillDeadline,
                    acrossV3DepositAndExecuteData.exclusivityDeadline,
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
        return superRegistry.getAddress(superRegistry.ACROSS_GATEWAY_ID());
    }
}
