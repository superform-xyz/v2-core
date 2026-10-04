// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseAaveV4LoanHookV2 } from "./BaseAaveV4LoanHookV2.sol";
import { ISuperHookInflowOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseAaveV4StandaloneLoanHookV2
/// @author Superform Labs
/// @notice Shared machinery for the standalone Aave V4 V2 borrower hooks (pledge / borrow /
///         release): exact-primary and release resolution (with the RELEASE mode / over-position guards) and
///         single-leg settles; strict single-slot sizing views, reserve binding and the shared idle-position guard
///         come from BaseAaveV4LoanHookV2. SUP-21141, twin of
///         BaseMorphoStandaloneLoanHookV2 (which has no mode guards: Morpho markets are per-mode).
/// @dev Deliberately a SEPARATE abstract inherited only by the standalone hooks: adding these
///      helpers to BaseAaveV4LoanHookV2 / BaseLoanHookV2 would change the compiled bytecode of the
///      composite V2 loan hooks (legacy solc codegen embeds inherited internal functions even when
///      unreferenced). Historical note: SUP-21141 kept the deployed OPEN / REPAY / CLOSE byte-identical
///      this way; SUP-21143 (header = reserve key) then deliberately re-pinned all 12 LOAN hooks in
///      test/unit/hooks/loan/AaveV4LoanBytecodeUnchanged.t.sol (`_BytecodePinned`), so the separation
///      now serves scope hygiene, not a lock.
///      Layout: the canonical 241-byte Aave V4 V2 layout with the secondary word (offset 208)
///      RESERVED ZERO — one advertised leg only. The strategy header (offsets 0-51) is bound by the
///      inherited decoder: `yieldSource` (offset 32) == `AaveV4ReserveKey.computeMarketKey(spoke,
///      supplyReserveId, borrowReserveId)` — the MARKET key of the pair, identical for every leg of a market
///      (SUP-21239, superseding SUP-21143's per-reserve rule). A standalone leg advertises one amount, but it
///      still carries both reserve ids in its body, so the market key is derivable from its calldata and the
///      pin applies unchanged.
///      ISuperHookLoans getters: the inherited non-virtual BaseLoanHook getters read offsets 52 / 72,
///      which on this layout ARE loanToken / collateralToken (unlike the idle layout, where 72 is the
///      Spoke), so _snapshotBalances and the _settle* helpers below measure the real ERC-20s.
abstract contract BaseAaveV4StandaloneLoanHookV2 is BaseAaveV4LoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice No Spoke constructor arg — the Spoke comes from calldata, like every Aave V4 hook
    /// @param hookSubtype_ Hook subtype identifier (LOAN for all three standalone hooks)
    constructor(bytes32 hookSubtype_) BaseAaveV4LoanHookV2(hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Strict decode with the reserved secondary word (header key pinned inside the pure
    ///      decoder), then binds both reserve ids to the declared tokens through the Spoke (view).
    ///      Used by build and _preExecute; inspect() and the sizing views run the pure decoder alone.
    /// @param data The hook data
    /// @return vars The decoded and reserve-bound hook parameters
    function _decodeAndBind(bytes memory data) internal view returns (AaveV4V2Vars memory vars) {
        vars = _decodeAaveV4V2(data, true);
        _validateReserves(vars);
    }

    /// @dev Resolves the single exact primary amount shared by pledge and borrow. When
    ///      usePrevHookAmount is set the calldata word is ignored and the previous hook's output
    ///      (which must be denominated in `expectedToken`) becomes the amount. Zero and
    ///      type(uint256).max are rejected on both paths — the standalone primary is always exact,
    ///      never a cap or sentinel — all before any provider call is emitted.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param expectedToken The token the primary slot is denominated in
    /// @param amountWord The calldata amount word (ignored when usePrevHookAmount is set)
    /// @param usePrevHookAmount True to source the amount from the previous hook's output
    /// @return resolved The exact amount the provider call will move
    function _resolveExactPrimary(
        address prevHook,
        address account,
        address expectedToken,
        uint256 amountWord,
        bool usePrevHookAmount
    )
        internal
        view
        returns (uint256 resolved)
    {
        resolved = usePrevHookAmount ? _resolvePrevHookOutput(prevHook, account, expectedToken) : amountWord;
        if (resolved == 0 || resolved == type(uint256).max) revert AMOUNT_NOT_VALID();
    }

    /// @dev Resolves the release amount against the account's supplied assets on the supply
    ///      reserve, read before any provider execution is emitted. An empty position reverts on every
    ///      path, and so does a position that is not flagged as collateral: RELEASE is the LOAN-mode exit,
    ///      and an un-flagged position is the idle MONEY_MARKET side's (ledger-tracked) — paying it out
    ///      here would bypass the ledger outflow (mirror of the idle hooks' RESERVE_IS_COLLATERAL). PREV path:
    ///      the previous hook's output, denominated in the collateral token (the calldata word is
    ///      ignored, so the sentinel is only reachable with usePrevHookAmount = false). Calldata
    ///      path: an exact word, or type(uint256).max resolving to the full supplied position (the
    ///      sentinel itself is passed through to the Spoke, which withdraws everything natively; the
    ///      pre-read is the exact expected receipt — same virtual index, same block). Unlike Morpho,
    ///      Aave does NOT underflow-revert an over-withdrawal but silently converts it into a full
    ///      withdrawal, so an exact or PREV amount above the position is rejected here with a
    ///      typed WITHDRAW_EXCEEDS_SUPPLIED(requested, supplied) up front (before any Spoke call is emitted)
    ///      instead of a late, less legible DELTA_MISMATCH after the Spoke has already paid the full position.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @return amount The exact collateral amount the withdraw will pay out
    /// @return fullWithdraw True when the calldata sentinel was used (emit withdraw(max))
    function _resolveReleaseAmount(
        address prevHook,
        address account,
        AaveV4V2Vars memory vars
    )
        internal
        view
        returns (uint256 amount, bool fullWithdraw)
    {
        uint256 supplied = _requireCollateralPosition(vars, account);
        if (vars.usePrevHookAmount) {
            amount = _resolvePrevHookOutput(prevHook, account, vars.collateralToken);
        } else if (vars.amount1 == 0) {
            revert AMOUNT_NOT_VALID();
        } else if (vars.amount1 == type(uint256).max) {
            return (supplied, true);
        } else {
            amount = vars.amount1;
        }
        if (amount > supplied) revert WITHDRAW_EXCEEDS_SUPPLIED(amount, supplied);
    }

    /// @dev Standalone pledge settle: collateral spent must equal expectedPrimaryAmount. A pledge
    ///      hook is terminal — it consumes the collateral asset and produces nothing — so it
    ///      publishes outAmount = 0 while keeping outToken = collateralToken for off-chain
    ///      classification (mirrors _settleRepay): publishing the spend would let a downstream
    ///      usePrevHookAmount consumer mistake it for produced tokens; zero makes such chaining fail
    ///      closed. The spend is still enforced against the measured wallet delta.
    function _settleSupplyCollateral(address account, bytes memory data) internal {
        uint256 collateralSpent = _balanceDecrease(preCollateralTokenBalance, getCollateralTokenBalance(account, data));
        if (collateralSpent != expectedPrimaryAmount) revert DELTA_MISMATCH(expectedPrimaryAmount, collateralSpent);
        _setOutAmount(0, account);
        _setOutToken(getCollateralTokenAddress(data), account);
    }

    /// @dev Standalone borrow settle: loan tokens received must equal expectedPrimaryAmount.
    ///      Publishes the measured loan-token wallet delta so downstream usePrevHookAmount
    ///      consumers receive the token actually produced.
    function _settleBorrow(address account, bytes memory data) internal {
        uint256 loanReceived = _balanceIncrease(preLoanTokenBalance, getLoanTokenBalance(account, data));
        if (loanReceived != expectedPrimaryAmount) revert DELTA_MISMATCH(expectedPrimaryAmount, loanReceived);
        _setOutAmount(loanReceived, account);
        _setOutToken(getLoanTokenAddress(data), account);
    }

    /// @dev Standalone release settle: collateral received must equal expectedPrimaryAmount.
    ///      Publishes the measured collateral-token wallet delta.
    function _settleWithdrawCollateral(address account, bytes memory data) internal {
        uint256 collateralReceived =
            _balanceIncrease(preCollateralTokenBalance, getCollateralTokenBalance(account, data));
        if (collateralReceived != expectedPrimaryAmount) {
            revert DELTA_MISMATCH(expectedPrimaryAmount, collateralReceived);
        }
        _setOutAmount(collateralReceived, account);
        _setOutToken(getCollateralTokenAddress(data), account);
    }

    /// @dev Roles for single-slot produced-token layouts (standalone borrow / release): [OUT/TOKEN]
    function _oneOutTokenRole() internal pure returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.OUT, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }
}
