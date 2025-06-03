// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {INexusFactory} from "../../vendor/nexus/INexusFactory.sol";
import {Execution, ExecutionLib as ERC7579ExecutionLib} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {IERC7579Account} from "modulekit/accounts/common/interfaces/IERC7579Account.sol";
import {
    ModeCode,
    ModeLib as ERC7579ModeLib,
    EXECTYPE_DEFAULT,
    CALLTYPE_BATCH,
    MODE_DEFAULT,
    ModePayload
} from "modulekit/accounts/common/lib/ModeLib.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Superform
import {SuperExecutorBase} from "./SuperExecutorBase.sol";
import {ISuperExecutor} from "../interfaces/ISuperExecutor.sol";
import {ISuperDestinationExecutor} from "../interfaces/ISuperDestinationExecutor.sol";
import {ISuperDestinationValidator} from "../interfaces/ISuperDestinationValidator.sol";

import "forge-std/console2.sol";

/// @title SuperDestinationExecutor
/// @author Superform Labs
/// @notice Generic executor for destination chains of Superform, processing bridged executions
/// @dev Implements ISuperDestinationExecutor for receiving funds via Adapters and executing validated cross-chain
/// operations
///      Handles account creation, signature validation, and execution forwarding
contract SuperDestinationExecutor is SuperExecutorBase, ISuperDestinationExecutor {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Address of the validator contract used to verify cross-chain signatures
    /// @dev Used to validate signatures in the processBridgedExecution method
    address public immutable SUPER_DESTINATION_VALIDATOR;

    /// @notice Factory contract used to create new smart accounts when needed
    /// @dev Creates deterministic smart accounts during cross-chain operations
    INexusFactory public immutable NEXUS_FACTORY;

    /// @notice Tracks which merkle roots have been used by each user address
    /// @dev Prevents replay attacks by ensuring each merkle root can only be used once per user
    mapping(address user => mapping(bytes32 merkleRoot => bool used)) public usedMerkleRoots;

    /// @notice Maps accounts to their allowed callers
    mapping(address account => mapping(address caller => bool isAllowed)) internal _allowedCallers;
    mapping(address => EnumerableSet.AddressSet) private _allowedCallersSet;

    /// @notice Maps accounts to their owners
    mapping(address account => address owner) internal _accountOwners;

    /// @notice Magic value returned by ERC-1271 contracts when a signature is valid
    /// @dev From EIP-1271 standard:
    /// https://docs.uniswap.org/contracts/v3/reference/periphery/interfaces/external/IERC1271
    bytes4 internal constant SIGNATURE_MAGIC_VALUE = bytes4(0x1626ba7e);

    /// @notice Length of an empty execution data structure
    /// @dev 228 represents the length of the ExecutorEntry object (hooksAddresses, hooksData) for empty arrays
    ///      plus the 4 bytes of the `execute` function selector
    ///      Used to check if actual hook execution data is present without full decoding
    uint256 internal constant EMPTY_EXECUTION_LENGTH = 228;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the SuperDestinationExecutor with required references
    /// @param ledgerConfiguration_ Address of the ledger configuration contract for fee calculations
    /// @param superDestinationValidator_ Address of the validator contract used to verify cross-chain messages
    /// @param nexusFactory_ Address of the account factory used to create new smart accounts
    constructor(address ledgerConfiguration_, address superDestinationValidator_, address nexusFactory_)
        SuperExecutorBase(ledgerConfiguration_)
    {
        // Validate critical contract references
        if (superDestinationValidator_ == address(0) || nexusFactory_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        SUPER_DESTINATION_VALIDATOR = superDestinationValidator_;
        NEXUS_FACTORY = INexusFactory(nexusFactory_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperExecutor
    function name() external pure override returns (string memory) {
        // Updated name
        return "SuperDestinationExecutor";
    }

    /// @inheritdoc ISuperExecutor
    function version() external pure override returns (string memory) {
        return "0.0.1";
    }

    /// @inheritdoc ISuperDestinationExecutor
    function isMerkleRootUsed(address user, bytes32 merkleRoot) external view returns (bool) {
        return usedMerkleRoots[user][merkleRoot];
    }

    /// @inheritdoc ISuperDestinationExecutor
    function getAccountOwner(address account) public view returns (address) {
        return _accountOwners[account];
    }

    /// @inheritdoc ISuperDestinationExecutor
    function isCallerAllowed(address account) public view returns (bool) {
        console2.log("-- account ", account);
        console2.log("-- msg.sender ", msg.sender);
        console2.log("-- _allowedCallers[account][msg.sender] ", _allowedCallers[account][msg.sender]);
        return _allowedCallers[account][msg.sender];
    }

    /// @inheritdoc ISuperDestinationExecutor
    function getAllowedCallers(address account) external view returns (address[] memory) {
        return _allowedCallersSet[account].values();
    }

    /*//////////////////////////////////////////////////////////////
                          MODULE MANAGEMENT LOGIC
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperDestinationExecutor
    function setAllowedCaller(address account_, address[] memory callers_, bool allowed_) external {
        if (!_initialized[account_]) revert NOT_INITIALIZED();
        if (getAccountOwner(account_) != msg.sender) revert CALLER_NOT_ALLOWED();

        uint256 len = callers_.length;
        for (uint256 i = 0; i < len; ++i) {
            address _caller = callers_[i];
            if (allowed_) {
                if (_allowedCallers[account_][_caller]) continue;

                _allowedCallers[account_][_caller] = true;
                _allowedCallersSet[account_].add(_caller);
            } else {
                if (!_allowedCallers[account_][_caller]) continue;

                _allowedCallers[account_][_caller] = false;
                _allowedCallersSet[account_].remove(_caller);
            }
        }

        emit AllowedCallerSet(account_, callers_, allowed_);
    }

    function onInstall(bytes calldata data) external override(SuperExecutorBase) {
        if (_initialized[msg.sender]) revert ALREADY_INITIALIZED();

        if (data.length > 0) {
            (address owner, address[] memory allowedCallers) = abi.decode(data, (address, address[]));
            if (owner == address(0)) revert ZERO_ADDRESS();
            _accountOwners[msg.sender] = owner;

            uint256 len = allowedCallers.length;
            for (uint256 i; i < len; ++i) {
                _allowedCallers[msg.sender][allowedCallers[i]] = true;
            }
        }

        _initialized[msg.sender] = true;
    }

    function onUninstall(bytes calldata) external virtual override(SuperExecutorBase) {
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();
        _initialized[msg.sender] = false;
        delete _accountOwners[msg.sender];
        delete _allowedCallersSet[msg.sender];
        address[] memory _callers = _allowedCallersSet[msg.sender].values();
        uint256 len = _callers.length;
        for (uint256 i; i < len; ++i) {
            delete _allowedCallers[msg.sender][_callers[i]];
        }
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
    ) external override {
        account = _validateOrCreateAccount(account, initData);
        if (!isCallerAllowed(account)) revert CALLER_NOT_ALLOWED();

        bytes32 merkleRoot = _decodeMerkleRoot(userSignatureData);

        // --- Signature Validation ---
        // DestinationData encodes both the adapter (msg.sender) and the executor (address(this))
        //  this is useful to avoid replay attacks on a different group of executor <> sender (adapter)
        // Note: the msgs.sender doesn't necessarily match an adapter address
        bytes memory destinationData =
            abi.encode(executorCalldata, uint64(block.chainid), account, address(this), dstTokens, intentAmounts);

        // The userSignatureData is passed directly from the adapter
        bytes4 validationResult = ISuperDestinationValidator(SUPER_DESTINATION_VALIDATOR).isValidDestinationSignature(
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
        execs[0] = Execution({target: address(this), value: 0, callData: executorCalldata});

        ModeCode modeCode = ERC7579ModeLib.encode({
            callType: CALLTYPE_BATCH,
            execType: EXECTYPE_DEFAULT,
            mode: MODE_DEFAULT,
            payload: ModePayload.wrap(bytes22(0))
        });

        try IERC7579Account(account).executeFromExecutor(modeCode, ERC7579ExecutionLib.encodeBatch(execs)) {
            emit SuperDestinationExecutorExecuted(account);
        } catch Panic(uint256 errorCode) {
            emit SuperDestinationExecutorPanicFailed(account, errorCode);
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
            address computedAddress = NEXUS_FACTORY.createAccount(factoryInitData, salt);
            if (account != computedAddress) revert INVALID_ACCOUNT();
        }

        if (account == address(0) || account.code.length == 0) revert ACCOUNT_NOT_CREATED();

        return account;
    }

    function _decodeMerkleRoot(bytes memory userSignatureData) private pure returns (bytes32) {
        (, bytes32 merkleRoot,,) = abi.decode(userSignatureData, (uint48, bytes32, bytes32[], bytes));
        return merkleRoot;
    }

    function _validateBalances(address account, address[] memory dstTokens, uint256[] memory intentAmounts)
        private
        returns (bool)
    {
        uint256 len = dstTokens.length;
        for (uint256 i; i < len; i++) {
            address _token = dstTokens[i];
            uint256 _intentAmount = intentAmounts[i];

            if (_token == address(0)) {
                if (_intentAmount != 0 && account.balance < _intentAmount) {
                    emit SuperDestinationExecutorReceivedButNotEnoughBalance(
                        account, _token, _intentAmount, account.balance
                    );
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
