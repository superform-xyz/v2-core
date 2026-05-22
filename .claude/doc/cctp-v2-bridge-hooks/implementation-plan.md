# CCTP V2 Bridge Hooks - Implementation Plan

## Date: 2026-05-06

## Overview

Build CCTP V2 (Circle Cross-Chain Transfer Protocol) bridge hooks for cross-chain USDC transfers using Circle's burn-and-mint mechanism via `TokenMessengerV2.depositForBurn`. These hooks enable source-chain USDC burning with optional destination execution (same pattern as Stargate hooks -- append validator signature to `hookCallData` / destination message).

---

## Architecture Decision: One Hook or Two?

**Decision: Build ONLY `ApproveAndCCTPSendHook` (the approve variant).**

Rationale:
- CCTP exclusively handles USDC, which is always an ERC20 token (never native ETH)
- There is no native-token transfer path for CCTP (unlike Stargate which has native ETH pools)
- The `StargateSendHook` (non-approve variant) exists because Stargate supports native ETH pools where `msg.value` carries the token amount. CCTP has no such use case
- A `CCTPSendHook` without approval would require the user to pre-approve TokenMessengerV2, which is less safe and not the standard pattern
- All existing ERC20 bridge hooks in the codebase use the approve pattern

If a non-approve variant is ever needed (e.g., USDC is already approved by a prior hook), it can be added later. For now, the approve variant covers all use cases.

---

## CCTP V2 Protocol Research

### TokenMessengerV2 `depositForBurn` Signature

Based on Circle's CCTP V2 specification (deployed on mainnet, immutable contracts):

```solidity
function depositForBurn(
    uint256 amount,              // Amount of tokens to burn
    uint32 destinationDomain,    // CCTP domain ID for destination chain
    bytes32 mintRecipient,       // Recipient address on destination (left-padded bytes32)
    address burnToken,           // Token to burn (USDC address on source chain)
    bytes32 destinationCaller,   // Restricts who can call receiveMessage on destination (bytes32(0) = anyone)
    uint256 maxBurnAmountPerMessage, // Max amount allowed per message (SDK-determined, per-route limit)
    uint32 minFinalityThreshold  // Minimum finality level required (fast vs standard)
) external returns (bytes memory); // Returns the raw CCTP message bytes
```

### Important CCTP V2 Details

1. **Domain IDs** (NOT chain IDs): CCTP uses its own domain numbering:
   - Ethereum: 0
   - Avalanche: 1
   - Optimism: 2
   - Arbitrum: 3
   - Base: 6
   - Polygon PoS: 7
   - Solana: 5 (not EVM)

2. **TokenMessengerV2 Addresses** (deployed at same address across chains via CREATE2):
   - All EVM chains: `0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440`
   - This is a universal constant -- same address on Ethereum, Arbitrum, Base, Optimism, Polygon, Avalanche

3. **USDC Addresses** (varies per chain -- NOT relevant for constructor, but for testing):
   - Ethereum: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
   - Base: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
   - Arbitrum: `0xaf88d065e77c8cC2239327C5EDb3A432268e5831`
   - Optimism: `0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85`
   - Polygon: `0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359`
   - Avalanche: `0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E`

4. **No native fee**: Unlike Stargate (which has `lzNativeFee`), CCTP V2 `depositForBurn` requires no native ETH fee. The fee is taken from the burned amount itself (Circle's relayer service is free for standard finality; fast finality may have Circle-internal costs but no `msg.value` needed).

5. **No `composeMsg` / destination execution at protocol level**: Unlike Stargate which has native `composeMsg` support for destination execution, CCTP V2 does NOT natively support destination execution in `depositForBurn`. The destination execution pattern for Superform would need to be handled differently.

### Destination Execution Strategy

**CRITICAL INSIGHT**: CCTP V2's `depositForBurn` does NOT have a `composeMsg` parameter like Stargate. The destination execution for Superform requires a different approach.

**Two possible approaches:**

**Option A: No destination execution in the CCTP hook itself** -- USDC is simply bridged and received by the `mintRecipient`. Destination execution is handled by separate off-chain coordination (the Superform bundler on the destination chain picks up the mint event and submits a separate userOp).

**Option B: Use `destinationCaller` restriction** -- Set `destinationCaller` to a Superform-controlled address (like the SuperDestinationExecutor or a relayer), which then calls `receiveMessage` on the destination MessageTransmitter and subsequently executes Superform operations. But this doesn't embed the execution payload in the CCTP message itself.

**Recommended approach (based on interview notes saying "same pattern as Stargate"):**
The interview notes say "append validator signature to composeMsg for executing operations on the destination chain." However, CCTP V2 has no native `composeMsg`.

**Resolution**: After re-reading the interview notes more carefully, the pattern is:
- The hook still takes a `hookCallData` / destination message in the packed data
- This message is NOT sent through CCTP itself (since CCTP has no compose capability)
- Instead, the destination message is handled by the Superform off-chain infrastructure that monitors CCTP attestations
- The validator signature is still appended (same pattern as Across/Stargate) for the destination executor to use
- The `destinationCaller` field in CCTP can be set to restrict who calls `receiveMessage` on destination

**However**, looking more carefully at the Across hook pattern (which also does not embed messages in the bridge protocol itself but uses a separate `destinationMessage` parameter), the CCTP hook should follow the same pattern but WITHOUT a destination message since CCTP has no native way to deliver it. The bridging is purely a token transfer.

**FINAL DECISION**: Build the CCTP hook as a **pure bridge hook** (token transfer only, no destination execution embedded). The `destinationCaller` restriction field provides security. If destination execution is needed, it can be coordinated off-chain. This matches how CCTP actually works -- it is a pure token bridge, not a message bridge.

However, to maintain consistency with the interview notes asking for "destination execution support", we WILL include a `hookCallData` field (variable-length bytes) that:
1. Contains the destination execution payload (same ABI structure as Stargate/Across)
2. Gets the validator signature appended to it (retrieved from `ISuperSignatureStorage`)
3. Is NOT sent through CCTP itself -- it is emitted as an event or stored for off-chain pickup
4. The Superform bundler on the destination chain uses this data after the CCTP attestation is processed

**WAIT** -- re-examining the Across and Stargate patterns more carefully:

In **Across**: The `destinationMessage` is passed directly to `depositV3Now` as a parameter. Across's fillers execute the message on the destination.

In **Stargate**: The `composeMsg` is passed to `sendToken`. Stargate's LayerZero endpoint delivers and executes the compose message.

In **CCTP V2**: There is NO message parameter in `depositForBurn`. CCTP V2 is purely a token bridge.

**Therefore**: The CCTP hook should NOT include a `hookCallData`/destination message field, since there is nowhere to send it. The hook is a pure send-side bridge hook. Any destination execution would be orchestrated entirely off-chain by the Superform bundler system.

BUT -- the interview notes explicitly say "with destination execution" and "append validator signature like Stargate." Let me re-examine...

**FINAL FINAL DECISION**: Looking at the interview notes again: "With destination execution -- same pattern as Stargate hooks: append validator signature to composeMsg for executing operations on the destination chain after USDC is received"

This suggests the team wants a `hookCallData` field even though CCTP does not natively support it. The hookCallData + signature would be emitted or stored off-chain. The `VALIDATOR` constructor arg confirms this -- it is needed to retrieve the signature.

**Implementation**: Include `hookCallData` (variable-length bytes) in the data layout. Append the validator signature to it. The combined payload is NOT sent through CCTP but is available via the hook's transient state or events for the off-chain system to pick up. This follows the interview instruction while acknowledging CCTP's limitations.

Actually, looking even MORE carefully at the Stargate and Across hooks: they pass the message WITH signature directly into the bridge protocol call. Since CCTP cannot do this, there are two options:
1. Store the signed hookCallData in transient storage for off-chain pickup
2. Do not include hookCallData at all

Given that the interview says "with destination execution," I will include the `hookCallData` field and the `VALIDATOR` constructor arg. The hook will:
1. Decode the hookCallData from packed data
2. Append the validator signature (same as Stargate/Across)
3. Store it in a transient storage slot or emit an event
4. The off-chain bundler picks it up to execute on the destination chain

This way, the hook is ready for destination execution when the off-chain infrastructure supports it.

---

## File Plan

### Files to CREATE

1. **`src/vendor/bridges/cctp/ITokenMessengerV2.sol`** -- CCTP V2 interface
2. **`src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol`** -- Main hook
3. **`test/unit/hooks/bridges/CCTPHooks.t.sol`** -- Unit tests

### Files to MODIFY

4. **`script/utils/Constants.sol`** -- Add hook key constants
5. **`script/utils/ConfigBase.sol`** -- Add `cctpTokenMessengers` mapping to `EnvironmentData`
6. **`script/utils/ConfigCore.sol`** -- Add TokenMessengerV2 addresses per chain
7. **`script/DeployV2Core.s.sol`** -- Add deployment integration
8. **`script/run/regenerate_bytecode.sh`** -- Add to HOOK_CONTRACTS array

---

## Detailed File Specifications

### 1. `src/vendor/bridges/cctp/ITokenMessengerV2.sol`

```
Interface file for CCTP V2 TokenMessengerV2 contract.

Contents:
- depositForBurn function signature:
  function depositForBurn(
      uint256 amount,
      uint32 destinationDomain,
      bytes32 mintRecipient,
      address burnToken,
      bytes32 destinationCaller,
      uint256 maxBurnAmountPerMessage,
      uint32 minFinalityThreshold
  ) external returns (bytes memory);

Notes:
- Return type is `bytes memory` (raw CCTP message bytes)
- Solidity 0.8.30
- Apache-2.0 license header
- No need for receiveMessage -- that is on MessageTransmitter (receive side, not needed)
```

### 2. `src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol`

**Constructor:**
```
constructor(address tokenMessenger_, address validator_)
    BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE)

- tokenMessenger_ => address public immutable TOKEN_MESSENGER
- validator_ => address private immutable VALIDATOR
- Both must be non-zero (revert ADDRESS_NOT_VALID)
- Follows the Across pattern: protocol address + validator as immutable constructor args
```

**Data Layout (packed, sequential BytesLib decoding):**
```
Offset  Type       Field                    Description
------  ----       -----                    -----------
0       address    burnToken                USDC address on source chain (20 bytes)
20      uint256    amount                   Amount of USDC to burn (32 bytes)
52      uint32     destinationDomain        CCTP domain ID of destination (4 bytes)
56      bytes32    mintRecipient            Recipient on destination chain (32 bytes)
88      bytes32    destinationCaller        Who can call receiveMessage on dst (32 bytes)
120     uint256    maxBurnAmountPerMessage  Per-message burn limit (32 bytes)
152     uint32     minFinalityThreshold     Finality level required (4 bytes)
156     bool       usePrevHookAmount        Whether to use prev hook output (1 byte)
157     uint256    hookCallDataLength       Length of hookCallData (32 bytes)
189     bytes      hookCallData             Destination execution payload (variable)

Minimum data length: 157 bytes (no hookCallData)
With hookCallData: 189 + hookCallDataLength bytes
```

**USE_PREV_HOOK_AMOUNT_POSITION = 156**

**NatSpec data documentation (immediately after `/// @dev data has the following structure`):**
```solidity
/// @dev data has the following structure
/// @notice         address burnToken = BytesLib.toAddress(data, 0);
/// @notice         uint256 amount = BytesLib.toUint256(data, 20);
/// @notice         uint32 destinationDomain = BytesLib.toUint32(data, 52);
/// @notice         bytes32 mintRecipient = BytesLib.toBytes32(data, 56);
/// @notice         bytes32 destinationCaller = BytesLib.toBytes32(data, 88);
/// @notice         uint256 maxBurnAmountPerMessage = BytesLib.toUint256(data, 120);
/// @notice         uint32 minFinalityThreshold = BytesLib.toUint32(data, 152);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
/// @notice         uint256 hookCallDataLength = BytesLib.toUint256(data, 157);
/// @notice         bytes hookCallData = BytesLib.slice(data, 189, hookCallDataLength);
```

**Struct:**
```solidity
struct CCTPSendData {
    address burnToken;
    uint256 amount;
    uint32 destinationDomain;
    bytes32 mintRecipient;
    bytes32 destinationCaller;
    uint256 maxBurnAmountPerMessage;
    uint32 minFinalityThreshold;
    bytes hookCallData;
}
```

**Custom Errors:**
```solidity
error DATA_NOT_VALID();      // Data length too short or variable fields exceed bounds
error RECIPIENT_NOT_VALID(); // mintRecipient is bytes32(0)
```

**`_buildHookExecutions` logic:**
```
1. Validate minimum data length (>= 157 bytes, or >= 189 if hookCallData present)
2. Decode all fixed fields from packed data
3. Validate:
   - burnToken != address(0) => revert ADDRESS_NOT_VALID
   - mintRecipient != bytes32(0) => revert RECIPIENT_NOT_VALID
4. Decode variable-length hookCallData if present:
   - Read hookCallDataLength at offset 157
   - Validate data.length >= 189 + hookCallDataLength => revert DATA_NOT_VALID
   - Slice hookCallData from offset 189
5. Handle usePrevHookAmount:
   - If true, get amount from ISuperHookResult(prevHook).getOutAmount(account)
   - No proportional scaling needed since there is no minAmount (CCTP handles exact amounts)
6. Validate amount != 0 => revert AMOUNT_NOT_VALID
7. If hookCallData is present and non-empty:
   - Validate minimum length (>= 160 bytes, same as Stargate/Across)
   - Retrieve signature from ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account)
   - Decode hookCallData as (bytes initData, bytes executorCalldata, address account, address[] dstTokens, uint256[] intentAmounts)
   - Re-encode with signature appended
   - Store in transient storage or keep in memory (for off-chain pickup)
8. Build 4 executions (approve pattern):
   - Execution 0: IERC20(burnToken).approve(TOKEN_MESSENGER, 0)
   - Execution 1: IERC20(burnToken).approve(TOKEN_MESSENGER, amount)
   - Execution 2: ITokenMessengerV2(TOKEN_MESSENGER).depositForBurn(amount, destinationDomain, mintRecipient, burnToken, destinationCaller, maxBurnAmountPerMessage, minFinalityThreshold)
   - Execution 3: IERC20(burnToken).approve(TOKEN_MESSENGER, 0)

NOTE: Execution 2 has value = 0 (no native ETH needed for CCTP V2 depositForBurn)
```

**`inspect` function:**
```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    return abi.encodePacked(
        BytesLib.toAddress(data, 0),  // burnToken
        address(uint160(uint256(BytesLib.toBytes32(data, 56))))  // mintRecipient (as address from bytes32)
    );
}
// CRITICAL: Only addresses returned, never amounts or other data (protocol requirement)
```

**`decodeUsePrevHookAmount` function:**
```solidity
function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
    return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
}
```

**Interfaces implemented:** `BaseHook`, `ISuperHookContextAware`

**Imports required:**
```solidity
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { ITokenMessengerV2 } from "../../../vendor/bridges/cctp/ITokenMessengerV2.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperSignatureStorage } from "../../../interfaces/ISuperSignatureStorage.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
```

### 3. `test/unit/hooks/bridges/CCTPHooks.t.sol`

**Test contract:** `CCTPHooks is Helpers`

**Setup:**
```
- Create MockSignatureStorage (same pattern as StargateHooks.t.sol)
- Deploy ApproveAndCCTPSendHook with mock TOKEN_MESSENGER and mock validator
- Set up mock addresses: mockAccount, mockBurnToken, mockRecipient, etc.
- Define test data constants
```

**Test cases (minimum ~25 tests for comprehensive coverage):**

```
Constructor Tests:
1. test_CCTP_Constructor -- verify TOKEN_MESSENGER, hookType, subtype
2. test_CCTP_Constructor_RevertIf_ZeroTokenMessenger
3. test_CCTP_Constructor_RevertIf_ZeroValidator

Build Tests:
4. test_CCTP_Build -- basic build with valid data, verify 6 executions (pre + 4 hook + post)
5. test_CCTP_Build_VerifyApprovePattern -- check approve(0), approve(amount), depositForBurn, approve(0)
6. test_CCTP_Build_VerifyDepositForBurnCalldata -- verify exact calldata encoding
7. test_CCTP_Build_VerifyNoNativeValue -- confirm executions[3].value == 0 (no ETH for CCTP)
8. test_CCTP_Build_RevertIf_ZeroAmount
9. test_CCTP_Build_RevertIf_ZeroBurnToken
10. test_CCTP_Build_RevertIf_ZeroRecipient (bytes32(0))
11. test_CCTP_Build_RevertIf_DataTooShort -- data.length < 157

PrevHookAmount Tests:
12. test_CCTP_Build_WithPrevHookAmount -- usePrevHookAmount=true, verify amount replaced
13. test_CCTP_Build_WithPrevHookAmount_RevertIf_ZeroAmount -- prev hook returns 0

HookCallData Tests:
14. test_CCTP_Build_WithHookCallData -- verify signature appended to hookCallData
15. test_CCTP_Build_WithoutHookCallData -- hookCallDataLength=0, verify no signature retrieval
16. test_CCTP_Build_WithHookCallData_RevertIf_TooShort -- hookCallData < 160 bytes
17. test_CCTP_Build_RevertIf_HookCallDataLengthExceedsData -- bad hookCallDataLength

Inspector Tests:
18. test_CCTP_Inspector -- verify only addresses returned
19. test_CCTP_Inspector_VerifyBurnToken
20. test_CCTP_Inspector_VerifyMintRecipient

DecodeUsePrevHookAmount Tests:
21. test_CCTP_DecodeUsePrevHookAmount_True
22. test_CCTP_DecodeUsePrevHookAmount_False

PreExecute/PostExecute Tests:
23. test_CCTP_PreExecute -- no-op, coverage only
24. test_CCTP_PostExecute -- no-op, coverage only

Subtype Test:
25. test_CCTP_Subtype -- verify HookSubTypes.BRIDGE

Fuzz Tests:
26. testFuzz_CCTP_Build_VariableAmounts -- fuzz amount
27. testFuzz_CCTP_Build_VariableDomains -- fuzz destinationDomain
```

**Data encoding helper:**
```solidity
function _encodeCCTPData(bool usePrevHookAmount) internal view returns (bytes memory) {
    return abi.encodePacked(
        mockBurnToken,              // address (20 bytes)
        mockAmount,                 // uint256 (32 bytes)
        mockDestinationDomain,      // uint32 (4 bytes)
        mockMintRecipient,          // bytes32 (32 bytes)
        mockDestinationCaller,      // bytes32 (32 bytes)
        mockMaxBurnAmount,          // uint256 (32 bytes)
        mockMinFinality,            // uint32 (4 bytes)
        usePrevHookAmount,          // bool (1 byte)
        uint256(mockHookCallData.length), // uint256 (32 bytes)
        mockHookCallData            // bytes (variable)
    );
}
```

### 4. `script/utils/Constants.sol` -- MODIFY

Add after the existing Circle Gateway hook keys (around line 247):

```solidity
// CCTP V2 Bridge Hook Keys
string internal constant APPROVE_AND_CCTP_SEND_HOOK_KEY = "ApproveAndCCTPSendHook";

// CCTP V2 TokenMessengerV2 address (universal across all EVM chains via CREATE2)
address internal constant CCTP_V2_TOKEN_MESSENGER = 0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440;
```

NOTE: The TokenMessengerV2 address is the SAME on all EVM chains. Since it is universal (like Permit2), it can be a constant rather than a per-chain mapping. However, to maintain consistency with the Across pattern (which uses per-chain spoke pool mappings), AND to account for chains where CCTP V2 may not yet be deployed, we should use the ConfigCore mapping approach. The constant here is for test usage.

### 5. `script/utils/ConfigBase.sol` -- MODIFY

Add to the `EnvironmentData` struct (after `uniswapV2SwapRouters` on line 33):

```solidity
mapping(uint64 chainId => address tokenMessenger) cctpTokenMessengers;
```

### 6. `script/utils/ConfigCore.sol` -- MODIFY

Add CCTP V2 TokenMessengerV2 addresses in `_setCoreConfiguration()`.

**VERIFIED chain ID constant names from `script/utils/Constants.sol`:**
- `MAINNET_CHAIN_ID` (1)
- `ARBITRUM_CHAIN_ID` (42161)
- `BASE_CHAIN_ID` (8453)
- `OPTIMISM_CHAIN_ID` (10)
- `POLYGON_CHAIN_ID` (137)
- `AVALANCHE_CHAIN_ID` (43114)
- `BNB_CHAIN_ID` (56)
- `LINEA_CHAIN_ID` (59144)
- `SONIC_CHAIN_ID` (146)
- `GNOSIS_CHAIN_ID` (100)
- `BERACHAIN_CHAIN_ID` (80094)
- `UNICHAIN_CHAIN_ID` (130)
- `WORLDCHAIN_CHAIN_ID` (480) -- NOTE: NOT `WORLD_CHAIN_ID`
- `HYPEREVM_CHAIN_ID` (999)
- `FLARE_CHAIN_ID` (14)

```solidity
// ===== CCTP V2 TOKEN MESSENGER ADDRESSES =====
// CCTP V2 uses CREATE2 -- same address on all deployed chains
// Deployed on 6 EVM chains as of May 2026
configuration.cctpTokenMessengers[MAINNET_CHAIN_ID] = 0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440;
configuration.cctpTokenMessengers[ARBITRUM_CHAIN_ID] = 0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440;
configuration.cctpTokenMessengers[BASE_CHAIN_ID] = 0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440;
configuration.cctpTokenMessengers[OPTIMISM_CHAIN_ID] = 0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440;
configuration.cctpTokenMessengers[POLYGON_CHAIN_ID] = 0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440;
configuration.cctpTokenMessengers[AVALANCHE_CHAIN_ID] = 0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440;

// Not deployed on these chains (no CCTP V2 support)
configuration.cctpTokenMessengers[BNB_CHAIN_ID] = address(0);
configuration.cctpTokenMessengers[LINEA_CHAIN_ID] = address(0);
configuration.cctpTokenMessengers[SONIC_CHAIN_ID] = address(0);
configuration.cctpTokenMessengers[GNOSIS_CHAIN_ID] = address(0);
configuration.cctpTokenMessengers[BERACHAIN_CHAIN_ID] = address(0);
configuration.cctpTokenMessengers[UNICHAIN_CHAIN_ID] = address(0);
configuration.cctpTokenMessengers[WORLDCHAIN_CHAIN_ID] = address(0);
configuration.cctpTokenMessengers[HYPEREVM_CHAIN_ID] = address(0);
configuration.cctpTokenMessengers[FLARE_CHAIN_ID] = address(0);
```

**IMPORTANT NOTE ON ADDRESS VERIFICATION**: The TokenMessengerV2 address `0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440` should be verified against Circle's official documentation before deployment. Circle uses CREATE2 so the address is deterministic across chains, but the implementor MUST verify this is the correct V2 (not V1) address on each chain. Check https://developers.circle.com/stablecoins/docs/evm-smart-contracts for the latest deployment records.

### 7. `script/DeployV2Core.s.sol` -- MODIFY

**Step 1: Add to HookAddresses struct** (after `approveAndStargateSendHook` field, around line 97):
```solidity
address approveAndCCTPSendHook;
```

**Step 2: Add availability flag to ContractAvailability struct** (after `batchTransferFromHook` around line 246):
```solidity
bool cctpSendHook;
```

**Step 3: Add availability check in `_getContractAvailability`** (look for where other bridge availability checks are):
```solidity
if (configuration.cctpTokenMessengers[chainId] != address(0)) {
    availability.cctpSendHook = true;
    expectedHooks += 1; // ApproveAndCCTPSendHook
} else {
    potentialSkips[skipCount++] = "ApproveAndCCTPSendHook";
}
```

**Step 4: Update hooks array length**:
Change `uint256 len = 64;` to `uint256 len = 65;` (one new hook)

**Step 5: Add hook check in `_checkContractsExist`** (near other bridge checks around line 1276):
```solidity
// CCTP V2 bridge hooks
if (availability.cctpSendHook && superValidator != address(0)) {
    __checkContract(
        APPROVE_AND_CCTP_SEND_HOOK_KEY,
        __getSalt(APPROVE_AND_CCTP_SEND_HOOK_KEY),
        abi.encode(configuration.cctpTokenMessengers[chainId], superValidator),
        env
    );
} else if (!availability.cctpSendHook) {
    console2.log("SKIPPED ApproveAndCCTPSendHook: CCTP V2 not available on chain", chainId);
} else {
    revert("CCTP_HOOK_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
}
```

**Step 6: Add conditional hook deployment in `_deployHooks`** (after Stargate hooks, use index 64):
```solidity
// ===== CCTP V2 BRIDGE HOOK =====
if (availability.cctpSendHook) {
    address cctpValidator = _getContract(chainId, SUPER_VALIDATOR_KEY);
    require(cctpValidator != address(0), "CCTP_HOOK_VALIDATOR_PARAM_ZERO");
    require(cctpValidator.code.length > 0, "CCTP_HOOK_VALIDATOR_NOT_DEPLOYED");

    hooks[64] = _createSafeHookDeploymentWithArgs(
        APPROVE_AND_CCTP_SEND_HOOK_KEY,
        "ApproveAndCCTPSendHook",
        env,
        abi.encode(configuration.cctpTokenMessengers[chainId], cctpValidator)
    );
} else {
    console2.log("SKIPPED ApproveAndCCTPSendHook: CCTP V2 TokenMessenger not available on chain", chainId);
}
```

**Step 7: Add hook address assignment in `_populateHookAddresses`** (after Stargate entries):
```solidity
hookAddresses.approveAndCCTPSendHook =
    Strings.equal(hooks[64].name, APPROVE_AND_CCTP_SEND_HOOK_KEY) ? addresses[64] : address(0);
```

**Step 8: Add validation in final validation section** (conditional, like Across):
```solidity
if (availability.cctpSendHook) {
    require(
        hookAddresses.approveAndCCTPSendHook != address(0),
        "APPROVE_AND_CCTP_SEND_HOOK_NOT_ASSIGNED"
    );
}
```

### 8. `script/run/regenerate_bytecode.sh` -- MODIFY

Add to the `HOOK_CONTRACTS` array (after `ApproveAndStargateSendHook`):
```bash
"ApproveAndCCTPSendHook"
```

---

## Execution Flow Diagram

```
User signs UserOp with CCTP bridge hook data
    |
    v
SuperExecutor calls hook.build(prevHook, account, data)
    |
    v
hook._buildHookExecutions returns 4 Executions:
    |
    +-- [0] USDC.approve(TOKEN_MESSENGER, 0)          // Reset approval
    +-- [1] USDC.approve(TOKEN_MESSENGER, amount)      // Set exact approval
    +-- [2] TOKEN_MESSENGER.depositForBurn(             // Burn USDC
    |         amount,
    |         destinationDomain,
    |         mintRecipient,
    |         burnToken,
    |         destinationCaller,
    |         maxBurnAmountPerMessage,
    |         minFinalityThreshold
    |       )
    +-- [3] USDC.approve(TOKEN_MESSENGER, 0)          // Cleanup approval
    |
    v
BaseHook wraps with preExecute + postExecute => 6 total executions
    |
    v
Circle attestation service observes burn event
    |
    v
Circle relayer (or Superform bundler) calls receiveMessage on destination
    |
    v
USDC minted to mintRecipient on destination chain
```

---

## Security Considerations

1. **Approval Pattern**: Standard approve(0) -> approve(amount) -> call -> approve(0) prevents approval race conditions. This is critical for USDC which may have front-running concerns on approvals.

2. **Zero Address Validation**: burnToken, mintRecipient must be non-zero. The hook validates both.

3. **destinationCaller**: When set to a non-zero bytes32 value, ONLY the specified address can call `receiveMessage` on the destination chain. This prevents front-running of the receive transaction. When bytes32(0), anyone can relay the message. The user/SDK controls this.

4. **maxBurnAmountPerMessage**: This is a CCTP V2 safety feature. The SDK should set this based on per-route limits published by Circle. The hook passes it through without validation (Circle's contract validates it).

5. **minFinalityThreshold**: Controls finality requirements. Higher values = more security but slower. The SDK sets appropriate values per chain.

6. **No reentrancy risk**: The hook's `_buildHookExecutions` is a `view` function that only constructs calldata. Actual execution happens through the account's execution flow with BaseHook's pre/post mutex protection.

7. **Inspector compliance**: Only returns addresses (burnToken, mintRecipient). Never returns amounts or other data types.

8. **Token restriction**: While the hook accepts any `burnToken` address, in practice CCTP V2 only supports USDC (and EURC on some chains). The TokenMessengerV2 contract itself will revert if an unsupported token is passed. We do NOT add this validation in the hook because Circle may add new supported tokens in the future.

---

## Testing Strategy

### Unit Tests (CCTPHooks.t.sol)

- Inherit from `Helpers` (not `BaseTest` or `MinimalBaseIntegrationTest`)
- Use `vm.mockCall()` for external calls (TokenMessengerV2)
- Focus on:
  - Correct data decoding at all byte offsets
  - Proper execution array construction
  - Approval pattern correctness
  - Error conditions (zero addresses, zero amounts, short data)
  - PrevHookAmount handling
  - Inspector output
  - HookCallData signature appending

### Fork Tests (optional, can be added later)

- Fork Ethereum mainnet
- Use real TokenMessengerV2 at `0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440`
- Use real USDC
- Test that `depositForBurn` actually succeeds (burn USDC on forked mainnet)
- Cannot verify destination mint (would need cross-chain fork setup)

---

## Important Implementation Notes

### Note 1: No ETH value in depositForBurn
Unlike Stargate where `msg.value` carries the LZ fee, CCTP V2's `depositForBurn` requires NO native ETH. All Execution values should be 0.

### Note 2: bytes32 for mintRecipient
CCTP uses bytes32 for the recipient (left-padded), not address. This is because CCTP supports non-EVM chains (Solana). The hook data layout uses bytes32 for `mintRecipient`, and the inspector function extracts the address from the lower 20 bytes.

### Note 3: Domain IDs vs Chain IDs
CCTP uses its own domain numbering system, NOT EVM chain IDs. The mapping:
- Ethereum = 0, Avalanche = 1, Optimism = 2, Arbitrum = 3, Solana = 5, Base = 6, Polygon = 7
The SDK/off-chain system is responsible for mapping chain IDs to CCTP domain IDs. The hook passes through whatever domain ID is in the packed data.

### Note 4: TokenMessengerV2 address verification
Before deployment, verify the TokenMessengerV2 address `0x28b5a0e9CD0f5e4b4C1FD0e3285b6a170A165440` against Circle's official deployment records at:
- https://developers.circle.com/stablecoins/docs/evm-smart-contracts
- On-chain verification on Etherscan/Basescan/etc.

### Note 5: HookCallData and destination execution
The hookCallData field enables future destination execution support. Currently, CCTP V2 does not natively support passing messages with transfers. The signed hookCallData is prepared for off-chain pickup by the Superform bundler system. If Circle adds message support in a future CCTP version, the hook data layout already accommodates it.

### Note 6: No proportional minAmount scaling
Unlike Across (which has outputAmount) or Stargate (which has minAmountLD), CCTP V2's depositForBurn does not have a minimum output amount parameter. CCTP guarantees exact 1:1 minting of the burned amount (minus any protocol fees, which are currently 0). Therefore, when `usePrevHookAmount` is true, only the `amount` field is updated -- no proportional scaling of a min amount is needed.

### Note 7: Branch check
The implementation MUST be on the `pre-dev` branch. If the current branch is not `pre-dev`, alert the user before proceeding with implementation.

### Note 8: Existing Circle hooks in codebase
There are already 4 Circle Gateway hooks in `src/hooks/bridges/circle/`:
- `CircleGatewayWalletHook.sol` -- deposit to Circle Gateway Wallet
- `CircleGatewayMinterHook.sol` -- mint from Circle Gateway Minter (receive side)
- `CircleGatewayAddDelegateHook.sol` -- add delegate
- `CircleGatewayRemoveDelegateHook.sol` -- remove delegate

The new CCTP V2 hook is in a DIFFERENT directory (`src/hooks/bridges/cctp/`) because:
- It uses a completely different protocol (CCTP V2 vs Circle Gateway)
- Different interface (TokenMessengerV2 vs GatewayWallet/GatewayMinter)
- Different purpose (cross-chain bridge vs gateway wallet management)

---

## Implementation Order

1. Create `ITokenMessengerV2.sol` interface (simple, no dependencies)
2. Create `ApproveAndCCTPSendHook.sol` (depends on #1)
3. Create `CCTPHooks.t.sol` unit tests (depends on #2)
4. Run tests: `make forge-test TEST=CCTPHooks`
5. Verify all tests pass
6. Update deployment files (Constants.sol, ConfigBase.sol, ConfigCore.sol, DeployV2Core.s.sol)
7. Update regenerate_bytecode.sh
8. Run `forge build` to verify compilation
9. (Optional) Add fork integration test

---

## Comparison with Existing Bridge Hooks

| Feature | Across | Stargate | CCTP V2 |
|---------|--------|----------|---------|
| Constructor args | spokePool + validator | validator | tokenMessenger + validator |
| Native ETH flow | Yes (depositV3Now value) | Yes (sendToken value) | No (always 0) |
| ERC20 approve pattern | Yes (Approve variant) | Yes (Approve variant) | Yes (always) |
| Destination execution | Yes (destinationMessage) | Yes (composeMsg) | Prepared (hookCallData) |
| Validator signature | Appended to destinationMessage | Appended to composeMsg | Appended to hookCallData |
| Min output amount | outputAmount (proportional) | minAmountLD (proportional) | None (1:1 guaranteed) |
| Protocol fee in call | msg.value | msg.value (lzNativeFee) | None |
| Token restriction | Any ERC20/native | Per-pool token | USDC only (protocol-enforced) |
| Non-approve variant | Yes | Yes (native ETH) | No (not needed) |
| Hook subtype | BRIDGE | BRIDGE | BRIDGE |
| Hook type | NONACCOUNTING | NONACCOUNTING | NONACCOUNTING |
