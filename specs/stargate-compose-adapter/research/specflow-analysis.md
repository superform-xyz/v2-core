# StargateAdapter SpecFlow Analysis

## User Flows

### Flow 1: ERC20 Token Compose (Happy Path)
1. Source: StargateSendHook calls `sendToken()` with `to=adapter`, `composeMsg=6-tuple`
2. LZ delivers cross-chain
3. Tx1 (lzReceive): Dst pool credits ERC20 to adapter, queues compose
4. Tx2 (lzCompose): Endpoint calls `adapter.lzCompose()`, adapter transfers tokens to account, calls `processBridgedExecution()`

### Flow 2: Native ETH Compose
Same as Flow 1 but `_from.token()` returns `address(0)`, adapter forwards ETH via `call{value}`

### Flow 3: OFT Mode (mode=2)
OFT mints/unlocks tokens to adapter, `_from.token()` returns `address(_from)` (OFT IS the token), adapter calls `safeTransfer` on the OFT contract itself

### Flow 4: Bus Mode (mode=1)
Same as Flow 1 but batched delivery - two-transaction gap is longer, balance accumulation risk higher

### Flow 5: Failed Compose + Retry
Compose reverts -> stays in LZ queue -> retryable -> on retry, adapter may have dust from prior attempts -> all swept to account

### Flow 6: No composeMsg (out of scope)
When `composeMsg.length == 0`, `to` is user address directly, no adapter involved

### Flow 7: Bundler Misconfiguration
`to = user address` with composeMsg -> tokens go to user, compose fails (user has no `lzCompose`), tokens not lost but compose orphaned

## Critical Gaps Identified

### Gap 1: `_message.length < 76` not explicitly checked
Implicit Solidity panic on out-of-bounds slice. **Resolution**: Add explicit `if (_message.length < 76) revert COMPOSE_MSG_TOO_SHORT()`

### Gap 2: Inner composeMsg decode failure
Malformed payload causes `abi.decode` revert. **Resolution**: Let revert propagate (compose retryable), consistent with other adapters.

### Gap 3: OFT-as-token (`token() == address(_from)`)
Adapter calls `safeTransfer` on OFT contract itself. Works for standard OFTs but OFTs with transfer fees could break. **Resolution**: Document as assumption.

### Gap 4: Compose index always 0
Stargate always uses index 0. If future versions use index > 0, second compose may have zero balance. **Resolution**: Document as known limitation.

### Gap 5: `_from.token()` revert handling
If `_from` doesn't implement `token()`, compose reverts (retryable). **Resolution**: Accept as liveness issue, not fund loss.

### Gap 6: Error names not specified
Need: `ADDRESS_NOT_VALID`, `INVALID_SENDER`, `ETH_TRANSFER_FAILED`. Define in adapter contract (not interface).

### Gap 7: `_from` terminology
`_from` is the DESTINATION chain pool, not source. Clarify in NatSpec.

### Gap 8: Zero-balance compose
If adapter has no tokens, `safeTransfer(account, 0)` may succeed, executor validates balances and emits `ReceivedButNotEnoughBalance`. **Resolution**: Document behavior.

### Gap 9: Concurrent compose sweep
Two lzReceives for same token -> first lzCompose sweeps both balances -> second gets zero. **Resolution**: Accepted risk of balance-based design. Document.

### Gap 10: Fee-on-transfer tokens
`safeTransfer(account, balanceOf)` may fail if token has transfer fees. **Resolution**: Out of scope (Stargate pools use standard tokens).

## Key Questions (with defaults)

| # | Question | Default Resolution |
|---|----------|-------------------|
| 1 | `_message.length < 76` handling | Add explicit length check |
| 2 | Hook validation of `to == adapter` | No hook changes, bundler trusted |
| 3 | `lzEndpoint_` param vs constant | Constructor param (enables testing) |
| 4 | Error name for invalid caller | `INVALID_SENDER()` in adapter |
| 5 | Error name for ETH failure | `ETH_TRANSFER_FAILED()` in adapter |
| 6 | ILayerZeroComposer location | Vendor copy at `src/vendor/bridges/layerzero/` |
| 7 | OFTComposeMsgCodec approach | Inline with named constant `COMPOSE_MSG_OFFSET = 76` |
| 8 | Compose index support | Document index=0 only |
| 9 | Adapter events | None (consistent with other adapters) |

## Deployment Infrastructure
- Add to `script/run/regenerate_bytecode.sh` `CORE_CONTRACTS` array
- Add `LZ_ENDPOINT` constant to `test/utils/Constants.sol`
- Add `StargateAdapter` deployment to `test/BaseTest.t.sol`
