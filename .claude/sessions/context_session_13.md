# Session 13: Fix StargateAdapter — Use amountLD Instead of balanceOf

## Context
The StargateAdapter uses `balanceOf(address(this))` to determine transfer amounts during `lzCompose`. Because Stargate V2 splits `lzReceive` and `lzCompose` into separate transactions, concurrent bridges can cause one user's compose to sweep another user's tokens.

## Plan
1. Extract `amountLD` from OFTComposeMsgCodec header (bytes 12-44) in StargateAdapter.sol
2. Replace balance-based transfers with amountLD-based transfers (both ERC20 and ETH paths)
3. Update dev comments
4. Update unit tests to verify amountLD-based behavior
5. Update fork tests
6. Regenerate bytecode
7. Mark P2-2 as FIXED in security report

## Status: COMPLETE

## Changes Made

### src/adapters/StargateAdapter.sol
- Added `uint256 amountLD = uint256(bytes32(_message[12:44]))` extraction from OFTComposeMsgCodec header at bytes 12-44
- Replaced `balanceOf(address(this))` / `address(this).balance` with `amountLD` in both ERC20 and ETH transfer paths
- Updated dev comments to document the amountLD approach instead of balance-based warnings
- Renumbered internal step comments (3-7 instead of 3-6)

### test/unit/adapters/AdaptersUnitTests.sol
- Updated `test_StargateAdapter_lzCompose_ERC20_HappyPath` — amountLD matches balance
- Renamed `test_StargateAdapter_lzCompose_TransfersFullBalance` → `test_StargateAdapter_lzCompose_TransfersOnlyAmountLD` — verifies only 500 of 1000 transfers
- Renamed `test_StargateAdapter_lzCompose_ZeroBalance` → `test_StargateAdapter_lzCompose_ZeroAmountLD`
- Renamed `test_StargateAdapter_lzCompose_DustFromPriorCompose` → `test_StargateAdapter_lzCompose_DustRemainsInAdapter` — verifies 200 dust stays
- Added `test_StargateAdapter_lzCompose_ConcurrentComposesIsolated` — two users, isolated transfers

### test/integration/stargate/StargateAdapterFork.t.sol
- Renamed `test_Fork_StargateAdapter_lzCompose_RealUSDC_FullBalanceSweep` → `test_Fork_StargateAdapter_lzCompose_RealUSDC_DustNotSwept`
- Updated assertions: only amountLD transferred, dust remains

### specs/security-reports/2026-05-26-stargate-adapter.md
- Marked P2-2 as **FIXED**
- Updated description with resolution details
- Updated peer adapter comparison table
- Updated attack surface summary

### Bytecode
- Regenerated `script/generated-bytecode/StargateAdapter.json`
- Copied to `script/locked-bytecode/StargateAdapter.json`
- Copied to `script/locked-bytecode-dev/StargateAdapter.json`

## Test Results
- All 14 StargateAdapterTest unit tests pass
- Fork tests require ETHEREUM_RPC_URL (not run in this session)
