// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IMinimalEntryPoint, PackedUserOperation } from "../../vendor/account-abstraction/IMinimalEntryPoint.sol";
import { BytesLib } from "../../vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IAcrossV3Receiver } from "../../vendor/bridges/across/IAcrossV3Receiver.sol";

/// @title AcrossReceiveFundsAndExecuteGateway
/// @author Superform Labs
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
contract AcrossReceiveFundsAndExecuteGateway is IAcrossV3Receiver {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable acrossSpokePool;
    address public immutable entryPointAddress;
    address payable public immutable superBundler;

    error ADDRESS_NOT_VALID();

    constructor(address acrossSpokePool_, address entryPointAddress_, address superBundler_) {
        if (acrossSpokePool_ == address(0)) revert ADDRESS_NOT_VALID();
        if (entryPointAddress_ == address(0)) revert ADDRESS_NOT_VALID();
        acrossSpokePool = acrossSpokePool_;
        entryPointAddress = entryPointAddress_;
        superBundler = payable(superBundler_);
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
        uint256 offset = 0;
        address account = BytesLib.toAddress(BytesLib.slice(message, offset, 20), 0);
        offset += 20;

        uint256 intentAmount = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;

        PackedUserOperation memory userOp;
        userOp.sender = BytesLib.toAddress(BytesLib.slice(message, offset, 20), 0);
        offset += 20;

        userOp.nonce = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;

        uint256 codeLength = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;

        userOp.initCode = BytesLib.slice(message, offset, codeLength);
        offset += codeLength;

        codeLength = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;

        userOp.callData = BytesLib.slice(message, offset, codeLength);
        offset += codeLength;

        userOp.accountGasLimits = BytesLib.toBytes32(BytesLib.slice(message, offset, 32), 0);
        offset += 32;

        userOp.preVerificationGas = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;

        userOp.gasFees = BytesLib.toBytes32(BytesLib.slice(message, offset, 32), 0);
        offset += 32;

        codeLength = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;

        userOp.paymasterAndData = BytesLib.slice(message, offset, codeLength);
        offset += codeLength;

        userOp.signature = BytesLib.slice(message, offset, message.length - offset);

        IERC20 token = IERC20(tokenSent);

        // send tokens to the smart account
        token.safeTransfer(account, amount);
        // Check if the account has sufficient balance before proceeding
        if (intentAmount != 0 && token.balanceOf(account) < intentAmount) {
            emit AcrossFundsReceivedButNotEnoughBalance(account);
            return;
        }

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        // Execute the userOp through EntryPoint
        IMinimalEntryPoint(entryPointAddress).handleOps(userOps, superBundler);

        emit AcrossFundsReceivedAndExecuted(account);
    }
}
