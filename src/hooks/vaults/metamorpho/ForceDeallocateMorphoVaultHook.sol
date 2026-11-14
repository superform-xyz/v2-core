// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IMorphoVaultV2 } from "../../../vendor/morpho/IMorphoVaultV2.sol";
import { IMorphoMarketV1Adapter } from "../../../vendor/morpho/IMorphoMarketV1Adapter.sol";
import { IMorphoStaticTyping, MarketParams, Id } from "../../../vendor/morpho/IMorpho.sol";
import { MathLib } from "../../../vendor/morpho/MathLib.sol";

/// @title ForceDeallocateMorphoVaultHook
/// @author Superform Labs
/// @notice NONACCOUNTING hook that fills a Morpho Vault V2's idle balance by force-deallocating across the
///         markets its own adapters list, cheapest-first, stopping the moment the requested amount is covered
/// @dev THE VAULT-LEVEL SIBLING OF `ForceDeallocateMorphoHook`, NOT A REPLACEMENT. That hook takes one
///      adapter and one ABI-encoded `MarketParams` and is the right tool when the caller knows the market.
///      A curator vault lists many Morpho Blue markets and the list moves under the curator timelock, so
///      packing each market into its own hook call makes the strategy do the vault's job and the packed
///      params go stale. This hook reads the list on chain instead. Both are deployed and registered.
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         uint256 assets = BytesLib.toUint256(data, 52);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
/// @notice         uint256 maxPenaltyWad = BytesLib.toUint256(data, 85);
/// @dev THIS NATSPEC IS THE SOURCE OF THE REGISTRY BUILD PATH, not just documentation. The OMS hook
///      registry parses the five lines above to derive:
///        None-bytes32-32-yieldSourceOracleId, None-address-20-yieldSource, None-uint256-32-assets,
///        None-bool-1-usePrevHookAmount, None-uint256-32-maxPenaltyWad
///      The field NAMES are load-bearing. `yieldSourceOracleId` must not be renamed to anything matching
///      the registry's reserved `^placeholder\d*$` pattern, which is encoded `Zeroes-...` and would
///      zero-fill the oracle id before it ever reached the chain; and OMS asset identity reads the
///      parameter named literally `yieldSource`. Registry tags are set at registration, not here:
///      `yieldSourceOracleId` = get_oracle_id_from_vault, `yieldSource` = get_yield_source_from_vault,
///      `assets` = get_input_amount.
/// @dev `assets` IS UNDERLYING, NOT SHARES, and it is what lands in idle. The penalty is charged ON TOP, as
///      a share burn against the executing account, so idle rises by the full `assets` rather than by
///      `assets * (1 - penalty)`. The next hop is an ordinary ERC-4626 withdraw of that same number with
///      `usePrevHookAmount` FALSE.
/// @dev SCOPE LIMIT, AND ITS OPERATOR-FACING SYMPTOM. Only Morpho Blue market adapters are walked, one
///      level deep, never recursing into a `MorphoVaultV1Adapter` or any other adapter shape. A Vault V2
///      whose liquidity sits entirely behind non-market adapters therefore reverts `SHORTFALL(0, assets)`.
///      That looks like an outage and is not one: it is this hook declining to unwind an adapter type it
///      does not model. Unwinding those is explicitly out of scope.
/// @dev LEAF-COMMITTED PENALTY CAP (SUP-21849). This hook produces NO output (`outAmount` is zero by
///      construction), so a caller's `expectedAssetsOrSharesOut` floor passes trivially and never sees the
///      penalty shares the pulls burn. `maxPenaltyWad` at offset 85 is therefore the ONE on-chain bound on that
///      burn: adapters charging more are SKIPPED (not fatal; the fill completes from cheaper ones), and a short
///      fill caused by the cap says so (`PENALTY_ABOVE_CAP`). Chosen off chain per intent, committed by the
///      signature over the hook data, must be non-zero (a zero-filled word fails closed) and at most Morpho's
///      own 2%. Deliberately NO deploy-time cap: the fixed 25 bps immutable this replaces broke honest
///      SuperStocks exits the day cbAssets moved its adapter to 30 bps.
/// @dev TRUST ASSUMPTION: Morpho Vault V2's internal reentrancy guards, its adapter registry and its own 2%
///      penalty ceiling are trusted. The adapter SET is curator-controlled, which is why every adapter is
///      identity-checked (`parentVault()`) and gas-stipended before it is read. `onBehalf` is always the
///      executing smart account.
/// @dev NOT A WITHDRAW, despite moving underlying. `forceDeallocate` moves underlying from an adapter into
///      the vault's idle balance and burns penalty shares from the executing account; it does not redeem
///      shares and does not pay the account. It stays NONACCOUNTING and the classification stays
///      config/instant/sized. Relabelling it would make OMS price this hop as a vault conversion.
contract ForceDeallocateMorphoVaultHook is
    BaseHook,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    using BytesLib for bytes;
    using HookDataDecoder for bytes;
    using MathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The fill fell short AND at least one adapter was excluded solely for being over the leaf cap
    /// @dev A SHORTFALL DIAGNOSTIC rather than a hard gate: an adapter over the cap is skipped, not fatal. This
    ///      fires only when the cap is the actual cause, turning an opaque "not enough liquidity" into the one
    ///      thing the operator can act on.
    error PENALTY_ABOVE_CAP(uint256 penaltyWad, uint256 capWad);
    /// @notice The leaf's `maxPenaltyWad` is zero or above Morpho's own 2% ceiling
    error PENALTY_CAP_OUT_OF_RANGE(uint256 leafCapWad, uint256 ceilingWad);
    /// @notice The payload is not exactly the declared 117-byte layout
    error INVALID_DATA_LENGTH(uint256 given, uint256 expected);
    /// @notice The vault lists more markets than one transaction will walk
    error TOO_MANY_MARKETS(uint256 count, uint256 maxCount);
    /// @notice The vault registers more adapters than one transaction will probe
    error TOO_MANY_ADAPTERS(uint256 count, uint256 maxCount);
    /// @notice Every eligible market together cannot cover the request
    error SHORTFALL(uint256 available, uint256 requested);
    /// @notice The account cannot cover the penalty share burn the planned pulls would charge
    error INSUFFICIENT_SHARES(uint256 held, uint256 required);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Morpho Vault V2's own hard ceiling on `forceDeallocatePenalty`, in WAD (2%).
    /// @dev A compile-time constant in Morpho's non-upgradeable bytecode, so it cannot be raised. A leaf cap
    ///      above it could never bind and is rejected as an encoding error.
    uint256 public constant MORPHO_MAX_PENALTY_WAD = 0.02e18;

    /// @notice Hard bound on how many listed markets this hook will walk in one call.
    /// @dev A DOS BOUND, NOT A STYLE CHOICE. `build` runs ON CHAIN inside the UserOp
    ///      (`SuperExecutorBase._processHook` -> `validateHookCompliance` -> `ISuperHook.build`), so the
    ///      whole discovery pass is paid for by the executing account. Without this, a curator could grow
    ///      the adapter's market list until every exit through this hook ran out of gas — a liveness
    ///      failure on the one path that exists to escape an illiquid vault. Gauntlet WETH Prime listed 3
    ///      markets on 2026-11-10; 32 is the ceiling, not a target.
    uint256 public constant MAX_MARKETS = 32;

    /// @notice Hard bound on how many registered adapters this hook will probe in one call.
    /// @dev `MAX_MARKETS` alone does NOT bound the adapter walk: adapters rejected on shape contribute zero
    ///      markets, so an arbitrarily long list of junk adapters is walked in full before the market
    ///      ceiling is ever evaluated. Each rejected adapter still costs a cold `EXTCODESIZE`, an
    ///      `adapters(i)` read and at least one stipended probe, so without this bound the adapter list is
    ///      itself a gas-exhaustion surface against an on-chain `build`.
    uint256 public constant MAX_ADAPTERS = 32;

    /// @notice The single sized leg. `replaceCalldataAmounts` writes bytes 52..83 and nothing else.
    uint256 private constant AMOUNT_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;
    /// @notice The leaf-committed penalty cap, WAD
    uint256 private constant MAX_PENALTY_POSITION = 85;
    /// @notice Exact, not minimum: nothing may follow the cap word.
    uint256 private constant DATA_LENGTH = 117;

    /// @notice Gas stipend for each probe of a curator-registered adapter.
    /// @dev Neither `staticcall` nor `try/catch` catches out-of-gas, and 63/64 of the remaining gas is
    ///      forwarded by default. A hostile adapter in the list could therefore burn the UserOp's gas from
    ///      inside a read that this hook was going to discard anyway. The Morpho Blue reads are to a known
    ///      singleton and are left unstipended.
    /// @dev MEASURED, NOT GUESSED, AND THE SUM IS WHAT MATTERS. The stipend bounds each probe, not the
    ///      total, and the worst case is `MAX_ADAPTERS * 4 + MAX_MARKETS * 2 == 192` probes. At a 100_000
    ///      stipend that is 19.2M gas of probing alone, ABOVE the 16,777,216 (2^24) per-transaction gas cap
    ///      EIP-7825 introduced on Ethereum in Fusaka — so an all-hostile adapter set could put this exit
    ///      beyond any transaction, on the one path that exists to escape an illiquid vault. Katana carries
    ///      the same cap.
    /// @dev The figure below is ~3x the heaviest HONEST probe, measured on Ethereum at block 26,384,300
    ///      against the live `MorphoMarketV1AdapterV2` of Gauntlet WETH Prime: `expectedSupplyAssets` cost
    ///      22,621 gas cold (it previews accrual through `IIrm.borrowRateView`, and pays cold-access for
    ///      both Morpho and the IRM); every other probe cost under 1,400. Headroom matters in BOTH
    ///      directions — too low and an honest-but-heavier adapter is silently skipped, which surfaces to
    ///      the operator as `SHORTFALL` and looks like illiquidity rather than a tuning error. Both bounds
    ///      are pinned by tests: the worst-case total against 2^24, and this constant against a live
    ///      re-measurement, so a heavier adapter shows up as a failing test rather than a skipped market.
    uint256 private constant PROBE_GAS = 70_000;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The one Morpho Blue singleton this hook will read market state from.
    /// @dev AN IMMUTABLE GATE, NOT A CONVENIENCE. `adapter.morpho()` is answered by a CURATOR-REGISTERED
    ///      contract, and the returned address was previously used as the target of TYPED, UN-STIPENDED
    ///      calls to `idToMarketParams` and `market` — so a hostile or buggy adapter chose where this hook
    ///      read its capacity numbers from. That let it revert `build` outright (a typed call to a lying
    ///      contract bubbles up rather than being skipped), burn the UserOp's gas from a read whose result
    ///      was going to be discarded, or claim unlimited capacity at a zero penalty so that every pull
    ///      routed to it and no honest market was touched. Requiring equality with this immutable removes
    ///      the attacker-chosen call target entirely, and an adapter pointing elsewhere is SKIPPED like any
    ///      other ineligible one.
    /// @dev IT ALSO MAKES THE PER-MARKET LEDGER KEY SOUND. A Morpho id is `keccak256(abi.encode(params))`
    ///      with no Morpho address in the preimage, so identical params on two Morpho deployments collide
    ///      BY CONSTRUCTION. Keying `_fill`'s committed-liquidity ledger on the id alone is only correct
    ///      because every candidate now provably comes from the same singleton.
    address public immutable MORPHO;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice What the adapter-level probe concluded about one entry in `vault.adapters`
    struct AdapterInfo {
        bool eligible;
        address adapter;
        address morpho;
        /// @dev `address(0)` means "this adapter pins no IRM" (the V1 shape), not "pins the zero IRM".
        address adaptiveCurveIrm;
        uint256 marketCount;
        uint256 penaltyWad;
    }

    /// @notice One (adapter, market) pair that survived every filter
    struct Candidate {
        address adapter;
        /// @dev Kept so the fill loop can net out liquidity already committed to the SAME market id by a
        ///      different adapter. See `_fill`.
        bytes32 marketId;
        uint256 penaltyWad;
        uint256 position;
        uint256 liquidity;
        /// @dev Carried rather than re-read, so the bytes handed to `forceDeallocate` cannot differ from
        ///      the params this pass filtered on.
        MarketParams params;
    }

    /// @notice One planned `forceDeallocate`
    struct Pull {
        address adapter;
        uint256 amount;
        MarketParams params;
    }

    /// @notice The outcome of the greedy fill
    struct Plan {
        Pull[] pulls;
        uint256 totalPenaltyAssets;
        /// @dev Count of pulls charging a NON-ZERO penalty. Drives the `n - 1` rounding slack in the
        ///      solvency bound; a zero-penalty leg burns no shares and contributes no rounding.
        uint256 penalisedCount;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ The Morpho Blue singleton for this chain. Adapters pointing anywhere else are
    ///        skipped. Part of the CREATE2 address, so it cannot be repointed after deployment.
    /// @dev NO DEPLOY-TIME CAP (SUP-21849). The bound on the penalty is the leaf-committed `maxPenaltyWad`
    ///      in the hook data (see the contract NatSpec), not a constructor immutable: a fixed number broke
    ///      honest exits the day a curator raised a rate. Morpho's own 2% ceiling stands above it.
    constructor(address morpho_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        MORPHO = morpho_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Force Deallocate Morpho Vault";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Fills a Morpho Vault V2's idle balance across its listed markets";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    /// @dev Every pass sits inside this one view because `BaseHook.build` offers no non-view phase: resolve
    ///      the request, count the listed markets and bound them, collect the eligible ones with their
    ///      capacities, order them cheapest-first, fill greedily, then prove the account can pay the
    ///      penalty before a single call is emitted.
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        (address vault, uint256 assets, uint256 leafCap) = _resolveRequest(prevHook, account, data);

        AdapterInfo[] memory infos = _probeAdapters(vault, leafCap);
        Candidate[] memory candidates = _collectCandidates(vault, infos);
        Plan memory plan = _fill(candidates, _sortOrder(candidates), assets, infos, leafCap);

        _requireSolvent(vault, account, assets, plan);

        return _emit(vault, account, plan.pulls);
    }

    /// @notice Strict layout check, amount resolution and the leaf cap, shared by `build` and `_preExecute`
    /// @dev The length check is `!=`, not `<`. A longer payload in this layout has nowhere to go, so
    ///      accepting it would silently ignore caller bytes.
    function _resolveRequest(
        address prevHook,
        address account,
        bytes calldata data
    )
        private
        view
        returns (address vault, uint256 assets, uint256 leafCap)
    {
        if (data.length != DATA_LENGTH) revert INVALID_DATA_LENGTH(data.length, DATA_LENGTH);

        vault = data.extractYieldSource();
        if (vault == address(0)) revert ADDRESS_NOT_VALID();

        assets = data.toUint256(AMOUNT_POSITION);
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            if (prevHook == address(0)) revert ADDRESS_NOT_VALID();
            assets = ISuperHookResult(prevHook).getOutAmount(account);
        }
        if (assets == 0) revert AMOUNT_NOT_VALID();

        leafCap = data.toUint256(MAX_PENALTY_POSITION);
        if (leafCap == 0 || leafCap > MORPHO_MAX_PENALTY_WAD) {
            revert PENALTY_CAP_OUT_OF_RANGE(leafCap, MORPHO_MAX_PENALTY_WAD);
        }
    }

    /// @notice Pass A: probe every registered adapter and bound the total market count
    /// @dev The count is summed over adapters that SURVIVE the adapter-level filter only. An adapter
    ///      rejected on shape or penalty contributes zero, because its `marketIds` are never read. Markets
    ///      that survive this pass but are dropped later (wrong loan token, IRM mismatch, no capacity) DO
    ///      count — the bound is on walking work, not on usable markets.
    function _probeAdapters(address vault, uint256 leafCap) private view returns (AdapterInfo[] memory infos) {
        uint256 len = IMorphoVaultV2(vault).adaptersLength();
        if (len > MAX_ADAPTERS) revert TOO_MANY_ADAPTERS(len, MAX_ADAPTERS);
        infos = new AdapterInfo[](len);

        uint256 total;
        for (uint256 i; i < len; ++i) {
            infos[i] = _probeAdapter(vault, IMorphoVaultV2(vault).adapters(i), leafCap);
            if (!infos[i].eligible) continue;
            total += infos[i].marketCount;
            // Stop walking the moment the ceiling is breached; the revert is the same either way, and
            // continuing would pay for probes whose results are about to be discarded.
            if (total > MAX_MARKETS) revert TOO_MANY_MARKETS(total, MAX_MARKETS);
        }
    }

    /// @notice The adapter-level filter: is this a Morpho Blue market adapter of THIS vault, under the leaf cap?
    /// @dev Every read is a guarded `staticcall` rather than a typed call, because the adapter list is
    ///      heterogeneous and curator-controlled: a `MorphoVaultV1Adapter` implements none of these, and a
    ///      `STATICCALL` to a codeless address SUCCEEDS with empty returndata, so `try/catch` would take the
    ///      success branch and then decode nothing. An ineligible adapter is SKIPPED, never fatal.
    function _probeAdapter(
        address vault,
        address adapter,
        uint256 leafCap
    )
        private
        view
        returns (AdapterInfo memory info)
    {
        info.adapter = adapter;

        (bool ok, bytes32 word) = _probe(adapter, abi.encodeCall(IMorphoMarketV1Adapter.parentVault, ()));
        if (!ok || address(uint160(uint256(word))) != vault) return info;

        // Equality with the immutable, NOT merely "is a contract". See `MORPHO`.
        (ok, word) = _probe(adapter, abi.encodeCall(IMorphoMarketV1Adapter.morpho, ()));
        if (!ok || address(uint160(uint256(word))) != MORPHO) return info;
        info.morpho = MORPHO;

        (ok, word) = _probe(adapter, abi.encodeCall(IMorphoMarketV1Adapter.marketIdsLength, ()));
        if (!ok) return info;
        info.marketCount = uint256(word);

        // The leaf cap is the gate; the rate also orders the fill cheapest-first.
        info.penaltyWad = IMorphoVaultV2(vault).forceDeallocatePenalty(adapter);
        if (info.penaltyWad > leafCap) return info;

        // Absent on the V1 adapter shape; a failed read is "pins no IRM", which is the correct reading.
        (ok, word) = _probe(adapter, abi.encodeCall(IMorphoMarketV1Adapter.adaptiveCurveIrm, ()));
        if (ok) info.adaptiveCurveIrm = address(uint160(uint256(word)));

        info.eligible = true;
    }

    /// @notice Pass B: expand each eligible adapter's market list into scored candidates
    function _collectCandidates(
        address vault,
        AdapterInfo[] memory infos
    )
        private
        view
        returns (Candidate[] memory candidates)
    {
        address asset = IMorphoVaultV2(vault).asset();
        Candidate[] memory scratch = new Candidate[](MAX_MARKETS);
        uint256 found;

        // Adapter-major, market-minor. The fill sort is STABLE, so this order supplies the
        // "adapter index then market index ascending" tie-break for free.
        for (uint256 i; i < infos.length; ++i) {
            if (!infos[i].eligible) continue;
            for (uint256 j; j < infos[i].marketCount; ++j) {
                (bool ok, Candidate memory c) = _marketCapacity(infos[i], j, asset);
                if (ok && !_alreadyCollected(scratch, found, c.adapter, c.marketId)) scratch[found++] = c;
            }
        }

        candidates = new Candidate[](found);
        for (uint256 k; k < found; ++k) {
            candidates[k] = scratch[k];
        }
    }

    /// @notice Has this exact (adapter, market) pair already been collected?
    /// @dev DEDUPLICATION IS A CORRECTNESS REQUIREMENT, NOT TIDINESS. `expectedSupplyAssets(id)` returns
    ///      ONE number for one adapter-market pair, so two candidates naming that pair describe the SAME
    ///      capacity rather than two. Nothing in the adapter forbids the same id appearing twice in
    ///      `marketIds`, and `forceDeallocate` takes `MarketParams` rather than a list index, so two pulls
    ///      on one pair are indistinguishable from a single larger pull. Left un-deduplicated, the fill
    ///      would plan `2 x position` against a market with ample liquidity — the per-market-id liquidity
    ///      ledger in `_fill` does NOT catch this, because liquidity is not the binding constraint there —
    ///      and the second `forceDeallocate` would revert inside the adapter, killing the whole exit.
    /// @dev Dropping the duplicate here rather than netting it in `_fill` keeps the position bound a
    ///      property of the candidate set (one entry per real position) and leaves the fill loop with a
    ///      single ledger to maintain.
    function _alreadyCollected(
        Candidate[] memory collected,
        uint256 count,
        address adapter,
        bytes32 marketId
    )
        private
        pure
        returns (bool)
    {
        for (uint256 i; i < count; ++i) {
            if (collected[i].adapter == adapter && collected[i].marketId == marketId) return true;
        }
        return false;
    }

    /// @notice Per-market filter and capacity, for market `index` of one eligible adapter
    /// @dev Capacity is `min(position, liquidity)` and BOTH bounds are real. `expectedSupplyAssets` is the
    ///      adapter's own accrued position, which can exceed what the market can presently pay out; market
    ///      liquidity can exceed what this adapter actually holds. Exceeding either reverts inside the
    ///      adapter or inside Morpho and takes the whole transaction with it, so this view must never emit
    ///      a pull above the smaller one.
    function _marketCapacity(
        AdapterInfo memory info,
        uint256 index,
        address asset
    )
        private
        view
        returns (bool ok, Candidate memory c)
    {
        bytes32 word;
        (ok, word) = _probe(info.adapter, abi.encodeCall(IMorphoMarketV1Adapter.marketIds, (index)));
        if (!ok) return (false, c);

        c.marketId = word;
        c.params = _marketParams(info.morpho, word);
        if (c.params.loanToken == address(0) || c.params.loanToken != asset) return (false, c);
        // The V2 adapter reverts `IrmMismatch` on a market outside its pinned IRM, which would revert the
        // whole fill, so such a market is dropped here rather than discovered at execution time.
        if (info.adaptiveCurveIrm != address(0) && c.params.irm != info.adaptiveCurveIrm) return (false, c);

        c.liquidity = _marketLiquidity(info.morpho, word);
        if (c.liquidity == 0) return (false, c);

        (ok, word) = _probe(info.adapter, abi.encodeCall(IMorphoMarketV1Adapter.expectedSupplyAssets, (c.marketId)));
        if (!ok) return (false, c);
        c.position = uint256(word);
        if (c.position == 0) return (false, c);

        c.adapter = info.adapter;
        c.penaltyWad = info.penaltyWad;
        ok = true;
    }

    /// @notice Withdrawable liquidity of a Morpho Blue market
    /// @dev READ RAW, AND THAT IS EXACT, NOT AN APPROXIMATION. `supply - borrow` is INVARIANT under
    ///      interest accrual: Morpho's `_accrueInterest` adds the SAME `interest` to both
    ///      `totalSupplyAssets` and `totalBorrowAssets`, and pays the market fee purely by MINTING SUPPLY
    ///      SHARES — it never deducts assets. So an accrual preview over `wTaylorCompounded` returns a
    ///      number identical to this one, at every timestamp, with or without a fee, and also when
    ///      `irm == address(0)` (no accrual at all). This repo already states the same algebra at
    ///      `MorphoBlueYieldSourceOracle._accrue`. Morpho's own withdraw guard is this same difference,
    ///      evaluated post-accrual, which is why matching it exactly is what makes a full-liquidity pull
    ///      admissible rather than one wei too large.
    /// @dev WHY THIS IS WORTH SPELLING OUT: the alternative — an accrual preview over
    ///      `wTaylorCompounded`, which is what `MorphoBalancesLib` does for the borrow side — costs one
    ///      `IIrm.borrowRateView` per market, the most expensive read in this loop, and returns the same
    ///      number. Since `build` runs on chain inside the UserOp, that is real user gas spent to compute
    ///      a value already in storage. The position leg is the one that genuinely needs accrual, and it
    ///      gets it inside `expectedSupplyAssets` for free.
    function _marketLiquidity(address morpho, bytes32 marketId) private view returns (uint256) {
        (uint128 supplyAssets,, uint128 borrowAssets,,,) = IMorphoStaticTyping(morpho).market(Id.wrap(marketId));
        return supplyAssets > borrowAssets ? uint256(supplyAssets - borrowAssets) : 0;
    }

    /// @notice The market's parameters, or an all-zero struct when the id is unknown to Morpho
    function _marketParams(address morpho, bytes32 marketId) private view returns (MarketParams memory params) {
        (params.loanToken, params.collateralToken, params.oracle, params.irm, params.lltv) =
            IMorphoStaticTyping(morpho).idToMarketParams(Id.wrap(marketId));
    }

    /// @notice Stable insertion sort of candidate INDICES on (penalty ascending, capacity descending)
    /// @dev Indices rather than structs: swapping an eleven-word `Candidate` up to 496 times is pure waste.
    ///      Stability is load-bearing, not incidental — because `_collectCandidates` builds the array in
    ///      adapter-major, market-minor order, a stable sort satisfies the spec's final
    ///      "adapter index then market index ascending" tie-break without coding it as a third comparison.
    /// @dev Insertion sort, not quicksort: `n <= MAX_MARKETS`, so the worst case is 496 comparisons with no
    ///      recursion and no pivot pathology.
    function _sortOrder(Candidate[] memory candidates) private pure returns (uint256[] memory order) {
        uint256 n = candidates.length;
        order = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            order[i] = i;
        }

        for (uint256 i = 1; i < n; ++i) {
            uint256 slot = order[i];
            uint256 j = i;
            while (j > 0 && _cheaperFirst(candidates[slot], candidates[order[j - 1]])) {
                order[j] = order[j - 1];
                --j;
            }
            order[j] = slot;
        }
    }

    /// @notice Strict ordering predicate: is `a` to be filled before `b`?
    /// @dev Must be STRICT. Returning true on a tie would make the insertion sort unstable and silently
    ///      break the discovery-order tie-break that `_sortOrder` relies on.
    function _cheaperFirst(Candidate memory a, Candidate memory b) private pure returns (bool) {
        if (a.penaltyWad != b.penaltyWad) return a.penaltyWad < b.penaltyWad;
        return _capacity(a) > _capacity(b);
    }

    /// @notice Capacity of one candidate before any liquidity has been committed elsewhere
    function _capacity(Candidate memory c) private pure returns (uint256) {
        return c.position < c.liquidity ? c.position : c.liquidity;
    }

    /// @notice Greedy fill in sorted order, stopping the instant the request is covered
    /// @dev THE COMMITTED-LIQUIDITY LEDGER IS NOT BELT-AND-BRACES. `min(position, liquidity)` is computed
    ///      per (adapter, market) pair, but liquidity is a property of the MARKET. Two adapters of one vault
    ///      can hold positions in the same market id, and nothing forbids one adapter listing an id twice.
    ///      If two such candidates were sized independently, their pulls could sum above that market's
    ///      liquidity and the SECOND `forceDeallocate` would revert — failing the one operation that exists
    ///      to escape an illiquid vault, after the caller had already paid for the whole discovery pass.
    ///      Netting per market id removes that failure mode entirely. A linear scan over at most 32 memory
    ///      entries costs a few thousand gas; a mapping cannot be declared in memory at all.
    /// @dev Markets are NOT emptied merely because they are listed. The penalty is charged on the amount
    ///      pulled, so draining a market to free a small exit overpays for liquidity nobody asked for.
    function _fill(
        Candidate[] memory candidates,
        uint256[] memory order,
        uint256 assets,
        AdapterInfo[] memory infos,
        uint256 leafCap
    )
        private
        pure
        returns (Plan memory plan)
    {
        Pull[] memory scratch = new Pull[](order.length);
        bytes32[] memory seenIds = new bytes32[](order.length);
        uint256[] memory committed = new uint256[](order.length);
        uint256 distinct;
        uint256 taken;
        uint256 remaining = assets;

        for (uint256 i; i < order.length && remaining != 0; ++i) {
            Candidate memory c = candidates[order[i]];
            uint256 slot = _ledgerSlot(seenIds, distinct, c.marketId);
            if (slot == distinct) {
                seenIds[slot] = c.marketId;
                ++distinct;
            }

            // Clamped rather than a bare subtraction. The `MORPHO` gate makes a cross-deployment id
            // collision impossible today, so this cannot currently go negative — but an underflow here
            // would surface as a bare `Panic(0x11)` that reverts the whole exit instead of skipping one
            // candidate, which is too sharp an edge to leave resting on an invariant proved elsewhere.
            uint256 free = c.liquidity > committed[slot] ? c.liquidity - committed[slot] : 0;
            uint256 capacity = c.position < free ? c.position : free;
            if (capacity == 0) continue;

            uint256 pull = remaining < capacity ? remaining : capacity;
            committed[slot] += pull;
            remaining -= pull;

            scratch[taken++] = Pull(c.adapter, pull, c.params);
            uint256 penalty = pull.mulDivUp(c.penaltyWad, 1e18);
            if (penalty != 0) {
                plan.totalPenaltyAssets += penalty;
                ++plan.penalisedCount;
            }
        }

        if (remaining != 0) _revertUnfillable(infos, assets, assets - remaining, leafCap);

        plan.pulls = new Pull[](taken);
        for (uint256 k; k < taken; ++k) {
            plan.pulls[k] = scratch[k];
        }
    }

    /// @notice Index of `marketId` in the ledger, or `count` when it is not present yet
    function _ledgerSlot(bytes32[] memory ids, uint256 count, bytes32 marketId) private pure returns (uint256) {
        for (uint256 i; i < count; ++i) {
            if (ids[i] == marketId) return i;
        }
        return count;
    }

    /// @notice Explain a short fill: blame the leaf cap when an adapter WITH MARKETS was skipped for cost,
    ///         otherwise report the shortfall
    /// @dev Reverts unconditionally. `_probeAdapter` reads `marketCount` before the rate, so an ineligible adapter
    ///      with a non-zero rate AND a non-zero market count was skipped for cost and had something to offer. An
    ///      adapter rejected for shape has both at zero; one skipped for cost but listing no markets could not
    ///      have helped, so it does not get the blame. Whether its markets had liquidity is not known here, so
    ///      the blame is "raising the cap may help", not "would have".
    function _revertUnfillable(
        AdapterInfo[] memory infos,
        uint256 assets,
        uint256 available,
        uint256 leafCap
    )
        private
        pure
    {
        uint256 worstSkipped;
        for (uint256 i; i < infos.length; ++i) {
            AdapterInfo memory info = infos[i];
            if (!info.eligible && info.marketCount != 0 && info.penaltyWad > worstSkipped) {
                worstSkipped = info.penaltyWad;
            }
        }
        if (worstSkipped > leafCap) revert PENALTY_ABOVE_CAP(worstSkipped, leafCap);
        revert SHORTFALL(available, assets);
    }

    /// @notice Refuse the plan unless the account's claim covers the WHOLE exit: the assets it is freeing
    ///         plus the penalty those pulls will burn
    /// @dev THE BASE OF THE BURN IS WHAT THIS BOUNDS. `inspect` pins the vault and nothing else, and
    ///      `assets` is a resizable sized leg, so whoever builds the calldata chooses how much to force out.
    ///      Checking only `previewWithdraw(totalPenaltyAssets)` meant a leaf authorised "burn the penalty on
    ///      the vault's ENTIRE reachable liquidity", not "on this account's exit": any position smaller than
    ///      the penalty on that liquidity could be burned to nothing in one call, with the burned value
    ///      accruing to the vault's other holders. That is the compromised-session-key case, and the
    ///      vault-level hook widens the reach from one market to every eligible market under a single leaf.
    ///      A mis-sized amount from OMS lands on the same path, because SUP-21689 sizes the force and
    ///      redeem legs independently.
    /// @dev IT REJECTS NOTHING A REAL EXIT NEEDS. The next hop withdraws exactly `assets` for the account,
    ///      which costs `previewWithdraw(assets)` shares AFTER this leg has burned the penalty — so a plan
    ///      that fails this check would fail at its own withdraw step anyway. Checking it here converts a
    ///      late, partial failure (shares already burned, idle created for somebody else to claim) into an
    ///      early one that costs nothing.
    /// @dev STILL A CONSERVATIVE PRE-FLIGHT, NOT A TIGHT BOUND. Morpho burns
    ///      `previewWithdraw(penaltyAssets)` shares ROUNDED UP once per call, so summing per call can
    ///      exceed `previewWithdraw` of the total by at most one share per call after the first — the
    ///      `n - 1` slack. Each leg also moves the vault's `totalAssets`/`totalSupply`, so
    ///      `previewWithdraw` is not constant across legs; the drift is in the account's favour, since
    ///      the penalty withdraw leaves assets in the vault while burning shares. The accrual itself is
    ///      exact: `_emit` accrues before the first pull, on the state this view priced.
    /// @dev `previewWithdraw` is share math only and does NOT require the vault to hold idle, which is what
    ///      makes it callable while the vault is still illiquid — the only state this hook ever runs in.
    /// @dev THE ZERO-PENALTY EARLY RETURN STAYS. With no burn the account loses nothing here, so there is
    ///      no value at risk for this check to protect; an oversized request simply fails at the withdraw.
    function _requireSolvent(
        address vault,
        address account,
        uint256 assets,
        Plan memory plan
    )
        private
        view
    {
        if (plan.totalPenaltyAssets == 0) return;

        uint256 required = IMorphoVaultV2(vault).previewWithdraw(assets + plan.totalPenaltyAssets);
        if (plan.penalisedCount > 1) required += plan.penalisedCount - 1;

        uint256 held = IMorphoVaultV2(vault).balanceOf(account);
        if (held < required) revert INSUFFICIENT_SHARES(held, required);
    }

    /// @notice `accrueInterest()` first, then one `forceDeallocate` per planned pull, all targeted at the vault
    /// @dev ACCRUAL FIRST (SUP-21849, as in the redeem sibling). The vault settles on exactly the state `build`
    ///      priced `_requireSolvent` against (`previewWithdraw` already folds in `accrueInterestView`), BEFORE
    ///      pull 1 moves assets out of an adapter; every later leg hits Vault V2's once-per-tx latch. Without it
    ///      the first penalty withdraw accrued after the move and the adapter's post-withdraw `realAssets` could
    ///      differ from the view by a wei or two, which the pre-flight's slack absorbed but did not make exact.
    /// @dev TARGETED AT THE VAULT, AND EXECUTED BY THE ACCOUNT, both load-bearing. `VaultV2.forceDeallocate`
    ///      pays the penalty with `withdraw(penaltyAssets, vault, onBehalf)`, and Vault V2's `exit` spends
    ///      `allowance[onBehalf][msg.sender]` whenever `msg.sender != onBehalf`. The executor runs these
    ///      `Execution`s AS THE ACCOUNT, so `msg.sender` is already `onBehalf` and no allowance is needed.
    ///      Routing the loop through a helper contract would make the helper `msg.sender` and require the
    ///      account to grant it a share allowance — which is why this hook emits N calls instead.
    function _emit(address vault, address account, Pull[] memory pulls) private pure returns (Execution[] memory) {
        Execution[] memory executions = new Execution[](pulls.length + 1);
        executions[0] =
            Execution({ target: vault, value: 0, callData: abi.encodeCall(IMorphoVaultV2.accrueInterest, ()) });
        for (uint256 i; i < pulls.length; ++i) {
            executions[i + 1] = Execution({
                target: vault,
                value: 0,
                callData: abi.encodeCall(
                    IMorphoVaultV2.forceDeallocate,
                    (pulls[i].adapter, abi.encode(pulls[i].params), pulls[i].amount, account)
                )
            });
        }
        return executions;
    }

    /// @notice Guarded single-word read of a curator-controlled address
    /// @dev `code.length` first because a `STATICCALL` to a codeless address SUCCEEDS with empty returndata;
    ///      then an explicit returndata-length check, because a wrong-shaped contract can succeed and return
    ///      too little to decode. This is why the probes do not use `try/catch`.
    /// @dev THE LENGTH TEST IS `!= 32`, NOT `>= 32`. Two different hazards, and only one of them is a
    ///      revert. SHORT returndata is the revert: `abi.decode` of a word from fewer than 32 bytes throws,
    ///      and that throw happens AFTER the call returns, so the `success` flag cannot catch it — a
    ///      wrong-shaped contract in the curator's adapter list would take down the whole exit. An
    ///      OVER-LONG reply does not revert at all; `abi.decode` to a single static word simply reads the
    ///      first 32 bytes and ignores the rest. Rejecting it is still right, but for a different reason:
    ///      every getter probed here returns exactly one word, so a two-word answer means the target is not
    ///      the interface it is claiming to be, and silently believing its first word is how a look-alike
    ///      contract gets itself admitted. Both cases become "failed probe, skip this adapter", which is
    ///      the behaviour every other filter here has.
    function _probe(address target, bytes memory callData) private view returns (bool ok, bytes32 word) {
        if (target.code.length == 0) return (false, bytes32(0));
        (bool success, bytes memory ret) = target.staticcall{ gas: PROBE_GAS }(callData);
        if (!success || ret.length != 32) return (false, bytes32(0));
        return (true, abi.decode(ret, (bytes32)));
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    /// @dev DENOMINATION IS DELIBERATELY `TOKEN`, NOT `ASSETS`, matching the one-market sibling. By the
    ///      letter of `ISuperHook`'s own definitions `ASSETS` is the closer fit, since `assets` here is an
    ///      underlying quantity on an ERC-4626-shaped vault. It stays `TOKEN` because `ASSETS` invites OMS
    ///      to apply a price-per-share conversion, and there is no share conversion in this operation at
    ///      all. Changing it also requires an `amountMeta` override in `tooling/hook-enrichment.yaml`.
    /// @dev The argument is intentionally unnamed and unread: `HookSizingInterface.t.sol` calls this with
    ///      `""`, so reading `data` here would break that caller.
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

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    /// @dev PIPE MODE STAYS THE DEFAULT, recorded here because the alternative looks superficially right.
    ///      A hook that pays nobody reads like the textbook side-effect mode, but that mode AUTO-FORWARDS
    ///      the previous hook's output, which is exactly the chaining this hook must not invite — see
    ///      `_preExecute`, where the whole point is that nothing chainable is published.
    /// @dev DO NOT WRITE THE QUALIFIED ENUM NAME ANYWHERE IN THIS FILE, including in prose. `detectPipeMode`
    ///      in `tooling/generate-hook-sizing-manifest.ts` classifies a hook by plain substring search over
    ///      its SOURCE TEXT, so a comment naming the mode would silently reclassify this hook in the
    ///      generated sizing manifest. That is why the modes are described in words rather than named.
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Writes bytes 52..83 only — strictly below the flag at 84 — and the layout is fixed-length, so
    ///      the payload length is preserved.
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    /// @dev THE VAULT ALONE, deliberately. A leaf authorises this hook against one vault and does NOT pin
    ///      adapters or market ids, so a market the curator lists later is usable without re-signing — which
    ///      is the reason this hook reads the list on chain instead of taking it as calldata. `MAX_MARKETS`,
    ///      `_requireSolvent` and the leaf's `maxPenaltyWad` (committed by the signature, not the allowlist)
    ///      are the bounds on that authority.
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice On-chain pre-execution: publishes an output that FAILS CLOSED.
    /// @dev outAmount IS DELIBERATELY ZERO, not the requested `assets`, and this hook is built that way from
    ///      the start. `forceDeallocate` is terminal in the sense this repo has already written down twice:
    ///      it moves underlying from an adapter into the VAULT'S idle balance and burns penalty shares from
    ///      the account. The account receives nothing and its share balance strictly DECREASES. Publishing
    ///      `assets` would be byte-identical to the receipt a real redeem publishes, so a successor with
    ///      `usePrevHookAmount = true` would size a real movement of the account's own balance from a figure
    ///      it never received. Zero makes any such chaining hit the successor's own `amount == 0` guard and
    ///      revert. Precedents: `BaseLoanHookV2._settleRepay` and `HyperCoreSendAssetHook`.
    /// @dev CONSEQUENCE FOR THE MANAGER PATH: `SuperVaultStrategy` compares `getOutAmount()` against the
    ///      leg's `expectedAssetsOrSharesOut`, so a leaf containing this hook must pass ZERO as that floor.
    ///      That is the honest value — the leg produces nothing.
    /// @dev outToken REMAINS the vault's UNDERLYING, for off-chain classification. Keeping it is safe only
    ///      because outAmount is zero: a successor expecting the same underlying would pass a
    ///      `PREV_TOKEN_MISMATCH` check, and the zero amount is what stops it.
    /// @dev NO DISCOVERY HERE, unlike the one-market sibling's penalty re-check. `build` already ran in THIS
    ///      transaction at this `block.timestamp` — `SuperExecutorBase._processHook` calls it on chain — so
    ///      there is no simulate-then-execute gap to re-close, and repeating a pass that walks up to 32
    ///      markets would double the gas for no new information.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        (address vault,,) = _resolveRequest(prevHook, account, data);

        _setOutAmount(0, account);
        _setOutToken(IERC4626(vault).asset(), account);
    }
}
