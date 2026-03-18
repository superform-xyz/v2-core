# KyberSwap MetaAggregationRouterV2 Hook - Implementation Plan

## Overview

Two swap hooks for KyberSwap's MetaAggregationRouterV2 aggregator following the **1inch raw calldata pattern**. The critical differentiator from 0x/1inch is the `_updateTxDataAmounts()` function that decodes standard ABI-encoded `SwapExecutionParams`, updates `desc.amount` and `desc.minReturnAmount` when `usePrevHookAmount` is true, and re-encodes.

**Branch**: `feat/psm-integration-SV-1516` (current branch)

---

## Files to Create/Modify

### New Files (6 total)

| # | File | Purpose |
|---|------|---------|
| 1 | `src/vendor/kyberswap/IMetaAggregationRouterV2.sol` | Vendor interface with verified struct layouts |
| 2 | `src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol` | Swap-only hook (1 execution) |
| 3 | `src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol` | Approve + swap hook (4 executions) |
| 4 | `test/mocks/MockKyberSwapRouter.sol` | Mock router for unit tests |
| 5 | `test/unit/hooks/swappers/kyberswap/KyberSwapUnitTests.t.sol` | Unit tests for both hooks |
| 6 | `test/unit/hooks/swappers/kyberswap/KyberSwapUpdateTxData.t.sol` | Focused tests for `_updateTxDataAmounts` |

### Files to Modify (5 total for deployment)

| # | File | Change |
|---|------|--------|
| 7 | `script/utils/Constants.sol` | Add `SWAP_KYBERSWAP_HOOK_KEY` and `APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY` |
| 8 | `script/utils/ConfigBase.sol` | Add `mapping(uint64 chainId => address kyberSwapRouter) kyberSwapRouters` to `EnvironmentData` struct |
| 9 | `script/utils/ConfigCore.sol` | Add KyberSwap router addresses for all 14 chains |
| 10 | `script/DeployV2Core.s.sol` | Add deployment integration (availability check, hook deployment, address assignment) |
| 11 | `script/run/regenerate_bytecode.sh` | Add `"SwapKyberSwapHook"` and `"ApproveAndSwapKyberSwapHook"` to contracts array |

---

## Implementation Order

### Phase 1: Vendor Interface

**File**: `src/vendor/kyberswap/IMetaAggregationRouterV2.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

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

    function swap(SwapExecutionParams calldata execution)
        external
        payable
        returns (uint256 returnAmount, uint256 gasUsed);
}
```

**CRITICAL NOTE**: The struct field ordering MUST be verified from the Etherscan verified source before implementation. The spec mentions that `clientData` may come before `desc` in the actual ABI. Run:
```bash
cast interface 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5 --etherscan-api-key $ETHERSCAN_API_KEY
```

If the field ordering differs from what is shown above, all encoding/decoding logic must be adjusted. The `SwapExecutionParams` struct field order determines how `abi.decode` works.

---

### Phase 2: SwapKyberSwapHook

**File**: `src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol`

**Pattern**: Follows `Swap1InchHook` raw calldata approach but with:
- Full ABI decode/re-encode for `_updateTxDataAmounts` (unlike 1inch which validates per-selector)
- Single `swap` selector (simpler than 1inch which has 3 selectors)

**NatSpec Data Layout** (place immediately after `/// @dev data has the following structure`):
```
/// @notice         address outputToken = BytesLib.toAddress(data, 0);
/// @notice         uint256 value = BytesLib.toUint256(data, 20);
/// @notice         uint256 inputAmount = BytesLib.toUint256(data, 52);
/// @notice         uint256 outputMin = BytesLib.toUint256(data, 84);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 116);
/// @notice         uint256 txDataLength = BytesLib.toUint256(data, 117);
/// @notice         bytes txData_ = BytesLib.slice(data, 149, txDataLength);
```

**Contract Structure**:
```solidity
contract SwapKyberSwapHook is BaseHook, ISuperHookContextAware {
    IMetaAggregationRouterV2 public immutable KYBER_ROUTER;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 116;

    error ZERO_ADDRESS();

    constructor(address router_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (router_ == address(0)) revert ZERO_ADDRESS();
        KYBER_ROUTER = IMetaAggregationRouterV2(router_);
    }
}
```

**Key Methods**:

1. **`_buildHookExecutions`**: Returns 1 execution targeting `KYBER_ROUTER` with txData as calldata.
   - Decode: outputToken, value, inputAmount, usePrevHookAmount, txDataLength, txData_
   - If `usePrevHookAmount`: get prevAmount, update value (if > 0 for native swaps), call `_updateTxDataAmounts`
   - Return single `Execution(target: KYBER_ROUTER, value: value, callData: txData_)`

2. **`_updateTxDataAmounts`** (CRITICAL - detailed design below)

3. **`_preExecute`**: `_setOutAmount(_getBalance(account, data), account)`

4. **`_postExecute`**: `_setOutAmount(_getBalance(account, data) - getOutAmount(account), account)`

5. **`_getBalance`**: Check outputToken at offset 0; if `address(0)`, return `account.balance`; else return `IERC20(outputToken).balanceOf(account)`

6. **`decodeUsePrevHookAmount`**: Return `_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)`

7. **`inspect`**: Extract addresses from decoded txData (see inspect section below)

---

### Phase 3: ApproveAndSwapKyberSwapHook

**File**: `src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol`

**NatSpec Data Layout**:
```
/// @notice         address inputToken = BytesLib.toAddress(data, 0);
/// @notice         address outputToken = BytesLib.toAddress(data, 20);
/// @notice         uint256 inputAmount = BytesLib.toUint256(data, 40);
/// @notice         uint256 outputMin = BytesLib.toUint256(data, 72);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 104);
/// @notice         uint256 txDataLength = BytesLib.toUint256(data, 105);
/// @notice         bytes txData_ = BytesLib.slice(data, 137, txDataLength);
```

**Key Differences from SwapKyberSwapHook**:
- Has `inputToken` in data (needed for approval executions)
- Has `outputToken` at offset 20 instead of offset 0
- `usePrevHookAmount` at position 104 (not 116)
- Returns 4 executions instead of 1:
  1. `approve(approveTarget, 0)` - Reset allowance
  2. `approve(approveTarget, inputAmount)` - Set allowance
  3. `swap(txData_)` on router - Execute swap
  4. `approve(approveTarget, 0)` - Revoke allowance

**CRITICAL: Approval Target Handling**:
KyberSwap has separate `callTarget` and `approveTarget` fields in `SwapExecutionParams`. The approval MUST be granted to the `approveTarget` (not the router itself). This must be extracted from the txData:

```solidity
// Decode SwapExecutionParams from txData_ to extract approveTarget
IMetaAggregationRouterV2.SwapExecutionParams memory params =
    abi.decode(txData_[4:], (IMetaAggregationRouterV2.SwapExecutionParams));
address approveTarget = params.approveTarget;

// If approveTarget is zero, fall back to KYBER_ROUTER address
if (approveTarget == address(0)) {
    approveTarget = address(KYBER_ROUTER);
}
```

The approve executions use `approveTarget`, while the swap execution targets `KYBER_ROUTER`.

**`_getBalance` difference**: `outputToken` is at offset 20 (not 0):
```solidity
function _getBalance(address account, bytes memory data) private view returns (uint256) {
    address outputToken = BytesLib.toAddress(data, 20);
    if (outputToken == address(0)) {
        return account.balance;
    }
    return IERC20(outputToken).balanceOf(account);
}
```

---

## `_updateTxDataAmounts` - Detailed Design

This is the most critical function and the key differentiator from the 0x integration. It leverages the fact that KyberSwap uses standard ABI encoding for `SwapExecutionParams`.

### Approach: Full ABI Decode/Re-Encode

```solidity
function _updateTxDataAmounts(
    bytes memory txData_,
    uint256 newAmount,
    uint256 originalAmount
) private pure returns (bytes memory) {
    // Step 1: Extract the function selector (first 4 bytes)
    bytes4 selector = bytes4(txData_[0]) | (bytes4(txData_[1]) >> 8)
        | (bytes4(txData_[2]) >> 16) | (bytes4(txData_[3]) >> 24);

    // Step 2: Decode SwapExecutionParams from remaining bytes
    IMetaAggregationRouterV2.SwapExecutionParams memory params =
        abi.decode(_sliceBytes(txData_, 4, txData_.length - 4),
        (IMetaAggregationRouterV2.SwapExecutionParams));

    // Step 3: Update the amounts
    params.desc.amount = newAmount;
    params.desc.minReturnAmount = HookDataUpdater.getUpdatedOutputAmount(
        newAmount,
        originalAmount,
        params.desc.minReturnAmount
    );

    // Step 4: Re-encode with selector
    return abi.encodePacked(selector, abi.encode(params));
}
```

### Alternative: Simpler selector extraction

Since we know the only selector is `IMetaAggregationRouterV2.swap.selector`, we can simplify:

```solidity
function _updateTxDataAmounts(
    bytes memory txData_,
    uint256 newAmount,
    uint256 originalAmount
) private pure returns (bytes memory) {
    // Decode the SwapExecutionParams (skip 4-byte selector)
    // Use BytesLib.slice to get bytes after selector
    bytes memory paramsData = BytesLib.slice(txData_, 4, txData_.length - 4);

    IMetaAggregationRouterV2.SwapExecutionParams memory params =
        abi.decode(paramsData, (IMetaAggregationRouterV2.SwapExecutionParams));

    // Update amounts
    params.desc.amount = newAmount;
    params.desc.minReturnAmount = HookDataUpdater.getUpdatedOutputAmount(
        newAmount,
        originalAmount,
        params.desc.minReturnAmount
    );

    // Re-encode: selector + abi.encode(params)
    return abi.encodePacked(
        IMetaAggregationRouterV2.swap.selector,
        abi.encode(params)
    );
}
```

### Important Notes on `_updateTxDataAmounts`:

1. **Gas Cost**: This is the most gas-intensive part because it decodes/re-encodes a complex struct with dynamic arrays. However, it is still `pure` and only runs in `_buildHookExecutions` (which is `view`), so it does not affect on-chain gas during actual execution via the account.

2. **`BytesLib.slice` Usage**: Must use `BytesLib.slice(txData_, 4, txData_.length - 4)` to create a memory copy suitable for `abi.decode`. Cannot use `calldata` slicing here since `txData_` is already `memory` type inside the function.

3. **Selector Preservation**: The re-encoded data MUST include the original 4-byte function selector. Using `abi.encodePacked(selector, abi.encode(params))` achieves this.

4. **`abi.decode` with Nested Dynamic Types**: This works because `SwapExecutionParams` contains `SwapDescriptionV2` which has dynamic arrays (`address[]`, `uint256[]`, `bytes`). Solidity's `abi.decode` handles nested dynamic types correctly as long as the ABI encoding is standard.

5. **The `_updateTxDataAmounts` function MUST be shared between both hooks**. Options:
   - Option A (RECOMMENDED): Duplicate the function in both hooks (follows codebase pattern - 1inch and Odos both have their own internal helpers)
   - Option B: Create a shared internal library (adds complexity, not done in codebase for swap hooks)

---

## `inspect()` Function Design

### Protocol Requirement

Inspector functions MUST only return addresses (never amounts, booleans, or other data).

### What to Return

For KyberSwap, the relevant addresses for whitelisting are:
- `callTarget` - The target contract that executes the swap
- `approveTarget` - The target contract that receives token approvals

Both are extracted from the decoded `SwapExecutionParams`.

### SwapKyberSwapHook `inspect()`:

```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    uint256 txDataLength = BytesLib.toUint256(data, 117);
    bytes memory txData_ = BytesLib.slice(data, 149, txDataLength);

    // Decode SwapExecutionParams to extract target addresses
    IMetaAggregationRouterV2.SwapExecutionParams memory params =
        abi.decode(BytesLib.slice(txData_, 4, txData_.length - 4),
        (IMetaAggregationRouterV2.SwapExecutionParams));

    // Return only addresses (PROTOCOL REQUIREMENT)
    return abi.encodePacked(
        params.callTarget,
        params.approveTarget,
        address(params.desc.srcToken),
        address(params.desc.dstToken)
    );
}
```

### ApproveAndSwapKyberSwapHook `inspect()`:

Same but with different txData offset (starts at 137):

```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    uint256 txDataLength = BytesLib.toUint256(data, 105);
    bytes memory txData_ = BytesLib.slice(data, 137, txDataLength);

    IMetaAggregationRouterV2.SwapExecutionParams memory params =
        abi.decode(BytesLib.slice(txData_, 4, txData_.length - 4),
        (IMetaAggregationRouterV2.SwapExecutionParams));

    return abi.encodePacked(
        params.callTarget,
        params.approveTarget,
        address(params.desc.srcToken),
        address(params.desc.dstToken)
    );
}
```

**Note**: The `inspect` function visibility MUST be `pure` (not `view`) since it only operates on calldata, following the 1inch pattern. The `IMetaAggregationRouterV2` import does not require state access for decoding.

---

## Phase 4: Mock Router

**File**: `test/mocks/MockKyberSwapRouter.sol`

Follows `MockOdosRouterV2` pattern -- mock that pulls input tokens and sends output tokens:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IMetaAggregationRouterV2 } from "../../src/vendor/kyberswap/IMetaAggregationRouterV2.sol";

contract MockKyberSwapRouter {
    uint256 public returnAmount;
    uint256 public lastGasUsed;

    function setReturnAmount(uint256 amount_) external {
        returnAmount = amount_;
    }

    function swap(IMetaAggregationRouterV2.SwapExecutionParams calldata execution)
        external
        payable
        returns (uint256, uint256)
    {
        address srcToken = address(execution.desc.srcToken);
        address dstToken = address(execution.desc.dstToken);
        address receiver = execution.desc.dstReceiver == address(0)
            ? msg.sender
            : execution.desc.dstReceiver;

        // Pull input tokens (skip for native ETH)
        if (srcToken != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE && srcToken != address(0)) {
            ERC20(srcToken).transferFrom(msg.sender, address(this), execution.desc.amount);
        }

        // Send output tokens
        uint256 amountOut = returnAmount > 0 ? returnAmount : execution.desc.minReturnAmount;
        if (dstToken != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE && dstToken != address(0)) {
            ERC20(dstToken).transfer(receiver, amountOut);
        } else {
            payable(receiver).transfer(amountOut);
        }

        return (amountOut, 0);
    }
}
```

---

## Phase 5: Unit Tests

**File**: `test/unit/hooks/swappers/kyberswap/KyberSwapUnitTests.t.sol`

### Test Structure

Follows the `OdosUnitTests.t.sol` pattern: single file testing both hooks.

**Imports**: `Helpers`, `MockERC20`, `MockHook`, `MockKyberSwapRouter`, both KyberSwap hooks, `ISuperHook`, `BytesLib`, `IMetaAggregationRouterV2`.

**Test Contract Setup**:
```solidity
contract KyberSwapUnitTests is Helpers {
    SwapKyberSwapHook public swapHook;
    ApproveAndSwapKyberSwapHook public approveAndSwapHook;
    MockKyberSwapRouter public mockRouter;
    MockHook public prevHook;

    address inputToken;
    address outputToken;
    address account;

    receive() external payable { }

    function setUp() public {
        account = address(this);
        mockRouter = new MockKyberSwapRouter();
        inputToken = address(new MockERC20("Input", "IN", 18));
        outputToken = address(new MockERC20("Output", "OUT", 18));
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);
        swapHook = new SwapKyberSwapHook(address(mockRouter));
        approveAndSwapHook = new ApproveAndSwapKyberSwapHook(address(mockRouter));
    }
}
```

### Test Scenarios

#### Constructor Tests
- `test_SwapHook_Constructor` - Verify NONACCOUNTING type, SWAP subtype, router address
- `test_ApproveAndSwapHook_Constructor` - Same checks
- `test_SwapHook_Constructor_RevertIf_AddressZero` - Verify revert with zero address
- `test_ApproveAndSwapHook_Constructor_RevertIf_AddressZero` - Same

#### Build Tests (SwapKyberSwapHook)
- `test_SwapHook_Build` - Basic build returns 3 executions (pre + 1 swap + post), target is router
- `test_SwapHook_Build_WithValue` - ETH value forwarding for native swaps
- `test_SwapHook_Build_WithPrevHookAmount` - Uses prevHook output, verify txData is updated
- `test_SwapHook_Build_WithPrevHookAmount_NativeValue` - Value updates when usePrevHookAmount + value > 0

#### Build Tests (ApproveAndSwapKyberSwapHook)
- `test_ApproveAndSwapHook_Build` - Returns 6 executions (pre + approve(0) + approve(amt) + swap + approve(0) + post)
- `test_ApproveAndSwapHook_Build_ApproveTargetsCorrect` - Approvals target the `approveTarget` from txData
- `test_ApproveAndSwapHook_Build_WithPrevHookAmount` - Uses prevHook output, amount in approve updates
- `test_ApproveAndSwapHook_Build_ApproveTargetFallback` - When approveTarget is address(0), falls back to router

#### Pre/Post Execute Tests
- `test_SwapHook_PreExecute` - Sets outAmount to output token balance
- `test_SwapHook_PostExecute` - Sets outAmount to balance delta
- `test_ApproveAndSwapHook_PreExecute` - Same
- `test_ApproveAndSwapHook_PostExecute` - Same
- `test_SwapHook_PreExecute_NativeToken` - Tests with outputToken = address(0) for ETH balance

#### DecodeUsePrevHookAmount Tests
- `test_SwapHook_DecodeUsePrevHookAmount_False`
- `test_SwapHook_DecodeUsePrevHookAmount_True`
- `test_ApproveAndSwapHook_DecodeUsePrevHookAmount_False`
- `test_ApproveAndSwapHook_DecodeUsePrevHookAmount_True`

#### Inspect Tests
- `test_SwapHook_Inspect` - Returns packed addresses (callTarget, approveTarget, srcToken, dstToken)
- `test_ApproveAndSwapHook_Inspect` - Same

**File**: `test/unit/hooks/swappers/kyberswap/KyberSwapUpdateTxData.t.sol`

Focused tests for `_updateTxDataAmounts`:

- `test_UpdateTxDataAmounts_AmountIncreased` - 10% increase: verify desc.amount updated, minReturnAmount scaled up proportionally
- `test_UpdateTxDataAmounts_AmountDecreased` - 10% decrease: verify desc.amount updated, minReturnAmount scaled down
- `test_UpdateTxDataAmounts_AmountUnchanged` - Same amount: verify no change to minReturnAmount
- `test_UpdateTxDataAmounts_PreservesDynamicArrays` - Verify srcReceivers, srcAmounts, feeReceivers, feeAmounts survive decode/re-encode
- `test_UpdateTxDataAmounts_PreservesTargetData` - Verify targetData bytes are preserved
- `test_UpdateTxDataAmounts_PreservesClientData` - Verify clientData bytes are preserved
- `test_UpdateTxDataAmounts_ReencodedCalldataIsValid` - Decode the re-encoded calldata and verify all fields match expected

### Helper Functions

```solidity
function _buildSwapKyberSwapData(
    bool usePrevious,
    uint256 ethValue,
    uint256 inputAmt,
    uint256 outputMinAmt
) internal view returns (bytes memory) {
    bytes memory txData_ = _buildKyberSwapTxData(inputAmt, outputMinAmt);

    return bytes.concat(
        bytes20(outputToken),           // outputToken (20 bytes)
        bytes32(ethValue),              // value (32 bytes)
        bytes32(inputAmt),              // inputAmount (32 bytes)
        bytes32(outputMinAmt),          // outputMin (32 bytes)
        usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),  // usePrevHookAmount (1 byte)
        bytes32(txData_.length),        // txDataLength (32 bytes)
        txData_                         // txData_ (variable)
    );
}

function _buildApproveAndSwapKyberSwapData(
    bool usePrevious,
    uint256 inputAmt,
    uint256 outputMinAmt
) internal view returns (bytes memory) {
    bytes memory txData_ = _buildKyberSwapTxData(inputAmt, outputMinAmt);

    return bytes.concat(
        bytes20(inputToken),            // inputToken (20 bytes)
        bytes20(outputToken),           // outputToken (20 bytes)
        bytes32(inputAmt),              // inputAmount (32 bytes)
        bytes32(outputMinAmt),          // outputMin (32 bytes)
        usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),  // usePrevHookAmount (1 byte)
        bytes32(txData_.length),        // txDataLength (32 bytes)
        txData_                         // txData_ (variable)
    );
}

function _buildKyberSwapTxData(
    uint256 amount,
    uint256 minReturnAmount
) internal view returns (bytes memory) {
    IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
        srcToken: IERC20(inputToken),
        dstToken: IERC20(outputToken),
        srcReceivers: new address[](0),
        srcAmounts: new uint256[](0),
        feeReceivers: new address[](0),
        feeAmounts: new uint256[](0),
        dstReceiver: account,
        amount: amount,
        minReturnAmount: minReturnAmount,
        flags: 0,
        permit: ""
    });

    IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
        callTarget: address(mockRouter),
        approveTarget: address(mockRouter),
        desc: desc,
        targetData: "",
        clientData: ""
    });

    return abi.encodePacked(
        IMetaAggregationRouterV2.swap.selector,
        abi.encode(params)
    );
}
```

### Test Contract Must Implement `getOutAmount` for prevHook Testing

The test contract acts as the mock prevHook in some tests. Use the existing `MockHook` for this:
```solidity
prevHook.setOutAmount(2000, address(this));
Execution[] memory execs = swapHook.build(address(prevHook), account, hookData);
```

---

## Phase 6: Deployment Integration

### 6.1 Constants.sol

Add after the PSM keys (around line 162):

```solidity
string internal constant SWAP_KYBERSWAP_HOOK_KEY = "SwapKyberSwapHook";
string internal constant APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY = "ApproveAndSwapKyberSwapHook";
```

### 6.2 ConfigBase.sol

Add to `EnvironmentData` struct (after `sparkPsm3s`):

```solidity
mapping(uint64 chainId => address kyberSwapRouter) kyberSwapRouters;
```

### 6.3 ConfigCore.sol

Add KyberSwap router configuration. The router address is `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` on ALL chains where KyberSwap is deployed.

According to KyberSwap docs, MetaAggregationRouterV2 is deployed on: Ethereum, BSC, Arbitrum, Polygon, Optimism, Avalanche, Base, Linea, Scroll, zkSync, and more.

```solidity
// ===== KYBERSWAP ROUTER ADDRESSES =====
address constant KYBERSWAP_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;

configuration.kyberSwapRouters[MAINNET_CHAIN_ID] = KYBERSWAP_ROUTER;
configuration.kyberSwapRouters[BASE_CHAIN_ID] = KYBERSWAP_ROUTER;
configuration.kyberSwapRouters[BNB_CHAIN_ID] = KYBERSWAP_ROUTER;
configuration.kyberSwapRouters[ARBITRUM_CHAIN_ID] = KYBERSWAP_ROUTER;
configuration.kyberSwapRouters[OPTIMISM_CHAIN_ID] = KYBERSWAP_ROUTER;
configuration.kyberSwapRouters[POLYGON_CHAIN_ID] = KYBERSWAP_ROUTER;
configuration.kyberSwapRouters[LINEA_CHAIN_ID] = KYBERSWAP_ROUTER;
configuration.kyberSwapRouters[AVALANCHE_CHAIN_ID] = KYBERSWAP_ROUTER;
configuration.kyberSwapRouters[SONIC_CHAIN_ID] = address(0);      // Verify deployment
configuration.kyberSwapRouters[GNOSIS_CHAIN_ID] = address(0);     // Verify deployment
configuration.kyberSwapRouters[UNICHAIN_CHAIN_ID] = address(0);   // Verify deployment
configuration.kyberSwapRouters[WORLDCHAIN_CHAIN_ID] = address(0); // Verify deployment
configuration.kyberSwapRouters[BERACHAIN_CHAIN_ID] = address(0);  // Verify deployment
configuration.kyberSwapRouters[HYPEREVM_CHAIN_ID] = address(0);   // Verify deployment
```

**IMPORTANT**: Must verify actual deployment on each chain using `cast code 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5 --rpc-url <RPC>` before marking as available. Some chains might have the same address but not actually deployed.

### 6.4 DeployV2Core.s.sol Changes

**A) HookAddresses struct** - Add two new fields:
```solidity
address swapKyberSwapHook;
address approveAndSwapKyberSwapHook;
```

**B) ContractAvailability struct** - Add flag:
```solidity
bool swapKyberSwapHooks;
```

**C) `_getContractAvailability()`** - Add check:
```solidity
if (configuration.kyberSwapRouters[chainId] != address(0)) {
    availability.swapKyberSwapHooks = true;
} else {
    expectedHooks -= 2; // SwapKyberSwapHook + ApproveAndSwapKyberSwapHook
    potentialSkips[skipCount++] = "SwapKyberSwapHook";
    potentialSkips[skipCount++] = "ApproveAndSwapKyberSwapHook";
}
```

Also update the `potentialSkips` array size (currently 28, increase to 30) and the `baseHooks` array to include the two new hooks.

**D) Hook array length** - Increment from 52 to 54.

**E) `_deployHooks()`** - Add deployment at new indices (52 and 53):
```solidity
// KyberSwap swap hooks
if (availability.swapKyberSwapHooks) {
    hooks[52] = _createSafeHookDeploymentWithArgs(
        SWAP_KYBERSWAP_HOOK_KEY,
        "SwapKyberSwapHook",
        env,
        abi.encode(configuration.kyberSwapRouters[chainId])
    );
    hooks[53] = _createSafeHookDeploymentWithArgs(
        APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY,
        "ApproveAndSwapKyberSwapHook",
        env,
        abi.encode(configuration.kyberSwapRouters[chainId])
    );
} else {
    console2.log("SKIPPED KyberSwap hooks: Router not available on chain", chainId);
    hooks[52] = HookDeployment("", "", "");
    hooks[53] = HookDeployment("", "", "");
}
```

**F) `_populateHookAddresses()`** - Add assignment:
```solidity
hookAddresses.swapKyberSwapHook =
    Strings.equal(hooks[52].name, SWAP_KYBERSWAP_HOOK_KEY) ? addresses[52] : address(0);
hookAddresses.approveAndSwapKyberSwapHook =
    Strings.equal(hooks[53].name, APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY) ? addresses[53] : address(0);
```

**G) Final validation** - Add conditional check:
```solidity
if (availability.swapKyberSwapHooks) {
    require(hookAddresses.swapKyberSwapHook != address(0), "SWAP_KYBERSWAP_HOOK_NOT_ASSIGNED");
    require(hookAddresses.approveAndSwapKyberSwapHook != address(0), "APPROVE_AND_SWAP_KYBERSWAP_HOOK_NOT_ASSIGNED");
}
```

**H) `_checkHookContracts()`** - Add check:
```solidity
if (availability.swapKyberSwapHooks) {
    require(configuration.kyberSwapRouters[chainId] != address(0), "KYBERSWAP_ROUTER_PARAM_ZERO");
    require(configuration.kyberSwapRouters[chainId].code.length > 0, "KYBERSWAP_ROUTER_NOT_DEPLOYED");
    _createSafeHookDeploymentWithArgs(
        SWAP_KYBERSWAP_HOOK_KEY, "SwapKyberSwapHook", env, abi.encode(configuration.kyberSwapRouters[chainId])
    );
    _createSafeHookDeploymentWithArgs(
        APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY,
        "ApproveAndSwapKyberSwapHook",
        env,
        abi.encode(configuration.kyberSwapRouters[chainId])
    );
} else {
    console2.log("SKIPPED KyberSwap hooks: Router not configured for chain", chainId);
}
```

### 6.5 regenerate_bytecode.sh

Add before the closing `)` of the contracts array (after `"ApproveAndSwapSparkPSMExactOutHook"`):

```bash
    "SwapKyberSwapHook"
    "ApproveAndSwapKyberSwapHook"
```

---

## Critical Implementation Notes

### 1. Struct Field Ordering Verification (BLOCKING)

Before implementing, MUST verify the exact `SwapExecutionParams` and `SwapDescriptionV2` struct field ordering from the Etherscan verified source. The spec flags that `clientData` might come before `desc`. If the ordering differs:
- The `abi.decode` in `_updateTxDataAmounts` will decode wrong data
- The `inspect()` function will extract wrong addresses
- The mock router expectations will be wrong

Run this verification step FIRST:
```bash
cast interface 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5 --etherscan-api-key $ETHERSCAN_API_KEY
```

### 2. `_updateTxDataAmounts` Gas Considerations

The full decode/re-encode is expensive in gas (~50-100k gas for complex structs with dynamic arrays) BUT:
- It only runs in `_buildHookExecutions` which is a `view` function
- `build()` is called off-chain by the bundler
- The actual on-chain execution uses the pre-computed `Execution[]` array
- So the gas cost is ONLY paid by the off-chain simulation, not on-chain

### 3. Native ETH Handling

KyberSwap uses `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE` as ETH sentinel (same as 1inch, different from Odos which uses `address(0)`). The hook's `_getBalance` function uses `address(0)` as the native ETH indicator (matching the codebase convention for outputToken), but the txData sent to KyberSwap will use the sentinel address.

### 4. Approval Target vs Router

KyberSwap's `SwapExecutionParams` separates `callTarget` (where swap logic executes) and `approveTarget` (where tokens should be approved). In most cases they are the same, but they CAN differ. The `ApproveAndSwapKyberSwapHook` MUST:
- Approve tokens to `approveTarget` (extracted from decoded txData)
- Send the swap call to `address(KYBER_ROUTER)` (the MetaAggregationRouterV2)

### 5. `usePrevHookAmount` + `_updateTxDataAmounts` Interaction

When `usePrevHookAmount` is true:
1. Get `prevAmount = ISuperHookResult(prevHook).getOutAmount(account)`
2. `originalAmount` = the inputAmount from hook data (used for ratio calculation)
3. Call `_updateTxDataAmounts(txData_, prevAmount, originalAmount)`
4. Inside `_updateTxDataAmounts`:
   - `desc.amount = prevAmount` (new input amount)
   - `desc.minReturnAmount = HookDataUpdater.getUpdatedOutputAmount(prevAmount, originalAmount, desc.minReturnAmount)` (proportionally scaled)

The `outputMin` field in the hook data layout is NOT used for `_updateTxDataAmounts`. The actual `minReturnAmount` comes from inside the decoded `SwapExecutionParams.desc`. The `outputMin` in the hook data layout is the user's original expected minimum and serves as documentation/backup for off-chain systems.

### 6. Error Naming Convention

Follow codebase conventions. 1inch uses: `ZERO_ADDRESS`, `INVALID_RECEIVER`, `INVALID_SELECTOR`. For KyberSwap, use:
```solidity
error ZERO_ADDRESS();
```
Keep it minimal since the hook does minimal validation (raw calldata pattern delegates validation to the router).

### 7. Import Patterns

Follow the exact import pattern from `Swap1InchHook`:
```solidity
// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IMetaAggregationRouterV2 } from "../../../vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
```

### 8. No Validation of txData Selector

Unlike 1inch which validates multiple selectors (`unoswapTo`, `swap`, `clipperSwapTo`), KyberSwap has only one relevant function (`swap`). The hook does NOT need to validate the selector because:
- The raw calldata comes from KyberSwap's API
- The router will revert if the selector is invalid
- Adding selector validation adds gas without meaningful security benefit

However, for `_updateTxDataAmounts`, the function ASSUMES the selector is `swap`. If needed, add a selector check:
```solidity
bytes4 selector = bytes4(txData_[0]) | ...;
if (selector != IMetaAggregationRouterV2.swap.selector) revert INVALID_SELECTOR();
```

---

## Testing Commands

```bash
# Build
forge build

# Unit tests
make forge-test TEST=KyberSwapUnitTests
make forge-test TEST=KyberSwapUpdateTxData

# All swap hook tests
make forge-test TEST=KyberSwap
```

---

## Summary Checklist

- [ ] Verify struct field ordering from Etherscan (`cast interface`)
- [ ] Create `src/vendor/kyberswap/IMetaAggregationRouterV2.sol`
- [ ] Create `src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol`
- [ ] Create `src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol`
- [ ] Create `test/mocks/MockKyberSwapRouter.sol`
- [ ] Create `test/unit/hooks/swappers/kyberswap/KyberSwapUnitTests.t.sol`
- [ ] Create `test/unit/hooks/swappers/kyberswap/KyberSwapUpdateTxData.t.sol`
- [ ] Update `script/utils/Constants.sol`
- [ ] Update `script/utils/ConfigBase.sol`
- [ ] Update `script/utils/ConfigCore.sol`
- [ ] Update `script/DeployV2Core.s.sol`
- [ ] Update `script/run/regenerate_bytecode.sh`
- [ ] Run `forge build` successfully
- [ ] Run unit tests successfully
- [ ] Run `make coverage-genhtml` (verify no stack-too-deep issues)
