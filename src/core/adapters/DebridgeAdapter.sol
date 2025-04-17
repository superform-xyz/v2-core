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
    function handleDebridgeMessage(bytes calldata message) external {
        // 1. Decode Debridge-specific message payload
        //      sigData contains: uint48 validUntil, bytes32 merkleRoot, bytes32[] proof, bytes signature
        //      executorCalldata is the ExecutorEntry (hooksAddresses, hooksData)
        (
            address tokenSent,
            uint256 amount,
            bytes memory initData,
            bytes memory executorCalldata,
            bytes memory sigData,
            address account,
            uint256 intentAmount
        ) = abi.decode(message[4:], (address, uint256, bytes, bytes, bytes, address, uint256));

      
        if (amount > intentAmount) {
            revert AMOUNT_NOT_VALID();
        }

        // 3. Transfer received funds to the target account *before* calling the executor.
        //    This ensures the executor can reliably check the balance.
        //    Requires this adapter contract to hold the funds temporarily from DeBridge.
        //    Account is encoded in the merkle tree and validated by the destination executor
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
