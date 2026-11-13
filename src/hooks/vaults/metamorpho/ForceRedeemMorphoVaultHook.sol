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
    ISuperHookContextAware,
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
///         vault's listed markets, cheapest-penalty-first and no more than the redeem needs, then redeems
///         the shares the penalty did not burn.
/// @dev Third member of the family, replacing neither. `ForceDeallocateMorphoHook` takes one market;
///      `ForceDeallocateMorphoVaultHook` reads the whole list but stops at the vault's idle balance.
/// @dev SIZED IN SHARES (SUP-21849). Superman sizes this hop in shares (effect SHARES -> ASSETS), so offset 52
///      is the share input `S`. The pulls still move UNDERLYING; the last call is `redeem(S - P)` where `P` is
///      the penalty shares the pulls burn, so a full-balance exit leaves zero shares. `withdraw(assets)` would
///      burn `previewWithdraw(assets)`, which is not the leftover balance, and shares would remain.
/// @dev THE SMALLEST DEALLOCATION THAT COVERS THE REDEEM. Vault V2 accrues once per transaction; each pull
///      charges `pa = ceil(pull x rate)` assets and burns `ps = ceil(pa x N / D)` shares, then `N -= ps`,
///      `D -= pa`. The redeem pays `floor((S - P) x D / N)` out of idle, and idle after the pulls is exactly
///      `idle + X` (the penalty is paid to the vault itself). `build` walks the cheapest-first candidates
///      and binary-searches the last partial pull for the smallest `X` with `assetsOut <= idle + X`; a larger
///      `X` only burns more and pays less. `X = 0` is a plain `redeem(S)`. No feasible `X` reverts
///      `SHORTFALL`, never a partial exit.
/// @dev ON-CHAIN OUTPUT FLOOR, NO PENALTY CAP. `minAssetsOut` at offset 85 is the least underlying the account
///      must receive from the whole call: `build` refuses a plan that quotes below it and `_postExecute`
///      re-checks the MEASURED balance delta, so a rate the curator raises between signing and execution fails
///      the floor instead of silently burning more. The planner prices the live penalty into its quote and
///      expresses its tolerance through this one word; a per-adapter cap would be a second knob for the same
///      thing. Zero disables the floor. The word is committed by the signature over the hook data (source and
///      destination leaves hash the calldata), so a signer cannot loosen it; `inspect()` stays address-only.
/// @dev `usePrevHookAmount` is REJECTED: a previous outflow publishes underlying, and copying that into a
///      share field over-burns. This hop is the withdrawal vault-main; the flag is false by construction.
/// @dev FIRST-ACCRUAL ROUNDING. The chain accrues after pull 1 moved its assets adapter -> vault; the Morpho Blue
///      adapter can report up to 2 wei less than `build` read, so on a vault that is not rate-capped one
///      penalty burn can exceed the prediction by a single share-wei on an integer boundary, and a FULL exit's
///      `redeem(S - P)` then reverts (no loss). Partial exits are unaffected.
/// @dev data has the following structure (standard yield-source header + hook-specific), exactly 117 bytes:
/// @notice         bytes32 yieldSourceOracleId = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         uint256 shares = BytesLib.toUint256(data, 52);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 84);
/// @notice         uint256 minAssetsOut = BytesLib.toUint256(data, 85);
/// @dev Those five lines ARE the OMS registry build path, not documentation. `yieldSourceOracleId` must not
///      match `^placeholder\d*$` (zero-filled), OMS asset identity reads the field named literally
///      `yieldSource`, and the sized word is named `shares` so the encoder writes the share integer there.
/// @dev OUTFLOW/ERC4626 because it pays the account, so offset 0 must carry the chain's real oracle id;
///      a zero or unregistered id reverts `MANAGER_NOT_SET`. Do not place another exit on the same position
///      after this hook; it has already redeemed.
/// @dev Trusts Vault V2's reentrancy guards, adapter registry and 2% penalty ceiling. The adapter SET is
///      curator-controlled, which is why every adapter is identity-checked and gas-stipended.
contract ForceRedeemMorphoVaultHook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    using BytesLib for bytes;
    using HookDataDecoder for bytes;
    using MathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The underlying this call quotes (in `build`) or delivered (in `_postExecute`) is below the floor
    error INSUFFICIENT_OUTPUT(uint256 received, uint256 minAssetsOut);
    /// @notice The payload is not exactly the declared 117-byte layout
    error INVALID_DATA_LENGTH(uint256 given, uint256 expected);
    /// @notice The vault lists more markets than one transaction will walk
    error TOO_MANY_MARKETS(uint256 count, uint256 maxCount);
    /// @notice The vault registers more adapters than one transaction will probe
    error TOO_MANY_ADAPTERS(uint256 count, uint256 maxCount);
    /// @notice No deallocation within the eligible markets lets the redeem be paid
    error SHORTFALL(uint256 available, uint256 requested);
    /// @notice The account holds fewer shares than the request
    error INSUFFICIENT_SHARES(uint256 held, uint256 required);
    /// @notice The flag at offset 84 is set; this hook is sized in shares and takes no predecessor
    error USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED();

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev A DoS bound. `build` runs on chain inside the UserOp, so without it a curator could grow the
    ///      market list until every exit ran out of gas. Gauntlet WETH Prime listed 3 on 2026-11-10.
    uint256 public constant MAX_MARKETS = 32;

    /// @dev `MAX_MARKETS` does not bound this: shape-rejected adapters contribute zero markets, so a long
    ///      list of junk adapters would still be walked in full, each costing a cold read and a probe.
    uint256 public constant MAX_ADAPTERS = 32;

    /// @notice The single sized leg (shares). `replaceCalldataAmounts` writes bytes 52..83 and nothing else.
    uint256 private constant AMOUNT_POSITION = 52;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 84;
    /// @notice The output floor, in underlying
    uint256 private constant MIN_ASSETS_OUT_POSITION = 85;
    /// @notice Exact, not minimum: nothing may follow the floor word.
    uint256 private constant DATA_LENGTH = 117;

    /// @dev Measured, and the SUM is what matters: 192 probes worst case, so 100_000 each exceeded the
    ///      16,777,216 (2^24) per-tx cap from EIP-7825. This is ~3x the heaviest honest probe.
    uint256 private constant PROBE_GAS = 70_000;

    uint256 private constant WAD = 1e18;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev An immutable gate: `adapter.morpho()` comes from a curator-registered contract and was otherwise
    ///      the target of typed, un-stipended reads. It also keeps the per-market-id ledger key sound.
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
        bytes32 marketId;
        uint256 penaltyWad;
        uint256 position;
        uint256 liquidity;
        MarketParams params;
    }

    /// @notice One planned `forceDeallocate`
    struct Pull {
        address adapter;
        uint256 amount;
        MarketParams params;
    }

    /// @notice The vault's share-price state as the pulls will see it, stepped per pull
    /// @param n `totalSupply + fee shares + virtualShares`, minus the penalty burns so far
    /// @param d `newTotalAssets + 1`, minus the penalty assets so far
    /// @param penaltyShares `P`, the shares the pulls burn from the account
    /// @param sourced `X`, the underlying deallocated into idle
    struct Ladder {
        uint256 n;
        uint256 d;
        uint256 penaltyShares;
        uint256 sourced;
    }

    /// @notice The solved exit
    struct Plan {
        Pull[] pulls;
        uint256 penaltyShares;
        uint256 assetsOut;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ The Morpho Blue singleton for this chain. Adapters pointing anywhere else are skipped.
    constructor(address morpho_) BaseHook(HookType.OUTFLOW, HookSubTypes.ERC4626) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        MORPHO = morpho_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Force Redeem Morpho Vault";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Force deallocates across a Morpho Vault V2's markets and redeems the shares above a minimum output";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Everything lives in this one view because `BaseHook.build` offers no non-view phase.
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory)
    {
        (address vault, uint256 shares, uint256 minAssetsOut) = _decodeRequest(data);
        Plan memory plan = _plan(vault, account, shares);
        // Quoted here so the OMS pre-flight sees the same verdict; `_postExecute` re-checks what was delivered.
        if (plan.assetsOut < minAssetsOut) revert INSUFFICIENT_OUTPUT(plan.assetsOut, minAssetsOut);
        return _emit(vault, account, shares - plan.penaltyShares, plan.pulls);
    }

    /// @notice The underlying the account would receive for `shares` right now, from the same solver `build` uses
    /// @dev Reverts exactly like `build` (SHORTFALL, INSUFFICIENT_SHARES, ...), minus the floor: the caller is
    ///      asking what the floor should be. Block-state dependent: a different block accrues differently. Not
    ///      an OMS input; the OMS keeps its gross share quote.
    function previewAssetsOut(address vault, address account, uint256 shares) external view returns (uint256) {
        if (vault == address(0)) revert ADDRESS_NOT_VALID();
        if (shares == 0) revert AMOUNT_NOT_VALID();
        return _plan(vault, account, shares).assetsOut;
    }

    /// @dev Checks 1-4 of the revert order: length, vault, flag, shares. The floor word is read, not validated
    ///      (zero disables it). Shared by `build` and `_preExecute`; nothing else reads the layout.
    function _decodeRequest(bytes calldata data)
        private
        pure
        returns (address vault, uint256 shares, uint256 minAssetsOut)
    {
        if (data.length != DATA_LENGTH) revert INVALID_DATA_LENGTH(data.length, DATA_LENGTH);
        vault = data.extractYieldSource();
        if (vault == address(0)) revert ADDRESS_NOT_VALID();
        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) revert USE_PREV_HOOK_AMOUNT_NOT_SUPPORTED();
        shares = data.toUint256(AMOUNT_POSITION);
        if (shares == 0) revert AMOUNT_NOT_VALID();
        minAssetsOut = data.toUint256(MIN_ASSETS_OUT_POSITION);
    }

    /// @dev Probe, collect, order, net capacities, read the ladder once, solve. Reverts on anything short.
    function _plan(address vault, address account, uint256 shares) private view returns (Plan memory plan) {
        uint256 held = IMorphoVaultV2(vault).balanceOf(account);
        if (shares > held) revert INSUFFICIENT_SHARES(held, shares);

        AdapterInfo[] memory infos = _probeAdapters(vault);
        Candidate[] memory candidates = _collectCandidates(vault, infos);
        uint256[] memory order = _sortOrder(candidates);
        uint256[] memory caps = _capacities(candidates, order);
        (Ladder memory start, uint256 idle) = _ladder(vault);

        uint256 gross = _assetsOut(start, shares);
        // A total-loss vault (or dust shares) has no positive redeem to size against.
        if (gross == 0) revert AMOUNT_NOT_VALID();

        bool found;
        (found, plan) = _solve(start, idle, shares, candidates, order, caps);
        if (!found) revert SHORTFALL(idle + _sum(caps), gross);
    }

    /// @dev `N = totalSupply + performanceFeeShares + managementFeeShares + virtualShares`, `D = newTotalAssets
    ///      + 1`, read once before any pull: the first penalty withdraw accrues exactly this, and later pulls
    ///      only move `N`/`D` by their burns. `idle` is the vault's own underlying balance.
    function _ladder(address vault) private view returns (Ladder memory l, uint256 idle) {
        IMorphoVaultV2 v = IMorphoVaultV2(vault);
        (uint256 newTotalAssets, uint256 perfShares, uint256 mgmtShares) = v.accrueInterestView();
        l.n = v.totalSupply() + perfShares + mgmtShares + v.virtualShares();
        l.d = newTotalAssets + 1;
        idle = IERC20(v.asset()).balanceOf(vault);
    }

    /// @notice Smallest sourceable `X` whose post-penalty redeem is covered by `idle + X`
    /// @dev Monotone: within a pull a penalty wei lowers `S - P` by at least one share while raising the
    ///      price by at most one share's worth, so `assetsOut` never rises with `x`, and `idle + X` rises
    ///      one for one. Hence `covered` flips once along the cheapest-first walk, and once within the pull
    ///      where it flips: one prefix walk plus one binary search is exact.
    function _solve(
        Ladder memory start,
        uint256 idle,
        uint256 shares,
        Candidate[] memory candidates,
        uint256[] memory order,
        uint256[] memory caps
    )
        private
        pure
        returns (bool found, Plan memory plan)
    {
        if (_covered(start, idle, shares)) {
            plan.pulls = new Pull[](0);
            plan.assetsOut = _assetsOut(start, shares);
            return (true, plan);
        }

        Ladder memory s = start;
        for (uint256 k; k < order.length; ++k) {
            if (caps[k] == 0) continue;
            uint256 rate = candidates[order[k]].penaltyWad;
            (Ladder memory full, bool ok) = _step(s, caps[k], rate);
            if (!ok) break;
            if (!_covered(full, idle, shares)) {
                s = full;
                continue;
            }
            uint256 x = _searchPartial(s, idle, shares, caps[k], rate);
            (Ladder memory fin,) = _step(s, x, rate);
            if (fin.penaltyShares >= shares) return (false, plan);
            plan.assetsOut = _assetsOut(fin, shares);
            if (plan.assetsOut == 0) return (false, plan);
            plan.penaltyShares = fin.penaltyShares;
            plan.pulls = _materialise(candidates, order, caps, k, x);
            return (true, plan);
        }
        return (false, plan);
    }

    /// @dev Binary search for the smallest `x` in `[1, min(cap, deficit)]` that covers. `deficit` always
    ///      covers: idle rises by it while `assetsOut` cannot rise.
    function _searchPartial(
        Ladder memory s,
        uint256 idle,
        uint256 shares,
        uint256 cap,
        uint256 rate
    )
        private
        pure
        returns (uint256 lo)
    {
        uint256 deficit = _assetsOut(s, shares) - (idle + s.sourced);
        uint256 hi = cap < deficit ? cap : deficit;
        lo = 1;
        while (lo < hi) {
            uint256 mid = (lo + hi) >> 1;
            (Ladder memory m, bool ok) = _step(s, mid, rate);
            if (ok && _covered(m, idle, shares)) hi = mid;
            else lo = mid + 1;
        }
    }

    /// @dev Exactly Morpho's arithmetic: `pa = mulDivUp(x, rate, 1e18)`, `ps = previewWithdraw(pa) = mulDivUp(pa, N,
    /// D)`, then `exit` burns `ps` and takes `pa` off total assets. Not ok when a step would exhaust N or D.
    function _step(Ladder memory s, uint256 x, uint256 rate) private pure returns (Ladder memory next, bool ok) {
        uint256 pa = x.mulDivUp(rate, WAD);
        uint256 ps = pa.mulDivUp(s.n, s.d);
        if (ps >= s.n || pa >= s.d) return (s, false);
        next = Ladder(s.n - ps, s.d - pa, s.penaltyShares + ps, s.sourced + x);
        ok = true;
    }

    /// @dev `previewRedeem(S - P)` at the stepped state; zero once the penalty has eaten the whole input.
    function _assetsOut(Ladder memory s, uint256 shares) private pure returns (uint256) {
        if (s.penaltyShares >= shares) return 0;
        return (shares - s.penaltyShares).mulDivDown(s.d, s.n);
    }

    function _covered(Ladder memory s, uint256 idle, uint256 shares) private pure returns (bool) {
        return _assetsOut(s, shares) <= idle + s.sourced;
    }

    /// @dev Net capacity per ordered candidate: `min(position, liquidity)` with liquidity shared per market id
    ///      across adapters, committed in walk order. Only the last pull is ever partial, so committing full
    ///      capacities up front equals netting on the fly.
    function _capacities(
        Candidate[] memory candidates,
        uint256[] memory order
    )
        private
        pure
        returns (uint256[] memory caps)
    {
        caps = new uint256[](order.length);
        bytes32[] memory seenIds = new bytes32[](order.length);
        uint256[] memory committed = new uint256[](order.length);
        uint256 distinct;
        for (uint256 i; i < order.length; ++i) {
            Candidate memory c = candidates[order[i]];
            uint256 slot = _ledgerSlot(seenIds, distinct, c.marketId);
            if (slot == distinct) {
                seenIds[slot] = c.marketId;
                ++distinct;
            }
            uint256 free = c.liquidity > committed[slot] ? c.liquidity - committed[slot] : 0;
            uint256 capacity = c.position < free ? c.position : free;
            committed[slot] += capacity;
            caps[i] = capacity;
        }
    }

    /// @dev Full pulls for every non-empty candidate before `k`, then the partial `x` on `k`.
    function _materialise(
        Candidate[] memory candidates,
        uint256[] memory order,
        uint256[] memory caps,
        uint256 k,
        uint256 x
    )
        private
        pure
        returns (Pull[] memory pulls)
    {
        uint256 count;
        for (uint256 i; i < k; ++i) {
            if (caps[i] != 0) ++count;
        }
        pulls = new Pull[](count + 1);
        uint256 w;
        for (uint256 i; i < k; ++i) {
            if (caps[i] == 0) continue;
            Candidate memory c = candidates[order[i]];
            pulls[w++] = Pull(c.adapter, caps[i], c.params);
        }
        Candidate memory last = candidates[order[k]];
        pulls[w] = Pull(last.adapter, x, last.params);
    }

    function _sum(uint256[] memory xs) private pure returns (uint256 total) {
        for (uint256 i; i < xs.length; ++i) {
            total += xs[i];
        }
    }

    /// @dev Counts only adapters surviving the adapter-level filter.
    function _probeAdapters(address vault) private view returns (AdapterInfo[] memory infos) {
        uint256 len = IMorphoVaultV2(vault).adaptersLength();
        if (len > MAX_ADAPTERS) revert TOO_MANY_ADAPTERS(len, MAX_ADAPTERS);
        infos = new AdapterInfo[](len);

        uint256 total;
        for (uint256 i; i < len; ++i) {
            infos[i] = _probeAdapter(vault, IMorphoVaultV2(vault).adapters(i));
            if (!infos[i].eligible) continue;
            total += infos[i].marketCount;
            if (total > MAX_MARKETS) revert TOO_MANY_MARKETS(total, MAX_MARKETS);
        }
    }

    /// @dev Every read is a guarded `staticcall`, not `try/catch`: the adapter list is heterogeneous and a
    ///      `STATICCALL` to a codeless address succeeds with empty returndata. Ineligible means skipped.
    function _probeAdapter(address vault, address adapter) private view returns (AdapterInfo memory info) {
        info.adapter = adapter;

        (bool ok, bytes32 word) = _probe(adapter, abi.encodeCall(IMorphoMarketV1Adapter.parentVault, ()));
        if (!ok || address(uint160(uint256(word))) != vault) return info;

        (ok, word) = _probe(adapter, abi.encodeCall(IMorphoMarketV1Adapter.morpho, ()));
        if (!ok || address(uint160(uint256(word))) != MORPHO) return info;
        info.morpho = MORPHO;

        (ok, word) = _probe(adapter, abi.encodeCall(IMorphoMarketV1Adapter.marketIdsLength, ()));
        if (!ok) return info;
        info.marketCount = uint256(word);

        // Read for cheapest-first ordering and the burn arithmetic, never as a gate: the floor is the bound.
        info.penaltyWad = IMorphoVaultV2(vault).forceDeallocatePenalty(adapter);

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

    /// @dev Deduplication is correctness: a duplicate listing describes the same capacity.
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

    /// @dev Both bounds are real: the adapter's position and the market's withdrawable liquidity.
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

    /// @dev `supply - borrow`, invariant under accrual; Morpho's own withdraw guard is this difference.
    function _marketLiquidity(address morpho, bytes32 marketId) private view returns (uint256) {
        (uint128 supplyAssets,, uint128 borrowAssets,,,) = IMorphoStaticTyping(morpho).market(Id.wrap(marketId));
        return supplyAssets > borrowAssets ? uint256(supplyAssets - borrowAssets) : 0;
    }

    function _marketParams(address morpho, bytes32 marketId) private view returns (MarketParams memory params) {
        (params.loanToken, params.collateralToken, params.oracle, params.irm, params.lltv) =
            IMorphoStaticTyping(morpho).idToMarketParams(Id.wrap(marketId));
    }

    /// @dev Indices, not structs. Stable insertion sort (n <= 32): discovery order is the tie-break.
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

    /// @dev Strict: a tie keeps discovery order.
    function _cheaperFirst(Candidate memory a, Candidate memory b) private pure returns (bool) {
        if (a.penaltyWad != b.penaltyWad) return a.penaltyWad < b.penaltyWad;
        return _capacity(a) > _capacity(b);
    }

    function _capacity(Candidate memory c) private pure returns (uint256) {
        return c.position < c.liquidity ? c.position : c.liquidity;
    }

    function _ledgerSlot(bytes32[] memory ids, uint256 count, bytes32 marketId) private pure returns (uint256) {
        for (uint256 i; i < count; ++i) {
            if (ids[i] == marketId) return i;
        }
        return count;
    }

    /// @dev The pulls, then `redeem(S - P)`: `receiver` and `onBehalf` are both the account, so no allowance.
    function _emit(
        address vault,
        address account,
        uint256 remainderShares,
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
            target: vault, value: 0, callData: abi.encodeCall(IERC4626.redeem, (remainderShares, account, account))
        });
        return executions;
    }

    /// @dev `!= 32`: short returndata would make `abi.decode` throw after the call; over-long means a
    ///      look-alike. Codeless targets are refused before the call.
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

    /// @dev `SHARES`: offset 52 is the share input the vault redeems. Needs the `amountMeta` override in
    ///      `tooling/hook-enrichment.yaml`, whose default is IN/TOKEN.
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES
        );
    }

    /// @dev Implements ISuperHookInflowOutflow + ISuperHookOutflow. Pipe mode stays the default: this hook
    ///      publishes its own measured delta. Never write the qualified enum name here.
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    /// @dev Writes bytes 52..83 only: the flag at 84 and the floor word at 85..116 are untouched.
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

    /// @dev The vault alone, address-shaped as every inspector in the fleet. The floor word is committed by the
    ///      signature over the hook data, not by the allowlist.
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Measured, not declared: `outAmount` is the observed underlying delta; `usedShares` spans the whole
    ///      call, penalty burns included. `build` ran on chain in this same transaction, so the rates it
    ///      planned on cannot have moved; only the layout is re-validated here.
    function _preExecute(address, address account, bytes calldata data) internal override {
        (address vault,,) = _decodeRequest(data);

        asset = IERC4626(vault).asset();
        spToken = vault;
        _setOutAmount(IERC20(asset).balanceOf(account), account);
        usedShares = IMorphoVaultV2(vault).balanceOf(account);
    }

    /// @dev THE FLOOR IS CHECKED ON WHAT ARRIVED, not on the quote: a fee-on-transfer underlying or a vault that
    ///      pays less than `previewRedeem` fails here even though `build` passed.
    /// @dev PRE-FEE. The floor is judged on the gross delta; `SuperExecutor` then refreshes `outAmount` net of
    ///      the ledger's performance fee, so a successor sizing from `getOutAmount` (the ADL repay) may read
    ///      slightly less than `minAssetsOut`. Size the floor on the gross quote, not on the net amount.
    /// @dev Clamped: a vault that minted shares mid-exit would otherwise panic at the very end.
    function _postExecute(address, address account, bytes calldata data) internal override {
        address vault = data.extractYieldSource();

        uint256 received = IERC20(asset).balanceOf(account) - getOutAmount(account);
        uint256 minAssetsOut = data.toUint256(MIN_ASSETS_OUT_POSITION);
        if (received < minAssetsOut) revert INSUFFICIENT_OUTPUT(received, minAssetsOut);

        _setOutAmount(received, account);
        _setOutToken(asset, account);

        uint256 remaining = IMorphoVaultV2(vault).balanceOf(account);
        usedShares = usedShares > remaining ? usedShares - remaining : 0;
    }
}
