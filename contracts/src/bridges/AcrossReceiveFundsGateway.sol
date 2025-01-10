// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { IAcrossV3Receiver } from "../interfaces/vendors/bridges/across/IAcrossV3Receiver.sol";
import { IAcrossV3Interpreter } from "../interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

contract AcrossReceiveFundsGateway is IAcrossV3Receiver, SuperRegistryImplementer {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable acrossSpokePool;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AcrossFundsReceived(address indexed account, uint64 indexed sourceChainId, bytes32 indexed id);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    constructor(address registry_, address acrossSpokePool_) SuperRegistryImplementer(registry_) {
        acrossSpokePool = acrossSpokePool_;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAcrossV3Receiver
    function handleV3AcrossMessage(
        address tokenSent,
        uint256 amount,
        address, //relayer; not used
        bytes memory message
    )
        external
    {
        if (msg.sender != acrossSpokePool) revert INVALID_SENDER();

        // decode instruction
        (address account, uint64 sourceChainId, bytes32 id) = abi.decode(message, (address, uint64, bytes32));

        // send tokens to the smart account
        IERC20(tokenSent).safeTransfer(account, amount);

        // emit an event that should be picked up by the Super Bundler
        emit AcrossFundsReceived(account, sourceChainId, id);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the super gateway executor
    function _getSuperExecutor() internal view returns (address) {
        return superRegistry.getAddress(superRegistry.SUPER_EXECUTOR_ID());
    }
}
