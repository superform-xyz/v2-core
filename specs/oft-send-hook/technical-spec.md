# OFT Send Hook - Technical Specification

## Overview

Extend `StargateSendHook` and `ApproveAndStargateSendHook` to support generic LayerZero V2 OFT/OFTAdapter tokens via a mode flag in calldata. The immediate use case is the UP OFT token, but the solution is generic for any IOFT-compatible contract.

## Problem Statement

The existing Stargate hooks call `IStargate.sendToken()` which only works with Stargate pool contracts. Generic OFT tokens (like UP) use `IOFT.send()` with a different function selector. Both share the same `SendParam` struct layout and LayerZero V2 messaging infrastructure, but the hooks cannot currently route to `IOFT.send()`.

## Proposed Solution

Repurpose the `isBusMode` byte (offset 225) as a `uint8 mode` field:

| Mode | Behavior | Function Call |
|------|----------|--------------|
| 0 | Stargate taxi | `IStargate.sendToken()` with `oftCmd = bytes("")` |
| 1 | Stargate bus | `IStargate.sendToken()` with `oftCmd = abi.encodePacked(uint8(1))` |
| 2 | Generic OFT | `IOFT.send()` with `oftCmd = bytes("")` |
| >2 | Invalid | Revert |

**Benefits**: No data layout offset changes, same minimum data length (290 bytes), backward-compatible byte interpretation (0=taxi was false, 1=bus was true).

## Technical Considerations

### SendParam Struct Compatibility

Both `IStargate.SendParam` and `IOFT.SendParam` have identical fields (including `oftCmd`). For generic OFTs, `oftCmd` is always empty bytes. The struct layout in calldata is the same; only the function selector differs.

### msg.value Semantics (Critical)

| Hook | Stargate Mode (0/1) | OFT Mode (2) |
|------|---------------------|--------------|
| StargateSendHook (native) | `lzNativeFee + amountLD` | `lzNativeFee` only |
| ApproveAndStargateSendHook (ERC20) | `lzNativeFee` | `lzNativeFee` |

**StargateSendHook in OFT mode**: OFTs burn tokens from `msg.sender` internally. No `amountLD` in `msg.value`. Sending excess ETH to an OFT contract risks permanent loss.

**ApproveAndStargateSendHook**: No change - both modes use `lzNativeFee` only for ERC20 sends.

### Approval Target Semantics

| Mode | `stargatePool` field contains | Approval target |
|------|-------------------------------|-----------------|
| Stargate | Stargate pool address | Pool contract |
| OFT (OFTAdapter) | OFTAdapter address | OFTAdapter contract |
| OFT (native OFT) | OFT contract address | N/A (burns from caller) |

The `stargatePool` field at offset 64 serves double duty. In OFT mode it holds the OFT/OFTAdapter address.

### Pool/OFT Validation

Both `IStargate` and `IOFT` expose `token()`. The function selector is identical (`0xfc0c546a`), so existing validation calls work for both modes without interface casting changes:
- **StargateSendHook**: `IStargate(s.stargatePool).token()` (existence check) - works for OFTs too
- **ApproveAndStargateSendHook**: `IStargate(s.stargatePool).token() != s.inputToken` - works for OFTAdapters too (returns underlying token)

### OFT vs OFTAdapter Usage

| Chain | Contract | Hook | Why |
|-------|----------|------|-----|
| Ethereum | UpOFTAdapter | ApproveAndStargateSendHook (mode=2) | OFTAdapter needs approval (`transferFrom`) |
| Base | UpOFT | StargateSendHook (mode=2) | Native OFT burns from caller (no approval) |
| HyperEVM | UpOFT | StargateSendHook (mode=2) | Native OFT burns from caller |
| Flare | UpOFT | StargateSendHook (mode=2) | Native OFT burns from caller |

## Attack Surface Analysis

### Mode Flag Injection
- **Risk**: Wrong mode causes wrong function call or wrong msg.value
- **Mitigation**: `if (s.mode > 2) revert MODE_NOT_VALID()` — strict validation, revert on unknown values

### msg.value Divergence (Critical)
- **Risk**: Sending `lzNativeFee + amountLD` to OFT contract = excess ETH stuck permanently
- **Mitigation**: Separate value computation per mode branch; code paths are explicit

### Approval Target Divergence
- **Risk**: Malicious contract implementing IOFT could drain approved tokens
- **Mitigation**: Same trust model as Stargate (bundler trust + `token()` validation). `IOFT(oft).token() == inputToken` validation in ApproveAndStargateSendHook

### DVN Trust Model
- **Risk**: Generic OFTs may have weak DVN configs (1-of-1 DVN = compromisable)
- **Mitigation**: Document in SECURITY.md; hook cannot validate DVN quality (inherited from OFT deployer)

### Exploit Precedent
| Exploit | Loss | Relevance | Our Mitigation |
|---------|------|-----------|----------------|
| KelpDAO rsETH (Apr 2026) | $292M | 1-of-1 DVN compromise | Document DVN trust assumptions |
| Calldata Injection (Jan 2026) | $17M+ | Contracts with approvals + user-controlled data | Strict mode validation, fixed offsets |
| Cork Protocol (May 2025) | $11M | Hook callback authorization bypass | Existing validator pattern unchanged |

## Acceptance Criteria

- [ ] StargateSendHook supports `IOFT.send()` via mode=2
- [ ] ApproveAndStargateSendHook supports `IOFT.send()` via mode=2
- [ ] Mode 0/1 behavior identical to current (backward compatible)
- [ ] Mode >2 reverts with `MODE_NOT_VALID()`
- [ ] msg.value = `lzNativeFee` only in OFT mode (StargateSendHook)
- [ ] Existing Stargate unit tests pass unchanged
- [ ] New unit tests for OFT mode (mode=2)
- [ ] Fork integration tests using real UP OFT contracts
- [ ] ComposeMsg signature appending works in OFT mode
- [ ] IOFT vendor interface added
- [ ] Bytecode regenerated for updated hooks

## Implementation

### Phase 1: IOFT Interface

#### `src/vendor/bridges/layerzero/IOFT.sol` (new file)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IOFT
/// @notice Interface for LayerZero V2 OFT (Omnichain Fungible Token) contracts
/// @dev Used by StargateSendHook and ApproveAndStargateSendHook in OFT mode (mode=2)
interface IOFT {
    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    struct OFTReceipt {
        uint256 amountSentLD;
        uint256 amountReceivedLD;
    }

    /// @notice Send tokens cross-chain via LayerZero V2
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory);

    /// @notice Get the underlying token address
    /// @return For OFT: address(this). For OFTAdapter: underlying ERC20 address.
    function token() external view returns (address);
}
```

### Phase 2: StargateSendHook Changes

Key modifications to `src/hooks/bridges/stargate/StargateSendHook.sol`:

1. **Import IOFT**:
```solidity
import { IOFT } from "../../../vendor/bridges/layerzero/IOFT.sol";
```

2. **Struct change** — `bool isBusMode` → `uint8 mode`:
```solidity
struct StargateSendData {
    // ... unchanged fields ...
    uint8 mode;        // was: bool isBusMode
    // ... unchanged fields ...
}
```

3. **New error**:
```solidity
error MODE_NOT_VALID();
```

4. **Mode decoding + validation**:
```solidity
// was: s.isBusMode = _decodeBool(data, 225);
s.mode = uint8(data[225]);
if (s.mode > 2) revert MODE_NOT_VALID();
```

5. **Mode-branched execution building** (in the lzTokenFee > 0 path):
```solidity
if (s.mode <= 1) {
    // Stargate mode — existing code
    IStargate.SendParam memory sendParam = IStargate.SendParam({
        dstEid: s.dstEid, to: s.to, amountLD: s.amountLD, minAmountLD: s.minAmountLD,
        extraOptions: s.extraOptions, composeMsg: s.composeMsg,
        oftCmd: s.mode == 1 ? abi.encodePacked(uint8(1)) : bytes("")
    });
    IStargate.MessagingFee memory messagingFee = IStargate.MessagingFee({nativeFee: s.lzNativeFee, lzTokenFee: s.lzTokenFee});

    executions[N] = Execution({
        target: s.stargatePool,
        value: s.lzNativeFee + s.amountLD,  // native pool bundles token amount
        callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
    });
} else {
    // OFT mode
    IOFT.SendParam memory sendParam = IOFT.SendParam({
        dstEid: s.dstEid, to: s.to, amountLD: s.amountLD, minAmountLD: s.minAmountLD,
        extraOptions: s.extraOptions, composeMsg: s.composeMsg,
        oftCmd: bytes("")
    });
    IOFT.MessagingFee memory messagingFee = IOFT.MessagingFee({nativeFee: s.lzNativeFee, lzTokenFee: s.lzTokenFee});

    executions[N] = Execution({
        target: s.stargatePool,            // holds OFT address in mode=2
        value: s.lzNativeFee,              // OFT burns tokens, no amountLD in value
        callData: abi.encodeCall(IOFT.send, (sendParam, messagingFee, account))
    });
}
```

6. **Same pattern for lzTokenFee == 0 path** — only value and callData differ.

7. **NatSpec update** — `bool isBusMode` → `uint8 mode` in data layout documentation.

### Phase 3: ApproveAndStargateSendHook Changes

Key modifications to `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`:

1. **Import IOFT** (same as above)

2. **Struct change** — same `bool isBusMode` → `uint8 mode`

3. **New error** — same `MODE_NOT_VALID()`

4. **Mode decoding + validation** — same pattern

5. **Validation change** in `_buildHookExecutions`:
```solidity
if (s.mode <= 1) {
    // Stargate: pool's token must match inputToken
    if (IStargate(s.stargatePool).token() != s.inputToken) revert POOL_NOT_VALID();
} else {
    // OFT: OFT's underlying token must match inputToken
    // IOFT.token() returns underlying ERC20 for OFTAdapter
    if (IOFT(s.stargatePool).token() != s.inputToken) revert POOL_NOT_VALID();
}
```

Note: Since `token()` has the same selector for both interfaces, this could remain as `IStargate(s.stargatePool).token() != s.inputToken` for both modes. The explicit branching is for clarity and correctness.

6. **`_buildExecutions` changes** — branch on mode for the sendToken/send call:
```solidity
// In _buildExecutions, where the bridge call execution is built:

bytes memory sendCallData;

if (s.mode <= 1) {
    IStargate.SendParam memory sendParam = IStargate.SendParam({...});
    IStargate.MessagingFee memory messagingFee = IStargate.MessagingFee({...});
    sendCallData = abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account));
} else {
    IOFT.SendParam memory sendParam = IOFT.SendParam({...});
    IOFT.MessagingFee memory messagingFee = IOFT.MessagingFee({...});
    sendCallData = abi.encodeCall(IOFT.send, (sendParam, messagingFee, account));
}

// Then use sendCallData in the execution that was previously:
// abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
```

Note: `value` remains `s.lzNativeFee` for all ERC20 sends (no change needed).

### Phase 4: Unit Tests

Add to `test/unit/hooks/bridges/StargateHooks.t.sol`:

1. **Mode=2 basic send** (StargateSendHook) — mock `IOFT.send()`, verify calldata encoding
2. **Mode=2 basic send** (ApproveAndStargateSendHook) — mock `IOFT.send()`, verify approval target is OFT address
3. **Mode=2 with composeMsg** — verify signature appending works
4. **Mode=2 with lzTokenFee** — verify lzToken approval targets OFT address
5. **Mode=2 with usePrevHookAmount** — verify amount substitution works
6. **Mode>2 revert** — verify `MODE_NOT_VALID()` for invalid modes
7. **Mode=2 value check** (StargateSendHook) — verify `value = lzNativeFee` (not + amountLD)
8. **Mode=0/1 unchanged** — existing tests pass (regression)
9. **Mode=2 token validation** (ApproveAndStargateSendHook) — verify `POOL_NOT_VALID()` when `IOFT.token() != inputToken`

Update test helper: `_encodeStargateData(bool usePrevHookAmount, bool isBusMode, ...)` → `_encodeStargateData(bool usePrevHookAmount, uint8 mode, ...)`

### Phase 5: Fork Integration Tests

Add `test/integration/oft/OFTSendHookFork.t.sol`:

1. **Fork Ethereum mainnet** — test ApproveAndStargateSendHook with UpOFTAdapter (`0x722ff7C0665F4b1823c9C4cFcDF73A43de5865BD`)
2. **Fork Base** — test StargateSendHook with UpOFT (`0x5b2193fDc451C1f847bE09CA9d13A4Bf60f8c86B`)
3. Verify actual token transfer and LZ message emission
4. Test with compose message if feasible

### Phase 6: Bytecode & Deployment

1. Regenerate locked bytecode for both hooks
2. Same deployment keys (`STARGATE_SEND_HOOK_KEY`, `APPROVE_AND_STARGATE_SEND_HOOK_KEY`)
3. CREATE2 with updated bytecode = new addresses
4. Coordinate bundler update for new hook addresses

## Data Layout (Unchanged)

| Offset | Size | Field | Notes |
|--------|------|-------|-------|
| 0 | 32 | `uint256 lzNativeFee` | |
| 32 | 32 | `uint256 lzTokenFee` | |
| 64 | 20 | `address stargatePool` | OFT address in mode=2 |
| 84 | 20 | `address inputToken` | ApproveAndStargateSendHook only |
| 104 | 20 | `address lzToken` | |
| 124 | 4 | `uint32 dstEid` | |
| 128 | 32 | `bytes32 to` | |
| 160 | 32 | `uint256 amountLD` | |
| 192 | 32 | `uint256 minAmountLD` | |
| 224 | 1 | `bool usePrevHookAmount` | |
| 225 | 1 | `uint8 mode` | **Changed**: was `bool isBusMode` |
| 226 | 32 | `uint256 extraOptionsLength` | |
| 258 | var | `bytes extraOptions` | |
| 258+len | 32 | `uint256 composeMsgLength` | |
| 290+len | var | `bytes composeMsg` | |

Minimum data length: **290 bytes** (unchanged).

## Dependencies & Risks

- **Bundler coordination**: New hook addresses require bundler update before production use
- **Bytecode change**: Existing locked bytecode must be regenerated; new CREATE2 addresses
- **DVN trust**: Security of cross-chain transfer depends on OFT deployer's DVN configuration (outside our control)

## References & Research

### Internal References
- `src/hooks/bridges/stargate/StargateSendHook.sol` — current native send hook
- `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol` — current ERC20 send hook
- `src/vendor/bridges/stargate/IStargate.sol` — current Stargate interface
- `test/unit/hooks/bridges/StargateHooks.t.sol` — existing unit tests
- `.claude/doc/stargate-bridge-hook/implementation-plan.md` — original Stargate hook design

### External References
- [IOFT.sol (LayerZero devtools)](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/interfaces/IOFT.sol)
- [OFTAdapter.sol](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/OFTAdapter.sol)
- [OFT.sol](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/OFT.sol)

### Research
- [research/repo-analysis.md](./research/repo-analysis.md) — Repository patterns and mode flag design
- [research/framework-docs.md](./research/framework-docs.md) — IOFT interface, OFT vs OFTAdapter, msg.value requirements
- [research/evm-security.md](./research/evm-security.md) — Security analysis and exploit precedents
