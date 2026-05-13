// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IMachine } from "../../vendor/vaults/deth/IMachine.sol";
import { IDETHAsyncRedeemer } from "../../vendor/vaults/deth/IDETHAsyncRedeemer.sol";

/// @title DETHYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Dialectic's DETH/Machine vault with async redemption support
/// @dev Receives AsyncRedeemer as yieldSourceAddress, discovers Machine dynamically via .machine().
///      Pricing calls route to Machine's convertToAssets/convertToShares (not preview functions).
///      TVL includes both held DETH value and pending async redemption value.
///      All address resolution is dynamic — a single oracle instance can serve multiple AsyncRedeemers.
///
///      Redemption routing:
///      The SuperVaultStrategy does not implement onERC721Received, so DETH async redemptions are
///      routed through a dedicated FOUNDATION address that can receive ERC-721 NFT receipts.
///      The oracle is configured with this FOUNDATION address and includes its pending NFTs in the
///      strategy's TVL calculation. This prevents a temporary PPS drop during the async redeem window.
///      NOTE: This design assumes a single strategy uses the FOUNDATION for DETH redemptions.
///      If multiple strategies share the same FOUNDATION, all pending NFTs would be attributed to
///      whichever strategy's TVL is queried — do NOT use with multiple strategies.
///
///      Security assumptions:
///      - Machine's convertToAssets() uses internal accounting (not external AMM prices)
///      - AsyncRedeemer pending requests are scanned from lastFinalizedRequestId+1 to nextRequestId-1
///      - MAX_PENDING_REQUESTS bounds iteration to prevent DoS via unbounded loops
///      - FOUNDATION is trusted and only used by a single strategy for DETH redemptions
contract DETHYieldSourceOracle is AbstractYieldSourceOracle {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is provided for a required parameter
    error ZERO_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum number of pending requests to scan for TVL calculation
    /// @dev Bounds iteration to prevent DoS. If exceeded, only the first MAX_PENDING_REQUESTS are counted.
    ///      At 200 requests, the loop makes up to 400 external calls (ownerOf + getShares).
    ///      When FOUNDATION is set, both owner and FOUNDATION are checked in a single pass.
    uint256 public constant MAX_PENDING_REQUESTS = 200;

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The FOUNDATION address used to route DETH async redemptions
    /// @dev SuperVaultStrategy lacks onERC721Received, so redemption NFTs are minted to this address.
    ///      The oracle counts pending NFTs owned by FOUNDATION as part of the queried strategy's TVL.
    ///      WARNING: Only one strategy should use this FOUNDATION. Multiple strategies sharing the same
    ///      FOUNDATION would cause incorrect TVL attribution.
    address public immutable FOUNDATION;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructs the DETH oracle
    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract
    /// @param foundation_ Address that routes DETH redemptions on behalf of the strategy
    constructor(
        address superLedgerConfiguration_,
        address foundation_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        if (foundation_ == address(0)) revert ZERO_ADDRESS();
        FOUNDATION = foundation_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns the decimals of the DETH share token
    /// @dev Discovery chain: yieldSourceAddress (AsyncRedeemer) → machine() → shareToken() → decimals()
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        (, address shareToken) = _resolve(yieldSourceAddress);
        return IERC20Metadata(shareToken).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns expected DETH shares from depositing WETH assets
    /// @dev Routes to Machine.convertToShares() (not previewDeposit, which may revert on async vaults)
    function getShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        if (assetsIn == 0) return 0;
        address machineAddr = IDETHAsyncRedeemer(yieldSourceAddress).machine();
        return IMachine(machineAddr).convertToShares(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns DETH shares needed to withdraw a specific amount of WETH assets
    /// @dev Uses manual mulDiv inverse with Ceil rounding to favor the vault.
    ///      Does not use previewWithdraw/previewRedeem as Machine uses async redemption.
    function getWithdrawalShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        if (assetsIn == 0) return 0;

        (address machineAddr, address shareToken) = _resolve(yieldSourceAddress);
        uint256 oneShare = 10 ** IERC20Metadata(shareToken).decimals();
        uint256 assetsPerShare = IMachine(machineAddr).convertToAssets(oneShare);
        if (assetsPerShare == 0) return 0;

        return Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns WETH assets redeemable for a given amount of DETH shares
    /// @dev Routes to Machine.convertToAssets() (not previewRedeem)
    function getAssetOutput(
        address yieldSourceAddress,
        address,
        uint256 sharesIn
    )
        public
        view
        override
        returns (uint256)
    {
        if (sharesIn == 0) return 0;
        address machineAddr = IDETHAsyncRedeemer(yieldSourceAddress).machine();
        return IMachine(machineAddr).convertToAssets(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns price per DETH share in WETH terms
    /// @dev Converts one full share (10^decimals) to assets via Machine
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        (address machineAddr, address shareToken) = _resolve(yieldSourceAddress);
        uint256 oneShare = 10 ** IERC20Metadata(shareToken).decimals();
        return IMachine(machineAddr).convertToAssets(oneShare);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns DETH share balance of a given owner
    /// @dev Returns only held DETH shares, NOT including pending redemptions
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        (, address shareToken) = _resolve(yieldSourceAddress);
        return IERC20(shareToken).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns total value locked (in WETH) for a given share owner
    /// @dev Includes both held DETH value and pending async redemption value.
    ///      Pending redemptions are tracked by scanning NFT requests from
    ///      (lastFinalizedRequestId+1) to (nextRequestId-1), checking ownerOf() for each.
    ///      Also includes pending NFTs owned by FOUNDATION, since the strategy routes redemptions
    ///      through FOUNDATION to work around the missing onERC721Received on SuperVaultStrategy.
    ///      Uses try/catch for pending redemption scanning (R2 graceful degradation).
    ///      Iteration is bounded by MAX_PENDING_REQUESTS to prevent DoS.
    ///      Both owner and FOUNDATION pending NFTs are scanned in a single loop pass for gas efficiency.
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        (address machineAddr, address shareToken) = _resolve(yieldSourceAddress);

        // Component 1: Value of held DETH shares (R1 - hard revert on failure)
        uint256 heldShares = IERC20(shareToken).balanceOf(ownerOfShares);
        uint256 heldValue = heldShares > 0 ? IMachine(machineAddr).convertToAssets(heldShares) : 0;

        // Component 2+3: Value of pending async redemptions for both owner and FOUNDATION
        // Single-pass loop checks both addresses to avoid redundant external calls
        address foundation = FOUNDATION;
        address secondAddr = (foundation != ownerOfShares) ? foundation : address(0);
        uint256 pendingValue = _getPendingRedemptionValueForTwo(yieldSourceAddress, machineAddr, ownerOfShares, secondAddr);

        return heldValue + pendingValue;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @notice Returns total assets managed by Machine vault
    /// @dev Uses Machine.lastTotalAum() since Machine does not expose totalAssets().
    ///      WARNING: lastTotalAum() is a cached snapshot updated only when Machine's accounting refreshes.
    ///      Between updates, this value may not reflect real-time yield/loss events in the vault.
    ///      Consumers should be aware of potential staleness when using this for solvency checks.
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        address machineAddr = IDETHAsyncRedeemer(yieldSourceAddress).machine();
        return IMachine(machineAddr).lastTotalAum();
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Resolves the Machine and share token addresses from an AsyncRedeemer
    /// @dev Discovery chain: yieldSourceAddress (AsyncRedeemer) → machine() → shareToken()
    /// @param yieldSourceAddress The AsyncRedeemer contract address
    /// @return machineAddr The Machine vault address
    /// @return shareToken The DETH share token address
    function _resolve(address yieldSourceAddress) internal view returns (address machineAddr, address shareToken) {
        machineAddr = IDETHAsyncRedeemer(yieldSourceAddress).machine();
        shareToken = IMachine(machineAddr).shareToken();
    }

    /// @notice Calculates the total value of pending redemption requests for up to two addresses in a single pass
    /// @dev Scans NFT request IDs from (lastFinalizedRequestId+1) to (nextRequestId-1).
    ///      For each request, checks ownerOf() against both primaryOwner and secondaryOwner,
    ///      accumulating getShares() into a single total converted to assets at the end.
    ///      Uses try/catch so that burned/claimed NFTs are silently skipped.
    ///      Bounded by MAX_PENDING_REQUESTS to prevent unbounded iteration.
    ///      Single-pass design avoids redundant lastFinalizedRequestId/nextRequestId fetches
    ///      and halves the ownerOf() calls compared to two separate scans.
    /// @param asyncRedeemer The AsyncRedeemer contract address (yieldSourceAddress)
    /// @param machineAddr The Machine vault address (pre-resolved for gas efficiency)
    /// @param primaryOwner The primary address to check pending redemptions for
    /// @param secondaryOwner Optional second address (e.g. FOUNDATION). Set to address(0) to skip.
    /// @return totalPendingValue The total WETH value of pending redemptions for both owners combined
    function _getPendingRedemptionValueForTwo(
        address asyncRedeemer,
        address machineAddr,
        address primaryOwner,
        address secondaryOwner
    )
        internal
        view
        returns (uint256 totalPendingValue)
    {
        IDETHAsyncRedeemer redeemer = IDETHAsyncRedeemer(asyncRedeemer);

        uint256 lastFinalized;
        uint256 nextId;
        try redeemer.lastFinalizedRequestId() returns (uint256 val) {
            lastFinalized = val;
        } catch {
            return 0;
        }
        try redeemer.nextRequestId() returns (uint256 val) {
            nextId = val;
        } catch {
            return 0;
        }

        // No pending requests
        if (nextId <= lastFinalized + 1) return 0;

        bool checkSecondary = secondaryOwner != address(0);
        uint256 pendingCount = nextId - lastFinalized - 1;
        uint256 scanLimit = pendingCount > MAX_PENDING_REQUESTS ? MAX_PENDING_REQUESTS : pendingCount;
        uint256 totalPendingShares;

        for (uint256 i; i < scanLimit; ++i) {
            uint256 requestId = lastFinalized + 1 + i;

            // Check if this request belongs to either owner
            try IERC721(asyncRedeemer).ownerOf(requestId) returns (address nftOwner) {
                if (nftOwner == primaryOwner || (checkSecondary && nftOwner == secondaryOwner)) {
                    // Get shares locked in this request
                    try redeemer.getShares(requestId) returns (uint256 shares) {
                        totalPendingShares += shares;
                    } catch {
                        // Skip if getShares reverts (shouldn't happen for valid NFTs)
                    }
                }
            } catch {
                // Skip burned/claimed NFTs
            }
        }

        // Convert accumulated pending shares to asset value (R2 - graceful degradation)
        if (totalPendingShares > 0) {
            try IMachine(machineAddr).convertToAssets(totalPendingShares) returns (uint256 value) {
                totalPendingValue = value;
            } catch {
                // Graceful degradation: pending value treated as 0
            }
        }
    }
}
