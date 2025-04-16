// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { INexusFactory } from "../../vendor/nexus/INexusFactory.sol";
import { Execution, ExecutionLib as ERC7579ExecutionLib } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {
    ModeCode,
    ModeLib as ERC7579ModeLib,
    EXECTYPE_DEFAULT,
    CALLTYPE_BATCH,
    MODE_DEFAULT,
    ModePayload
} from "modulekit/accounts/common/lib/ModeLib.sol";

// Superform
import { SuperExecutorBase } from "./SuperExecutorBase.sol";
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { ISuperDestinationValidator } from "../interfaces/ISuperDestinationValidator.sol";

/// @title SuperDestinationExecutor
/// @author Superform Labs
/// @notice Generic executor for destination chains of Superform, processing bridged executions.
/// @notice This contract acts as the core logic gateway for receiving funds (via Adapters)
/// @notice and executing associated user operations validated by a SuperDestinationValidator.
/// @dev Receives calls from Adapter contracts (e.g., AcrossV3Adapter) via `processBridgedExecution`.
/// @dev Handles account creation, nonce management, signature validation, and execution forwarding.
contract SuperDestinationExecutor is SuperExecutorBase, ISuperDestinationExecutor {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    // Renamed events for clarity
    event SuperDestinationExecutorReceivedButNotEnoughBalance(address indexed account);
    event SuperDestinationExecutorReceivedButNoHooks(address indexed account);
    event SuperDestinationExecutorExecuted(address indexed account);
    event SuperDestinationExecutorFailed(address indexed account, string reason);
    event SuperDestinationExecutorFailedLowLevel(address indexed account, bytes lowLevelData);
    event AccountCreated(address indexed account, bytes32 salt);

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable superDestinationValidator;
    INexusFactory public immutable nexusFactory;
    mapping(address => uint256) public nonces;

    // https://docs.uniswap.org/contracts/v3/reference/periphery/interfaces/external/IERC1271
    bytes4 constant SIGNATURE_MAGIC_VALUE = bytes4(0x1626ba7e);

    // @dev 228 represents the length of the ExecutorEntry object (hooksAddresses, hooksData) for empty arrays + the 4
    // bytes of the `execute` function selector
    // @dev saves decoding gas
    uint256 constant EMPTY_EXECUTION_LENGTH = 228;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ACCOUNT();
    error INVALID_SIGNATURE();
    error ADDRESS_NOT_ACCOUNT();
    error ACCOUNT_NOT_CREATED();

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address registry_,
        address superDestinationValidator_,
        address nexusFactory_
    )
        SuperExecutorBase(registry_)
    {
        // Updated constructor validation
        if (superDestinationValidator_ == address(0) || nexusFactory_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        // acrossSpokePool = acrossSpokePool_; // Removed
        superDestinationValidator = superDestinationValidator_;
        nexusFactory = INexusFactory(nexusFactory_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function name() external pure override returns (string memory) {
        // Updated name
        return "SuperDestinationExecutor";
    }

    function version() external pure override returns (string memory) {
        return "0.0.1";
    }

    /*//////////////////////////////////////////////////////////////
                          CORE EXECUTION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperDestinationExecutor
    function processBridgedExecution(
        address tokenSent,
        address account,
        uint256 intentAmount,
        bytes memory initData,
        bytes memory executorCalldata,
        bytes memory userSignatureData
    )
        external
        override
    {
        // --- Account creation or validation ---
        if (account.code.length > 0) {
            string memory accountId = IERC7579Account(account).accountId();
            if (bytes(accountId).length == 0) revert ADDRESS_NOT_ACCOUNT();
        }
        // @dev we need to create the account
        if (initData.length > 0 && account.code.length == 0) {
            (bytes memory factoryInitData, bytes32 salt) = abi.decode(initData, (bytes, bytes32));
            address computedAddress = nexusFactory.createAccount(factoryInitData, salt);
            if (account != computedAddress) revert INVALID_ACCOUNT();
        }

        // Account must exist at this point
        if (account == address(0) || account.code.length == 0) revert ACCOUNT_NOT_CREATED();

        // --- Nonce & Signature Validation ---
        uint256 _nonce = nonces[account];
        bytes memory destinationData =
            abi.encode(_nonce, executorCalldata, uint64(block.chainid), account, address(this), tokenSent, intentAmount);

        // The userSignatureData is passed directly from the adapter
        bytes4 validationResult = ISuperDestinationValidator(superDestinationValidator).isValidDestinationSignature(
            account, abi.encode(userSignatureData, destinationData)
        );

        if (validationResult != SIGNATURE_MAGIC_VALUE) revert INVALID_SIGNATURE();

        // --- Balance Check ---
        // Token transfer is handled by the callee *before* this call.
        // We just check if the target account now has sufficient balance.
        IERC20 token = IERC20(tokenSent);
        if (intentAmount != 0 && token.balanceOf(account) < intentAmount) {
            emit SuperDestinationExecutorReceivedButNotEnoughBalance(account);
            // Nonce is NOT incremented if balance is insufficient
            return;
        }

        // --- Nonce Increment ---
        /// @dev increment the nonce here to allow multiple messages to be sent using current nonce
        ///      nonce increased after the account has enough balance (`token.balanceOf(account) < intentAmount`)
        ///      Example:
        ///       - User sends 100 USDC from chain A, intent amount is 200
        ///       - User sends 100 USDC from chain B, intent amount is 200
        ///      Nonce will be increased after both tx are finalized and `executorCalldata` is performed
        nonces[account]++;

        // --- Execute User Operation ---
        // Check if there's actual execution data to process
        if (executorCalldata.length <= EMPTY_EXECUTION_LENGTH) {
            emit SuperDestinationExecutorReceivedButNoHooks(account);
            return; // Nothing to execute
        }

        // Prepare execution parameters
        Execution[] memory execs = new Execution[](1);
        // Target is address(this) because SuperExecutorBase.execute handles the actual callData forwarding
        execs[0] = Execution({ target: address(this), value: 0, callData: executorCalldata });

        ModeCode modeCode = ERC7579ModeLib.encode({
            callType: CALLTYPE_BATCH,
            execType: EXECTYPE_DEFAULT,
            mode: MODE_DEFAULT,
            payload: ModePayload.wrap(bytes22(0))
        });

        // Execute via the target account's ERC7579 interface
        try IERC7579Account(account).executeFromExecutor(modeCode, ERC7579ExecutionLib.encodeBatch(execs)) {
            emit SuperDestinationExecutorExecuted(account);
        } catch Error(string memory reason) {
            // Log failure but do not revert the state change (nonce increment)
            emit SuperDestinationExecutorFailed(account, reason);
        } catch (bytes memory lowLevelData) {
            // Log low-level failure but do not revert the state change (nonce increment)
            emit SuperDestinationExecutorFailedLowLevel(account, lowLevelData);
        }
    }
}
