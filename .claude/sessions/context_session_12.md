# Session 12: StargateAdapter Implementation

## Status: COMPLETE

## Summary
Implemented the `StargateAdapter` contract — a destination-side compose receiver for Stargate V2 / LayerZero V2 cross-chain operations. Follows the same pattern as `AcrossV3Adapter` and `DebridgeAdapter`.

## Files Created
- `src/vendor/bridges/layerzero/ILayerZeroComposer.sol` — LZ V2 composer interface
- `src/adapters/StargateAdapter.sol` — Compose receiver adapter

## Files Modified
- `test/unit/adapters/AdaptersUnitTests.sol` — Added 13 test cases (StargateAdapterTest contract, MockStargatePool, NonPayableContract helpers)
- `script/run/regenerate_bytecode.sh` — Added `StargateAdapter` to CORE_CONTRACTS array

## Key Design Decisions
- **Balance-based transfer**: Full adapter balance transferred, not `amountLD` from codec
- **Endpoint-only validation**: `msg.sender == LZ_ENDPOINT` (no `_from` whitelist)
- **Token identification**: `_from.token()` — selector `0xfc0c546a` shared by IStargate and IOFT
- **Native ETH**: `receive()` for StargatePoolNative; `_from.token() == address(0)` triggers ETH path
- **OFTComposeMsgCodec**: 76-byte header (nonce:8 + srcEid:4 + amountLD:32 + composeFrom:32), then inner 6-tuple payload
- **Constructor**: `(lzEndpoint_, superDestinationExecutor_)` — both immutable

## Test Results
All 13 tests pass:
- Constructor validation (3 tests)
- Sender auth, message length, invalid decoding (3 tests)
- ERC20 happy path, ETH happy path (2 tests)
- ETH transfer failure, full balance sweep, zero balance, dust accumulation (4 tests)
- receive() accepts ETH (1 test)

## Fork Integration Tests

Added `test/integration/stargate/StargateAdapterFork.t.sol` — 8 fork tests using real Ethereum mainnet contracts:

### Test Cases (9 total)
1. **Constructor_RealEndpoint** — deploy with real LZ endpoint, verify immutables
2. **RealPool_TokenInterface** — real Stargate USDC pool returns correct `token()` (USDC, 6 decimals)
3. **RealOFTAdapter_TokenInterface** — WBTC OFT adapter returns WBTC, UP OFT adapter returns UP token
4. **lzCompose_ERC20_RealPool** — full lzCompose flow: deal USDC to adapter, prank as LZ endpoint, call with real pool as `_from`, verify transfer
5. **lzCompose_ERC20_OFTAdapter** — same flow but with WBTC OFT adapter as `_from`
6. **RevertIf_NotRealEndpoint** — non-endpoint caller gets INVALID_SENDER revert
7. **RealUSDC_FullBalanceSweep** — dust (50 USDC) + delivery (1000 USDC) = full 1050 USDC swept to account
8. **MultipleTokenTypes** — sequential test: USDC (6 decimals) via pool, then WBTC (8 decimals) via OFT adapter
9. **EndToEnd_HookSendWithCompose_To_AdapterLzCompose** — full bridge flow:
   - Source: `ApproveAndStargateSendHook` builds and executes real `sendToken` with `composeMsg` on real Stargate USDC pool
   - Destination: `StargateAdapter.lzCompose` receives the same compose message format, transfers tokens to destination account
   - Proves end-to-end format compatibility between hook (source) and adapter (destination)

### Real Addresses Used
- LZ Endpoint: `0x1a44076050125825900e736c501f859c50fE728c`
- Stargate USDC Pool: `0xc026395860Db2d07ee33e05fE50ed7bD583189C7`
- UP OFT Adapter: `0x722ff7C0665F4b1823c9C4cFcDF73A43de5865BD`
- WBTC OFT Adapter: `0x0555E30da8f98308EdB960aa94C0Db47230d2B9c`

### Design
- Only `processBridgedExecution` is mocked (via `vm.mockCall`) — everything else uses real contracts
- Follows `StargateHooksFork.t.sol` pattern for constants, fork setup, helpers

## Security Review

Ran `/superform:security` on StargateAdapter. Report: `specs/security-reports/2026-05-26-stargate-adapter.md`

**Verdict: PASS** (0 P0, 0 P1, 3 P2, 6 P3)

### Findings Resolution
- **P2-1 (_from validation)**: No fix needed. Signature validation in `processBridgedExecution` validates `(executorCalldata, chainId, account, address(this), dstTokens, intentAmounts)` — spoofed `_from` can't cause harm beyond the accepted balance-sweep tradeoff.
- **P2-2 (balance-based accounting)**: No fix needed. Consistent with `DebridgeAdapter` ETH path (`address(this).balance`). Accepted design decision documented in `@dev WARNING`.
- **P2-3 (missing events)**: **FIXED**. Added `ComposeExecuted(address indexed account, address indexed tokenSent, uint256 amount)` event, emitted in both ETH and ERC20 paths. Also cached ETH balance before transfer (P3-5). Unit tests updated with `vm.expectEmit`.
- **P3-1 (account == address(0))**: No fix needed. Neither AcrossV3Adapter nor DebridgeAdapter check this. `SuperDestinationExecutor._validateOrCreateAccount` handles it downstream (line 170).

## Spec Reference
- `specs/stargate-compose-adapter/spec.md`
- `specs/stargate-compose-adapter/technical-spec.md`
