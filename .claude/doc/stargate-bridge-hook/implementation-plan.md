# Stargate V2 Bridge Hook - Implementation Plan

## Date: 2026-05-05
## Branch: `pre-dev` (MUST be on this branch)

---

## Overview

Implement two Stargate V2 bridge hook variants for Superform v2-core, enabling cross-chain token transfers via Stargate/LayerZero V2 with optional destination execution through LZ compose messages. Follows the same architectural patterns as the existing Across bridge hooks.

---

## Files to Create

### 1. `src/vendor/bridges/stargate/IStargate.sol`

**Purpose**: Vendor interface for Stargate V2's IStargate contract (sendToken function and related structs).

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

/// @title IStargate
/// @notice Interface for Stargate V2 pool contracts (per-token pools implementing OFT pattern)
/// @dev Each token has its own Stargate pool contract (e.g., StargatePoolUSDC, StargatePoolETH)
interface IStargate {
    /// @notice Parameters for sending tokens cross-chain
    struct SendParam {
        uint32 dstEid;           // LayerZero V2 endpoint ID for destination chain
        bytes32 to;              // Recipient address on destination (bytes32 for cross-VM)
        uint256 amountLD;        // Amount to send in local decimals
        uint256 minAmountLD;     // Minimum amount to receive on destination in local decimals
        bytes extraOptions;      // LayerZero V2 executor options (gas, value for dst)
        bytes composeMsg;        // Compose message for destination execution
        bytes oftCmd;            // OFT command: empty = taxi mode, non-empty = bus mode
    }

    /// @notice Fee structure for LayerZero V2 messaging
    struct MessagingFee {
        uint256 nativeFee;       // Fee in native token
        uint256 lzTokenFee;      // Fee in LZ token (typically 0)
    }

    /// @notice Receipt from LayerZero V2 messaging
    struct MessagingReceipt {
        bytes32 guid;            // Global unique identifier
        uint64 nonce;            // Message nonce
        MessagingFee fee;        // Actual fee paid
    }

    /// @notice Receipt from OFT send operation
    struct OFTReceipt {
        uint256 amountSentLD;    // Actual amount sent (after dust removal)
        uint256 amountReceivedLD; // Amount to be received on destination
    }

    /// @notice Send tokens cross-chain via Stargate/LayerZero V2
    /// @param _sendParam The send parameters
    /// @param _fee The messaging fee
    /// @param _refundAddress Address to refund excess native fee
    /// @return msgReceipt The messaging receipt
    /// @return oftReceipt The OFT receipt with actual amounts
    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);

    /// @notice Quote the messaging fee for a send operation
    /// @param _sendParam The send parameters
    /// @param _payInLzToken Whether to pay in LZ token
    /// @return fee The estimated messaging fee
    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory fee);

    /// @notice Get the underlying token address for this pool
    /// @return The ERC20 token address (or address(0) for native pools)
    function token() external view returns (address);
}
```

---

### 2. `src/hooks/bridges/stargate/StargateSendHook.sol`

**Purpose**: Bridge native tokens (ETH) cross-chain via Stargate V2 with optional destination execution via LZ compose.

**Key Design Decisions**:
- Constructor only takes `validator_` (not a pool address) because Stargate V2 has per-token pools and the bundler selects the appropriate one
- Pool address (`stargatePool`) is passed in hook data
- For native sends: `value` = `lzNativeFee + amountLD` (must send ETH for both fee and bridged amount)
- `oftCmd` is derived from `isBusMode` flag: taxi = `""`, bus = `abi.encodePacked(uint8(1))`

**NatSpec Data Layout**:
```solidity
/// @dev data has the following structure
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
```

**Implementation Skeleton**:
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
/// @dev For native token sends, msg.value = lzNativeFee + amountLD
/// @dev `composeMsg` field won't contain the signature for the destination executor
/// @dev      signature is retrieved from the validator contract transient storage
/// @dev      This is needed to avoid circular dependency between merkle root which contains the signature needed to sign it
/// @dev data has the following structure
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
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address private immutable VALIDATOR;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 172;

    struct StargateSendData {
        uint256 lzNativeFee;
        address stargatePool;
        address inputToken;
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bool usePrevHookAmount;
        bool isBusMode;
        bytes extraOptions;
        bytes composeMsg;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DATA_NOT_VALID();
    error POOL_NOT_VALID();

    constructor(address validator_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE) {
        if (validator_ == address(0)) revert ADDRESS_NOT_VALID();
        VALIDATOR = validator_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        // 1. Validate minimum data length
        if (data.length < 238) revert DATA_NOT_VALID();

        // 2. Decode data
        StargateSendData memory sendData;
        sendData.lzNativeFee = BytesLib.toUint256(data, 0);
        sendData.stargatePool = BytesLib.toAddress(data, 32);
        sendData.inputToken = BytesLib.toAddress(data, 52);
        sendData.dstEid = BytesLib.toUint32(data, 72);
        sendData.to = BytesLib.toBytes32(data, 76);
        sendData.amountLD = BytesLib.toUint256(data, 108);
        sendData.minAmountLD = BytesLib.toUint256(data, 140);
        sendData.usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        sendData.isBusMode = _decodeBool(data, 173);

        uint256 extraOptionsLength = BytesLib.toUint256(data, 174);
        sendData.extraOptions = BytesLib.slice(data, 206, extraOptionsLength);

        uint256 composeMsgOffset = 206 + extraOptionsLength;
        uint256 composeMsgLength = BytesLib.toUint256(data, composeMsgOffset);
        sendData.composeMsg = BytesLib.slice(data, composeMsgOffset + 32, composeMsgLength);

        // 3. Handle usePrevHookAmount
        if (sendData.usePrevHookAmount) {
            uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);

            // Scale minAmountLD proportionally
            if (sendData.amountLD > 0 && sendData.minAmountLD > 0) {
                sendData.minAmountLD = Math.mulDiv(sendData.minAmountLD, outAmount, sendData.amountLD);
            }

            sendData.amountLD = outAmount;
        }

        // 4. Validations
        if (sendData.amountLD == 0) revert AMOUNT_NOT_VALID();
        if (sendData.stargatePool == address(0)) revert POOL_NOT_VALID();
        if (sendData.to == bytes32(0)) revert ADDRESS_NOT_VALID();

        // 5. Append signature to composeMsg if present
        if (sendData.composeMsg.length > 0) {
            bytes memory signature = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account);

            (
                bytes memory initData,
                bytes memory executorCalldata,
                address _account,
                address[] memory dstTokens,
                uint256[] memory intentAmounts
            ) = abi.decode(sendData.composeMsg, (bytes, bytes, address, address[], uint256[]));

            sendData.composeMsg = abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts, signature);
        }

        // 6. Build SendParam
        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: sendData.dstEid,
            to: sendData.to,
            amountLD: sendData.amountLD,
            minAmountLD: sendData.minAmountLD,
            extraOptions: sendData.extraOptions,
            composeMsg: sendData.composeMsg,
            oftCmd: sendData.isBusMode ? abi.encodePacked(uint8(1)) : bytes("")
        });

        // 7. Build MessagingFee
        IStargate.MessagingFee memory messagingFee = IStargate.MessagingFee({
            nativeFee: sendData.lzNativeFee,
            lzTokenFee: 0
        });

        // 8. Build execution
        // For native token: value = lzNativeFee + amountLD
        // For ERC20 (via ApproveAndStargateSendHook): value = lzNativeFee only
        uint256 executionValue = sendData.lzNativeFee + sendData.amountLD;

        executions = new Execution[](1);
        executions[0] = Execution({
            target: sendData.stargatePool,
            value: executionValue,
            callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address stargatePool = BytesLib.toAddress(data, 32);
        address inputToken = BytesLib.toAddress(data, 52);
        // Extract recipient as address from bytes32 (last 20 bytes)
        address toAddress = address(uint160(uint256(BytesLib.toBytes32(data, 76))));

        return abi.encodePacked(
            stargatePool,
            inputToken,
            toAddress
        );
    }
}
```

---

### 3. `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`

**Purpose**: Bridge ERC20 tokens cross-chain via Stargate V2 with approval pattern and optional destination execution.

**Key Differences from StargateSendHook**:
- Returns 4 Executions: approve(0) -> approve(amountLD) -> sendToken() -> approve(0)
- `value` in bridge Execution = `lzNativeFee` only (tokens transferred via approve)
- Uses `inputToken` from data for approval target

**Implementation Notes**:
- Same data layout as StargateSendHook
- Same constructor (only validator_)
- `_buildHookExecutions` returns 4 executions instead of 1
- Bridge execution `value` = `lzNativeFee` (not `lzNativeFee + amountLD`)
- Approval target is `stargatePool` (Stargate pulls tokens from the sender)

```solidity
// Same structure as StargateSendHook but with approval pattern:
executions = new Execution[](4);

// Execution 0: Reset approval to 0
executions[0] = Execution({
    target: sendData.inputToken,
    value: 0,
    callData: abi.encodeCall(IERC20.approve, (sendData.stargatePool, 0))
});

// Execution 1: Approve exact amount
executions[1] = Execution({
    target: sendData.inputToken,
    value: 0,
    callData: abi.encodeCall(IERC20.approve, (sendData.stargatePool, sendData.amountLD))
});

// Execution 2: Bridge call (value = lzNativeFee only for ERC20)
executions[2] = Execution({
    target: sendData.stargatePool,
    value: sendData.lzNativeFee,
    callData: abi.encodeCall(IStargate.sendToken, (sendParam, messagingFee, account))
});

// Execution 3: Cleanup approval to 0
executions[3] = Execution({
    target: sendData.inputToken,
    value: 0,
    callData: abi.encodeCall(IERC20.approve, (sendData.stargatePool, 0))
});
```

---

### 4. `test/unit/hooks/bridges/StargateHooks.t.sol`

**Purpose**: Comprehensive unit tests for both Stargate hook variants.

**Test Structure** (follows `BridgeHooks.t.sol` pattern):
- Inherits from `Helpers`
- Uses `MockSignatureStorage` (same as existing bridge tests)
- Uses `vm.mockCall` for external interactions
- Tests both variants with shared helper functions

**Test Cases**:

```
// Constructor Tests
test_StargateSend_Constructor()
test_StargateSend_Constructor_RevertIf_ZeroValidator()
test_ApproveAndStargateSend_Constructor()
test_ApproveAndStargateSend_Constructor_RevertIf_ZeroValidator()

// Basic Build Tests
test_StargateSend_Build()
test_StargateSend_Build_TaxiMode()
test_StargateSend_Build_BusMode()
test_ApproveAndStargateSend_Build_ERC20()
test_ApproveAndStargateSend_Build_ApprovalPattern()

// usePrevHookAmount Tests
test_StargateSend_Build_WithPrevHookAmount()
test_ApproveAndStargateSend_Build_WithPrevHookAmount()
test_StargateSend_Build_WithPrevHookAmount_ScalesMinAmount()

// Validation/Revert Tests
test_StargateSend_Build_RevertIf_DataTooShort()
test_StargateSend_Build_RevertIf_AmountZero()
test_StargateSend_Build_RevertIf_PoolZero()
test_StargateSend_Build_RevertIf_RecipientZero()
test_ApproveAndStargateSend_Build_RevertIf_DataTooShort()

// ComposeMsg Tests
test_StargateSend_Build_WithComposeMsg()
test_StargateSend_Build_WithoutComposeMsg()
test_ApproveAndStargateSend_Build_WithComposeMsg()

// Inspector Tests
test_StargateSend_Inspector()
test_ApproveAndStargateSend_Inspector()

// ISuperHookContextAware Tests
test_StargateSend_DecodeUsePrevHookAmount_True()
test_StargateSend_DecodeUsePrevHookAmount_False()

// PreExecute/PostExecute (no-op coverage)
test_StargateSend_PreExecute()
test_StargateSend_PostExecute()
test_ApproveAndStargateSend_PreExecute()
test_ApproveAndStargateSend_PostExecute()
```

**Helper Function**:
```solidity
function _encodeStargateData(
    bool usePrevHookAmount,
    bool isBusMode,
    bool includeComposeMsg
) internal view returns (bytes memory) {
    bytes memory extraOptions = hex"0003"; // minimal options
    bytes memory composeMsg;
    if (includeComposeMsg) {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = mockOutputToken;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 100;
        composeMsg = abi.encode("", "", mockAccount, dstTokens, intentAmounts);
    }

    return abi.encodePacked(
        mockLzNativeFee,           // uint256 lzNativeFee
        mockStargatePool,          // address stargatePool
        mockInputToken,            // address inputToken
        mockDstEid,                // uint32 dstEid
        mockTo,                    // bytes32 to
        mockAmountLD,              // uint256 amountLD
        mockMinAmountLD,           // uint256 minAmountLD
        usePrevHookAmount,         // bool usePrevHookAmount
        isBusMode,                 // bool isBusMode
        uint256(extraOptions.length), // uint256 extraOptionsLength
        extraOptions,              // bytes extraOptions
        uint256(composeMsg.length),   // uint256 composeMsgLength
        composeMsg                 // bytes composeMsg
    );
}
```

---

## Files to Modify

### 5. `script/utils/Constants.sol`

**Add** (after line ~203, near other bridge hook keys):

```solidity
// Stargate V2 Hook Keys
string internal constant STARGATE_SEND_HOOK_KEY = "StargateSendHook";
string internal constant APPROVE_AND_STARGATE_SEND_HOOK_KEY = "ApproveAndStargateSendHook";
```

---

### 6. `script/DeployV2Core.s.sol`

**Changes needed** (follow existing Across pattern):

Since the Stargate hooks only take `validator_` as constructor argument (no per-chain pool address), deployment is simpler than Across:

1. Add hook key constants usage (already defined in Constants.sol)
2. Add deployment entries in `_deployHooks()` - these deploy unconditionally (like utility hooks) since they only need the validator
3. Increment hook array length by 2

**Deployment pattern** (similar to hooks that only need validator):
```solidity
// StargateSendHook (always deploys - only needs validator)
if (superValidator != address(0)) {
    hooks[INDEX] = HookDeployment(
        STARGATE_SEND_HOOK_KEY,
        __getSalt(STARGATE_SEND_HOOK_KEY),
        abi.encodePacked(
            __getBytecode("StargateSendHook", env),
            abi.encode(superValidator)
        )
    );
} else {
    revert("STARGATE_SEND_HOOK_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
}

// ApproveAndStargateSendHook (always deploys - only needs validator)
if (superValidator != address(0)) {
    hooks[INDEX+1] = HookDeployment(
        APPROVE_AND_STARGATE_SEND_HOOK_KEY,
        __getSalt(APPROVE_AND_STARGATE_SEND_HOOK_KEY),
        abi.encodePacked(
            __getBytecode("ApproveAndStargateSendHook", env),
            abi.encode(superValidator)
        )
    );
} else {
    revert("APPROVE_AND_STARGATE_SEND_HOOK_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
}
```

### 7. `script/run/regenerate_bytecode.sh`

**Add** to `contracts_to_compile` array:
```bash
"StargateSendHook"
"ApproveAndStargateSendHook"
```

---

## Important Implementation Notes

### Note 1: stargatePool in Data (NOT Constructor)

Unlike Across which has a single SpokePool per chain, Stargate V2 has a separate pool per token. The bundler selects the appropriate pool and passes it in hook data. This is a CRITICAL architectural difference.

### Note 2: Value Calculation

- **StargateSendHook (native)**: `Execution.value = lzNativeFee + amountLD`
  - The pool needs both the bridging amount AND the LZ fee in `msg.value`
- **ApproveAndStargateSendHook (ERC20)**: `Execution.value = lzNativeFee`
  - Only the LZ fee needs to be sent as `msg.value`; tokens are pulled via `transferFrom`

### Note 3: Bus Mode Encoding

- Taxi mode: `oftCmd = bytes("")` (empty)
- Bus mode: `oftCmd = abi.encodePacked(uint8(1))` - single byte indicating bus ride
  - Note: Stargate V2 may use different bus encoding. Verify against deployed contracts. The key point is that an empty `oftCmd` = taxi and non-empty = bus.

### Note 4: bytes32 Recipient Format

Stargate V2 uses `bytes32` for the recipient to support cross-VM transfers. For EVM-to-EVM:
```solidity
bytes32 to = bytes32(uint256(uint160(recipientAddress)));
```
The bundler handles this conversion. The hook passes `to` as-is from the data.

### Note 5: No ConfigCore/ConfigBase Changes Needed

Since the hooks only need `validator_` (which is always deployed as part of core), no per-chain Stargate configuration is needed. The pool addresses are bundler-managed. This simplifies deployment significantly.

### Note 6: extraOptions is Bundler-Computed

The `extraOptions` field (which configures destination gas for compose execution) is pre-computed by the bundler using LayerZero's OptionsBuilder. The hook passes it through as raw bytes without modification.

### Note 7: ComposeMsg Signature Appending

Same pattern as Across and deBridge:
1. `composeMsg` in hook data = `abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts)` (5 fields)
2. Hook retrieves signature from validator transient storage
3. Hook re-encodes as `abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)` (6 fields)
4. This re-encoded version becomes the actual `composeMsg` in `SendParam`

### Note 8: Refund Address

The `_refundAddress` parameter in `sendToken()` should be set to `account` (the smart account). Any excess LZ native fee is refunded there. This is safe since the account controls the funds.

### Note 9: Inspector Function - CRITICAL

Per protocol requirement, inspector ONLY returns addresses:
- `stargatePool` (address at offset 32)
- `inputToken` (address at offset 52)
- `toAddress` (derived from bytes32 at offset 76, taking last 20 bytes via `address(uint160(uint256(...)))`)

### Note 10: Minimum Data Length

The minimum valid data length is 238 bytes:
- Fixed fields: 174 bytes (offsets 0-173)
- extraOptionsLength field: 32 bytes (offset 174)
- composeMsgLength field: 32 bytes (offset 206)
- Total minimum: 238 bytes (with 0-length extraOptions and 0-length composeMsg)

---

## Execution Order

1. Create `src/vendor/bridges/stargate/IStargate.sol`
2. Create `src/hooks/bridges/stargate/StargateSendHook.sol`
3. Create `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`
4. Create `test/unit/hooks/bridges/StargateHooks.t.sol`
5. Add constants to `script/utils/Constants.sol`
6. Update deployment script `script/DeployV2Core.s.sol`
7. Update `script/run/regenerate_bytecode.sh`
8. Run `forge build` to verify compilation
9. Run tests: `make forge-test TEST=StargateHooks`

---

## Verification Checklist

- [ ] Both hooks compile without errors
- [ ] All unit tests pass
- [ ] Inspector functions only return addresses
- [ ] `view` visibility on all internal decode/helper functions
- [ ] No hardcoded addresses (pool from data, validator from constructor)
- [ ] Proper approval race condition mitigation (approve 0 pattern)
- [ ] `usePrevHookAmount` correctly scales `minAmountLD`
- [ ] Signature appending follows exact same pattern as Across
- [ ] `DATA_NOT_VALID` error on insufficient data length
- [ ] `AMOUNT_NOT_VALID` error on zero amountLD
- [ ] `ADDRESS_NOT_VALID` error on zero recipient
- [ ] `POOL_NOT_VALID` error on zero pool address
- [ ] Bus/Taxi mode correctly maps to `oftCmd`
- [ ] Native variant: `value = lzNativeFee + amountLD`
- [ ] ERC20 variant: `value = lzNativeFee`
- [ ] ERC20 variant: approval target is `stargatePool`
