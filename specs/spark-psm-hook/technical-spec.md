# Spark PSM Hook Technical Specification

## Overview

Four Solidity hooks enabling USDC/USDS/sUSDS swaps through Sky.money's Spark PSM (Peg Stability Module) within Superform v2's hook chain system. The PSM provides zero-fee, zero-slippage deterministic swaps — the primary venue for stablecoin swaps on Base.

## Problem Statement / Motivation

Standard DEX pools lack sufficient USDS/USDC liquidity. The PSM is the canonical swap venue for these pairs. Superform needs PSM hooks to route swaps before/after vault operations (e.g., USDC → USDS → Morpho vault deposit, or Morpho vault redeem → USDS → USDC).

## Proposed Solution

Create 4 hooks following the existing swap hook pattern (UniswapV3, Odos):

| Hook | Type | Executions |
|------|------|-----------|
| `SwapSparkPSMExactInHook` | Pre-approved swap | 3 (pre + swap + post) |
| `ApproveAndSwapSparkPSMExactInHook` | Approve + swap | 6 (pre + approve(0) + approve(amt) + swap + approve(0) + post) |
| `SwapSparkPSMExactOutHook` | Pre-approved swap | 3 (pre + swap + post) |
| `ApproveAndSwapSparkPSMExactOutHook` | Approve + swap | 6 (pre + approve(0) + approve(maxIn) + swap + approve(0) + post) |

All hooks: `BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)`

## Technical Considerations

### PSM Interface
```solidity
interface IPSM3 {
    function swapExactIn(
        address assetIn, address assetOut, uint256 amountIn,
        uint256 minAmountOut, address receiver, uint256 referralCode
    ) external returns (uint256 amountOut);

    function swapExactOut(
        address assetIn, address assetOut, uint256 amountOut,
        uint256 maxAmountIn, address receiver, uint256 referralCode
    ) external returns (uint256 amountIn);
}
```

### Token Properties
- **USDC/USDS**: Fixed 1:1 rate, decimal adjustment (6 vs 18)
- **sUSDS**: Oracle-based rate from `rateProvider` (1e27 precision), monotonically increasing
- **Rounding**: ExactIn rounds output DOWN, ExactOut rounds input UP (typically 1 wei)

### Hook Data Layout (157 bytes, shared by all 4 hooks)

```
Offset  Size  Type      Field
0       20    address   assetIn
20      20    address   assetOut
40      32    uint256   amount          (amountIn for ExactIn, amountOut for ExactOut)
72      32    uint256   slippageParam   (minAmountOut for ExactIn, maxAmountIn for ExactOut)
104     20    address   receiver        (IGNORED — forced to account)
124     32    uint256   referralCode
156     1     bool      usePrevHookAmount
```

**Minimum data length**: 157 bytes. Guard: `if (data.length < 157) revert INVALID_HOOK_DATA()`

### usePrevHookAmount Chaining

**ExactIn**: replaces `amountIn` with `prevHook.getOutAmount(account)`, scales `minAmountOut` proportionally via `HookDataUpdater.getUpdatedOutputAmount`.

**ExactOut**: replaces `amountOut` with `prevHook.getOutAmount(account)`, scales `maxAmountIn` proportionally.

### Critical Implementation Requirements

1. **Receiver = account**: Always hardcode `receiver = account` in the PSM call. Never use the receiver from hook data. Balance tracking depends on output tokens landing in the account.

2. **ExactOut approval = maxAmountIn**: The `ApproveAndSwapSparkPSMExactOutHook` must approve `maxAmountIn` (not `amountOut`) to the PSM. The PSM pulls variable `amountIn <= maxAmountIn`.

3. **ExactOut chained approval uses scaled value**: When `usePrevHookAmount=true`, the approval must use the scaled `maxAmountIn` (same value passed to the swap).

## Attack Surface Analysis

### Token Risks
- [x] Fee-on-transfer: N/A — USDC, USDS, sUSDS are standard ERC-20
- [x] Rebasing: sUSDS is ERC-4626 shares, `balanceOf` is stable (not rebasing)
- [x] Missing return values: Use direct `IERC20.approve` with zero-first pattern
- [x] Decimals: USDC (6) vs USDS/sUSDS (18) — HookDataUpdater handles via ratio scaling

### Reentrancy
- [x] CEI pattern: Execution is atomic batch via ERC-7579 account
- [x] Reentrancy guard: `nonReentrant` on `_processHook` in SuperExecutorBase
- [x] Transient storage: keccak256-keyed slots prevent SIR.trading-style collision

### Oracle & Price
- [x] sUSDS rate not flash-loan manipulable (governance-controlled rateProvider)
- [x] Rate drift between signing and execution protected by slippage params
- [x] Preview functions round differently than actual swaps — bundler must add buffer

### Access Control
- [x] PSM is permissionless (any address can swap)
- [x] Hook execution gated by SuperValidator Merkle proof validation

### Exploit Precedents
- [x] SIR.trading (Mar 2025, $355k) — transient storage collision. Mitigated by keccak256 keys.
- [x] Li.Fi/SocketDotTech (2024, $13M) — infinite approvals. Mitigated by approve-and-revoke.
- [x] PSM drainage DoS — temporary liveness issue, not security exploit.

## Acceptance Criteria

### Functional
- [ ] All 4 hooks compile and pass unit tests
- [ ] Correct PSM integration: swapExactIn and swapExactOut
- [ ] Hook chaining with usePrevHookAmount works for both ExactIn and ExactOut
- [ ] Balance tracking (pre/post delta) correctly reports outAmount
- [ ] Approve-and-revoke pattern: approve(0) → approve(exact) → swap → approve(0)
- [ ] Receiver forced to account in all hooks
- [ ] INVALID_HOOK_DATA revert on data < 157 bytes
- [ ] Constructor validates PSM address != address(0)
- [ ] inspect() returns assetOut for all hooks
- [ ] referralCode passed through from hook data

### Testing
- [ ] Unit tests for all 4 hooks (constructor, build, preExecute, postExecute, inspect, decodeUsePrevHookAmount)
- [ ] Fuzz tests for slippage recalculation
- [ ] MockPSM3 contract for deterministic testing
- [ ] ExactOut-specific: verify approve(maxAmountIn), not approve(amountOut)

### Deployment
- [ ] IPSM3 vendor interface created
- [ ] PSM address constants added per chain
- [ ] Deployment script integration with conditional chain availability
- [ ] 4 hook key constants in Constants.sol

## Implementation

### File Structure
```
src/vendor/spark/IPSM3.sol
src/hooks/swappers/spark-psm/SwapSparkPSMExactInHook.sol
src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactInHook.sol
src/hooks/swappers/spark-psm/SwapSparkPSMExactOutHook.sol
src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactOutHook.sol
test/unit/hooks/swappers/spark-psm/SparkPSMExactInUnitTests.t.sol
test/unit/hooks/swappers/spark-psm/SparkPSMExactOutUnitTests.t.sol
test/mocks/MockPSM3.sol
```

### SwapSparkPSMExactInHook.sol (skeleton)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { IPSM3 } from "../../../vendor/spark/IPSM3.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/interfaces/IERC7579Module.sol";

/// @title SwapSparkPSMExactInHook
/// @notice Swaps tokens via Spark PSM using swapExactIn (assumes pre-approved)
/// @dev Data layout (157 bytes):
///   [0:20]   address assetIn
///   [20:40]  address assetOut
///   [40:72]  uint256 amountIn
///   [72:104] uint256 minAmountOut
///   [104:124] address receiver (IGNORED - forced to account)
///   [124:156] uint256 referralCode
///   [156:157] bool usePrevHookAmount
contract SwapSparkPSMExactInHook is BaseHook {
    IPSM3 public immutable PSM;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 156;

    constructor(address psmAddress_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (psmAddress_ == address(0)) revert ADDRESS_NOT_VALID();
        PSM = IPSM3(psmAddress_);
    }

    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    ) internal view override returns (Execution[] memory executions) {
        if (data.length < 157) revert INVALID_HOOK_DATA();

        address assetIn = data.toAddress(0);
        address assetOut = data.toAddress(20);
        uint256 amountIn = data.toUint256(40);
        uint256 minAmountOut = data.toUint256(72);
        uint256 referralCode = data.toUint256(124);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            uint256 prevAmount = ISuperHookResult(prevHook).getOutAmount(account);
            minAmountOut = HookDataUpdater.getUpdatedOutputAmount(prevAmount, amountIn, minAmountOut);
            amountIn = prevAmount;
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(PSM),
            value: 0,
            callData: abi.encodeCall(IPSM3.swapExactIn, (assetIn, assetOut, amountIn, minAmountOut, account, referralCode))
        });
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        address assetOut = data.toAddress(20);
        _setOutAmount(IERC20(assetOut).balanceOf(account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        address assetOut = data.toAddress(20);
        uint256 finalBalance = IERC20(assetOut).balanceOf(account);
        uint256 initialBalance = getOutAmount(account);
        _setOutAmount(finalBalance - initialBalance, account);
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.toAddress(20)); // assetOut
    }

    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }
}
```

### ApproveAndSwapSparkPSMExactInHook.sol (skeleton)

Same as above but `_buildHookExecutions` returns 4 executions:
```solidity
executions = new Execution[](4);
executions[0] = Execution(assetIn, 0, abi.encodeCall(IERC20.approve, (address(PSM), 0)));
executions[1] = Execution(assetIn, 0, abi.encodeCall(IERC20.approve, (address(PSM), amountIn)));
executions[2] = Execution(address(PSM), 0, abi.encodeCall(IPSM3.swapExactIn, (...)));
executions[3] = Execution(assetIn, 0, abi.encodeCall(IERC20.approve, (address(PSM), 0)));
```

### SwapSparkPSMExactOutHook.sol (skeleton)

Same pattern but:
- `amount` at offset 40 is `amountOut` (desired output)
- `slippageParam` at offset 72 is `maxAmountIn`
- When `usePrevHookAmount=true`: `amountOut = prevHook.getOutAmount(account)`, `maxAmountIn` scaled

### ApproveAndSwapSparkPSMExactOutHook.sol (skeleton)

Same as ExactOut but with 4 executions. **Critical**: `executions[1]` approves `maxAmountIn` (NOT `amountOut`).

### IPSM3.sol

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

interface IPSM3 {
    function swapExactIn(
        address assetIn, address assetOut, uint256 amountIn,
        uint256 minAmountOut, address receiver, uint256 referralCode
    ) external returns (uint256 amountOut);

    function swapExactOut(
        address assetIn, address assetOut, uint256 amountOut,
        uint256 maxAmountIn, address receiver, uint256 referralCode
    ) external returns (uint256 amountIn);

    function previewSwapExactIn(
        address assetIn, address assetOut, uint256 amountIn
    ) external view returns (uint256 amountOut);

    function previewSwapExactOut(
        address assetIn, address assetOut, uint256 amountOut
    ) external view returns (uint256 amountIn);
}
```

## Implementation Plan

### Phase 1: Foundation
- [ ] Create `src/vendor/spark/IPSM3.sol`
- [ ] Create `test/mocks/MockPSM3.sol`

### Phase 2: ExactIn Hooks
- [ ] Implement `SwapSparkPSMExactInHook`
- [ ] Implement `ApproveAndSwapSparkPSMExactInHook`
- [ ] Write `SparkPSMExactInUnitTests.t.sol`

### Phase 3: ExactOut Hooks
- [ ] Implement `SwapSparkPSMExactOutHook`
- [ ] Implement `ApproveAndSwapSparkPSMExactOutHook`
- [ ] Write `SparkPSMExactOutUnitTests.t.sol`

### Phase 4: Deployment
- [ ] Add PSM address constants per chain
- [ ] Add hook key constants to Constants.sol
- [ ] Add deployment logic with conditional chain availability

## References & Research

### Internal
- `src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol` — Primary pattern reference
- `src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol` — Approve pattern reference
- `src/libraries/HookDataUpdater.sol` — Chaining logic
- `src/hooks/BaseHook.sol` — Base hook lifecycle
- `test/unit/hooks/swappers/uniswap-v3/UniswapV3UnitTests.t.sol` — Test pattern

### External
- [Spark PSM Docs](https://docs.spark.fi/dev/savings/spark-psm)
- [ChainSecurity PSM Audit (Oct 2024)](https://www.chainsecurity.com/security-audit/spark-psm)
- PSM Contract (Base): `0x1601843c5e9bc251a3272907010afa41fa18347e`
