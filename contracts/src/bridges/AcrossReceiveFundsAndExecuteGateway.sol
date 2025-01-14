// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { UserOpData, PackedUserOperation } from "modulekit/ModuleKit.sol";
import { IEntryPoint } from "modulekit/external/ERC4337.sol";
import { BytesLib } from "../libraries/BytesLib.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

import { IAcrossV3Receiver } from "./interfaces/IAcrossV3Receiver.sol";
import { IAcrossV3Interpreter } from "../interfaces/vendors/bridges/across/IAcrossV3Interpreter.sol";

import { console2 } from "forge-std/console2.sol";

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
/// @notice  address account = BytesLib.toAddress(BytesLib.slice(message, 0, 20), 0);
/// @notice  uint256 intentAmount = BytesLib.toUint256(BytesLib.slice(message, 20, 32), 0);
/// @notice  PackedUserOperation memory userOp;
/// @notice  userOp.sender = BytesLib.toAddress(BytesLib.slice(message, 52, 20), 0);
/// @notice  userOp.nonce = BytesLib.toUint256(BytesLib.slice(message, 72, 32), 0);
/// @notice  uint256 initCodeLength = BytesLib.toUint256(BytesLib.slice(message, 104, 32), 0);
/// @notice  userOp.initCode = BytesLib.slice(message, 136, initCodeLength);
/// @notice  uint256 callDataLength = BytesLib.toUint256(BytesLib.slice(message, 136 + initCodeLength, 32), 0);
/// @notice  userOp.callData = BytesLib.slice(message, 168 + initCodeLength, callDataLength);
/// @notice  userOp.accountGasLimits = BytesLib.toBytes32(BytesLib.slice(message, 168 + initCodeLength + callDataLength,
/// 32), 0);
/// @notice  userOp.preVerificationGas = BytesLib.toUint256(BytesLib.slice(message, 200 + initCodeLength +
/// callDataLength, 32), 0);
/// @notice  userOp.gasFees = BytesLib.toBytes32(BytesLib.slice(message, 232 + initCodeLength + callDataLength, 32), 0);
/// @notice  uint256 paymasterLength = BytesLib.toUint256(BytesLib.slice(message, 264 + initCodeLength + callDataLength,
/// 32), 0);
/// @notice  userOp.paymasterAndData = BytesLib.slice(message, 296 + initCodeLength + callDataLength, paymasterLength);
/// @notice  uint256 signatureLength = BytesLib.toUint256(BytesLib.slice(message, 296 + initCodeLength + callDataLength
/// + paymasterLength, 32), 0);
/// @notice  userOp.signature = BytesLib.slice(message, 328 + initCodeLength + callDataLength + paymasterLength,
/// signatureLength);
/// @notice  address entrypoint = BytesLib.toAddress(BytesLib.slice(message, 328 + initCodeLength + callDataLength +
/// paymasterLength + signatureLength, 20), 0);

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
        // First 104 bytes are fixed positions for account, intentAmount, sender, and nonce
        // Base offsets
        uint256 offset = 0;

        // Fixed-length fields (first 104 bytes)
        address account = BytesLib.toAddress(BytesLib.slice(message, offset, 20), 0);
        offset += 20;
        console2.log("account", account);
        uint256 intentAmount = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;
        console2.log("intentAmount", intentAmount);

        PackedUserOperation memory userOp;
        userOp.sender = BytesLib.toAddress(BytesLib.slice(message, offset, 20), 0);
        offset += 20;
        console2.log("sender", userOp.sender);
        userOp.nonce = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;
        console2.log("nonce", userOp.nonce);

        // Dynamic-length fields
        uint256 initCodeLength = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;
        console2.log("initCodeLength");
        userOp.initCode = BytesLib.slice(message, offset, initCodeLength);
        offset += initCodeLength;
        console2.log("initCode");
        uint256 callDataLength = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;
        console2.log("callDataLength");
        userOp.callData = BytesLib.slice(message, offset, callDataLength);
        offset += callDataLength;

        userOp.accountGasLimits = BytesLib.toBytes32(BytesLib.slice(message, offset, 32), 0);
        offset += 32;

        userOp.preVerificationGas = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;

        userOp.gasFees = BytesLib.toBytes32(BytesLib.slice(message, offset, 32), 0);
        offset += 32;
        console2.log("gasFees");

        uint256 paymasterLength = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;
        userOp.paymasterAndData = BytesLib.slice(message, offset, paymasterLength);
        offset += paymasterLength;

        uint256 signatureLength = BytesLib.toUint256(BytesLib.slice(message, offset, 32), 0);
        offset += 32;
        console2.log("signatureLength", signatureLength);
        userOp.signature = BytesLib.slice(message, offset, signatureLength);
        offset += signatureLength;

        address entrypoint = BytesLib.toAddress(BytesLib.slice(message, offset, 20), 0);
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
        IEntryPoint(entrypoint).handleOps(userOps, _getSuperBundler());

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
