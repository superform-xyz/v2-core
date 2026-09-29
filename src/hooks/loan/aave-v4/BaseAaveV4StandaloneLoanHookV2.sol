// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseAaveV4LoanHookV2 } from "./BaseAaveV4LoanHookV2.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseAaveV4StandaloneLoanHookV2
/// @author Superform Labs
/// @notice Shared machinery for the standalone Aave V4 V2 borrower hooks (pledge / borrow /
///         release): strict single-slot sizing views, reserve binding, exact-primary and release
///         resolution, idle/loan mode guards and single-leg settles. SUP-21141, twin of
///         BaseMorphoStandaloneLoanHookV2 (which has no mode guards: Morpho markets are per-mode).
/// @dev Deliberately a SEPARATE abstract inherited only by the standalone hooks: adding these
///      helpers to BaseAaveV4LoanHookV2 / BaseLoanHookV2 changes the compiled bytecode of the
///      already-deployed V2 loan hooks (legacy solc codegen embeds inherited internal functions
///      even when unreferenced), which the locked-bytecode system forbids. The deployed
///      OPEN / REPAY / CLOSE never import this file, so their bytecode is untouched by construction
///      (proven by test/unit/hooks/loan/AaveV4LoanBytecodeUnchanged.t.sol).
///      Layout: the canonical 241-byte Aave V4 V2 layout with the secondary word (offset 208)
///      RESERVED ZERO — one advertised leg only. The strategy header (offsets 0-51) is a
///      placeholder on this base; the reserve-key bind is a later, layout-preserving change.
///      ISuperHookLoans getters: the inherited non-virtual BaseLoanHook getters read offsets 52 / 72,
///      which on this layout ARE loanToken / collateralToken (unlike the idle layout, where 72 is the
///      Spoke), so _snapshotBalances and the _settle* helpers below measure the real ERC-20s.
abstract contract BaseAaveV4StandaloneLoanHookV2 is BaseAaveV4LoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a PLEDGE targets a reserve already carrying an un-flagged (idle-mode) position
    error RESERVE_HAS_IDLE_POSITION();

    /// @notice Thrown when a RELEASE targets a reserve that is not enabled as collateral for the account
    error RESERVE_NOT_COLLATERAL();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice No Spoke constructor arg — the Spoke comes from calldata, like every Aave V4 hook
    /// @param hookSubtype_ Hook subtype identifier (LOAN for all three standalone hooks)
    constructor(bytes32 hookSubtype_) BaseAaveV4LoanHookV2(hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                        SIZING-INTERFACE OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Runs the full strict V2 decode (exact 241-byte length, reserved secondary word zero,
    ///      canonical usePrevHookAmount boolean, nonzero/distinct addresses) before surfacing the
    ///      single primary amount. The inherited one-slot reader only checks the length, so without
    ///      this an off-chain sizer could transform payloads that build()/inspect() reject.
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        _decodeAaveV4V2(data, true);
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT1_OFFSET);
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Strictly validates the canonical layout before replacing the primary word; the reserved
    ///      secondary word and the boolean byte are left untouched, so the result still decodes.
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        _decodeAaveV4V2(data, true);
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT1_OFFSET);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Strict decode with the reserved secondary word, then binds both reserve ids to the
    ///      declared tokens through the Spoke (view). Used by build and _preExecute; inspect() keeps
    ///      the pure decoder.
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

    /// @dev The account's collateral flag on the supply reserve, read through the Spoke
    /// @param vars The decoded hook parameters
    /// @param account The executing smart account
    /// @return flag True when the supply reserve is enabled as collateral for the account
    function _isUsingAsCollateral(AaveV4V2Vars memory vars, address account) internal view returns (bool flag) {
        (flag,) = IAaveV4Spoke(vars.spoke).getUserReserveStatus(vars.supplyReserveId, account);
    }

    /// @dev Mode guard for PLEDGE. A supplied position that is NOT flagged as collateral belongs to the
    ///      idle MONEY_MARKET side (AaveV4LendHook, ledger-tracked): pledging on top of it would flip the
    ///      flag and let a later RELEASE pay the idle part out with no ledger update, so it is refused
    ///      before any provider execution is emitted. A fresh reserve (zero supply) or an already-flagged
    ///      one passes. Mirror of the idle hooks' RESERVE_IS_COLLATERAL — together they keep one mode per
    ///      (account, reserve) on-chain.
    /// @param vars The decoded hook parameters
    /// @param account The executing smart account
    function _requireNoIdlePosition(AaveV4V2Vars memory vars, address account) internal view {
        if (!_isUsingAsCollateral(vars, account) && _suppliedAssets(vars, account) != 0) {
            revert RESERVE_HAS_IDLE_POSITION();
        }
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
    ///      specific error instead of failing later as DELTA_MISMATCH.
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
        uint256 supplied = _suppliedAssets(vars, account);
        if (supplied == 0) revert AMOUNT_NOT_VALID();
        if (!_isUsingAsCollateral(vars, account)) revert RESERVE_NOT_COLLATERAL();
        if (vars.usePrevHookAmount) {
            amount = _resolvePrevHookOutput(prevHook, account, vars.collateralToken);
        } else if (vars.amount1 == 0) {
            revert AMOUNT_NOT_VALID();
        } else if (vars.amount1 == type(uint256).max) {
            return (supplied, true);
        } else {
            amount = vars.amount1;
        }
        if (amount > supplied) revert AMOUNT_NOT_VALID();
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
