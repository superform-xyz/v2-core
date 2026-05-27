# Repository Research: StargateAdapter Implementation Patterns

## 1. Existing Adapter Contract Patterns

### AcrossV3Adapter (`src/adapters/AcrossV3Adapter.sol`, 89 lines)
- **License**: `Apache-2.0`, **Pragma**: `0.8.30`
- **Implements**: Bridge-specific receiver interface (`IAcrossV3Receiver`)
- **Immutable storage**: Two `address public immutable` - bridge entry point + `SUPER_DESTINATION_EXECUTOR`
- **Constructor**: Takes two addresses, validates non-zero, reverts `ADDRESS_NOT_VALID()`
- **Sender validation**: `msg.sender != ACROSS_SPOKE_POOL` -> reverts `INVALID_SENDER()`
- **Message decoding**: Standard `abi.decode` 6-tuple: `(bytes initData, bytes executorCalldata, address account, address[] dstTokens, uint256[] intentAmounts, bytes sigData)`
- **Token transfer**: `IERC20(tokenSent).safeTransfer(account, amount)` BEFORE calling executor (line 76)
- **Executor call**: `processBridgedExecution(tokenSent, account, dstTokens, intentAmounts, initData, executorCalldata, sigData)` (lines 79-87)

### DebridgeAdapter (`src/adapters/DebridgeAdapter.sol`, 160 lines)
- **Dual-path**: Separate `onEtherReceived` and `onERC20Received` methods
- **ETH handling**: `(bool success,) = account.call{value: address(this).balance}("")` with `ON_ETHER_RECEIVED_FAILED()` error
- **Private helpers**: `_handleMessageReceived` consolidates executor call, `_decodeMessage` isolates ABI decoding
- **Modifier**: `onlyExternalCallAdapter` for auth
- **No `receive()` function** - ETH comes via `onEtherReceived` payable function

## 2. ISuperDestinationExecutor Interface

**File**: `src/interfaces/ISuperDestinationExecutor.sol` (lines 108-117)

```solidity
function processBridgedExecution(
    address tokenSent,
    address targetAccount,
    address[] memory dstTokens,
    uint256[] memory intentAmounts,
    bytes memory initData,
    bytes memory executorCalldata,
    bytes memory userSignatureData
) external;
```

**Important**: The executor does NOT validate who called it. Any address can call `processBridgedExecution`. Security comes from signature/merkle proof validation.

## 3. StargateSendHook ComposeMsg Encoding (lines 146-162)

The composeMsg enters the hook with 5 fields (no signature). The hook retrieves the signature from validator transient storage and appends it:

```
Input:  abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts)
Output: abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)
```

## 4. Vendor Interfaces Available

- `src/vendor/bridges/stargate/IStargate.sol` - `token() -> address`
- `src/vendor/bridges/layerzero/IOFT.sol` - `token() -> address` (selector `0xfc0c546a`)
- **Missing**: `ILayerZeroComposer` does NOT exist yet. Needs to be created.

## 5. Deployment Patterns

- **Locked bytecode**: Adapters tracked in `script/locked-bytecode/`, `script/generated-bytecode/`, `script/locked-bytecode-dev/`
- **Regenerate script**: `script/run/regenerate_bytecode.sh` - adapters listed in `CORE_CONTRACTS` array (lines 86-87)
- **CREATE2 deployment**: `new StargateAdapter{salt: SALT}(...)` pattern in `test/BaseTest.t.sol`
- **Constants**: `test/utils/Constants.sol` - need to add LZ_ENDPOINT constant

## 6. Test Patterns

**Unit tests** at `test/unit/adapters/AdaptersUnitTests.sol`:
1. Constructor zero-address reverts
2. Sender validation (prank as wrong address)
3. Decoding tests (empty bytes revert)
4. Token transfer tests
5. Happy path with mock executor
6. `_buildDestinationData()` helper for standard 6-tuple
7. Test contract implements `processBridgedExecution` as mock

## 7. Files to Create/Modify

| # | File | Action |
|---|------|--------|
| 1 | `src/vendor/bridges/layerzero/ILayerZeroComposer.sol` | CREATE |
| 2 | `src/adapters/StargateAdapter.sol` | CREATE |
| 3 | `test/unit/adapters/AdaptersUnitTests.sol` | MODIFY |
| 4 | `script/run/regenerate_bytecode.sh` | MODIFY |
| 5 | `test/utils/Constants.sol` | MODIFY |
| 6 | `test/BaseTest.t.sol` | MODIFY |

## 8. OFTComposeMsgCodec Decoding

```solidity
// Skip: nonce(8) + srcEid(4) + amountLD(32) + composeSender(32) = 76 bytes
bytes memory composeMsg = _message[76:];
// Then standard 6-tuple decode
```

## 9. Code Style

- Section comments with `/*///...*/` dividers
- NatSpec: `@title`, `@author Superform Labs`, `@notice`
- `using SafeERC20 for IERC20;`
- Immutables: ALL_CAPS (`SUPER_DESTINATION_EXECUTOR`)
- Constructor params: trailing underscore (`superDestinationExecutor_`)
- No ReentrancyGuard on existing adapters
- Unused params: `address,` (no name)
