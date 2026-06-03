# SpectraMetaVaultOracle Technical Specification

## Overview

A custom yield source oracle for Spectra MetaVault (MetaVaultWrapper over Amphor AsyncVault) that fixes two bugs in the generic `ERC7540YieldSourceOracle` when used with this vault pattern.

## Problem Statement

The Spectra MetaVaultWrapper at `0x6420a613e936602ca3f1ad5680b3f4d47d473bf1` on Base is a UUPS proxy wrapping an Amphor AsyncVault. It selectively overrides certain ERC-4626 functions but not others, creating a mismatch between the public API (`convertToAssets`) and internal pricing (`_convertToAssets`):

### Bug 1: getTVL() returns 0
- MetaVaultWrapper does NOT override `totalAssets()` from OZ ERC4626Upgradeable
- OZ default: `totalAssets() = asset.balanceOf(address(this))` = idle USDC in the vault
- All assets are deployed to the infra vault, so `totalAssets() = 0`

### Bug 2: Component 3 uses wrong pricing
- MetaVaultWrapper does NOT override `maxWithdraw()` from OZ ERC4626Upgradeable
- OZ `maxWithdraw()` calls internal `_convertToAssets()` which uses `totalAssets()/totalSupply()` (idle USDC ratio)
- But the public `convertToAssets()` IS overridden to use epoch snapshot rate
- Result: Component 3 returns a meaningless value based on idle USDC pricing

## Proposed Solution

Create `SpectraMetaVaultOracle` extending `AbstractYieldSourceOracle` directly, copying unchanged methods from `ERC7540YieldSourceOracle` and overriding:
1. **getTVL**: `convertToAssets(totalSupply())` instead of `totalAssets()`
2. **Component 3**: `claimableRedeemRequest(requestId, owner)` → `convertToAssets(claimableShares)` instead of `maxWithdraw(owner)`

## Technical Considerations

### Architecture
- Extends `AbstractYieldSourceOracle` directly (not `ERC7540YieldSourceOracle`)
- Constructor: `(address superLedgerConfiguration_, uint256 requestId_)` — same signature as generic oracle
- Immutable `REQUEST_ID` for accumulated-pattern vaults (typically 0)
- Pure view oracle — no state modifications, no access control

### Verified On-Chain Facts
- `vault.decimals()` = 6 (USDC-aligned, share token = vault)
- `vault.share()` reverts (vault IS the share token)
- `convertToAssets(1e6)` = 863399 (epoch 5 snapshot rate, ~0.863 USDC/share)
- `totalAssets()` = 0 (idle USDC)
- `totalSupply()` = 513917
- `claimableRedeemRequest(0, addr)` works with standard `(uint256, address)` signature
- `requestId` always 0 (accumulated pattern)
- `previewDeposit/previewRedeem` revert with `NotImplemented()`

### Error Handling
- **R1 (hard revert)**: `getPricePerShare` — must be correct or absent
- **R2 (graceful degradation)**: Async components 2-5 wrapped in try/catch, component = 0 on failure
- `convertToAssets` revert inside a successful try block propagates (existing pattern, accepted)

## Attack Surface Analysis

### Token Risks
- [x] Not applicable — oracle is pure read layer, no token transfers

### Reentrancy
- [x] Not a concern — all functions are view/pure, no state modifications

### Oracle & Price
- [x] PPS uses epoch snapshot rate via `convertToAssets` — resistant to flash loan manipulation
- [x] Stale price: PPS lags to last settled epoch — accepted, documented as design choice
- [x] No multi-oracle fallback needed — single source (vault's `convertToAssets`)

### Access Control & Upgrades
- [x] No state-changing functions — no access control needed
- [x] UUPS upgrade risk of underlying vault — accepted, same risk as all vault integrations

### DeFi Interaction Risks
- [x] No flash loan exposure — view functions only
- [x] No MEV/sandwich exposure — no value transfers
- [x] Donation attack resistant — uses epoch snapshot pricing, not live balances

### Exploit Precedent
- [x] Amphor AsyncVault audited on Sherlock (2024) — epoch settlement timing issues addressed
- [x] No ERC-4626 donation/inflation risk — `convertToAssets` uses epoch snapshots, not `totalAssets()/totalSupply()`

## Acceptance Criteria

### Functional
- [ ] `getPricePerShare()` returns correct epoch snapshot rate via `convertToAssets(10^decimals)`
- [ ] `getTVL()` returns `convertToAssets(totalSupply())` instead of `totalAssets()`
- [ ] Component 3 uses `claimableRedeemRequest(requestId, owner)` → `convertToAssets(claimableShares)` instead of `maxWithdraw(owner)`
- [ ] All other components (1, 2, 4, 5) behave identically to `ERC7540YieldSourceOracle`
- [ ] `share()` fallback to vault address works when `share()` reverts
- [ ] All async components (2-5) wrapped in try/catch for graceful degradation (R2)
- [ ] Works for any MetaVaultWrapper instance, not hardcoded to a specific address

### Testing
- [ ] Unit tests covering all 5 TVL components
- [ ] Unit test verifying `getTVL` uses `convertToAssets(totalSupply)` not `totalAssets`
- [ ] Unit test verifying Component 3 uses `claimableRedeemRequest` not `maxWithdraw`
- [ ] Fork test against live Base MetaVault at 0x6420
- [ ] Bytecode generated and locked

## Implementation

### `src/accounting/oracles/SpectraMetaVaultOracle.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IERC7540 } from "../../vendor/vaults/7540/IERC7540.sol";

/// @title SpectraMetaVaultOracle
/// @author Superform Labs
/// @notice Oracle for Spectra MetaVaultWrapper (ERC-7540 async vault over Amphor AsyncVault)
/// @dev Fixes two issues in the generic ERC7540YieldSourceOracle for MetaVaultWrapper:
///      1. getTVL uses convertToAssets(totalSupply()) instead of totalAssets() — MetaVaultWrapper
///         does not override totalAssets(), so it returns idle USDC (0) instead of vault NAV.
///      2. Component 3 (claimable redeem) uses claimableRedeemRequest → convertToAssets instead
///         of maxWithdraw — MetaVaultWrapper does not override maxWithdraw(), so it uses OZ
///         _convertToAssets (totalAssets/totalSupply ratio) instead of the epoch snapshot rate.
///      All other behavior (Components 1, 2, 4, 5, PPS, share token discovery) is identical
///      to ERC7540YieldSourceOracle.
contract SpectraMetaVaultOracle is AbstractYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The requestId used for accumulated-pattern 7540 vaults
    /// @dev Most 7540 vaults use requestId=0 (accumulated pattern). Set via constructor.
    uint256 public immutable REQUEST_ID;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract
    /// @param requestId_ The requestId to use for pending/claimable queries (typically 0)
    constructor(
        address superLedgerConfiguration_,
        uint256 requestId_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        REQUEST_ID = requestId_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        address shareToken = _getShareToken(yieldSourceAddress);
        return IERC20Metadata(shareToken).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
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
        return IERC7540(yieldSourceAddress).convertToShares(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
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
        IERC7540 vault = IERC7540(yieldSourceAddress);
        address shareToken = _getShareToken(yieldSourceAddress);
        uint256 shareDecimals = IERC20Metadata(shareToken).decimals();
        uint256 oneShare = 10 ** shareDecimals;

        uint256 assetsPerShare = vault.convertToAssets(oneShare);
        if (assetsPerShare == 0) return 0;

        return Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
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
        return IERC7540(yieldSourceAddress).convertToAssets(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev R1: Hard revert. PPS must be correct or absent.
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        IERC7540 vault = IERC7540(yieldSourceAddress);
        address shareToken = _getShareToken(yieldSourceAddress);
        uint256 _decimals = IERC20Metadata(shareToken).decimals();
        return vault.convertToAssets(10 ** _decimals);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        external
        view
        override
        returns (uint256)
    {
        address shareToken = _getShareToken(yieldSourceAddress);
        return IERC20(shareToken).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev R2: Graceful degradation. Each async component wrapped in try/catch.
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = getAsyncStateBreakdown(yieldSourceAddress, ownerOfShares);

        return heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue + claimableDepositValue;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Uses convertToAssets(totalSupply()) instead of totalAssets().
    ///      MetaVaultWrapper does not override totalAssets(), so the OZ default returns
    ///      idle USDC balance (0) instead of the actual vault NAV.
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        IERC7540 vault = IERC7540(yieldSourceAddress);
        return vault.convertToAssets(vault.totalSupply());
    }

    /*//////////////////////////////////////////////////////////////
                            ERC-7540 SPECIFIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns all 5 TVL components individually for monitoring
    /// @dev Component 3 uses claimableRedeemRequest → convertToAssets instead of maxWithdraw.
    ///      MetaVaultWrapper does not override maxWithdraw(), so it uses OZ _convertToAssets
    ///      (totalAssets/totalSupply ratio) which gives a meaningless value when totalAssets = 0.
    function getAsyncStateBreakdown(
        address yieldSourceAddress,
        address owner
    )
        public
        view
        returns (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        )
    {
        IERC7540 vault = IERC7540(yieldSourceAddress);
        address shareToken = _getShareToken(yieldSourceAddress);

        // Component 1: Held shares value
        uint256 heldShares = IERC20(shareToken).balanceOf(owner);
        if (heldShares > 0) {
            heldValue = vault.convertToAssets(heldShares);
        }

        // Component 2: Pending redeem value (shares → assets via convertToAssets)
        try vault.pendingRedeemRequest(REQUEST_ID, owner) returns (uint256 pendingShares) {
            if (pendingShares > 0) {
                pendingRedeemValue = vault.convertToAssets(pendingShares);
            }
        } catch { }

        // Component 3: Claimable redeem value
        // Uses claimableRedeemRequest → convertToAssets instead of maxWithdraw.
        // maxWithdraw uses OZ _convertToAssets (totalAssets/totalSupply ratio = 0).
        try vault.claimableRedeemRequest(REQUEST_ID, owner) returns (uint256 claimableShares) {
            if (claimableShares > 0) {
                claimableRedeemValue = vault.convertToAssets(claimableShares);
            }
        } catch { }

        // Component 4: Pending deposit value (already in assets)
        try vault.pendingDepositRequest(REQUEST_ID, owner) returns (uint256 pendingAssets) {
            pendingDepositValue = pendingAssets;
        } catch { }

        // Component 5: Claimable deposit value (already in assets)
        try vault.claimableDepositRequest(REQUEST_ID, owner) returns (uint256 claimableAssets) {
            claimableDepositValue = claimableAssets;
        } catch { }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Discovers the share token for a vault
    /// @dev Tries ERC-7575 share() first. Falls back to vault address (ERC-4626 pattern).
    function _getShareToken(address yieldSourceAddress) internal view returns (address) {
        try IERC7540(yieldSourceAddress).share() returns (address shareToken) {
            return shareToken;
        } catch {
            return yieldSourceAddress;
        }
    }
}
```

### Test File: `test/unit/oracles/SpectraMetaVaultOracle.t.sol`

Test structure:
1. Mock contract `MockSpectraMetaVault` that simulates:
   - `totalAssets()` returns 0 (OZ default, idle USDC)
   - `totalSupply()` returns non-zero
   - `convertToAssets()` returns epoch snapshot rate (overridden)
   - `share()` reverts
   - `claimableRedeemRequest()` returns shares
   - `maxWithdraw()` returns 0 (OZ default with totalAssets=0)
   - `pendingRedeemRequest()`, `pendingDepositRequest()`, `claimableDepositRequest()` return configurable values

2. Unit tests:
   - `test_getTVL_usesConvertToAssetsNotTotalAssets` - verify getTVL > 0 when totalAssets = 0
   - `test_getTVL_zeroSupply` - verify getTVL = 0 when totalSupply = 0
   - `test_component3_usesClaimableRedeemRequest` - verify Component 3 uses claimableRedeemRequest not maxWithdraw
   - `test_component3_claimableRedeemReverts_gracefulDegradation` - verify try/catch works
   - `test_allFiveComponents` - verify all components aggregate correctly
   - `test_getPricePerShare` - verify PPS uses convertToAssets(10^decimals)
   - `test_shareTokenFallback` - verify share() revert falls back to vault address
   - `test_zeroBalances` - verify zero balance edge cases

3. Fork test in `test/integration/spectra/SpectraMetaVaultOracleFork.t.sol`:
   - Against live 0x6420 on Base
   - Verify getTVL > 0
   - Verify PPS matches expected epoch rate

### Deployment

1. Add to `ORACLE_CONTRACTS` in `script/run/regenerate_bytecode.sh`
2. Add `SPECTRA_META_VAULT_ORACLE_KEY` to `script/utils/Constants.sol`
3. Add deployment logic to `DeployV2Core.s.sol` `_deployOracles()` section
4. Generate and lock bytecode

## References

- `src/accounting/oracles/ERC7540YieldSourceOracle.sol` — generic oracle being replaced
- `src/accounting/oracles/AbstractYieldSourceOracle.sol` — base class
- `test/unit/oracles/ERC7540OracleTests.sol` — test patterns to follow
- Spectra MetaVaultWrapper source: verified on Blockscout at `0x9bae29812bbc7ad442f49b180d0eb7c5bf107afe`
