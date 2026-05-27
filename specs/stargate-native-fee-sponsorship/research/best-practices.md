# Best Practices Research — Stargate Native Fee Sponsorship

## ERC-4337 Sponsorship Patterns

### Key Insight: No Existing Primitive
There is no existing ERC-4337 primitive for "execution-time native token sponsorship." Standard paymasters only cover gas costs. This design fills a gap where a smart account needs native ETH during execution (e.g., for LayerZero messaging fees) but doesn't hold any.

### EntryPoint Compatibility
- EntryPoint v0.9 restricts `handleOps` to top-level EOA calls — verify current version compatibility
- The `sponsorNativeAndHandleUserOp` function calls `entryPoint.handleOps` from a contract context
- If EntryPoint restricts this, the paymaster design needs adjustment
- **Action:** Verify the EntryPoint version used in production accepts contract-initiated `handleOps`

### Atomicity in ERC-4337
Two distinct revert scenarios:
1. **Full handleOps revert** (validation failure) — entire transaction reverts, sponsorship deposit also reverts. Safe.
2. **Inner call revert** (execution failure) — within `innerHandleOp`, if execution reverts, state changes from the execution call are reverted (FetchNativeFeeHook withdrawal would be undone), but postOp runs. The deposit in NativeFeeSponsorship stays.

**Important nuance:** Since the sponsorship deposit happens BEFORE `handleOps`, but the FetchNativeFeeHook withdrawal happens INSIDE the UserOp execution, an inner execution revert reverts the withdrawal but NOT the deposit. This creates an orphaned deposit.

### Mitigation
- Bundler reclaims orphaned deposits manually via `withdrawSponsorDeposit`
- The `sponsorNativeAndHandleUserOp` wrapper ensures the outer tx reverts on full handleOps failure
- Inner execution failure is the only orphan scenario — accepted tradeoff

## ETH Escrow Best Practices

### Checks-Effects-Interactions (CEI)
- All state updates MUST happen before ETH transfers
- NativeFeeSponsorship follows CEI: validate → update mapping → transfer ETH
- This prevents reentrancy even without guards (but we add ReentrancyGuard for defense-in-depth)

### ReentrancyGuardTransient (Recommended)
- Use `ReentrancyGuardTransient` instead of `ReentrancyGuard` for ~2000 gas savings per guarded call
- Available in OpenZeppelin 5.x via EIP-1153 transient storage
- The codebase already uses transient storage extensively (hook execution context)
- **Note:** Verify OpenZeppelin version in the project supports `ReentrancyGuardTransient`

### ETH Transfer Pattern
- Use `(bool success,) = payable(to).call{value: amount}("")` — standard pattern
- Revert on failure with descriptive error (`ETH_TRANSFER_FAILED`)
- No gas limit on the call (trusted recipients: smart accounts)

## Stargate V2 Integration Patterns

### LayerZero Fee Structure
- `quoteSend()` returns `MessagingFee(nativeFee, lzTokenFee)`
- `sendToken()` requires `msg.value >= nativeFee + amountLD`
- The FetchNativeFeeHook sponsors ONLY `nativeFee`, not `amountLD`
- Smart account holds `amountLD` separately (e.g., via WETH unwrap hook before Stargate hook)

### Fee Quoting
- Off-chain bundler calls `quoteSend` with the planned parameters
- Quote may change between quote time and execution time (gas price volatility)
- Slight oversponsorship is acceptable (excess stays on smart account)
- Undersponsorship causes the Stargate send to revert (acceptable — atomic revert)

## Open Balance Model

### Design Philosophy
- No signatures, nonces, or approvals required
- Sponsor deposits ETH keyed by `(sponsor, account)` pair
- Account withdraws by being `msg.sender`
- Sponsor reclaims by being `msg.sender`
- Replay risk is the bundler's responsibility

### Trade-offs
- **Pro:** Simpler implementation, lower gas costs, no signature verification overhead
- **Con:** Race condition between sponsor reclaim and account withdrawal
- **Mitigation:** Atomic `sponsorNativeAndHandleUserOp` ensures normal flow has no race condition
