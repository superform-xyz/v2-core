# ClaimFailedTransferHook Technical Specification

## Overview

Create a `ClaimFailedTransferHook` that allows smart accounts to call `claimFailedTransfer(address token, uint256 amount)` on the StargateAdapter. The StargateAdapter stores failed transfers in a `failedTransfers` mapping when `_tryTransfer` fails during `lzCompose`. This hook enables recovery of those tokens via the SuperExecutor hook system.

## Acceptance Criteria

- [ ] `ClaimFailedTransferHook` created at `src/hooks/claim/stargate/ClaimFailedTransferHook.sol`
- [ ] NONACCOUNTING hook type, CLAIM subtype (matches existing claim hooks)
- [ ] Supports both ERC20 and native ETH (token = address(0))
- [ ] Adapter address passed in hook data (not constructor) — multiple adapters per chain possible
- [ ] Builds single Execution targeting `claimFailedTransfer(address,uint256)`
- [ ] Pre/post execute tracks outAmount (balance delta)
- [ ] Unit tests at `test/unit/hooks/claim/stargate/ClaimFailedTransferHook.t.sol`
- [ ] Bytecode generated

## Context

**Closest pattern:** `FluidClaimRewardHook` — also a claim hook with target address in data. Key differences:
- Our hook uses `NONACCOUNTING` (not `OUTFLOW`) since this is recovery, not vault accounting
- No `ISuperHookInflowOutflow` / `ISuperHookOutflow` / `ISuperHookContextAware` — no chaining needed
- No `BaseClaimRewardHook` — that reverts on token=address(0), but we need it for native ETH
- Uses `abi.encodeWithSignature` to stay decoupled from adapter interface

**Data layout (72 bytes, abi.encodePacked):**
```
Offset 0:  address adapter  (20 bytes) — StargateAdapter to claim from
Offset 20: address token    (20 bytes) — Token to claim, address(0) for native ETH
Offset 40: uint256 amount   (32 bytes) — Amount to claim
```

## Implementation

### src/hooks/claim/stargate/ClaimFailedTransferHook.sol

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title ClaimFailedTransferHook
/// @author Superform Labs
/// @notice Hook to claim failed transfers from the StargateAdapter
/// @dev Calls claimFailedTransfer(address token, uint256 amount) on the StargateAdapter
/// @dev The StargateAdapter stores failed transfers when lzCompose token delivery fails.
///      This hook allows smart accounts to recover those tokens.
/// @dev Supports both ERC20 tokens and native ETH (token = address(0))
/// @dev data layout:
/// @notice         address adapter = BytesLib.toAddress(data, 0);
/// @notice         address token = BytesLib.toAddress(data, 20);
/// @notice         uint256 amount = BytesLib.toUint256(data, 40);
contract ClaimFailedTransferHook is BaseHook {

    error CLAIM_AMOUNT_ZERO();

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) { }

    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    ) internal pure override returns (Execution[] memory executions) {
        address adapter = BytesLib.toAddress(data, 0);
        address token = BytesLib.toAddress(data, 20);
        uint256 amount = BytesLib.toUint256(data, 40);

        if (adapter == address(0)) revert ADDRESS_NOT_VALID();
        if (amount == 0) revert CLAIM_AMOUNT_ZERO();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: adapter,
            value: 0,
            callData: abi.encodeWithSignature("claimFailedTransfer(address,uint256)", token, amount)
        });
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, 0),  // adapter
            BytesLib.toAddress(data, 20)  // token
        );
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
    }

    function _getBalance(bytes calldata data, address account) private view returns (uint256) {
        address token = BytesLib.toAddress(data, 20);
        if (token == address(0)) {
            return account.balance;
        } else {
            return IERC20(token).balanceOf(account);
        }
    }
}
```

### Deployment changes

1. **`script/utils/Constants.sol`** — add `CLAIM_FAILED_TRANSFER_HOOK_KEY`
2. **`script/DeployV2Core.s.sol`** — add to HookAddresses struct, deployment array (no constructor args), address assignment, `__checkContract`
3. **`script/run/regenerate_bytecode.sh`** — add to `HOOK_CONTRACTS` array

### Test plan

| Test | Validates |
|------|-----------|
| `test_Constructor` | HookType is NONACCOUNTING |
| `test_Build_ERC20` | Correct execution array for ERC20 claim |
| `test_Build_NativeETH` | Correct execution for native ETH (token=0x0) |
| `test_Build_CallDataEncoding` | Calldata matches `claimFailedTransfer(address,uint256)` |
| `test_Build_RevertIf_AdapterZeroAddress` | Reverts ADDRESS_NOT_VALID |
| `test_Build_RevertIf_AmountZero` | Reverts CLAIM_AMOUNT_ZERO |
| `test_Build_TokenZeroAddress_Allowed` | token=address(0) is valid |
| `test_PreAndPostExecute_ERC20` | outAmount tracking for ERC20 |
| `test_PreAndPostExecute_NativeETH` | outAmount tracking for native ETH |
| `test_Inspector` | Returns adapter + token addresses |
| `test_Inspector_NativeETH` | Inspector with address(0) token |
| `test_CalldataDecoding` | Full decode of arbitrary inputs |
| `testFuzz_Build` | Fuzz test for valid inputs |

## References

- Pattern: `src/hooks/claim/fluid/FluidClaimRewardHook.sol`
- Target: `src/adapters/StargateAdapter.sol:262` (`claimFailedTransfer`)
- Base: `src/hooks/BaseHook.sol`
- Test pattern: `test/unit/hooks/claim/fluid/FluidClaimRewardHook.t.sol`
