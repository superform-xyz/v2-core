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
import { ISuperHook, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title BaseAaveV4MoneyMarketHook
/// @author Superform Labs
/// @notice Base for the Aave V4 idle lend / redeem hooks (AaveV4LendHook, AaveV4RedeemHook) — the
///         MONEY_MARKET, vault-main-accounted side of the Aave V4 family (SUP-21142). Twin of
///         BaseMorphoMoneyMarketHook.
/// @dev Inherited ONLY by the two idle leaves. It deliberately does NOT inherit BaseAaveV4LoanHook /
///      BaseAaveV4LoanHookV2: those are the LOAN PLEDGE / BORROW / RELEASE bases (241-byte layout, a
///      borrow reserve is mandatory, and the supply leaf enables collateral). Idle supply is a
///      deposit/withdraw vault-main — no collateral bit, no debt — so it gets its own 157-byte layout.
///      BaseLoanHookV2 is used for its strict decoding and exact wallet-delta settlement helpers; the
///      shared loan bases fix `HookType.NONACCOUNTING` and stay untouched — `hookType` is plain storage
///      on BaseHook, so this base reassigns it after construction (INFLOW lend / OUTFLOW redeem) with
///      zero impact on any LOAN sibling (the same trick as BaseMorphoMoneyMarketHook).
///
/// @dev Data layout (exact 157 bytes; standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Aave V4 supply YS id
/// @notice         address yieldSource = data.extractYieldSource(); // registry reserve key (spoke, supplyReserveId)
/// @notice         address underlying = BytesLib.toAddress(data, 52);
/// @notice         address spoke = BytesLib.toAddress(data, 72);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 156); // canonical 0x00 / 0x01
///
///      HEADER IDENTITY: offset 32 carries the RESERVE KEY — `keccak256(abi.encode(spoke, reserveId))`
///      truncated to an address, byte-identical to `AaveV4ReserveRegistry.computeReserveKey` — never the
///      Spoke. SuperExecutorBase posts INFLOW / OUTFLOW to SuperLedger keyed by that address and
///      AaveV4SupplyYieldSourceOracle resolves the same key through the registry (identity PPS, asset
///      units). Keying by the Spoke would collide every reserve of a spoke, and every LOAN position on
///      it, onto one accounting slot. The key is recomputed locally (pure) and pinned against the body
///      in the decoder, so build, preExecute AND inspect all fail closed on a mismatch. The Spoke stays
///      on the hook as the only call target and approve spender.
///
///      FAIL-CLOSED ALLOWLIST: the hooks never consult the registry; a reserve whose key is not
///      registered reverts at accounting (`RESERVE_NOT_REGISTERED` from the oracle), so the whole
///      userOp reverts. Registration is an ops precondition, exactly like Morpho markets.
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

    /// @notice Exact hook-data length for both idle hooks
    uint256 internal constant IDLE_DATA_LENGTH = 157;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct IdleVars {
        address reserveKey; // header offset 32 — registry reserve key (accounting / PPS key)
        address underlying;
        address spoke;
        uint256 reserveId;
        uint256 amount;
        bool usePrevHookAmount;
    }

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the header yield-source oracle id (offset 0) is zero
    error ORACLE_ID_NOT_VALID();

    /// @notice Thrown when the header yield source (offset 32) is not computeReserveKey(spoke, reserveId)
    error RESERVE_KEY_MISMATCH();

    /// @notice Thrown when the calldata underlying is not the reserve's underlying on the Spoke
    error TOKEN_RESERVE_MISMATCH();

    /// @notice Thrown when the reserve is flagged as collateral for the account (LOAN mode, not idle)
    error RESERVE_IS_COLLATERAL();

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
    /// @dev Single slot at offset 124 (lend: underlying assets in; redeem: 1:1 share wei in)
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        if (data.length != IDLE_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, IDLE_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookOutflow
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

    /// @dev Reserve key derivation. MUST stay byte-identical to
    ///      `AaveV4ReserveRegistry.computeReserveKey` (pure keccak, documented in both places).
    function _computeReserveKey(address spoke, uint256 reserveId) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))));
    }

    /// @dev Strictly decodes the idle layout: exact 157-byte length, nonzero oracle id, nonzero
    ///      addresses, canonical boolean, and the header reserve key pinned to the body. Pure, so
    ///      `inspect()` shares it and fails closed on the same malformed inputs.
    /// @param data The hook data
    /// @return vars The decoded idle parameters
    function _decodeIdle(bytes memory data) internal pure returns (IdleVars memory vars) {
        if (data.length != IDLE_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();

        vars.reserveKey = data.extractYieldSource();
        vars.underlying = BytesLib.toAddress(data, IDLE_UNDERLYING_OFFSET);
        vars.spoke = BytesLib.toAddress(data, IDLE_SPOKE_OFFSET);
        vars.reserveId = BytesLib.toUint256(data, IDLE_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, IDLE_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeStrictBool(data, IDLE_USE_PREV_OFFSET);

        if (vars.reserveKey == address(0) || vars.underlying == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        if (vars.reserveKey != _computeReserveKey(vars.spoke, vars.reserveId)) revert RESERVE_KEY_MISMATCH();
    }

    /// @dev Binds the calldata underlying to the reserve through the Spoke's canonical
    ///      getReserve(reserveId).underlying. The underlying is the approve target, the wallet-delta
    ///      token and the fee `asset`, so a mismatch fails here with a specific error instead of a
    ///      late transferFrom / DELTA_MISMATCH revert. View — called from build and _preExecute only.
    function _requireUnderlyingMatchesReserve(IdleVars memory vars) internal view {
        if (IAaveV4Spoke(vars.spoke).getReserve(vars.reserveId).underlying != vars.underlying) {
            revert TOKEN_RESERVE_MISMATCH();
        }
    }

    /// @dev ONE MODE PER (ACCOUNT, RESERVE): the Spoke's collateral flag is per user and reserve, not
    ///      per deposit. If the account has the reserve enabled as collateral (a LOAN pledge, a position
    ///      manager, or a direct call), an "idle" supply would become seizable collateral, the redeem
    ///      could hit the Spoke's health-factor check, and `getUserSuppliedAssets` — the oracle's
    ///      balance — would mix NONACCOUNTING LOAN supply with ledger-tracked idle supply. Both idle
    ///      hooks therefore refuse a collateral-flagged reserve on build and preExecute (one staticcall).
    /// @param vars The decoded idle parameters
    /// @param account The executing smart account
    function _requireNotCollateral(IdleVars memory vars, address account) internal view {
        (bool isUsingAsCollateral,) = IAaveV4Spoke(vars.spoke).getUserReserveStatus(vars.reserveId, account);
        if (isUsingAsCollateral) revert RESERVE_IS_COLLATERAL();
    }

    /// @dev The account's supplied assets on the reserve — the SAME read
    ///      AaveV4SupplyYieldSourceOracle performs, so hook units equal oracle units by construction.
    function _suppliedAssets(IdleVars memory vars, address account) internal view returns (uint256) {
        return IAaveV4Spoke(vars.spoke).getUserSuppliedAssets(vars.reserveId, account);
    }

    /// @dev Resolves the amount to move: the previous hook's output (which must be denominated in
    ///      `expectedPrevToken`) when usePrevHookAmount is set, else the calldata word. Deterministic
    ///      within a transaction, so build, _preExecute and _postExecute agree.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded idle parameters
    /// @param expectedPrevToken Token the previous hook must have produced (lend: underlying; redeem: reserve key)
    /// @return The exact amount to move
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

    /// @dev Inspector payload: reserve key FIRST (the ledger / PPS key, same rule as the Morpho idle
    ///      hooks — leaves are hashed over these raw bytes), then spoke, underlying and reserve id.
    ///      92 bytes. Amount, usePrevHookAmount and the oracle id are intentionally excluded.
    function _inspectIdle(IdleVars memory vars) internal pure returns (bytes memory) {
        return abi.encodePacked(vars.reserveKey, vars.spoke, vars.underlying, vars.reserveId);
    }
}
