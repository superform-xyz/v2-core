// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Vendor Interfaces
import { ILayerZeroComposer } from "../vendor/bridges/layerzero/ILayerZeroComposer.sol";
import { IStargate } from "../vendor/bridges/stargate/IStargate.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";

/// @title StargateAdapter
/// @author Superform Labs
/// @notice Receives LayerZero V2 compose messages from Stargate/OFT and forwards them to the SuperDestinationExecutor.
/// @notice This contract acts as a translator between LayerZero V2 compose callbacks and the core Superform execution
/// logic.
/// @dev Supports both Stargate pool tokens (taxi/bus modes) and generic OFT tokens
/// @dev Token delivery happens in a separate transaction (lzReceive) before lzCompose is called
/// @dev WARNING: This contract uses balance-based transfers. If a prior compose failed and left dust,
/// @dev the next successful compose will sweep all held tokens (including dust) to its target account.
contract StargateAdapter is ILayerZeroComposer {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Offset where the inner composeMsg starts in the OFTComposeMsgCodec-encoded message
    /// @dev Layout: nonce(8) + srcEid(4) + amountLD(32) + composeFrom(32) = 76 bytes header
    uint256 private constant COMPOSE_MSG_OFFSET = 76;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The LayerZero V2 EndpointV2 address
    /// @dev Same on all EVM chains: 0x1a44076050125825900e736c501f859c50fE728c
    address public immutable LZ_ENDPOINT;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a constructor argument is the zero address
    error ADDRESS_NOT_VALID();

    /// @notice Thrown when lzCompose is called by an address other than the LZ endpoint
    error INVALID_SENDER();

    /// @notice Thrown when native ETH transfer to the target account fails
    error ETH_TRANSFER_FAILED();

    /// @notice Thrown when the compose message is too short to contain the OFTComposeMsgCodec header
    error COMPOSE_MSG_TOO_SHORT();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a compose message is successfully executed
    /// @param account The target account that received the tokens
    /// @param tokenSent The token address transferred (address(0) for native ETH)
    /// @param amount The amount of tokens transferred
    event ComposeExecuted(address indexed account, address indexed tokenSent, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param lzEndpoint_ The LayerZero V2 EndpointV2 address
    /// @param superDestinationExecutor_ The SuperDestinationExecutor address
    constructor(address lzEndpoint_, address superDestinationExecutor_) {
        if (lzEndpoint_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        LZ_ENDPOINT = lzEndpoint_;
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
    }

    /*//////////////////////////////////////////////////////////////
                                 RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @dev Accepts native ETH from StargatePoolNative during lzReceive token credit
    /// @dev WARNING: Any ETH sent to this contract will be forwarded to the next compose account
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            LAYERZERO COMPOSE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILayerZeroComposer
    /// @dev Decodes the OFTComposeMsgCodec message, transfers tokens to the target account,
    ///      and forwards the execution payload to SuperDestinationExecutor
    /// @dev The _from parameter is the destination Stargate pool or OFT contract (NOT the source chain sender)
    /// @dev Uses balance-based transfers: transfers full adapter balance of the identified token
    function lzCompose(
        address _from,
        bytes32, // _guid
        bytes calldata _message,
        address, // _executor
        bytes calldata // _extraData
    )
        external
        payable
        override
    {
        // 1. Validate sender: only the LZ endpoint can call lzCompose
        if (msg.sender != LZ_ENDPOINT) revert INVALID_SENDER();

        // 2. Validate message length: must contain OFTComposeMsgCodec header
        if (_message.length < COMPOSE_MSG_OFFSET) revert COMPOSE_MSG_TOO_SHORT();

        // 3. Decode the inner application payload (skip 76-byte OFTComposeMsgCodec header)
        (
            bytes memory initData,
            bytes memory executorCalldata,
            address account,
            address[] memory dstTokens,
            uint256[] memory intentAmounts,
            bytes memory sigData
        ) = abi.decode(_message[COMPOSE_MSG_OFFSET:], (bytes, bytes, address, address[], uint256[], bytes));

        // 4. Identify token via _from.token()
        //    - Stargate ERC20 pools: returns underlying ERC20 address
        //    - StargatePoolNative: returns address(0) for ETH
        //    - OFT contracts: returns address(this) (OFT IS the token)
        //    - OFTAdapter contracts: returns underlying ERC20 address
        address tokenSent = IStargate(_from).token();

        // 5. Transfer received funds to the target account before calling the executor
        //    This ensures the executor can reliably check the balance.
        //    Account is encoded in the merkle tree and validated by the destination executor
        if (tokenSent == address(0)) {
            // Native ETH path
            uint256 ethBalance = address(this).balance;
            (bool success,) = account.call{ value: ethBalance }("");
            if (!success) revert ETH_TRANSFER_FAILED();
            emit ComposeExecuted(account, tokenSent, ethBalance);
        } else {
            // ERC20 path
            uint256 balance = IERC20(tokenSent).balanceOf(address(this));
            IERC20(tokenSent).safeTransfer(account, balance);
            emit ComposeExecuted(account, tokenSent, balance);
        }

        // 6. Call the core executor's standardized function
        SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            tokenSent,
            account,
            dstTokens,
            intentAmounts,
            initData,
            executorCalldata,
            sigData
        );
    }
}
