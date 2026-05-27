# Repository Analysis - Bridge Hook Patterns

## Existing Bridge Hooks

### `src/hooks/bridges/across/` (2 files)
- `AcrossSendFundsAndExecuteOnDstHook.sol` - Native ETH bridge
- `ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol` - ERC20 with approval

### `src/hooks/bridges/debridge/` (2 files)
- `DeBridgeSendOrderAndExecuteOnDstHook.sol` - DLN order creation
- `DeBridgeCancelOrderHook.sol` - Order cancellation

### `src/hooks/bridges/circle/` (4 files)
- Circle CCTP gateway hooks (already implemented)

## Vendor Interfaces (`src/vendor/bridges/`)
- `across/IAcrossSpokePoolV3.sol`
- `across/IAcrossV3Receiver.sol`
- `debridge/IDlnSource.sol`
- `debridge/IDeBridgeGate.sol`
- `debridge/IExternalCallExecutor.sol`
- **No Stargate interfaces exist yet** - need to create `src/vendor/bridges/stargate/IStargate.sol`

## Common Patterns

### Constructor
- All bridge hooks take target contract address + validator
- Exception: Stargate will only take validator (pool is per-token, in data)

### HookType & SubType
- All use `HookType.NONACCOUNTING` + `HookSubTypes.BRIDGE`

### Signature Injection
All bridge hooks with dst execution follow identical pattern:
```solidity
bytes memory signature = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account);
// decode 5-field composeMsg, re-encode with 6 fields (+ signature)
```

### Inspector
Returns only addresses packed with `abi.encodePacked`

### usePrevHookAmount
All bridge hooks scale output amounts proportionally using `Math.mulDiv`

## Test File
Single file: `test/unit/hooks/bridges/BridgeHooks.t.sol` covers all bridge hooks.
Stargate tests should go in a separate `StargateHooks.t.sol` for isolation.

## Key Interface: `ISuperSignatureStorage`
```solidity
interface ISuperSignatureStorage {
    function retrieveSignatureData(address account) external view returns (bytes memory);
}
```
Implemented by SuperValidator, stores signature in transient storage during UserOp validation.

## HookSubTypes (`src/libraries/HookSubTypes.sol`)
```solidity
bytes32 public constant BRIDGE = keccak256(bytes("Bridge"));
```
No new subtype needed for Stargate.

## Git Note
Branch `feat/stargate-bridge-SUP-19617` exists remotely but is not merged into dev.
