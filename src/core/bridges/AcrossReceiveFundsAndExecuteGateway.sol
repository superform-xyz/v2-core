// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Superform
import { IMinimalEntryPoint } from "../../vendor/account-abstraction/IMinimalEntryPoint.sol";
import { BytesLib } from "../../vendor/BytesLib.sol";
import { IAcrossV3Receiver } from "../../vendor/bridges/across/IAcrossV3Receiver.sol";
import { ISuperNativePaymaster } from "../interfaces/ISuperNativePaymaster.sol";
import { PaymasterGasCalculator } from "../libraries/PaymasterGasCalculator.sol";
import { ISuperGasTank } from "../interfaces/ISuperGasTank.sol";
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

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
contract AcrossReceiveFundsAndExecuteGateway is IAcrossV3Receiver, SuperRegistryImplementer {
    using SafeERC20 for IERC20;
    using PaymasterGasCalculator for PackedUserOperation;
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable acrossSpokePool;
    address public immutable entryPointAddress;
    address payable public immutable superBundler;
    address public immutable superNativePaymaster;

    error ADDRESS_NOT_VALID();

    receive() external payable { }

    constructor(
        address acrossSpokePool_,
        address entryPointAddress_,
        address superBundler_,
        address superRegistry_
    )
        SuperRegistryImplementer(superRegistry_)
    {
        if (acrossSpokePool_ == address(0)) revert ADDRESS_NOT_VALID();
        if (entryPointAddress_ == address(0)) revert ADDRESS_NOT_VALID();
        if (superBundler_ == address(0)) revert ADDRESS_NOT_VALID();
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

        if (userOp.paymasterAndData.length == 0) {
            // Execute the userOp through EntryPoint
            try IMinimalEntryPoint(entryPointAddress).handleOps(userOps, superBundler) {
                emit AcrossFundsReceivedAndExecuted(account);
            } catch {
                // no action, as funds are already transferred
                emit AcrossFundsReceivedButExecutionFailed(account);
            }
        } else {
            /// @dev TODO: note to auditors - users can grieve gas tank out of all its value
            /// this is currently unfixed (issue 8 of previous audit)
            uint256 gasCost = userOps[0].calculateGasCostInWei();
            address superGasTank = superRegistry.getAddress(keccak256("SUPER_GAS_TANK_ID"));
            if (address(this).balance < gasCost) {
                uint256 balanceDiff = gasCost - address(this).balance;
                ISuperGasTank(superGasTank).withdrawETH(balanceDiff, payable(address(this)));
            }
            // Execute the userOp through SuperNativePaymaster
            try ISuperNativePaymaster(superRegistry.getAddress(keccak256("SUPER_NATIVE_PAYMASTER_ID"))).handleOps{
                value: gasCost
            }(userOps) { } catch {
                // no action, as funds are already transferred
                emit AcrossFundsReceivedButExecutionFailed(account);
                return;
            }

            emit AcrossFundsReceivedAndExecuted(account);
        }
    }
}
