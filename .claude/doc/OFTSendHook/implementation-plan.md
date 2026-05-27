# OFT Send Hook - Implementation Plan

## Overview

Extend `StargateSendHook` and `ApproveAndStargateSendHook` to support generic LayerZero V2 OFT/OFTAdapter tokens by repurposing the `isBusMode` boolean as a `uint8 mode` field at the same byte offset (225).

**Branch**: `feat/cctp-bridge-hook` (current branch)
**Solidity Version**: 0.8.30
**Framework**: Foundry

---

## File Change Summary

| # | File | Action | Description |
|---|------|--------|-------------|
| 1 | `src/vendor/bridges/layerzero/IOFT.sol` | CREATE | New IOFT vendor interface |
| 2 | `src/hooks/bridges/stargate/StargateSendHook.sol` | MODIFY | Add OFT mode (mode=2) support |
| 3 | `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol` | MODIFY | Add OFT mode (mode=2) support |
| 4 | `test/unit/hooks/bridges/StargateHooks.t.sol` | MODIFY | Add OFT mode unit tests |
| 5 | `test/integration/stargate/StargateHooksFork.t.sol` | MODIFY | Add OFT fork integration tests |

---

## File 1: `src/vendor/bridges/layerzero/IOFT.sol` (NEW)

Create new directory `src/vendor/bridges/layerzero/` and add the IOFT interface.

### Exact File Content

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IOFT
/// @notice Interface for LayerZero V2 OFT (Omnichain Fungible Token) contracts
/// @dev Used by StargateSendHook and ApproveAndStargateSendHook in OFT mode (mode=2)
/// @dev Both OFT and OFTAdapter implement this interface. OFT burns tokens from the caller;
///      OFTAdapter locks tokens via transferFrom (requires approval).
/// @dev Reference: https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/interfaces/IOFT.sol
interface IOFT {
    /// @notice Parameters for sending tokens cross-chain (identical layout to IStargate.SendParam)
    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    /// @notice Fee structure for LayerZero V2 messaging
    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    /// @notice Receipt from LayerZero V2 messaging
    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    /// @notice Receipt from OFT send operation
    struct OFTReceipt {
        uint256 amountSentLD;
        uint256 amountReceivedLD;
    }

    /// @notice Send tokens cross-chain via LayerZero V2
    /// @param _sendParam The send parameters
    /// @param _fee The messaging fee
    /// @param _refundAddress Address to refund excess native fee
    /// @return msgReceipt The messaging receipt
    /// @return oftReceipt The OFT receipt with actual amounts
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);

    /// @notice Get the underlying token address
    /// @return For OFT: address(this). For OFTAdapter: underlying ERC20 address.
    /// @dev Selector 0xfc0c546a - identical to IStargate.token()
    function token() external view returns (address);
}
```

### Important Notes

- The `SendParam` struct has identical fields to `IStargate.SendParam` -- same names, same types, same order. But they are different Solidity types (different interface namespaces), so ABI encoding must use the correct type.
- The `send()` selector is `0xc7c7f5b3`, different from `IStargate.sendToken()` which is `0xcbef2aa9`.
- The `token()` selector is `0xfc0c546a` -- identical for both interfaces.
- `MessagingFee`, `MessagingReceipt`, `OFTReceipt` also have identical layouts to their IStargate counterparts.

---

## File 2: `src/hooks/bridges/stargate/StargateSendHook.sol` (MODIFY)

### Change 1: Add IOFT import (after line 7)

**After line 7** (`import { IStargate } from ...`), add:

```solidity
import { IOFT } from "../../../vendor/bridges/layerzero/IOFT.sol";
```

### Change 2: Update NatSpec - line 41

**Replace line 41:**
```solidity
/// @notice         bool isBusMode = _decodeBool(data, 225);
```
**With:**
```solidity
/// @notice         uint8 mode = uint8(data[225]);
```

### Change 3: Update struct field - line 62

**Replace line 62:**
```solidity
        bool isBusMode;
```
**With:**
```solidity
        uint8 mode;
```

### Change 4: Add MODE_NOT_VALID error (after line 75, alongside other errors)

Add after `error POOL_NOT_VALID();`:

```solidity
    /// @notice Thrown when the mode flag is not 0 (taxi), 1 (bus), or 2 (OFT)
    error MODE_NOT_VALID();
```

### Change 5: Update mode decoding - line 108

**Replace line 108:**
```solidity
        s.isBusMode = _decodeBool(data, 225);
```
**With:**
```solidity
        s.mode = uint8(data[225]);
        if (s.mode > 2) revert MODE_NOT_VALID();
```

### Change 6: Replace the execution building section (lines 159-209)

This is the core change. Replace everything from line 159 (`// Build SendParam`) through line 209 (the last execution before the closing brace of the function).

**Replace lines 159-209 with:**

```solidity
        // Build executions based on mode
        if (s.mode <= 1) {
            // Stargate mode (taxi=0, bus=1)
            IStargate.SendParam memory sendParam = IStargate.SendParam({
                dstEid: s.dstEid,
                to: s.to,
                amountLD: s.amountLD,
                minAmountLD: s.minAmountLD,
                extraOptions: s.extraOptions,
                composeMsg: s.composeMsg,
                oftCmd: s.mode == 1 ? abi.encodePacked(uint8(1)) : bytes("")
            });

            if (s.lzTokenFee > 0) {
                IStargate.MessagingFee memory messagingFee =
                    IStargate.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: s.lzTokenFee });

                executions = new Execution[](4);
                executions[0] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
                executions[1] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, s.lzTokenFee))
                });
                executions[2] = Execution({
                    target: s.stargatePool,
                    value: s.lzNativeFee + s.amountLD,
                    callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
                });
                executions[3] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
            } else {
                IStargate.MessagingFee memory messagingFee =
                    IStargate.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: 0 });

                executions = new Execution[](1);
                executions[0] = Execution({
                    target: s.stargatePool,
                    value: s.lzNativeFee + s.amountLD,
                    callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
                });
            }
        } else {
            // OFT mode (mode=2)
            // CRITICAL: value = lzNativeFee ONLY. OFT contracts burn tokens from msg.sender internally.
            // Sending amountLD in msg.value to an OFT contract risks permanent ETH loss.
            IOFT.SendParam memory sendParam = IOFT.SendParam({
                dstEid: s.dstEid,
                to: s.to,
                amountLD: s.amountLD,
                minAmountLD: s.minAmountLD,
                extraOptions: s.extraOptions,
                composeMsg: s.composeMsg,
                oftCmd: bytes("")
            });

            if (s.lzTokenFee > 0) {
                IOFT.MessagingFee memory messagingFee =
                    IOFT.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: s.lzTokenFee });

                executions = new Execution[](4);
                executions[0] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
                executions[1] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, s.lzTokenFee))
                });
                executions[2] = Execution({
                    target: s.stargatePool,
                    value: s.lzNativeFee,
                    callData: abi.encodeCall(IOFT.send, (sendParam, messagingFee, account))
                });
                executions[3] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
            } else {
                IOFT.MessagingFee memory messagingFee =
                    IOFT.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: 0 });

                executions = new Execution[](1);
                executions[0] = Execution({
                    target: s.stargatePool,
                    value: s.lzNativeFee,
                    callData: abi.encodeCall(IOFT.send, (sendParam, messagingFee, account))
                });
            }
        }
```

### Critical Notes for StargateSendHook

1. **msg.value difference is the most critical change**: In Stargate mode, `value = lzNativeFee + amountLD` (Stargate pool wraps native ETH internally). In OFT mode, `value = lzNativeFee` ONLY because OFT contracts burn tokens from the caller -- they do NOT accept native ETH as the token amount. Sending excess ETH to an OFT contract = permanent loss.

2. **The existing `IStargate(s.stargatePool).token()` validation on line 116 still works for OFT mode** because both IStargate and IOFT have the same `token()` selector (`0xfc0c546a`). The call verifies the contract exists and implements the interface.

3. **`oftCmd` for OFT mode is always `bytes("")`**. OFTs do not support bus mode -- that is a Stargate-specific concept.

4. **The `stargatePool` field at offset 64 holds the OFT contract address in mode=2**. This is documented in NatSpec but the variable name stays `stargatePool` for backward compatibility.

---

## File 3: `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol` (MODIFY)

### Change 1: Add IOFT import (after line 7)

**After line 7** (`import { IStargate } from ...`), add:

```solidity
import { IOFT } from "../../../vendor/bridges/layerzero/IOFT.sol";
```

### Change 2: Update NatSpec - line 43

**Replace line 43:**
```solidity
/// @notice         bool isBusMode = _decodeBool(data, 225);
```
**With:**
```solidity
/// @notice         uint8 mode = uint8(data[225]);
```

### Change 3: Update struct field - line 65

**Replace line 65:**
```solidity
        bool isBusMode;
```
**With:**
```solidity
        uint8 mode;
```

### Change 4: Add MODE_NOT_VALID error (after line 78, alongside other errors)

Add after `error POOL_NOT_VALID();`:

```solidity
    /// @notice Thrown when the mode flag is not 0 (taxi), 1 (bus), or 2 (OFT)
    error MODE_NOT_VALID();
```

### Change 5: Update mode decoding - line 112

**Replace line 112:**
```solidity
        s.isBusMode = _decodeBool(data, 225);
```
**With:**
```solidity
        s.mode = uint8(data[225]);
        if (s.mode > 2) revert MODE_NOT_VALID();
```

### Change 6: Update `_buildExecutions` private function (lines 194-327)

The existing `_buildExecutions` function constructs `IStargate.SendParam` and `IStargate.sendToken` calldata at the top, then uses it across all lzTokenFee branches. For OFT mode, we need `IOFT.SendParam` and `IOFT.send` calldata instead.

**Strategy**: Compute the `sendCallData` bytes before entering the lzTokenFee branches, then use the pre-computed calldata uniformly. This avoids duplicating the entire 3-branch lzTokenFee logic.

**Replace lines 194-327 with:**

```solidity
    /// @dev Builds execution calls with approval pattern
    /// @dev lzTokenFee == 0: approve(0) -> approve(amount) -> send/sendToken -> approve(0) [4 executions]
    /// @dev lzTokenFee > 0 && inputToken == lzToken: combined approval for amountLD + lzTokenFee [4 executions]
    /// @dev lzTokenFee > 0 && inputToken != lzToken: separate approvals [7 executions]
    function _buildExecutions(
        StargateSendData memory s,
        address account
    )
        private
        pure
        returns (Execution[] memory executions)
    {
        // Pre-compute the bridge call data based on mode
        bytes memory sendCallData;

        if (s.mode <= 1) {
            // Stargate mode (taxi=0, bus=1)
            IStargate.SendParam memory sendParam = IStargate.SendParam({
                dstEid: s.dstEid,
                to: s.to,
                amountLD: s.amountLD,
                minAmountLD: s.minAmountLD,
                extraOptions: s.extraOptions,
                composeMsg: s.composeMsg,
                oftCmd: s.mode == 1 ? abi.encodePacked(uint8(1)) : bytes("")
            });
            IStargate.MessagingFee memory messagingFee =
                IStargate.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: s.lzTokenFee });
            sendCallData = abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account));
        } else {
            // OFT mode (mode=2)
            IOFT.SendParam memory sendParam = IOFT.SendParam({
                dstEid: s.dstEid,
                to: s.to,
                amountLD: s.amountLD,
                minAmountLD: s.minAmountLD,
                extraOptions: s.extraOptions,
                composeMsg: s.composeMsg,
                oftCmd: bytes("")
            });
            IOFT.MessagingFee memory messagingFee =
                IOFT.MessagingFee({ nativeFee: s.lzNativeFee, lzTokenFee: s.lzTokenFee });
            sendCallData = abi.encodeCall(IOFT.send, (sendParam, messagingFee, account));
        }

        if (s.lzTokenFee > 0) {
            if (s.inputToken == s.lzToken) {
                // Same token for bridge amount and LZ fee: combine into single approval
                // Pool pulls amountLD (for bridging) + lzTokenFee (forwarded to LZ endpoint)
                uint256 combinedAmount = s.amountLD + s.lzTokenFee;

                executions = new Execution[](4);
                executions[0] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
                executions[1] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, combinedAmount))
                });
                executions[2] = Execution({
                    target: s.stargatePool,
                    value: s.lzNativeFee,
                    callData: sendCallData
                });
                executions[3] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
            } else {
                // Different tokens: separate approval sequences (7 executions)
                executions = new Execution[](7);

                // Input token approval
                executions[0] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
                executions[1] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, s.amountLD))
                });

                // LZ token approval (pool pulls via safeTransferFrom to endpoint)
                executions[2] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
                executions[3] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, s.lzTokenFee))
                });

                // Bridge call (value = lzNativeFee only for ERC20)
                executions[4] = Execution({
                    target: s.stargatePool,
                    value: s.lzNativeFee,
                    callData: sendCallData
                });

                // Cleanup LZ token approval
                executions[5] = Execution({
                    target: s.lzToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });

                // Cleanup input token approval
                executions[6] = Execution({
                    target: s.inputToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
                });
            }
        } else {
            // ERC20 only: 4 executions
            executions = new Execution[](4);

            // Execution 0: Reset approval to 0 (prevents approval race conditions)
            executions[0] = Execution({
                target: s.inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
            });

            // Execution 1: Approve exact amount
            executions[1] = Execution({
                target: s.inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (s.stargatePool, s.amountLD))
            });

            // Execution 2: Bridge call (value = lzNativeFee only for ERC20)
            executions[2] = Execution({
                target: s.stargatePool,
                value: s.lzNativeFee,
                callData: sendCallData
            });

            // Execution 3: Cleanup approval to 0
            executions[3] = Execution({
                target: s.inputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (s.stargatePool, 0))
            });
        }
    }
```

### Critical Notes for ApproveAndStargateSendHook

1. **msg.value is `lzNativeFee` for ALL modes in this hook** -- both Stargate ERC20 and OFT mode use the same value. This is because ERC20 tokens are pulled via `transferFrom` (Stargate) or `transferFrom`/`burn` (OFTAdapter), never sent as native ETH.

2. **The refactoring approach**: Pre-compute `sendCallData` bytes before entering the lzTokenFee branching. This avoids duplicating the entire 3-way branch (lzTokenFee == 0 / lzTokenFee > 0 same token / lzTokenFee > 0 different token) for each mode. The `sendCallData` encodes either `IStargate.sendToken(...)` or `IOFT.send(...)` depending on mode, then the same calldata is used across all branches.

3. **The existing pool validation on line 121 (`IStargate(s.stargatePool).token() != s.inputToken`) works unchanged for OFT mode** because `token()` has the same selector `0xfc0c546a`. The staticcall to `IStargate(s.stargatePool).token()` will actually call the OFT contract's `token()` function, which returns the underlying ERC20 address for OFTAdapter contracts. This is exactly what we need -- we verify the OFTAdapter's underlying token matches the `inputToken`. No need to branch the validation.

4. **Approval targets remain `s.stargatePool`** in all modes. For OFTAdapter mode, the OFTAdapter contract needs approval to pull tokens via `transferFrom`, so approving the OFTAdapter address (stored in `s.stargatePool`) is correct.

---

## File 4: `test/unit/hooks/bridges/StargateHooks.t.sol` (MODIFY)

### Change 1: Add IOFT import (after line 7)

After the IStargate import, add:

```solidity
import { IOFT } from "../../../../src/vendor/bridges/layerzero/IOFT.sol";
```

### Change 2: Update `_encodeStargateData` helper (lines 1090-1117)

**Replace the entire function** with a version that accepts `uint8 mode` instead of `bool isBusMode`:

```solidity
    function _encodeStargateData(
        bool usePrevHookAmount,
        uint8 mode,
        bool includeComposeMsg
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory composeMsg;
        if (includeComposeMsg) {
            address[] memory dstTokens = new address[](1);
            dstTokens[0] = mockInputToken;
            uint256[] memory intentAmounts = new uint256[](1);
            intentAmounts[0] = mockAmountLD;
            composeMsg = abi.encode(bytes("0x123"), bytes("0x456"), mockAccount, dstTokens, intentAmounts);
        }

        // Split encoding to avoid stack too deep
        bytes memory fixedPart = abi.encodePacked(
            mockLzNativeFee, uint256(0), mockStargatePool, mockInputToken, address(0), mockDstEid, mockTo,
            mockAmountLD, mockMinAmountLD
        );
        return abi.encodePacked(
            fixedPart, usePrevHookAmount, mode, uint256(mockExtraOptions.length), mockExtraOptions,
            uint256(composeMsg.length), composeMsg
        );
    }
```

### Change 3: Update ALL existing callers of `_encodeStargateData`

Every existing call to `_encodeStargateData(bool, bool, bool)` must be updated to `_encodeStargateData(bool, uint8, bool)`.

The mapping is: `false` (was isBusMode=false, taxi) becomes `uint8(0)`, and `true` (was isBusMode=true, bus) becomes `uint8(1)`.

**List of all call sites that need updating** (search for `_encodeStargateData`):

| Line | Old Call | New Call |
|------|---------|---------|
| 94 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 104 | `_encodeStargateData(false, true, false)` | `_encodeStargateData(false, 1, false)` |
| 113 | `_encodeStargateData(false, false, true)` | `_encodeStargateData(false, 0, true)` |
| 125 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 147 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |
| 165 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |
| 229 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |
| 240 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 253 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |
| 257 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 278 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 305 | `_encodeStargateData(false, false, true)` | `_encodeStargateData(false, 0, true)` |
| 323 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |
| 343 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 355 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 378 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 407 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 418 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 440 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 452 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |
| 464 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |
| 474 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |
| 486 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |
| 824 | `_encodeStargateData(false, true, false)` | `_encodeStargateData(false, 1, false)` |
| 828 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 840 | `_encodeStargateData(false, false, false)` | `_encodeStargateData(false, 0, false)` |
| 872 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |
| 888 | `_encodeStargateData(true, false, false)` | `_encodeStargateData(true, 0, false)` |

**Additionally**, the inline `abi.encodePacked` calls in tests that manually encode data (e.g., lines 496-512) use `false, false` for `usePrevHookAmount, isBusMode`. The second `false` at offset 225 encodes as `0x00` which is mode=0 (taxi). These tests DO NOT need changes because `false` encodes to `0x00` = mode 0, which is valid. However, there are also some tests that use `false, false` where the second bool was isBusMode -- these also encode as `0x00` and remain correct. No manual encoding changes needed for inline tests.

**CRITICAL VERIFICATION**: Search for all `false, false` patterns in the inline `abi.encodePacked` calls. The byte value `0x00` from `false` is identical to the byte value from `uint8(0)`, so all existing inline encodings produce correct mode=0 data. No changes needed for inline-encoded test data.

### Change 4: Add new OFT mode tests

Add the following test functions BEFORE the `HELPER FUNCTIONS` section (before line 1086):

```solidity
    /*//////////////////////////////////////////////////////////////
                         OFT MODE (MODE=2) TESTS
    //////////////////////////////////////////////////////////////*/

    // --- StargateSendHook OFT mode ---

    function test_StargateSend_Build_OFTMode() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // preExecute + IOFT.send + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, mockStargatePool);

        // CRITICAL: OFT mode value = lzNativeFee ONLY (not + amountLD)
        assertEq(executions[1].value, mockLzNativeFee);

        // Verify selector is IOFT.send, not IStargate.sendToken
        assertEq(bytes4(executions[1].callData), IOFT.send.selector);
    }

    function test_StargateSend_Build_OFTMode_ValueIsLzNativeFeeOnly() public view {
        // Explicitly verify the critical msg.value difference between modes
        bytes memory stargateData = _encodeStargateData(false, 0, false);
        Execution[] memory stargateExecs = stargateHook.build(address(0), mockAccount, stargateData);

        bytes memory oftData = _encodeStargateData(false, 2, false);
        Execution[] memory oftExecs = stargateHook.build(address(0), mockAccount, oftData);

        // Stargate: value = lzNativeFee + amountLD
        assertEq(stargateExecs[1].value, mockLzNativeFee + mockAmountLD);

        // OFT: value = lzNativeFee ONLY
        assertEq(oftExecs[1].value, mockLzNativeFee);
    }

    function test_StargateSend_Build_OFTMode_WithComposeMsg() public view {
        bytes memory data = _encodeStargateData(false, 2, true);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(bytes4(executions[1].callData), IOFT.send.selector);
        // value still lzNativeFee only
        assertEq(executions[1].value, mockLzNativeFee);
    }

    function test_StargateSend_Build_OFTMode_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, 2, false);
        Execution[] memory executions = stargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 3);
        // OFT mode: value = lzNativeFee only (prevHookAmount NOT added to value)
        assertEq(executions[1].value, mockLzNativeFee);
        assertEq(bytes4(executions[1].callData), IOFT.send.selector);
    }

    function test_StargateSend_Build_OFTMode_WithLzTokenFee() public {
        address mockLzToken = makeAddr("lzToken");
        uint256 lzTokenFee = 1e18;
        bytes memory fixedPart = abi.encodePacked(
            mockLzNativeFee, lzTokenFee, mockStargatePool, mockInputToken, mockLzToken, mockDstEid, mockTo,
            mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(2), uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // pre + 4 hook executions + post = 6
        assertEq(executions.length, 6);

        // Execution 1: approve(lzToken, pool, 0)
        assertEq(executions[1].target, mockLzToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));

        // Execution 2: approve(lzToken, pool, lzTokenFee)
        assertEq(executions[2].target, mockLzToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, lzTokenFee)));

        // Execution 3: IOFT.send (value = lzNativeFee ONLY for OFT)
        assertEq(executions[3].target, mockStargatePool);
        assertEq(executions[3].value, mockLzNativeFee);
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);

        // Execution 4: approve(lzToken, pool, 0) cleanup
        assertEq(executions[4].target, mockLzToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));
    }

    // --- ApproveAndStargateSendHook OFT mode ---

    function test_ApproveAndStargateSend_Build_OFTMode() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        // preExecute + approve(0) + approve(amount) + IOFT.send + approve(0) + postExecute = 6
        assertEq(executions.length, 6);

        // Execution 1: approve(inputToken, pool/OFT, 0)
        assertEq(executions[1].target, mockInputToken);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));

        // Execution 2: approve(inputToken, pool/OFT, amountLD)
        assertEq(executions[2].target, mockInputToken);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, mockAmountLD)));

        // Execution 3: IOFT.send (value = lzNativeFee)
        assertEq(executions[3].target, mockStargatePool);
        assertEq(executions[3].value, mockLzNativeFee);
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);

        // Execution 4: approve(inputToken, pool/OFT, 0)
        assertEq(executions[4].target, mockInputToken);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, 0)));
    }

    function test_ApproveAndStargateSend_Build_OFTMode_WithComposeMsg() public view {
        bytes memory data = _encodeStargateData(false, 2, true);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 6);
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);
    }

    function test_ApproveAndStargateSend_Build_OFTMode_WithPrevHookAmount() public {
        uint256 prevHookAmount = 2000e6;

        mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, mockInputToken));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.mockCall(
            mockPrevHook, abi.encodeWithSelector(ISuperHookResult.getOutAmount.selector), abi.encode(prevHookAmount)
        );

        bytes memory data = _encodeStargateData(true, 2, false);
        Execution[] memory executions = approveAndStargateHook.build(mockPrevHook, mockAccount, data);

        assertEq(executions.length, 6);
        // Approval should use prevHookAmount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (mockStargatePool, prevHookAmount)));
        // Value should be lzNativeFee only
        assertEq(executions[3].value, mockLzNativeFee);
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);
    }

    function test_ApproveAndStargateSend_Build_OFTMode_WithLzTokenFee() public {
        address mockLzToken = makeAddr("lzToken");
        uint256 lzTokenFee = 1e18;
        bytes memory fixedPart = abi.encodePacked(
            mockLzNativeFee, lzTokenFee, mockStargatePool, mockInputToken, mockLzToken, mockDstEid, mockTo,
            mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(2), uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        // pre + 7 hook executions + post = 9
        assertEq(executions.length, 9);

        // Execution 5: IOFT.send (value = lzNativeFee only)
        assertEq(executions[5].target, mockStargatePool);
        assertEq(executions[5].value, mockLzNativeFee);
        assertEq(bytes4(executions[5].callData), IOFT.send.selector);
    }

    function test_ApproveAndStargateSend_Build_OFTMode_WithLzTokenFee_SameToken() public {
        uint256 lzTokenFee = 1e18;
        bytes memory fixedPart = abi.encodePacked(
            mockLzNativeFee, lzTokenFee, mockStargatePool, mockInputToken, mockInputToken, mockDstEid, mockTo,
            mockAmountLD, mockMinAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart, false, uint8(2), uint256(mockExtraOptions.length), mockExtraOptions, uint256(0)
        );

        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        // Combined approval path: pre + 4 hook executions + post = 6
        assertEq(executions.length, 6);

        // Execution 2: approve(inputToken, pool, amountLD + lzTokenFee)
        assertEq(
            executions[2].callData,
            abi.encodeCall(IERC20.approve, (mockStargatePool, mockAmountLD + lzTokenFee))
        );

        // Execution 3: IOFT.send
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);
    }

    function test_ApproveAndStargateSend_Build_OFTMode_TokenValidation() public {
        // OFT's token() must match inputToken, same as Stargate mode
        address wrongToken = makeAddr("wrongToken");
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(wrongToken));

        bytes memory data = _encodeStargateData(false, 2, false);

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);

        // Restore
        vm.mockCall(mockStargatePool, abi.encodeWithSelector(IStargate.token.selector), abi.encode(mockInputToken));
    }

    // --- Mode validation tests (both hooks) ---

    function test_StargateSend_Build_RevertIf_ModeInvalid() public {
        bytes memory data = _encodeStargateData(false, 3, false);

        vm.expectRevert(StargateSendHook.MODE_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_StargateSend_Build_RevertIf_ModeMax() public {
        bytes memory data = _encodeStargateData(false, 255, false);

        vm.expectRevert(StargateSendHook.MODE_NOT_VALID.selector);
        stargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_ModeInvalid() public {
        bytes memory data = _encodeStargateData(false, 3, false);

        vm.expectRevert(ApproveAndStargateSendHook.MODE_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    function test_ApproveAndStargateSend_Build_RevertIf_ModeMax() public {
        bytes memory data = _encodeStargateData(false, 255, false);

        vm.expectRevert(ApproveAndStargateSendHook.MODE_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), mockAccount, data);
    }

    // --- OFT mode selector verification ---

    function test_StargateSend_OFTMode_UsesCorrectSelector() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // IOFT.send selector = 0xc7c7f5b3
        assertEq(bytes4(executions[1].callData), IOFT.send.selector);
        // Verify it's NOT IStargate.sendToken selector
        assertTrue(bytes4(executions[1].callData) != IStargate.sendToken.selector);
    }

    function test_ApproveAndStargateSend_OFTMode_UsesCorrectSelector() public view {
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = approveAndStargateHook.build(address(0), mockAccount, data);

        // IOFT.send selector = 0xc7c7f5b3
        assertEq(bytes4(executions[3].callData), IOFT.send.selector);
        assertTrue(bytes4(executions[3].callData) != IStargate.sendToken.selector);
    }

    // --- OFT mode oftCmd always empty ---

    function test_StargateSend_OFTMode_OftCmdIsEmpty() public view {
        // In OFT mode, oftCmd should always be bytes(""), never bus mode encoding
        bytes memory data = _encodeStargateData(false, 2, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        // The calldata should encode IOFT.send with empty oftCmd
        // We verify this indirectly: OFT mode should produce different calldata than bus mode
        bytes memory busData = _encodeStargateData(false, 1, false);
        Execution[] memory busExecs = stargateHook.build(address(0), mockAccount, busData);

        // Different selectors already guarantee different calldata
        assertTrue(bytes4(executions[1].callData) != bytes4(busExecs[1].callData));
    }

    // --- Backward compatibility ---

    function test_StargateSend_Mode0_IdenticalToOriginalTaxi() public view {
        // Mode=0 should produce identical behavior to the old false (taxi) mode
        bytes memory data = _encodeStargateData(false, 0, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].value, mockLzNativeFee + mockAmountLD);
        assertEq(bytes4(executions[1].callData), IStargate.sendToken.selector);
    }

    function test_StargateSend_Mode1_IdenticalToOriginalBus() public view {
        // Mode=1 should produce identical behavior to the old true (bus) mode
        bytes memory data = _encodeStargateData(false, 1, false);
        Execution[] memory executions = stargateHook.build(address(0), mockAccount, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].value, mockLzNativeFee + mockAmountLD);
        assertEq(bytes4(executions[1].callData), IStargate.sendToken.selector);
    }
```

### Change 5: Update inline encoded data in lzTokenFee tests

The tests at lines 946-948 and 981-982 use inline `abi.encodePacked(..., false, false, ...)` where the second `false` was `isBusMode`. These encode `0x00` which equals `uint8(0)` (taxi mode). They are correct as-is for testing Stargate mode but should be explicitly annotated for clarity. No code change needed -- just a comment audit.

However, if you want to be explicit in those tests, you can replace `false, false` with `false, uint8(0)` in the inline encodings. This is OPTIONAL but recommended for readability:

Lines 947, 982, 1027, 1043, 1079:
- Replace second `false` with `uint8(0)` in `abi.encodePacked` calls for clarity.

---

## File 5: `test/integration/stargate/StargateHooksFork.t.sol` (MODIFY)

### Add OFT fork integration tests

Add the following at the end of the test contract, before the closing brace:

```solidity
    /*//////////////////////////////////////////////////////////////
                    OFT MODE FORK TESTS
    //////////////////////////////////////////////////////////////*/

    // UP OFTAdapter on Ethereum mainnet
    address public constant UP_OFT_ADAPTER_ETH = 0x722ff7C0665F4b1823c9C4cFcDF73A43de5865BD;
    // UP token on Ethereum (underlying token for OFTAdapter)
    // Retrieve dynamically via IOFT(UP_OFT_ADAPTER_ETH).token()

    /// @notice Verify UP OFTAdapter implements token() interface
    function test_Fork_OFTAdapter_TokenInterface() public view {
        address underlyingToken = IStargate(UP_OFT_ADAPTER_ETH).token();
        assertTrue(underlyingToken != address(0), "OFTAdapter should return underlying token");
        // Verify the token is a valid ERC20
        uint256 totalSupply = IERC20(underlyingToken).totalSupply();
        assertGt(totalSupply, 0, "Underlying token should have non-zero supply");
    }

    /// @notice Test ApproveAndStargateSendHook build() with OFT mode against real OFTAdapter
    function test_Fork_ApproveAndStargateSend_OFTMode_Build() public view {
        address upToken = IStargate(UP_OFT_ADAPTER_ETH).token();
        uint256 amountLD = 1000e18; // UP tokens (18 decimals)
        uint256 minAmountLD = 990e18; // 1% slippage
        uint32 dstEid = 30_184; // Base
        bytes32 to = bytes32(uint256(uint160(account)));
        uint256 lzNativeFee = 0.01 ether;

        bytes memory fixedPart = abi.encodePacked(
            lzNativeFee,
            uint256(0), // lzTokenFee
            UP_OFT_ADAPTER_ETH, // stargatePool field = OFTAdapter address
            upToken, // inputToken
            address(0), // lzToken
            dstEid,
            to,
            amountLD,
            minAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart,
            false, // usePrevHookAmount
            uint8(2), // mode = OFT
            uint256(2), // extraOptionsLength
            hex"0003", // extraOptions
            uint256(0) // composeMsgLength
        );

        // This should succeed - build() is view, validates OFTAdapter.token() == inputToken
        Execution[] memory executions = approveAndStargateHook.build(address(0), account, data);

        // preExecute + approve(0) + approve(amount) + IOFT.send + approve(0) + postExecute = 6
        assertEq(executions.length, 6);
        assertEq(executions[3].target, UP_OFT_ADAPTER_ETH);
        assertEq(executions[3].value, lzNativeFee);
    }

    /// @notice Test that OFT mode correctly rejects when token doesn't match
    function test_Fork_ApproveAndStargateSend_OFTMode_RevertIf_WrongToken() public {
        uint256 amountLD = 1000e18;
        uint256 minAmountLD = 990e18;
        uint32 dstEid = 30_184;
        bytes32 to = bytes32(uint256(uint160(account)));
        uint256 lzNativeFee = 0.01 ether;

        bytes memory fixedPart = abi.encodePacked(
            lzNativeFee,
            uint256(0),
            UP_OFT_ADAPTER_ETH,
            USDC_ETH, // WRONG token - UP OFTAdapter wraps UP, not USDC
            address(0),
            dstEid,
            to,
            amountLD,
            minAmountLD
        );
        bytes memory data = abi.encodePacked(
            fixedPart,
            false,
            uint8(2),
            uint256(2),
            hex"0003",
            uint256(0)
        );

        vm.expectRevert(ApproveAndStargateSendHook.POOL_NOT_VALID.selector);
        approveAndStargateHook.build(address(0), account, data);
    }
```

### Integration test notes

- The fork tests use `build()` which is a `view` function -- it generates execution arrays without executing them. This validates that the hook correctly builds the right calldata against real on-chain contracts.
- Actual execution tests (sending tokens cross-chain) require funding the account with UP tokens and executing through EntryPoint, which is more complex. The `build()` validation is the most important gate.
- The `IStargate(UP_OFT_ADAPTER_ETH).token()` call works because both interfaces share the same `token()` selector.

---

## Execution Order

1. **Create** `src/vendor/bridges/layerzero/IOFT.sol`
2. **Modify** `src/hooks/bridges/stargate/StargateSendHook.sol` (import, struct, error, decoding, execution building)
3. **Modify** `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol` (import, struct, error, decoding, _buildExecutions)
4. **Modify** `test/unit/hooks/bridges/StargateHooks.t.sol` (import, helper signature, update all callers, add OFT tests)
5. **Modify** `test/integration/stargate/StargateHooksFork.t.sol` (add OFT fork tests)
6. **Run** `forge build` to verify compilation
7. **Run** `make forge-test TEST=StargateHooks` to verify all unit tests pass
8. **Run** `make forge-test TEST=StargateHooksFork` (requires `ETHEREUM_RPC_URL` in `.env`)

---

## Security Considerations

1. **msg.value divergence is the #1 risk**: StargateSendHook Stargate mode uses `lzNativeFee + amountLD` while OFT mode uses `lzNativeFee` only. The code paths are explicitly separated (if/else on `s.mode <= 1` vs else), making the distinction unambiguous.

2. **Mode validation**: `if (s.mode > 2) revert MODE_NOT_VALID()` prevents unknown mode values from falling through to OFT mode, which would be the default else branch.

3. **token() validation**: The existing `IStargate(s.stargatePool).token()` call works unchanged for OFT contracts because the selector is identical. This provides the same level of on-chain interface validation.

4. **No new trust assumptions**: The trust model is unchanged -- the bundler is trusted to provide correct calldata. OFT contracts receive the same level of trust as Stargate pools.

5. **Backward compatibility**: Mode 0 and 1 produce identical byte-for-byte output to the current implementation. The `false`/`true` boolean encoding maps directly to `0x00`/`0x01` uint8 encoding.

---

## Gas Impact

- **Mode 0/1**: Near-zero gas increase. One additional `if (s.mode > 2)` check (~3 gas for `GT` + `JUMPI`).
- **Mode 2**: Similar gas to modes 0/1. The `IOFT.SendParam` construction is identical in cost to `IStargate.SendParam`. The `abi.encodeCall(IOFT.send, ...)` is the same cost as `abi.encodeCall(IStargate.sendToken, ...)`.
- **ApproveAndStargateSendHook**: Minor gas increase from pre-computing `sendCallData` in a `bytes memory` variable before the lzTokenFee branching. This adds one memory allocation but avoids code duplication.
