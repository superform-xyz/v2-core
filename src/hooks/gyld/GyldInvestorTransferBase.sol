// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { BytesLib } from "../../vendor/BytesLib.sol";
import { GyldInTransitRegistry } from "../../accounting/oracles/GyldInTransitRegistry.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../interfaces/ISuperHook.sol";

/// @title GyldInvestorTransferBase
/// @author Superform Labs
/// @notice Shared body of the two Gyld Investor API hooks: a plain ERC20 transfer from the account to a
///         destination PINNED in `GyldInTransitRegistry`, plus the matching in-transit record, with both
///         balance deltas verified in `_postExecute`.
/// @dev THE CHAIN SEES ONLY A TRANSFER. Gyld's Investor API places a broker limit order off chain and mints
///      (or pays out) in a later transaction signed by Gyld, so nothing about price, quantity or fill can be
///      validated here. What CAN be enforced, and is: the destination is never read from calldata, the
///      account's balance of the moved token decreases by exactly the amount, the destination's balance
///      increases by exactly the amount, and the registry accepted the record in the same atomic batch.
/// @dev TERMINAL. `outAmount` is published as ZERO (repo rule for hooks that produce nothing for the
///      account; see `ForceDeallocateMorphoHook._preExecute`), so a successor with `usePrevHookAmount` fails
///      closed. `outToken` is the moved token, for off-chain classification only.
/// @dev The 125-byte layout is shared by both hooks and parsed by the OMS from each hook's NatSpec block:
///      `yieldSource` at 52 is found BY NAME. Keep the field names.
/// @dev `decodeAmounts`, `replaceCalldataAmounts` and the `AMOUNT_POSITION` constant live in EACH concrete hook,
///      not here: `tooling/generate-hook-sizing-manifest.ts` classifies a hook by scanning its OWN source file.
abstract contract GyldInvestorTransferBase is
    BaseHook,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error INVALID_DATA_LENGTH(uint256 given, uint256 expected);
    error IDENTICAL_TOKENS();
    /// @notice The previous hook's output token is not the token this hook moves
    error PREV_TOKEN_MISMATCH();
    /// @notice The pinned destination is still zero in the registry
    error DESTINATION_NOT_SET();
    /// @notice The account's balance did not decrease by exactly the amount
    error INPUT_NOT_SPENT(uint256 expected, uint256 actual);
    /// @notice The destination's balance did not increase by exactly the amount
    error DESTINATION_NOT_CREDITED(uint256 expected, uint256 actual);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant EXPECTED_DATA_LENGTH = 125;
    uint256 internal constant YIELD_SOURCE_OFFSET = 52;
    uint256 internal constant CASH_TOKEN_OFFSET = 72;
    uint256 internal constant AMOUNT_OFFSET = 92;
    uint256 internal constant USE_PREV_HOOK_AMOUNT_POSITION = 124;

    /// @dev Private transient namespace for the two balance snapshots. `_setOutAmount` is reserved for the
    ///      published output.
    bytes32 private constant TRANSIENT_NAMESPACE = keccak256("superform.gyld.investor.transient.v1");
    uint256 private constant SLOT_ACCOUNT_BEFORE = 0;
    uint256 private constant SLOT_DESTINATION_BEFORE = 1;

    /// @notice Pinned destinations, caps and in-transit state
    GyldInTransitRegistry public immutable IN_TRANSIT;

    constructor(address inTransit_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) {
        if (inTransit_ == address(0)) revert ADDRESS_NOT_VALID();
        IN_TRANSIT = GyldInTransitRegistry(inTransit_);
    }

    /*//////////////////////////////////////////////////////////////
                                 SIZING
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev `TOKEN` for both hooks, raw units of the moved token and no price-per-share conversion. The
    ///      argument is unnamed and unread; `HookSizingInterface.t.sol` calls this with empty bytes.
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }

    /// @dev Implements ISuperHookInflowOutflow + ISuperHookOutflow. Pipe mode stays the transform default.
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev Commits the instrument and its cash denomination: a leaf authorises exactly one pair.
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return
            abi.encodePacked(BytesLib.toAddress(data, YIELD_SOURCE_OFFSET), BytesLib.toAddress(data, CASH_TOKEN_OFFSET));
    }

    /*//////////////////////////////////////////////////////////////
                            SHARED INTERNALS
    //////////////////////////////////////////////////////////////*/

    /// @dev Exact length, non-zero and distinct tokens.
    function _decode(bytes calldata data) internal pure returns (address yieldSource, address cashToken) {
        if (data.length != EXPECTED_DATA_LENGTH) revert INVALID_DATA_LENGTH(data.length, EXPECTED_DATA_LENGTH);
        yieldSource = BytesLib.toAddress(data, YIELD_SOURCE_OFFSET);
        cashToken = BytesLib.toAddress(data, CASH_TOKEN_OFFSET);
        if (yieldSource == address(0) || cashToken == address(0)) revert ADDRESS_NOT_VALID();
        if (yieldSource == cashToken) revert IDENTICAL_TOKENS();
    }

    /// @dev The amount at offset 92, or the previous hook's output when the flag is set, in which case the
    ///      previous output token must be the token this hook moves.
    function _resolveAmount(
        address prevHook,
        address account,
        bytes calldata data,
        address movedToken
    )
        internal
        view
        returns (uint256 amount)
    {
        amount = BytesLib.toUint256(data, AMOUNT_OFFSET);
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            if (prevHook == address(0)) revert ADDRESS_NOT_VALID();
            amount = ISuperHookResult(prevHook).getOutAmount(account);
            if (ISuperHookResult(prevHook).getOutToken(account) != movedToken) revert PREV_TOKEN_MISMATCH();
        }
        if (amount == 0) revert AMOUNT_NOT_VALID();
    }

    /// @dev Snapshot both sides of the transfer and publish a zero output.
    function _snapshot(address account, address movedToken, address destination) internal {
        _tstore(_key(account, SLOT_ACCOUNT_BEFORE), IERC20(movedToken).balanceOf(account));
        _tstore(_key(account, SLOT_DESTINATION_BEFORE), IERC20(movedToken).balanceOf(destination));
        _setOutAmount(0, account);
    }

    /// @dev Both deltas must be exact: fee-on-transfer and blocklist tokens fail closed.
    function _verifyTransfer(address account, address movedToken, address destination, uint256 amount) internal {
        uint256 accountBefore = _tload(_key(account, SLOT_ACCOUNT_BEFORE));
        uint256 accountNow = IERC20(movedToken).balanceOf(account);
        uint256 spent = accountBefore > accountNow ? accountBefore - accountNow : 0;
        if (spent != amount) revert INPUT_NOT_SPENT(amount, spent);

        uint256 destBefore = _tload(_key(account, SLOT_DESTINATION_BEFORE));
        uint256 destNow = IERC20(movedToken).balanceOf(destination);
        uint256 credited = destNow > destBefore ? destNow - destBefore : 0;
        if (credited != amount) revert DESTINATION_NOT_CREDITED(amount, credited);

        _setOutAmount(0, account);
        _setOutToken(movedToken, account);
    }

    function _key(address account, uint256 slot) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(TRANSIENT_NAMESPACE, account, slot));
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
