// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { UserOpData, PackedUserOperation } from "modulekit/ModuleKit.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { IAcrossV3Receiver } from "../interfaces/vendors/bridges/across/IAcrossV3Receiver.sol";
import { IAcrossV3Interpreter } from "../interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

/*

/// @title UserOpData
/// @param userOp The user operation
/// @param userOpHash The hash of the user operation
/// @param entrypoint The entrypoint contract
struct UserOpData {
    PackedUserOperation userOp;
    bytes32 userOpHash;
    IEntryPoint entrypoint;
}
*/
contract AcrossReceiveFundsAndExecuteGateway is IAcrossV3Receiver, SuperRegistryImplementer {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable acrossSpokePool;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AcrossFundsReceivedAndExecuted(address indexed account);
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

        (address account, UserOpData memory userOpData) = abi.decode(message, (address, UserOpData));

        // send tokens to the smart account
        IERC20(tokenSent).safeTransfer(account, amount);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOpData.userOp;
        // Execute the userOp through EntryPoint
        userOpData.entrypoint.handleOps(userOps, _getSuperBundler());

        // emit an event that should be picked up by the Super Bundler
        emit AcrossFundsReceivedAndExecuted(account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the super bundler
    function _getSuperBundler() internal view returns (address payable) {
        return payable(superRegistry.getAddress(superRegistry.SUPER_BUNDLER_ID()));
    }
}
