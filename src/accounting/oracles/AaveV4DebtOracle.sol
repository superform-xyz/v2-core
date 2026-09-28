// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// aave-v4 vendor
import { IAaveV4Spoke } from "../../vendor/aave-v4/IAaveV4Spoke.sol";

// superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { AaveV4ReserveRegistry } from "./AaveV4ReserveRegistry.sol";

/// @title AaveV4DebtOracle
/// @author Superform Labs
/// @notice Oracle for Aave V4 debt positions (borrow side)
/// @dev Uses identity mapping (PPS = 1:1) since Aave V4's getUserDebt() returns accrued debt directly in
///      asset units (drawn + premium). The yieldSourceAddress parameter is a pseudo-address reserve key
///      resolved through the AaveV4ReserveRegistry to a (spoke, reserveId) pair — Aave V4 mints no
///      debtToken, so no protocol-provided address handle exists. Spoke views virtually accrue interest
///      (drawn via the live hub index, premium riding the same index) — no manual accrual logic needed.
///
///      STANDALONE ORACLE — accounting-wiring scope:
///      No loan hook currently drives this oracle through SuperLedger: every loan hook is
///      HookType.NONACCOUNTING, so SuperExecutorBase never calls updateAccounting for loan positions
///      (identical to the deployed EulerDebtOracle / MorphoBlueDebtOracle, which are equally
///      hook-unwired). This oracle serves monitoring, periphery, and off-chain accounting consumers;
///      live fee-pipeline wiring is future work.
///
///      IMPORTANT — Fee configuration:
///      This oracle MUST NOT be configured with feePercent > 0 in SuperLedgerConfiguration. Debt
///      positions do not take cost-basis snapshots, so the entire debt balance would be treated as
///      "profit" and fees applied incorrectly. This applies to BOTH fee paths: the view path
///      getAssetOutputWithFees() (overridden here to bypass fees — see below) AND the ledger accounting
///      path (BaseLedger._processOutflow() computes fees directly from config.feePercent via
///      _calculateFees() and does not route through this contract). The ledger path is NOT guarded
///      on-chain; correct behavior depends on the operational invariant that this oracle's
///      yieldSourceOracleId is configured with feePercent = 0 (or not registered in
///      SuperLedgerConfiguration at all).
///
///      Semantic notes for downstream consumers:
///      - getBalanceOfOwner() returns accrued debt in asset units (drawn + premium), not a share
///        balance. Aave V4's internal drawnShares/premiumShares are not a single meaningful unit; the
///        identity PPS mapping makes the numeric result correct regardless of interpretation.
///      - getTVL() returns the reserve-level aggregate outstanding debt (drawn + premium via
///        getReserveDebt) — the totalBorrows() analog — not total supplied assets.
///      - Values are denominated in the reserve's underlying (borrow) asset. When used alongside
///        AaveV4SupplyYieldSourceOracle for the collateral leg of a leveraged position, the two oracles
///        return values in different asset denominations. Cross-asset conversion must be handled
///        externally — no price feeds exist in this contract.
///      - Aave V4 rounds debt UP at source (drawn via rayMulUp, premium via fromRayUp): the borrower
///        owes at least this much. Values are passed through unmodified — no double-rounding.
///      - Debt keeps accruing while a reserve is paused or frozen (flags gate mutations, not accrual).
///
///      Every registry-resolving view (decimals, getPricePerShare, getBalanceOfOwner,
///      getTVLByOwnerOfShares, getTVL) reverts with the registry's RESERVE_NOT_REGISTERED for
///      unregistered keys — never a zero return. The pure identity converters (getShareOutput,
///      getWithdrawalShareOutput, getAssetOutput, and the fee-bypass getAssetOutputWithFees) do
///      NOT consult the registry and return the input amount for any key; identity is the
///      invariant-correct answer independent of registration, so they cannot be used to probe
///      registration status. Batch methods in AbstractYieldSourceOracle isolate reverts via
///      try/catch in getTVLByOwnerOfSharesMultiple only; getPricePerShareMultiple/getTVLMultiple
///      loop without isolation (inherited behavior — one reverting key aborts those batch calls).
///
///      DEBT MUTATION WITHOUT OWNER ACTION: the premium component of a user's debt is re-rated by
///      updateUserRiskPremium — self-callable and AccessManager-authorized on the deployed spoke
///      (fork-verified; the pre-launch Sherlock-contest code was permissionless, hardened before
///      deployment) — and implicitly whenever the position is touched, including by approved
///      position managers. Combined with continuous index accrual, consumers must not assume the
///      reported debt is constant absent position-owner actions — it can move between blocks.
contract AaveV4DebtOracle is AbstractYieldSourceOracle {
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

    /// @notice Deploys the AaveV4DebtOracle bound to a ledger configuration and reserve registry
    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract; must be non-zero
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
    /// @dev Overridden to bypass fee computation entirely. Debt positions do not take cost-basis
    ///      snapshots, so the base implementation's previewFees() would treat the entire debt
    ///      balance as "profit" and apply fees incorrectly. NOTE: this override only protects
    ///      callers of this view function — BaseLedger._processOutflow() computes fees directly
    ///      from config.feePercent and does not route through here. The oracle must still be
    ///      configured with feePercent = 0 in SuperLedgerConfiguration (see contract-level docs).
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
    /// @dev Returns drawn + premium debt from spoke.getUserDebt — accrued debt in asset units, not
    ///      shares. The exact read BaseAaveV4LoanHookV2._totalDebt performs, so hook-resolved repay
    ///      amounts and oracle-read debt can never disagree within a transaction.
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
        (uint256 drawnDebt, uint256 premiumDebt) = IAaveV4Spoke(spoke).getUserDebt(reserveId, ownerOfShares);
        return drawnDebt + premiumDebt;
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
    /// @dev Returns the reserve-level aggregate outstanding debt (drawn + premium via
    ///      spoke.getReserveDebt) — the totalBorrows() analog, not total supplied assets.
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        (address spoke, uint256 reserveId,,) = REGISTRY.getReserveInfo(yieldSourceAddress);
        (uint256 drawnDebt, uint256 premiumDebt) = IAaveV4Spoke(spoke).getReserveDebt(reserveId);
        return drawnDebt + premiumDebt;
    }
}
