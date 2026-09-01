// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../vendor/BytesLib.sol";

// Superform
import { BaseLoanHook } from "./BaseLoanHook.sol";
import { ISuperHookResult, ISuperHookInflowOutflow } from "../../interfaces/ISuperHook.sol";

/// @title BaseLoanHookV2
/// @author Superform Labs
/// @notice Shared machinery for the V2 (versioned) position loan hooks: strict calldata decoding,
///         previous-hook output validation, and truthful produced-token reporting via wallet
///         balance snapshots.
/// @dev V2 loan hooks standardize on:
///      - Open (supply+borrow) slots: [collateralAmount, borrowAmount] with roles [IN/TOKEN, OUT/TOKEN]
///      - Close (repay+withdraw) slots: [repayAmount, withdrawAmount] with roles [IN/TOKEN, OUT/TOKEN]
///      - Standalone repay slot: [repayAmount] with role [IN/TOKEN]
///      - usePrevHookAmount applies ONLY to the first slot; the previous hook's output token must
///        equal the token the first slot is denominated in (collateral token for open, loan token
///        for close/repay)
///      - type(uint256).max is the ONLY all-debt/all-collateral sentinel, valid only in close and
///        standalone-repay hooks; a max primary requires usePrevHookAmount == false
///      - No amount is ever derived from a ratio/oracle inside the hook; every non-sentinel value
///        is exact when the hook executes and is enforced against the measured wallet delta
///      - Exact byte lengths, canonical boolean bytes (0x00/0x01), and reserved-zero fields
///      Expected amounts are resolved in _preExecute (after provider interest accrual, in the same
///      transaction as execution, so view-resolved values are exact) and stored in transient
///      storage; _postExecute measures wallet deltas and reverts on any mismatch.
/// @dev Strict delta equality intentionally makes fee-on-transfer / rebasing tokens unusable with
///      V2 loan hooks: a token that delivers less than the provider reports fails the settle check.
abstract contract BaseLoanHookV2 is BaseLoanHook {
    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Wallet balance of the loan token snapshotted by _preExecute
    /// @dev Plain (non context-keyed) transient storage is safe here: a hook's preExecute,
    ///      provider operations and postExecute never interleave with another execution of the
    ///      same hook contract within a transaction (mirrors the `usedShares` precedent).
    ///      CAVEAT: this invariant assumes the tokens/providers in the hook chain do not hand
    ///      execution to third parties mid-settle (e.g. ERC-777-style transfer callbacks), which
    ///      could interleave another account's preExecute and poison these values. Consistent with
    ///      SECURITY.md: hook safety depends on external contract trustworthiness.
    uint256 public transient preLoanTokenBalance;

    /// @notice Wallet balance of the collateral token snapshotted by _preExecute
    uint256 public transient preCollateralTokenBalance;

    /// @notice Exact amount the primary leg must move, resolved by _preExecute
    /// @dev Open: collateral supplied. Close/repay: loan tokens spent repaying (sentinels resolved
    ///      against provider state after interest accrual).
    uint256 public transient expectedPrimaryAmount;

    /// @notice Exact amount the secondary leg must move, resolved by _preExecute
    /// @dev Open: loan tokens borrowed. Close: collateral withdrawn. Unused for standalone repay.
    uint256 public transient expectedSecondaryAmount;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook calldata does not have the exact required byte length
    error INVALID_DATA_LENGTH();

    /// @notice Thrown when a boolean byte is neither 0x00 nor 0x01
    error INVALID_BOOL_VALUE();

    /// @notice Thrown when a reserved byte/word is not zero
    error RESERVED_FIELD_NOT_ZERO();

    /// @notice Thrown when the previous hook's output token does not match the expected token
    error PREV_TOKEN_MISMATCH();

    /// @notice Thrown when a type(uint256).max primary amount is combined with usePrevHookAmount
    error MAX_WITH_PREV_NOT_ALLOWED();

    /// @notice Thrown when a repayment is attempted against a position with zero resolved debt
    error NO_OUTSTANDING_DEBT();

    /// @notice Thrown when the loan token equals the collateral token
    error IDENTICAL_TOKENS();

    /// @notice Thrown when a wallet balance moved in the opposite direction than expected
    error NEGATIVE_BALANCE_DELTA();

    /// @notice Thrown when a measured wallet delta does not equal the resolved expected amount
    /// @param expected The amount resolved before execution
    /// @param actual The measured wallet balance delta
    error DELTA_MISMATCH(uint256 expected, uint256 actual);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                        STRICT DECODE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Decodes a canonical boolean byte; any value other than 0x00/0x01 reverts
    function _decodeStrictBool(bytes memory data, uint256 offset) internal pure returns (bool) {
        bytes1 raw = data[offset];
        if (raw == 0x00) return false;
        if (raw == 0x01) return true;
        revert INVALID_BOOL_VALUE();
    }

    /// @dev Reverts unless the 32-byte word at `offset` is zero
    function _requireZeroWord(bytes memory data, uint256 offset) internal pure {
        if (BytesLib.toUint256(data, offset) != 0) revert RESERVED_FIELD_NOT_ZERO();
    }

    /// @dev Reverts unless the byte at `offset` is zero
    function _requireZeroByte(bytes memory data, uint256 offset) internal pure {
        if (data[offset] != 0x00) revert RESERVED_FIELD_NOT_ZERO();
    }

    /*//////////////////////////////////////////////////////////////
                        PREVIOUS-HOOK OUTPUT PIPE
    //////////////////////////////////////////////////////////////*/

    /// @dev Validates and resolves the immediate previous hook's output for the primary slot.
    ///      Reverts when the previous hook is unset, produced the wrong token, or produced a zero
    ///      or type(uint256).max amount (max is reserved as the all-debt/all-collateral sentinel
    ///      and can never be a legitimate wallet delta) — all before any provider call is emitted.
    ///      Deterministic within a transaction: the previous hook's transient outputs persist for
    ///      the whole transaction, so build, _preExecute and _postExecute resolve the same value.
    ///      NOTE: a predecessor that sets only outAmount and never outToken reports outToken ==
    ///      address(0) and hard-fails here with PREV_TOKEN_MISMATCH; V2 loan hooks require the
    ///      predecessor to publish a token (all V2 producers do — see the _settle* helpers).
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param expectedToken The token the primary slot is denominated in
    /// @return amount The previous hook's output amount
    function _resolvePrevHookOutput(
        address prevHook,
        address account,
        address expectedToken
    )
        internal
        view
        returns (uint256 amount)
    {
        if (prevHook == address(0)) revert ADDRESS_NOT_VALID();
        if (ISuperHookResult(prevHook).getOutToken(account) != expectedToken) revert PREV_TOKEN_MISMATCH();
        amount = ISuperHookResult(prevHook).getOutAmount(account);
        if (amount == 0 || amount == type(uint256).max) revert AMOUNT_NOT_VALID();
    }

    /// @dev Resolves the collateral (amount1) leg shared by every V2 supply-and-borrow hook.
    ///      Rejects a zero or sentinel borrow (amount2) and a zero or sentinel resolved collateral,
    ///      all before any provider call. When usePrevHookAmount is set, amount1 is taken from the
    ///      previous hook's output (which must be denominated in `collateralToken`).
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param collateralToken The token the collateral leg is denominated in
    /// @param amount1 The calldata collateral amount (ignored when usePrevHookAmount is set)
    /// @param amount2 The calldata borrow amount (validated non-zero, non-sentinel)
    /// @param usePrevHookAmount True to source amount1 from the previous hook's output
    /// @return resolvedAmount1 The exact collateral amount to supply
    function _resolveOpenAmount1(
        address prevHook,
        address account,
        address collateralToken,
        uint256 amount1,
        uint256 amount2,
        bool usePrevHookAmount
    )
        internal
        view
        returns (uint256 resolvedAmount1)
    {
        if (amount2 == 0 || amount2 == type(uint256).max) revert AMOUNT_NOT_VALID();
        resolvedAmount1 = usePrevHookAmount ? _resolvePrevHookOutput(prevHook, account, collateralToken) : amount1;
        if (resolvedAmount1 == 0 || resolvedAmount1 == type(uint256).max) revert AMOUNT_NOT_VALID();
    }

    /*//////////////////////////////////////////////////////////////
                        SNAPSHOT / SETTLE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Snapshots both wallet balances; call at the end of _preExecute, after provider
    ///      interest accrual and expected-amount resolution
    function _snapshotBalances(address account, bytes memory data) internal {
        preLoanTokenBalance = getLoanTokenBalance(account, data);
        preCollateralTokenBalance = getCollateralTokenBalance(account, data);
    }

    /// @dev Open settle: collateral spent must equal expectedPrimaryAmount, loan tokens received
    ///      must equal expectedSecondaryAmount. Publishes the borrowed loan-token delta so
    ///      downstream usePrevHookAmount consumers receive the token actually produced.
    function _settleOpen(address account, bytes memory data) internal {
        uint256 collateralSpent = _balanceDecrease(preCollateralTokenBalance, getCollateralTokenBalance(account, data));
        if (collateralSpent != expectedPrimaryAmount) revert DELTA_MISMATCH(expectedPrimaryAmount, collateralSpent);

        uint256 loanReceived = _balanceIncrease(preLoanTokenBalance, getLoanTokenBalance(account, data));
        if (loanReceived != expectedSecondaryAmount) revert DELTA_MISMATCH(expectedSecondaryAmount, loanReceived);

        _setOutAmount(loanReceived, account);
        _setOutToken(getLoanTokenAddress(data), account);
    }

    /// @dev Close settle: loan tokens spent must equal expectedPrimaryAmount, collateral received
    ///      must equal expectedSecondaryAmount. Publishes the released collateral-token delta.
    function _settleClose(address account, bytes memory data) internal {
        uint256 loanSpent = _balanceDecrease(preLoanTokenBalance, getLoanTokenBalance(account, data));
        if (loanSpent != expectedPrimaryAmount) revert DELTA_MISMATCH(expectedPrimaryAmount, loanSpent);

        uint256 collateralReceived =
            _balanceIncrease(preCollateralTokenBalance, getCollateralTokenBalance(account, data));
        if (collateralReceived != expectedSecondaryAmount) {
            revert DELTA_MISMATCH(expectedSecondaryAmount, collateralReceived);
        }

        _setOutAmount(collateralReceived, account);
        _setOutToken(getCollateralTokenAddress(data), account);
    }

    /// @dev Standalone-repay settle: loan tokens spent must equal expectedPrimaryAmount.
    ///      A repay hook is terminal — it consumes the debt asset and produces nothing — so it
    ///      publishes outAmount = 0 while keeping outToken = loanToken for off-chain classification.
    ///      Publishing the spend as an output would let a downstream usePrevHookAmount consumer
    ///      mistake it for produced tokens and spend an equal amount of unrelated wallet balance;
    ///      zero makes any such chaining fail closed (the prev-hook pipe rejects a zero amount).
    function _settleRepay(address account, bytes memory data) internal {
        uint256 loanSpent = _balanceDecrease(preLoanTokenBalance, getLoanTokenBalance(account, data));
        if (loanSpent != expectedPrimaryAmount) revert DELTA_MISMATCH(expectedPrimaryAmount, loanSpent);

        _setOutAmount(0, account);
        _setOutToken(getLoanTokenAddress(data), account);
    }

    /// @dev Returns post - pre, reverting if the balance decreased
    function _balanceIncrease(uint256 pre, uint256 post) internal pure returns (uint256) {
        if (post < pre) revert NEGATIVE_BALANCE_DELTA();
        return post - pre;
    }

    /// @dev Returns pre - post, reverting if the balance increased
    function _balanceDecrease(uint256 pre, uint256 post) internal pure returns (uint256) {
        if (post > pre) revert NEGATIVE_BALANCE_DELTA();
        return pre - post;
    }

    /*//////////////////////////////////////////////////////////////
                    TWO-SLOT SIZING-INTERFACE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Reads the two amount slots of a composite (open/close) layout
    function _decodeTwoAmounts(
        bytes memory data,
        uint256 offset1,
        uint256 offset2
    )
        internal
        pure
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = BytesLib.toUint256(data, offset1);
        amounts[1] = BytesLib.toUint256(data, offset2);
    }

    /// @dev Replaces both amount slots of a composite (open/close) layout; exactly two amounts
    ///      are required
    function _replaceTwoAmounts(
        bytes memory data,
        uint256[] memory amounts,
        uint256 offset1,
        uint256 offset2
    )
        internal
        pure
        returns (bytes memory)
    {
        if (amounts.length != 2) revert INVALID_AMOUNTS_LENGTH();
        data = _replaceCalldataAmount(data, amounts[0], offset1);
        return _replaceCalldataAmount(data, amounts[1], offset2);
    }

    /// @dev Roles for composite layouts: [IN/TOKEN, OUT/TOKEN]
    function _twoTokenRoles() internal pure returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](2);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN
        );
        meta[1] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.OUT, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }
}
