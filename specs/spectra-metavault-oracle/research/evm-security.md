# EVM Security Research: SpectraMetaVaultOracle

## Relevant Vulnerability Patterns

### BUG-1: maxWithdraw Wrong Pricing (Critical - P0)
- **Issue**: MetaVaultWrapper does NOT override `maxWithdraw()` from OZ ERC4626Upgradeable
- **Root Cause**: OZ `maxWithdraw()` calls `_convertToAssets()` which uses `totalAssets()/totalSupply()`
- **Impact**: Component 3 returns meaningless value based on idle USDC, not epoch NAV
- **Fix**: Replace `maxWithdraw(owner)` with `claimableRedeemRequest(0, owner)` -> `convertToAssets(claimableShares)`
- **Reference**: vulnerabilities.md Section 22 (Vault/Share Accounting)

### BUG-2: totalAssets Returns 0 (High - P1)
- **Issue**: MetaVaultWrapper does NOT override `totalAssets()` from OZ ERC4626Upgradeable
- **Root Cause**: OZ default `totalAssets() = asset.balanceOf(address(this))` = idle USDC = 0
- **Impact**: `getTVL()` returns 0, breaking TVL reporting
- **Fix**: Use `convertToAssets(totalSupply())` instead of `totalAssets()`
- **Reference**: vulnerabilities.md Section 22

## Exploit Precedents

### Amphor Sherlock Audit (2024)
- Amphor AsyncVault (the infra vault underlying MetaVaultWrapper) was audited on Sherlock
- Key findings related to epoch settlement timing, share price manipulation during epoch transitions
- Our oracle only reads epoch-settled prices, mitigating timing attacks

### Curve/dForce Read-Only Reentrancy
- View functions using stale state during callback execution
- **Relevance**: Our oracle is pure view, no callbacks, no state modification
- **Assessment**: Not a concern for this oracle

### ERC-4626 First Depositor / Donation Attacks
- Share price manipulation via donations to inflate `totalAssets()`
- **Relevance**: We use `convertToAssets(totalSupply())` which uses epoch snapshot rate, not live balances
- **Assessment**: Mitigated by design - epoch snapshot pricing is resistant to donation attacks

## Attack Surface Map

### External Calls (All View/Pure)
1. `vault.convertToAssets(shares)` - epoch snapshot rate
2. `vault.totalSupply()` - ERC20 totalSupply
3. `vault.share()` - ERC-7575 share token discovery (may revert)
4. `vault.pendingRedeemRequest(requestId, owner)` - pending shares
5. `vault.claimableRedeemRequest(requestId, owner)` - claimable shares (NEW)
6. `vault.pendingDepositRequest(requestId, owner)` - pending assets
7. `vault.claimableDepositRequest(requestId, owner)` - claimable assets
8. `IERC20(shareToken).balanceOf(owner)` - held shares
9. `IERC20Metadata(shareToken).decimals()` - share decimals

### Trust Assumptions
- MetaVaultWrapper's `convertToAssets()` returns accurate epoch snapshot rate
- `totalSupply()` accurately reflects all outstanding shares
- `claimableRedeemRequest()` correctly reports claimable shares
- UUPS proxy implementation is not maliciously upgraded

### No Attack Vectors Identified
- Oracle is pure view (no state modification)
- No value transfers
- No reentrancy risk (view functions only)
- No flash loan exposure
- No MEV/sandwich risk
- No access control needed (public view functions)

## Security Patterns Applied
- **R1/R2 Error Handling**: Hard revert for PPS (must be correct), try/catch for async components (graceful degradation)
- **Epoch Snapshot Pricing**: Uses settled epoch rates, resistant to manipulation
- **Share Token Fallback**: `try share() catch { return vault }` - safe pattern from generic oracle

## Testing Recommendations

### Unit Tests (7)
1. `getTVL` returns `convertToAssets(totalSupply)` not `totalAssets()`
2. Component 3 uses `claimableRedeemRequest` not `maxWithdraw`
3. All 5 TVL components with non-zero values
4. Zero balance edge cases
5. `claimableRedeemRequest` revert -> component = 0
6. `share()` revert -> fallback to vault address
7. `getPricePerShare` uses `convertToAssets(10^decimals)`

### Fork Tests (3)
1. Against live 0x6420 on Base: getTVL > 0
2. Against live 0x6420: no double-counting in getTVLByOwnerOfShares
3. Against live 0x6420: PPS matches expected epoch rate

### Invariant Tests (4)
1. `getTVL >= sum(getTVLByOwnerOfShares)` for all registered owners
2. `getPricePerShare > 0` when `totalSupply > 0`
3. No component double-counting (C3 independent of C1)
4. `convertToAssets(totalSupply) >= totalAssets()` (NAV >= idle USDC)
