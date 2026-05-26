# StargateAdapter - Technical Specification

## Overview

Implement a `StargateAdapter` contract that receives LayerZero V2 compose messages on the destination chain, decodes the OFT compose payload, transfers received tokens to the target smart account, and calls `SuperDestinationExecutor.processBridgedExecution()`. This completes the destination-side flow for cross-chain operations initiated by `StargateSendHook` / `ApproveAndStargateSendHook` with compose messages.

## Problem Statement / Motivation

Superform v2 currently supports destination execution via Across (`AcrossV3Adapter`) and deBridge (`DebridgeAdapter`) bridges. The `StargateSendHook` and `ApproveAndStargateSendHook` already support sending cross-chain with `composeMsg` payloads, but there is no destination-side adapter to receive and process these compose messages. Without this adapter, cross-chain operations via Stargate/LayerZero cannot trigger destination execution.

## Proposed Solution

A standalone adapter contract at `src/adapters/StargateAdapter.sol` implementing `ILayerZeroComposer`. Follows the exact same adapter pattern as `AcrossV3Adapter` and `DebridgeAdapter`:
1. Receive bridge callback (via `lzCompose`)
2. Validate sender (`msg.sender == LZ_ENDPOINT`)
3. Decode payload (strip OFTComposeMsgCodec header, decode 6-tuple)
4. Transfer tokens to target account
5. Call `processBridgedExecution()`

## Technical Considerations

### Token Delivery Timing (Two-Transaction Model)
- **Transaction 1 (lzReceive)**: Destination Stargate pool credits tokens to adapter, calls `endpoint.sendCompose()` to queue compose
- **Transaction 2 (lzCompose)**: LZ endpoint calls `adapter.lzCompose()`. Tokens already in adapter balance.
- If `lzCompose` reverts, tokens stay in adapter, compose is retryable from LZ queue

### OFTComposeMsgCodec Format
```
Offset | Type    | Size     | Field
-------|---------|----------|------------------
0      | uint64  | 8 bytes  | nonce
8      | uint32  | 4 bytes  | srcEid
12     | uint256 | 32 bytes | amountLD (post-fee)
44     | bytes32 | 32 bytes | composeFrom
76     | bytes   | variable | composeMsg (inner payload)
```

The inner `composeMsg` (offset 76+) is the standard 6-tuple:
```solidity
abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)
```

### Key Design Decisions
- **Balance-based transfer**: Transfer full adapter balance, not `amountLD` from codec. Simpler, handles rounding.
- **Endpoint-only validation**: `msg.sender == LZ_ENDPOINT` only. No `_from` whitelist.
- **Token identification**: `_from.token()` - selector `0xfc0c546a` shared by IStargate and IOFT.
- **Native ETH**: `receive()` function for StargatePoolNative. `_from.token() == address(0)` triggers ETH path.
- **Constructor params**: `lzEndpoint_`, `superDestinationExecutor_` (enables test mocking).
- **No source hook changes**: Bundler sets `to = adapter address`. Hook trust the bundler.

### Known Limitations
- **Dust accumulation**: Failed compose retries leave tokens in adapter. Next successful compose sweeps all balance (including dust) to its target account.
- **Concurrent compose sweep**: Two lzReceives for same token -> first lzCompose sweeps both -> second gets zero.
- **Compose index**: Only index 0 supported (Stargate standard).
- **Fee-on-transfer tokens**: Not supported (Stargate pools use standard ERC20s).

## Attack Surface Analysis

### Reentrancy
- [x] ETH forwarding before `processBridgedExecution` - mitigated by layered defense: LZ endpoint compose hash, executor's `usedMerkleRoots`, `nonReentrant` on `_processHook`
- [x] Consistent with existing adapters (no ReentrancyGuard)

### Token Balance Manipulation
- [x] Donation attack (inflating balance between lzReceive/lzCompose): Impact limited - extra tokens go to user account, attacker loses funds
- [x] Zero balance compose: Executor handles gracefully via `ReceivedButNotEnoughBalance` event

### Cross-Chain
- [x] Message replay: LZ endpoint provides nonce/compose hash protection + executor's merkle root tracking
- [x] Authentication: Only LZ endpoint can call `lzCompose`

### Exploit Precedent
| Protocol | Loss | Relevance | Our Mitigation |
|----------|------|-----------|----------------|
| Nomad ($190M) | Auth bypass | `msg.sender` check prevents | Immutable LZ endpoint via CREATE2 |
| KelpDAO ($292M) | DVN compromise | DVN config is Stargate's concern | Not adapter-level risk |

## Acceptance Criteria

### Functional
- [ ] Receive ERC20 token compose messages via `lzCompose`
- [ ] Receive native ETH compose messages via `lzCompose`
- [ ] Handle both Stargate pool compose (mode 0/1) and OFT compose (mode 2)
- [ ] Transfer full adapter token balance to target account
- [ ] Call `processBridgedExecution()` with decoded 6-tuple payload
- [ ] Accept native ETH via `receive()` function

### Validation
- [ ] Revert `INVALID_SENDER` if `msg.sender != LZ_ENDPOINT`
- [ ] Revert `ADDRESS_NOT_VALID` if constructor params are zero
- [ ] Revert `ETH_TRANSFER_FAILED` if native ETH forwarding fails
- [ ] Revert on malformed `_message` (length < 76 or invalid inner ABI encoding)

### Security
- [ ] Only LZ endpoint can trigger compose execution
- [ ] SafeERC20 for all token transfers
- [ ] ETH forwarding via `call{value}` (not `transfer()`)

## Implementation

### File 1: `src/vendor/bridges/layerzero/ILayerZeroComposer.sol` (NEW)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ILayerZeroComposer
/// @notice Interface for contracts that receive composed LayerZero messages
/// @dev See https://docs.layerzero.network/v2/developers/evm/composer/overview
interface ILayerZeroComposer {
    /// @notice Composes a LayerZero message from an OApp
    /// @param _from The address initiating the composition (destination OApp/pool)
    /// @param _guid The unique identifier for the corresponding LayerZero src/dst tx
    /// @param _message The composed message payload (OFTComposeMsgCodec-encoded)
    /// @param _executor The address of the executor for the composed message
    /// @param _extraData Additional arbitrary data passed by the executor
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable;
}
```

### File 2: `src/adapters/StargateAdapter.sol` (NEW)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External Dependencies
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Vendor Interfaces
import { ILayerZeroComposer } from "../vendor/bridges/layerzero/ILayerZeroComposer.sol";
import { IStargate } from "../vendor/bridges/stargate/IStargate.sol";

// Superform Interfaces
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";

/// @title StargateAdapter
/// @author Superform Labs
/// @notice Receives LayerZero V2 compose messages from Stargate/OFT and forwards them to SuperDestinationExecutor
/// @dev This contract acts as a translator between LayerZero V2 compose callbacks and the core Superform execution logic
/// @dev Supports both Stargate pool tokens (mode 0/1) and generic OFT tokens (mode 2)
/// @dev Token delivery happens in a separate transaction (lzReceive) before lzCompose is called
/// @dev WARNING: This contract uses balance-based transfers. If a prior compose failed and left dust,
/// @dev the next successful compose will sweep all held tokens (including dust) to its target account.
contract StargateAdapter is ILayerZeroComposer {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Offset where the inner composeMsg starts in the OFTComposeMsgCodec-encoded message
    /// @dev Layout: nonce(8) + srcEid(4) + amountLD(32) + composeFrom(32) = 76 bytes header
    uint256 private constant COMPOSE_MSG_OFFSET = 76;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The LayerZero V2 EndpointV2 address
    /// @dev Same on all EVM chains: 0x1a44076050125825900e736c501f859c50fE728c
    address public immutable LZ_ENDPOINT;

    /// @notice The SuperDestinationExecutor for processing bridged executions
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a constructor argument is the zero address
    error ADDRESS_NOT_VALID();

    /// @notice Thrown when lzCompose is called by an address other than the LZ endpoint
    error INVALID_SENDER();

    /// @notice Thrown when native ETH transfer to the target account fails
    error ETH_TRANSFER_FAILED();

    /// @notice Thrown when the compose message is too short to contain the OFTComposeMsgCodec header
    error COMPOSE_MSG_TOO_SHORT();

    /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param lzEndpoint_ The LayerZero V2 EndpointV2 address
    /// @param superDestinationExecutor_ The SuperDestinationExecutor address
    constructor(address lzEndpoint_, address superDestinationExecutor_) {
        if (lzEndpoint_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        LZ_ENDPOINT = lzEndpoint_;
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
    }

    /*//////////////////////////////////////////////////////////////
                                 RECEIVE
    //////////////////////////////////////////////////////////////*/

    /// @dev Accepts native ETH from StargatePoolNative during lzReceive token credit
    /// @dev WARNING: Any ETH sent to this contract will be forwarded to the next compose account
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            LAYERZERO COMPOSE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILayerZeroComposer
    /// @dev Decodes the OFTComposeMsgCodec message, transfers tokens to the target account,
    ///      and forwards the execution payload to SuperDestinationExecutor
    /// @dev The _from parameter is the destination Stargate pool or OFT contract (NOT the source chain sender)
    /// @dev Uses balance-based transfers: transfers full adapter balance of the identified token
    function lzCompose(
        address _from,
        bytes32, // _guid
        bytes calldata _message,
        address, // _executor
        bytes calldata // _extraData
    )
        external
        payable
        override
    {
        // 1. Validate sender: only the LZ endpoint can call lzCompose
        if (msg.sender != LZ_ENDPOINT) revert INVALID_SENDER();

        // 2. Validate message length: must contain OFTComposeMsgCodec header
        if (_message.length < COMPOSE_MSG_OFFSET) revert COMPOSE_MSG_TOO_SHORT();

        // 3. Decode the inner application payload (skip 76-byte OFTComposeMsgCodec header)
        (
            bytes memory initData,
            bytes memory executorCalldata,
            address account,
            address[] memory dstTokens,
            uint256[] memory intentAmounts,
            bytes memory sigData
        ) = abi.decode(_message[COMPOSE_MSG_OFFSET:], (bytes, bytes, address, address[], uint256[], bytes));

        // 4. Identify token via _from.token()
        //    - Stargate ERC20 pools: returns underlying ERC20 address
        //    - StargatePoolNative: returns address(0) for ETH
        //    - OFT contracts: returns address(this) (OFT IS the token)
        //    - OFTAdapter contracts: returns underlying ERC20 address
        address tokenSent = IStargate(_from).token();

        // 5. Transfer received funds to the target account before calling the executor
        if (tokenSent == address(0)) {
            // Native ETH path
            (bool success,) = account.call{ value: address(this).balance }("");
            if (!success) revert ETH_TRANSFER_FAILED();
        } else {
            // ERC20 path
            uint256 balance = IERC20(tokenSent).balanceOf(address(this));
            IERC20(tokenSent).safeTransfer(account, balance);
        }

        // 6. Forward to SuperDestinationExecutor
        SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            tokenSent,
            account,
            dstTokens,
            intentAmounts,
            initData,
            executorCalldata,
            sigData
        );
    }
}
```

### File 3: Unit Tests - `test/unit/adapters/AdaptersUnitTests.sol` (MODIFY)

Add StargateAdapter test section following the existing AcrossV3Adapter/DebridgeAdapter test pattern:

**Test cases:**
1. `test_StargateAdapter_Constructor` - validates immutable assignments
2. `test_StargateAdapter_Constructor_RevertIf_ZeroEndpoint` - zero lzEndpoint reverts
3. `test_StargateAdapter_Constructor_RevertIf_ZeroExecutor` - zero executor reverts
4. `test_StargateAdapter_lzCompose_RevertIf_InvalidSender` - non-endpoint caller reverts
5. `test_StargateAdapter_lzCompose_RevertIf_MessageTooShort` - message < 76 bytes reverts
6. `test_StargateAdapter_lzCompose_ERC20_HappyPath` - ERC20 token compose flow
7. `test_StargateAdapter_lzCompose_NativeETH_HappyPath` - native ETH compose flow
8. `test_StargateAdapter_lzCompose_NativeETH_RevertIf_AccountNotPayable` - ETH to non-payable account
9. `test_StargateAdapter_lzCompose_TransfersFullBalance` - verifies full balance sweep
10. `test_StargateAdapter_lzCompose_ZeroBalance` - zero-balance compose calls executor
11. `test_StargateAdapter_lzCompose_DustFromPriorCompose` - dust included in transfer
12. `test_StargateAdapter_receive_AcceptsETH` - receive() function works

**Mock requirements:**
- Mock Stargate pool with configurable `token()` return value
- Mock LZ endpoint address for `msg.sender` validation
- Mock `ISuperDestinationExecutor` to verify `processBridgedExecution` call args

**OFTComposeMsgCodec test helper:**
```solidity
function _encodeComposeMsg(
    uint64 nonce_,
    uint32 srcEid_,
    uint256 amountLD_,
    bytes32 composeFrom_,
    bytes memory innerPayload_
) internal pure returns (bytes memory) {
    return abi.encodePacked(nonce_, srcEid_, amountLD_, composeFrom_, innerPayload_);
}
```

### File 4: Infrastructure Updates

**`test/utils/Constants.sol` (MODIFY)**
```solidity
address public constant LZ_V2_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
```

**`script/run/regenerate_bytecode.sh` (MODIFY)**
Add `StargateAdapter` to `CORE_CONTRACTS` array.

**`test/BaseTest.t.sol` (MODIFY)**
Add `StargateAdapter` deployment with `new StargateAdapter{salt: SALT}(LZ_V2_ENDPOINT, address(superDestinationExecutor))`.

## Test Plan

### Unit Tests
- [ ] Constructor validation (zero-address reverts, immutable assignments)
- [ ] Sender validation (only LZ endpoint)
- [ ] Message length validation (< 76 bytes reverts)
- [ ] ERC20 compose happy path (transfer + executor call)
- [ ] Native ETH compose happy path (ETH forward + executor call)
- [ ] ETH transfer failure revert
- [ ] Balance-based transfer (full balance swept)
- [ ] Zero-balance compose (executor handles)
- [ ] Dust accumulation scenario
- [ ] `receive()` function accepts ETH

### Fuzz Tests
- [ ] Message length fuzzing (revert for < 76 bytes)
- [ ] Token amount fuzzing (full balance transfer)
- [ ] ETH amount fuzzing (full balance forwarded)

### Integration/Fork Tests (optional, if LayerZeroV2Helper available)
- [ ] Real Stargate pool `token()` call on mainnet fork
- [ ] OFTComposeMsgCodec encoding matches real LZ format

## Deployment

- Add `StargateAdapter` to `CORE_CONTRACTS` in `regenerate_bytecode.sh`
- Constructor: `(LZ_V2_ENDPOINT, superDestinationExecutor)`
- Deploy on all Superform chains (LZ endpoint same address everywhere)
- Add to locked-bytecode system

## References

- Existing adapters: `src/adapters/AcrossV3Adapter.sol`, `src/adapters/DebridgeAdapter.sol`
- StargateSendHook compose encoding: `src/hooks/bridges/stargate/StargateSendHook.sol:146-162`
- SuperDestinationExecutor: `src/executors/SuperDestinationExecutor.sol`
- LZ V2 Composers: https://docs.layerzero.network/v2/developers/evm/composer/overview
- Stargate V2 Composability: https://stargateprotocol.gitbook.io/stargate/v2-developer-docs/integrate-with-stargate/composability
- OFTComposeMsgCodec: https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oft/libs/OFTComposeMsgCodec.sol
- LZ V2 Security Checklist: https://github.com/windhustler/Interoperability-Protocol-Security-Checklist/blob/main/audit-checklists/LayerZeroV2.md
