// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// aave-v4 vendor
import { IAaveV4Spoke } from "../../vendor/aave-v4/IAaveV4Spoke.sol";

// superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { AaveV4ReserveRegistry } from "./AaveV4ReserveRegistry.sol";

/// @title AaveV4SupplyYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Aave V4 supply positions (collateral/deposit side)
/// @dev Uses identity mapping (PPS = 1:1) over getUserSuppliedAssets(), which returns the supplied
///      balance directly in asset units. The yieldSourceAddress parameter is a pseudo-address reserve
///      key resolved through the AaveV4ReserveRegistry to a (spoke, reserveId) pair — Aave V4 plain
///      spokes mint no aToken (positions are spoke-internal shares), so no protocol-provided address
///      handle exists. Spoke views virtually accrue supply interest via the hub share price — no
///      manual accrual logic needed.
///
///      WHY IDENTITY (asset units) AND NOT A SHARES-BASED PPS ORACLE:
///      Every Superform loan hook measures ERC20 wallet-balance deltas in ASSET units (V4 has no
///      transferable share token to delta against), and BaseLedger._takeSnapshot treats inflow
///      amounts as literal shares priced by this oracle's PPS. Identity PPS (shares ≡ assets) is the
///      only mapping unit-consistent with what hooks can report. A true shares-PPS oracle (over
///      getUserSuppliedShares / hub.previewRemoveByShares) would require hooks that read spoke share
///      state — a different settle architecture and explicit future work.
///
///      IMPORTANT — Fee configuration (standalone phase):
///      This oracle MUST NOT be configured with feePercent > 0 in SuperLedgerConfiguration until
///      real hook-to-ledger wiring exists. No loan hook currently drives updateAccounting, so no
///      cost-basis snapshot is ever taken for supply positions; the inherited fee view would then
///      treat the ENTIRE principal as profit and inflate the quoted output. getAssetOutputWithFees
///      is therefore overridden to bypass fee math entirely (mirroring AaveV4DebtOracle). NOTE:
///      the override only protects the view path — BaseLedger._processOutflow() computes fees
///      directly from config.feePercent and is NOT guarded on-chain; correct behavior depends on
///      the operational invariant that this oracle's yieldSourceOracleId is configured with
///      feePercent = 0 (or not registered at all).
///      Once accounting hooks exist and inflows snapshot cost basis, the ledger path charges fees
///      on measured asset-delta profit only (yield, never principal — identity PPS makes a plain
///      principal round trip read zero profit); re-enabling the fee view then requires removing
///      the override in a new oracle version, not a config change.
///
///      STANDALONE ORACLE — accounting-wiring scope:
///      No loan hook currently drives this oracle through SuperLedger: every loan hook is
///      HookType.NONACCOUNTING, so SuperExecutorBase never calls updateAccounting for loan positions
///      (identical to the deployed MorphoBlueYieldSourceOracle, which is equally hook-unwired). This
///      oracle serves monitoring, periphery, and off-chain accounting consumers.
///
///      Semantic notes for downstream consumers:
///      - getBalanceOfOwner() returns supplied balance in asset units (via getUserSuppliedAssets),
///        not a share balance. The identity PPS mapping makes the numeric result correct regardless
///        of interpretation.
///      - getTVL() returns the reserve-level total supplied assets (getReserveSuppliedAssets).
///      - Values are denominated in the reserve's underlying asset; cross-asset conversion is
///        external — no price feeds exist in this contract.
///      - Aave V4 rounds supply conversions DOWN at source (toAddedAssetsDown): the supplier can
///        claim at most this much. Values are passed through unmodified — no double-rounding.
///      - Direct spoke withdrawals (self-calls are always allowed by onlyPositionManager) bypass any
///        Superform accounting and desync cached cost basis — the documented SECURITY.md trade-off
///        for withdrawing directly from a yield source.
///
///      Every registry-resolving view (decimals, getPricePerShare, getBalanceOfOwner,
///      getTVLByOwnerOfShares, getTVL) reverts with the registry's RESERVE_NOT_REGISTERED for
///      unregistered keys — never a zero return. The pure identity converters (getShareOutput,
///      getWithdrawalShareOutput, getAssetOutput) do NOT consult the registry and return the
///      input amount for any key; identity is the invariant-correct answer independent of
///      registration, so they cannot be used to probe registration status. Batch methods in
///      AbstractYieldSourceOracle isolate reverts via try/catch in getTVLByOwnerOfSharesMultiple
///      only; getPricePerShareMultiple/getTVLMultiple loop without isolation (inherited behavior
///      — one reverting key aborts those batch calls).
contract AaveV4SupplyYieldSourceOracle is AbstractYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is supplied where one is not permitted
    error ZERO_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                               STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The registry resolving pseudo-address reserve keys to (spoke, reserveId) pairs
    AaveV4ReserveRegistry public immutable REGISTRY;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the AaveV4SupplyYieldSourceOracle bound to a ledger configuration and reserve registry
    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract; must be non-zero
    ///        (a zero/codeless value would silently disable the inherited fee path forever)
    /// @param registry_ Address of the AaveV4ReserveRegistry; must be non-zero
    constructor(
        address superLedgerConfiguration_,
        address registry_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        if (superLedgerConfiguration_ == address(0) || registry_ == address(0)) revert ZERO_ADDRESS();
        REGISTRY = AaveV4ReserveRegistry(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Registry-stored underlying decimals, bound at registration from the spoke's Reserve struct
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        (,,, uint8 decimals_) = REGISTRY.getReserveInfo(yieldSourceAddress);
        return decimals_;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns 10 ** decimals (always 1:1 identity, never zero). Reverts via checked arithmetic if
    ///      decimals >= 78, which cannot occur with real ERC-20 tokens (max 18 in practice).
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        (,,, uint8 decimals_) = REGISTRY.getReserveInfo(yieldSourceAddress);
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
    /// @dev Overridden to bypass fee computation entirely for the standalone phase. No loan hook
    ///      currently drives SuperLedger.updateAccounting, so supply positions never take
    ///      cost-basis snapshots and the base implementation's previewFees() would treat the
    ///      entire principal as "profit", inflating the quoted output. NOTE: this override only
    ///      protects callers of this view function — BaseLedger._processOutflow() computes fees
    ///      directly from config.feePercent and does not route through here. The oracle must
    ///      still be configured with feePercent = 0 in SuperLedgerConfiguration (see
    ///      contract-level docs).
    function getAssetOutputWithFees(
        bytes32,
        address yieldSourceAddress,
        address assetOut,
        address,
        uint256 usedShares
    )
        external
        view
        override
        returns (uint256)
    {
        return getAssetOutput(yieldSourceAddress, assetOut, usedShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns spoke.getUserSuppliedAssets(reserveId, owner) — supplied balance in asset units,
    ///      not shares. The exact read BaseAaveV4LoanHookV2._suppliedAssets performs, so hook-side and
    ///      oracle-side supply figures can never disagree within a transaction.
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        (address spoke, uint256 reserveId,,) = REGISTRY.getReserveInfo(yieldSourceAddress);
        return IAaveV4Spoke(spoke).getUserSuppliedAssets(reserveId, ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Identical to getBalanceOfOwner since PPS = 1:1.
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
    /// @dev Returns the reserve-level total supplied assets via spoke.getReserveSuppliedAssets
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        (address spoke, uint256 reserveId,,) = REGISTRY.getReserveInfo(yieldSourceAddress);
        return IAaveV4Spoke(spoke).getReserveSuppliedAssets(reserveId);
    }
}
