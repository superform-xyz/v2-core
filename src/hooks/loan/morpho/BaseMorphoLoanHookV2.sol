// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { MarketParamsLib } from "../../../vendor/morpho/MarketParamsLib.sol";
import { MorphoBalancesLib } from "../../../vendor/morpho/MorphoBalancesLib.sol";
import { IMorpho, IMorphoStaticTyping, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { BaseLoanHookV2 } from "../BaseLoanHookV2.sol";

/// @title BaseMorphoLoanHookV2
/// @author Superform Labs
/// @notice Base abstract hook for the V2 Morpho Blue loan hooks (open / close / standalone repay)
/// @dev One canonical 230-byte layout is shared by all three Morpho V2 hooks
///      (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92); // market identity only — never priced
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 amount1 = BytesLib.toUint256(data, 132); // open: collateral; close/repay: repay CAP
/// @notice         uint256 amount2 = BytesLib.toUint256(data, 164); // open: borrow; close: withdraw; repay: 0
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196); // canonical 0x00/0x01
/// @notice         uint256 lltv = BytesLib.toUint256(data, 197); // market identity
/// @notice         byte reserved = data[229]; // must be 0x00
/// @dev Standalone repay reserves the amount2 word as zero, keeping one canonical provider layout
///      without advertising a second active leg.
///      SECURITY INVARIANT: All Morpho calls MUST use empty callback data ("") to prevent
///      reentrancy through Morpho's callback mechanism (onMorphoSupply, onMorphoRepay, etc.).
///      No amount is ever derived from the oracle or an LTV ratio inside the hook.
abstract contract BaseMorphoLoanHookV2 is BaseLoanHookV2 {
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant LOAN_TOKEN_OFFSET = 52;
    uint256 internal constant COLLATERAL_TOKEN_OFFSET = 72;
    uint256 internal constant ORACLE_OFFSET = 92;
    uint256 internal constant IRM_OFFSET = 112;
    /// @dev Alias of the inherited slot so Morpho code reads the same as the Aave families
    uint256 internal constant AMOUNT1_OFFSET = AMOUNT_POSITION; // 132
    uint256 internal constant AMOUNT2_OFFSET = 164;
    /// @dev Alias of the inherited slot so Morpho code reads the same as the Aave families
    uint256 internal constant USE_PREV_OFFSET = USE_PREV_HOOK_AMOUNT_POSITION; // 196
    uint256 internal constant LLTV_OFFSET = 197;
    uint256 internal constant RESERVED_BYTE_OFFSET = 229;

    /// @notice Exact hook-data length for every Morpho V2 loan hook
    uint256 internal constant MORPHO_V2_DATA_LENGTH = 230;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the Morpho Blue singleton
    address public immutable morpho;

    /// @notice Statically-typed view of the Morpho Blue singleton
    IMorphoStaticTyping public immutable morphoStaticTyping;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct MorphoV2Vars {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 amount1;
        uint256 amount2;
        bool usePrevHookAmount;
        uint256 lltv;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton
    /// @param hookSubtype_ Hook subtype identifier (LOAN or LOAN_REPAY)
    constructor(address morpho_, bytes32 hookSubtype_) BaseLoanHookV2(hookSubtype_) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        morpho = morpho_;
        morphoStaticTyping = IMorphoStaticTyping(morpho_);
    }

    /*//////////////////////////////////////////////////////////////
                       SIZING-INTERFACE PLUMBING
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseLoanHook
    /// @dev Same offset (196) as the inherited implementation, but with the exact-length guard and
    ///      a strict canonical-boolean read so this view never disagrees with execution-time
    ///      decoding on malformed data (custom error instead of an out-of-bounds panic)
    function decodeUsePrevHookAmount(bytes memory data) external pure override returns (bool) {
        if (data.length != MORPHO_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        return _decodeStrictBool(data, USE_PREV_OFFSET);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Strictly decodes the canonical Morpho V2 layout.
    ///      Enforces: exact 230-byte length, nonzero market addresses, distinct loan/collateral
    ///      tokens, canonical usePrevHookAmount boolean, zero reserved byte, and — when
    ///      `secondaryReserved` is true (standalone repay) — a zero amount2 word.
    /// @param data The hook data
    /// @param secondaryReserved True for standalone repay (amount2 must be zero)
    /// @return vars The decoded hook parameters
    function _decodeMorphoV2(
        bytes memory data,
        bool secondaryReserved
    )
        internal
        pure
        returns (MorphoV2Vars memory vars)
    {
        if (data.length != MORPHO_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.oracle = BytesLib.toAddress(data, ORACLE_OFFSET);
        vars.irm = BytesLib.toAddress(data, IRM_OFFSET);

        if (
            vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.oracle == address(0)
                || vars.irm == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
        if (vars.loanToken == vars.collateralToken) revert IDENTICAL_TOKENS();

        vars.amount1 = BytesLib.toUint256(data, AMOUNT1_OFFSET);
        vars.amount2 = BytesLib.toUint256(data, AMOUNT2_OFFSET);
        vars.usePrevHookAmount = _decodeStrictBool(data, USE_PREV_OFFSET);
        vars.lltv = BytesLib.toUint256(data, LLTV_OFFSET);
        _requireZeroByte(data, RESERVED_BYTE_OFFSET);

        // Reuse the already-decoded word instead of re-reading it
        if (secondaryReserved && vars.amount2 != 0) revert RESERVED_FIELD_NOT_ZERO();
    }

    /// @dev Generates the Morpho Blue market params from decoded vars
    function _marketParams(MorphoV2Vars memory vars) internal pure returns (MarketParams memory) {
        return MarketParams({
            loanToken: vars.loanToken,
            collateralToken: vars.collateralToken,
            oracle: vars.oracle,
            irm: vars.irm,
            lltv: vars.lltv
        });
    }

    /// @dev Returns the account's borrow shares on the market
    function _borrowShares(MarketParams memory marketParams, address account) internal view returns (uint256) {
        (, uint128 borrowShares,) = morphoStaticTyping.position(marketParams.id(), account);
        return uint256(borrowShares);
    }

    /// @dev Returns the account's posted collateral on the market
    function _positionCollateral(MarketParams memory marketParams, address account) internal view returns (uint256) {
        (,, uint128 collateral) = morphoStaticTyping.position(marketParams.id(), account);
        return uint256(collateral);
    }

    /// @dev Accrues interest on the market (call from _preExecute before resolving expected amounts)
    function _accrueInterest(MorphoV2Vars memory vars) internal {
        IMorpho(morpho).accrueInterest(_marketParams(vars));
    }

    /// @dev Resolves the repay leg shared by MorphoRepayHookV2 and MorphoRepayAndWithdrawHookV2.
    ///      The primary word is a CAP: the resolved repayment is min(cap, accrued debt). Zero
    ///      borrow shares resolves to (0, 0, false) — the repay leg is skipped — instead of
    ///      reverting, and the debt check precedes previous-hook resolution (the PREV pipe is
    ///      never consulted with zero debt). A cap covering the whole debt (including the
    ///      type(uint256).max word, subsumed by the min) selects a shares-denominated full
    ///      repayment: toSharesDown(toAssetsUp(shares)) rounding makes an exact-assets clear
    ///      unsafe, so any predicted clear MUST execute via repay(assets = 0, shares). The
    ///      resolved repayAssets equals what toAssetsUp(borrowShares) pulls at execution — exact
    ///      within the transaction because accrual is timestamp-based. cap < debt executes the
    ///      assets path and pulls exactly `cap`.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @param marketParams The Morpho market params derived from `vars`
    /// @return repayAssets The exact debt-asset amount the repay call will pull (0 = leg skipped)
    /// @return borrowShares The account's borrow shares (only meaningful when `fullRepay`)
    /// @return fullRepay True when the resolved repayment clears the debt (shares path)
    function _resolveRepayLeg(
        address prevHook,
        address account,
        MorphoV2Vars memory vars,
        MarketParams memory marketParams
    )
        internal
        view
        returns (uint256 repayAssets, uint256 borrowShares, bool fullRepay)
    {
        borrowShares = _borrowShares(marketParams, account);
        if (borrowShares == 0) return (0, 0, false);

        uint256 debt = MorphoBalancesLib.expectedBorrowAssets(IMorpho(morpho), marketParams, account);
        (repayAssets, fullRepay) =
            _resolveRepayCap(prevHook, account, vars.loanToken, vars.amount1, vars.usePrevHookAmount, debt);
    }

    /// @dev Full market-identity inspector payload: Morpho singleton, loan token, collateral
    ///      token, oracle, IRM and LLTV. Amount fields, usePrevHookAmount and the strategy header
    ///      are intentionally excluded.
    /// @param vars The decoded hook parameters
    /// @return The packed inspector payload
    function _inspectMorphoV2(MorphoV2Vars memory vars) internal view returns (bytes memory) {
        return abi.encodePacked(morpho, vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
    }
}
