// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title ERC20YieldSourceOracle
/// @author Superform Labs
/// @notice Identity-PPS yield-source oracle for plain ERC20 tokens held directly by strategies
/// @dev Makes plain ERC20 tokens (e.g. tokenized stocks such as NVDAb/TSLAb on BSC) whitelistable
///      as SuperVault yield sources: the token is simultaneously the "vault", the "share", and the
///      "asset" (identity semantics — 1 share == 1 asset == 1 token unit). All cross-asset pricing
///      happens OFF-CHAIN: the validator network keys on this oracle's address (stored per source
///      by SuperVaultStrategy) and prices getBalanceOfOwner(token, strategy) against external
///      price sources. One deployed instance serves every ERC20; no registry, no storage, no admin.
///
///      IMPORTANT — Fee configuration invariant. This oracle MUST NOT be configured with
///      feePercent > 0 in SuperLedgerConfiguration. No hook ever snapshots cost basis for plain
///      ERC20 holdings, so any configured fee would treat the ENTIRE balance as profit. This
///      applies to BOTH fee paths: the view path getAssetOutputWithFees() (overridden here to
///      bypass fees) AND the ledger accounting path (BaseLedger._processOutflow() computes fees
///      directly from config.feePercent and does not route through this contract). The ledger
///      path is NOT guarded on-chain; correct behavior depends on the operational invariant that
///      this oracle's yieldSourceOracleId is configured with feePercent = 0 (or not registered in
///      SuperLedgerConfiguration at all). Registering this oracle with FlatFeeLedger is
///      categorically forbidden: FlatFeeLedger hardcodes cost basis to zero and would fee the
///      full principal on every outflow. Re-enabling fee capability requires a NEW oracle
///      version, never a configuration change.
///
///      getTVL(token) returns the token's GLOBAL totalSupply() — all holders worldwide, not
///      Superform-held value. It exists for monitoring parity with the oracle family and MUST
///      NOT be used as a pricing input; pricing consumers use getBalanceOfOwner(token, owner).
///
///      Token-behavior scope: rebasing and fee-on-transfer tokens are OUT of scope (documented,
///      not engineered around) — a rebase (including stock splits implemented as balance
///      redenomination) silently shifts reported balances between off-chain price snapshots.
///      Whoever whitelists a token owns its due diligence: single canonical entry point (a
///      double-entry token whitelisted under both addresses would be double-counted by off-chain
///      pricing), corporate-action convention pinned per token and confirmed with the issuer in
///      writing (dividend/split handling differs per issuer family: balance rebase vs fixed
///      balances + total-return price multiplier vs airdrops — the price feed used off-chain
///      MUST match the token's convention), upgrade surface understood (tokens behind a shared
///      upgradeable beacon can have balanceOf/decimals semantics for the WHOLE token family
///      swapped in one transaction — monitor the beacon implementation, not just the token),
///      blocklist/pause semantics understood (balance reads stay live while assets may be
///      frozen — reported value is not necessarily realizable), donations understood (anyone can
///      transfer tokens directly to the tracked owner; getBalanceOfOwner cannot distinguish
///      donated from deposited value, so off-chain pricing should reconcile balance deltas
///      against executed flows), and decimals <= 18.
///
///      Revert surface: decimals() and getPricePerShare() revert for addresses that do not
///      implement ERC20 decimals() — this probe is the only on-chain validation and the natural
///      gate against whitelisting non-tokens. getBalanceOfOwner/getTVLByOwnerOfShares/getTVL
///      revert if the target lacks the corresponding read. The pure identity converters answer
///      for ANY address and cannot be used to probe token validity.
///
///      Batch methods in AbstractYieldSourceOracle isolate reverts via try/catch in
///      getTVLByOwnerOfSharesMultiple only; getPricePerShareMultiple/getTVLMultiple loop without
///      isolation (inherited behavior — one reverting entry aborts those batch calls). Duplicate
///      entries are returned duplicated; deduplication is the caller's responsibility.
contract ERC20YieldSourceOracle is AbstractYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the constructor receives a zero address
    error ZERO_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the identity oracle bound to the SuperLedgerConfiguration
    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract; must be
    ///        non-zero (retained for interface parity with a future fee-capable oracle version;
    ///        this oracle's getAssetOutputWithFees intentionally bypasses the inherited fee path)
    constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) {
        if (superLedgerConfiguration_ == address(0)) revert ZERO_ADDRESS();
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        return IERC20Metadata(yieldSourceAddress).decimals();
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
    /// @dev Always 1:1 identity in token decimals, never zero. Reverts via checked arithmetic if
    ///      decimals >= 78, which cannot occur with real ERC-20 tokens (max 18 in practice)
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        return 10 ** uint256(IERC20Metadata(yieldSourceAddress).decimals());
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        return IERC20(yieldSourceAddress).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Identical to getBalanceOfOwner since PPS = 1:1
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
    /// @dev GLOBAL token totalSupply — all holders worldwide, not Superform-held value.
    ///      Monitoring-only; never a pricing input (pricing consumers must use getBalanceOfOwner)
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return IERC20(yieldSourceAddress).totalSupply();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Overridden to bypass fee computation entirely. Plain ERC20 holdings never take
    ///      cost-basis snapshots, so the inherited fee view would treat the entire balance as
    ///      profit and inflate quoted outputs. NOTE: this override only protects callers of this
    ///      view function — BaseLedger._processOutflow() computes fees directly from
    ///      config.feePercent and does not route through here. The oracle must still be
    ///      configured with feePercent = 0 in SuperLedgerConfiguration (see contract-level docs)
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
}
