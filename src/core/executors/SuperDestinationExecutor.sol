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
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable superDestinationValidator;
    INexusFactory public immutable nexusFactory;

    // Track used merkle roots per user
    mapping(address user => mapping(bytes32 merkleRoot => bool used)) public usedMerkleRoots;

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
    error MERKLE_ROOT_ALREADY_USED();

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address ledgerConfiguration_,
        address superDestinationValidator_,
        address nexusFactory_
    )
        SuperExecutorBase(ledgerConfiguration_)
    {
        // Updated constructor validation
        if (superDestinationValidator_ == address(0) || nexusFactory_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
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

    /// @inheritdoc ISuperDestinationExecutor
    function isMerkleRootUsed(address user, bytes32 merkleRoot) external view returns (bool) {
        return usedMerkleRoots[user][merkleRoot];
    }

    /*//////////////////////////////////////////////////////////////
                          CORE EXECUTION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperDestinationExecutor
    function processBridgedExecution(
        address,
        address account,
        address[] memory dstTokens,
        uint256[] memory intentAmounts,
        bytes memory initData,
        bytes memory executorCalldata,
        bytes memory userSignatureData
    )
        external
        override
    {
        account = _validateOrCreateAccount(account, initData);

        bytes32 merkleRoot = _decodeMerkleRoot(userSignatureData);

        bytes memory destinationData = abi.encode(
            executorCalldata, uint64(block.chainid), account, address(this), dstTokens, intentAmounts
        );

        bytes4 validationResult = ISuperDestinationValidator(superDestinationValidator).isValidDestinationSignature(
            account, abi.encode(userSignatureData, destinationData)
        );

        if (validationResult != SIGNATURE_MAGIC_VALUE) revert INVALID_SIGNATURE();

        if (!_validateBalances(account, dstTokens, intentAmounts)) return;

        if (usedMerkleRoots[account][merkleRoot]) revert MERKLE_ROOT_ALREADY_USED();
        usedMerkleRoots[account][merkleRoot] = true;

        if (executorCalldata.length <= EMPTY_EXECUTION_LENGTH) {
            emit SuperDestinationExecutorReceivedButNoHooks(account);
            return;
        }

        Execution[] memory execs = new Execution[](1);
        execs[0] = Execution({ target: address(this), value: 0, callData: executorCalldata });

        ModeCode modeCode = ERC7579ModeLib.encode({
            callType: CALLTYPE_BATCH,
            execType: EXECTYPE_DEFAULT,
            mode: MODE_DEFAULT,
            payload: ModePayload.wrap(bytes22(0))
        });

        try IERC7579Account(account).executeFromExecutor(modeCode, ERC7579ExecutionLib.encodeBatch(execs)) {
            emit SuperDestinationExecutorExecuted(account);
        } catch Error(string memory reason) {
            emit SuperDestinationExecutorFailed(account, reason);
        } catch (bytes memory lowLevelData) {
            emit SuperDestinationExecutorFailedLowLevel(account, lowLevelData);
        }
    }

    function _validateOrCreateAccount(address account, bytes memory initData) internal returns (address) {
        if (account.code.length > 0) {
            string memory accountId = IERC7579Account(account).accountId();
            if (bytes(accountId).length == 0) revert ADDRESS_NOT_ACCOUNT();
        }

        if (initData.length > 0 && account.code.length == 0) {
            (bytes memory factoryInitData, bytes32 salt) = abi.decode(initData, (bytes, bytes32));
            address computedAddress = nexusFactory.createAccount(factoryInitData, salt);
            if (account != computedAddress) revert INVALID_ACCOUNT();
        }

        if (account == address(0) || account.code.length == 0) revert ACCOUNT_NOT_CREATED();

        return account;
    }

    function _decodeMerkleRoot(bytes memory userSignatureData) private pure returns (bytes32) {
        (, bytes32 merkleRoot,,) = abi.decode(userSignatureData, (uint48, bytes32, bytes32[], bytes));
        return merkleRoot;
    }

    function _validateBalances(address account, address[] memory dstTokens, uint256[] memory intentAmounts) private returns (bool) {
        uint256 len = dstTokens.length;
        for (uint256 i = 0; i < len; i++) {
            address _token = dstTokens[i];
            uint256 _intentAmount = intentAmounts[i];

            if (_token == address(0)) {
                if (_intentAmount != 0 && account.balance < _intentAmount) {
                    emit SuperDestinationExecutorReceivedButNotEnoughBalance(account, _token, _intentAmount, account.balance);
                    return false;
                }
            } else {
                uint256 _balance = IERC20(_token).balanceOf(account);
                if (_intentAmount != 0 && _balance < _intentAmount) {
                    emit SuperDestinationExecutorReceivedButNotEnoughBalance(account, _token, _intentAmount, _balance);
                    return false;
                }
            }
        }
        return true;
    }

}
