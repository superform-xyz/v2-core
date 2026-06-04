# ClaimFailedTransferHook - Interview Notes

## Date: 2026-06-02

## Feature Summary
Create a `ClaimFailedTransferHook` that allows smart accounts to call `claimFailedTransfer(address token, uint256 amount)` on the StargateAdapter contract via the SuperExecutor hook system. This enables recovery of tokens from failed lzCompose transfers.

## Technical Decisions

### Hook Variant
- **Decision:** Single hook only (`ClaimFailedTransferHook`)
- **Rationale:** The adapter's `claimFailedTransfer` sends tokens back to `msg.sender` (the smart account). No approval to a third party is needed, so an `ApproveAndClaim` variant is unnecessary.

### Scope
- **Decision:** Single adapter per call
- **Rationale:** One StargateAdapter address per hook execution. If the user has failed transfers on multiple adapters, they batch via multiple hooks in a single userOp.

### Post-Claim Behavior
- **Decision:** Just claim, leave tokens in the smart account
- **Rationale:** The hook only calls `claimFailedTransfer`. A subsequent `TransferHook` in the same userOp can move tokens if needed. Keeps the hook single-purpose.

### Address Validation
- **Decision:** Trust the bundler (no validation)
- **Rationale:** If the address is wrong, `claimFailedTransfer` reverts naturally. No extra check needed — matches pattern of other hooks that trust bundler-provided addresses.

### Token Support
- **Decision:** Support both ERC20 and native ETH (token = address(0))
- **Rationale:** The StargateAdapter supports both paths. The hook just passes the token param through to the adapter.

## Security Considerations
- The hook makes a single external call to a known function signature
- No token approvals needed (adapter sends tokens to caller)
- No reentrancy risk in the hook itself (single execution, no state)
- The adapter has its own `nonReentrant` guard on `claimFailedTransfer`
- For native ETH: the adapter sends ETH back via `call{value}` to the smart account

## Acceptance Criteria
- [ ] `ClaimFailedTransferHook` contract created following existing hook patterns
- [ ] Supports ERC20 and native ETH (address(0)) token claims
- [ ] Takes adapter address, token address, and amount as packed data parameters
- [ ] Builds a single `Execution` targeting the adapter's `claimFailedTransfer(address,uint256)`
- [ ] Unit tests covering ERC20 claim, native ETH claim, and error cases
- [ ] Bytecode generated and locked
