// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Protocol Interfaces
import { IAcrossV3Receiver } from "../../vendor/bridges/across/IAcrossV3Receiver.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";

/// @title AcrossV3Adapter
/// @author Superform Labs
/// @notice Receives messages from the Across V3 protocol and forwards them to the SuperDestinationExecutor.
/// @notice This contract acts as a translator between the Across V3 protocol and the core Superform execution logic.
contract AcrossV3Adapter is IAcrossV3Receiver {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable acrossSpokePool;
    ISuperDestinationExecutor public immutable superDestinationExecutor;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error INVALID_SENDER();
    error ADDRESS_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address acrossSpokePool_, address superDestinationExecutor_) {
        if (acrossSpokePool_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        acrossSpokePool = acrossSpokePool_;
        superDestinationExecutor = ISuperDestinationExecutor(superDestinationExecutor_);
    }

    /*//////////////////////////////////////////////////////////////
                            ACROSS V3 RECEIVER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAcrossV3Receiver
    function handleV3AcrossMessage(
        address tokenSent,
        uint256 amount,
        address, // relayer; not used
        bytes memory message
    )
        external
        override
    {
        // 1. Validate Sender
        if (msg.sender != acrossSpokePool) {
            revert INVALID_SENDER();
        }

        // 2. Decode Across-specific message payload
        //      sigData contains: uint48 validUntil, bytes32 merkleRoot, bytes32[] proof, bytes signature
        //      executorCalldata is the ExecutorEntry (hooksAddresses, hooksData)
        (
            bytes memory initData,
            bytes memory executorCalldata,
            bytes memory sigData,
            address account,
            uint256 intentAmount
        ) = abi.decode(message, (bytes, bytes, bytes, address, uint256));

        // 3. Transfer received funds to the target account *before* calling the executor.
        //    This ensures the executor can reliably check the balance.
        //    Requires this adapter contract to hold the funds temporarily from Across.
        IERC20(tokenSent).safeTransfer(account, amount);

        // 4. Call the core executor's standardized function
        // @dev idea: does it make sense to pass `amount` here to use as part of signature?
        superDestinationExecutor.processBridgedExecution(
            tokenSent,
            account,
            intentAmount,
            initData,
            executorCalldata,
            sigData // User signature + validation payload
        );

        // Note: Events related to execution success/failure should be emitted by SuperDestinationExecutor
    }

    // If Across V3 can send native currency, implement receive() or fallback()
    // receive() external payable {
    //     // Handle native currency transfer, decode message differently?
    //     // Requires careful thought on how native currency fits into the flow.
    // }
}
