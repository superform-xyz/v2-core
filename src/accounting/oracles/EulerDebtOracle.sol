// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// euler vendor
import { IEVaultDebt } from "../../vendor/euler/IEVaultDebt.sol";

// superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title EulerDebtOracle
/// @author Superform Labs
/// @notice Oracle for Euler V2 debt positions (borrow side)
/// @dev Uses identity mapping (PPS = 1:1) since Euler V2's debtOf() returns accrued debt directly in asset units.
///      The yieldSourceAddress parameter is the controller EVault (the vault the account borrowed from).
///      Interest auto-accrues in debtOf() and totalBorrows() — no manual accrual logic needed.
///
///      IMPORTANT — Fee configuration:
///      This oracle MUST NOT be configured with feePercent > 0 in SuperLedgerConfiguration. The inherited
///      getAssetOutputWithFees() computes fees via previewFees() which relies on cost basis snapshots. Debt positions
///      do not take snapshots, so the entire debt balance would be treated as "profit" and fees applied incorrectly.
///      This applies to BOTH fee paths: the inherited getAssetOutputWithFees() view AND the ledger accounting path
///      (BaseLedger._processOutflow() computes fees directly from config.feePercent via _calculateFees()). Neither
///      is guarded on-chain here; correct behavior depends on the operational invariant that this oracle's
///      yieldSourceOracleId is configured with feePercent = 0 (or not registered in SuperLedgerConfiguration at all).
///
///      Semantic notes for downstream consumers:
///      - getBalanceOfOwner() returns accrued debt in asset units (via debtOf), not a share balance. The identity
///        PPS mapping makes the numeric result correct regardless of interpretation.
///      - getTVL() returns totalBorrows() (aggregate outstanding debt), not totalAssets().
///      - When used alongside ERC4626YieldSourceOracle for the supply leg of a leveraged position, the two oracles
///        return values in different asset denominations (e.g. WETH collateral vs USDC debt). Cross-asset conversion
///        must be handled externally.
///      - debtOf() rounds UP (conservative — borrower owes at least this much).
///
///      All functions revert with an empty revert if yieldSourceAddress is not a deployed contract (including
///      address(0)). Batch methods in AbstractYieldSourceOracle isolate these reverts via try/catch.
contract EulerDebtOracle is AbstractYieldSourceOracle {
    constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        return IEVaultDebt(yieldSourceAddress).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns 10 ** decimals (always 1:1 identity). Reverts via checked arithmetic if decimals >= 78,
    ///      which cannot occur with real ERC-20 tokens (max 18 in practice).
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        return 10 ** uint256(IEVaultDebt(yieldSourceAddress).decimals());
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
    /// @dev Returns IEVaultDebt(yieldSourceAddress).debtOf(ownerOfShares) — accrued debt in asset units, not shares.
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        return IEVaultDebt(yieldSourceAddress).debtOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns IEVaultDebt(yieldSourceAddress).debtOf(ownerOfShares). Identical to getBalanceOfOwner since PPS = 1:1.
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        return IEVaultDebt(yieldSourceAddress).debtOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns IEVaultDebt(yieldSourceAddress).totalBorrows() — aggregate outstanding debt, not totalAssets().
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return IEVaultDebt(yieldSourceAddress).totalBorrows();
    }
}
