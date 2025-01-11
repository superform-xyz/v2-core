// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { UserOpData, PackedUserOperation } from "modulekit/ModuleKit.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { IAcrossV3Receiver } from "./interfaces/IAcrossV3Receiver.sol";

/// @title AcrossReceiveFundsAndExecuteGateway
/// @notice This contract acts as a gateway for receiving funds from the Across Protocol
/// @notice and executing associated user operations.
contract AcrossReceiveFundsAndExecuteGateway is IAcrossV3Receiver, SuperRegistryImplementer {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable acrossSpokePool;

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
        (address account, uint256 intentAmount, UserOpData memory userOpData) =
            abi.decode(message, (address, uint256, UserOpData));
        IERC20 token = IERC20(tokenSent);

        // send tokens to the smart account
        token.safeTransfer(account, amount);
        // Check if the account has sufficient balance before proceeding
        if (intentAmount != 0 && token.balanceOf(account) < intentAmount) {
            emit AcrossFundsReceivedButNotEnoughBalance(account);
            return;
        }

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOpData.userOp;
        // Execute the userOp through EntryPoint
        userOpData.entrypoint.handleOps(userOps, _getSuperBundler());

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
