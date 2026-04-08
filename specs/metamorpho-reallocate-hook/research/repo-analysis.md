# MetaMorpho Reallocate Hook - Repository Analysis

This document captures patterns, conventions, and reference implementations from the v2-core repository that should guide implementation of a NONACCOUNTING hook for MetaMorpho's `reallocate()` function.

---

## 1. NONACCOUNTING Hook Patterns

### 1.1 Simple NONACCOUNTING Hooks (Best Reference Models)

#### SetOperator7540Hook (`/src/hooks/vaults/7540/SetOperator7540Hook.sol`)

This is the closest analog to a MetaMorpho reallocate hook -- a management operation that does not affect accounting, with a simple data layout and no pre/post execute logic needed.

**Key characteristics:**
- HookType: `NONACCOUNTING`
- HookSubType: `HookSubTypes.ERC7540` (ours would be `HookSubTypes.MISC`)
- Uses the **standard header** with `bytes32 placeholder` + `address yieldSource`
- No `_preExecute` or `_postExecute` overrides (default no-ops from BaseHook)
- No `ISuperHookContextAware` interface (no `usePrevHookAmount`)
- Single Execution returned from `_buildHookExecutions()`

**Data layout:**
```
bytes32 placeholder    = data[0:32]    // bytes32 at offset 0
address vault          = data[32:52]   // address at offset 32 (extracted via HookDataDecoder.extractYieldSource)
address operator       = data[52:72]   // address at offset 52
bool    approved       = data[72]      // bool at offset 72
```

#### SetSlippageHook (`/src/hooks/vaults/7540/SetSlippageHook.sol`)

Another simple management NONACCOUNTING hook:

**Data layout:**
```
bytes32 placeholder    = data[0:32]
address vault          = data[32:52]   // uses extractYieldSource()
uint16  slippageBps    = data[52:54]
```

#### ApproveERC20Hook (`/src/hooks/tokens/erc20/ApproveERC20Hook.sol`)

Simple utility hook with `usePrevHookAmount` support:

**Data layout (NO standard header):**
```
address token              = data[0:20]
address spender            = data[20:40]
uint256 amount             = data[40:72]
bool    usePrevHookAmount  = data[72]
```

**Key observation:** Token hooks do NOT use the standard `bytes32 placeholder + address yieldSource` header. The header pattern is used when the hook needs to associate with a yield source for accounting.

#### NativeTransferHook (`/src/hooks/tokens/NativeTransferHook.sol`)

The simplest possible hook:
- No `_preExecute` or `_postExecute`
- No `ISuperHookContextAware`
- `_buildHookExecutions` is `pure` (not `view`)
- Minimal data: `address to (20 bytes) + uint256 amount (32 bytes)`

### 1.2 Standard Data Layout Header

Two patterns exist in the codebase:

**Pattern A: Standard Header (for yield-source-associated hooks)**
Used by: SpectraExchangeDepositHook, PendleUnifiedHook, SetOperator7540Hook, SetSlippageHook, MarkRootAsUsedHook

```
bytes32 placeholder        = data[0:32]     // HookDataDecoder.extractYieldSourceOracleId
address yieldSource        = data[32:52]    // HookDataDecoder.extractYieldSource
bool    usePrevHookAmount  = data[52]       // optional
uint256 value              = data[53:85]    // optional (for native ETH)
bytes   txData_            = data[85:]      // optional (variable-length)
```

The `HookDataDecoder` library provides:
- `extractYieldSourceOracleId(data)` -> `bytes32` from offset 0
- `extractYieldSource(data)` -> `address` from offset 32

**Pattern B: Direct encoding (for utility/token hooks)**
Used by: ApproveERC20Hook, TransferERC20Hook, Swap1InchHook, SwapKyberSwapHook

No standard header. Fields packed directly from offset 0.

**For MetaMorpho Reallocate:** Pattern A is recommended since the MetaMorpho vault address fits naturally into the `yieldSource` position at offset 32, and the `placeholder` bytes32 at offset 0 is available for the oracle ID.

---

## 2. Complex Hooks with Variable-Length Data

### 2.1 BatchTransferHook (`/src/hooks/tokens/BatchTransferHook.sol`)

Handles variable-length arrays using `abi.decode` on a tail portion:

```solidity
address to = BytesLib.toAddress(data, 0);
bytes memory tokensData = BytesLib.slice(data, 20, data.length - 20);
(address[] memory tokens, uint256[] memory amounts) = abi.decode(tokensData, (address[], uint256[]));
```

**Pattern:** Fixed fields at known offsets, then ABI-encoded variable-length data as the remainder.

**Test encoding:**
```solidity
function _encodeData(address[] memory tokens, uint256[] memory amounts) internal view returns (bytes memory) {
    bytes memory tokensData = abi.encode(tokens, amounts);
    return abi.encodePacked(to, tokensData);
}
```

### 2.2 MarkRootAsUsedHook (`/src/hooks/superform/MarkRootAsUsedHook.sol`)

Handles a variable-length `bytes32[]` array:

```solidity
address destinationExecutor = data.extractYieldSource();  // offset 32
bytes memory merkleRootData = BytesLib.slice(data, 52, data.length - 52);
bytes32[] memory merkleRoots = abi.decode(merkleRootData, (bytes32[]));
```

**Pattern:** Standard header (placeholder + yieldSource), then ABI-encoded array as tail data starting at offset 52.

### 2.3 SpectraExchangeDepositHook (`/src/hooks/swappers/spectra/SpectraExchangeDepositHook.sol`)

Handles complex router calldata with full selector-based dispatch:

```
bytes32 placeholder = data[0:32]
address yieldSource = data[32:52]
bool    usePrev     = data[52]
uint256 value       = data[53:85]
bytes   txData_     = data[85:]     // Entire ABI-encoded function call
```

Uses `abi.decode` on the txData_ portion after extracting the selector.

### 2.4 SwapKyberSwapHook - Length-Prefixed Variable Data

Uses an explicit length field before the variable-length data:

```
address outputToken    = data[0:20]
uint256 value          = data[20:52]
uint256 inputAmount    = data[52:84]
uint256 outputMin      = data[84:116]
bool    usePrevHook    = data[116]
uint256 txDataLength   = data[117:149]
bytes   txData_        = data[149:149+txDataLength]
```

### 2.5 Recommended Pattern for Reallocate Hook

Since `reallocate()` takes `MarketAllocation[]` which is a variable-length array of structs, the most appropriate pattern is the **MarkRootAsUsedHook** approach:

```
bytes32 placeholder         = data[0:32]       // oracle/yield source ID
address metaMorphoVault     = data[32:52]      // extractYieldSource()
bytes   allocationsData     = data[52:]        // abi.encode(MarketAllocation[])
```

Then in `_buildHookExecutions`:
```solidity
address vault = data.extractYieldSource();
bytes memory allocationsData = BytesLib.slice(data, 52, data.length - 52);
MarketAllocation[] memory allocations = abi.decode(allocationsData, (MarketAllocation[]));
```

---

## 3. Morpho Vendor Code and Existing Hooks

### 3.1 Existing Vendor Interfaces (`/src/vendor/morpho/`)

| File | Contents |
|------|----------|
| `IMorpho.sol` | `MarketParams`, `Position`, `Market`, `IMorphoBase`, `IMorpho` interfaces |
| `MarketParamsLib.sol` | Library for computing market `Id` from `MarketParams` |
| `IIrm.sol` | Interest rate model interface |
| `IOracle.sol` | Oracle price interface |
| `MathLib.sol` | Math utilities |
| `SharesMathLib.sol` | Shares-to-assets conversion math |

**MarketParams struct** (already vendored):
```solidity
struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}
```

### 3.2 Missing Vendor Interface

**MetaMorpho interface is NOT vendored yet.** We need to create a minimal interface file:

```solidity
// src/vendor/morpho/IMetaMorpho.sol
struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;
}

interface IMetaMorpho {
    function reallocate(MarketAllocation[] calldata allocations) external;
}
```

The `MarketAllocation` struct and `reallocate()` function signature must come from the MetaMorpho contract (not Morpho Blue).

### 3.3 Existing Morpho Loan Hooks Pattern (`/src/hooks/loan/morpho/`)

The existing Morpho loan hooks use a different approach:
- They inherit from `BaseLoanHook` -> `BaseHook`
- They use the **Pattern B** data layout (no standard header)
- MarketParams fields are encoded individually using BytesLib at fixed offsets
- They take the `morpho` address as a **constructor parameter** (immutable)

**Data layout for MorphoSupplyHook:**
```
address loanToken          = data[0:20]
address collateralToken    = data[20:40]
address oracle             = data[40:60]
address irm                = data[60:80]
uint256 amount             = data[80:112]
uint256 lltv               = data[112:144]
bool    usePrevHookAmount  = data[144]
```

**Key difference for our hook:** The Morpho loan hooks encode each MarketParams field individually because they operate on a single market. Our reallocate hook operates on an **array** of `MarketAllocation` structs, so individual field encoding does not scale. The ABI-encoded array approach (Pattern from MarkRootAsUsedHook/BatchTransferHook) is more appropriate.

---

## 4. Hook Registration and Deployment

### 4.1 Deployment Script Patterns

**Core hooks** are deployed in `/script/DeployV2Core.s.sol` function `_deployHooks()`.

**Non-core hooks** (claim, stake, Spectra, Morpho loan) are deployed in `/script/DeployV2OtherHooks.s.sol`.

The deployment uses a `HookDeployment` struct:
```solidity
struct HookDeployment {
    string name;           // Key name like "MetaMorphoReallocateHook"
    string saltOverride;   // Optional custom salt
    bytes creationCode;    // Bytecode, optionally with encoded constructor args
}
```

**Without constructor args:**
```solidity
hooks[0] = HookDeployment(KEY, "", __getOtherHooksBytecode("ContractName", env));
```

**With constructor args:**
```solidity
hooks[11] = HookDeployment(
    MORPHO_SUPPLY_AND_BORROW_HOOK_KEY,
    "",
    abi.encodePacked(
        __getOtherHooksBytecode("MorphoSupplyAndBorrowHook", env),
        abi.encode(otherHooksConfiguration.morphos[chainId])
    )
);
```

**For a hook with no constructor args (like our reallocate hook):**
```solidity
hooks[N] = HookDeployment(KEY, "", __getOtherHooksBytecode("MetaMorphoReallocateHook", env));
```

### 4.2 Contract Key Constants

Hook keys are defined as string constants in deployment config files:
```solidity
string constant MORPHO_SUPPLY_AND_BORROW_HOOK_KEY = "MorphoSupplyAndBorrowHook";
```

### 4.3 Bytecode Locking

Production deployments use locked bytecode from `script/locked-bytecode-other/`.
Dev/vnet deployments use `script/generated-bytecode-other/`.

---

## 5. Test Patterns for NONACCOUNTING Hooks

### 5.1 Standard Test Structure

From `SetOperator7540Hook.t.sol` (most relevant reference):

```solidity
contract SetOperator7540HookTest is Helpers {
    SetOperator7540Hook public hook;

    function setUp() public {
        hook = new SetOperator7540Hook();
    }

    // 1. Constructor verification
    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(hook.SUB_TYPE()), uint256(HookSubTypes.ERC7540));
    }

    // 2. Build with valid data
    function test_Build_ApproveOperator() public {
        bytes memory data = _encodeData(vault, operator, true);
        Execution[] memory executions = hook.build(address(0), address(0), data);
        assertEq(executions.length, 3); // pre + hook + post
        assertEq(executions[1].target, vault);
        assertEq(executions[1].callData, expectedCalldata);
    }

    // 3. Revert on invalid input
    function test_Build_RevertIf_ZeroVault() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    // 4. Inspect function
    function test_Inspector() public {
        bytes memory inspectionResult = hook.inspect(data);
        assertEq(BytesLib.toAddress(inspectionResult, 0), vault);
    }

    // 5. Data encoding verification
    function test_DataEncodingDecoding() public {
        assertEq(data.length, 73); // 32 + 20 + 20 + 1
        assertEq(BytesLib.toAddress(data, 32), vault);
    }

    // 6. Fuzz testing
    function testFuzz_Build(address vault, address operator, bool approved) public {
        vm.assume(vault != address(0));
        vm.assume(operator != address(0));
        // ...
    }

    // 7. Helper encoding function
    function _encodeData(address vault, address operator, bool approved)
        internal pure returns (bytes memory)
    {
        bytes memory placeholder = new bytes(32);
        return bytes.concat(
            placeholder,
            abi.encodePacked(vault),
            abi.encodePacked(operator),
            abi.encodePacked(approved ? uint8(1) : uint8(0))
        );
    }
}
```

### 5.2 Test Import Pattern

```solidity
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook } from "src/interfaces/ISuperHook.sol";
import { BaseHook } from "src/hooks/BaseHook.sol";
import { Helpers } from "test/utils/Helpers.sol";
import { BytesLib } from "src/vendor/BytesLib.sol";
import { HookSubTypes } from "src/libraries/HookSubTypes.sol";
```

### 5.3 Execution Count Convention

For `build()` the BaseHook wraps `_buildHookExecutions()` with preExecute + postExecute:
- `build()` returns `_buildHookExecutions().length + 2`
- `executions[0]` = preExecute call
- `executions[1..N]` = hook-specific operations
- `executions[last]` = postExecute call

So if `_buildHookExecutions` returns 1 execution, `build()` returns 3.

### 5.4 Morpho Test Mock Pattern

From `MorphoLoanHooks.t.sol`:
```solidity
contract MockMorpho {
    // Minimal mock implementing only needed functions
    function supplyCollateral(...) external { ... }
    function borrow(...) external { ... }
}
```

For our hook, we would need:
```solidity
contract MockMetaMorpho {
    MarketAllocation[] public lastAllocations;

    function reallocate(MarketAllocation[] calldata allocations) external {
        delete lastAllocations;
        for (uint256 i; i < allocations.length; i++) {
            lastAllocations.push(allocations[i]);
        }
    }
}
```

---

## 6. Inspect Pattern

The `inspect()` function returns a packed bytes representation of the hook's "inspectable" parameters. It is used by off-chain tooling to understand what a hook's data targets.

### 6.1 Common Patterns

**Return yieldSource only (for simple hooks):**
```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    return abi.encodePacked(data.extractYieldSource());
}
```
Used by: SetOperator7540Hook, SetSlippageHook, MarkRootAsUsedHook, SpectraExchangeDepositHook

**Return multiple fixed addresses:**
```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    return abi.encodePacked(
        BytesLib.toAddress(data, 0),  // token
        BytesLib.toAddress(data, 20)  // spender
    );
}
```
Used by: ApproveERC20Hook, TransferERC20Hook

**For our reallocate hook:** Returning just the MetaMorpho vault address is sufficient:
```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    return abi.encodePacked(data.extractYieldSource());
}
```

---

## 7. HookSubType Selection

From `/src/libraries/HookSubTypes.sol`, the available subtypes are:

| Constant | Value | Used By |
|----------|-------|---------|
| `BRIDGE` | keccak256("Bridge") | Bridge hooks |
| `CLAIM` | keccak256("Claim") | Reward claim hooks |
| `ERC4626` | keccak256("ERC4626") | ERC-4626 vault hooks |
| `ERC5115` | keccak256("ERC5115") | ERC-5115 vault hooks |
| `ERC7540` | keccak256("ERC7540") | ERC-7540 vault hooks |
| `LOAN` | keccak256("Loan") | Morpho loan supply/borrow |
| `LOAN_REPAY` | keccak256("LoanRepay") | Morpho loan repay |
| `MISC` | keccak256("Misc") | MarkRootAsUsedHook |
| `STAKE` | keccak256("Stake") | Staking hooks |
| `SWAP` | keccak256("Swap") | Swap hooks |
| `TOKEN` | keccak256("Token") | ERC-20 utility hooks |
| `UNSTAKE` | keccak256("Unstake") | Unstaking hooks |
| `PTYT` | keccak256("PTYT") | Pendle/Spectra hooks |
| `VAULT_BANK` | keccak256("VaultBank") | SuperPositions hooks |

**For MetaMorpho Reallocate:** `HookSubTypes.MISC` is the appropriate choice, consistent with MarkRootAsUsedHook which is also a management/utility operation.

---

## 8. Summary: Recommended Implementation Blueprint

### File Structure

```
src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol
src/vendor/morpho/IMetaMorpho.sol
test/unit/hooks/vaults/metamorpho/MetaMorphoReallocateHook.t.sol
```

### Hook Contract Skeleton

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { MarketParams } from "../../../vendor/morpho/IMorpho.sol";
import { IMetaMorpho, MarketAllocation } from "../../../vendor/morpho/IMetaMorpho.sol";

/// @title MetaMorphoReallocateHook
/// @author Superform Labs
/// @notice NONACCOUNTING hook for calling MetaMorpho's reallocate() function
/// @dev data has the following structure:
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32));
/// @notice         address metaMorphoVault = BytesLib.toAddress(data, 32);
/// @notice         bytes allocationsData = BytesLib.slice(data, 52, data.length - 52);
///                 where allocationsData = abi.encode(MarketAllocation[])
contract MetaMorphoReallocateHook is BaseHook {
    using HookDataDecoder for bytes;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) { }

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
        address vault = data.extractYieldSource();
        if (vault == address(0)) revert ADDRESS_NOT_VALID();

        bytes memory allocationsData = BytesLib.slice(data, 52, data.length - 52);
        MarketAllocation[] memory allocations = abi.decode(allocationsData, (MarketAllocation[]));
        if (allocations.length == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(IMetaMorpho.reallocate, (allocations))
        });
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }
}
```

### Key Design Decisions Supported by Evidence

1. **No constructor args** - The MetaMorpho vault address is in hook data (like SetOperator7540Hook), not immutable. This allows one deployment to serve all MetaMorpho vaults.

2. **No `_preExecute`/`_postExecute`** - Reallocate is net-zero, so no balance tracking needed. Matches SetOperator7540Hook pattern.

3. **No `usePrevHookAmount`** - Reallocate does not take a single amount input; it takes a complex array. The interview notes mention it as optional, but it adds significant complexity for minimal value.

4. **Standard header** (bytes32 placeholder + address yieldSource at offset 32) - Matches the yield-source-associated hook pattern.

5. **ABI-encoded array as tail data** - Follows MarkRootAsUsedHook and BatchTransferHook patterns for variable-length data.

6. **`HookSubTypes.MISC`** - Management operation, consistent with MarkRootAsUsedHook.

7. **`_buildHookExecutions` is `pure`** - No state reads needed (matches SetSlippageHook, MarkRootAsUsedHook).

---

## 9. Reference File Paths

### Core Architecture
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/BaseHook.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/interfaces/ISuperHook.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/libraries/HookSubTypes.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/libraries/HookDataDecoder.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/BytesLib.sol`

### Best Reference Hooks (ordered by relevance)
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/vaults/7540/SetOperator7540Hook.sol` -- Simple NONACCOUNTING, standard header, management operation
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/superform/MarkRootAsUsedHook.sol` -- NONACCOUNTING + variable-length array data
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/tokens/BatchTransferHook.sol` -- Variable-length array decoding pattern
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/vaults/7540/SetSlippageHook.sol` -- Simple management hook
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/tokens/erc20/ApproveERC20Hook.sol` -- usePrevHookAmount pattern

### Morpho Vendor Code
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/morpho/IMorpho.sol` -- MarketParams struct
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/morpho/MarketParamsLib.sol` -- Market ID computation
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/loan/morpho/BaseMorphoLoanHook.sol` -- Existing Morpho hook base
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/loan/morpho/MorphoSupplyHook.sol` -- Morpho hook implementation

### Deployment
- `/Users/cosming/1.Coding/Superform/v2-core/script/DeployV2OtherHooks.s.sol` -- Where non-core hooks are deployed
- `/Users/cosming/1.Coding/Superform/v2-core/script/DeployV2Core.s.sol` -- Core hook deployment reference

### Tests
- `/Users/cosming/1.Coding/Superform/v2-core/test/unit/hooks/vaults/7540/SetOperator7540Hook.t.sol` -- Best test reference
- `/Users/cosming/1.Coding/Superform/v2-core/test/unit/hooks/tokens/BatchTransferHook.t.sol` -- Array data test reference
- `/Users/cosming/1.Coding/Superform/v2-core/test/unit/hooks/superform/MarkRootAsUsedHook.t.sol` -- Management hook test
- `/Users/cosming/1.Coding/Superform/v2-core/test/unit/hooks/loan/MorphoLoanHooks.t.sol` -- Morpho mock pattern
- `/Users/cosming/1.Coding/Superform/v2-core/test/unit/hooks/tokens/erc20/ApproveERC20Hook.t.sol` -- Simple hook test
- `/Users/cosming/1.Coding/Superform/v2-core/test/mocks/MockHook.sol` -- Mock hook for prevHook testing
- `/Users/cosming/1.Coding/Superform/v2-core/test/utils/Helpers.sol` -- Base test helpers

### Existing Specs
- `/Users/cosming/1.Coding/Superform/v2-core/specs/metamorpho-reallocate-hook/interview-notes.md` -- Feature requirements
