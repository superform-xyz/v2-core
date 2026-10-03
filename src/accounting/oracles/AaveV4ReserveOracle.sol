// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// aave-v4 vendor
import { IAaveV4Spoke } from "../../vendor/aave-v4/IAaveV4Spoke.sol";

// superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { AaveV4ReserveRegistryV2 } from "./AaveV4ReserveRegistryV2.sol";

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
contract AaveV4ReserveOracle is AbstractYieldSourceOracle {
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
        (,,, uint8 decimals_,) = REGISTRY.getReserveInfo(yieldSourceAddress);
        return decimals_;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns 10 ** decimals (always 1:1 identity, never zero) on both legs. Reverts via checked
    ///      arithmetic if decimals >= 78, which cannot occur with real ERC-20 tokens (max 18 in practice).
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        (,,, uint8 decimals_,) = REGISTRY.getReserveInfo(yieldSourceAddress);
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
        (address spoke, uint256 reserveId,,, AaveV4ReserveRegistryV2.Side side) =
            REGISTRY.getReserveInfo(yieldSourceAddress);

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
        (address spoke, uint256 reserveId,,, AaveV4ReserveRegistryV2.Side side) =
            REGISTRY.getReserveInfo(yieldSourceAddress);

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
    /// @param yieldSourceAddress The reserve key to classify
    /// @return side SUPPLY or DEBT
    function sideOf(address yieldSourceAddress) external view returns (AaveV4ReserveRegistryV2.Side side) {
        (,,,, side) = REGISTRY.getReserveInfo(yieldSourceAddress);
    }
}
