# DETHYieldSourceOracle Technical Specification

## Overview

A custom yield source oracle for Dialectic's DETH/Machine vault that enables Superform's accounting system to calculate PPS, fees, and TVL for the DETH async redemption flow. The oracle receives the AsyncRedeemer address as `yieldSourceAddress`, discovers Machine via `asyncRedeemer.machine()`, and calls ERC-4626 conversion functions on Machine for pricing.

## Problem Statement

The 3 DETH hooks (RequestRedeem, ApproveAndRequestRedeem, ClaimAssets) all reference a `yieldSourceOracleId` in their hookData. Without a corresponding oracle, Superform's SuperLedger cannot calculate performance fees, track TVL, or report PPS for DETH positions. Additionally, during the async redemption window (between requestRedeem and claimAssets), the user's DETH shares are transferred to AsyncRedeemer, creating an artificial TVL drop unless the oracle accounts for pending NFT receipts.

## Proposed Solution

Create `DETHYieldSourceOracle` extending `AbstractYieldSourceOracle` that:
1. Resolves Machine, DETH, and WETH addresses immutably in constructor
2. Routes all pricing calls to Machine's ERC-4626 functions
3. Tracks pending async redemptions for accurate TVL reporting
4. Uses `convertToAssets`/`convertToShares` (not preview functions) for async vault safety

## Technical Approach

### Architecture

```
yieldSourceAddress (AsyncRedeemer)
    |
    v
DETHYieldSourceOracle (constructor resolves immutably)
    |
    ├── MACHINE = asyncRedeemer.machine()
    ├── DETH_TOKEN = machine.shareToken()
    └── WETH_TOKEN = machine.accountingToken()

Pricing calls → IERC4626(MACHINE).convertToAssets/convertToShares
Balance calls → IERC20(DETH_TOKEN).balanceOf
TVL calls    → held value + pending redemption value
```

### Pre-Implementation: Verify Machine ERC-4626 Support

Before finalizing the oracle, fork-test against mainnet to confirm Machine supports:
- `convertToAssets(uint256 shares)`
- `convertToShares(uint256 assets)`
- `totalAssets()`
- `decimals()`
- `balanceOf(address)`

Also verify AsyncRedeemer's NFT enumeration capabilities:
- Does it implement `IERC721Enumerable`?
- Does it have `nextRequestId()` for range scanning?
- How to determine the value of a pending request?

### IMachine Interface Extension

Extend the existing minimal `IMachine` interface with ERC-4626 view functions:

```solidity
interface IMachine {
    // Existing
    function shareToken() external view returns (address);
    function accountingToken() external view returns (address);

    // New: ERC-4626 view functions needed by oracle
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function decimals() external view returns (uint8);
}
```

### DETHYieldSourceOracle Implementation

```solidity
contract DETHYieldSourceOracle is AbstractYieldSourceOracle {
    using Math for uint256;

    address public immutable MACHINE;
    address public immutable DETH_TOKEN;
    address public immutable WETH_TOKEN;
    uint256 public immutable ONE_SHARE;

    constructor(address superLedgerConfiguration_, address asyncRedeemer_)
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        address machine = IDETHAsyncRedeemer(asyncRedeemer_).machine();
        MACHINE = machine;
        DETH_TOKEN = IMachine(machine).shareToken();
        WETH_TOKEN = IMachine(machine).accountingToken();
        ONE_SHARE = 10 ** IMachine(machine).decimals();
    }

    // decimals → IMachine(MACHINE).decimals()
    // getShareOutput → IMachine(MACHINE).convertToShares(assetsIn)
    // getAssetOutput → IMachine(MACHINE).convertToAssets(sharesIn)
    // getWithdrawalShareOutput → Math.mulDiv inverse with Ceil rounding
    // getPricePerShare → IMachine(MACHINE).convertToAssets(ONE_SHARE)
    // getBalanceOfOwner → IERC20(DETH_TOKEN).balanceOf(owner)
    // getTVL → IMachine(MACHINE).totalAssets()
    // getTVLByOwnerOfShares → heldValue + pendingRedemptionValue
}
```

### TVL Calculation Strategy

**Component 1: Held DETH shares**
```
heldValue = Machine.convertToAssets(DETH.balanceOf(owner))
```

**Component 2: Pending redemption value (TBD based on verification)**

Option A - If AsyncRedeemer supports ERC-721 Enumerable:
```
Enumerate NFTs → sum values → add to TVL
```

Option B - If AsyncRedeemer has nextRequestId() + ownerOf():
```
Scan from lastFinalized to nextRequestId, check ownerOf, sum values
```

Option C - No enumeration available:
```
TVL = held shares only (document limitation)
Pending tracking handled off-chain by monitoring
```

### Error Handling Policy

- **R1 (Hard Revert)**: `getPricePerShare`, `getShareOutput`, `getAssetOutput`, `getWithdrawalShareOutput`, `decimals`, `getBalanceOfOwner`, `getTVL`
- **R2 (Graceful Degradation)**: `getTVLByOwnerOfShares` async components wrapped in try/catch

## Attack Surface Analysis

### Oracle Manipulation
- [x] Trust Machine's convertToAssets directly (internal accounting, not external pools)
- [x] Immutable Machine address prevents redirection attacks
- [x] Hard revert on zero PPS (R1 policy)
- [x] Makina exploit mitigation: oracle does NOT use external AMM spot prices

### Token Risks
- [x] DETH/WETH both 18 decimals (verify on-chain)
- [x] Use SafeERC20 not needed (view-only oracle, no transfers)
- [x] No fee-on-transfer risk (oracle doesn't transfer tokens)

### Reentrancy
- [x] View-only oracle - no state modifications
- [x] No reentrancy guards needed

### Rounding
- [x] Floor rounding for getShareOutput, getAssetOutput, getPricePerShare
- [x] Ceil rounding for getWithdrawalShareOutput (favors vault)
- [x] Use Math.mulDiv for precision

### Exploit Precedent
| Protocol | Exploit | Our Mitigation |
|----------|---------|----------------|
| Makina Finance ($4M) | Oracle used Curve spot prices | Use Machine's internal convertToAssets |
| Venus/wUSDM | Donation inflated convertToAssets | Monitor PPS anomalies off-chain |
| ERC-4626 First Depositor | Zero-share inflation | Rely on Machine's own mitigations |

## Acceptance Criteria

### Functional
- [ ] Oracle extends AbstractYieldSourceOracle
- [ ] Receives AsyncRedeemer as yieldSourceAddress
- [ ] Resolves Machine, DETH, WETH immutably in constructor
- [ ] All 8 abstract methods implemented correctly
- [ ] getTVLByOwnerOfShares includes pending redemption value (if enumerable)
- [ ] getWithdrawalShareOutput uses Ceil rounding
- [ ] Uses convertToAssets/convertToShares (not preview functions)

### Non-Functional
- [ ] Gas-efficient: immutable address caching, early zero returns
- [ ] NatSpec documentation on all public/external functions
- [ ] Security assumptions documented (Machine's convertToAssets trust model)

### Testing
- [ ] Unit tests with inline mock (MockMachine, MockAsyncRedeemer)
- [ ] All oracle functions tested: zero inputs, 1:1 rate, non-1:1 rate, edge cases
- [ ] Fuzz tests for rounding invariants (round-trip, ceil favors vault)
- [ ] TVL preservation test (requestRedeem doesn't drop TVL)
- [ ] Fork integration test against mainnet Machine
- [ ] Verify Machine ERC-4626 support on mainnet fork

## Implementation Plan

### Phase 1: Verify On-Chain (fork tests)
- [ ] Fork-test Machine's convertToAssets, convertToShares, totalAssets, decimals
- [ ] Fork-test AsyncRedeemer's NFT enumeration capabilities
- [ ] Determine pending redemption tracking strategy (Option A/B/C)
- [ ] Verify DETH decimals on mainnet

### Phase 2: Extend IMachine Interface
- [ ] Add convertToAssets, convertToShares, totalAssets, decimals to IMachine

### Phase 3: Implement Oracle
- [ ] Create DETHYieldSourceOracle.sol
- [ ] Implement all 8 abstract methods
- [ ] Implement pending redemption tracking (based on Phase 1 findings)

### Phase 4: Unit Tests
- [ ] Create DETHYieldSourceOracle.t.sol with inline mocks
- [ ] Test all functions with standard scenarios
- [ ] Fuzz tests for rounding and overflow
- [ ] TVL preservation tests

### Phase 5: Fork Integration Tests
- [ ] Oracle against real mainnet Machine
- [ ] PPS sanity checks
- [ ] TVL calculation verification

## Dependencies
- Machine vault must support ERC-4626 view functions (verified in Phase 1)
- AsyncRedeemer NFT enumeration determines TVL tracking strategy (verified in Phase 1)

## Files to Create/Modify
- **Create**: `src/accounting/oracles/DETHYieldSourceOracle.sol`
- **Create**: `test/unit/accounting/DETHYieldSourceOracle.t.sol`
- **Modify**: `src/vendor/vaults/deth/IMachine.sol` (add ERC-4626 view functions)

## References
- `src/accounting/oracles/YoYieldSourceOracle.sol` - closest analog (async + simple)
- `src/accounting/oracles/FirelightYieldSourceOracle.sol` - pending withdrawal scanning
- `src/accounting/oracles/ERC7540YieldSourceOracle.sol` - 5-component async TVL + try/catch
- `src/accounting/oracles/AbstractYieldSourceOracle.sol` - base contract
- `src/interfaces/accounting/IYieldSourceOracle.sol` - required interface
