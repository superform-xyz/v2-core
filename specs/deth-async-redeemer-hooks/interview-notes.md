# DETH Async Redeemer Hooks - Interview Notes

## Date: 2026-05-11

## Context

DETH (Dialectic ETH Vault) is a tokenized leveraged wstETH/WETH loop strategy on Aave V3 by Makina/Dialectic. The architecture consists of:

- **DETH token** (`0x871aB8E36CaE9AF35c6A3488B049965233DeB7ed`) — ERC-20 share token ("MachineShare"), 12 decimals
- **Machine vault** (`0x0447D0aD7FD6a3409B48Ecbb9DDB075C1e11D735`) — BeaconProxy to Machine.sol, modified ERC-4626 with separate shareToken(), accountingToken = WETH
- **AsyncRedeemer** (`0xE44b62dD3F6379D6d14c38081fe1499D1a56250F`) — Async redemption queue, ERC-721 NFT per request

Current PPS: ~1.009 WETH per DETH. Finalization delay: 43,200 seconds (~12 hours).

DETH spot liquidity is effectively zero on DEXes, so Superform must interact with the AsyncRedeemer directly for unstaking.

Dialectic recently withdrew from Aave Umbrella (tx 0x9be7b9...), removing slashing risk exposure. The 317 WETH was re-leveraged into the wstETH/WETH loop.

## Feature Summary

Build 3 custom hooks for interacting with Dialectic's AsyncRedeemer contract:

1. **RequestRedeemDETHHook** (NONACCOUNTING) — calls `requestRedeem(shares, receiver, minAssets)` on AsyncRedeemer
2. **ApproveAndRequestRedeemDETHHook** (NONACCOUNTING) — approves DETH to AsyncRedeemer, then calls `requestRedeem`
3. **ClaimAssetsDETHHook** (OUTFLOW) — calls `claimAssets(requestId)` to collect WETH after finalization

## AsyncRedeemer Redemption Flow

### Phase 1: Request Redeem
1. Caller calls `requestRedeem(shares, receiver, minAssets)` on AsyncRedeemer
2. AsyncRedeemer does `safeTransferFrom(msg.sender, address(this), shares)` — transfers DETH from caller to itself
3. Calculates `assets = IMachine(machine).convertToAssets(shares)`
4. Checks `assets >= minAssets` (slippage protection)
5. Checks `shares >= minRedeemAmount` (currently 0)
6. Mints ERC-721 NFT to `receiver` with request data including the calculated assets amount
7. Returns requestId

### Phase 2: Finalization (by Dialectic keeper)
1. Dialectic calls `finalizeRequests(upToRequestId, minAssets)`
2. Calls `machine.redeem()` to deleverage the Aave position
3. Assets amount may be recalculated at finalization time
4. Finalization delay: 43,200 seconds (~12 hours)

### Phase 3: Claim Assets
1. Caller calls `claimAssets(requestId)` on AsyncRedeemer
2. Checks `msg.sender == ownerOf(requestId)` (NFT owner check)
3. Checks whitelist
4. Burns the NFT
5. Transfers WETH to receiver

## Technical Decisions

### D1: Approval Strategy → Both hooks
Create both `RequestRedeemDETHHook` (assumes approval exists) and `ApproveAndRequestRedeemDETHHook` (handles approval in-hook). Follows 7540 deposit hook pattern.

**Approve target**: DETH share token (`0x871aB8...`) approved for AsyncRedeemer (`0xE44b62...`). Confirmed from source: `IERC20(IMachine(_machine).shareToken()).safeTransferFrom(msg.sender, address(this), shares)`.

### D2: minAssets slippage → Encode in hookData
The off-chain keeper/bundler (Fair Pricing Service) encodes minAssets directly in hookData. This is necessary because:
- Spot market liquidity is broken for DETH/WETH pair
- The slippage check at requestRedeem time uses `convertToAssets` which is pseudo-locked (recalculated at finalization)
- Fair Pricing Service will determine the proper reference value

### D3: requestId for ClaimAssetsDETHHook → Encode in hookData
Off-chain keeper encodes the specific requestId in hookData. Simple and explicit.

### D4: HookSubType → ERC4626
Consistent with Firelight precedent. The Machine vault is 4626-like.

### D5: Testing → Mainnet fork
Fork Ethereum and test against the real AsyncRedeemer at `0xE44b62dD3F6379D6d14c38081fe1499D1a56250F`. Most realistic.

### D6: Oracle scope → Hooks only (off-chain PPS)
Build only the 3 hooks for now. PPS tracking during the redemption period will be handled off-chain by the PPS validator network reading from AsyncRedeemer's on-chain state (`getShares(requestId)`, `getClaimableAssets(requestId)`, `ownerOf(requestId)`). Custom on-chain oracle to be built separately later.

### D7: No cancel support
AsyncRedeemer has no cancel redeem functionality. Once `requestRedeem()` is called, DETH is transferred out and assets are available only after Dialectic finalizes. This is a trust assumption on Dialectic — low risk but documented.

## Nuances (from user)

### T1: Whitelist Requirement
Both `requestRedeem()` and `claimAssets()` have `whitelistCheck()` modifier. If whitelist is enabled and caller is not whitelisted, reverts with `CoreErrors.UnauthorizedCaller()`. The SuperVault Strategy smart account must be whitelisted by Dialectic.

Additionally, `claimAssets()` checks `msg.sender == ownerOf(requestId)` — the caller must own the NFT minted during requestRedeem.

In our case, the same smart account (SuperVault Strategy) calls both, so this is trivial.

### T2: Request Redeem Checks
- **T2.1 Min amount**: `shares >= minRedeemAmount` (currently 0, not an issue)
- **T2.2 Slippage**: `convertToAssets(shares) >= minAssets`. PPS is pseudo-locked at request time but recalculated at finalization. Fair Pricing Service sets minAssets.

### T3: PPS Jump Prevention
When requestRedeem is called, DETH leaves the SuperVault Strategy balance and an NFT enters. The NFT's data contains the asset amount. Options for tracking:
1. Off-chain PPS validator reads AsyncRedeemer state (chosen for MVP)
2. On-chain oracle reads NFT assets field (future work)
3. SuperVault Core Oracle that prices the NFT position (future work)

### T4: No Cancel
No `cancelRedeemRequest()` exists. Once DETH is transferred to AsyncRedeemer, it's locked until Dialectic finalizes. Trusted relationship assumption.

## hookData Layout

### RequestRedeemDETHHook / ApproveAndRequestRedeemDETHHook
```
bytes32 placeholder/oracleId  [0:32]    — unused/oracleId
address asyncRedeemer          [32:52]   — AsyncRedeemer contract address
uint256 shares                 [52:84]   — DETH shares to redeem
uint256 minAssets              [84:116]  — minimum WETH to receive (slippage)
bool    usePrevHookAmount      [116:117] — use output from previous hook
```

### ClaimAssetsDETHHook
```
bytes32 placeholder/oracleId  [0:32]    — unused/oracleId
address asyncRedeemer          [32:52]   — AsyncRedeemer contract address
uint256 requestId              [52:84]   — NFT request ID to claim
bool    usePrevHookAmount      [84:85]   — use output from previous hook (unlikely used)
```

## Contract Addresses (Ethereum Mainnet)

| Contract | Address |
|----------|---------|
| DETH share token | `0x871aB8E36CaE9AF35c6A3488B049965233DeB7ed` |
| Machine vault | `0x0447D0aD7FD6a3409B48Ecbb9DDB075C1e11D735` |
| AsyncRedeemer | `0xE44b62dD3F6379D6d14c38081fe1499D1a56250F` |
| WETH (accounting token) | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |

## Source Code References

- AsyncRedeemer: https://github.com/MakinaHQ/makina-periphery/blob/main/src/redeemers/AsyncRedeemer.sol
- Whitelist: https://github.com/MakinaHQ/makina-periphery/blob/main/src/utils/Whitelist.sol
