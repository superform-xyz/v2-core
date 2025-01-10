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

/// @title AcrossSendFundsHook
/// @dev data has the following structure
/// @notice         address account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         bytes32 id = BytesLib.toBytes32(BytesLib.slice(data, 20, 32), 0);
/// @notice         uint256 value = BytesLib.toUint256(BytesLib.slice(data, 52, 32), 0);
/// @notice         address recipient = BytesLib.toAddress(BytesLib.slice(data, 84, 20), 0);
/// @notice         address inputToken = BytesLib.toAddress(BytesLib.slice(data, 104, 20), 0);
/// @notice         address outputToken = BytesLib.toAddress(BytesLib.slice(data, 124, 20), 0);
/// @notice         uint256 inputAmount = BytesLib.toUint256(BytesLib.slice(data, 144, 32), 0);
/// @notice         uint256 outputAmount = BytesLib.toUint256(BytesLib.slice(data, 176, 32), 0);
/// @notice         uint256 destinationChainId = BytesLib.toUint256(BytesLib.slice(data, 208, 32), 0);
/// @notice         address exclusiveRelayer = BytesLib.toAddress(BytesLib.slice(data, 240, 20), 0);
/// @notice         uint32 fillDeadlineOffset = BytesLib.toUint32(BytesLib.slice(data, 260, 4), 0);
/// @notice         uint32 exclusivityPeriod = BytesLib.toUint32(BytesLib.slice(data, 264, 4), 0);
contract AcrossSendFundsHook is BaseHook, ISuperHook {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable spokePoolV3;
    uint64 public immutable sourceChainId;

    struct AcrossV3DepositData {
        address account;
        bytes32 id;
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
    function build(address, bytes memory data) external view override returns (Execution[] memory executions) {
        AcrossV3DepositData memory acrossV3DepositData;
        acrossV3DepositData.account = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        acrossV3DepositData.id = BytesLib.toBytes32(BytesLib.slice(data, 20, 32), 0);
        acrossV3DepositData.value = BytesLib.toUint256(BytesLib.slice(data, 52, 32), 0);
        acrossV3DepositData.recipient = BytesLib.toAddress(BytesLib.slice(data, 84, 20), 0);
        acrossV3DepositData.inputToken = BytesLib.toAddress(BytesLib.slice(data, 104, 20), 0);
        acrossV3DepositData.outputToken = BytesLib.toAddress(BytesLib.slice(data, 124, 20), 0);
        acrossV3DepositData.inputAmount = BytesLib.toUint256(BytesLib.slice(data, 144, 32), 0);
        acrossV3DepositData.outputAmount = BytesLib.toUint256(BytesLib.slice(data, 176, 32), 0);
        acrossV3DepositData.destinationChainId = BytesLib.toUint256(BytesLib.slice(data, 208, 32), 0);
        acrossV3DepositData.exclusiveRelayer = BytesLib.toAddress(BytesLib.slice(data, 240, 20), 0);
        acrossV3DepositData.fillDeadlineOffset = BytesLib.toUint32(BytesLib.slice(data, 260, 4), 0);
        acrossV3DepositData.exclusivityPeriod = BytesLib.toUint32(BytesLib.slice(data, 264, 4), 0);

        // assume it has the same address on all chains
        if (acrossV3DepositData.recipient == address(0)) revert ADDRESS_NOT_VALID();

        // build execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: spokePoolV3,
            value: acrossV3DepositData.value,
            callData: abi.encodeCall(
                IAcrossSpokePoolV3.depositV3Now,
                (
                    _getAcrossGatewayExecutor(),
                    acrossV3DepositData.recipient,
                    acrossV3DepositData.inputToken,
                    acrossV3DepositData.outputToken,
                    acrossV3DepositData.inputAmount,
                    acrossV3DepositData.outputAmount,
                    acrossV3DepositData.destinationChainId,
                    acrossV3DepositData.exclusiveRelayer,
                    acrossV3DepositData.fillDeadlineOffset,
                    acrossV3DepositData.exclusivityPeriod,
                    abi.encode(acrossV3DepositData.account, sourceChainId, acrossV3DepositData.id)
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
        return superRegistry.getAddress(superRegistry.ACROSS_RECEIVE_FUNDS_GATEWAY_ID());
    }
}
