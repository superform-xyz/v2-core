// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { IDeBridgeGate  } from "../../vendor/bridges/debridge/IDeBridgeGate.sol";

/// @title DebridgeAdapter
/// @author Superform Labs
/// @notice Receives messages from the Debridge protocol and forwards them to the SuperDestinationExecutor.
/// @notice This contract acts as a translator between the Debridge protocol and the core Superform execution logic.
contract DebridgeAdapter {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable deBridgeGate;
    ISuperDestinationExecutor public immutable superDestinationExecutor;

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
    error INVALID_RECEIVER();
    error AMOUNT_NOT_VALID();
    error ADDRESS_NOT_VALID();
    error INVALID_AUTO_PARAMS();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event GatewayClaimed(bytes32 debridgeId, uint256 amount, uint256 chainIdFrom, address receiver, uint256 nonce);

    constructor(address deBridgeGate_, address superDestinationExecutor_) {
        if (deBridgeGate_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        deBridgeGate = deBridgeGate_;
        superDestinationExecutor = ISuperDestinationExecutor(superDestinationExecutor_);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function claim(bytes calldata claimDataMsg) external {
        // TODO#1: confirm with DeBridge if we need to claim here or solvers claim it and then call `recipient.call(autoParams)`
        /**
        // 1. Decode and claim on DebridgeGate
        (
            bytes32 debridgeId,
            uint256 amount,
            uint256 chainIdFrom,
            address receiver,
            uint256 nonce,
            bytes memory signatures,
            bytes memory autoParams,
            address tokenSent
        ) = abi.decode(claimDataMsg[4:], (bytes32, uint256, uint256, address, uint256, bytes, bytes, address));

        if (autoParams.length == 0) {
            revert INVALID_AUTO_PARAMS();
        }

        IDeBridgeGate(deBridgeGate).claim(debridgeId, amount, chainIdFrom, receiver, nonce, signatures, autoParams);
        emit GatewayClaimed(debridgeId, amount, chainIdFrom, receiver, nonce);
        */

        // 2. Decode Debridge-specific message payload
        //      sigData contains: uint48 validUntil, bytes32 merkleRoot, bytes32[] proof, bytes signature
        //      executorCalldata is the ExecutorEntry (hooksAddresses, hooksData)

        // @dev uncomment based on [TODO#1]
        //(,,, bytes memory message) = abi.decode(autoParams, (uint256, uint256, bytes, bytes));
        (,,, bytes memory message) = abi.decode(claimDataMsg[4:], (uint256, uint256, bytes, bytes));
        (
            address tokenSent,
            uint256 amount,
            bytes memory initData,
            bytes memory executorCalldata,
            bytes memory sigData,
            address account,
            uint256 intentAmount
        ) = abi.decode(message, (address, uint256, bytes, bytes, bytes, address, uint256));

        if (amount > intentAmount) {
            // TODO#2 : I think we should include `amount` and `account` in the signature and check this param with the signature's amount
            //        That way, we protect from solvers encoding a larger amount or a different account
            revert AMOUNT_NOT_VALID();
        }

        // @dev uncomment based on [TODO#1]
        //if (account != receiver) revert INVALID_RECEIVER();

        // 3. Transfer received funds to the target account *before* calling the executor.
        //    This ensures the executor can reliably check the balance.
        //    Requires this adapter contract to hold the funds temporarily from DeBridge.
        IERC20(tokenSent).safeTransfer(account, amount);

        // 4. Call the core executor's standardized function
        superDestinationExecutor.processBridgedExecution(
            tokenSent,
            account,
            intentAmount,
            initData,
            executorCalldata,
            sigData // User signature + validation payload
        );
    }
}
