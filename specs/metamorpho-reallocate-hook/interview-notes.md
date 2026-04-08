# MetaMorpho Reallocate Hook - Interview Notes

## Feature Summary
Create a NONACCOUNTING hook that calls MetaMorpho's `reallocate()` function to redistribute funds between Morpho Blue markets within a single MetaMorpho vault. This is a management/curator operation used by SuperVault managers.

## Functional Requirements
- Hook type: NONACCOUNTING (no accounting impact - reallocate is net-zero)
- Hook subtype: MISC (management operation)
- MetaMorpho vault address passed in hook data (one hook deployment for all vaults)
- Supports `usePrevHookAmount` for chaining
- Called via `executeHooks()` on SuperVaultStrategy by the manager
- The SuperVault manager is also a curator/allocator on MetaMorpho

## Technical Decisions

### Data Encoding
- Use BytesLib pattern consistent with other hooks (Spectra, Pendle, etc.)
- MetaMorpho vault address is in the hook data (not constructor)
- Raw ABI-encoded `MarketAllocation[]` passed as variable-length data at the end
- usePrevHookAmount flag to modify one allocation's assets from previous hook output

### MetaMorpho reallocate() Interface
```solidity
function reallocate(MarketAllocation[] calldata allocations) external;

struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;
}

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}
```

### Key Constraints of reallocate()
- **Net-zero invariant**: totalWithdrawn must equal totalSupplied (else reverts InconsistentReallocation)
- **Supply cap**: Each market has a configured cap, supplying beyond it reverts
- **Ordering**: Withdrawals should come before supplies in the array
- **type(uint256).max pattern**: Setting assets = type(uint256).max on last supply entry absorbs remaining withdrawn balance
- **Access**: onlyAllocatorRole - owner, curator, or allocator can call

### Constructor
- No native address needed (reallocate operates on ERC20 supply positions only)
- Minimal constructor: `BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC)`

### Hook Execution Flow
1. Manager calls `SuperVaultExecutor.executeHooks(strategy, args)`
2. Strategy validates manager and iterates hooks
3. This hook's `build()` returns Execution[] targeting the MetaMorpho vault
4. The Execution calls `reallocate(allocations)` on the MetaMorpho vault
5. MetaMorpho redistributes funds between Morpho Blue markets

## Risks & Security
- reallocate() is net-zero so no fund loss risk from the reallocation itself
- Must validate MetaMorpho vault address is non-zero
- The allocator/curator role on MetaMorpho is the trust boundary
- No reentrancy concern since reallocate() is a view-like operation (withdraws then supplies within same tx)
- Supply cap enforcement is done by MetaMorpho contract itself

## Testing Strategy
- Unit tests for data encoding/decoding
- Unit tests for build() execution generation
- Unit tests for usePrevHookAmount
- Integration tests with forked mainnet MetaMorpho vault (optional)
