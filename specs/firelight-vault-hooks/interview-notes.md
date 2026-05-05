# Firelight Vault Hooks — Interview Notes

**Date:** 2026-04-20
**Feature:** Custom hooks for Firelight vault (stXRP) on Flare chain

## Context (from on-chain investigation)

Firelight vault at `0x4C18Ff3C89632c3Dd62E796c0aFA5c07c4c1B2b3` on Flare (chain ID 14):
- Claims ERC-4626 compliance but has **async withdrawal semantics**
- `redeem(shares, receiver, owner)` → burns stXRP, emits `WithdrawRequest`, does NOT transfer FXRP
- `withdraw(assets, receiver, owner)` → same behavior, burns shares, emits `WithdrawRequest`
- `claimWithdraw(requestId)` → claims FXRP after cooldown (~2 days max)
- `deposit()` appears synchronous (standard ERC-4626)
- Vault is upgradeable (proxy delegates to `0x70CCf1bEE0c1217069FE74083Ca71AF7BCd7fb76`)
- FXRP token: `0xAd552A648C74D49E10027AB8a618A3ad4901c5bE`
- `maxRedeem()`/`maxWithdraw()` return full balance (misleading — implies instant redemption)
- `supportsInterface(ERC7540)` returns `false`
- Does NOT implement ERC-7540 functions (`requestRedeem`, `claimableRedeemRequest`, `pendingRedeemRequest` all revert)
- Custom event: `WithdrawRequest(address sender, address receiver, address owner, uint256 requestId, uint256 assets, uint256 shares)`
- `claimWithdraw(0)` reverts with `NoWithdrawalAmount(uint256)`

## On-chain evidence

- TX `0xe9fa9a...` shows `redeem()` call that succeeds (status=1) but only burns stXRP (Transfer to 0x0) and emits WithdrawRequest — no FXRP transfer
- Trace of `withdraw(1000000)` from top holder confirms: shares burned, WithdrawRequest emitted with requestId=139, no FXRP outflow

## Decisions

### Hook 1: RedeemFirelightVaultHook
- **HookType:** NONACCOUNTING — redeem() only queues a request, no asset outflow
- **HookSubType:** ERC4626 (reusing existing subtype since it uses 4626 function signatures)
- **Cancellation:** CancelationType.NONE — Firelight has no cancel mechanism
- **Behavior:** Calls `redeem(shares, account, account)` on the Firelight vault

### Hook 2: ClaimWithdrawFirelightVaultHook
- **HookType:** OUTFLOW — claimWithdraw() actually transfers FXRP to the account
- **HookSubType:** ERC4626
- **RequestId:** Encoded in hookData (off-chain keeper passes it explicitly)
- **Outflow tracking:** Yes — measure FXRP balanceOf(account) delta in _preExecute/_postExecute

### Deposit
- Use existing `Deposit4626VaultHook` / `ApproveAndDeposit4626VaultHook` — deposit() is synchronous

### Interface
- Create custom `IFirelightVault` interface with just `redeem()`, `claimWithdraw(uint256)`, and `asset()` signatures
- Cleaner and self-documenting rather than casting to IERC4626 + raw calls

## Scope

- 2 new hook contracts in v2-core
- 1 new interface (`IFirelightVault`)
- Unit tests for both hooks
- No changes to existing hooks or contracts
