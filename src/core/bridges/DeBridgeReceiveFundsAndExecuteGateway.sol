// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IMinimalEntryPoint, PackedUserOperation } from "../../vendor/account-abstraction/IMinimalEntryPoint.sol";
import { BytesLib } from "../../vendor/BytesLib.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { IDeBridgeGate } from "../../vendor/bridges/debridge/IDeBridgeGate.sol";

/// @title DeBridgeReceiveFundsAndExecuteGateway
/// @notice This contract acts as a gateway for receiving funds from the DeBridge Protocol
/// @notice and executing associated user operations.
/// @notice  address account = BytesLib.toAddress(BytesLib.slice(message, 0, 20), 0);
/// @notice  uint256 intentAmount = BytesLib.toUint256(BytesLib.slice(message, 20, 32), 0);
/// @notice  userOp.sender = BytesLib.toAddress(BytesLib.slice(message, 52, 20), 0);
/// @notice  userOp.nonce = BytesLib.toUint256(BytesLib.slice(message, 72, 32), 0);
/// @notice  uint256 codeLength = BytesLib.toUint256(BytesLib.slice(message, 104, 32), 0);
/// @notice  userOp.initCode = BytesLib.slice(message, 104, codeLength);
/// @notice  userOp.accountGasLimits = BytesLib.toBytes32(BytesLib.slice(message, 136, 32), 0);
/// @notice  userOp.preVerificationGas = BytesLib.toUint256(BytesLib.slice(message, 168, 32), 0);
/// @notice  userOp.gasFees = BytesLib.toBytes32(BytesLib.slice(message, 168, 32), 0);
/// @notice  codeLength = BytesLib.toUint256(BytesLib.slice(message, 200, 32), 0);
/// @notice  userOp.paymasterAndData = BytesLib.slice(message, 200, codeLength);
/// @notice  codeLength = BytesLib.toUint256(BytesLib.slice(message, 232, 32), 0);
/// @notice  userOp.signature = BytesLib.slice(message, 232, codeLength);
contract DeBridgeReceiveFundsAndExecuteGateway is SuperRegistryImplementer {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable deBridgeGate;
    address public immutable entryPointAddress; // can be a constant, but better to set it in constructor

    struct DeBridgeClaimData {
        bytes32 debridgeId;
        uint256 amount;
        uint256 chainIdFrom;
        address receiver;
        uint256 nonce;
        bytes signatures;
        bytes autoParams;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ADDRESS_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event GatewayClaimed(bytes32 debridgeId, uint256 amount, uint256 chainIdFrom, address receiver, uint256 nonce);
    event DeBridgeFundsReceivedAndExecuted(PackedUserOperation[] userOps);

    constructor(
        address registry_,
        address deBridgeGate_,
        address entryPointAddress_
    )
        SuperRegistryImplementer(registry_)
    {
        if (deBridgeGate_ == address(0)) revert ADDRESS_NOT_VALID();
        if (entryPointAddress_ == address(0)) revert ADDRESS_NOT_VALID();
        deBridgeGate = deBridgeGate_;
        entryPointAddress = entryPointAddress_;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function claim(DeBridgeClaimData[] memory batch, PackedUserOperation[] memory userOps) external {
        uint256 len = batch.length;
        for (uint256 i; i < len;) {
            DeBridgeClaimData memory claimData = batch[i];

            IDeBridgeGate(deBridgeGate).claim(
                claimData.debridgeId,
                claimData.amount,
                claimData.chainIdFrom,
                claimData.receiver,
                claimData.nonce,
                claimData.signatures,
                claimData.autoParams
            );
            emit GatewayClaimed(
                claimData.debridgeId, claimData.amount, claimData.chainIdFrom, claimData.receiver, claimData.nonce
            );
            unchecked {
                ++i;
            }
        }

        IMinimalEntryPoint(entryPointAddress).handleOps(userOps, _getSuperBundler());
        emit DeBridgeFundsReceivedAndExecuted(userOps);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the super bundler
    function _getSuperBundler() internal view returns (address payable) {
        return payable(superRegistry.getAddress(keccak256("SUPER_BUNDLER_ID")));
    }
}
