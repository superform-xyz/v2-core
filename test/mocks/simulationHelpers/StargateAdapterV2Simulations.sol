// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Protocol Interfaces
import { ILayerZeroComposer } from "../../../src/vendor/bridges/layerzero/ILayerZeroComposer.sol";
import { IStargate } from "../../../src/vendor/bridges/stargate/IStargate.sol";
import { ITokenMessaging } from "../../../src/vendor/bridges/stargate/ITokenMessaging.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/// @title StargateAdapterV2Simulations
/// @author Superform Labs
/// @notice Strict simulation equivalent of StargateAdapterV2
/// @dev This contract is never deployed. Its runtime is installed at a live Stargate adapter
///      with a state override after its constructor-configured immutables are patched.
///      It preserves the production lzCompose -> handleCompose -> destination executor call
///      layering while turning every best-effort failure into a top-level revert.
contract StargateAdapterV2Simulations is ILayerZeroComposer, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Offset of the inner compose payload after the Stargate OFT header
    uint256 private constant COMPOSE_MSG_OFFSET = 76;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The LayerZero V2 EndpointV2 address
    address public immutable LZ_ENDPOINT;

    /// @notice The Stargate V2 TokenMessaging contract for pool registration verification
    ITokenMessaging public immutable TOKEN_MESSAGING;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// @notice OFTs allowed to bypass TokenMessaging pool registration
    /// @dev Must remain in the same storage position as StargateAdapterV2
    mapping(address oft => bool allowed) public allowedOFTs;

    /// @notice Enumerates the live adapter's allowed OFTs
    /// @dev Must remain in the same storage position as StargateAdapterV2
    address[] public allowedOFTsList;

    /// @notice Claimable balances recorded by the live adapter
    /// @dev Must remain in the same storage position as StargateAdapterV2
    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Holds fields extracted from sigData's destination proof
    struct ExtractedData {
        address account;
        bytes executorCalldata;
        address[] dstTokens;
        uint256[] intentAmounts;
        bool found;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ADDRESS_NOT_VALID();
    error INVALID_SENDER();
    error COMPOSE_MSG_TOO_SHORT(uint256 messageLength);
    error UNREGISTERED_POOL(address pool);
    error NO_DST_PROOF_FOR_CHAIN(uint64 chainId);
    error ACCOUNT_NOT_VALID();
    error INSUFFICIENT_ADAPTER_BALANCE(address token, uint256 required, uint256 available);
    error TRANSFER_FAILED(address token, address account, uint256 amount);
    error COMPOSE_EXECUTION_FAILED();
    error ETH_TRANSFER_FAILED();
    error INSUFFICIENT_FAILED_BALANCE();
    error ZERO_AMOUNT();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSucceeded(bytes32 indexed guid, address indexed account, address indexed tokenSent, uint256 amount);
    event TransferFailed(bytes32 indexed guid, address indexed account, address indexed token, uint256 amount);
    event ExecutionFailed(bytes32 indexed guid, address indexed account);
    event ComposeMsgTooShort(bytes32 indexed guid, uint256 messageLength);
    event ComposeDecodeFailed(bytes32 indexed guid);
    event TokenResolutionFailed(bytes32 indexed guid, address indexed from);
    event UnregisteredPool(bytes32 indexed guid, address indexed from);
    event NoDstProofForChain(bytes32 indexed guid, uint64 chainId);
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address lzEndpoint_, address tokenMessaging_, address superDestinationExecutor_) {
        if (lzEndpoint_ == address(0) || tokenMessaging_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        LZ_ENDPOINT = lzEndpoint_;
        TOKEN_MESSAGING = ITokenMessaging(tokenMessaging_);
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
    }

    /*//////////////////////////////////////////////////////////////
                                 RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @dev Accepts native assets already delivered by Stargate
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            LAYERZERO COMPOSE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILayerZeroComposer
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address,
        bytes calldata
    )
        external
        payable
        override
    {
        if (msg.sender != LZ_ENDPOINT) revert INVALID_SENDER();
        if (_message.length < COMPOSE_MSG_OFFSET) revert COMPOSE_MSG_TOO_SHORT(_message.length);

        if (TOKEN_MESSAGING.assetIds(_from) == 0 && !allowedOFTs[_from]) {
            revert UNREGISTERED_POOL(_from);
        }

        uint256 amountLD = uint256(bytes32(_message[12:44]));
        address composeFrom = address(uint160(uint256(bytes32(_message[44:76]))));
        address tokenSent = IStargate(_from).token();

        try this.handleCompose(_guid, _message, tokenSent, amountLD, composeFrom) { }
        catch (bytes memory reason) {
            _revert(reason);
        }
    }

    /// @notice Strict external compose handler preserving Stargate's production self-call
    function handleCompose(
        bytes32 _guid,
        bytes calldata _message,
        address tokenSent,
        uint256 amountLD,
        address composeFrom
    )
        external
    {
        if (msg.sender != address(this)) revert INVALID_SENDER();

        (bytes memory initData, bytes memory sigDataRaw) = abi.decode(_message[COMPOSE_MSG_OFFSET:], (bytes, bytes));
        ExtractedData memory extracted = _extractFromSigData(sigDataRaw);

        if (!extracted.found) revert NO_DST_PROOF_FOR_CHAIN(uint64(block.chainid));

        _handleTransferAndExecution(
            _guid, tokenSent, amountLD, composeFrom, extracted.account, initData, sigDataRaw, extracted
        );
    }

    /// @notice Executes the strict transfer and destination executor path
    function _handleTransferAndExecution(
        bytes32 _guid,
        address tokenSent,
        uint256 amountLD,
        address,
        address account,
        bytes memory initData,
        bytes memory sigDataRaw,
        ExtractedData memory extracted
    )
        private
    {
        uint256 preBalance =
            tokenSent == address(0) ? address(this).balance : IERC20(tokenSent).balanceOf(address(this));
        if (account == address(0)) revert ACCOUNT_NOT_VALID();
        if (!_tryTransfer(tokenSent, account, amountLD)) {
            if (preBalance < amountLD) {
                revert INSUFFICIENT_ADAPTER_BALANCE(tokenSent, amountLD, preBalance);
            }
            revert TRANSFER_FAILED(tokenSent, account, amountLD);
        }

        emit TransferSucceeded(_guid, account, tokenSent, amountLD);

        try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            tokenSent,
            account,
            extracted.dstTokens,
            extracted.intentAmounts,
            initData,
            extracted.executorCalldata,
            sigDataRaw
        ) { }
        catch (bytes memory reason) {
            _revert(reason);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Claims tokens recorded by the live adapter before the code override
    /// @dev Included to preserve the production adapter's storage and callable surface
    function claimFailedTransfer(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();

        uint256 available = failedTransfers[msg.sender][token];
        if (available < amount) revert INSUFFICIENT_FAILED_BALANCE();

        failedTransfers[msg.sender][token] = available - amount;

        if (token == address(0)) {
            (bool success,) = msg.sender.call{ value: amount }("");
            if (!success) revert ETH_TRANSFER_FAILED();
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit FailedTransferClaimed(msg.sender, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the full list of whitelisted OFT addresses
    function getAllowedOFTs() external view returns (address[] memory) {
        return allowedOFTsList;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Extracts destination execution fields for the current chain
    function _extractFromSigData(bytes memory sigDataRaw) internal view returns (ExtractedData memory extracted) {
        (,,,,, ISuperValidator.DstProof[] memory proofDst,) =
            abi.decode(sigDataRaw, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));

        uint64 currentChain = uint64(block.chainid);
        uint256 len = proofDst.length;
        for (uint256 i; i < len; ++i) {
            if (proofDst[i].dstChainId == currentChain) {
                extracted.account = proofDst[i].info.account;
                extracted.executorCalldata = proofDst[i].info.data;
                extracted.dstTokens = proofDst[i].info.dstTokens;
                extracted.intentAmounts = proofDst[i].info.intentAmounts;
                extracted.found = true;
                return extracted;
            }
        }
    }

    /// @notice Attempts the same native/ERC20 transfer as StargateAdapterV2
    function _tryTransfer(address token, address account, uint256 amount) internal returns (bool success) {
        if (token == address(0)) {
            (success,) = account.call{ value: amount }("");
        } else {
            (bool callSuccess, bytes memory returnData) = token.call(abi.encodeCall(IERC20.transfer, (account, amount)));
            success = callSuccess && (returnData.length == 0 || abi.decode(returnData, (bool)));
        }
    }

    /// @notice Bubbles an inner self-call failure without changing its revert selector
    function _revert(bytes memory reason) private pure {
        if (reason.length == 0) revert COMPOSE_EXECUTION_FAILED();
        assembly ("memory-safe") {
            revert(add(reason, 0x20), mload(reason))
        }
    }
}
