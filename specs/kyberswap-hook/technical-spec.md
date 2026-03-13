# KyberSwap Hook Technical Specification

## Overview

Create two swap hooks for KyberSwap's MetaAggregationRouterV2 aggregator, following the established Superform hook patterns. The hooks enable token swaps through KyberSwap within the Superform hook execution chain.

## Problem Statement / Motivation

Superform needs broader DEX aggregator coverage. KyberSwap's aggregator routes through 100+ DEX sources across 17+ chains. Adding KyberSwap hooks diversifies swap routing options alongside existing Odos, 1inch, and Uniswap integrations.

## Proposed Solution

Two hook variants following the **1inch hook pattern** (raw calldata with validation):

1. **`SwapKyberSwapHook`** - Swap only (assumes prior approval or native ETH)
2. **`ApproveAndSwapKyberSwapHook`** - Approval + swap in one hook

### Why 1inch Pattern (Not Odos Pattern)

KyberSwap's `SwapDescriptionV2` contains dynamic arrays (`srcReceivers[]`, `srcAmounts[]`, `feeReceivers[]`, `feeAmounts[]`). Manually constructing this struct from packed bytes would be complex and gas-expensive. The 1inch approach of passing raw API-generated calldata is cleaner.

### CRITICAL: usePrevHookAmount Amount Updating (Improvement over 0x)

Unlike the 0x integration where we couldn't update amounts in the encoded calldata, KyberSwap's `swap(SwapExecutionParams)` uses standard ABI encoding. This means we CAN decode the `SwapExecutionParams`, update `desc.amount` and `desc.minReturnAmount` when `usePrevHookAmount` is true, and re-encode.

**This is a key advantage over 0x** and must be validated in implementation:

```solidity
function _updateTxDataAmounts(
    bytes memory txData_,
    uint256 newAmount,
    uint256 originalAmount
) private pure returns (bytes memory) {
    // Skip 4-byte function selector
    bytes4 selector = bytes4(txData_[:4]);

    // Decode SwapExecutionParams from txData_ (after selector)
    IMetaAggregationRouterV2.SwapExecutionParams memory params =
        abi.decode(txData_[4:], (IMetaAggregationRouterV2.SwapExecutionParams));

    // Update amounts
    uint256 originalMin = params.desc.minReturnAmount;
    params.desc.amount = newAmount;
    params.desc.minReturnAmount = HookDataUpdater.getUpdatedOutputAmount(
        newAmount, originalAmount, originalMin
    );

    // Re-encode with updated amounts
    return abi.encodePacked(selector, abi.encode(params));
}
```

**Test requirement**: Must verify that:
1. The re-encoded calldata is accepted by the KyberSwap router (no hash/signature validation on calldata)
2. `desc.minReturnAmount` is correctly scaled proportionally
3. Fork test with actual prevHook output feeding into KyberSwap swap

## Technical Considerations

### Router Interface

KyberSwap MetaAggregationRouterV2 at `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` (same address all chains).

```solidity
interface IMetaAggregationRouterV2 {
    struct SwapDescriptionV2 {
        IERC20 srcToken;
        IERC20 dstToken;
        address[] srcReceivers;
        uint256[] srcAmounts;
        address[] feeReceivers;
        uint256[] feeAmounts;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
        bytes permit;
    }

    struct SwapExecutionParams {
        address callTarget;
        address approveTarget;
        SwapDescriptionV2 desc;
        bytes targetData;
        bytes clientData;
    }

    function swap(SwapExecutionParams calldata execution) external payable returns (uint256 returnAmount, uint256 gasUsed);
}
```

**NOTE**: The ABI signature is `swap((address,address,bytes,(address,address,address[],uint256[],address[],uint256[],address,uint256,uint256,uint256,bytes),bytes))`. The field ordering may have `clientData` before `desc`. MUST verify exact layout from [Etherscan verified source](https://etherscan.io/address/0x6131b5fae19ea4f9d964eac0408e4408b66337b5#code) using `cast interface` before implementation.

### Native ETH

KyberSwap uses `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE` as the ETH sentinel (different from Odos which uses `address(0)`). The hook should handle both conventions for consistency with the rest of the codebase.

### Fee/Referral System

No simple `referralCode` like Odos. Fees are embedded in the `SwapDescriptionV2` struct via `srcReceivers[]`, `srcAmounts[]`, `feeReceivers[]`, `feeAmounts[]`, configured at API level. The `clientData` field is used for partner tracking (emitted in events). No on-chain referral code needed in the hook.

## Acceptance Criteria

- [ ] `SwapKyberSwapHook` implements BaseHook with NONACCOUNTING type and SWAP subtype
- [ ] `ApproveAndSwapKyberSwapHook` implements approve(0)->approve(amount)->swap->approve(0) pattern
- [ ] Both hooks support `usePrevHookAmount` via `ISuperHookContextAware`
- [ ] Both hooks track output via pre/post balance delta pattern
- [ ] `inspect()` returns `callTarget` and `approveTarget` from decoded calldata
- [ ] Native ETH swaps supported (value forwarding)
- [ ] Constructor validates non-zero router address
- [ ] Vendor interface `IMetaAggregationRouterV2.sol` created with verified struct layouts
- [ ] Mock router created for unit tests
- [ ] Unit tests cover: constructor, build, usePrevHookAmount, pre/post execute, inspect, approval sequence
- [ ] Fork-based integration tests against live KyberSwap router

## Implementation

### Files to Create

| File | Purpose |
|------|---------|
| `src/vendor/kyberswap/IMetaAggregationRouterV2.sol` | Vendor interface |
| `src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol` | Swap-only hook |
| `src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol` | Approve + swap hook |
| `test/mocks/MockKyberSwapRouter.sol` | Mock router for unit tests |
| `test/unit/hooks/swappers/kyberswap/KyberSwapUnitTests.t.sol` | Unit tests |
| `test/integration/kyberswap/KyberSwapIntegration.t.sol` | Fork integration tests |

### Hook Data Layout

#### SwapKyberSwapHook

```
address outputToken      = BytesLib.toAddress(data, 0);      // 0-19   (20 bytes)
uint256 value             = BytesLib.toUint256(data, 20);     // 20-51  (32 bytes) - ETH value for native swaps
uint256 inputAmount       = BytesLib.toUint256(data, 52);     // 52-83  (32 bytes) - for usePrevHookAmount scaling
uint256 outputMin         = BytesLib.toUint256(data, 84);     // 84-115 (32 bytes) - for usePrevHookAmount scaling
bool usePrevHookAmount    = _decodeBool(data, 116);           // 116    (1 byte)
uint256 txDataLength      = BytesLib.toUint256(data, 117);    // 117-148 (32 bytes)
bytes txData_             = BytesLib.slice(data, 149, txDataLength); // 149+  (variable)
```

Total minimum: 149 bytes + txData.

#### ApproveAndSwapKyberSwapHook

```
address inputToken        = BytesLib.toAddress(data, 0);      // 0-19   (20 bytes)
address outputToken       = BytesLib.toAddress(data, 20);     // 20-39  (20 bytes)
uint256 inputAmount       = BytesLib.toUint256(data, 40);     // 40-71  (32 bytes)
uint256 outputMin         = BytesLib.toUint256(data, 72);     // 72-103 (32 bytes)
bool usePrevHookAmount    = _decodeBool(data, 104);           // 104    (1 byte)
uint256 txDataLength      = BytesLib.toUint256(data, 105);    // 105-136 (32 bytes)
bytes txData_             = BytesLib.slice(data, 137, txDataLength); // 137+  (variable)
```

Total minimum: 137 bytes + txData.

### SwapKyberSwapHook Implementation Skeleton

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IMetaAggregationRouterV2 } from "../../../vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title SwapKyberSwapHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address outputToken = BytesLib.toAddress(data, 0);
/// @notice         uint256 value = BytesLib.toUint256(data, 20);
/// @notice         uint256 inputAmount = BytesLib.toUint256(data, 52);
/// @notice         uint256 outputMin = BytesLib.toUint256(data, 84);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 116);
/// @notice         uint256 txDataLength = BytesLib.toUint256(data, 117);
/// @notice         bytes txData_ = BytesLib.slice(data, 149, txDataLength);
contract SwapKyberSwapHook is BaseHook, ISuperHookContextAware {
    IMetaAggregationRouterV2 public immutable KYBER_ROUTER;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 116;

    constructor(address _router) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (_router == address(0)) revert ADDRESS_NOT_VALID();
        KYBER_ROUTER = IMetaAggregationRouterV2(_router);
    }

    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        uint256 value = BytesLib.toUint256(data, 20);
        uint256 inputAmount = BytesLib.toUint256(data, 52);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        uint256 txDataLength = BytesLib.toUint256(data, 117);
        bytes memory txData_ = BytesLib.slice(data, 149, txDataLength);

        if (usePrevHookAmount) {
            uint256 prevAmount = ISuperHookResult(prevHook).getOutAmount(account);
            // Update value for native ETH swaps
            if (value > 0) {
                value = prevAmount;
            }
            // Update txData_ amounts (decode SwapExecutionParams, update desc.amount and desc.minReturnAmount)
            txData_ = _updateTxDataAmounts(txData_, prevAmount, inputAmount);
        }

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(KYBER_ROUTER),
            value: value,
            callData: txData_
        });
    }

    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        uint256 txDataLength = BytesLib.toUint256(data, 117);
        bytes memory txData_ = BytesLib.slice(data, 149, txDataLength);
        // Decode SwapExecutionParams to extract callTarget and approveTarget
        // Return packed addresses for whitelisting
        // Implementation depends on verified struct layout
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, 0);
        if (outputToken == address(0)) {
            return account.balance;
        }
        return IERC20(outputToken).balanceOf(account);
    }

    function _updateTxDataAmounts(
        bytes memory txData_,
        uint256 newAmount,
        uint256 originalAmount
    ) private pure returns (bytes memory) {
        // Decode the SwapExecutionParams from txData_
        // Update desc.amount = newAmount
        // Update desc.minReturnAmount proportionally via HookDataUpdater
        // Re-encode and return
        // Implementation depends on verified struct layout
    }
}
```

### ApproveAndSwapKyberSwapHook Implementation Skeleton

Same as SwapKyberSwapHook but `_buildHookExecutions` returns 4 executions:

```solidity
function _buildHookExecutions(...) internal view override returns (Execution[] memory executions) {
    address inputToken = BytesLib.toAddress(data, 0);
    uint256 inputAmount = BytesLib.toUint256(data, 40);
    bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    uint256 txDataLength = BytesLib.toUint256(data, 105);
    bytes memory txData_ = BytesLib.slice(data, 137, txDataLength);

    if (usePrevHookAmount) {
        uint256 prevAmount = ISuperHookResult(prevHook).getOutAmount(account);
        txData_ = _updateTxDataAmounts(txData_, prevAmount, inputAmount);
        inputAmount = prevAmount;
    }

    address approveSpender = address(KYBER_ROUTER);
    // Optionally decode approveTarget from txData_ if it differs from router

    executions = new Execution[](4);
    executions[0] = Execution({
        target: inputToken,
        value: 0,
        callData: abi.encodeCall(IERC20.approve, (approveSpender, 0))
    });
    executions[1] = Execution({
        target: inputToken,
        value: 0,
        callData: abi.encodeCall(IERC20.approve, (approveSpender, inputAmount))
    });
    executions[2] = Execution({
        target: address(KYBER_ROUTER),
        value: 0,
        callData: txData_
    });
    executions[3] = Execution({
        target: inputToken,
        value: 0,
        callData: abi.encodeCall(IERC20.approve, (approveSpender, 0))
    });
}
```

### Mock Router

```solidity
contract MockKyberSwapRouter {
    uint256 public returnAmount;

    function setReturnAmount(uint256 amount_) external {
        returnAmount = amount_;
    }

    function swap(IMetaAggregationRouterV2.SwapExecutionParams calldata execution)
        external
        payable
        returns (uint256, uint256)
    {
        // Pull input tokens
        if (address(execution.desc.srcToken) != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            IERC20(address(execution.desc.srcToken)).transferFrom(
                msg.sender, address(this), execution.desc.amount
            );
        }
        // Send output tokens
        address receiver = execution.desc.dstReceiver == address(0) ? msg.sender : execution.desc.dstReceiver;
        IERC20(address(execution.desc.dstToken)).transfer(receiver, returnAmount);
        return (returnAmount, 0);
    }
}
```

## Dependencies & Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| KyberSwap router is upgradeable proxy | Medium | High | Document trust assumption; approve-swap-revoke pattern limits exposure window |
| Struct field ordering differs from docs | Medium | Medium | Verify via `cast interface` from Etherscan before implementation |
| KyberSwap API returns unexpected calldata | Low | Medium | Balance delta tracking catches bad swaps |
| Fee-on-transfer token accounting | Low | Low | Pre/post balance pattern handles correctly |

## References & Research

### Internal References
- `src/hooks/swappers/1inch/Swap1InchHook.sol` - Primary pattern reference (raw calldata approach)
- `src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol` - Approval pattern reference
- `src/hooks/swappers/spark-psm/SwapSparkPSMExactInHook.sol` - Cleanest/newest hook implementation
- `src/hooks/BaseHook.sol` - Base class
- `src/libraries/HookDataUpdater.sol` - Output amount scaling for usePrevHookAmount
- `src/libraries/HookSubTypes.sol` - SWAP subtype constant

### External References
- [KyberSwap Aggregator Docs](https://docs.kyberswap.com/kyberswap-solutions/kyberswap-aggregator)
- [KyberSwap Deployment Contracts](https://docs.kyberswap.com/kyberswap-solutions/kyberswap-aggregator/contracts)
- [Etherscan Verified Source](https://etherscan.io/address/0x6131b5fae19ea4f9d964eac0408e4408b66337b5#code)
- [KyberSwap Elastic Exploit Post-Mortem](https://blog.kyberswap.com/post-mortem-kyberswap-elastic-exploit/)
