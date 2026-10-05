// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { BaseLoanHookV2 } from "../BaseLoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { AaveV4ReserveKey } from "../../../libraries/AaveV4ReserveKey.sol";
import { ISuperHook, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseAaveV4MoneyMarketHook
/// @author Superform Labs
/// @notice Base for the Aave V4 idle lend / redeem hooks (AaveV4LendHook, AaveV4RedeemHook) — the
///         MONEY_MARKET, vault-main-accounted side of the Aave V4 family (SUP-21142). Twin of
///         BaseMorphoMoneyMarketHook.
/// @dev Inherited ONLY by the two idle leaves. It deliberately does NOT inherit BaseAaveV4LoanHook /
///      BaseAaveV4LoanHookV2: those are the LOAN PLEDGE / BORROW / RELEASE bases (241-byte layout, a
///      borrow reserve is mandatory, and the supply leaf enables collateral). Idle supply is a
///      deposit/withdraw vault-main — no collateral bit, no debt — so it gets its own 189-byte layout.
///      BaseLoanHookV2 is used for its strict decoding and exact wallet-delta settlement helpers; the
///      shared loan bases fix `HookType.NONACCOUNTING` and stay untouched — `hookType` is plain storage
///      on BaseHook, so this base reassigns it after construction (INFLOW lend / OUTFLOW redeem) with
///      zero impact on any LOAN sibling (the same trick as BaseMorphoMoneyMarketHook).
///
/// @dev Data layout (exact 189 bytes; standard 52-byte strategy header + hook-specific). SUP-21254 APPENDED
///      `borrowReserveId` rather than inserting it, so every pre-existing offset is unchanged and the whole
///      sizing surface moved by one constant:
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Aave V4 supply YS id
/// @notice         address yieldSource = data.extractYieldSource(); // computeMarketKey(spoke, supplyId, borrowId)
/// @notice         address underlying = BytesLib.toAddress(data, 52);
/// @notice         address spoke = BytesLib.toAddress(data, 72);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 92); // THE reserve this op moves
/// @notice         uint256 amount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 156); // canonical 0x00 / 0x01
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 157); // identity only; never called
///
///      HEADER IDENTITY (SUP-21254): offset 32 carries the MARKET KEY —
///      `keccak256(abi.encode(spoke, supplyReserveId, borrowReserveId, MARKET_KEY_DOMAIN))` truncated to an
///      address, byte-identical to `AaveV4ReserveRegistryV2.computeMarketKey`, the same key the six V2 LOAN
///      hooks pin. Unlike theirs, THIS header is also a SuperLedger key and an oracle argument: the pair is
///      INFLOW / OUTFLOW, so `SuperExecutorBase._updateAccounting` reads it and `AaveV4ReserveOracle`
///      resolves it to the market's SUPPLY leg — which, by the one-word construction above, is the reserve
///      this op moved. A consequence worth stating: because the oracle reverts
///      `RESERVE_NOT_REGISTERED` for an unregistered market, an idle op can only settle under a market the
///      registry has blessed, so the accounting allowlist is now market-granular for free. The ops invariant
///      that keeps ONE ledger key per idle position is `marketRefs[computeReserveKey(spoke, supplyReserveId)]
///      <= 1` for every idle-lendable reserve — curated in the registry, not enforceable from calldata, and
///      satisfied naturally by the Base MAG7 topology. The header was never the
///      Spoke. SuperExecutorBase posts INFLOW / OUTFLOW to SuperLedger keyed by that address and
///      AaveV4ReserveOracle resolves the same key through the registry (identity PPS, asset
///      units). Keying by the Spoke would collide every reserve of a spoke, and every LOAN position on
///      it, onto one accounting slot. The key is recomputed locally (pure) and pinned against the body
///      in the decoder, so build, preExecute AND inspect all fail closed on a mismatch. The sizing views
///      (`decodeAmounts`, `replaceCalldataAmounts`, `decodeUsePrevHookAmount`) check the exact length and
///      the canonical bool only — they are transformation APIs and do not authenticate the header; a
///      template that sizes must also pass inspect() / build(). The Spoke stays on the hook as the only
///      call target and approve spender.
///
///      FAIL-CLOSED ALLOWLIST, now MARKET-granular: the hooks never consult the registry, but the header is
///      a ledger key, so an unregistered MARKET reverts at accounting (`RESERVE_NOT_REGISTERED`, raised by
///      the oracle while resolving the market key) and the whole userOp reverts. SUP-21254 therefore tightened
///      this allowlist from per-reserve to per-market for free. Registration is an ops precondition, exactly
///      like Morpho markets.
///      SECURITY INVARIANT: onBehalfOf is always hardcoded to `account` — never arbitrary.
///      ONE MODE PER (ACCOUNT, RESERVE): a reserve the account has flagged as collateral is refused by
///      both hooks (RESERVE_IS_COLLATERAL) — see _requireNotCollateral.
///
///      LIMITATION: the inherited non-virtual ISuperHookLoans getters read the LOAN layout offsets.
///      getLoanTokenAddress(data) returns the underlying (truthful), but getCollateralTokenAddress(data)
///      returns the SPOKE (offset 72) and getCollateralTokenBalance(account, data) reverts (the Spoke is
///      not an ERC-20). Neither idle leaf calls them or _snapshotBalances — both snapshot the underlying
///      directly. Consumers must not treat offset 72 as a collateral token for these hooks (same accepted
///      shape as EulerRepayHook; ERC-165 never advertises ISuperHookLoans).
abstract contract BaseAaveV4MoneyMarketHook is BaseLoanHookV2 {
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant IDLE_UNDERLYING_OFFSET = 52;
    uint256 internal constant IDLE_SPOKE_OFFSET = 72;
    uint256 internal constant IDLE_RESERVE_ID_OFFSET = 92;
    uint256 internal constant IDLE_AMOUNT_OFFSET = 124;
    uint256 internal constant IDLE_USE_PREV_OFFSET = 156;
    /// @notice The market's borrow leg — identity only, appended after the bool so no prior offset moved
    uint256 internal constant IDLE_BORROW_RESERVE_ID_OFFSET = 157;

    /// @notice Exact hook-data length for both idle hooks (157 before SUP-21254)
    uint256 internal constant IDLE_DATA_LENGTH = 189;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct IdleVars {
        address marketKey; // header offset 32 — the market key; ledger / PPS key, resolved to its SUPPLY leg
        address underlying;
        address spoke;
        uint256 supplyReserveId; // the reserve the Spoke call moves AND the market's supply leg — one word
        uint256 borrowReserveId; // identity only: completes the market key, never passed to the Spoke
        uint256 amount;
        bool usePrevHookAmount;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the header yield-source oracle id (offset 0) is zero
    error ORACLE_ID_NOT_VALID();

    /// @notice Thrown when the calldata underlying is not the reserve's underlying on the Spoke
    error TOKEN_RESERVE_MISMATCH();

    /// @notice Thrown when the reserve is flagged as collateral for the account (LOAN mode, not idle)
    error RESERVE_IS_COLLATERAL();

    /// @notice Thrown on lend when the account already borrows the same reserve (supply + debt on one key)
    error RESERVE_IS_BORROWED();

    /// @notice Thrown when the body names one reserve as both the market's supply and borrow leg
    /// @dev Same name as `AaveV4ReserveRegistryV2.IDENTICAL_RESERVES`, so registry/hook parity is nominal
    ///      as well as semantic: a header these hooks accept is always a market the registry could register.
    error IDENTICAL_RESERVES();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice No constructor args — the Spoke comes from calldata, like every Aave V4 hook
    /// @param hookType_ INFLOW (lend) or OUTFLOW (redeem)
    constructor(ISuperHook.HookType hookType_) BaseLoanHookV2(HookSubTypes.LOAN) {
        // BaseLoanHook fixes NONACCOUNTING for the shared loan family; idle supply is vault-main
        // accounting, so reassign the (storage) type here without touching any base.
        hookType = hookType_;
    }

    /*//////////////////////////////////////////////////////////////
                       SIZING-INTERFACE PLUMBING
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseLoanHook
    /// @dev Idle layout stores usePrevHookAmount at offset 156. Exact-length guard + strict
    ///      canonical-boolean read so this view never disagrees with execution-time decoding.
    function decodeUsePrevHookAmount(bytes memory data) external pure override returns (bool) {
        if (data.length != IDLE_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        return _decodeStrictBool(data, IDLE_USE_PREV_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev Single slot at offset 124 (lend: underlying assets in; redeem: 1:1 share wei in). Exact length only —
    ///      the header is not authenticated here (inspect / build do)
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        if (data.length != IDLE_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, IDLE_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Exact length only; the header passes through unchecked — a mis-keyed template still fails at inspect /
    /// build
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (data.length != IDLE_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], IDLE_AMOUNT_OFFSET);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Strictly decodes the idle layout: exact 189-byte length, nonzero oracle id, nonzero addresses,
    ///      distinct reserve ids, canonical boolean, and the header MARKET key pinned to the body. Pure, so
    ///      `inspect()` shares it and fails closed on the same malformed inputs.
    ///      THE SUPPLY-LEG CONVENTION, BY CONSTRUCTION: the single word at offset 92 is both the
    ///      `supplyReserveId` argument to `computeMarketKey` AND the `reserveId` argument to the Spoke's
    ///      `supply` / `withdraw`. There is no second variable, so "the reserve this op moves is the
    ///      market's supply leg" cannot be violated — the same bug class SUP-21239 closed for the V2 LOAN
    ///      hooks by deleting `_primaryReserveId`, closed here the same way.
    ///      That matters because this header is a SuperLedger key: `AaveV4ReserveOracle` resolves a market
    ///      key to its SUPPLY leg, so the balance the ledger reads is the reserve this op actually moved.
    /// @param data The hook data
    /// @return vars The decoded idle parameters
    function _decodeIdle(bytes memory data) internal pure returns (IdleVars memory vars) {
        if (data.length != IDLE_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();

        vars.marketKey = data.extractYieldSource();
        vars.underlying = BytesLib.toAddress(data, IDLE_UNDERLYING_OFFSET);
        vars.spoke = BytesLib.toAddress(data, IDLE_SPOKE_OFFSET);
        vars.supplyReserveId = BytesLib.toUint256(data, IDLE_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, IDLE_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeStrictBool(data, IDLE_USE_PREV_OFFSET);
        vars.borrowReserveId = BytesLib.toUint256(data, IDLE_BORROW_RESERVE_ID_OFFSET);

        if (vars.marketKey == address(0) || vars.underlying == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        // Self-consistency, before identity: `computeMarketKey(spoke, R, R)` is derivable but is a market
        // `AaveV4ReserveRegistryV2.registerMarket` can never register (its own IDENTICAL_RESERVES), so
        // refusing it here keeps the set of headers these hooks accept a subset of the registry's.
        if (vars.supplyReserveId == vars.borrowReserveId) revert IDENTICAL_RESERVES();
        AaveV4ReserveKey.requireHeaderIsMarketKey(
            vars.marketKey, vars.spoke, vars.supplyReserveId, vars.borrowReserveId
        );
    }

    /// @dev Binds the calldata underlying to the reserve through the Spoke's canonical
    ///      getReserve(reserveId).underlying. The underlying is the approve target, the wallet-delta
    ///      token and the fee `asset`, so a mismatch fails here with a specific error instead of a
    ///      late transferFrom / DELTA_MISMATCH revert. View — called from build and _preExecute only.
    function _requireUnderlyingMatchesReserve(IdleVars memory vars) internal view {
        if (IAaveV4Spoke(vars.spoke).getReserve(vars.supplyReserveId).underlying != vars.underlying) {
            revert TOKEN_RESERVE_MISMATCH();
        }
    }

    /// @dev ONE MODE PER (ACCOUNT, RESERVE): the Spoke's collateral flag is per user and reserve, not
    ///      per deposit. If the account has the reserve enabled as collateral (a LOAN pledge, a position
    ///      manager, or a direct call), an "idle" supply would become seizable collateral, the redeem
    ///      could hit the Spoke's health-factor check, and `getUserSuppliedAssets` — the oracle's
    ///      balance — would mix NONACCOUNTING LOAN supply with ledger-tracked idle supply. Both idle
    ///      hooks therefore refuse a collateral-flagged reserve on build and preExecute (one staticcall).
    ///      The reverse direction is guarded by every recompiled flag-setting LOAN hook (SUP-21141 PLEDGE
    ///      refuses an un-flagged position and RELEASE requires the flag; since SUP-21143 the composite
    ///      V2 OPEN and the V1 Supply / SupplyAndBorrow carry the same `RESERVE_HAS_IDLE_POSITION` guard,
    ///      and CLOSE / V1 Withdraw / V1 RepayAndWithdraw require the flag like RELEASE).
    ///      Only the pre-SUP-21143 deployed OPEN / V1 addresses and a manual `setUsingAsCollateral(true)`
    ///      are unguarded, which the OMS allow-list rule covers (never an idle leaf and one of those for
    ///      one (account, spoke, reserveId)).
    /// @param vars The decoded idle parameters
    /// @param account The executing smart account
    function _requireNotCollateral(IdleVars memory vars, address account) internal view {
        (bool isUsingAsCollateral,) = IAaveV4Spoke(vars.spoke).getUserReserveStatus(vars.supplyReserveId, account);
        if (isUsingAsCollateral) revert RESERVE_IS_COLLATERAL();
    }

    /// @dev Lend-side guard: the collateral rule above PLUS no open debt on the same reserve. Supplying
    ///      the asset the account already borrows is economically pointless (pay the borrow rate, earn
    ///      the lower supply rate) and, once BORROW / REPAY are keyed by the same reserve key
    ///      (SUP-21148), would put a ledger-tracked supply and a debt on one yield-source address.
    ///      Redeem deliberately keeps only the collateral rule, so an exit is never trapped behind a
    ///      debt taken later. Same single staticcall (PR #1018 review, P3-2).
    /// @param vars The decoded idle parameters
    /// @param account The executing smart account
    function _requireIdleLendable(IdleVars memory vars, address account) internal view {
        (bool isUsingAsCollateral, bool isBorrowing) =
            IAaveV4Spoke(vars.spoke).getUserReserveStatus(vars.supplyReserveId, account);
        if (isUsingAsCollateral) revert RESERVE_IS_COLLATERAL();
        if (isBorrowing) revert RESERVE_IS_BORROWED();
    }

    /// @dev The account's supplied assets on the reserve — the SAME read
    ///      AaveV4ReserveOracle performs, so hook units equal oracle units by construction.
    function _suppliedAssets(IdleVars memory vars, address account) internal view returns (uint256) {
        return IAaveV4Spoke(vars.spoke).getUserSuppliedAssets(vars.supplyReserveId, account);
    }

    /// @dev Resolves the amount to move: the previous hook's output (which must be denominated in
    ///      `expectedPrevToken`) when usePrevHookAmount is set, else the calldata word. Deterministic
    ///      within a transaction, so build, _preExecute and _postExecute agree.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded idle parameters
    /// @param expectedPrevToken Token the previous hook must have produced (lend: underlying; redeem: the header market
    /// key) @return The exact amount to move
    function _resolveIdleAmount(
        address prevHook,
        address account,
        IdleVars memory vars,
        address expectedPrevToken
    )
        internal
        view
        returns (uint256)
    {
        return vars.usePrevHookAmount ? _resolvePrevHookOutput(prevHook, account, expectedPrevToken) : vars.amount;
    }

    /// @dev Inspector payload: MARKET key FIRST (the ledger / PPS key, same rule as the Morpho idle hooks —
    ///      leaves are hashed over these raw bytes), then spoke, underlying and the SUPPLY reserve id.
    ///      Still 92 bytes in the same field order: SUP-21254 changed only what the leading 20 bytes mean.
    ///      Amount, usePrevHookAmount, the oracle id AND `borrowReserveId` are intentionally excluded.
    ///      WHY EXCLUDING `borrowReserveId` LOSES NO IDENTITY — AND THE CONDITION THAT MAKES IT TRUE: the
    ///      market key is a cryptographic commitment to `(spoke, supplyReserveId, borrowReserveId,
    ///      MARKET_KEY_DOMAIN)`, so two bodies differing only in the borrow leg produce different keys,
    ///      different payloads and different leaves. That argument holds ONLY while the header is pinned to
    ///      `computeMarketKey`. If the pin were ever weakened back to a reserve key, offset 157 would become
    ///      32 bytes of signed-but-uncommitted calldata and this field would have to be added here.
    function _inspectIdle(IdleVars memory vars) internal pure returns (bytes memory) {
        return abi.encodePacked(vars.marketKey, vars.spoke, vars.underlying, vars.supplyReserveId);
    }
}
