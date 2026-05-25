# Odos V3 Hook Implementation Plan

## Summary

Create `SwapOdosV3Hook` and `ApproveAndSwapOdosV3Hook` for the Odos V3 DEX aggregator router. The V3 router replaces V2's `uint32 referralCode` with `swapReferralInfo { uint64 code, uint64 fee, address feeRecipient }`, requiring an extended hook data layout with referral fee validation. `ApproveAndSwapOdosV3Hook` additionally adds native ETH support (skipping all approvals when inputToken is address(0)).

## Branch Requirement

MUST be on `pre-dev` branch. Check current branch before starting.

---

## Research Findings

### 1. V3 Data Layout Validation (CONFIRMED CORRECT)

The V2 hook data layout (from `SwapOdosV2Hook.sol` NatSpec and source):

```
Offset 0:    address inputToken           (20 bytes)
Offset 20:   uint256 inputAmount          (32 bytes)
Offset 52:   address inputReceiver        (20 bytes)
Offset 72:   address outputToken          (20 bytes)
Offset 92:   uint256 outputQuote          (32 bytes)
Offset 124:  uint256 outputMin            (32 bytes)
Offset 156:  bool usePrevHookAmount       (1 byte)
Offset 157:  uint256 pathDefinitionLength (32 bytes)
Offset 189:  bytes pathDefinition         (variable)
Offset 189+len:     address executor      (20 bytes)
Offset 189+len+20:  uint32 referralCode   (4 bytes)
V2 tail: 24 bytes (executor:20 + referralCode:4)
```

The V3 data layout extends the tail section:

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
V3 tail: 56 bytes (executor:20 + code:8 + fee:8 + feeRecipient:20)
```

The shared prefix (offsets 0-189+pathDefinitionLength) is identical. The difference is only in the tail (after pathDefinition).

### 2. Patterns and Helpers to Reuse

The following from V2 should be reused directly:

- **BaseHook**: Same inheritance pattern (`BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)`)
- **ISuperHookContextAware**: Same `decodeUsePrevHookAmount` pattern at offset 156
- **HookDataUpdater.getUpdatedOutputAmount**: Same proportional scaling for `usePrevHookAmount`
- **`_decodeBool(data, 156)`**: Same position, same logic
- **`_getBalance` private method**: Identical implementation (checks outputToken at offset 72)
- **`_preExecute` / `_postExecute`**: Identical balance-delta tracking pattern
- **`_getSwapInfo` pattern**: Same prefix decoding, returns V3 struct instead of V2
- **BytesLib**: `toAddress`, `toUint256`, `toUint64` (confirmed available at line 319-328 of BytesLib.sol)
- **ISuperHookResult**: Same chaining pattern for `getOutAmount`

### 3. BytesLib.toUint64 Availability (CONFIRMED)

`BytesLib.toUint64` IS available in the codebase (lines 319-328 of `src/vendor/BytesLib.sol`):

```solidity
function toUint64(bytes memory _bytes, uint256 _start) internal pure returns (uint64) {
    require(_bytes.length >= _start + 8, "toUint64_outOfBounds");
    uint64 tempUint;
    assembly {
        tempUint := mload(add(add(_bytes, 0x8), _start))
    }
    return tempUint;
}
```

No gotchas here -- it follows the same pattern as `toUint32`, `toAddress`, etc.

### 4. Native ETH Conditional for ApproveAndSwap (Reducing 4 to 1 Execution)

The pattern is proven in `ApproveAndSwapUniswapV2Hook.sol` (lines 112-159):

```solidity
if (tokenIn == NATIVE) {
    // Native input: skip approvals, only 1 execution with value
    executions = new Execution[](1);
    executions[0] = Execution({
        target: address(SWAP_ROUTER),
        value: amountIn,
        callData: abi.encodeCall(...)
    });
} else {
    // ERC-20 input: approve(0) -> approve(amount) -> swap -> approve(0)
    executions = new Execution[](4);
    // ... 4 executions
}
```

For `ApproveAndSwapOdosV3Hook`, the conditional is simpler because the Odos router uses the same `swap()` function signature for both native ETH and ERC-20 inputs (unlike UniswapV2 which has separate `swapExactETHForTokens` vs `swapExactTokensForTokens`). The difference is:

- **Native ETH**: `value: inputAmount`, no approvals. 1 execution total.
- **ERC-20**: `value: 0`, with approve(0) -> approve(amount) -> swap -> approve(0). 4 executions total.

The `inputToken == address(0)` check (not a NATIVE sentinel like UniV2) is the standard Odos pattern, already used in `SwapOdosV2Hook` at line 71 for the `value` field.

### 5. V2 Test Data Encoding Quirk (IMPORTANT WARNING)

The V2 test `_buildApproveAndSwapOdosData` helper includes a phantom `bytes20(address(0))` between the bool and pathDefinitionLength (lines 264-265 of OdosUnitTests.t.sol). This is **incorrect** -- it pushes the pathDefinitionLength 20 bytes past where the hook reads it (offset 157), making the encoded data technically malformed. The tests still pass because they only check execution counts and target addresses, not actual swap calldata values.

The `_buildSwapOdosData` helper does NOT include this phantom padding, and matches the hook's expected layout correctly.

**For V3 tests**: Do NOT replicate this phantom padding. Follow the `_buildSwapOdosData` pattern (no padding) for both swap and approve-and-swap helpers.

### 6. Deployment Decision: DeployV2Core vs DeployV2OtherHooks

The V2 Odos hooks are deployed via **DeployV2Core.s.sol** (not OtherHooks). However, V3 hooks should go in **DeployV2OtherHooks.s.sol** because:

1. The V2 hooks in DeployV2Core are part of the locked bytecode system (audited). Adding V3 to DeployV2Core would require changing the array length and indices of all existing hooks, which is risky.
2. The OtherHooks script is designed for incremental hook additions (Morpho, Aave V4, Firelight, Algebra, DETH were all added post-audit).
3. The Odos V3 router address (`0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05`) is the same on all EVM chains, so we can use a constant in ConstantsOtherHooks.

### 7. inspect() Return Format (CONFIRMED)

V2 `inspect()` returns `abi.encodePacked(executor)` (20 bytes).
V3 `inspect()` should return `abi.encodePacked(executor, feeRecipient)` (40 bytes).

This follows the protocol requirement: only addresses, never amounts or other data types.

---

## Implementation Tasks

### Task 1: Create `src/vendor/odos/IOdosRouterV3.sol`

**New file.** Mirror `IOdosRouterV2.sol` structure with V3 types.

```solidity
// SPDX-License-Identifier: UNLICENSED
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

Notes:
- The `swapTokenInfo` struct is identical between V2 and V3.
- No `permit2Info`, `swapPermit2`, or `swapCompact` -- V3 interface only needs `swap()` for our hooks.
- License should match V2: `UNLICENSED`.
- The struct names are lowercase (`swapTokenInfo`, `swapReferralInfo`) -- this matches the actual Odos V3 router ABI.

### Task 2: Create `src/hooks/swappers/odos/SwapOdosV3Hook.sol`

**New file.** Mirror `SwapOdosV2Hook.sol` with the following changes:

1. **Import `IOdosRouterV3` instead of `IOdosRouterV2`**.

2. **Immutable**: `IOdosRouterV3 public immutable ODOS_ROUTER_V3;`

3. **Constructor**: Same pattern, takes `address _routerV3`.

4. **Constants for fee validation**:
   ```solidity
   uint64 public constant FEE_DENOM = 1e18;
   uint64 public constant MAX_REFERRAL_FEE = FEE_DENOM / 50; // 2%
   ```
   IMPORTANT: `uint64` can hold up to ~1.8e19, so `1e18` fits in uint64.

5. **Custom error**: `error REFERRAL_FEE_TOO_HIGH();`

6. **NatSpec data layout**: Update to V3 layout (see section 1 above). The NatSpec MUST be placed immediately after the line `/// @dev data has the following structure`.

7. **`_buildHookExecutions`**: Decode the 3 new tail fields using `BytesLib.toUint64` and `BytesLib.toAddress`:
   ```solidity
   uint256 tailOffset = 189 + pathDefinitionLength;
   address executor = BytesLib.toAddress(data, tailOffset);
   uint64 referralCode = BytesLib.toUint64(data, tailOffset + 20);
   uint64 referralFee = BytesLib.toUint64(data, tailOffset + 28);
   address feeRecipient = BytesLib.toAddress(data, tailOffset + 36);
   ```
   Then validate:
   ```solidity
   if (referralFee > MAX_REFERRAL_FEE) revert REFERRAL_FEE_TOO_HIGH();
   if (referralFee > 0 && feeRecipient == address(0)) revert ADDRESS_NOT_VALID();
   ```
   Then build the single execution with `abi.encodeCall(IOdosRouterV3.swap, (...))` passing `swapReferralInfo` struct.

8. **`_getSwapInfo`**: Returns `IOdosRouterV3.swapTokenInfo` instead of V2's.

9. **`inspect()`**: Decode executor AND feeRecipient from tail, return `abi.encodePacked(executor, feeRecipient)`.

10. **`value` field**: Same as V2: `inputToken == address(0) ? inputAmount : 0`.

11. **All other methods** (`_preExecute`, `_postExecute`, `_getBalance`, `decodeUsePrevHookAmount`): Identical to V2.

### Task 3: Create `src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol`

**New file.** Mirror `ApproveAndSwapOdosV2Hook.sol` with V3 changes plus native ETH conditional.

Key differences from V2 `ApproveAndSwapOdosV2Hook`:

1. **All V3 changes from Task 2** (imports, immutable, constructor, constants, errors, NatSpec, tail decoding, fee validation, inspect).

2. **`HookParams` struct**: Extended with V3 fields:
   ```solidity
   struct HookParams {
       address inputToken;
       uint256 inputAmount;
       address approveSpender;
       bytes pathDefinition;
       address executor;
       uint64 referralCode;
       uint64 referralFee;
       address feeRecipient;
   }
   ```

3. **Native ETH conditional** in `_buildHookExecutions`:
   ```solidity
   if (params.inputToken == address(0)) {
       // Native ETH: skip all approvals, 1 execution only
       executions = new Execution[](1);
       executions[0] = Execution({
           target: address(ODOS_ROUTER_V3),
           value: params.inputAmount,
           callData: abi.encodeCall(
               IOdosRouterV3.swap,
               (_getSwapInfo(account, prevHook, data), params.pathDefinition, params.executor,
                IOdosRouterV3.swapReferralInfo(params.referralCode, params.referralFee, params.feeRecipient))
           )
       });
   } else {
       // ERC-20: approve(0) -> approve(amount) -> swap -> approve(0)
       executions = new Execution[](4);
       // ... same 4-execution pattern as V2 but with V3 swap call
   }
   ```

4. **`_getSwapInfo`**: Returns `IOdosRouterV3.swapTokenInfo`.

### Task 4: Create `test/mocks/MockOdosRouterV3.sol`

**New file.** Mirror `MockOdosRouterV2.sol` with V3 swap signature.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IOdosRouterV3 } from "../../src/vendor/odos/IOdosRouterV3.sol";

contract MockOdosRouterV3 {
    function swap(
        IOdosRouterV3.swapTokenInfo memory tokenInfo,
        bytes calldata,
        address,
        IOdosRouterV3.swapReferralInfo memory
    )
        external
        payable
        returns (uint256 amountOut)
    {
        if (tokenInfo.inputToken != address(0)) {
            ERC20(tokenInfo.inputToken).transferFrom(msg.sender, address(this), tokenInfo.inputAmount);
        }

        if (tokenInfo.outputToken != address(0)) {
            ERC20(tokenInfo.outputToken).transfer(
                msg.sender, tokenInfo.outputQuote - (tokenInfo.outputQuote * 50 / 10_000)
            ); // 0.5%
        } else {
            payable(msg.sender).transfer(tokenInfo.outputQuote);
        }

        return tokenInfo.outputMin;
    }
}
```

Notes:
- No need for `swapCompact` -- only `swap` is used by V3 hooks.
- The mock accepts `swapReferralInfo` but does not validate it (fee validation is in the hook, not the router mock).
- The mock should also accept ETH via `receive() external payable {}` so it can be funded for native output tests.

### Task 5: Create `test/unit/hooks/swappers/odos/OdosV3UnitTests.t.sol`

**New file.** Mirror `OdosUnitTests.t.sol` structure but with V3-specific tests added.

Key structure:
- Import `SwapOdosV3Hook`, `ApproveAndSwapOdosV3Hook`, `IOdosRouterV3`
- Define inline `MockOdosRouterV3` (following the pattern in OdosUnitTests.t.sol where MockOdosRouter is defined inline)
- Test variables: add `uint64 referralCode = 123;`, `uint64 referralFee = 0;`, `address feeRecipient;`
- `receive() external payable { }` -- required for tests dealing with native ETH

Test cases to include:

**Constructor tests:**
- `test_Constructor()` -- hookType, immutable router address
- `test_Constructor_RevertIf_AddressZero()`

**ApproveAndSwapOdosV3Hook tests:**
- `test_Build()` -- ERC-20 input: verify 6 executions (pre + approve(0) + approve(N) + swap + approve(0) + post)
- `test_Build_NativeInput()` -- native ETH input: verify 3 executions (pre + swap + post). CRITICAL TEST.
- `test_Build_NativeInput_Value()` -- verify the swap execution has `value: inputAmount`
- `test_Build_WithPrevHookAmount()`
- `test_PreExecute()`
- `test_PostExecute()`
- `test_DecodeUsePrevHookAmount_True()`
- `test_DecodeUsePrevHookAmount_False()`
- `test_inspect()` -- verify returns 40 bytes (executor + feeRecipient)
- `test_inspect_Format()` -- decode returned bytes and verify both addresses

**SwapOdosV3Hook tests:**
- `test_SwapOdosV3Hook_Build()` -- verify 3 executions (pre + swap + post)
- `test_SwapOdosV3Hook_Build_WithPrevHookAmount()`
- `test_SwapOdosV3Hook_PreExecute()`
- `test_SwapOdosV3Hook_PostExecute()`
- `test_SwapOdosV3Hook_DecodeUsePrevHookAmount()`
- `test_SwapOdosV3Hook_inspect()` -- verify returns 40 bytes

**Fee validation tests:**
- `test_Build_RevertIf_ReferralFeeTooHigh()` -- set `referralFee = MAX_REFERRAL_FEE + 1`
- `test_Build_ReferralFeeAtCap()` -- set `referralFee = MAX_REFERRAL_FEE`, should NOT revert
- `test_Build_RevertIf_FeeRecipientZeroWithNonZeroFee()` -- `referralFee > 0, feeRecipient = address(0)`
- `test_Build_ZeroFee_ZeroRecipient()` -- `referralFee = 0, feeRecipient = address(0)`, should NOT revert
- `testFuzz_ReferralFeeBoundary(uint64 fee)` -- fuzz fee, expect revert if > MAX_REFERRAL_FEE

**Native ETH tests:**
- `test_NativeSwapOdosV3Hook()` -- SwapOdosV3Hook with native input
- `test_PreExecuteNativeSwapOdosV3Hook()` -- balance tracking with ETH
- `test_NativeOutputBalance()` -- balance tracking when outputToken is native

**Data encoding helper:**
```solidity
function _buildSwapOdosV3Data(bool usePrevious) internal view returns (bytes memory) {
    return bytes.concat(
        bytes20(inputToken),
        bytes32(inputAmount),
        bytes20(inputReceiver),
        bytes20(outputToken),
        bytes32(outputQuote),
        bytes32(outputMin),
        usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
        bytes32(pathDefinition.length),
        pathDefinition,
        bytes20(executor),
        bytes8(referralCode),
        bytes8(referralFee),
        bytes20(feeRecipient)
    );
}
```

IMPORTANT: Do NOT include the phantom `bytes20(address(0))` padding that exists in the V2 `_buildApproveAndSwapOdosData`. The V3 helper should match the hook's expected layout exactly.

### Task 6: Modify `script/utils/ConstantsOtherHooks.sol`

Add constants:
```solidity
// Odos V3 hook keys
string internal constant SWAP_ODOSV3_HOOK_KEY = "SwapOdosV3Hook";
string internal constant APPROVE_AND_SWAP_ODOSV3_HOOK_KEY = "ApproveAndSwapOdosV3Hook";

// Odos V3 Router (same address on all EVM chains)
address internal constant ODOS_ROUTER_V3 = 0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05;
```

### Task 7: Modify `script/utils/ConfigOtherHooks.sol`

Add to `OtherHooksData` struct:
```solidity
mapping(uint64 chainId => address odosRouterV3) odosRouterV3s;
```

Add to `_setOtherHooksConfiguration()`:
```solidity
// Odos V3 Router (same CREATE2 address on all EVM chains)
otherHooksConfiguration.odosRouterV3s[MAINNET_CHAIN_ID] = ODOS_ROUTER_V3;
otherHooksConfiguration.odosRouterV3s[BASE_CHAIN_ID] = ODOS_ROUTER_V3;
otherHooksConfiguration.odosRouterV3s[BNB_CHAIN_ID] = ODOS_ROUTER_V3;
otherHooksConfiguration.odosRouterV3s[ARBITRUM_CHAIN_ID] = ODOS_ROUTER_V3;
otherHooksConfiguration.odosRouterV3s[OPTIMISM_CHAIN_ID] = ODOS_ROUTER_V3;
otherHooksConfiguration.odosRouterV3s[POLYGON_CHAIN_ID] = ODOS_ROUTER_V3;
otherHooksConfiguration.odosRouterV3s[AVALANCHE_CHAIN_ID] = ODOS_ROUTER_V3;
otherHooksConfiguration.odosRouterV3s[SONIC_CHAIN_ID] = ODOS_ROUTER_V3;
otherHooksConfiguration.odosRouterV3s[LINEA_CHAIN_ID] = ODOS_ROUTER_V3;
otherHooksConfiguration.odosRouterV3s[UNICHAIN_CHAIN_ID] = ODOS_ROUTER_V3;
// Not deployed on these chains (verify before deploying):
otherHooksConfiguration.odosRouterV3s[BERACHAIN_CHAIN_ID] = address(0);
otherHooksConfiguration.odosRouterV3s[GNOSIS_CHAIN_ID] = address(0);
otherHooksConfiguration.odosRouterV3s[WORLDCHAIN_CHAIN_ID] = address(0);
```

NOTE: The V3 router address `0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05` needs to be verified for each chain before production deployment. It is advertised as the same address on all EVM chains, but verify which chains actually have it deployed.

### Task 8: Modify `script/DeployV2OtherHooks.s.sol`

Add:

1. **New struct**:
   ```solidity
   struct OdosV3HookAddresses {
       address swapOdosV3Hook;
       address approveAndSwapOdosV3Hook;
   }
   ```

2. **New `runOdosV3` entry point** (following `runAlgebraIntegral` pattern):
   ```solidity
   function runOdosV3(uint256 env, uint64 chainId) public broadcast(env) {
       _setConfiguration(env, "");
       console2.log("Deploying Odos V3 Hooks on chainId: ", chainId);
       _deployOdosV3Hooks(chainId, env);
       _writeExportedContracts(chainId);
   }
   ```

3. **Add to `_deployAllHooks`**:
   ```solidity
   // Odos V3 hooks -- on chains where Odos V3 router is deployed
   if (otherHooksConfiguration.odosRouterV3s[chainId] != address(0)) {
       console2.log("Deploying Odos V3 Hooks on chainId: ", chainId);
       _deployOdosV3Hooks(chainId, env);
   }
   ```

4. **New `_deployOdosV3Hooks` method** (following `_deployAlgebraIntegralHooks` pattern):
   ```solidity
   function _deployOdosV3Hooks(
       uint64 chainId,
       uint256 env
   ) internal returns (OdosV3HookAddresses memory) {
       uint256 len = 2;
       HookDeployment[] memory hooks = new HookDeployment[](len);
       address[] memory addresses = new address[](len);

       bytes memory routerArg = abi.encode(otherHooksConfiguration.odosRouterV3s[chainId]);

       hooks[0] = HookDeployment(
           SWAP_ODOSV3_HOOK_KEY,
           "",
           abi.encodePacked(__getOtherHooksBytecode("SwapOdosV3Hook", env), routerArg)
       );
       hooks[1] = HookDeployment(
           APPROVE_AND_SWAP_ODOSV3_HOOK_KEY,
           "",
           abi.encodePacked(__getOtherHooksBytecode("ApproveAndSwapOdosV3Hook", env), routerArg)
       );

       for (uint256 i = 0; i < len; ++i) {
           HookDeployment memory hook = hooks[i];
           string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
           addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
       }

       OdosV3HookAddresses memory hookAddresses;
       hookAddresses.swapOdosV3Hook = addresses[0];
       hookAddresses.approveAndSwapOdosV3Hook = addresses[1];

       require(hookAddresses.swapOdosV3Hook != address(0), "SwapOdosV3Hook not assigned");
       require(hookAddresses.approveAndSwapOdosV3Hook != address(0), "ApproveAndSwapOdosV3Hook not assigned");

       console2.log("All Odos V3 hooks deployed and validated successfully.");

       return hookAddresses;
   }
   ```

### Task 9: Modify `script/run/regenerate_bytecode.sh`

Add `SwapOdosV3Hook` and `ApproveAndSwapOdosV3Hook` to the `HOOK_CONTRACTS` array (after `ApproveAndSwapOdosV2Hook`):
```bash
"SwapOdosV3Hook"
"ApproveAndSwapOdosV3Hook"
```

Also add a new `ODOS_V3_HOOK_CONTRACTS` array for the `generated-bytecode-other/` directory:
```bash
ODOS_V3_HOOK_CONTRACTS=(
    "SwapOdosV3Hook"
    "ApproveAndSwapOdosV3Hook"
)
```

And add a copy loop for them (following the DETH_HOOK_CONTRACTS pattern).

### Task 10: Run `forge build` and Tests

- `forge build` to verify compilation
- `make forge-test-contract TEST-CONTRACT=OdosV3UnitTests` or equivalent to run the unit tests
- Verify all tests pass

---

## Important Gotchas and Warnings

### 1. FEE_DENOM is uint64, NOT uint256

The spec says `uint64 public constant FEE_DENOM = 1e18`. This fits in uint64 (max ~1.8e19 > 1e18). Do NOT use `uint256` for these constants -- they must match the router's actual types. The `MAX_REFERRAL_FEE` calculation `FEE_DENOM / 50` = `2e16` also fits in uint64.

### 2. bytes8 Encoding in Tests

When encoding `uint64` values in `bytes.concat`, use `bytes8(referralCode)` and `bytes8(referralFee)`. Solidity's `bytes.concat` does NOT accept `uint64` directly -- it must be cast to `bytes8`.

### 3. Do NOT Replicate V2 Test Phantom Padding

The V2 `_buildApproveAndSwapOdosData` helper includes `bytes20(address(0))` between the bool and pathDefinitionLength. This is incorrect for the actual hook data layout. The V3 helpers must NOT include this padding.

### 4. SwapOdosV3Hook Value Field

Same as V2: `value: inputToken == address(0) ? inputAmount : 0`. This is already handled in V2 SwapOdosV2Hook and works for native ETH swaps.

### 5. ApproveAndSwapOdosV3Hook Native ETH

The V2 `ApproveAndSwapOdosV2Hook` does NOT handle native ETH -- it always generates 4 executions. The V3 version adds native ETH support. When `inputToken == address(0)`:
- Generate only 1 execution (the swap call with `value: inputAmount`)
- Skip all 3 approve executions
- This means the `build()` function returns 3 executions total (pre + swap + post) for native, vs 6 (pre + approve(0) + approve(N) + swap + approve(0) + post) for ERC-20

### 6. test_Build Execution Count

Due to BaseHook's `build()` wrapping `_buildHookExecutions` with preExecute and postExecute:
- SwapOdosV3Hook: always 3 executions (pre + 1 inner + post)
- ApproveAndSwapOdosV3Hook with ERC-20 input: 6 executions (pre + 4 inner + post)
- ApproveAndSwapOdosV3Hook with native input: 3 executions (pre + 1 inner + post)

### 7. Deployment: OtherHooks, Not Core

The V3 hooks go in `DeployV2OtherHooks.s.sol`, NOT `DeployV2Core.s.sol`. The V2 hooks remain in Core for backward compatibility. The bytecode goes in `generated-bytecode-other/` directory.

### 8. inspect() Visibility

The `inspect()` function should be `pure` (not `view`) since it only decodes calldata using BytesLib, and does not access any immutable/storage variables. This matches the V2 pattern.

---

## File Summary

### New Files (5)
1. `src/vendor/odos/IOdosRouterV3.sol`
2. `src/hooks/swappers/odos/SwapOdosV3Hook.sol`
3. `src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol`
4. `test/mocks/MockOdosRouterV3.sol`
5. `test/unit/hooks/swappers/odos/OdosV3UnitTests.t.sol`

### Modified Files (4)
6. `script/utils/ConstantsOtherHooks.sol` -- add hook keys + router address
7. `script/utils/ConfigOtherHooks.sol` -- add V3 router mapping
8. `script/DeployV2OtherHooks.s.sol` -- add V3 deployment functions
9. `script/run/regenerate_bytecode.sh` -- add V3 hooks to bytecode generation
