// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// aave-v4 vendor
import { IAaveV4Spoke } from "../../vendor/aave-v4/IAaveV4Spoke.sol";

// superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { AaveV4ReserveRegistryV2 } from "./AaveV4ReserveRegistryV2.sol";
import { AaveV4ReserveKey } from "../../libraries/AaveV4ReserveKey.sol";
import { IAaveV4OwnerSnapshot } from "../../interfaces/accounting/IAaveV4OwnerSnapshot.sol";
import { IAaveV4MarketPosition } from "../../interfaces/accounting/IAaveV4MarketPosition.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title AaveV4ReserveOracle
/// @author Superform Labs
/// @notice Single oracle serving BOTH legs of an Aave V4 reserve — the supply (collateral/deposit) leg and
///         the debt (borrow) leg — replacing the former `AaveV4SupplyYieldSourceOracle` /
///         `AaveV4DebtOracle` pair.
/// @dev THE SIDE COMES FROM THE KEY, NOT FROM THE FUNCTION. `IYieldSourceOracle`'s reads take
///      `(yieldSourceAddress, owner)` with no side parameter, and the aggregator `SuperYieldSourceOracle`
///      invokes them polymorphically — `getTVLByOwnerOfShares(yieldSourceAddresses[i], ownersOfShares[i])`
///      on `yieldSourceOracles[i]`. The previous two-contract design disambiguated the leg by ORACLE
///      ADDRESS: callers passed the debt oracle for the debt leg and the supply oracle for the supply leg,
///      both with the same key. Collapsing to one address removes that discriminator, so
///      `AaveV4ReserveRegistryV2` binds a `Side` into each key's record and this oracle branches on it in
///      `getBalanceOfOwner` and `getTVL` ONLY — `decimals`, `getPricePerShare` and the four identity
///      converters are side-INDEPENDENT, because both legs of a reserve share one underlying asset and
///      PPS is 1:1 on each. Each key therefore has exactly one meaning, forever — a debt key can never
///      be read as a supply balance. The dispatch is exhaustive (see `UNHANDLED_SIDE`): a supply read is
///      an explicit decision, never the fall-through for "not DEBT".
///
///      Both legs use identity mapping (PPS = 1:1) because Aave V4's spoke views already return accrued
///      amounts directly in asset units: `getUserSuppliedAssets` for supply, and `getUserDebt`
///      (drawn + premium) for debt. Spoke views virtually accrue interest — the supply leg via the hub
///      share price, the debt leg via the live hub index with premium riding the same index — so no manual
///      accrual logic is needed here.
///
///      WHY IDENTITY (asset units) AND NOT A SHARES-BASED PPS ORACLE — supply leg:
///      Every Superform loan hook measures ERC20 wallet-balance deltas in ASSET units (V4 has no
///      transferable share token to delta against), and `BaseLedger._takeSnapshot` treats inflow amounts as
///      literal shares priced by this oracle's PPS. Identity PPS (shares ≡ assets) is the only mapping
///      unit-consistent with what hooks can report. A true shares-PPS oracle (over `getUserSuppliedShares`
///      / `hub.previewRemoveByShares`) would require hooks that read spoke share state — a different settle
///      architecture. That variant was only ever needed to enable performance fees, which require ledger
///      registration; see the fee note below.
///
///      LEDGER REGISTRATION — asymmetric by leg, and NOT simply "unregistered":
///      Today this oracle is deployed for SuperVault price-per-share computation and no Aave V4
///      yieldSourceOracleId is configured in `SuperLedgerConfiguration` anywhere in the deploy path.
///      But the two already-deployed idle MONEY_MARKET hooks are accounting hooks — `AaveV4LendHook` is
///      `HookType.INFLOW` and `AaveV4RedeemHook` is `HookType.OUTFLOW` — and `SuperExecutorBase`
///      reverts `MANAGER_NOT_SET` for them unless the SUPPLY key's id is registered pointing at an
///      oracle. So driving those hooks REQUIRES registering this oracle for SUPPLY keys, and it must
///      then be at `feePercent = 0`. DEBT keys must never be ledger-wired at all (every LOAN hook is
///      `HookType.NONACCOUNTING`, so nothing drives `updateAccounting` for them).
///      `superLedgerConfiguration_` is nonetheless inert INSIDE this contract: `getAssetOutputWithFees`
///      bypasses the inherited fee path, and `BaseLedger._processOutflow()` reads `config.feePercent`
///      directly without routing through here — so `feePercent = 0` is an operational invariant, not an
///      on-chain guard.
///
///      WHY THE FEE VIEW IS BYPASSED ON BOTH LEGS — the two legs have different reasons:
///      DEBT: debt positions take no cost-basis snapshot, so the inherited `previewFees()` would treat
///      an entire debt balance as "profit". SUPPLY: the idle hooks report the supplied-assets delta as
///      "shares", so under identity PPS cost basis == shares at every snapshot and the ledger's outflow
///      profit is structurally zero — a partial redeem re-prices to its own cost basis, and a full
///      redeem after accrual reports usedShares above the accumulator, which `BaseLedger` caps and
///      re-prices to the accumulator. A non-zero feePercent would therefore charge nothing on the
///      supply leg (no fee leak, no FEE_NOT_SET DoS), while the inherited view would still inflate the
///      quoted output. Enabling real performance fees needs a shares-PPS oracle version (over
///      `getUserSuppliedShares` / `hub.previewRemoveByShares`), never a config change.
///
///      CONSUMER WARNING — ledger shares are not NAV: once yield has accrued, a redeem larger than the
///      ledger principal clears the accumulator for the key while the remainder stays supplied on the
///      Spoke. Pricing, NAV and monitoring must read `getBalanceOfOwner`, never
///      `usersAccumulatorShares`.
///
///      Semantic notes for downstream consumers:
///      - `getBalanceOfOwner()` returns asset units on both legs, not a share balance. Identity PPS makes
///        the numeric result correct regardless of interpretation. For a DEBT key it is the owner's accrued
///        debt; Aave V4's internal drawnShares/premiumShares are not a single meaningful unit.
///      - `getTVL()` returns reserve-level total supplied assets for a SUPPLY key, and reserve-level
///        aggregate outstanding debt (the `totalBorrows()` analog) for a DEBT key — never total supplied
///        assets for a debt key.
///      - Values are denominated in the reserve's underlying asset. A leveraged position's supply and debt
///        legs are different reserves in different denominations; cross-asset conversion and any netting of
///        supply against debt are PERIPHERY concerns. This contract holds no price feeds and deliberately
///        exposes no net-balance view.
///      - TOKENIZED EQUITIES (Coinbase B20, the Base equities hub): these return RAW token units, which
///        are NOT share counts. B20 applies corporate actions through an off-balance `multiplier()` that
///        never touches `balanceOf` — a split or reinvested dividend moves the multiplier, not holder
///        balances. So a consumer MUST price these units with the per-token, multiplier-inclusive feed
///        (Chainlink's B20 total-return value), never a per-share equity feed, and must NOT additionally
///        apply `multiplier()` / `scaledBalanceOf` to what this oracle returns — that double-counts it.
///        The error from using a per-share feed is silent and compounds with every dividend.
///      - Rounding is passed through unmodified — no double-rounding. Aave V4 rounds supply conversions
///        DOWN at source (`toAddedAssetsDown`: the supplier can claim at most this much) and debt UP
///        (drawn via `rayMulUp`, premium via `fromRayUp`: the borrower owes at least this much).
///      - Debt keeps accruing while a reserve is paused or frozen (flags gate mutations, not accrual).
///      - Direct spoke withdrawals (self-calls are always allowed by `onlyPositionManager`) bypass
///        Superform accounting — the documented SECURITY.md trade-off for withdrawing directly from a
///        yield source.
///
///      DEBT MUTATION WITHOUT OWNER ACTION: the premium component of a user's debt is re-rated by
///      `updateUserRiskPremium` — self-callable and AccessManager-authorized on the deployed spoke
///      (fork-verified; the pre-launch Sherlock-contest code was permissionless, hardened before
///      deployment) — and implicitly whenever the position is touched, including by approved position
///      managers. Combined with continuous index accrual, consumers must not assume reported debt is
///      constant absent position-owner actions — it can move between blocks.
///
///      Every registry-resolving view (`decimals`, `getPricePerShare`, `getBalanceOfOwner`,
///      `getTVLByOwnerOfShares`, `getTVL`) reverts with the registry's `RESERVE_NOT_REGISTERED` for
///      unregistered keys — never a zero return. The pure identity converters (`getShareOutput`,
///      `getWithdrawalShareOutput`, `getAssetOutput`, and the fee-bypass `getAssetOutputWithFees`) do NOT
///      consult the registry and return the input amount for any key; identity is the invariant-correct
///      answer independent of registration, so they cannot be used to probe registration status. Batch
///      methods in `AbstractYieldSourceOracle` isolate reverts via try/catch in
///      `getTVLByOwnerOfSharesMultiple` only; `getPricePerShareMultiple` / `getTVLMultiple` loop without
///      isolation (inherited behavior — one reverting key aborts those batch calls).
contract AaveV4ReserveOracle is AbstractYieldSourceOracle, IAaveV4OwnerSnapshot, IAaveV4MarketPosition {
    /// @notice Requested discovery coverage exceeds the caller's explicit bound.
    error SNAPSHOT_RESERVE_LIMIT();
    /// @notice Debt positions for the same token have inconsistent registry decimal metadata.
    error SNAPSHOT_DECIMALS_MISMATCH();

    /// @notice A covered spoke holds supplied collateral that no requested market accounts for, and whose
    ///         SUPPLY leg is not registered, so it cannot be included either (SUP-21259).
    /// @dev The asymmetry this closes: debt was always DISCOVERED on covered spokes while supply arrived
    ///      only through requested market bindings. Removing the last market naming a supply reserve
    ///      therefore dropped its collateral out of NAV while its debt kept being discovered — PPS falls, or
    ///      a negative-NAV guard rejects, with the supply key still registered. Residual collateral is now
    ///      INCLUDED when its leg is registered and REJECTED when it is not; it is never silently omitted.
    error UNCOVERED_COLLATERAL(address spoke, uint256 reserveId);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is supplied where one is not permitted
    error ZERO_ADDRESS();

    /// @notice Thrown when a key's registry side is neither SUPPLY nor DEBT
    /// @dev Unreachable while `Side` has exactly two members and `getReserveInfo` gates on `registered`.
    ///      It exists so the dispatch is EXHAUSTIVE rather than falling through: a supply read must be an
    ///      explicit decision, never the default for "not DEBT". `Side.SUPPLY` is the zero value and
    ///      therefore the `delete` default, so a fall-through would make any future unset or third-member
    ///      state silently report NAV-positive supplied assets.
    error UNHANDLED_SIDE();

    /*//////////////////////////////////////////////////////////////
                               STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The registry resolving pseudo-address keys to (spoke, reserveId, side) bindings
    AaveV4ReserveRegistryV2 public immutable REGISTRY;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the AaveV4ReserveOracle bound to a ledger configuration and reserve registry
    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract; must be non-zero.
    ///        Inert here — see the LEDGER REGISTRATION note in the contract docs — but required by
    ///        AbstractYieldSourceOracle and kept for constructor parity with every other oracle.
    /// @param registry_ Address of the AaveV4ReserveRegistryV2; must be non-zero
    constructor(
        address superLedgerConfiguration_,
        address registry_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        if (superLedgerConfiguration_ == address(0) || registry_ == address(0)) revert ZERO_ADDRESS();
        REGISTRY = AaveV4ReserveRegistryV2(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Registry-stored underlying decimals, bound at registration from the spoke's Reserve struct.
    ///      Side-independent: both legs of a reserve share one underlying asset.
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        (,, uint8 decimals_,) = _resolveLeg(yieldSourceAddress);
        return decimals_;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns 10 ** decimals (always 1:1 identity, never zero) on both legs. Reverts via checked
    ///      arithmetic if decimals >= 78, which cannot occur with real ERC-20 tokens (max 18 in practice).
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        (,, uint8 decimals_,) = _resolveLeg(yieldSourceAddress);
        return 10 ** uint256(decimals_);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) {
        return assetsIn;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getWithdrawalShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) {
        return assetsIn;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getAssetOutput(address, address, uint256 sharesIn) public pure override returns (uint256) {
        return sharesIn;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Overridden to bypass fee computation entirely on both legs. See the LEDGER REGISTRATION note
    ///      in the contract docs: this override protects callers of this view only —
    ///      `BaseLedger._processOutflow()` computes fees directly from `config.feePercent` and does not
    ///      route through here.
    function getAssetOutputWithFees(
        bytes32,
        address yieldSourceAddress,
        address assetOut,
        address,
        uint256 usedShares
    )
        external
        pure
        override
        returns (uint256)
    {
        return getAssetOutput(yieldSourceAddress, assetOut, usedShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev SUPPLY key: `spoke.getUserSuppliedAssets(reserveId, owner)` — the exact read
    ///      `BaseAaveV4LoanHookV2._suppliedAssets` performs. DEBT key: `spoke.getUserDebt(reserveId, owner)`
    ///      summed (drawn + premium) — the exact read `BaseAaveV4LoanHookV2._totalDebt` performs. Both match
    ///      their hook-side counterpart exactly, so hook-resolved amounts and oracle-read amounts can never
    ///      disagree within a transaction.
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        (address spoke, uint256 reserveId,, AaveV4ReserveRegistryV2.Side side) = _resolveLeg(yieldSourceAddress);

        if (side == AaveV4ReserveRegistryV2.Side.SUPPLY) {
            return IAaveV4Spoke(spoke).getUserSuppliedAssets(reserveId, ownerOfShares);
        }
        if (side == AaveV4ReserveRegistryV2.Side.DEBT) {
            (uint256 drawnDebt, uint256 premiumDebt) = IAaveV4Spoke(spoke).getUserDebt(reserveId, ownerOfShares);
            return drawnDebt + premiumDebt;
        }
        revert UNHANDLED_SIDE();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Identical to getBalanceOfOwner on both legs since PPS = 1:1.
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        return getBalanceOfOwner(yieldSourceAddress, ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev SUPPLY key: reserve-level total supplied assets (`spoke.getReserveSuppliedAssets`). DEBT key:
    ///      reserve-level aggregate outstanding debt (`spoke.getReserveDebt`, drawn + premium) — the
    ///      `totalBorrows()` analog, NOT total supplied assets.
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        (address spoke, uint256 reserveId,, AaveV4ReserveRegistryV2.Side side) = _resolveLeg(yieldSourceAddress);

        if (side == AaveV4ReserveRegistryV2.Side.SUPPLY) {
            return IAaveV4Spoke(spoke).getReserveSuppliedAssets(reserveId);
        }
        if (side == AaveV4ReserveRegistryV2.Side.DEBT) {
            (uint256 drawnDebt, uint256 premiumDebt) = IAaveV4Spoke(spoke).getReserveDebt(reserveId);
            return drawnDebt + premiumDebt;
        }
        revert UNHANDLED_SIDE();
    }

    /*//////////////////////////////////////////////////////////////
                           SIDE INTROSPECTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Which leg of a reserve the given key denotes
    /// @dev MIGRATION GUARD. The `IYieldSourceOracle` read surface is sideless and returns a sign-blind
    ///      `uint256` with identical `decimals()` and `getPricePerShare()` on both legs, so a debt entry is
    ///      indistinguishable from a supply entry in the return value alone. Worse, the legacy key
    ///      (`AaveV4ReserveRegistryV2.computeReserveKey`) used to serve EITHER leg depending on which of the
    ///      two former oracle addresses a consumer called; against this merged oracle it is unconditionally
    ///      the SUPPLY leg. An address-only migration — swap the oracle, keep the key — therefore turns a
    ///      debt reference into a supply read silently, inverting that entry's economic sign in a NAV sum.
    ///      Use this to ASSERT the side of every carried-over `(oracle, key)` pair at configuration time, in
    ///      a deployment script's check phase or an indexer's startup validation, rather than trusting a
    ///      runbook. Reverts `RESERVE_NOT_REGISTERED` for unknown keys, so it is also a registration probe.
    /// @dev DELIBERATELY NOT market-key-resolving, unlike every other registry-resolving read here. This is
    ///      the RESERVE-namespace classifier and the probe migrations use to tell the two namespaces apart;
    ///      resolving a market key to `SUPPLY` would make it answer for a key that `isRegistered` reports as
    ///      false, i.e. it would stop discriminating exactly where discrimination is the point. A market key
    ///      therefore still reverts `RESERVE_NOT_REGISTERED` here. Use `getMarketInfo` / `isMarketRegistered`
    ///      to classify the other namespace.
    /// @param yieldSourceAddress The reserve key to classify
    /// @return side SUPPLY or DEBT
    function sideOf(address yieldSourceAddress) external view returns (AaveV4ReserveRegistryV2.Side side) {
        (,,,, side) = REGISTRY.getReserveInfo(yieldSourceAddress);
    }

    /// @inheritdoc IAaveV4MarketPosition
    function getMarketPosition(address marketKey, address owner)
        external
        view
        returns (MarketPosition memory position)
    {
        if (owner == address(0)) revert ZERO_ADDRESS();

        // Reverts MARKET_NOT_REGISTERED for an unknown key AND for a reserve key: the namespaces do not
        // fall back onto each other in either direction.
        (
            position.spoke,
            position.supplyReserveId,
            position.borrowReserveId,
            position.collateralToken,
            position.loanToken
        ) = REGISTRY.getMarketInfo(marketKey);

        // Decimals come from the registry's leg bindings, which `registerMarket` required to exist, rather
        // than from a second token call — one source of truth per leg. Read directly rather than through
        // `_resolveLeg`: these are reserve keys by construction, so the market probe would always miss.
        (,,, position.collateralDecimals,) =
            REGISTRY.getReserveInfo(AaveV4ReserveKey.computeReserveKey(position.spoke, position.supplyReserveId));
        (,,, position.loanDecimals,) =
            REGISTRY.getReserveInfo(AaveV4ReserveKey.computeDebtKey(position.spoke, position.borrowReserveId));

        position.suppliedAssets = IAaveV4Spoke(position.spoke).getUserSuppliedAssets(position.supplyReserveId, owner);
        (uint256 drawn, uint256 premium) = IAaveV4Spoke(position.spoke).getUserDebt(position.borrowReserveId, owner);
        position.debtAssets = drawn + premium;
    }

    /*//////////////////////////////////////////////////////////////
                        KEY RESOLUTION
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolve any key this oracle accepts into ONE reserve leg.
    ///      A reserve key resolves to itself. A MARKET key (SUP-21255) resolves to its COLLATERAL leg —
    ///      `computeReserveKey(spoke, supplyReserveId)` — so the sideless `IYieldSourceOracle` surface keeps
    ///      returning one number in one asset for a market key, and that number is the supplied assets of
    ///      the reserve an idle lend settled. Debt is NEVER reachable through a market key here, and the two
    ///      legs are never netted: `getMarketPosition` is the read that returns both.
    ///      An unknown key still reverts `RESERVE_NOT_REGISTERED`, exactly as before this resolver existed —
    ///      the market probe is non-reverting, so the final `getReserveInfo` produces the error.
    ///      VALUATION CAVEAT: summing `getBalanceOfOwner` over several market keys is correct only while
    ///      their COLLATERAL reserves differ. Two markets over one collateral reserve resolve to the same
    ///      leg and would count that position twice — portfolio valuation belongs in `getOwnerSnapshot`,
    ///      which de-duplicates legs across the whole requested set.
    /// @param key A reserve-leg key or a market key
    /// @return spoke The spoke holding the resolved reserve
    /// @return reserveId The resolved reserve id
    /// @return decimals_ The resolved reserve's underlying decimals
    /// @return side The resolved leg's side
    function _resolveLeg(address key)
        private
        view
        returns (address spoke, uint256 reserveId, uint8 decimals_, AaveV4ReserveRegistryV2.Side side)
    {
        address legKey = key;
        if (REGISTRY.isMarketRegistered(key)) {
            (address marketSpoke, uint256 supplyReserveId,,,) = REGISTRY.getMarketInfo(key);
            legKey = REGISTRY.computeReserveKey(marketSpoke, supplyReserveId);
        }
        (spoke, reserveId,, decimals_, side) = REGISTRY.getReserveInfo(legKey);
    }

    /// @inheritdoc IAaveV4OwnerSnapshot
    function getOwnerSnapshot(
        address owner,
        address[] calldata marketKeys,
        address[] calldata configuredSpokes,
        address[] calldata cashTokens,
        address vaultAsset,
        uint256 maxReservesPerSpoke
    )
        external
        view
        returns (MarketBinding[] memory markets, OwnerPosition[] memory positions, WalletBalance[] memory balances)
    {
        if (owner == address(0) || vaultAsset == address(0)) {
            revert ZERO_ADDRESS();
        }
        if (maxReservesPerSpoke == 0 || maxReservesPerSpoke > 65_536) revert SNAPSHOT_RESERVE_LIMIT();

        markets = _marketBindings(marketKeys);
        positions = _ownerPositions(owner, markets, configuredSpokes, maxReservesPerSpoke);
        balances = _cashBalances(owner, positions, cashTokens, vaultAsset);
    }

    /// @dev Resolve each requested market exactly once, in request order, deriving both of its leg keys.
    ///      `getMarketInfo` reverts `MARKET_NOT_REGISTERED` for an unknown key and for a reserve key, so an
    ///      unregistered or mis-namespaced source fails the whole snapshot rather than being skipped.
    function _marketBindings(address[] calldata marketKeys) private view returns (MarketBinding[] memory markets) {
        markets = new MarketBinding[](marketKeys.length);
        uint256 count;
        for (uint256 i; i < marketKeys.length; ++i) {
            address marketKey = marketKeys[i];
            if (marketKey == address(0)) revert ZERO_ADDRESS();
            if (_hasMarket(markets, count, marketKey)) continue;

            (address spoke, uint256 supplyReserveId, uint256 borrowReserveId,,) = REGISTRY.getMarketInfo(marketKey);
            markets[count++] = MarketBinding({
                marketKey: marketKey,
                spoke: spoke,
                supplyReserveId: supplyReserveId,
                borrowReserveId: borrowReserveId,
                // SAME derivation source as `_borrowKeys`, deliberately: the dedup at `_ownerPositions`
                // compares keys produced here against keys produced there, and a divergence would
                // silently reproduce the per-market debt double count this whole function exists to
                // prevent. One library, one formula, both sides.
                supplyKey: AaveV4ReserveKey.computeReserveKey(spoke, supplyReserveId),
                debtKey: AaveV4ReserveKey.computeDebtKey(spoke, borrowReserveId)
            });
        }
        assembly ("memory-safe") {
            mstore(markets, count)
        }
    }

    /// @dev Expand the resolved markets into their accounting legs. EVERY leg is deduplicated against the
    ///      legs already collected, which is what collapses a borrow reserve shared by N markets into one
    ///      debt position and a collateral reserve shared by two markets into one supply position. Legs with
    ///      a zero balance are still returned, so a caller can verify coverage of both expected legs.
    function _ownerPositions(
        address owner,
        MarketBinding[] memory markets,
        address[] calldata configuredSpokes,
        uint256 maxReservesPerSpoke
    )
        private
        view
        returns (OwnerPosition[] memory positions)
    {
        address[] memory spokes = new address[](configuredSpokes.length + markets.length);
        uint256 spokeCount;
        for (uint256 i; i < configuredSpokes.length; ++i) {
            spokeCount = _appendAddress(spokes, spokeCount, configuredSpokes[i]);
        }
        OwnerPosition[] memory registered = new OwnerPosition[](markets.length * 2);
        uint256 registeredCount;
        for (uint256 i; i < markets.length; ++i) {
            spokeCount = _appendAddress(spokes, spokeCount, markets[i].spoke);
            if (!_hasPosition(registered, registeredCount, markets[i].supplyKey)) {
                registered[registeredCount++] = _ownerPosition(markets[i].supplyKey, owner);
            }
            if (!_hasPosition(registered, registeredCount, markets[i].debtKey)) {
                registered[registeredCount++] = _ownerPosition(markets[i].debtKey, owner);
            }
        }

        // ONE scan of the covered spokes yields both directions (SUP-21259): every reserve the owner has
        // debt on, and every reserve the owner still has collateral on that no requested market covers.
        (address[] memory debtKeys, address[] memory residualSupplyKeys) =
            _discoverKeys(owner, spokes, spokeCount, maxReservesPerSpoke, registered, registeredCount);

        positions = new OwnerPosition[](registeredCount + debtKeys.length + residualSupplyKeys.length);
        for (uint256 i; i < registeredCount; ++i) {
            positions[i] = registered[i];
        }
        uint256 positionCount = registeredCount;
        for (uint256 i; i < debtKeys.length; ++i) {
            if (!_hasPosition(positions, positionCount, debtKeys[i])) {
                positions[positionCount++] = _ownerPosition(debtKeys[i], owner);
            }
        }
        for (uint256 i; i < residualSupplyKeys.length; ++i) {
            if (!_hasPosition(positions, positionCount, residualSupplyKeys[i])) {
                positions[positionCount++] = _ownerPosition(residualSupplyKeys[i], owner);
            }
        }
        assembly ("memory-safe") {
            mstore(positions, positionCount)
        }
    }

    /// @dev ONE pass over every reserve of every covered spoke, collecting BOTH directions:
    ///      - `debtKeys`: reserves the owner has drawn debt on (unchanged behaviour);
    ///      - `residualSupplyKeys`: reserves the owner still has supplied collateral on that NONE of the
    ///        requested markets accounts for (SUP-21259).
    ///      WHY THE SECOND LIST EXISTS. Debt was always discovered here, while supply arrived only through
    ///      the requested market bindings. That asymmetry meant removing the last market naming a supply
    ///      reserve dropped its collateral from NAV while its debt kept being counted — PPS falls, or a
    ///      negative-NAV guard rejects a snapshot that is merely incomplete. Residual collateral is now
    ///      included when its SUPPLY leg is registered, and the whole call reverts `UNCOVERED_COLLATERAL`
    ///      when it is not: never silently omitted, and never resolved through an unregistered key.
    ///      COVERAGE BOUNDARY, stated so it is not over-read: this protects the snapshot only WHEN IT IS
    ///      REQUESTED. A consumer whose strategy no longer lists ANY Aave source requests no Aave snapshot
    ///      at all, so complete-removal coverage remains a manager/lifecycle guarantee, not something this
    ///      contract can enforce.
    ///      DETECTION COST: a pledged reserve is visible in `getUserReserveStatus`'s first return value,
    ///      but a plain IDLE supply reads `(false, false)` there — so catching that case needs
    ///      `getUserSuppliedAssets`, one extra staticcall per reserve per covered spoke. Both shapes count
    ///      as collateral for NAV, so the read is taken unconditionally rather than only for pledged
    ///      reserves.
    /// @param owner The account being snapshotted
    /// @param spokes Covered spokes (configured + the requested markets')
    /// @param spokeCount Live length of `spokes`
    /// @param maxReservesPerSpoke Caller's bound; exceeding it reverts rather than truncating
    /// @param covered Positions the requested markets already contributed
    /// @param coveredCount Live length of `covered`
    /// @return debtKeys Discovered DEBT leg keys
    /// @return residualSupplyKeys Discovered SUPPLY leg keys for collateral no market covered
    /// @dev Scan context, passed by reference so the per-reserve helper can append without widening any
    ///      caller's stack frame (this file builds without `via_ir`, and the flat version overflowed).
    struct ScanContext {
        address owner;
        OwnerPosition[] covered;
        uint256 coveredCount;
        address[] debtKeys;
        uint256 debtCount;
        address[] residualSupplyKeys;
        uint256 residualCount;
    }

    function _discoverKeys(
        address owner,
        address[] memory spokes,
        uint256 spokeCount,
        uint256 maxReservesPerSpoke,
        OwnerPosition[] memory covered,
        uint256 coveredCount
    )
        private
        view
        returns (address[] memory debtKeys, address[] memory residualSupplyKeys)
    {
        uint256[] memory counts = new uint256[](spokeCount);
        uint256 totalReserves;
        for (uint256 i; i < spokeCount; ++i) {
            counts[i] = IAaveV4Spoke(spokes[i]).getReserveCount();
            if (counts[i] > maxReservesPerSpoke) revert SNAPSHOT_RESERVE_LIMIT();
            totalReserves += counts[i];
        }

        // Provision keys for the scan; full position records are read later, only for what was found.
        ScanContext memory ctx = ScanContext({
            owner: owner,
            covered: covered,
            coveredCount: coveredCount,
            debtKeys: new address[](totalReserves),
            debtCount: 0,
            residualSupplyKeys: new address[](totalReserves),
            residualCount: 0
        });

        for (uint256 i; i < spokeCount; ++i) {
            for (uint256 reserveId; reserveId < counts[i]; ++reserveId) {
                _scanReserve(ctx, spokes[i], reserveId);
            }
        }

        debtKeys = ctx.debtKeys;
        residualSupplyKeys = ctx.residualSupplyKeys;
        uint256 debtCount = ctx.debtCount;
        uint256 residualCount = ctx.residualCount;
        assembly ("memory-safe") {
            mstore(debtKeys, debtCount)
            mstore(residualSupplyKeys, residualCount)
        }
    }

    /// @dev One reserve of one covered spoke, both directions.
    ///      DEBT: discovered exactly as before.
    ///      SUPPLY (SUP-21259): collateral no requested market accounts for is appended when its SUPPLY leg
    ///      is registered, and reverts `UNCOVERED_COLLATERAL` when it is not — never silently omitted, and
    ///      never resolved through an unregistered key. A pledged reserve is visible in
    ///      `getUserReserveStatus`'s first return value, but a plain IDLE supply reads `(false, false)`
    ///      there, so `getUserSuppliedAssets` is read unconditionally: both shapes are collateral for NAV.
    function _scanReserve(ScanContext memory ctx, address spoke, uint256 reserveId) private view {
        (, bool borrowing) = IAaveV4Spoke(spoke).getUserReserveStatus(reserveId, ctx.owner);
        if (borrowing) {
            ctx.debtKeys[ctx.debtCount++] = AaveV4ReserveKey.computeDebtKey(spoke, reserveId);
        }

        if (IAaveV4Spoke(spoke).getUserSuppliedAssets(reserveId, ctx.owner) == 0) return;
        address supplyKey = AaveV4ReserveKey.computeReserveKey(spoke, reserveId);
        if (_hasPosition(ctx.covered, ctx.coveredCount, supplyKey)) return;
        if (!REGISTRY.isRegistered(supplyKey)) revert UNCOVERED_COLLATERAL(spoke, reserveId);
        ctx.residualSupplyKeys[ctx.residualCount++] = supplyKey;
    }

    function _cashBalances(
        address owner,
        OwnerPosition[] memory positions,
        address[] calldata cashTokens,
        address vaultAsset
    )
        private
        view
        returns (WalletBalance[] memory balances)
    {
        balances = new WalletBalance[](cashTokens.length + positions.length);
        uint256 cashCount;
        // Registry decimals are authoritative for debt tokens. Reading configured cash second
        // avoids another decimals()/balanceOf() for the same token or for the vault underlying.
        for (uint256 i; i < positions.length; ++i) {
            OwnerPosition memory position = positions[i];
            if (position.side == uint8(AaveV4ReserveRegistryV2.Side.DEBT)) {
                cashCount = _appendCash(
                    balances, cashCount, owner, vaultAsset, position.underlying, position.underlyingDecimals
                );
            }
        }
        for (uint256 i; i < cashTokens.length; ++i) {
            address token = cashTokens[i];
            if (token == address(0)) revert ZERO_ADDRESS();
            if (token == vaultAsset || _hasCash(balances, cashCount, token)) continue;
            cashCount = _appendCash(balances, cashCount, owner, vaultAsset, token, IERC20Metadata(token).decimals());
        }
        assembly ("memory-safe") {
            mstore(balances, cashCount)
        }
    }

    function _ownerPosition(address key, address owner) private view returns (OwnerPosition memory position) {
        AaveV4ReserveRegistryV2.Side side;
        position.sourceKey = key;
        (position.spoke, position.reserveId, position.underlying, position.underlyingDecimals, side) =
            REGISTRY.getReserveInfo(key);
        position.side = uint8(side);
        position.symbol = _symbol(position.underlying);
        if (side == AaveV4ReserveRegistryV2.Side.SUPPLY) {
            position.assets = IAaveV4Spoke(position.spoke).getUserSuppliedAssets(position.reserveId, owner);
        } else if (side == AaveV4ReserveRegistryV2.Side.DEBT) {
            (uint256 drawn, uint256 premium) = IAaveV4Spoke(position.spoke).getUserDebt(position.reserveId, owner);
            position.assets = drawn + premium;
        } else {
            revert UNHANDLED_SIDE();
        }
    }

    /// @dev Symbol is optional display metadata and must not make accounting unavailable.
    function _symbol(address token) private view returns (string memory) {
        (bool success, bytes memory result) =
            token.staticcall{ gas: 30_000 }(abi.encodeWithSelector(IERC20Metadata.symbol.selector));
        if (!success || result.length < 64) return "";
        uint256 offset;
        uint256 length;
        assembly ("memory-safe") {
            offset := mload(add(result, 32))
            length := mload(add(result, 64))
        }
        if (offset != 32 || length > 256 || result.length < 64 + ((length + 31) / 32) * 32) return "";
        return abi.decode(result, (string));
    }

    function _appendAddress(address[] memory values, uint256 count, address value) private pure returns (uint256) {
        if (value == address(0)) revert ZERO_ADDRESS();
        for (uint256 i; i < count; ++i) {
            if (values[i] == value) return count;
        }
        values[count] = value;
        return count + 1;
    }

    /// @dev Whether a market key is already among the collected bindings
    function _hasMarket(MarketBinding[] memory markets, uint256 count, address marketKey) private pure returns (bool) {
        for (uint256 i; i < count; ++i) {
            if (markets[i].marketKey == marketKey) return true;
        }
        return false;
    }

    function _hasPosition(OwnerPosition[] memory positions, uint256 count, address key) private pure returns (bool) {
        for (uint256 i; i < count; ++i) {
            if (positions[i].sourceKey == key) return true;
        }
        return false;
    }

    function _hasCash(WalletBalance[] memory balances, uint256 count, address token) private pure returns (bool) {
        for (uint256 i; i < count; ++i) {
            if (balances[i].token == token) return true;
        }
        return false;
    }

    function _appendCash(
        WalletBalance[] memory balances,
        uint256 count,
        address owner,
        address vaultAsset,
        address token,
        uint8 tokenDecimals
    )
        private
        view
        returns (uint256)
    {
        if (token == vaultAsset) return count;
        for (uint256 i; i < count; ++i) {
            if (balances[i].token == token) {
                if (balances[i].decimals != tokenDecimals) revert SNAPSHOT_DECIMALS_MISMATCH();
                return count;
            }
        }
        balances[count] = WalletBalance(token, tokenDecimals, IERC20Metadata(token).balanceOf(owner));
        return count + 1;
    }
}
