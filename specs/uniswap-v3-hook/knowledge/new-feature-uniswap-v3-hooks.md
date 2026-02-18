---
title: UniswapV3 Swap Hooks Implementation
category: new-feature
date: 2026-02-02
spec: /specs/uniswap-v3-hook/spec.md
components:
  - src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol
  - src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.sol
  - src/hooks/swappers/uniswap-v3/interfaces/ISwapRouter.sol
  - test/unit/hooks/swappers/uniswap-v3/UniswapV3UnitTests.t.sol
  - test/integration/uniswap-v3/UniswapV3HookIntegrationTest.t.sol
tags:
  - hooks
  - swappers
  - uniswap-v3
  - dex
  - hook-chaining
---

# UniswapV3 Swap Hooks Implementation

## Summary

Implementation of Uniswap V3 swap functionality as modular hooks for the Superform protocol. This feature provides `exactInputSingle` swap capability through two variants:

1. **SwapUniswapV3Hook** - Minimal hook (1 execution) assuming tokens are pre-approved to the router
2. **ApproveAndSwapUniswapV3Hook** - Full approval lifecycle hook (4 executions) supporting USDT-like tokens

Both hooks support hook chaining via `usePrevHookAmount` flag with proportional slippage recalculation.

## Implementation Details

### Key Decisions

#### 1. Two Hook Variants Pattern
- **SwapUniswapV3Hook**: Gas-optimized for cases where approval already exists
- **ApproveAndSwapUniswapV3Hook**: Handles full approval lifecycle: `approve(0) → approve(amount) → swap → approve(0)`
- Rationale: Follows established Odos hook patterns, provides flexibility based on use case

#### 2. Packed Data Format (193 bytes)
The hook uses tightly packed data for gas efficiency:

```
Offset | Size | Field
-------|------|------
0-19   | 20   | tokenIn (address)
20-39  | 20   | tokenOut (address)
40-43  | 4    | fee (uint24 via uint32)
44-63  | 20   | recipient (address)
64-95  | 32   | deadline (uint256)
96-127 | 32   | sqrtPriceLimitX96 (uint160 via uint256)
128-159| 32   | originalAmountIn (uint256)
160-191| 32   | originalMinAmountOut (uint256)
192    | 1    | usePrevHookAmount (bool)
```

- **Why packed?** Each non-zero calldata byte costs 16 gas, zero bytes cost 4 gas
- **Why aligned uint256s?** Efficient single-word memory loads at offsets 64, 96, 128, 160
- **Why fee as uint32?** Simpler byte alignment than 3-byte uint24

#### 3. inspect() Returns Only Recipient
```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    address recipient = data.toAddress(44);
    return abi.encodePacked(recipient);
}
```

- Returns 20 bytes (just recipient address)
- **Critical for Merkle tree compatibility**: Dynamic amounts would make leaf construction difficult
- Recipient is the security-critical parameter that must match user's signature

#### 4. Hook Chaining with Slippage Recalculation
```solidity
if (usePrevHookAmount) {
    amountIn = ISuperHookResult(prevHook).getOutAmount(account);
    amountOutMinimum = HookDataUpdater.getUpdatedOutputAmount(
        amountIn,
        originalAmountIn,
        originalMinAmountOut
    );
}
```

Formula: `newMinAmountOut = originalMinAmountOut * (newAmountIn / originalAmountIn)`

### Code Examples

#### Building Hook Data
```solidity
function _buildHookData(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    address recipient,
    uint256 deadline,
    uint160 sqrtPriceLimitX96,
    uint256 amountIn,
    uint256 amountOutMinimum,
    bool usePrevHookAmount
) internal pure returns (bytes memory) {
    return abi.encodePacked(
        tokenIn,                      // 20 bytes
        tokenOut,                     // 20 bytes
        uint32(fee),                  // 4 bytes
        recipient,                    // 20 bytes
        deadline,                     // 32 bytes
        uint256(sqrtPriceLimitX96),   // 32 bytes
        amountIn,                     // 32 bytes
        amountOutMinimum,             // 32 bytes
        usePrevHookAmount             // 1 byte
    );
}
```

#### Executing via SuperExecutor
```solidity
address[] memory hookAddresses = new address[](1);
hookAddresses[0] = address(approveAndSwapHook);

bytes[] memory hookDataArray = new bytes[](1);
hookDataArray[0] = hookData;

ISuperExecutor.ExecutorEntry memory entryToExecute =
    ISuperExecutor.ExecutorEntry({
        hooksAddresses: hookAddresses,
        hooksData: hookDataArray
    });

UserOpData memory opData = _getExecOps(
    instanceOnEth,
    superExecutorOnEth,
    abi.encode(entryToExecute)
);
executeOp(opData);
```

#### Hook Chaining Pattern
```solidity
// Mock previous hook that outputs specific amount
contract MockPrevHook is BaseHook {
    uint256 private _outAmount;

    function _preExecute(address, address, bytes calldata) internal override {
        _setOutAmount(_outAmount, msg.sender);
    }
}

// Chain hooks together
address[] memory hookAddresses = new address[](2);
hookAddresses[0] = address(mockPrevHook);
hookAddresses[1] = address(approveAndSwapHook);
```

## Testing Strategy

### Unit Tests (28 tests)
Located at: `test/unit/hooks/swappers/uniswap-v3/UniswapV3UnitTests.t.sol`

| Category | Tests |
|----------|-------|
| Constructor | 4 (valid + zero address revert) |
| Data decoding | 4 (usePrevHookAmount true/false) |
| Build function | 6 (standard + with prev hook amount) |
| Invalid data | 2 (below minimum length) |
| PreExecute/PostExecute | 4 (balance tracking) |
| Inspect | 2 (recipient extraction) |
| Slippage recalculation | 4 (with/without verification) |
| Fee tiers | 2 (100, 500, 3000, 10000) |

Key patterns:
- Use MockSwapRouter for isolated testing
- Verify execution array lengths (SwapHook=3, ApproveAndSwapHook=6)
- Decode swap calldata to verify recalculated values

### Integration Tests (7 tests)
Located at: `test/integration/uniswap-v3/UniswapV3HookIntegrationTest.t.sol`

| Test | Description |
|------|-------------|
| HookDataDecoding | Verify data parsing on mainnet fork |
| InspectFunction | Verify recipient extraction |
| ApproveAndSwap_USDC_to_WETH | Real swap 1000 USDC → WETH |
| ApproveAndSwap_WETH_to_USDC | Real swap 1 WETH → USDC |
| DifferentFeeTiers | Test 0.05% fee tier |
| UsePrevHookAmount | Hook chaining with mock prev hook |
| OutAmountTracking | Verify balance delta tracking |

**CRITICAL**: Integration test contracts MUST include:
```solidity
receive() external payable { }
```

## Prevention & Best Practices

### Do
- Use `BytesLib` for gas-efficient packed data decoding
- Validate minimum data length: `if (data.length < 193) revert INVALID_HOOK_DATA();`
- Clear approvals after swap: `approve(router, 0)` at the end
- Use structs to avoid stack-too-deep in tests
- Test both with and without `usePrevHookAmount`

### Don't
- Don't include amounts in `inspect()` - only addresses for Merkle compatibility
- Don't skip the approve(0) reset for USDT-like token compatibility
- Don't use ABI-encoded structs for hook data (gas inefficient)
- Don't forget `receive()` in integration tests

### Security Checklist
- [x] Zero address validation in constructor
- [x] Minimum data length validation
- [x] Approval cleared after swap
- [x] USDT-like token compatibility (approve 0 first)
- [x] Recipient extracted via inspect() for validation

## Related Documentation

- **Similar Hooks**: `src/hooks/swappers/odos/SwapOdosV2Hook.sol`, `src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol`
- **UniswapV4 Pattern**: `src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol`
- **Hook Master Guide**: `.claude/agents/hooks-master.md`
- **Base Hook**: `src/hooks/BaseHook.sol`
- **Data Updater**: `src/libraries/HookDataUpdater.sol`

## Deployment

### Files Modified
- `script/utils/Constants.sol` - Added hook keys
- `script/run/regenerate_bytecode.sh` - Added to HOOK_CONTRACTS array
- `test/utils/Constants.sol` - Added `MAINNET_V3_SWAP_ROUTER` and hook key constants

### Mainnet Router Address
```solidity
address public constant MAINNET_V3_SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
```

### Bytecode Generation
```bash
./script/run/regenerate_bytecode.sh SwapUniswapV3Hook
./script/run/regenerate_bytecode.sh ApproveAndSwapUniswapV3Hook
```
