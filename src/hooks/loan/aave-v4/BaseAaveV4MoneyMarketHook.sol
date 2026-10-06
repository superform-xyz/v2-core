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
import { IAaveV4MarketRegistry } from "../../../interfaces/accounting/IAaveV4MarketRegistry.sol";

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
/// @dev Data layout (exact 157 bytes; standard 52-byte strategy header + hook-specific). SUP-21263 DELETED
///      the trailing `borrowReserveId` word SUP-21254 had appended and reinterpreted offset 92, so every
///      surviving offset is unchanged and the sizing surface again moved by one constant:
/// @notice         bytes32 yieldSourceOracleId = data.extractYieldSourceOracleId(); // Superform Aave V4 supply YS id
/// @notice         address yieldSource = data.extractYieldSource(); // a REGISTERED computeMarketKey(...)
/// @notice         address underlying = BytesLib.toAddress(data, 52);
/// @notice         address spoke = BytesLib.toAddress(data, 72);
/// @notice         uint256 targetReserveId = BytesLib.toUint256(data, 92); // THE reserve this op moves
/// @notice         uint256 amount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 156); // canonical 0x00 / 0x01
///
///      HEADER IDENTITY (SUP-21254, reshaped by SUP-21263): offset 32 carries the MARKET KEY —
///      `keccak256(abi.encode(spoke, supplyReserveId, borrowReserveId, MARKET_KEY_DOMAIN))` truncated to an
///      address, byte-identical to `AaveV4ReserveRegistryV2.computeMarketKey`, the same key the six V2 LOAN
///      hooks pin. Unlike theirs, THIS header is also a SuperLedger key and an oracle argument: the pair is
///      INFLOW / OUTFLOW, so `SuperExecutorBase._updateAccounting` reads it.
///
///      WHY THE PIN IS NO LONGER A PURE DERIVATION. Until SUP-21263 the body carried BOTH leg ids, so the
///      header could be recomputed from calldata alone and the moved reserve was, by construction, the
///      market's supply leg. SUP-21263 makes `targetReserveId` EITHER leg of the market — idle USDC on a
///      MAG7 pair must settle under the same market key as idle NVDAc, and USDC is that market's LOAN leg —
///      and a market key is a one-way commitment, so membership is now a REGISTRY READ:
///      `getMarketInfo(headerKey)` returns the two legs and `targetReserveId` must be one of them. Two
///      consequences, both deliberate:
///      (1) the fail-closed allowlist moved EARLIER, from accounting-time to BUILD-time — an idle op under
///          an unregistered market now reverts `MARKET_NOT_REGISTERED` in the hook instead of deep inside
///          SuperLedger, which is a strict improvement;
///      (2) `inspect` stays `pure` and therefore NO LONGER authenticates the header. It is a transformation
///          API, like the three sizing views: a template that inspects must also pass build() / preExecute(),
///          which both authenticate. Keeping it pure is what lets an indexer re-derive a historical leaf
///          after a market has been deregistered.
///
///      THE ORACLE RESOLVES THE KEY TO THE COLLATERAL LEG, WHICH MAY NOT BE THE MOVED RESERVE.
///      `AaveV4ReserveOracle._resolveLeg` maps a market key to `computeReserveKey(spoke, supplyReserveId)`.
///      When `targetReserveId` is the market's BORROW leg, the scalar `getBalanceOfOwner(marketKey, owner)`
///      therefore reports the COLLATERAL reserve's supplied assets, not the asset this op moved. That
///      asymmetry is accepted, not a defect to work around here: SUP-21263 forbids changing oracle
///      resolution. Portfolio valuation for this family MUST come from
///      `AaveV4ReserveOracle.getOwnerSnapshot`, which discovers every leg and de-duplicates across the
///      requested set (and, since SUP-21259, still reports idle collateral no requested market covers).
///      Never value an idle position from `getBalanceOfOwner(marketKey)` or from the ledger accumulators.
///
///      ONE LEDGER KEY, N PHYSICAL POSITIONS — AN OPS INVARIANT, NOT A PROPERTY. Two distinct reasons, both
///      inherent to a leg-ambiguous key and neither fixable from calldata:
///      (a) both legs of one market may be idled at once (the ticket's own motivation requires it), so
///          `usersAccumulatorShares[user][marketKey]` can sum two reserves' positions in incommensurable
///          units;
///      (b) a reserve that is the BORROW leg of N registered markets can settle under any of those N keys —
///          N = 7 on the Base MAG7 spoke, where every equity market borrows the one USDC reserve. Lending
///          under market A and redeeming under market B succeeds (`BaseLedger` CAPS `usedShares` at B's
///          accumulator rather than reverting) and strands A's accumulator.
///      Neither loses funds or blocks an exit while `feePercent == 0` for this oracle id, because the
///      identity PPS makes cost basis equal the amount and every fee is multiplied by zero. The required
///      controls are therefore: keep `feePercent = 0`, and designate exactly ONE registered market key per
///      `(spoke, reserveId)` as that reserve's idle settlement key — enforced in the OMS allowlist and
///      surfaced by `ConfigureAaveV4ReserveRegistry.runCheckAll`. See SECURITY.md §16.
///
///      The Spoke stays on the hook as the only call target and approve spender, and the sizing views
///      (`decodeAmounts`, `replaceCalldataAmounts`, `decodeUsePrevHookAmount`) check the exact length and
///      the canonical bool only.
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
    /// @notice THE reserve the Spoke call moves; must be one of the header market's two legs (SUP-21263)
    uint256 internal constant IDLE_TARGET_RESERVE_ID_OFFSET = 92;
    uint256 internal constant IDLE_AMOUNT_OFFSET = 124;
    uint256 internal constant IDLE_USE_PREV_OFFSET = 156;

    /// @notice Domain separator for the `usePrevHookAmount` chaining token — see `_idleChainToken`
    bytes32 internal constant IDLE_CHAIN_TOKEN_DOMAIN = keccak256("AaveV4Idle.CHAIN_TOKEN");

    /// @notice Exact hook-data length for both idle hooks
    /// @dev 157 is also the PRE-SUP-21254 length, so length alone no longer separates this revision from the
    ///      original reserve-keyed one. Fail-closed still holds in all four directions, via the HEADER:
    ///      a stale 157-byte reserve-keyed body reverts `MARKET_NOT_REGISTERED` here (the registry's
    ///      `KEY_NAMESPACE_COLLISION` makes a reserve key registered as a market unrepresentable, so this
    ///      can never fail open); a new body sent to a pre-SUP-21254 hook reverts `RESERVE_KEY_MISMATCH`;
    ///      a new body sent to a SUP-21254 hook, and a stale 189-byte body sent here, both revert
    ///      `INVALID_DATA_LENGTH`.
    uint256 internal constant IDLE_DATA_LENGTH = 157;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct IdleVars {
        address marketKey; // header offset 32 — the registered market key; the ledger / PPS key
        address underlying;
        address spoke;
        uint256 targetReserveId; // the reserve the Spoke call moves; EITHER leg of the market (SUP-21263)
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

    /// @notice Thrown when `targetReserveId` is neither leg of the registered header market
    error RESERVE_NOT_IN_MARKET();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice The registry these hooks resolve market keys through — immutable, set once at deployment
    /// @dev The ONLY constructor dependency in the Aave V4 hook family. The Spoke still comes from calldata;
    ///      this is needed solely because a market key cannot be inverted to recover its legs (SUP-21263).
    IAaveV4MarketRegistry public immutable REGISTRY;

    /// @param hookType_ INFLOW (lend) or OUTFLOW (redeem)
    /// @param registry_ AaveV4ReserveRegistryV2; must be non-zero
    constructor(ISuperHook.HookType hookType_, address registry_) BaseLoanHookV2(HookSubTypes.LOAN) {
        if (registry_ == address(0)) revert ADDRESS_NOT_VALID();
        REGISTRY = IAaveV4MarketRegistry(registry_);
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

    /// @dev Strictly decodes the idle layout: exact 157-byte length, nonzero oracle id, nonzero addresses
    ///      and a canonical boolean. STRUCTURE ONLY — identity is `_requireTargetIsMarketLeg`, which needs a
    ///      registry read. This stays `pure` so `inspect()` can share it; the two authenticating entry
    ///      points (`build`, `preExecute`) call both.
    ///      ONE RESERVE WORD, AND IT IS THE ONE THAT MOVES: offset 92 feeds the Spoke's `supply` /
    ///      `withdraw` and nothing else. Under SUP-21254 that same word also fed `computeMarketKey`'s supply
    ///      slot, which made "the moved reserve is the market's supply leg" true by construction; SUP-21263
    ///      drops that coupling on purpose, so the moved reserve is now whichever leg the body names and the
    ///      guarantee is the weaker "it is ONE OF the market's two legs", checked against the registry.
    ///      `IDENTICAL_RESERVES` is gone with the second word: a REGISTERED market can never have equal
    ///      legs (`AaveV4ReserveRegistryV2.registerMarket` rejects that itself), and these hooks now accept
    ///      registered markets only, so the invariant is inherited instead of re-derived.
    /// @param data The hook data
    /// @return vars The decoded idle parameters
    function _decodeIdle(bytes memory data) internal pure returns (IdleVars memory vars) {
        if (data.length != IDLE_DATA_LENGTH) revert INVALID_DATA_LENGTH();
        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();

        vars.marketKey = data.extractYieldSource();
        vars.underlying = BytesLib.toAddress(data, IDLE_UNDERLYING_OFFSET);
        vars.spoke = BytesLib.toAddress(data, IDLE_SPOKE_OFFSET);
        vars.targetReserveId = BytesLib.toUint256(data, IDLE_TARGET_RESERVE_ID_OFFSET);
        vars.amount = BytesLib.toUint256(data, IDLE_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeStrictBool(data, IDLE_USE_PREV_OFFSET);

        if (vars.marketKey == address(0) || vars.underlying == address(0) || vars.spoke == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
    }

    /// @dev THE IDENTITY CHECK (SUP-21263), and the reason these hooks hold a registry reference. Resolves
    ///      the header market to its two legs and requires `targetReserveId` to be one of them, so the
    ///      reserve the Spoke call moves is always part of the market the ledger settles under.
    ///      ORDER OF REVERTS, deliberate: `MARKET_NOT_REGISTERED` (the header is not a market at all) ->
    ///      `MARKET_KEY_MISMATCH` (the body's spoke is not the market's spoke) -> `RESERVE_NOT_IN_MARKET`
    ///      (the target is neither leg).
    ///      WHY RE-DERIVE THE KEY instead of comparing spokes directly: it keeps `AaveV4ReserveKey` the
    ///      single home of the derivation and keeps `MARKET_KEY_MISMATCH` alive for the spoke-mismatch case,
    ///      at the cost of one 4-word keccak. It is also defence in depth — a registry whose stored legs
    ///      disagreed with the key they are filed under would fail here rather than move the wrong reserve.
    ///      NOT CHECKED HERE: that `targetReserveId` is idle-SETTLEMENT-canonical for its reserve. A reserve
    ///      that is the borrow leg of N markets can settle under any of them; see the contract docblock.
    ///      Called from `_buildHookExecutions`, `_preExecute` AND `_postExecute`. The third call was added
    ///      in review and is deliberate defence in depth — one WARM `getMarketInfo` (~1.1k gas): it removes
    ///      the hooks' dependence on `SuperExecutorBase.validateHookCompliance` for the guarantee that a
    ///      body reaching `_postExecute` was validated earlier in the same transaction. It matters most on
    ///      the redeem side, where `usedShares -= suppliedAfter` reads `targetReserveId`, so a swapped
    ///      target could under-report consumption without failing any delta assertion.
    ///      NOT called from `_decodeIdle`, which must stay `pure` so `inspect` can.
    /// @param vars The decoded idle parameters
    function _requireTargetIsMarketLeg(IdleVars memory vars) internal view {
        (, uint256 supplyReserveId, uint256 borrowReserveId,,) = REGISTRY.getMarketInfo(vars.marketKey);
        // Re-deriving from the REGISTRY's legs and the BODY's spoke pins the spoke: the registry filed the
        // key under its own spoke, so this passes iff the body names that same spoke. No separate compare.
        AaveV4ReserveKey.requireHeaderIsMarketKey(vars.marketKey, vars.spoke, supplyReserveId, borrowReserveId);
        if (vars.targetReserveId != supplyReserveId && vars.targetReserveId != borrowReserveId) {
            revert RESERVE_NOT_IN_MARKET();
        }
    }

    /// @dev Binds the calldata underlying to the reserve through the Spoke's canonical
    ///      getReserve(reserveId).underlying. The underlying is the approve target, the wallet-delta
    ///      token and the fee `asset`, so a mismatch fails here with a specific error instead of a
    ///      late transferFrom / DELTA_MISMATCH revert. View — called from build and _preExecute only.
    function _requireUnderlyingMatchesReserve(IdleVars memory vars) internal view {
        if (IAaveV4Spoke(vars.spoke).getReserve(vars.targetReserveId).underlying != vars.underlying) {
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
        (bool isUsingAsCollateral,) = IAaveV4Spoke(vars.spoke).getUserReserveStatus(vars.targetReserveId, account);
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
            IAaveV4Spoke(vars.spoke).getUserReserveStatus(vars.targetReserveId, account);
        if (isUsingAsCollateral) revert RESERVE_IS_COLLATERAL();
        if (isBorrowing) revert RESERVE_IS_BORROWED();
    }

    /// @dev The account's supplied assets on the reserve — the SAME read
    ///      AaveV4ReserveOracle performs, so hook units equal oracle units by construction.
    function _suppliedAssets(IdleVars memory vars, address account) internal view returns (uint256) {
        return IAaveV4Spoke(vars.spoke).getUserSuppliedAssets(vars.targetReserveId, account);
    }

    /// @dev Resolves the amount to move: the previous hook's output (which must be denominated in
    ///      `expectedPrevToken`) when usePrevHookAmount is set, else the calldata word. Deterministic
    ///      within a transaction, so build, _preExecute and _postExecute agree.
    /// @param prevHook The previous hook in the chain
    /// @param account The executing smart account
    /// @param vars The decoded idle parameters
    /// @param expectedPrevToken Token the previous hook must have produced — lend: the underlying; redeem:
    ///        `_idleChainToken(vars)`, this (market, leg) pair's chaining token. NOT the header market key,
    ///        which is leg-ambiguous since SUP-21263, and NOT a bare reserve key, which is market-blind.
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

    /// @dev THE CHAINING TOKEN for `usePrevHookAmount`: unique per (MARKET, LEG), domain-separated.
    ///      WHY NOT THE RESERVE KEY (which this replaced, and which was a real defect): a reserve key is
    ///      `keccak(spoke, reserveId)` — it carries NO market component. On the Base MAG7 spoke reserve 7 is
    ///      the borrow leg of all seven equity markets, so `lend(market A, target 7)` and
    ///      `redeem(market B, target 7)` published and expected the SAME token, and a cross-market chain
    ///      passed `expectedPrevToken` inside ONE signed bundle. The INFLOW credited A's accumulator while
    ///      the OUTFLOW consumed B's — empty, so `BaseLedger.calculateCostBasisView` CAPS `usedShares` to
    ///      zero rather than reverting; `_processOutflow` then prices `mulDiv(0, pps, 10 ** decimals) = 0`,
    ///      so the performance fee is zero REGARDLESS of `feePercent` and A's basis is stranded forever.
    ///      That made the R6 ops hazard atomically reachable in one intent instead of requiring two.
    ///      WHY NOT THE MARKET KEY EITHER: it is leg-ambiguous since SUP-21263, so it would let
    ///      `lend(collateral leg)` feed `redeem(loan leg)` — an 18-decimal figure driving a 6-decimal
    ///      withdraw. Only the PAIR is safe, so the pair is what the token commits.
    ///      Domain-separated so it can never collide with a market key, a reserve key or a debt key.
    /// @param vars The decoded idle parameters
    /// @return The chaining pseudo-token for this (market, leg)
    function _idleChainToken(IdleVars memory vars) internal pure returns (address) {
        return address(
            uint160(uint256(keccak256(abi.encode(vars.marketKey, vars.targetReserveId, IDLE_CHAIN_TOKEN_DOMAIN))))
        );
    }

    /// @dev Inspector payload: MARKET key FIRST (the ledger / PPS key, same rule as the Morpho idle hooks —
    ///      leaves are hashed over these raw bytes), then spoke, underlying and the TARGET reserve id.
    ///      Still 92 bytes in the same field order: SUP-21263 changed only what the trailing word means.
    ///      WHY `targetReserveId` MUST BE HERE (it is not optional). Under SUP-21254 the market key was a
    ///      commitment to the single moved reserve, so the tail word was redundant-but-harmless. Now BOTH
    ///      legs are valid under one key, so two bodies moving DIFFERENT ASSETS share a header — without
    ///      this word they would produce identical payloads and therefore identical Merkle leaves, and one
    ///      signed leaf would authorise moving either asset. With it, all four identity fields of the body
    ///      (marketKey, spoke, underlying, targetReserveId) appear verbatim and the payload is injective
    ///      over them. `underlying` is bound to the target by `_requireUnderlyingMatchesReserve`, so it
    ///      discriminates the legs too — belt and braces, deliberately.
    ///      Amount, usePrevHookAmount and the oracle id stay excluded: amount and the bool are the resize
    ///      window `[124,156)`, which is disjoint from every identity field, so a resize can never turn a
    ///      mis-keyed payload into a well-keyed one.
    ///      THIS IS `pure`, SO IT DOES NOT AUTHENTICATE THE HEADER — unlike every prior revision. Market
    ///      membership is a registry read and lives in `build` / `preExecute`; `inspect` is a transformation
    ///      API, like the three sizing views, and a template that inspects must also pass those. Keeping it
    ///      pure is what lets an indexer re-derive a historical leaf after a market is deregistered.
    function _inspectIdle(IdleVars memory vars) internal pure returns (bytes memory) {
        return abi.encodePacked(vars.marketKey, vars.spoke, vars.underlying, vars.targetReserveId);
    }
}
