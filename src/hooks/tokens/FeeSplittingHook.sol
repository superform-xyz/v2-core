// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title FeeSplittingHook
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         bytes transfersArr = BytesLib.slice(data, 52, data.length - 52);
/// @notice         // transfersArr = abi.encode(address[] tokens, uint256[] amounts, address[] receivers)
contract FeeSplittingHook is BaseHook, ISuperHookInflowOutflow {
    /// @notice Emitted after a native-token fee has been successfully paid
    /// @param payer The smart account that paid the fee
    /// @param recipient The address that received the native-token fee
    /// @param amount The native-token amount sent to the recipient
    event NativeFeePaid(address indexed payer, address indexed recipient, uint256 amount);

    /// @notice Thrown when tokens, amounts and receivers arrays have different lengths
    error LENGTH_MISMATCH();

    /// @notice Thrown when the number of transfers exceeds MAX_TRANSFERS
    error TOO_MANY_TRANSFERS();

    /// @notice Thrown when the hook data is too short to contain the strategy header and transfers payload
    error INVALID_DATA_LENGTH();

    /// @notice Thrown when a transfer leg did not actually move the expected funds out of the account
    ///         (e.g. a token that returns false without reverting, or an unexpected inbound transfer).
    ///         `index` is the offending leg in the transfers array.
    error TRANSFER_NOT_PERFORMED(uint256 index);

    /// @notice Maximum number of transfers in a single split
    uint256 public constant MAX_TRANSFERS = 50;

    /// @dev This is not a constant because some chains have different representations for the native token
    ///      https://github.com/d-xo/weird-erc20?tab=readme-ov-file#erc-20-representation-of-native-currency
    address public immutable NATIVE_TOKEN;

    constructor(address _nativeToken) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        NATIVE_TOKEN = _nativeToken;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Fee Splitting";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Transfers multiple tokens to multiple recipients pairwise in a single call";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        (address[] memory tokens, uint256[] memory amounts, address[] memory receivers) = _decodeTransfers(data);

        uint256 tokensLen = tokens.length;
        executions = new Execution[](tokensLen);
        for (uint256 i; i < tokensLen; i++) {
            if (receivers[i] == address(0)) revert ADDRESS_NOT_VALID();
            if (amounts[i] == 0) revert AMOUNT_NOT_VALID();
            if (tokens[i] == NATIVE_TOKEN) {
                // For native token, send ETH directly to the recipient
                executions[i] = Execution({ target: receivers[i], value: amounts[i], callData: "" });
            } else {
                // Calls to codeless targets succeed with empty returndata, silently skipping the fee
                if (tokens[i].code.length == 0) revert ADDRESS_NOT_VALID();
                // For ERC20 tokens, use the standard transfer
                executions[i] = Execution({
                    target: tokens[i], value: 0, callData: abi.encodeCall(IERC20.transfer, (receivers[i], amounts[i]))
                });
            }
        }
    }

    /// @dev Decodes and validates the transfers payload; shared by build and inspect so a payload
    ///      that inspects cleanly can never revert on structural validation at execution time
    function _decodeTransfers(bytes calldata data)
        private
        pure
        returns (address[] memory tokens, uint256[] memory amounts, address[] memory receivers)
    {
        if (data.length <= 52) revert INVALID_DATA_LENGTH();
        bytes memory transfersData = BytesLib.slice(data, 52, data.length - 52);

        (tokens, amounts, receivers) = abi.decode(transfersData, (address[], uint256[], address[]));

        uint256 tokensLen = tokens.length;
        if (tokensLen != amounts.length || tokensLen != receivers.length) revert LENGTH_MISMATCH();
        if (tokensLen > MAX_TRANSFERS) revert TOO_MANY_TRANSFERS();
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Sizeless — variable-length amounts[] in ABI-encoded data
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        (,, address[] memory receivers) = _decodeTransfers(data);

        uint256 receiversLen = receivers.length;
        bytes memory out;
        for (uint256 i; i < receiversLen; i++) {
            out = abi.encodePacked(out, receivers[i]);
        }
        return out;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Side-effect-only hook: forwards the previous hook's outAmount/outToken so a
    ///      downstream hook using usePrevHookAmount is not fed 0 after a mid-chain fee split
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }

    /*//////////////////////////////////////////////////////////////
                    PASSTHROUGH FORWARDING + TRANSFER SAFETY
    //////////////////////////////////////////////////////////////*/
    /// @dev Transient-storage namespace for this hook's own bookkeeping (EIP-1153). Kept separate
    ///      from BaseHook's execution-context namespace so keys never collide.
    bytes32 private constant FS_NAMESPACE = keccak256("superform.feeSplitting.transient.v1");

    /// @notice Snapshots the previous hook's forwarded output and pre-transfer balances.
    /// @dev Overrides the default PASSTHROUGH forward to additionally (1) handle same-address
    ///      adjacency — when `prevHook == address(this)`, BaseHook's shared context has already been
    ///      advanced, so read this hook's own published output from transient storage instead of the
    ///      empty fresh context; and (2) snapshot the account's balance per distinct token so
    ///      _postExecute can verify the transfers actually happened.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        // (1) Forward previous output (adjacency-aware).
        if (prevHook != address(0)) {
            if (prevHook == address(this)) {
                _setOutAmount(_tload(_cacheAmountKey(account)), account);
                _setOutToken(address(uint160(_tload(_cacheTokenKey(account)))), account);
            } else {
                _setOutAmount(ISuperHookResult(prevHook).getOutAmount(account), account);
                _setOutToken(ISuperHookResult(prevHook).getOutToken(account), account);
            }
        }

        // (2) Snapshot pre-transfer balances and accumulate expected outflow per distinct token.
        _snapshotBalances(executionNonce, account, data);
    }

    /// @dev Records, per distinct token, the account's pre-transfer balance and the total expected outflow.
    function _snapshotBalances(uint256 nonce, address account, bytes calldata data) private {
        (address[] memory tokens, uint256[] memory amounts,) = _decodeTransfers(data);
        uint256 len = tokens.length;
        for (uint256 i; i < len; ++i) {
            address token = tokens[i];
            _tstore(_expectedKey(nonce, token), _tload(_expectedKey(nonce, token)) + amounts[i]);
            // Pre-transfer balance is identical across duplicate legs of the same token, so overwriting is safe.
            _tstore(
                _balanceKey(nonce, token), token == NATIVE_TOKEN ? account.balance : IERC20(token).balanceOf(account)
            );
        }
    }

    /// @notice Verifies every transfer leg moved funds and reconciles the forwarded amount post-fee.
    /// @dev (1) For each distinct token, asserts the account was debited at least the expected total —
    ///      catching tokens that return false without reverting (the sender is debited the full amount
    ///      even for fee-on-transfer tokens). (2) Subtracts fees paid in the forwarded (flow) token from
    ///      the forwarded outAmount so a downstream usePrevHookAmount consumer sees the post-fee remainder
    ///      rather than the stale pre-fee amount (prevents native/token overspend). (3) Publishes this
    ///      hook's final output for a possible adjacent same-address successor. (4) Emits a receipt log
    ///      for each successfully paid native-token leg.
    function _postExecute(address prevHook, address account, bytes calldata data) internal override {
        uint256 nonce = executionNonce;
        (address[] memory tokens, uint256[] memory amounts, address[] memory receivers) = _decodeTransfers(data);

        // Fees paid in the forwarded token (native-aware). Read before the verification loop consumes it.
        address flowToken = getOutToken(account);
        uint256 spent = _tload(
            _expectedKey(nonce, (flowToken == address(0) || flowToken == NATIVE_TOKEN) ? NATIVE_TOKEN : flowToken)
        );

        // (1) Verify every transfer leg actually left the account.
        _verifyTransfers(nonce, account, tokens);

        // (2) Decrement forwarded amount by fees paid in the flow token (clamp at 0).
        if (prevHook != address(0) && spent != 0) {
            uint256 fwd = getOutAmount(account);
            _setOutAmount(fwd > spent ? fwd - spent : 0, account);
        }

        // (3) Publish final output for an adjacent same-address successor.
        _tstore(_cacheAmountKey(account), getOutAmount(account));
        _tstore(_cacheTokenKey(account), uint256(uint160(getOutToken(account))));

        // Standards-compliant ERC-20 fees already expose payer, recipient, token, and amount through
        // Transfer logs emitted by the token contract. Native value transfers have no equivalent
        // standard log, so this explicitly native-only event needs only the payer, recipient, and amount.
        uint256 len = tokens.length;
        for (uint256 i; i < len; ++i) {
            if (tokens[i] == NATIVE_TOKEN) {
                emit NativeFeePaid(account, receivers[i], amounts[i]);
            }
        }
    }

    /// @dev For each distinct token, asserts the account was debited at least the expected total —
    ///      catching tokens that return false without reverting (the sender is debited the full amount
    ///      even for fee-on-transfer tokens). Consumes the expected accumulator to dedupe repeated tokens.
    function _verifyTransfers(uint256 nonce, address account, address[] memory tokens) private {
        uint256 len = tokens.length;
        for (uint256 i; i < len; ++i) {
            address token = tokens[i];
            uint256 expected = _tload(_expectedKey(nonce, token));
            if (expected != 0) {
                uint256 preBal = _tload(_balanceKey(nonce, token));
                uint256 postBal = token == NATIVE_TOKEN ? account.balance : IERC20(token).balanceOf(account);
                if (postBal > preBal || preBal - postBal < expected) revert TRANSFER_NOT_PERFORMED(i);
                _tstore(_expectedKey(nonce, token), 0);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                       TRANSIENT STORAGE HELPERS
    //////////////////////////////////////////////////////////////*/
    function _expectedKey(uint256 nonce, address token) private pure returns (bytes32) {
        return keccak256(abi.encode(FS_NAMESPACE, uint256(0), nonce, token));
    }

    function _balanceKey(uint256 nonce, address token) private pure returns (bytes32) {
        return keccak256(abi.encode(FS_NAMESPACE, uint256(1), nonce, token));
    }

    /// @dev Cache keys are per-account (not per-nonce): the value published by one instance must be
    ///      readable by the next adjacent instance, which runs under a fresh execution context.
    function _cacheAmountKey(address account) private pure returns (bytes32) {
        return keccak256(abi.encode(FS_NAMESPACE, uint256(2), account));
    }

    function _cacheTokenKey(address account) private pure returns (bytes32) {
        return keccak256(abi.encode(FS_NAMESPACE, uint256(3), account));
    }

    function _tload(bytes32 key) private view returns (uint256 value) {
        assembly ("memory-safe") {
            value := tload(key)
        }
    }

    function _tstore(bytes32 key, uint256 value) private {
        assembly ("memory-safe") {
            tstore(key, value)
        }
    }
}
