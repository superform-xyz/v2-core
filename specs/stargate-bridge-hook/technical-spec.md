# Stargate V2 Bridge Hook - Technical Specification

## Overview

Implement two Stargate V2 bridge hook variants for Superform v2-core, enabling cross-chain token transfers via Stargate/LayerZero V2 with optional destination execution through LZ compose messages. Follows the same architectural patterns as the existing Across bridge hooks.

## Problem Statement / Motivation

Superform currently supports cross-chain bridging via Across and deBridge. Adding Stargate V2 (LayerZero) expands the bridge coverage to all Stargate-supported chains with competitive fees and different liquidity pools. Stargate V2 also enables bus mode for cheaper batched messaging.

## Proposed Solution

Two hook contracts following the established bridge hook pattern:
1. **StargateSendHook** - For native ETH bridging (value includes both fee + amount)
2. **ApproveAndStargateSendHook** - For ERC20 bridging with approval pattern

Both support destination execution via LayerZero compose messages with the same validator signature injection pattern used by Across/deBridge.

## Technical Considerations

### Key Architectural Difference from Across
- Stargate V2 has **per-token pool contracts** (StargatePoolUSDC, StargatePoolETH, etc.)
- Unlike Across (single SpokePool per chain stored in constructor), the `stargatePool` address comes from **hook data**, not the constructor
- Constructor only takes `validator_` - hooks deploy unconditionally on all chains
- No ConfigCore/ConfigBase changes needed

### LayerZero V2 Integration
- Uses `uint32 dstEid` (LZ endpoint IDs) instead of `uint256 chainId`
- Recipient is `bytes32` format (cross-VM support)
- `extraOptions` pre-computed by bundler (configures dst gas for compose)
- `oftCmd` controls taxi (empty) vs bus (`0x01`) mode

## Implementation

### File Structure
```
src/vendor/bridges/stargate/IStargate.sol
src/hooks/bridges/stargate/StargateSendHook.sol
src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol
test/unit/hooks/bridges/StargateHooks.t.sol
```

### 1. `src/vendor/bridges/stargate/IStargate.sol`

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

/// @title IStargate
/// @notice Interface for Stargate V2 pool contracts (per-token pools implementing OFT pattern)
interface IStargate {
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

    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory fee);

    function token() external view returns (address);
}
```

### 2. `src/hooks/bridges/stargate/StargateSendHook.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IStargate } from "../../../vendor/bridges/stargate/IStargate.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperSignatureStorage } from "../../../interfaces/ISuperSignatureStorage.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title StargateSendHook
/// @author Superform Labs
/// @dev Sends native tokens cross-chain via Stargate V2 with optional destination execution
/// @dev For native sends: msg.value = lzNativeFee + amountLD
/// @dev `composeMsg` won't contain the signature for the destination executor
/// @dev      signature is retrieved from the validator contract transient storage
/// @dev data layout:
/// @notice         uint256 lzNativeFee = BytesLib.toUint256(data, 0);
/// @notice         address stargatePool = BytesLib.toAddress(data, 32);
/// @notice         address inputToken = BytesLib.toAddress(data, 52);
/// @notice         uint32 dstEid = BytesLib.toUint32(data, 72);
/// @notice         bytes32 to = BytesLib.toBytes32(data, 76);
/// @notice         uint256 amountLD = BytesLib.toUint256(data, 108);
/// @notice         uint256 minAmountLD = BytesLib.toUint256(data, 140);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 172);
/// @notice         bool isBusMode = _decodeBool(data, 173);
/// @notice         uint256 extraOptionsLength = BytesLib.toUint256(data, 174);
/// @notice         bytes extraOptions = BytesLib.slice(data, 206, extraOptionsLength);
/// @notice         uint256 composeMsgLength = BytesLib.toUint256(data, 206 + extraOptionsLength);
/// @notice         bytes composeMsg = BytesLib.slice(data, 238 + extraOptionsLength, composeMsgLength);
contract StargateSendHook is BaseHook, ISuperHookContextAware {
    address private immutable VALIDATOR;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 172;

    error DATA_NOT_VALID();
    error POOL_NOT_VALID();

    constructor(address validator_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (validator_ == address(0)) revert ADDRESS_NOT_VALID();
        VALIDATOR = validator_;
    }

    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    ) internal view override returns (Execution[] memory executions) {
        if (data.length < 238) revert DATA_NOT_VALID();

        uint256 lzNativeFee = BytesLib.toUint256(data, 0);
        address stargatePool = BytesLib.toAddress(data, 32);
        uint32 dstEid = BytesLib.toUint32(data, 72);
        bytes32 to = BytesLib.toBytes32(data, 76);
        uint256 amountLD = BytesLib.toUint256(data, 108);
        uint256 minAmountLD = BytesLib.toUint256(data, 140);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        bool isBusMode = _decodeBool(data, 173);

        uint256 extraOptionsLength = BytesLib.toUint256(data, 174);
        bytes memory extraOptions = BytesLib.slice(data, 206, extraOptionsLength);

        uint256 composeMsgOffset = 206 + extraOptionsLength;
        uint256 composeMsgLength = BytesLib.toUint256(data, composeMsgOffset);
        bytes memory composeMsg = BytesLib.slice(data, composeMsgOffset + 32, composeMsgLength);

        if (usePrevHookAmount) {
            uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);
            if (amountLD > 0 && minAmountLD > 0) {
                minAmountLD = Math.mulDiv(minAmountLD, outAmount, amountLD);
            }
            amountLD = outAmount;
        }

        if (amountLD == 0) revert AMOUNT_NOT_VALID();
        if (stargatePool == address(0)) revert POOL_NOT_VALID();
        if (to == bytes32(0)) revert ADDRESS_NOT_VALID();

        // Append signature to composeMsg if present
        if (composeMsg.length > 0) {
            bytes memory signature = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account);
            (
                bytes memory initData,
                bytes memory executorCalldata,
                address _account,
                address[] memory dstTokens,
                uint256[] memory intentAmounts
            ) = abi.decode(composeMsg, (bytes, bytes, address, address[], uint256[]));
            composeMsg = abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts, signature);
        }

        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: dstEid,
            to: to,
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: isBusMode ? abi.encodePacked(uint8(1)) : bytes("")
        });

        IStargate.MessagingFee memory messagingFee = IStargate.MessagingFee({
            nativeFee: lzNativeFee,
            lzTokenFee: 0
        });

        executions = new Execution[](1);
        executions[0] = Execution({
            target: stargatePool,
            value: lzNativeFee + amountLD,
            callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
        });
    }

    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, 32),  // stargatePool
            BytesLib.toAddress(data, 52),  // inputToken
            address(uint160(uint256(BytesLib.toBytes32(data, 76))))  // to (as address)
        );
    }
}
```

### 3. `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`

Same as above but with approval pattern:
- Returns 4 executions: approve(0) -> approve(amountLD) -> sendToken() -> approve(0)
- Bridge execution `value` = `lzNativeFee` only (not `lzNativeFee + amountLD`)
- Approval target is `stargatePool` (it pulls tokens via transferFrom)
- Uses `inputToken` from data (offset 52) for approval calls

### Data Layout (Both Variants)

```
Offset  | Type      | Size | Field
--------|-----------|------|---------------------------
0       | uint256   | 32   | lzNativeFee
32      | address   | 20   | stargatePool
52      | address   | 20   | inputToken
72      | uint32    | 4    | dstEid (LZ V2 endpoint ID)
76      | bytes32   | 32   | to (recipient, bytes32 format)
108     | uint256   | 32   | amountLD
140     | uint256   | 32   | minAmountLD
172     | bool      | 1    | usePrevHookAmount
173     | bool      | 1    | isBusMode
174     | uint256   | 32   | extraOptionsLength
206     | bytes     | var  | extraOptions
206+eol | uint256   | 32   | composeMsgLength
238+eol | bytes     | var  | composeMsg
```

Minimum data length: **238 bytes** (with 0-length extraOptions and composeMsg)

## Value Calculations

| Variant | Execution Value | Reason |
|---------|----------------|--------|
| StargateSendHook (native) | `lzNativeFee + amountLD` | Pool needs ETH for both fee and bridged amount |
| ApproveAndStargateSendHook (ERC20) | `lzNativeFee` | Only LZ fee in msg.value; tokens pulled via approve |

## Acceptance Criteria

### Functional
- [ ] Send native tokens cross-chain via Stargate V2
- [ ] Send ERC20 tokens cross-chain with approval pattern
- [ ] Support destination execution via composeMsg with validator signature injection
- [ ] Support `usePrevHookAmount` with proportional minAmountLD scaling
- [ ] Support taxi and bus send modes
- [ ] Implement `ISuperHookContextAware.decodeUsePrevHookAmount()`
- [ ] Implement `ISuperHookInspector.inspect()` returning addresses only

### Validation
- [ ] Revert `DATA_NOT_VALID` if data < 238 bytes
- [ ] Revert `AMOUNT_NOT_VALID` if amountLD == 0
- [ ] Revert `POOL_NOT_VALID` if stargatePool == address(0)
- [ ] Revert `ADDRESS_NOT_VALID` if to == bytes32(0)

### Security
- [ ] Approval race condition mitigation (approve 0 → approve amount → execute → approve 0)
- [ ] Safe proportional scaling via Math.mulDiv
- [ ] Signature injection follows proven Across/deBridge pattern
- [ ] No hardcoded pool addresses (bundler-managed)
- [ ] Refund address set to account (excess LZ fee returned to user)

## Test Plan

### Unit Tests (`test/unit/hooks/bridges/StargateHooks.t.sol`)
- [ ] Constructor validation (zero validator reverts)
- [ ] Basic build for both variants (taxi/bus modes)
- [ ] `usePrevHookAmount` scaling (including minAmountLD)
- [ ] Validation reverts (short data, zero amount, zero pool, zero recipient)
- [ ] composeMsg signature appending
- [ ] Inspector output correctness
- [ ] `decodeUsePrevHookAmount` helper
- [ ] Approval pattern correctness (4 executions in right order)

## Deployment

- Add constants to `script/utils/Constants.sol`
- Deploy unconditionally (only needs validator, always available)
- No per-chain configuration needed
- Add to `script/run/regenerate_bytecode.sh`

## References

- Across bridge hooks: `src/hooks/bridges/across/`
- DeBridge bridge hooks: `src/hooks/bridges/debridge/`
- BaseHook: `src/hooks/BaseHook.sol`
- Existing bridge tests: `test/unit/hooks/bridges/BridgeHooks.t.sol`
- Stargate V2 docs: https://stargateprotocol.gitbook.io/stargate/v2
- LayerZero V2 compose: https://docs.layerzero.network/v2
