# ClaimFailedTransferHook Implementation Plan

## Overview

Create a simple NONACCOUNTING hook that allows smart accounts to call `claimFailedTransfer(address token, uint256 amount)` on the StargateAdapter contract. This hook recovers tokens from failed LayerZero compose operations where the adapter stored them in its `failedTransfers` mapping.

The StargateAdapter is already deployed as a core contract. The hook simply needs to build an Execution that calls `claimFailedTransfer` on a given adapter address, with the token and amount provided in the hook data.

## Architecture Decision

This is one of the simplest possible hooks -- it builds a single Execution with no chaining support, no prev-hook awareness, and no complex accounting. The closest existing pattern is `NativeTransferHook` (a hook with no constructor args, NONACCOUNTING type, single execution, and no ISuperHookContextAware interface).

However, unlike NativeTransferHook, this hook needs:
- `_preExecute` / `_postExecute` to track the outAmount (tokens received by the account)
- Support for both ERC20 and native ETH (token = address(0))
- An `inspect()` function that returns only addresses

The hook takes the adapter address as a **constructor parameter** (immutable) for multi-chain deployment flexibility. This follows the pattern used by TransferHook (which takes `_nativeToken` as constructor parameter).

IMPORTANT: After further review, the adapter address should be passed per-call in the hook data, NOT as a constructor parameter. Reason: there may be multiple StargateAdapter instances on the same chain (one per upgrade/deployment), and the bundler needs to target whichever adapter holds the user's failed transfer balance. This follows the pattern of claim hooks like FluidClaimRewardHook which pass the target address in hook data.

## File Locations

### New Files to Create

1. **Hook Contract**: `src/hooks/claim/stargate/ClaimFailedTransferHook.sol`
2. **Unit Test**: `test/unit/hooks/claim/stargate/ClaimFailedTransferHook.t.sol`

### Files to Modify

3. **Bytecode Regeneration**: `script/run/regenerate_bytecode.sh` -- add `"ClaimFailedTransferHook"` to `HOOK_CONTRACTS` array
4. **Deploy Constants**: `script/utils/Constants.sol` -- add hook key constant
5. **Deploy Script**: `script/DeployV2Core.s.sol` -- add to HookAddresses struct, deployment array, and address assignment
6. **HookSubTypes (OPTIONAL)**: No new subtype needed. Use `HookSubTypes.CLAIM` since this is claiming stored funds -- identical to FluidClaimRewardHook's subtype.

## Data Layout

The hook data uses simple sequential encoding via `abi.encodePacked`:

```
Offset  | Type    | Field           | Description
--------|---------|-----------------|------------------------------------------
0       | address | adapter         | StargateAdapter address to claim from (20 bytes)
20      | address | token           | Token to claim, address(0) for native ETH (20 bytes)
52      | uint256 | amount          | Amount to claim (32 bytes)
```

Total data length: **72 bytes**

Why adapter is in data, not constructor:
- Multiple StargateAdapter deployments may exist per chain
- The bundler determines which adapter holds the user's failed balance
- Follows the FluidClaimRewardHook pattern of passing target in data

## Complete Contract Skeleton

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title ClaimFailedTransferHook
/// @author Superform Labs
/// @notice Hook to claim failed transfers from the StargateAdapter
/// @dev Calls claimFailedTransfer(address token, uint256 amount) on the StargateAdapter
/// @dev The StargateAdapter stores failed transfers in a failedTransfers mapping when lzCompose
///      token delivery fails. This hook allows smart accounts to recover those tokens.
/// @dev Supports both ERC20 tokens and native ETH (token = address(0))
/// @dev data has the following structure
/// @notice         address adapter = BytesLib.toAddress(data, 0);
/// @notice         address token = BytesLib.toAddress(data, 20);
/// @notice         uint256 amount = BytesLib.toUint256(data, 40);
contract ClaimFailedTransferHook is BaseHook {

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the claim amount is zero
    error CLAIM_AMOUNT_ZERO();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) { }

    /*//////////////////////////////////////////////////////////////
                             VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
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

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, 0),  // adapter
            BytesLib.toAddress(data, 20)  // token
        );
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the balance of the token for a given account
    /// @dev For native ETH (token = address(0)), returns the ETH balance
    /// @dev For ERC20 tokens, returns the ERC20 balance
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

### Key Design Decisions

1. **NONACCOUNTING HookType**: This hook does not affect Superform's vault accounting system. It is a utility hook for recovering stuck tokens.

2. **CLAIM HookSubtype**: Uses the existing `HookSubTypes.CLAIM` subtype, consistent with FluidClaimRewardHook.

3. **No ISuperHookContextAware**: No `usePrevHookAmount` support is needed. The amount to claim is always specified explicitly (it must match what the adapter has stored).

4. **No ISuperHookInflowOutflow / ISuperHookOutflow**: This is not an inflow/outflow hook that needs `decodeAmount` or `replaceCalldataAmount`.

5. **Pre/Post Execute Pattern**: Tracks `outAmount` as the difference in the account's token balance before and after execution. This allows subsequent hooks to use the claimed amount.

6. **Native ETH Support**: The `_getBalance` helper checks if `token == address(0)` and uses `account.balance` for native ETH, matching how the StargateAdapter itself treats `address(0)` as native ETH.

7. **`inspect()` returns only addresses**: Returns `adapter` and `token` addresses -- NEVER amounts or other data types. This is a protocol requirement.

8. **`inspect()` uses `pure` visibility**: Since there are no immutable variables accessed, `pure` is correct (unlike hooks that access immutable state which need `view`).

9. **No `_decodeBool` usage**: There is no `usePrevHookAmount` flag in the data, so no boolean decoding.

10. **`abi.encodeWithSignature` for the call**: We use `abi.encodeWithSignature("claimFailedTransfer(address,uint256)", token, amount)` rather than importing the StargateAdapter interface. This keeps the hook decoupled from the adapter's full interface. The function signature is stable and well-defined.

    ALTERNATIVE: If the team prefers, we could define a minimal interface:
    ```solidity
    interface IStargateAdapterClaim {
        function claimFailedTransfer(address token, uint256 amount) external;
    }
    ```
    And use `abi.encodeCall(IStargateAdapterClaim.claimFailedTransfer, (token, amount))` for type safety. Either approach works; `abi.encodeCall` is slightly more gas-efficient and provides compile-time type checking.

## Unit Test Plan

File: `test/unit/hooks/claim/stargate/ClaimFailedTransferHook.t.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ClaimFailedTransferHook } from
    "../../../../../src/hooks/claim/stargate/ClaimFailedTransferHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";

contract ClaimFailedTransferHookTest is Helpers {
    using BytesLib for bytes;

    ClaimFailedTransferHook public hook;
    address public adapter;
    address public token;
    address public account;
    uint256 public amount;

    function setUp() public {
        MockERC20 _mockToken = new MockERC20("Mock Token", "MTK", 18);
        token = address(_mockToken);
        adapter = makeAddr("stargateAdapter");
        account = makeAddr("account");
        amount = 1000;

        hook = new ClaimFailedTransferHook();
    }

    // --- Constructor Tests ---

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    // --- Build Tests ---

    function test_Build_ERC20() public view {
        bytes memory data = _encodeData(adapter, token, amount);
        Execution[] memory executions = hook.build(address(0), account, data);

        // 3 executions: preExecute + claimFailedTransfer + postExecute
        assertEq(executions.length, 3);

        // Middle execution targets the adapter
        assertEq(executions[1].target, adapter);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_NativeETH() public view {
        bytes memory data = _encodeData(adapter, address(0), amount);
        Execution[] memory executions = hook.build(address(0), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, adapter);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_CallDataEncoding() public view {
        bytes memory data = _encodeData(adapter, token, amount);
        Execution[] memory executions = hook.build(address(0), account, data);

        // Verify the calldata encodes claimFailedTransfer(address,uint256)
        bytes memory expectedCalldata = abi.encodeWithSignature(
            "claimFailedTransfer(address,uint256)", token, amount
        );
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_RevertIf_AdapterZeroAddress() public {
        bytes memory data = _encodeData(address(0), token, amount);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertIf_AmountZero() public {
        bytes memory data = _encodeData(adapter, token, 0);
        vm.expectRevert(ClaimFailedTransferHook.CLAIM_AMOUNT_ZERO.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_TokenZeroAddress_Allowed() public view {
        // token = address(0) means native ETH - this is VALID, not an error
        bytes memory data = _encodeData(adapter, address(0), amount);
        Execution[] memory executions = hook.build(address(0), account, data);
        assertEq(executions.length, 3);
    }

    // --- Pre/Post Execute Tests ---

    function test_PreAndPostExecute_ERC20() public {
        _getTokens(token, account, amount);

        vm.prank(account);
        hook.preExecute(address(0), account, _encodeData(adapter, token, amount));
        assertEq(hook.getOutAmount(account), amount);

        vm.prank(account);
        hook.postExecute(address(0), account, _encodeData(adapter, token, amount));
        assertEq(hook.getOutAmount(account), 0);
    }

    function test_PreAndPostExecute_NativeETH() public {
        vm.deal(account, amount);

        vm.prank(account);
        hook.preExecute(address(0), account, _encodeData(adapter, address(0), amount));
        assertEq(hook.getOutAmount(account), amount);

        vm.prank(account);
        hook.postExecute(address(0), account, _encodeData(adapter, address(0), amount));
        assertEq(hook.getOutAmount(account), 0);
    }

    // --- Inspector Tests ---

    function test_Inspector() public view {
        bytes memory data = _encodeData(adapter, token, amount);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);

        // Should return adapter and token addresses only
        assertEq(BytesLib.toAddress(argsEncoded, 0), adapter);
        assertEq(BytesLib.toAddress(argsEncoded, 20), token);
    }

    function test_Inspector_NativeETH() public view {
        bytes memory data = _encodeData(adapter, address(0), amount);
        bytes memory argsEncoded = hook.inspect(data);

        assertEq(BytesLib.toAddress(argsEncoded, 0), adapter);
        assertEq(BytesLib.toAddress(argsEncoded, 20), address(0));
    }

    // --- Calldata Decoding Tests ---

    function test_CalldataDecoding() public view {
        address testAdapter = address(0x1234567890123456789012345678901234567890);
        address testToken = address(0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD);
        uint256 testAmount = 12345e18;

        bytes memory data = abi.encodePacked(testAdapter, testToken, testAmount);

        Execution[] memory executions = hook.build(address(0), account, data);

        // Check adapter is correctly used as target
        assertEq(executions[1].target, testAdapter, "Adapter address not correctly decoded");
        assertEq(data.length, 72, "Calldata length is incorrect");
    }

    // --- Fuzz Tests ---

    function testFuzz_Build(address fuzzAdapter, address fuzzToken, uint256 fuzzAmount) public view {
        vm.assume(fuzzAdapter != address(0));
        vm.assume(fuzzAmount > 0);

        bytes memory data = _encodeData(fuzzAdapter, fuzzToken, fuzzAmount);
        Execution[] memory executions = hook.build(address(0), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, fuzzAdapter);
    }

    // --- Helper Functions ---

    function _encodeData(
        address _adapter,
        address _token,
        uint256 _amount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(_adapter, _token, _amount);
    }
}
```

### Test Cases Summary

| Test Name | What It Validates |
|---|---|
| `test_Constructor` | HookType is NONACCOUNTING |
| `test_Build_ERC20` | Builds correct execution array for ERC20 claim |
| `test_Build_NativeETH` | Builds correct execution for native ETH claim (token=0x0) |
| `test_Build_CallDataEncoding` | Verifies the calldata matches `claimFailedTransfer(address,uint256)` signature |
| `test_Build_RevertIf_AdapterZeroAddress` | Reverts with ADDRESS_NOT_VALID when adapter is zero |
| `test_Build_RevertIf_AmountZero` | Reverts with CLAIM_AMOUNT_ZERO when amount is zero |
| `test_Build_TokenZeroAddress_Allowed` | Confirms token=address(0) is valid (native ETH) |
| `test_PreAndPostExecute_ERC20` | OutAmount tracking works for ERC20 tokens |
| `test_PreAndPostExecute_NativeETH` | OutAmount tracking works for native ETH |
| `test_Inspector` | Returns only adapter and token addresses |
| `test_Inspector_NativeETH` | Inspector works with address(0) token |
| `test_CalldataDecoding` | Full decode of arbitrary addresses and amounts |
| `testFuzz_Build` | Fuzz test for arbitrary valid inputs |

## Deployment Integration

### Step 1: Add Hook Key to Constants

File: `script/utils/Constants.sol`

Add after the existing claim-related hook keys (near line 265):

```solidity
string internal constant CLAIM_FAILED_TRANSFER_HOOK_KEY = "ClaimFailedTransferHook";
```

### Step 2: Add to HookAddresses Struct

File: `script/DeployV2Core.s.sol`

Add to the `HookAddresses` struct (after `approveAndCCTPSendHook` at line 103):

```solidity
address claimFailedTransferHook;
```

### Step 3: Add Deployment Entry

File: `script/DeployV2Core.s.sol`

This hook has NO constructor arguments, so use `_createSafeHookDeployment`:

Increment the hook array length from `70` to `71` at line 2468:

```solidity
uint256 len = 71; // was 70
```

Add the hook deployment (after the CCTP hooks at index 65):

```solidity
// ClaimFailedTransferHook - no constructor dependencies
hooks[66] = _createSafeHookDeployment(
    CLAIM_FAILED_TRANSFER_HOOK_KEY, "ClaimFailedTransferHook", env
);
```

NOTE: The exact index (66) depends on whether other hooks have been added between now and when this is implemented. Check what the current last used index is in `_deployHooks()` and use the next available one. Currently, indices 64-65 are CCTP hooks, and there may be gaps between 65 and 69 (len=70).

### Step 4: Add Address Assignment

File: `script/DeployV2Core.s.sol`

In `_populateHookAddresses()`, add after the CCTP address assignments:

```solidity
// ClaimFailedTransferHook
hookAddresses.claimFailedTransferHook =
    Strings.equal(hooks[66].name, CLAIM_FAILED_TRANSFER_HOOK_KEY) ? addresses[66] : address(0);
```

### Step 5: Add CheckContract Validation

File: `script/DeployV2Core.s.sol`

In the check hooks section (around the basic hooks without dependencies), add:

```solidity
__checkContract(CLAIM_FAILED_TRANSFER_HOOK_KEY, __getSalt(CLAIM_FAILED_TRANSFER_HOOK_KEY), "", env);
```

### Step 6: Add to Bytecode Regeneration Script

File: `script/run/regenerate_bytecode.sh`

Add `"ClaimFailedTransferHook"` to the `HOOK_CONTRACTS` array (after `"ApproveAndCCTPSendHook"` at line 174):

```bash
"ClaimFailedTransferHook"
```

## Implementation Checklist

- [ ] Create `src/hooks/claim/stargate/ClaimFailedTransferHook.sol`
- [ ] Create `test/unit/hooks/claim/stargate/ClaimFailedTransferHook.t.sol`
- [ ] Add `CLAIM_FAILED_TRANSFER_HOOK_KEY` to `script/utils/Constants.sol`
- [ ] Add `claimFailedTransferHook` to `HookAddresses` struct in `script/DeployV2Core.s.sol`
- [ ] Increment hook array length in `_deployHooks()` in `script/DeployV2Core.s.sol`
- [ ] Add deployment entry in `_deployHooks()` in `script/DeployV2Core.s.sol`
- [ ] Add address assignment in `_populateHookAddresses()` in `script/DeployV2Core.s.sol`
- [ ] Add `__checkContract` validation in `script/DeployV2Core.s.sol`
- [ ] Add `"ClaimFailedTransferHook"` to `HOOK_CONTRACTS` in `script/run/regenerate_bytecode.sh`
- [ ] Run `forge build` to verify compilation
- [ ] Run `make forge-test TEST=ClaimFailedTransferHook` to verify tests pass
- [ ] Run `./script/run/regenerate_bytecode.sh ClaimFailedTransferHook` to generate bytecode

## Important Notes

1. **No interface import for StargateAdapter**: The hook does NOT import the StargateAdapter contract or any interface. It uses `abi.encodeWithSignature` (or a minimal interface) to encode the call. This keeps the hook maximally decoupled. If the team prefers type-safe encoding, define a two-line interface inside the hook file.

2. **Token address(0) is VALID**: Unlike most hooks that revert on `token == address(0)`, this hook MUST allow it because the StargateAdapter uses `address(0)` to represent native ETH in its `failedTransfers` mapping.

3. **The hook value field is always 0**: Even for native ETH claims, the `Execution.value` is 0. The StargateAdapter sends ETH back to `msg.sender` via `msg.sender.call{value: amount}("")` -- the hook does NOT need to forward ETH.

4. **outAmount tracking for native ETH**: The `_getBalance` helper uses `account.balance` for native ETH. This means the outAmount will include any ETH balance changes from other sources during the transaction. In practice, this is fine since the pre/post difference captures the net change.

5. **Branch requirement**: This work should be done on the `pre-dev` branch as specified by the deployment guide.

6. **DeployV2Core.s.sol index assignment**: Before adding the hook, verify the current highest used hook index in `_deployHooks()`. The indices 66-69 may already be in use if other hooks were added between the current codebase state and when this is implemented. If so, use the next available index and increment `len` accordingly.
