# OFT Send Hook - Repository Analysis

## 1. Existing Stargate Hook Implementations

### StargateSendHook (`src/hooks/bridges/stargate/StargateSendHook.sol`)
- **Purpose**: Sends native tokens (ETH) cross-chain via Stargate V2 with optional destination execution
- **Constructor**: `(address validator_)` only
- **Data layout** (tightly packed):

| Offset | Size | Field |
|--------|------|-------|
| 0 | 32 | `uint256 lzNativeFee` |
| 32 | 32 | `uint256 lzTokenFee` |
| 64 | 20 | `address stargatePool` |
| 84 | 20 | `address inputToken` |
| 104 | 20 | `address lzToken` |
| 124 | 4 | `uint32 dstEid` |
| 128 | 32 | `bytes32 to` |
| 160 | 32 | `uint256 amountLD` |
| 192 | 32 | `uint256 minAmountLD` |
| 224 | 1 | `bool usePrevHookAmount` |
| 225 | 1 | `bool isBusMode` |
| 226 | 32 | `uint256 extraOptionsLength` |
| 258 | var | `bytes extraOptions` |
| 258+len | 32 | `uint256 composeMsgLength` |
| 290+len | var | `bytes composeMsg` |

- **Minimum data length**: 290 bytes (line 97)
- **Pool validation**: Calls `IStargate(s.stargatePool).token()` to verify pool (line 116)
- **Value computation**: `value = lzNativeFee + amountLD` for native sends (line 190)

### ApproveAndStargateSendHook (`src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`)
- **Purpose**: ERC20-only with approve(0) -> approve(amount) -> execute -> approve(0) pattern
- **Key difference**: Reads `inputToken` at offset 84 (line 106) and validates `IStargate(s.stargatePool).token() != s.inputToken` (line 121)
- **Value computation**: `value = lzNativeFee` only for ERC20 (line 236)
- **Execution count**: 4 (no lzTokenFee), 4 (lzTokenFee same token), 7 (lzTokenFee different token)

## 2. IStargate Vendor Interface

```solidity
interface IStargate {
    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;        // <-- only difference from standard OFT
    }
    struct MessagingFee { uint256 nativeFee; uint256 lzTokenFee; }
    struct MessagingReceipt { bytes32 guid; uint64 nonce; MessagingFee fee; }
    struct OFTReceipt { uint256 amountSentLD; uint256 amountReceivedLD; }

    function sendToken(SendParam, MessagingFee, address) external payable returns (MessagingReceipt, OFTReceipt);
    function quoteSend(SendParam, bool) external view returns (MessagingFee);
    function token() external view returns (address);
}
```

## 3. Key Difference: sendToken() vs IOFT.send()

| Aspect | Stargate `sendToken()` | IOFT `send()` |
|--------|----------------------|---------------|
| Function name | `sendToken` | `send` |
| Parameters | `(SendParam, MessagingFee, address)` | `(SendParam, MessagingFee, address)` |
| Returns | `(MessagingReceipt, OFTReceipt)` | `(MessagingReceipt, OFTReceipt)` |
| SendParam struct | Has `oftCmd` field | **No** `oftCmd` field |
| `token()` return | Underlying ERC20 address | `address(this)` for standard OFT |
| `oftCmd` usage | Bus/taxi mode flag | N/A |
| Approval target | Pool contract | OFT/OFTAdapter contract |

## 4. Mode Flag Pattern Analysis

**No existing mode flag pattern** found in hook codebase. All hooks are single-purpose. However:

- `isBusMode` boolean at offset 225 is the closest precedent to a "mode" concept
- `_decodeBool()` from BaseHook: `data[offset] != 0` — any non-zero byte is truthy

### Recommended: Repurpose `isBusMode` as `uint8 mode`

| Mode | Behavior |
|------|----------|
| 0 | Stargate `sendToken()` taxi mode (`oftCmd = bytes("")`) — equivalent to old `isBusMode=false` |
| 1 | Stargate `sendToken()` bus mode (`oftCmd = abi.encodePacked(uint8(1))`) — equivalent to old `isBusMode=true` |
| 2 | IOFT `send()` (generic OFT, no `oftCmd`) |

**Benefits**: No offset changes, same minimum data length (290), backward-compatible byte interpretation (0=taxi was false, 1=bus was true).

## 5. Pool Validation Differences

- **Stargate**: `IStargate(s.stargatePool).token()` validates pool exists
- **OFT**: `stargatePool` field reinterpreted as OFT address. `token()` exists on OFT too but returns `address(this)` for standard OFTs, or underlying token for OFTAdapter
- **ApproveAndStargateSendHook**: Validates `IStargate(s.stargatePool).token() != s.inputToken` — needs different logic for OFT mode

## 6. Deployment & Bytecode

- **Constants.sol** (lines 258-259): `STARGATE_SEND_HOOK_KEY` and `APPROVE_AND_STARGATE_SEND_HOOK_KEY`
- **DeployV2Core.s.sol**: Deployed at indices 62-63, constructor `abi.encode(stargateValidator)`
- **Locked bytecode** exists at `script/locked-bytecode/`, `script/locked-bytecode-dev/`, `script/generated-bytecode/`
- Bytecode change = new address via CREATE2 = redeployment required

## 7. Test Infrastructure

### Unit tests (`test/unit/hooks/bridges/StargateHooks.t.sol`, 1118 lines)
- Helper: `_encodeStargateData(bool usePrevHookAmount, bool isBusMode, bool includeComposeMsg)` (line 1090)
- Uses `MockStargateSignatureStorage` for validator mock
- Uses `vm.mockCall` for `IStargate.token()` responses

### Integration tests
- `test/integration/stargate/StargateHooksFork.t.sol` — fork tests against real Stargate USDC pool on mainnet
- `test/integration/stargate/StargateSmartAccountFork.t.sol` — full ERC-4337 flow

## 8. No Existing IOFT Interface

No IOFT interface exists in `src/vendor/`. A new file needed at `src/vendor/bridges/layerzero/IOFT.sol` or `src/vendor/bridges/stargate/IOFT.sol`.

## 9. Implementation Considerations

1. **Struct compatibility**: `IStargate.SendParam` identical to `IOFT.SendParam` except Stargate adds `oftCmd`. Same build logic, only function call differs.
2. **composeMsg**: OFT `send()` supports `composeMsg` in SendParam — existing signature-appending logic applies to both modes.
3. **Native value**: Same `lzNativeFee + amountLD` for native, `lzNativeFee` for ERC20 — applies to both modes.
4. **inspect()**: Returns addresses from fixed offsets — no change needed.
5. **No constructor changes**: Validator is the only param, no mode-specific constructor logic.
