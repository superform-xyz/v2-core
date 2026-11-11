// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
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

/// @title ForceRedeemMorphoVaultHook
/// @author Superform Labs
/// @notice OUTFLOW hook that exits an illiquid Morpho Vault V2 in one call: force-deallocates across the
///         vault's listed markets, cheapest-penalty-first, then withdraws the freed underlying.
/// @dev Third member of the family, replacing neither. `ForceDeallocateMorphoHook` takes one market;
///      `ForceDeallocateMorphoVaultHook` reads the whole list but stops at the vault's idle balance, and is
///      LIVE (mainnet 0x81fCC76adcE2180D43b375D6d065FE81bc15586e), which is why this is not a rename of it.
/// @dev data has the following structure
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         uint256 assets = BytesLib.toUint256(data, 52);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
/// @dev Those four lines ARE the OMS registry build path, not documentation. Renaming a field changes
///      what Superman can encode: `yieldSourceOracleId` must not match `^placeholder\d*$` (zero-filled),
///      and OMS asset identity reads the field named literally `yieldSource`.
/// @dev Deallocating without withdrawing is not an exit: the freed underlying lands in the VAULT'S own
///      balance, which `withdraw` pays to whoever burns shares next, while the penalty is already burned.
///      Hence one call, and the vault's idle ends where it started.
/// @dev `withdraw`, not `redeem` — the calldata amount is underlying. `receiver` and `onBehalf` are both
///      the account, so `msg.sender == onBehalf` and Vault V2's `exit` needs no share allowance.
/// @dev OUTFLOW/ERC4626 because it pays the account, so offset 0 must carry the chain's real oracle id;
///      a zero or unregistered id reverts `MANAGER_NOT_SET`. The deallocate siblings ignore that field.
/// @dev Do not place another exit on the same position after this hook; it has already withdrawn.
/// @dev Trusts Vault V2's reentrancy guards, adapter registry and 2% penalty ceiling. The adapter SET is
///      curator-controlled, which is why every adapter is identity-checked and gas-stipended.
contract ForceRedeemMorphoVaultHook is
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

    /// @notice A cap of zero, or one above Morpho's own 2% ceiling, would be meaningless
    error INVALID_PENALTY_CAP();
    /// @notice The fill fell short AND an adapter was excluded for being over the cap
    /// @dev A diagnostic, not a gate: an over-cap adapter is skipped. This fires only when the cap is
    ///      the actual cause, turning an opaque "not enough liquidity" into something actionable.
    error PENALTY_ABOVE_CAP(uint256 penaltyWad, uint256 capWad);
    /// @notice The payload is not exactly the declared 85-byte layout
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
    /// @dev A compile-time constant in Morpho's non-upgradeable bytecode, so it cannot be raised. A cap
    ///      above it would never bind and is rejected in the constructor as a configuration error.
    uint256 public constant MORPHO_MAX_PENALTY_WAD = 0.02e18;

    /// @dev A DoS bound. `build` runs on chain inside the UserOp, so without it a curator could grow the
    ///      market list until every exit ran out of gas. Gauntlet WETH Prime listed 3 on 2026-11-10.
    uint256 public constant MAX_MARKETS = 32;

    /// @dev `MAX_MARKETS` does not bound this: shape-rejected adapters contribute zero markets, so a long
    ///      list of junk adapters would still be walked in full, each costing a cold read and a probe.
    uint256 public constant MAX_ADAPTERS = 32;

    /// @notice The single sized leg. `replaceCalldataAmounts` writes bytes 52..83 and nothing else.
    uint256 private constant AMOUNT_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;
    /// @notice Exact, not minimum: there is no adapter and no `adapterData` tail in this layout, so a
    ///         longer payload is a caller error rather than a trailing blob to forward.
    uint256 private constant DATA_LENGTH = 85;

    /// @dev Measured, and the SUM is what matters: 192 probes worst case, so 100_000 each exceeded the
    ///      16,777,216 (2^24) per-tx cap from EIP-7825. This is ~3x the heaviest honest probe
    ///      (`expectedSupplyAssets`, 22,663 gas cold on mainnet); both bounds are pinned by tests.
    uint256 private constant PROBE_GAS = 70_000;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev An immutable, not a calldata field: it keeps the 85-byte layout, lands in the CREATE2 address
    ///      so every leaf already commits to it, and cannot be set vacuously by whoever builds calldata.
    /// @dev Needed despite Morpho's own 2% ceiling, because the per-adapter rate is curator-settable and
    ///      read at execution time, while signed intents can land much later.
    uint256 public immutable MAX_PENALTY_WAD;

    /// @dev An immutable gate: `adapter.morpho()` comes from a curator-registered contract and was otherwise
    ///      the target of typed, un-stipended reads — able to revert `build`, burn gas or claim unlimited
    ///      capacity. It also keeps the per-market-id ledger key sound; ids collide across deployments.
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
        /// @dev Count of pulls charging a NON-ZERO penalty. Drives the `+ n` rounding slack in the
        ///      solvency bound; a zero-penalty leg burns no shares and contributes no rounding.
        uint256 penalisedCount;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ The Morpho Blue singleton for this chain. Adapters pointing anywhere else are
    ///        skipped. Part of the CREATE2 address, so it cannot be repointed after deployment.
    /// @param maxPenaltyWad_ Ceiling in WAD. Must be non-zero and at most `MORPHO_MAX_PENALTY_WAD`; a cap
    ///        above Morpho's own ceiling could never bind.
    constructor(address morpho_, uint256 maxPenaltyWad_) BaseHook(HookType.OUTFLOW, HookSubTypes.ERC4626) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        if (maxPenaltyWad_ == 0 || maxPenaltyWad_ > MORPHO_MAX_PENALTY_WAD) revert INVALID_PENALTY_CAP();
        MORPHO = morpho_;
        MAX_PENALTY_WAD = maxPenaltyWad_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Force Redeem Morpho Vault";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Force deallocates across a Morpho Vault V2's markets and withdraws the assets";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Everything lives in this one view because `BaseHook.build` offers no non-view phase: resolve,
    ///      count and bound, collect with capacities, order cheapest-first, fill, then prove solvency.
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
        (address vault, uint256 assets) = _resolveRequest(prevHook, account, data);

        AdapterInfo[] memory infos = _probeAdapters(vault);
        Candidate[] memory candidates = _collectCandidates(vault, infos);
        Plan memory plan = _fill(candidates, _sortOrder(candidates), assets, infos);

        _requireSolvent(vault, account, assets, plan);

        return _emit(vault, account, assets, plan.pulls);
    }

    /// @dev `!=`, not `<`: a longer payload has nowhere to go, so accepting it would ignore caller bytes.
    function _resolveRequest(
        address prevHook,
        address account,
        bytes calldata data
    )
        private
        view
        returns (address vault, uint256 assets)
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
    }

    /// @dev Counts only adapters surviving the adapter-level filter — a rejected one contributes zero,
    ///      because its `marketIds` are never read. Markets dropped later still count.
    function _probeAdapters(address vault) private view returns (AdapterInfo[] memory infos) {
        uint256 len = IMorphoVaultV2(vault).adaptersLength();
        if (len > MAX_ADAPTERS) revert TOO_MANY_ADAPTERS(len, MAX_ADAPTERS);
        infos = new AdapterInfo[](len);

        uint256 total;
        for (uint256 i; i < len; ++i) {
            infos[i] = _probeAdapter(vault, IMorphoVaultV2(vault).adapters(i));
            if (!infos[i].eligible) continue;
            total += infos[i].marketCount;
            // Stop walking the moment the ceiling is breached; the revert is the same either way, and
            // continuing would pay for probes whose results are about to be discarded.
            if (total > MAX_MARKETS) revert TOO_MANY_MARKETS(total, MAX_MARKETS);
        }
    }

    /// @dev Every read is a guarded `staticcall`, not `try/catch`: the adapter list is heterogeneous and a
    ///      `STATICCALL` to a codeless address succeeds with empty returndata. Ineligible means skipped.
    function _probeAdapter(address vault, address adapter) private view returns (AdapterInfo memory info) {
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

        info.penaltyWad = IMorphoVaultV2(vault).forceDeallocatePenalty(adapter);
        if (info.penaltyWad > MAX_PENALTY_WAD) return info;

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

    /// @dev Deduplication is correctness: `expectedSupplyAssets` returns one number per (adapter, market),
    ///      so a duplicate listing describes the same capacity. Left in, the plan pulls twice the position
    ///      and the second call reverts — the liquidity ledger does not catch it.
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

    /// @dev Both bounds are real: `expectedSupplyAssets` is the adapter's accrued position, which can
    ///      exceed what the market can pay; exceeding either reverts and takes the transaction with it.
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

    /// @dev Raw, and exact: `supply - borrow` is invariant under accrual, since `_accrueInterest` adds the
    ///      same `interest` to both asset legs and pays the fee by minting shares. Morpho's own withdraw
    ///      guard is this same difference, which is why matching it exactly is admissible.
    function _marketLiquidity(address morpho, bytes32 marketId) private view returns (uint256) {
        (uint128 supplyAssets,, uint128 borrowAssets,,,) = IMorphoStaticTyping(morpho).market(Id.wrap(marketId));
        return supplyAssets > borrowAssets ? uint256(supplyAssets - borrowAssets) : 0;
    }

    /// @notice The market's parameters, or an all-zero struct when the id is unknown to Morpho
    function _marketParams(address morpho, bytes32 marketId) private view returns (MarketParams memory params) {
        (params.loanToken, params.collateralToken, params.oracle, params.irm, params.lltv) =
            IMorphoStaticTyping(morpho).idToMarketParams(Id.wrap(marketId));
    }

    /// @dev Indices, not structs. Stability is load-bearing: discovery is adapter-major/market-minor, so a
    ///      stable sort supplies the spec's final tie-break for free. Insertion sort because n <= 32.
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

    /// @dev The ledger is load-bearing: `min(position, liquidity)` is per (adapter, market) but liquidity
    ///      belongs to the MARKET, so two adapters sharing one could be sized past what it can pay and the
    ///      second call would revert. Markets are not emptied merely because they are listed.
    function _fill(
        Candidate[] memory candidates,
        uint256[] memory order,
        uint256 assets,
        AdapterInfo[] memory infos
    )
        private
        view
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

        if (remaining != 0) _revertUnfillable(infos, assets, assets - remaining);

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

    /// @dev Reverts unconditionally; split out to stay inside the repo's `code-complexity` ceiling.
    /// @dev A non-zero rate on an ineligible adapter is exactly the "skipped for cost" signal, since
    ///      `_probeAdapter` leaves it zero when it rejected earlier on shape.
    function _revertUnfillable(AdapterInfo[] memory infos, uint256 assets, uint256 available) private view {
        uint256 worstSkipped;
        for (uint256 i; i < infos.length; ++i) {
            if (!infos[i].eligible && infos[i].penaltyWad > worstSkipped) worstSkipped = infos[i].penaltyWad;
        }
        if (worstSkipped > MAX_PENALTY_WAD) revert PENALTY_ABOVE_CAP(worstSkipped, MAX_PENALTY_WAD);
        revert SHORTFALL(available, assets);
    }

    /// @notice Refuse the plan unless the account's claim covers the WHOLE exit, assets plus penalty.
    /// @dev Bounding the penalty alone let a leaf burn up to the cap of the vault's entire reachable
    ///      liquidity, not of this account's exit. Conservative by up to `penalisedCount` share-wei: at
    ///      Morpho's exact full-exit size `claim/(1+p)` it refuses by one wei, so the planner sizes under.
    /// @dev Not pre-flighted: a `receiveAssetsGate` excluding the account fails the final withdraw after
    ///      every pull has run (atomic, so no loss). `forceDeallocate`'s own penalty withdraw bypasses it.
    /// @dev No zero-penalty early return: the withdraw must be covered at any rate, else a panic after
    ///      every pull. Slack `+ penalisedCount` = one ceiling-rounded burn per penalised pull + withdraw.
    function _requireSolvent(
        address vault,
        address account,
        uint256 assets,
        Plan memory plan
    )
        private
        view
    {
        uint256 required =
            IMorphoVaultV2(vault).previewWithdraw(assets + plan.totalPenaltyAssets) + plan.penalisedCount;

        uint256 held = IMorphoVaultV2(vault).balanceOf(account);
        if (held < required) revert INSUFFICIENT_SHARES(held, required);
    }

    /// @dev Last execution, and what makes this an exit rather than a donation: it claims the idle the
    ///      pulls just created, in the same call. `receiver` and `onBehalf` are both the account, so no
    ///      share allowance is needed.
    function _emit(
        address vault,
        address account,
        uint256 assets,
        Pull[] memory pulls
    )
        private
        pure
        returns (Execution[] memory)
    {
        Execution[] memory executions = new Execution[](pulls.length + 1);
        for (uint256 i; i < pulls.length; ++i) {
            executions[i] = Execution({
                target: vault,
                value: 0,
                callData: abi.encodeCall(
                    IMorphoVaultV2.forceDeallocate,
                    (pulls[i].adapter, abi.encode(pulls[i].params), pulls[i].amount, account)
                )
            });
        }
        executions[pulls.length] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(IERC4626.withdraw, (assets, account, account))
        });
        return executions;
    }

    /// @dev `!= 32`, not `>= 32`. Short returndata makes `abi.decode` throw AFTER the call, where the
    ///      `success` flag cannot catch it. An over-long reply does not throw, but means the target is not
    ///      the interface it claims, and believing its first word is how a look-alike gets admitted.
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

    /// @dev `ASSETS`, reversing both siblings: `TOKEN` is right for a config hop that converts nothing.
    ///      This performs an ERC-4626 withdraw. `SHARES` would be wrong — the amount is underlying.
    ///      Needs the `amountMeta` override in `tooling/hook-enrichment.yaml`, whose default is IN/TOKEN.
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS
        );
    }

    /// @dev Implements ISuperHookInflowOutflow + ISuperHookOutflow. Pipe mode stays the default: this hook
    ///      publishes its own measured delta rather than forwarding the previous hook's. Never write the
    ///      qualified enum name here — `detectPipeMode` substring-matches source text.
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

    /// @dev The vault alone: a leaf does not pin adapters or markets, so a market the curator lists later
    ///      is usable without re-signing. `MAX_PENALTY_WAD` and `MAX_MARKETS` bound that authority.
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev The output FORWARDS, reversing the deallocate sibling's `outAmount = 0` rule — correct there
    ///      because the account receives nothing, wrong here because it does.
    /// @dev Measured, not declared: `outAmount` is the observed balance delta, so a fee-on-transfer
    ///      underlying is reported honestly. `usedShares` spans the whole call, penalty burns included.
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        (address vault,) = _resolveRequest(prevHook, account, data);

        asset = IERC4626(vault).asset();
        spToken = vault;
        _setOutAmount(IERC20(asset).balanceOf(account), account);
        usedShares = IMorphoVaultV2(vault).balanceOf(account);
    }

    /// @dev Clamped: it cannot underflow today, but doing so would surface as a bare panic at the very end
    ///      of an otherwise successful exit.
    function _postExecute(address, address account, bytes calldata data) internal override {
        address vault = data.extractYieldSource();

        _setOutAmount(IERC20(asset).balanceOf(account) - getOutAmount(account), account);
        _setOutToken(asset, account);

        uint256 remaining = IMorphoVaultV2(vault).balanceOf(account);
        usedShares = usedShares > remaining ? usedShares - remaining : 0;
    }
}
