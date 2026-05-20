# Session 9: DETH Async Redeemer Hooks

## Status: Complete

## Overview
Built 3 custom hooks for Dialectic's DETH AsyncRedeemer on Ethereum mainnet.

## Spec
See: `specs/deth-async-redeemer-hooks/technical-spec.md`

## Key Contracts
- DETH share token: `0x871aB8E36CaE9AF35c6A3488B049965233DeB7ed` (12 decimals)
- Machine vault: `0x0447D0aD7FD6a3409B48Ecbb9DDB075C1e11D735`
- AsyncRedeemer: `0xE44b62dD3F6379D6d14c38081fe1499D1a56250F`
- WETH: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`

## Tasks
1. [x] Create IDETHAsyncRedeemer.sol interface
2. [x] Create IMachine.sol interface
3. [x] Create RequestRedeemDETHHook.sol (NONACCOUNTING, tracks usedShares via DETH balance delta)
4. [x] Create ApproveAndRequestRedeemDETHHook.sol (NONACCOUNTING, zero-set-execute-zero approval, tracks outAmount)
5. [x] Create ClaimAssetsDETHHook.sol (OUTFLOW, discovers WETH via machine().accountingToken(), tracks outAmount)
6. [x] Create unit tests (34 tests, all passing)
7. [x] Verify compilation

## Files Created
- `src/vendor/vaults/deth/IDETHAsyncRedeemer.sol` — Interface: requestRedeem, claimAssets, machine
- `src/vendor/vaults/deth/IMachine.sol` — Interface: shareToken, accountingToken
- `src/hooks/vaults/deth/RequestRedeemDETHHook.sol` — NONACCOUNTING, 1 execution, discovers DETH via machine().shareToken()
- `src/hooks/vaults/deth/ApproveAndRequestRedeemDETHHook.sol` — NONACCOUNTING, 4 executions (approve pattern), DETH in hookData
- `src/hooks/vaults/deth/ClaimAssetsDETHHook.sol` — OUTFLOW, 1 execution, discovers WETH via machine().accountingToken()
- `test/unit/hooks/vaults/deth/DETHHooksTests.t.sol` — 34 unit tests with mock contracts

## hookData Layouts
- **RequestRedeem**: `[0:32] oracleId | [32:52] asyncRedeemer | [52:84] shares | [84:116] minAssets | [116:117] usePrevHook`
- **ApproveAndRequestRedeem**: `[0:32] oracleId | [32:52] asyncRedeemer | [52:72] dethToken | [72:104] shares | [104:136] minAssets | [136:137] usePrevHook`
- **ClaimAssets**: `[0:32] oracleId | [32:52] asyncRedeemer | [52:84] requestId | [84:85] usePrevHook`

## Key Design Decisions
- RequestRedeemDETHHook discovers DETH dynamically via asyncRedeemer.machine().shareToken()
- ApproveAndRequestRedeemDETHHook has DETH address in hookData (needed for approve calls)
- ClaimAssetsDETHHook discovers WETH via asyncRedeemer.machine().accountingToken(), sets asset and spToken in _preExecute
- usedShares intentionally NOT set in ClaimAssetsDETHHook (Firelight precedent — shares consumed in prior step)
- All hooks use HookSubTypes.ERC4626
