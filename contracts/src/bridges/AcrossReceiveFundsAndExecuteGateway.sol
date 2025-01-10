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

/// @title AcrossReceiveFundsAndExecuteGateway
/// @notice This contract acts as a gateway for receiving funds from the Across Protocol
/// @notice and executing associated user operations.
/// @dev Example Scenario:
/// @custom:example
/// User wants to transfer 100 USDC from Ethereum to Arbitrum and execute an operation:
/// 1. User initiates transfer on Ethereum (source chain)
/// 2. Across Protocol processes this as two separate transactions (TX1 and TX2) on Arbitrum
///
/// Two possible cases can occur:
///
/// Case 1 (Rare) - User receives new funds between TX1 and TX2:
/// - TX1 arrives first and attempts to execute with 100 USDC
/// - If 100 USDC is available (from other sources), TX1 succeeds
/// - TX2 arrives second but fails due to nonce change from TX1
///
/// Case 2 (Typical) - No new funds between TX1 and TX2:
/// - TX1 arrives first but silently fails  as 100 USDC not yet available
/// - TX2 arrives second with the 100 USDC and succeeds
/// @dev Also in cross-chain rebalancing operations to receive funds and execute actions
/// @custom:example
///     Cross-chain Rebalance Flow Example:
///     1. Chain A: User initiates withdrawal from Superform
///     2. Chain A: Funds are bridged via Across
///     3. Chain B: This contract receives funds + message
///     4. Chain B: Contract transfers tokens to user's account
///     5. Chain B: Executes deposit into new Superform
contract AcrossReceiveFundsAndExecuteGateway is IAcrossV3Receiver, SuperRegistryImplementer {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable acrossSpokePool;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AcrossFundsReceivedButNotEnoughBalance(address indexed account);
    event AcrossFundsReceivedAndExecuted(address indexed account); /*//////////////////////////////////////////////////////////////
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
