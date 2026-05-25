# CCTP V2 Bridge Hooks - Technical Specification

## Overview

Build an `ApproveAndCCTPSendHook` for cross-chain USDC transfers using Circle's CCTP V2 protocol (burn-and-mint mechanism). The hook calls `TokenMessengerV2.depositForBurnWithHook()` to burn USDC on the source chain with optional destination execution data, enabling cross-chain yield strategies (bridge USDC → execute on destination).

## Problem Statement / Motivation

Superform needs native USDC bridging via Circle's CCTP V2 — the canonical cross-chain USDC protocol. Unlike Stargate (LZ messaging) or Across (intent-based), CCTP uses Circle's burn-and-mint mechanism with attestation service, providing 1:1 USDC transfers with no slippage. CCTP V2 adds fast finality support and native hook data for composable cross-chain actions.

## Proposed Solution

Single hook: **`ApproveAndCCTPSendHook`** following the Across pattern (immutable protocol address + validator as constructor args).

Key design decisions:
- **One hook only** — USDC is always ERC20, no native ETH variant needed
- **`depositForBurnWithHook`** — Use the hook-enabled variant for native destination execution support
- **Across model constructor** — `(address tokenMessenger_, address validator_)`
- **No proportional scaling** — CCTP is 1:1 (minus fee), no minAmount to scale

## Technical Considerations

### Corrections from Implementation Plan
The implementation plan (`.claude/doc/cctp-v2-bridge-hooks/implementation-plan.md`) has several inaccuracies that MUST be corrected:

1. **TokenMessengerV2 Address**: Plan says `0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440` — **WRONG**
   - Correct: **`0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d`** (verified on Etherscan/BaseScan)

2. **Parameter Name**: Plan says `maxBurnAmountPerMessage` — **WRONG**
   - Correct: **`maxFee`** (the actual CCTP V2 parameter name)

3. **Function**: Plan says `depositForBurn` (no hook support) — **INCOMPLETE**
   - Correct: Use **`depositForBurnWithHook`** which has a `bytes hookData` parameter for native destination execution (analogous to Stargate's composeMsg)

4. **Chain Support**: Plan says Linea, Sonic, Unichain, World Chain, HyperEVM are "not deployed" — **OUTDATED**
   - Correct: CCTP V2 is deployed on ALL these chains (verified from Circle docs May 2026)

### Architecture
- Hook type: `NONACCOUNTING` / `BRIDGE` (same as all bridge hooks)
- Constructor: `(address tokenMessenger_, address validator_)` — both immutable, both validated non-zero
- Approval pattern: approve(0) → approve(amount) → depositForBurnWithHook → approve(0) — 4 executions
- No native ETH value (all execution values = 0)
- Destination execution: hookCallData with validator signature appended, passed as `hookData` to CCTP V2

### Security
- Approval race condition prevention via approve(0) pattern
- mintRecipient bytes32(0) validation (prevents permanent fund loss)
- burnToken address(0) validation
- amount != 0 validation
- destinationCaller restriction for relay front-running prevention
- No reentrancy risk (_buildHookExecutions is view)
- No flash loan exposure (burn is irreversible)
- No slippage/MEV (1:1 mint)

## Acceptance Criteria

### Functional
- [ ] `ApproveAndCCTPSendHook` deploys with `(tokenMessenger, validator)` constructor args
- [ ] Produces 4 executions: approve(0), approve(amount), depositForBurnWithHook, approve(0)
- [ ] All execution values are 0 (no native ETH)
- [ ] Correctly decodes packed data layout
- [ ] Supports `usePrevHookAmount` for chaining from previous hooks
- [ ] Appends validator signature to hookCallData when present
- [ ] Passes hookCallData as `hookData` to `depositForBurnWithHook`
- [ ] `inspect()` returns burnToken and mintRecipient addresses
- [ ] `decodeUsePrevHookAmount()` correctly reads bool at offset 156
- [ ] Validates: burnToken != 0, mintRecipient != 0, amount != 0
- [ ] Reverts with `DATA_NOT_VALID()` for short/malformed data

### Non-Functional
- [ ] Gas-efficient packed data decoding (BytesLib)
- [ ] Follows existing hook patterns exactly
- [ ] All unit tests pass
- [ ] Fork test against real TokenMessengerV2 on Ethereum mainnet

## Implementation

### Phase 1: Core Files

#### 1. `src/vendor/bridges/cctp/ITokenMessengerV2.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ITokenMessengerV2
/// @notice Interface for Circle's CCTP V2 TokenMessenger contract
interface ITokenMessengerV2 {
    /// @notice Burns tokens with hook data for composable cross-chain actions
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes memory hookData
    ) external returns (bytes memory);
}
```

#### 2. `src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol`

**Constructor:**
```solidity
constructor(address tokenMessenger_, address validator_)
    BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE)
{
    if (tokenMessenger_ == address(0)) revert ADDRESS_NOT_VALID();
    if (validator_ == address(0)) revert ADDRESS_NOT_VALID();
    TOKEN_MESSENGER = tokenMessenger_;
    VALIDATOR = validator_;
}
```

**Immutables:**
```solidity
address public immutable TOKEN_MESSENGER;
address private immutable VALIDATOR;
uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 156;
```

**Data Layout (packed, sequential BytesLib decoding):**
```
Offset  Type       Field                 Description
------  ----       -----                 -----------
0       address    burnToken             USDC address on source chain (20 bytes)
20      uint256    amount                Amount of USDC to burn (32 bytes)
52      uint32     destinationDomain     CCTP domain ID of destination (4 bytes)
56      bytes32    mintRecipient         Recipient on destination chain (32 bytes)
88      bytes32    destinationCaller     Who can call receiveMessage on dst (32 bytes)
120     uint256    maxFee                Maximum fee for transfer (32 bytes)
152     uint32     minFinalityThreshold  Finality level required (4 bytes)
156     bool       usePrevHookAmount     Whether to use prev hook output (1 byte)
157     uint256    hookCallDataLength    Length of hookCallData (32 bytes)
189     bytes      hookCallData          Destination execution payload (variable)
```

Minimum data length: **157 bytes** (no hookCallData, hookCallDataLength can be 0)
With hookCallData: **189 + hookCallDataLength bytes**

**Custom Errors:**
```solidity
error DATA_NOT_VALID();
error RECIPIENT_NOT_VALID();
```

**`_buildHookExecutions` Logic:**
```
1. Validate data.length >= 157 (revert DATA_NOT_VALID)
2. Decode fixed fields via BytesLib
3. Validate: burnToken != address(0) → revert ADDRESS_NOT_VALID
4. Validate: mintRecipient != bytes32(0) → revert RECIPIENT_NOT_VALID
5. Decode hookCallDataLength at offset 157
6. If hookCallDataLength > 0:
   - Validate data.length >= 189 + hookCallDataLength → revert DATA_NOT_VALID
   - Slice hookCallData from offset 189
7. Handle usePrevHookAmount:
   - If true: amount = ISuperHookResult(prevHook).getOutAmount(account)
   - No proportional scaling (no minAmount in CCTP)
8. Validate amount != 0 → revert AMOUNT_NOT_VALID
9. If hookCallData.length > 0:
   - Validate hookCallData.length >= 160 → revert DATA_NOT_VALID
   - Retrieve signature: ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account)
   - Decode: abi.decode(hookCallData, (bytes, bytes, address, address[], uint256[]))
   - Re-encode with signature: abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)
10. Build 4 executions:
    - [0]: IERC20(burnToken).approve(TOKEN_MESSENGER, 0)
    - [1]: IERC20(burnToken).approve(TOKEN_MESSENGER, amount)
    - [2]: ITokenMessengerV2(TOKEN_MESSENGER).depositForBurnWithHook(amount, destinationDomain, mintRecipient, burnToken, destinationCaller, maxFee, minFinalityThreshold, hookCallData)
    - [3]: IERC20(burnToken).approve(TOKEN_MESSENGER, 0)
    All execution values = 0 (no native ETH)
```

**`inspect` function:**
```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    return abi.encodePacked(
        BytesLib.toAddress(data, 0),  // burnToken
        address(uint160(uint256(BytesLib.toBytes32(data, 56))))  // mintRecipient (as address)
    );
}
```

**`decodeUsePrevHookAmount` function:**
```solidity
function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
    return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
}
```

**Struct (for readability):**
```solidity
struct CCTPSendData {
    address burnToken;
    uint256 amount;
    uint32 destinationDomain;
    bytes32 mintRecipient;
    bytes32 destinationCaller;
    uint256 maxFee;
    uint32 minFinalityThreshold;
    bytes hookCallData;
}
```

### Phase 2: Tests

#### 3. `test/unit/hooks/bridges/CCTPHooks.t.sol`

Test contract: `CCTPHooks is Helpers`

**Test Cases (~25):**

Constructor:
- test_CCTP_Constructor — verify TOKEN_MESSENGER, hookType, subtype
- test_CCTP_Constructor_RevertIf_ZeroTokenMessenger
- test_CCTP_Constructor_RevertIf_ZeroValidator

Build (basic):
- test_CCTP_Build — valid data, verify 6 executions (pre + 4 + post)
- test_CCTP_Build_VerifyApprovePattern — approve(0), approve(amount), burn, approve(0)
- test_CCTP_Build_VerifyDepositForBurnWithHookCalldata — exact calldata encoding
- test_CCTP_Build_VerifyNoNativeValue — all execution values == 0

Build (reverts):
- test_CCTP_Build_RevertIf_ZeroAmount
- test_CCTP_Build_RevertIf_ZeroBurnToken
- test_CCTP_Build_RevertIf_ZeroRecipient — bytes32(0)
- test_CCTP_Build_RevertIf_DataTooShort — data.length < 157

PrevHookAmount:
- test_CCTP_Build_WithPrevHookAmount — amount replaced from prev hook
- test_CCTP_Build_WithPrevHookAmount_RevertIf_ZeroAmount

HookCallData:
- test_CCTP_Build_WithHookCallData — signature appended, passed as hookData
- test_CCTP_Build_WithoutHookCallData — empty hookData, no signature retrieval
- test_CCTP_Build_WithHookCallData_RevertIf_TooShort — < 160 bytes
- test_CCTP_Build_RevertIf_HookCallDataLengthExceedsData

Inspector:
- test_CCTP_Inspector — returns burnToken + mintRecipient
- test_CCTP_Inspector_VerifyBurnToken
- test_CCTP_Inspector_VerifyMintRecipient

DecodeUsePrevHookAmount:
- test_CCTP_DecodeUsePrevHookAmount_True
- test_CCTP_DecodeUsePrevHookAmount_False

Pre/Post Execute:
- test_CCTP_PreExecute — no-op coverage
- test_CCTP_PostExecute — no-op coverage

Subtype:
- test_CCTP_Subtype — HookSubTypes.BRIDGE

Fuzz:
- testFuzz_CCTP_Build_VariableAmounts
- testFuzz_CCTP_Build_VariableDomains

### Phase 3: Deployment Integration

#### 4. `script/utils/Constants.sol`
Add after Stargate hook keys:
```solidity
// CCTP V2 Bridge Hook Keys
string internal constant APPROVE_AND_CCTP_SEND_HOOK_KEY = "ApproveAndCCTPSendHook";

// CCTP V2 TokenMessengerV2 (universal across all EVM chains via CREATE2)
address internal constant CCTP_V2_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
```

#### 5. `script/DeployV2Core.s.sol`
- Add `address approveAndCCTPSendHook` to HookAddresses struct
- Update hooks array length: 64 → 65
- Deploy at index 64 with constructor args: `abi.encode(CCTP_V2_TOKEN_MESSENGER, superValidator)`
- CCTP V2 is deployed on all Superform-supported chains, so no conditional deployment needed
- Add to `_checkHookContracts`

#### 6. `script/run/regenerate_bytecode.sh`
Add `"ApproveAndCCTPSendHook"` to HOOK_CONTRACTS array.

## CCTP V2 Reference

### TokenMessengerV2 Address
`0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d` — same on ALL EVM chains (CREATE2)

### Deployed Chains (May 2026)
| Chain | Domain ID | Superform Chain ID |
|-------|-----------|-------------------|
| Ethereum | 0 | 1 |
| Avalanche | 1 | 43114 |
| Optimism | 2 | 10 |
| Arbitrum | 3 | 42161 |
| Base | 6 | 8453 |
| Polygon PoS | 7 | 137 |
| Unichain | 10 | 130 |
| Linea | 11 | 59144 |
| Sonic | 13 | 146 |
| World Chain | 14 | 480 |
| HyperEVM | 19 | 999 |

### Constraints
- $10M per-message limit
- USDC only (6 decimals)
- maxFee: deducted from transfer amount (not via msg.value)
- minFinalityThreshold: >= 2000 = standard (15-19 min), < 2000 = fast (8-20 sec)

## Execution Flow

```
User signs UserOp with CCTP bridge hook data
    |
    v
SuperExecutor calls hook.build(prevHook, account, data)
    |
    v
hook._buildHookExecutions returns 4 Executions:
    |
    +-- [0] USDC.approve(TOKEN_MESSENGER, 0)
    +-- [1] USDC.approve(TOKEN_MESSENGER, amount)
    +-- [2] TOKEN_MESSENGER.depositForBurnWithHook(
    |         amount, destinationDomain, mintRecipient,
    |         burnToken, destinationCaller, maxFee,
    |         minFinalityThreshold, hookCallData
    |       )
    +-- [3] USDC.approve(TOKEN_MESSENGER, 0)
    |
    v
BaseHook wraps with preExecute + postExecute => 6 total
    |
    v
Circle attestation service observes burn event
    |
    v
Relayer calls receiveMessage on destination (with hookData if present)
    |
    v
USDC minted to mintRecipient + hook executed on destination
```

## Comparison with Existing Bridge Hooks

| Feature | Across | Stargate | CCTP V2 |
|---------|--------|----------|---------|
| Constructor args | spokePool + validator | validator | tokenMessenger + validator |
| Native ETH flow | Yes | Yes | No (always 0) |
| Approve pattern | Yes (variant) | Yes (variant) | Yes (always) |
| Dest execution | destinationMessage | composeMsg | hookData (native CCTP V2) |
| Signature append | To destinationMessage | To composeMsg | To hookData |
| Min output amount | outputAmount (proportional) | minAmountLD (proportional) | None (1:1 guaranteed) |
| Protocol fee | msg.value | msg.value (lzNativeFee) | maxFee (from amount) |
| Non-approve variant | Yes | Yes (native) | No (not needed) |

## References & Research
- TokenMessengerV2 verified: https://etherscan.io/address/0x28b5a0e9c621a5badaa536219b3a228c8168cf5d
- Circle CCTP docs: https://developers.circle.com/cctp/evm-smart-contracts
- Similar implementations: `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`, `src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol`
- Research: `specs/cctp-bridge-hooks/research/`
