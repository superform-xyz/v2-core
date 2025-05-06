// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IDlnDestination } from "../../vendor/debridge/IDlnDestination.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";
import { IExternalCallExecutor } from "../../vendor/bridges/debridge/IExternalCallExecutor.sol";

/// @title DebridgeAdapter
/// @author Superform Labs
/// @notice Receives messages from the Debridge protocol and forwards them to the SuperDestinationExecutor.
/// @notice This contract acts as a translator between the Debridge protocol and the core Superform execution logic.
contract DebridgeAdapter is IExternalCallExecutor {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    ISuperDestinationExecutor public immutable superDestinationExecutor;
    address public immutable externalCallAdapter;
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ADDRESS_NOT_VALID();
    error ON_ETHER_RECEIVED_FAILED();
    error ONLY_EXTERNAL_CALL_ADAPTER();

    constructor(address dlnDestination, address superDestinationExecutor_) {
        if (superDestinationExecutor_ == address(0) || dlnDestination == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        superDestinationExecutor = ISuperDestinationExecutor(superDestinationExecutor_);
        address _externalCallAdapter = IDlnDestination(dlnDestination).externalCallAdapter();
        if (_externalCallAdapter == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        externalCallAdapter = _externalCallAdapter;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IExternalCallExecutor
    function onEtherReceived(
        bytes32,
        address,
        bytes memory _payload
    )
        external
        payable
        returns (bool callSucceeded, bytes memory callResult)
    {
        _onlyExternalCallAdapter();
        (
            bytes memory initData,
            bytes memory executorCalldata,
            address account,
            uint256 intentAmount,
            bytes memory sigData
        ) = _decodeMessage(_payload);

        // 1. Transfer received funds to the target account *before* calling the executor.
        //    This ensures the executor can reliably check the balance.
        //    Requires this adapter contract to hold the funds temporarily from Debridge.
        //    Account is encoded in the merkle tree and validated by the destination executor
        (bool success,) = account.call{ value: address(this).balance }("");
        if (!success) revert ON_ETHER_RECEIVED_FAILED();

        // 2. Call the core executor's standardized function
        _handleMessageReceived(address(0), initData, executorCalldata, account, intentAmount, sigData);

        return (true, "");
    }

    /// @inheritdoc IExternalCallExecutor
    function onERC20Received(
        bytes32,
        address _token,
        uint256 _transferredAmount,
        address,
        bytes memory _payload
    )
        external
        returns (bool callSucceeded, bytes memory callResult)
    {
        _onlyExternalCallAdapter();
        (
            bytes memory initData,
            bytes memory executorCalldata,
            address account,
            uint256 intentAmount,
            bytes memory sigData
        ) = _decodeMessage(_payload);

        // 1. Transfer received funds to the target account *before* calling the executor.
        //    This ensures the executor can reliably check the balance.
        //    Requires this adapter contract to hold the funds temporarily from Debridge.
        //    Account is encoded in the merkle tree and validated by the destination executor
        IERC20(_token).safeTransfer(account, _transferredAmount);

        // 2. Call the core executor's standardized function
        _handleMessageReceived(_token, initData, executorCalldata, account, intentAmount, sigData);

        return (true, "");
    }

    /*//////////////////////////////////////////////////////////////
                                PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    function _onlyExternalCallAdapter() private view {
        if (msg.sender != externalCallAdapter) revert ONLY_EXTERNAL_CALL_ADAPTER();
    }

    function _handleMessageReceived(address tokenSent, bytes memory initData, bytes memory executorCalldata, address account, uint256 intentAmount, bytes memory sigData) private {
        // Call the core executor's standardized function
        superDestinationExecutor.processBridgedExecution(
            tokenSent,
            account,
            intentAmount,
            initData,
            executorCalldata,
            sigData // User signature + validation payload
        );
    }

    function _decodeMessage(bytes memory message)
        private
        pure
        returns (
            bytes memory initData,
            bytes memory executorCalldata,
            address account,
            uint256 intentAmount,
            bytes memory sigData
        )
    {
        (initData, executorCalldata, account, intentAmount, sigData) =
            abi.decode(message, (bytes, bytes, address, uint256, bytes));
    }
}
