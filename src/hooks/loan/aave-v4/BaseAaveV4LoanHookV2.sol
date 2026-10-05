// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { BaseLoanHookV2 } from "../BaseLoanHookV2.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { AaveV4ReserveKey } from "../../../libraries/AaveV4ReserveKey.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseAaveV4LoanHookV2
/// @author Superform Labs
/// @notice Base abstract hook for the six V2 Aave V4 Hub-and-Spoke loan hooks: the composite
///         OPEN / REPAY / CLOSE and, through BaseAaveV4StandaloneLoanHookV2, the standalone
///         PLEDGE / BORROW / RELEASE
/// @dev One canonical 241-byte layout is shared by all six Aave V4 V2 loan hooks
///      (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Aave V4 YS oracle id
/// @notice         address yieldSource = data.extractYieldSource(); // computeMarketKey(spoke, supplyId, borrowId)
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address spoke = BytesLib.toAddress(data, 92);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 112);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 144);
/// @notice         uint256 amount1 = BytesLib.toUint256(data, 176); // open: supply; close/repay: repay CAP
/// @notice         uint256 amount2 = BytesLib.toUint256(data, 208); // open: borrow; close: withdraw; repay: 0
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 240); // canonical 0x00/0x01
/// @dev Standalone repay reserves the amount2 word as zero, keeping one canonical provider layout
///      without advertising a second active leg.
///      The Spoke address comes from calldata rather than the constructor, enabling a single hook
///      deployment to work with any Aave V4 Spoke.
///      Reserve/token binding: each reserve id is resolved through the Spoke's canonical
///      getReserve(reserveId).underlying and must match the token declared in calldata, otherwise
///      the hook reverts before any provider call.
///      HEADER IDENTITY (SUP-21239, superseding SUP-21143's per-reserve rule; same shape as Morpho Blue's
///      market key): `yieldSource` (offset 32) MUST equal
///      `AaveV4ReserveKey.computeMarketKey(spoke, supplyReserveId, borrowReserveId)` — the lower 20 bytes of
///      `keccak256(abi.encode(spoke, supplyReserveId, borrowReserveId, MARKET_KEY_DOMAIN))`. One economic
///      market is therefore ONE yield source in merkle leaves, the vault whitelist and the UI, instead of the
///      two unrelated reserve keys the per-leg rule produced. ORDER IS SIGNIFICANT: the ids are never sorted,
///      so "collateral A, borrow B" and "collateral B, borrow A" are different markets.
///      The key is a function of the WHOLE body, which is why there is no `_primaryReserveId` any more: no leg
///      is selected, so the "override picked the wrong leg" bug class is closed by construction rather than by
///      convention. Mismatch reverts `AaveV4ReserveKey.MARKET_KEY_MISMATCH`.
///      The pin runs inside the pure decoder, so build, preExecute, inspect, decodeAmounts and
///      replaceCalldataAmounts all fail closed on a crafted header (decodeUsePrevHookAmount checks length +
///      canonical bool only). The Spoke (offset 92) remains the ONLY call target and approve spender; the key
///      is never called: `marketKey` appears only in the zero-check, the pin and the inspector payload, never
///      as an `Execution.target` or an approve spender. (The Spoke is the only PROVIDER target; the builds also
///      target `loanToken` / `collateralToken` for `IERC20.approve`, with the Spoke as spender.) The key is
///      also not oracle-resolvable: `AaveV4ReserveOracle` reads reserve legs only, so a market key passed to
///      any of its REGISTRY-RESOLVING reads reverts `RESERVE_NOT_REGISTERED`. Its `pure` identity converters
///      (`getShareOutput` / `getAssetOutput` / …) ignore the yield-source argument and still return a number
///      for any address — they read no state, so that is arithmetic, not a NAV read. `yieldSourceOracleId` (offset 0)
/// must be nonzero (ORACLE_ID_NOT_VALID) and is otherwise identity for off-chain consumers: LOAN hooks are
///      NONACCOUNTING, so the executor never reads the header for them and the market key is never a
///      SuperLedger key. NAV stays per reserve leg (`computeReserveKey` / `computeDebtKey`), which is also why
///      the V1 LOAN six and the idle INFLOW/OUTFLOW pair deliberately keep the reserve-key rule.
///      Registering a market in `AaveV4ReserveRegistryV2` records its binding for off-chain consumers; it does
///      NOT gate execution, because these hooks never call the registry.
///      SECURITY INVARIANT: onBehalfOf is always hardcoded to `account` — never arbitrary.
abstract contract BaseAaveV4LoanHookV2 is BaseLoanHookV2 {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant LOAN_TOKEN_OFFSET = 52;
    uint256 internal constant COLLATERAL_TOKEN_OFFSET = 72;
    uint256 internal constant SPOKE_OFFSET = 92;
    uint256 internal constant SUPPLY_RESERVE_ID_OFFSET = 112;
    uint256 internal constant BORROW_RESERVE_ID_OFFSET = 144;
    uint256 internal constant AMOUNT1_OFFSET = 176;
    uint256 internal constant AMOUNT2_OFFSET = 208;
    uint256 internal constant USE_PREV_OFFSET = 240;

    /// @notice Exact hook-data length for every Aave V4 V2 loan hook
    uint256 internal constant AAVE_V4_V2_DATA_LENGTH = 241;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct AaveV4V2Vars {
        address marketKey; // header offset 32 — AaveV4ReserveKey.computeMarketKey(spoke, supplyId, borrowId)
        address loanToken;
        address collateralToken;
        address spoke;
        uint256 supplyReserveId;
        uint256 borrowReserveId;
        uint256 amount1;
        uint256 amount2;
        bool usePrevHookAmount;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a reserve id's underlying does not match the declared token
    error TOKEN_RESERVE_MISMATCH();

    /// @notice Thrown when a supply that would flag the reserve as collateral targets a reserve already carrying an
    ///         un-flagged (idle MONEY_MARKET, ledger-tracked) position
    error RESERVE_HAS_IDLE_POSITION();

    /// @notice Thrown when a withdraw leg (RELEASE, CLOSE) targets a reserve that is not enabled as collateral for the
    ///         account — an un-flagged position is the idle MONEY_MARKET side's (ledger-tracked)
    error RESERVE_NOT_COLLATERAL();

    /// @notice Thrown when an exact or previous-hook withdraw amount exceeds the account's supplied position (Aave
    ///         would otherwise silently convert it into a full withdrawal)
    /// @param requested The exact amount asked for
    /// @param supplied The account's live supplied assets on the supply reserve
    error WITHDRAW_EXCEEDS_SUPPLIED(uint256 requested, uint256 supplied);

    /// @notice Thrown when the header `yieldSourceOracleId` (offset 0) is zero
    error ORACLE_ID_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice No constructor args — Spoke address comes from calldata
    /// @param hookSubtype_ Hook subtype identifier (LOAN or LOAN_REPAY)
    constructor(bytes32 hookSubtype_) BaseLoanHookV2(hookSubtype_) { }

    /*//////////////////////////////////////////////////////////////
                       SIZING-INTERFACE PLUMBING
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseLoanHook
    /// @dev Aave V4 V2 layout stores usePrevHookAmount at offset 240 (not the Morpho-shaped 196).
    ///      Exact-length guard + strict canonical-boolean read so this view never disagrees with
    ///      execution-time decoding on malformed data (custom error instead of an OOB panic).
    function decodeUsePrevHookAmount(bytes memory data) external pure override returns (bool) {
        if (data.length != AAVE_V4_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        return _decodeStrictBool(data, USE_PREV_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Single-slot default for the single-leg hooks (REPAY, PLEDGE, BORROW, RELEASE): amount1 lives at
    ///      offset 176 (not the Morpho-shaped 132). STRICT: runs the full decode (exact length, addresses, header
    ///      key, canonical bool, reserved secondary word) so an off-chain sizer can never size or rewrite a payload
    ///      that build() / inspect() reject. Composite hooks override with two-slot versions of the same strictness.
    function decodeAmounts(bytes memory data) external pure virtual override returns (uint256[] memory amounts) {
        _decodeAaveV4V2(data, true);
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT1_OFFSET);
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Single-slot default replacing amount1 at offset 176 after the strict decode; the header, the reserved
    ///      secondary word and the boolean byte are left untouched, so the result still decodes
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        virtual
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

    /// @dev Strictly decodes the canonical Aave V4 V2 layout.
    ///      Enforces: exact 241-byte length, nonzero oracle id, nonzero addresses (header key included), distinct
    ///      loan/collateral tokens, header key == `AaveV4ReserveKey.computeMarketKey(spoke, supplyReserveId,
    ///      borrowReserveId)` (SUP-21239 — there is no per-op primary reserve any more), canonical
    ///      usePrevHookAmount boolean, and — when `secondaryReserved` is true (standalone legs) — a
    ///      zero amount2 word. Reserve/token binding is validated separately via _validateReserves
    ///      (view) so this decoder stays pure for inspect() and the sizing views.
    /// @param data The hook data
    /// @param secondaryReserved True for the standalone legs (REPAY / PLEDGE / BORROW / RELEASE): amount2 must be
    ///        zero
    /// @return vars The decoded hook parameters
    function _decodeAaveV4V2(
        bytes memory data,
        bool secondaryReserved
    )
        internal
        pure
        returns (AaveV4V2Vars memory vars)
    {
        if (data.length != AAVE_V4_V2_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();

        vars.marketKey = data.extractYieldSource();
        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.spoke = BytesLib.toAddress(data, SPOKE_OFFSET);

        if (
            vars.marketKey == address(0) || vars.loanToken == address(0) || vars.collateralToken == address(0)
                || vars.spoke == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
        if (vars.loanToken == vars.collateralToken) revert IDENTICAL_TOKENS();

        vars.supplyReserveId = BytesLib.toUint256(data, SUPPLY_RESERVE_ID_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, BORROW_RESERVE_ID_OFFSET);
        vars.amount1 = BytesLib.toUint256(data, AMOUNT1_OFFSET);
        vars.amount2 = BytesLib.toUint256(data, AMOUNT2_OFFSET);
        vars.usePrevHookAmount = _decodeStrictBool(data, USE_PREV_OFFSET);

        // Reuse the already-decoded word instead of re-reading it
        if (secondaryReserved && vars.amount2 != 0) revert RESERVED_FIELD_NOT_ZERO();
        // Header pin, after every format check: the signed yield source must be THIS op's MARKET on THIS
        // spoke (format errors surface first; identity errors second). A function of the WHOLE body, so there
        // is no per-hook leg to select — see the removal of `_primaryReserveId` (SUP-21239).
        AaveV4ReserveKey.requireHeaderIsMarketKey(
            vars.marketKey, vars.spoke, vars.supplyReserveId, vars.borrowReserveId
        );
    }

    /// @dev Binds both reserve ids to the declared tokens through the Spoke's canonical
    ///      getReserve(reserveId).underlying; reverts before any provider call on mismatch
    function _validateReserves(AaveV4V2Vars memory vars) internal view {
        IAaveV4Spoke spoke = IAaveV4Spoke(vars.spoke);
        if (spoke.getReserve(vars.supplyReserveId).underlying != vars.collateralToken) {
            revert TOKEN_RESERVE_MISMATCH();
        }
        if (spoke.getReserve(vars.borrowReserveId).underlying != vars.loanToken) {
            revert TOKEN_RESERVE_MISMATCH();
        }
    }

    /// @dev The account's collateral flag on the supply reserve, read through the Spoke
    /// @param vars The decoded hook parameters
    /// @param account The executing smart account
    /// @return flag True when the supply reserve is enabled as collateral for the account
    function _isUsingAsCollateral(AaveV4V2Vars memory vars, address account) internal view returns (bool flag) {
        (flag,) = IAaveV4Spoke(vars.spoke).getUserReserveStatus(vars.supplyReserveId, account);
    }

    /// @dev Mode guard for every supply that flags the reserve as collateral (OPEN, PLEDGE). A supplied position
    ///      that is NOT flagged as collateral belongs to the idle MONEY_MARKET side (AaveV4LendHook, ledger-tracked):
    ///      supplying-and-flagging on top of it would flip the flag and let a later RELEASE / CLOSE pay the idle part
    ///      out with no ledger update, so it is refused before any provider execution is emitted. A fresh reserve
    ///      (zero supply) or an already-flagged one passes. Mirror of the idle hooks' RESERVE_IS_COLLATERAL —
    ///      together they keep one mode per (account, reserve) on-chain.
    /// @param vars The decoded hook parameters
    /// @param account The executing smart account
    function _requireNoIdlePosition(AaveV4V2Vars memory vars, address account) internal view {
        if (!_isUsingAsCollateral(vars, account) && _suppliedAssets(vars, account) != 0) {
            revert RESERVE_HAS_IDLE_POSITION();
        }
    }

    /// @dev Shared gate for every withdraw leg (RELEASE, CLOSE): the account must hold a position on the supply
    ///      reserve (empty → AMOUNT_NOT_VALID on every path) and that position must be flagged as collateral —
    ///      an un-flagged position is the idle MONEY_MARKET side's (ledger-tracked); paying it out here would bypass
    ///      the ledger outflow (RESERVE_NOT_COLLATERAL). Read before any provider execution is emitted.
    /// @param vars The decoded hook parameters
    /// @param account The executing smart account
    /// @return supplied The account's live supplied assets on the supply reserve
    function _requireCollateralPosition(
        AaveV4V2Vars memory vars,
        address account
    )
        internal
        view
        returns (uint256 supplied)
    {
        supplied = _suppliedAssets(vars, account);
        if (supplied == 0) revert AMOUNT_NOT_VALID();
        if (!_isUsingAsCollateral(vars, account)) revert RESERVE_NOT_COLLATERAL();
    }

    /// @dev Returns the account's total debt (drawn + premium) on the borrow reserve
    function _totalDebt(AaveV4V2Vars memory vars, address account) internal view returns (uint256) {
        (uint256 drawnDebt, uint256 premiumDebt) = IAaveV4Spoke(vars.spoke).getUserDebt(vars.borrowReserveId, account);
        return drawnDebt + premiumDebt;
    }

    /// @dev Returns the account's supplied assets on the supply reserve
    function _suppliedAssets(AaveV4V2Vars memory vars, address account) internal view returns (uint256) {
        return IAaveV4Spoke(vars.spoke).getUserSuppliedAssets(vars.supplyReserveId, account);
    }

    /// @dev Resolves the repay leg shared by AaveV4RepayHookV2 and AaveV4RepayAndWithdrawHookV2.
    ///      The primary word is a CAP: the resolved repayment is min(cap, total debt), where the
    ///      total debt is drawn + premium via the Spoke's getUserDebt. Zero outstanding debt
    ///      resolves to (0, true) — the repay leg is skipped — instead of reverting, and the debt
    ///      check precedes previous-hook resolution. `repayAssets` is exact for the transaction
    ///      because build, approval and repay execute in the same transaction. When `fullRepay`
    ///      (predicted clear), the repay call passes type(uint256).max so the Spoke clears the
    ///      debt natively without rounding dust while still pulling exactly `repayAssets`; the
    ///      approval always uses the resolved amount, never max.
    ///      CALLER CAVEAT: gate on `repayAssets == 0` BEFORE consulting `fullRepay` — zero debt
    ///      returns (0, true) and a repay(max) call must never be emitted with no debt.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded hook parameters
    /// @return repayAssets The exact debt-asset amount the repay call will pull (0 = leg skipped)
    /// @return fullRepay True when the resolved repayment clears the debt (repay(max) path)
    function _resolveRepayLeg(
        address prevHook,
        address account,
        AaveV4V2Vars memory vars
    )
        internal
        view
        returns (uint256 repayAssets, bool fullRepay)
    {
        (repayAssets, fullRepay) = _resolveRepayCap(
            prevHook, account, vars.loanToken, vars.amount1, vars.usePrevHookAmount, _totalDebt(vars, account)
        );
    }

    /// @dev Full market-identity inspector payload, MARKET key FIRST (the intent / indexing key — leaves are
    ///      hashed over these raw bytes, same rule as Morpho and the idle Aave hooks), then spoke, loan token,
    ///      collateral token and both reserve ids: 144 bytes. Byte layout and length are UNCHANGED by
    ///      SUP-21239 — only the meaning of the first 20 bytes moved from the primary reserve's key to the
    ///      market key. Amount fields, usePrevHookAmount and the oracle id are intentionally excluded.
    function _inspectAaveV4V2(AaveV4V2Vars memory vars) internal pure returns (bytes memory) {
        return abi.encodePacked(
            vars.marketKey, vars.spoke, vars.loanToken, vars.collateralToken, vars.supplyReserveId, vars.borrowReserveId
        );
    }
}
