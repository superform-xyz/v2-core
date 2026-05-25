# CCTP Bridge Hooks - Repository Analysis

## Date: 2026-05-06

## Existing Bridge Hook Patterns

### Directory Structure
- `src/hooks/bridges/across/` — Across V3 bridge hooks
- `src/hooks/bridges/debridge/` — deBridge bridge hooks
- `src/hooks/bridges/stargate/` — Stargate V2 bridge hooks
- `src/hooks/bridges/circle/` — Circle Gateway hooks (fiat on/off-ramp, NOT CCTP)
- New: `src/hooks/bridges/cctp/` — CCTP V2 bridge hooks

### Hook Patterns Comparison

| Aspect | Across | Stargate | CCTP V2 (planned) |
|--------|--------|----------|--------------------|
| Constructor | spokePool + validator | validator only | tokenMessenger + validator |
| Hook variants | Send + ApproveAndSend | Send + ApproveAndSend | ApproveAndSend only |
| Native ETH variant | Yes | Yes (native pools) | No (USDC is always ERC20) |
| Dest execution | destinationMessage | composeMsg | hookCallData (off-chain) |
| Min output | outputAmount (proportional) | minAmountLD (proportional) | None (1:1 guaranteed) |
| Protocol fee | msg.value | msg.value (lzNativeFee) | None |
| Hook type | NONACCOUNTING | NONACCOUNTING | NONACCOUNTING |
| Hook subtype | BRIDGE | BRIDGE | BRIDGE |

### Key Reference Files
- `src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol` — Best pattern match (immutable protocol address + validator)
- `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol` — Approve pattern with destination execution
- `src/hooks/BaseHook.sol` — Base hook implementation
- `src/libraries/HookSubTypes.sol` — Hook subtype definitions
- `src/interfaces/ISuperHook.sol` — Hook interfaces
- `src/interfaces/ISuperSignatureStorage.sol` — Validator signature retrieval
- `src/vendor/BytesLib.sol` — Byte-level data decoding

### Deployment Integration Points
- `script/utils/Constants.sol` — Hook key constants
- `script/DeployV2Core.s.sol` — Deployment orchestration
- `script/run/regenerate_bytecode.sh` — Bytecode generation

### Testing Patterns
- `test/unit/hooks/bridges/StargateHooks.t.sol` — Unit test reference
- Tests inherit from `Helpers`
- Use `vm.mockCall()` for external protocol calls
- Data encoding helpers with `abi.encodePacked`

### Existing Circle Hooks (NOT CCTP)
The 4 existing hooks in `src/hooks/bridges/circle/` are for Circle Gateway (fiat on/off-ramp), completely separate from CCTP V2 bridge hooks.
