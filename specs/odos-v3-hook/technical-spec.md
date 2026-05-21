# Odos V3 Hook Technical Specification

## Overview

Two new swap hooks integrating with the Odos V3 DEX aggregator router. The V3 router replaces V2's `uint32 referralCode` with `swapReferralInfo { uint64 code, uint64 fee, address feeRecipient }`, requiring a new hook data layout with referral fee validation.

## Problem Statement

Odos has launched their V3 router at `0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05` (same address all EVM chains). The Superform V2 hooks use the old V2 router interface with `uint32 referralCode`. To use V3's inline fee parameters, new hooks are needed. V2 hooks remain for backward compatibility.

## Proposed Solution

Create `SwapOdosV3Hook` and `ApproveAndSwapOdosV3Hook` mirroring V2 patterns with:
- New `IOdosRouterV3` interface with `swapReferralInfo` struct
- Extended data layout for 3 referral fields (code, fee, feeRecipient)
- Referral fee cap validation (router max: 2%)
- `feeRecipient != address(0)` when `fee > 0`

## Technical Considerations

### V3 Router Interface (CRITICAL)

The V3 struct uses `uint64` for code and fee (NOT `uint256`):

```solidity
interface IOdosRouterV3 {
    struct swapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }

    struct swapReferralInfo {
        uint64 code;
        uint64 fee;           // FEE_DENOM = 1e18, max = FEE_DENOM/50 = 2%
        address feeRecipient;
    }

    function swap(
        swapTokenInfo memory tokenInfo,
        bytes calldata pathDefinition,
        address executor,
        swapReferralInfo memory referralInfo
    ) external payable returns (uint256 amountOut);
}
```

### V3 Hook Data Layout (Tight-Packed, BytesLib Convention)

```
Offset 0:            address inputToken            (20 bytes)
Offset 20:           uint256 inputAmount           (32 bytes)
Offset 52:           address inputReceiver         (20 bytes)
Offset 72:           address outputToken           (20 bytes)
Offset 92:           uint256 outputQuote           (32 bytes)
Offset 124:          uint256 outputMin             (32 bytes)
Offset 156:          bool usePrevHookAmount        (1 byte)
Offset 157:          uint256 pathDefinitionLength  (32 bytes)
Offset 189:          bytes pathDefinition          (variable, pathDefinitionLength bytes)
Offset 189+len:      address executor              (20 bytes)
Offset 189+len+20:   uint64 referralCode           (8 bytes)
Offset 189+len+28:   uint64 referralFee            (8 bytes)
Offset 189+len+36:   address feeRecipient          (20 bytes)
Total tail: 56 bytes (vs V2's 24 bytes)
```

### Fee Validation

```solidity
uint64 public constant FEE_DENOM = 1e18;
uint64 public constant MAX_REFERRAL_FEE = FEE_DENOM / 50; // 2% -- matches router cap

error REFERRAL_FEE_TOO_HIGH();

// In _buildHookExecutions (view context, early revert):
if (referralFee > MAX_REFERRAL_FEE) revert REFERRAL_FEE_TOO_HIGH();
if (referralFee > 0 && feeRecipient == address(0)) revert ADDRESS_NOT_VALID();
```

### Native ETH Handling

- `SwapOdosV3Hook`: Sets `value: inputAmount` when `inputToken == address(0)`. Output balance check uses `account.balance`.
- `ApproveAndSwapOdosV3Hook`: When `inputToken == address(0)`, skip all approval executions (reduce from 4 to 1 inner execution). Follow UniV2 conditional pattern.

### inspect() Return Format

```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    // ... decode executor and feeRecipient from data ...
    return abi.encodePacked(executor, feeRecipient);
}
```

Returns 40 bytes: executor(20) + feeRecipient(20). Off-chain validator decodes both addresses.

### usePrevHookAmount Behavior

- `inputAmount` replaced by `ISuperHookResult(prevHook).getOutAmount(account)`
- `outputMin` scaled proportionally via `HookDataUpdater.getUpdatedOutputAmount()`
- `outputQuote` NOT scaled (matches V2 behavior)
- `referralInfo` passed through unchanged

## Attack Surface Analysis

### Referral Fee (V3-specific)
- [x] Fee capped at MAX_REFERRAL_FEE (2%) in _buildHookExecutions
- [x] feeRecipient != address(0) when fee > 0
- [x] feeRecipient exposed via inspect() for off-chain validation

### Token Risks
- [x] Standard ERC-20 only (same as V2)
- [x] Balance delta pattern handles actual received amounts
- [x] Approval pattern: approve(0)-approve(N)-swap-approve(0)

### Reentrancy
- [x] BaseHook transient storage mutex protects pre/post execute
- [x] No additional guards needed

### Oracle & Price
- [x] outputMin enforced by Odos router
- [x] No oracle dependencies in the hook

### Access Control
- [x] BaseHook msg.sender == account check
- [x] No additional restrictions (SuperExecutor validates userOps)

### Exploit Precedent
| Protocol | Attack | Our Mitigation |
|----------|--------|----------------|
| Kame Aggregator ($1.325M) | Arbitrary executor | inspect() exposes executor for off-chain validation |
| SwapNet/Aperture ($17M) | Unvalidated swap calldata | outputMin + balance delta |
| Odos LimitOrderRouter ($50K) | Arbitrary call | Not applicable (we call swap() only) |

## Acceptance Criteria

### Functional
- [ ] SwapOdosV3Hook builds 1 inner execution (swap) with correct V3 `abi.encodeCall`
- [ ] ApproveAndSwapOdosV3Hook builds 4 inner executions (approve-0, approve-amount, swap, approve-0)
- [ ] ApproveAndSwapOdosV3Hook reduces to 1 inner execution when inputToken=address(0)
- [ ] `usePrevHookAmount=true` reads prevHook output, scales inputAmount and outputMin
- [ ] Pre/post execute balance delta tracking stores correct outAmount
- [ ] Native ETH input works (SwapOdosV3Hook sets value, ApproveAndSwapOdosV3Hook skips approvals)
- [ ] Native ETH output balance tracking uses `account.balance`
- [ ] `decodeUsePrevHookAmount()` reads bool at offset 156

### Security
- [ ] referralFee > MAX_REFERRAL_FEE reverts with REFERRAL_FEE_TOO_HIGH
- [ ] referralFee > 0 && feeRecipient == address(0) reverts with ADDRESS_NOT_VALID
- [ ] inspect() returns abi.encodePacked(executor, feeRecipient)
- [ ] Constructor reverts on router address(0)

### Testing
- [ ] Unit tests: build execution count, fee cap boundary, feeRecipient validation, inspect format
- [ ] Unit tests: usePrevHookAmount with proportional scaling
- [ ] Unit tests: native ETH input/output for both variants
- [ ] Fuzz tests: referralFee boundary (at/above cap)
- [ ] MockOdosRouterV3 implementing V3 swap signature

## Implementation

### New Files

#### `src/vendor/odos/IOdosRouterV3.sol`
```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

interface IOdosRouterV3 {
    struct swapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address inputReceiver;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }

    struct swapReferralInfo {
        uint64 code;
        uint64 fee;
        address feeRecipient;
    }

    function swap(
        swapTokenInfo memory tokenInfo,
        bytes calldata pathDefinition,
        address executor,
        swapReferralInfo memory referralInfo
    ) external payable returns (uint256 amountOut);
}
```

#### `src/hooks/swappers/odos/SwapOdosV3Hook.sol`
```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// Mirror SwapOdosV2Hook structure with:
// - IOdosRouterV3 instead of IOdosRouterV2
// - swapReferralInfo struct in abi.encodeCall
// - Extended data decoding for uint64 code, uint64 fee, address feeRecipient
// - Fee validation: referralFee <= MAX_REFERRAL_FEE
// - feeRecipient validation: != address(0) when fee > 0
// - inspect() returns abi.encodePacked(executor, feeRecipient)
// - _getSwapInfo returns (IOdosRouterV3.swapTokenInfo, bytes, address, IOdosRouterV3.swapReferralInfo)
```

#### `src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol`
```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// Mirror ApproveAndSwapOdosV2Hook structure with:
// - IOdosRouterV3 instead of IOdosRouterV2
// - All V3 changes from SwapOdosV3Hook
// - Native ETH conditional: skip approvals when inputToken == address(0)
// - HookParams struct extended with referralFee and feeRecipient fields
```

#### `test/unit/hooks/swappers/odos/OdosV3UnitTests.t.sol`
```solidity
// Mirror OdosUnitTests.t.sol structure with:
// - MockOdosRouterV3 implementing IOdosRouterV3.swap()
// - _buildSwapOdosV3Data() helper encoding 3 referral fields
// - Test: fee cap enforcement (at cap, above cap)
// - Test: feeRecipient validation
// - Test: inspect() returns 40 bytes (executor + feeRecipient)
// - Test: native ETH input on both variants
// - Test: ApproveAndSwapOdosV3Hook skips approvals for native input
// - Fuzz: referralFee boundary
```

#### `test/mocks/MockOdosRouterV3.sol`
```solidity
// Mirror MockOdosRouterV2.sol with V3 swap signature
// Accept swapReferralInfo struct, validate fee <= FEE_DENOM/50
// Transfer output tokens to outputReceiver
```

### Modified Files

#### `test/utils/InternalHelpers.sol`
Add `_createOdosV3SwapHookData()` helper:
```solidity
function _createOdosV3SwapHookData(
    address inputToken,
    uint256 inputAmount,
    address inputReceiver,
    address outputToken,
    uint256 outputQuote,
    uint256 outputMin,
    bytes memory pathDefinition,
    address executor,
    uint64 referralCode,
    uint64 referralFee,
    address feeRecipient,
    bool usePrevHookAmount
) internal pure returns (bytes memory hookData) {
    hookData = abi.encodePacked(
        inputToken, inputAmount, inputReceiver, outputToken,
        outputQuote, outputMin, usePrevHookAmount,
        pathDefinition.length, pathDefinition,
        executor, referralCode, referralFee, feeRecipient
    );
}
```

#### `script/utils/ConstantsOtherHooks.sol`
Add:
```solidity
string internal constant SWAP_ODOSV3_HOOK_KEY = "SwapOdosV3Hook";
string internal constant APPROVE_AND_SWAP_ODOSV3_HOOK_KEY = "ApproveAndSwapOdosV3Hook";
address internal constant ODOS_ROUTER_V3 = 0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05;
```

#### `script/DeployV2OtherHooks.s.sol`
Add `_deployOdosV3Hooks(uint64 chainId, string memory env)` following Algebra Integral pattern.

#### `script/run/regenerate_bytecode.sh`
Add `SwapOdosV3Hook` and `ApproveAndSwapOdosV3Hook` to the contracts array.

## References

### Internal
- `src/hooks/swappers/odos/SwapOdosV2Hook.sol` — V2 template
- `src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol` — V2 approve template
- `src/vendor/odos/IOdosRouterV2.sol` — V2 interface
- `src/hooks/BaseHook.sol` — Base hook contract
- `src/hooks/claim/merkl/MerklClaimRewardHook.sol:37-38` — Fee validation pattern
- `test/unit/hooks/swappers/odos/OdosUnitTests.t.sol` — V2 test template

### External
- [Odos Router V3 GitHub](https://github.com/odos-xyz/odos-router-v3)
- [Odos V3 Etherscan](https://etherscan.io/address/0x0d05a7d3448512b78fa8a9e46c4872c88c4a0d05)
- [Odos Documentation](https://docs.odos.xyz/)
- [Odos Fee Documentation](https://docs.odos.xyz/build/fees)
