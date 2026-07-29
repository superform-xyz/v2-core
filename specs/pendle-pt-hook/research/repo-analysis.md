# PendlePTHook Repository Analysis

## Reference Implementation: PendleUnifiedHook

### Architecture
- Located at `src/hooks/swappers/pendle/PendleUnifiedHook.sol`
- Inherits: `BaseHook`, `ISuperHookSwap`, `ISuperHookContextAware`, `ISuperHookInflowOutflow`, `ISuperHookOutflow`, `ISuperHookInspector`
- Immutable constructor params: `SuperRegistry`, `HookSubType` (PTYT), `PENDLE_ROUTER_V4`

### Three Execution Paths
1. **Buy PT** (`swapExactTokenForPt`): `_buildSwapTokenForPtExecutions`
   - Approves inputToken to Router, calls Router, cleans up
   - TokenInput struct with `tokenMintSy`, `netTokenIn`, SwapData, ApproxParams
2. **Sell PT** (`swapExactPtForToken`): `_buildSwapPtForTokenExecutions`
   - Approves PT to Router, calls Router, cleans up
   - TokenOutput struct with `tokenRedeemSy`, `minTokenOut`, SwapData
3. **Redeem PT** (`redeemPyToToken`): `_buildRedeemExecutions`
   - Approves PT+YT to Router, calls Router, cleans up
   - TokenOutput struct, redeems PT+YT pair post-maturity

### Payload Encoding (PendleUnifiedHook)
```
payload = bytes4(selector) + abi.encode(routingParams)
```
Where routingParams vary per selector but include: tokenMintSy/tokenRedeemSy, pendleSwap, SwapData, ApproxParams, LimitOrderData

### ISuperHookOutflow Implementation
- `AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION` (offset 92)
- `decodeAmounts()`: returns single amount at AMOUNT_POSITION
- `amountRoles()`: returns `AmountMeta(Direction.IN, Denomination.TOKEN)`
- `replaceCalldataAmounts()`: replaces amount at AMOUNT_POSITION

### Inspect Implementation
```solidity
function inspect(bytes calldata data) external pure returns (bytes memory) {
    address yieldSource = HookDataDecoder.extractYieldSource(data);
    address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
    return abi.encodePacked(yieldSource, outputToken);
}
```
Returns 40 bytes: `abi.encodePacked(yieldSource, outputToken)`

### Amount Handling
- `inputAmount` read from header at `SwapCalldataLayout.INPUT_AMOUNT_OFFSET` (92)
- `outputMin` read from header at `SwapCalldataLayout.OUTPUT_MIN_OFFSET` (156)
- `usePrevHookAmount` flag at offset 188
- When `usePrevHookAmount=true`: reads actual amount from transient storage, scales `outputMin` via `HookDataUpdater.getUpdatedOutputAmount()`

### Key Constants
- Hook key: `PENDLE_UNIFIED_HOOK` in `Constants.sol`
- HookSubType: `PTYT = keccak256(bytes("PTYT"))` in `HookSubTypes.sol`
- Router: `PENDLE_ROUTER_V4` per-chain addresses in `Constants.sol`

### Test Patterns
- Unit tests: `test/unit/hooks/pendle/PendleUnifiedHook.t.sol`
- E2E tests: `test/integration/pendle/PendleUnifiedHookE2E.t.sol`
- Mocks: `MockPendleMarket`, `MockPendlePT`, `MockPendleYT`, `MockPendleSY`, `MockPendleRouterV4`
- Test helpers build calldata with proper header layout + payload encoding

### SwapCalldataLayout Offsets
```
yieldSourceOracleId: 0 (32 bytes)
yieldSource: 32 (20 bytes)
inputToken: 52 (20 bytes)
outputToken: 72 (20 bytes)
inputAmount: 92 (32 bytes) = AMOUNT_POSITION
outputQuote: 124 (32 bytes)
outputMin: 156 (32 bytes)
usePrevHookAmount: 188 (1 byte)
payloadLength: 189 (32 bytes)
payload: 221+
```

### Hook Classification
In `tooling/hook-classification.yaml`:
```yaml
PendleUnifiedHook:
  interfaces: [ISuperHookSwap, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookInspector]
  hookSubType: PTYT
```
