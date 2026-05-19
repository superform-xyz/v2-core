# Stargate Native Fee Sponsorship - Implementation Plan

## Status: Ready for Review

## Overview

Three on-chain components enabling bundler-sponsored native ETH for Stargate V2 LayerZero messaging fees:
1. **NativeFeeSponsorship** - Standalone ledger contract holding sponsored native ETH
2. **SuperNativePaymaster modification** - New `sponsorNativeAndHandleUserOp` function
3. **FetchNativeFeeHook** - NONACCOUNTING hook for smart account to withdraw sponsored ETH

---

## File-by-File Breakdown

### NEW FILES

---

### 1. `src/interfaces/INativeFeeSponsorship.sol` (NEW)

**Purpose**: Interface for the NativeFeeSponsorship ledger contract.

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

interface INativeFeeSponsorship {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error ZERO_AMOUNT();
    error INSUFFICIENT_SPONSORED_BALANCE();
    error ETH_TRANSFER_FAILED();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event NativeDeposited(address indexed sponsor, address indexed account, uint256 amount);
    event NativeWithdrawnByAccount(address indexed sponsor, address indexed account, uint256 amount);
    event NativeWithdrawnBySponsor(address indexed sponsor, address indexed account, address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit native ETH for a smart account, keyed by sponsor
    /// @param sponsor The address of the sponsor (typically the bundler)
    /// @param account The smart account that can withdraw these funds
    function depositForAccount(address sponsor, address account) external payable;

    /// @notice Account (msg.sender) withdraws sponsored native ETH
    /// @param sponsor The sponsor whose deposit to withdraw from
    /// @param amount The amount of native ETH to withdraw
    function withdrawSponsoredNative(address sponsor, uint256 amount) external;

    /// @notice Sponsor (msg.sender) reclaims unused deposit
    /// @param account The account whose allocation to reclaim from
    /// @param to The address to send reclaimed ETH to
    /// @param amount The amount to reclaim
    function withdrawSponsorDeposit(address account, address payable to, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the sponsored amount for a given sponsor-account pair
    /// @param sponsor The sponsor address
    /// @param account The account address
    /// @return The amount of native ETH sponsored
    function sponsoredAmount(address sponsor, address account) external view returns (uint256);
}
```

**Key design decisions**:
- Custom errors following Superform naming convention (UPPER_SNAKE_CASE)
- Events for all state-changing operations (deposit, account withdrawal, sponsor reclaim)
- `depositForAccount` takes explicit `sponsor` parameter (not msg.sender) because the paymaster calls it on behalf of the bundler
- `withdrawSponsoredNative` uses msg.sender as the account (the smart account calls this via hook execution)
- `withdrawSponsorDeposit` uses msg.sender as the sponsor

---

### 2. `src/sponsorship/NativeFeeSponsorship.sol` (NEW)

**Purpose**: Standalone ledger contract holding ETH deposits keyed by `mapping(sponsor => mapping(account => amount))`.

**Directory**: Create `src/sponsorship/` as a new top-level directory. This is NOT a hook, NOT a paymaster -- it is a standalone utility contract. Placing it under `src/sponsorship/` keeps the architecture clean. The other option would be `src/paymaster/NativeFeeSponsorship.sol` but since the paymaster and sponsorship are separate concerns, a new directory is cleaner.

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { INativeFeeSponsorship } from "../interfaces/INativeFeeSponsorship.sol";

/// @title NativeFeeSponsorship
/// @author Superform Labs
/// @notice Ledger contract for sponsoring native ETH for smart account operations (e.g., Stargate messaging fees)
/// @dev Open balance model: no signatures or nonces. Sponsors deposit ETH keyed by (sponsor, account),
///      and smart accounts withdraw via hooks. Sponsors can reclaim unused deposits.
contract NativeFeeSponsorship is INativeFeeSponsorship, ReentrancyGuard {

    mapping(address sponsor => mapping(address account => uint256 amount)) public sponsoredNative;

    /// @inheritdoc INativeFeeSponsorship
    function depositForAccount(address sponsor, address account) external payable nonReentrant {
        if (sponsor == address(0)) revert ZERO_ADDRESS();
        if (account == address(0)) revert ZERO_ADDRESS();
        if (msg.value == 0) revert ZERO_AMOUNT();

        sponsoredNative[sponsor][account] += msg.value;

        emit NativeDeposited(sponsor, account, msg.value);
    }

    /// @inheritdoc INativeFeeSponsorship
    function withdrawSponsoredNative(address sponsor, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();

        uint256 available = sponsoredNative[sponsor][msg.sender];
        if (available < amount) revert INSUFFICIENT_SPONSORED_BALANCE();

        sponsoredNative[sponsor][msg.sender] = available - amount;

        (bool success,) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert ETH_TRANSFER_FAILED();

        emit NativeWithdrawnByAccount(sponsor, msg.sender, amount);
    }

    /// @inheritdoc INativeFeeSponsorship
    function withdrawSponsorDeposit(address account, address payable to, uint256 amount) external nonReentrant {
        if (account == address(0)) revert ZERO_ADDRESS();
        if (to == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();

        uint256 available = sponsoredNative[msg.sender][account];
        if (available < amount) revert INSUFFICIENT_SPONSORED_BALANCE();

        sponsoredNative[msg.sender][account] = available - amount;

        (bool success,) = to.call{ value: amount }("");
        if (!success) revert ETH_TRANSFER_FAILED();

        emit NativeWithdrawnBySponsor(msg.sender, account, to, amount);
    }

    /// @inheritdoc INativeFeeSponsorship
    function sponsoredAmount(address sponsor, address account) external view returns (uint256) {
        return sponsoredNative[sponsor][account];
    }
}
```

**Critical implementation notes**:
- `nonReentrant` on ALL mutating functions (security requirement from spec)
- Checks-Effects-Interactions pattern: validate, update state, THEN transfer ETH
- `depositForAccount` takes explicit `sponsor` param (not `msg.sender`) because the paymaster contract calls this on behalf of the bundler. The paymaster receives ETH from the bundler and forwards it, so `msg.sender` would be the paymaster, not the bundler. The sponsor param allows correct attribution.
- No constructor arguments needed -- this is a pure ledger contract
- The `sponsoredNative` mapping is public (auto-generates a getter), but we also provide the explicit `sponsoredAmount` function to match the interface
- No access control / roles needed -- open balance model as per spec

**Security considerations**:
- Race condition between sponsor reclaim and account withdrawal is an accepted tradeoff (spec acknowledges this)
- If hook withdraws more than Stargate needs, excess stays on smart account (not recoverable by bundler -- accepted tradeoff)
- No overflow risk on `sponsoredNative` due to Solidity 0.8.30 checked math

---

### 3. `src/hooks/sponsorship/FetchNativeFeeHook.sol` (NEW)

**Purpose**: NONACCOUNTING hook that the smart account executes to withdraw sponsored native ETH from NativeFeeSponsorship. This hook is placed BEFORE the Stargate bridge hook in the execution chain.

**Directory**: Create `src/hooks/sponsorship/` as a new hook category.

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { INativeFeeSponsorship } from "../../interfaces/INativeFeeSponsorship.sol";

/// @title FetchNativeFeeHook
/// @author Superform Labs
/// @notice Withdraws sponsored native ETH from NativeFeeSponsorship before bridge operations
/// @dev Designed to be placed immediately before a Stargate bridge hook in the execution chain
/// @dev data has the following structure
/// @notice         address sponsor = BytesLib.toAddress(data, 0);
/// @notice         uint256 amount = BytesLib.toUint256(data, 20);
contract FetchNativeFeeHook is BaseHook {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_DATA_LENGTH();

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The NativeFeeSponsorship ledger contract
    address public immutable SPONSORSHIP;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant SPONSOR_POSITION = 0;
    uint256 private constant AMOUNT_POSITION = 20;
    uint256 private constant MIN_DATA_LENGTH = 52; // 20 (address) + 32 (uint256)

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address sponsorship_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {
        if (sponsorship_ == address(0)) revert ADDRESS_NOT_VALID();
        SPONSORSHIP = sponsorship_;
    }

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
        view
        override
        returns (Execution[] memory executions)
    {
        // 1. Validate minimum data length
        if (data.length < MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        // 2. Decode hook data
        address sponsor = BytesLib.toAddress(data, SPONSOR_POSITION);
        uint256 amount = BytesLib.toUint256(data, AMOUNT_POSITION);

        // 3. Validate
        if (sponsor == address(0)) revert ADDRESS_NOT_VALID();
        if (amount == 0) revert AMOUNT_NOT_VALID();

        // 4. Build single withdrawal execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: SPONSORSHIP,
            value: 0,
            callData: abi.encodeCall(INativeFeeSponsorship.withdrawSponsoredNative, (sponsor, amount))
        });
    }

    /// @inheritdoc BaseHook
    /// @dev PROTOCOL REQUIREMENT: Inspector functions MUST only return addresses
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return abi.encodePacked(SPONSORSHIP);
    }
}
```

**Key design decisions**:

1. **HookSubType = TOKEN**: Using `HookSubTypes.TOKEN` since this is a native ETH token operation, similar to `NativeTransferHook`. There is no existing `SPONSORSHIP` subtype, and adding a new one is unnecessary for MVP.

2. **Immutable SPONSORSHIP address**: The sponsorship contract address is an immutable constructor parameter (not in hook data). This follows the pattern used by `ClaimRFLRHook` with `RNAT` and `AcrossSendFundsAndExecuteOnDstHook` with `SPOKE_POOL_V3`. This is critical for multi-chain deployment flexibility.

3. **No preExecute/postExecute overrides needed**: This is a simple withdrawal hook. The base class default no-ops are sufficient. We do NOT need to track balance deltas because:
   - The hook is NONACCOUNTING (no accounting impact)
   - The withdrawn ETH stays on the smart account for the subsequent Stargate hook to use
   - The `outAmount` is not consumed by downstream hooks (Stargate hook uses its own `value` field)

4. **Data layout is simple**: Only 2 fields (sponsor + amount = 52 bytes). No `usePrevHookAmount` since the amount is always a fixed messaging fee determined off-chain by `quoteSend`.

5. **Inspector returns SPONSORSHIP address only**: Following the PROTOCOL REQUIREMENT that inspector functions only return addresses.

6. **No preExecute validation of sponsorship address against immutable**: The original spec suggested validating `data.sponsorship == EXPECTED_SPONSORSHIP` in preExecute. However, since we made SPONSORSHIP an immutable constructor parameter and the `_buildHookExecutions` already targets the immutable SPONSORSHIP address, there's no way for the execution to target a different contract. The hook data does NOT contain a sponsorship address -- the target is hardcoded via the immutable. This is more secure than allowing the data to specify the target.

---

### MODIFIED FILES

---

### 4. `src/interfaces/ISuperNativePaymaster.sol` (MODIFY)

**Changes**: Add the new function signature and associated errors/events.

Add these to the ERRORS section:
```solidity
/// @notice Thrown when the native amount exceeds msg.value
error NATIVE_AMOUNT_EXCEEDS_VALUE();

/// @notice Thrown when the handleOps call fails
error HANDLE_OPS_FAILED();

/// @notice Thrown when the sponsorship contract address is zero
error INVALID_SPONSORSHIP();
```

Add this to the EVENTS section:
```solidity
/// @notice Emitted when native fee sponsorship and UserOp handling completes
/// @param sponsor The bundler/sponsor address
/// @param account The smart account address
/// @param nativeAmount The native ETH deposited for messaging fees
/// @param gasAmount The ETH used for gas funding
event SponsorNativeAndHandleOp(
    address indexed sponsor,
    address indexed account,
    uint256 nativeAmount,
    uint256 gasAmount
);
```

Add this to the EXTERNAL METHODS section:
```solidity
/// @notice Deposit native ETH for messaging fees and execute a UserOp atomically
/// @dev Splits msg.value into nativeAmount (for sponsorship) and remainder (for gas)
/// @param op The packed user operation to execute
/// @param nativeAmount The amount of native ETH to deposit into NativeFeeSponsorship for op.sender
function sponsorNativeAndHandleUserOp(
    PackedUserOperation calldata op,
    uint256 nativeAmount
) external payable;
```

---

### 5. `src/paymaster/SuperNativePaymaster.sol` (MODIFY)

**Changes**: Add immutable SPONSORSHIP reference and new `sponsorNativeAndHandleUserOp` function.

**Add import**:
```solidity
import { INativeFeeSponsorship } from "../interfaces/INativeFeeSponsorship.sol";
```

**Add state variable** (after the `MAX_NODE_OPERATOR_PREMIUM` constant):
```solidity
/// @notice The NativeFeeSponsorship contract for messaging fee deposits
/// @dev Set to address(0) if sponsorship is not needed on this chain
INativeFeeSponsorship public immutable SPONSORSHIP;
```

**CRITICAL: Modify the constructor**:
```solidity
constructor(
    IEntryPoint _entryPoint,
    INativeFeeSponsorship _sponsorship
) payable BasePaymaster(_entryPoint) {
    SPONSORSHIP = _sponsorship;
}
```

**IMPORTANT NOTE on constructor change**: The current constructor only takes `IEntryPoint`. Adding `INativeFeeSponsorship` as a second parameter is a BREAKING CHANGE to the constructor signature. This means:
- The deployment script MUST be updated to pass the new parameter
- The locked bytecode will change
- All chains need redeployment of the paymaster OR we need to use a different approach

**ALTERNATIVE (Non-breaking approach)**: If we want to avoid redeploying the paymaster on all chains, we could:
- Deploy NativeFeeSponsorship as a standalone contract
- Pass the sponsorship address as a parameter in `sponsorNativeAndHandleUserOp` instead of using an immutable
- This avoids constructor changes but adds a parameter to the function

**RECOMMENDED**: Use the constructor approach (immutable) for gas efficiency and security, but this requires redeployment. The team should decide based on deployment timeline. For this plan, we proceed with the immutable approach.

**Add the new function** (after `handleOps`):
```solidity
/// @inheritdoc ISuperNativePaymaster
function sponsorNativeAndHandleUserOp(
    PackedUserOperation calldata op,
    uint256 nativeAmount
) external payable {
    // 1. Validate
    if (nativeAmount > msg.value) revert NATIVE_AMOUNT_EXCEEDS_VALUE();
    if (address(SPONSORSHIP) == address(0)) revert INVALID_SPONSORSHIP();

    // 2. Deposit native amount into sponsorship for the smart account
    //    msg.sender is the bundler (sponsor), op.sender is the smart account
    SPONSORSHIP.depositForAccount{ value: nativeAmount }(msg.sender, op.sender());

    // 3. Forward remaining ETH for gas funding (existing handleOps flow)
    uint256 gasAmount = msg.value - nativeAmount;

    // Deposit gas funds to EntryPoint
    if (gasAmount > 0) {
        (bool depositSuccess,) = payable(address(entryPoint)).call{ value: gasAmount }("");
        if (!depositSuccess) revert INSUFFICIENT_BALANCE();
    }

    // 4. Create single-op array and call handleOps
    PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    ops[0] = op;

    // NOTE: entryPoint.handleOps reverts on failure, so no try/catch needed.
    // If the UserOp fails, the entire transaction reverts, including the sponsorship deposit.
    // This provides atomicity -- no orphaned sponsorship.
    entryPoint.handleOps(ops, payable(msg.sender));

    // 5. Withdraw remaining deposit back to bundler
    uint256 withdrawnAmount = entryPoint.getDepositInfo(address(this)).deposit;
    if (withdrawnAmount > 0) {
        entryPoint.withdrawTo(payable(msg.sender), withdrawnAmount);
    }

    emit SponsorNativeAndHandleOp(msg.sender, op.sender(), nativeAmount, gasAmount);
}
```

**CRITICAL atomicity note**: `entryPoint.handleOps` reverts the entire transaction if the UserOp fails. This means the `SPONSORSHIP.depositForAccount` call is also reverted, providing the atomicity guarantee from the spec ("must hard-revert if handleOps fails"). No try/catch or manual revert is needed.

**Important note on `op.sender()`**: The `PackedUserOperation` struct has a `sender` field. When using `calldata`, access it via `op.sender`. When using `memory`, the UserOperationLib provides `op.sender()` method. Since the function parameter uses `calldata`, direct field access `op.sender` should work. However, check the actual struct definition -- the existing `handleOps` function uses `ops` as `calldata` and the codebase imports `UserOperationLib`. The `op.sender` is the raw field access for `PackedUserOperation.sender`. Verify this compiles correctly.

---

### 6. `src/libraries/HookSubTypes.sol` (NO CHANGE)

We reuse `HookSubTypes.TOKEN` for the FetchNativeFeeHook. No new subtype needed for MVP.

---

### DEPLOYMENT FILES

---

### 7. `script/utils/ConstantsOtherHooks.sol` (MODIFY)

Add hook key constant:
```solidity
// Native Fee Sponsorship hook keys
string internal constant FETCH_NATIVE_FEE_HOOK_KEY = "FetchNativeFeeHook";

// Native Fee Sponsorship contract key
string internal constant NATIVE_FEE_SPONSORSHIP_KEY = "NativeFeeSponsorship";
```

---

### 8. `script/DeployV2OtherHooks.s.sol` (MODIFY)

**Add struct**:
```solidity
struct NativeFeeSponsorshipAddresses {
    address nativeFeeSponsorship;
    address fetchNativeFeeHook;
}
```

**Add deployment function**:
```solidity
function runNativeFeeSponsorship(uint256 env, uint64 chainId) public broadcast(env) {
    _setConfiguration(env, "");
    console2.log("Deploying Native Fee Sponsorship on chainId: ", chainId);
    _deployNativeFeeSponsorshipContracts(chainId, env);
    _writeExportedContracts(chainId);
}
```

**Add internal deployment logic**:
```solidity
function _deployNativeFeeSponsorshipContracts(
    uint64 chainId,
    uint256 env
) internal returns (NativeFeeSponsorshipAddresses memory) {
    // Step 1: Deploy NativeFeeSponsorship (no constructor args)
    // This is NOT a hook, it's a standalone contract. Deploy it directly.
    address sponsorshipAddr = _deploySingleContract(
        NATIVE_FEE_SPONSORSHIP_KEY,
        __getOtherHooksBytecode("NativeFeeSponsorship", env)
    );

    // Step 2: Deploy FetchNativeFeeHook (constructor arg: sponsorship address)
    uint256 len = 1;
    HookDeployment[] memory hooks = new HookDeployment[](len);

    hooks[0] = HookDeployment(
        FETCH_NATIVE_FEE_HOOK_KEY,
        "",
        abi.encodePacked(
            __getOtherHooksBytecode("FetchNativeFeeHook", env),
            abi.encode(sponsorshipAddr)
        )
    );

    address[] memory addresses = _deployHookBatch(hooks);

    NativeFeeSponsorshipAddresses memory result;
    result.nativeFeeSponsorship = sponsorshipAddr;
    result.fetchNativeFeeHook = addresses[0];

    require(result.nativeFeeSponsorship != address(0), "NativeFeeSponsorship not deployed");
    require(result.fetchNativeFeeHook != address(0), "FetchNativeFeeHook not deployed");

    console2.log("Native Fee Sponsorship contracts deployed successfully.");
    return result;
}
```

**IMPORTANT NOTE**: The `_deploySingleContract` and `_deployHookBatch` helper names above are illustrative. The actual deployment should follow the existing patterns in `DeployV2OtherHooks.s.sol`. Look at how `_deployRFLRHooks` works:
- It creates a `HookDeployment[]` array
- It calls `_deployWithFactory` or similar from the base
- It maps the returned addresses to the struct

The NativeFeeSponsorship contract is NOT a hook but needs deployment too. Check how the base deployment script handles non-hook contracts (look at `_deploySingle` or similar in `DeployV2Base.s.sol`). If there's no existing pattern for deploying non-hook contracts in OtherHooks, you may need to add the sponsorship as a separate deployment or adapt the hook deployment machinery to handle it.

**Alternative approach**: Deploy NativeFeeSponsorship as a 0th element in the HookDeployment array (even though it's not technically a hook, the deployment machinery just deploys bytecode and returns addresses). This is simpler:

```solidity
function _deployNativeFeeSponsorshipContracts(
    uint64 chainId,
    uint256 env
) internal returns (NativeFeeSponsorshipAddresses memory) {
    uint256 len = 2;
    HookDeployment[] memory hooks = new HookDeployment[](len);

    // Deploy sponsorship contract first (no constructor args)
    hooks[0] = HookDeployment(
        NATIVE_FEE_SPONSORSHIP_KEY,
        "",
        __getOtherHooksBytecode("NativeFeeSponsorship", env)
    );

    // NOTE: We need the sponsorship address as constructor arg for the hook,
    // but we don't know it until deployment. This is a CHICKEN-AND-EGG problem.
    //
    // SOLUTION: Use CREATE2 to precompute the sponsorship address, OR
    // deploy in two stages (deploy sponsorship first, then deploy hook with the address).
    //
    // Looking at the existing codebase, the deployment uses deterministic CREATE2,
    // so we can precompute the sponsorship address before deploying the hook.
    // Check DeployV2Base.s.sol for the address precomputation pattern.

    // ... (implementation depends on existing deployment infrastructure)
}
```

**RESOLUTION**: The simplest approach is a two-step deployment:
1. First deploy NativeFeeSponsorship
2. Then deploy FetchNativeFeeHook with the sponsorship address

This matches the existing pattern where hooks with dependencies on other deployed contracts use addresses from prior deployment steps.

---

### 9. `script/run/regenerate_bytecode.sh` (MODIFY)

Add new contracts to the bytecode generation. Following the RFLR pattern, add a new array:

```bash
# Native Fee Sponsorship contracts (deployed via DeployV2OtherHooks)
NATIVE_FEE_SPONSORSHIP_CONTRACTS=(
    "NativeFeeSponsorship"
    "FetchNativeFeeHook"
)
```

And add the copy/verification logic for these contracts in the bytecode generation section, following the same pattern as `RFLR_HOOK_CONTRACTS`.

---

### 10. `script/run/deploy_v2_other_hooks_staging_prod.sh` (MODIFY)

Add deployment support for native fee sponsorship contracts, following the RFLR pattern:

```bash
# Native Fee Sponsorship supported chains (all chains that may use Stargate)
NATIVE_FEE_SPONSORSHIP_SUPPORTED_CHAINS=("1" "8453" "42161" "10" "137" "43114" "56")

is_native_fee_sponsorship_supported() {
    local chain_id=$1
    for supported in "${NATIVE_FEE_SPONSORSHIP_SUPPORTED_CHAINS[@]}"; do
        if [ "$supported" = "$chain_id" ]; then
            return 0
        fi
    done
    return 1
}
```

And add the deployment invocation in the chain loop.

---

### TEST FILES

---

### 11. `test/unit/sponsorship/NativeFeeSponsorshipTest.t.sol` (NEW)

**Purpose**: Unit tests for the NativeFeeSponsorship ledger contract.

**Test structure** (inherits `Helpers`, following ClaimRFLRHookTest pattern):

```
NativeFeeSponsorshipTest is Helpers {
    NativeFeeSponsorship public sponsorship;
    address public sponsor;
    address public account;

    receive() external payable { }  // Important for receiving ETH in tests

    setUp():
        sponsorship = new NativeFeeSponsorship();
        sponsor = makeAddr("sponsor");
        account = makeAddr("account");
        vm.deal(address(this), 100 ether);
        vm.deal(sponsor, 100 ether);
        vm.deal(account, 100 ether);

    // === depositForAccount tests ===
    test_DepositForAccount():
        - Call depositForAccount{value: 1 ether}(sponsor, account)
        - Assert sponsoredAmount(sponsor, account) == 1 ether
        - Assert contract balance == 1 ether

    test_DepositForAccount_MultipleDeposits():
        - Two deposits of 1 ether each
        - Assert total == 2 ether

    test_DepositForAccount_RevertIf_ZeroSponsor():
        - vm.expectRevert(INativeFeeSponsorship.ZERO_ADDRESS.selector)
        - depositForAccount{value: 1 ether}(address(0), account)

    test_DepositForAccount_RevertIf_ZeroAccount():
        - depositForAccount{value: 1 ether}(sponsor, address(0))

    test_DepositForAccount_RevertIf_ZeroValue():
        - depositForAccount{value: 0}(sponsor, account) -> ZERO_AMOUNT

    test_DepositForAccount_EmitsEvent():
        - vm.expectEmit with NativeDeposited event

    // === withdrawSponsoredNative tests ===
    test_WithdrawSponsoredNative():
        - Deposit 1 ether
        - vm.prank(account)
        - withdrawSponsoredNative(sponsor, 1 ether)
        - Assert sponsoredAmount == 0
        - Assert account balance increased

    test_WithdrawSponsoredNative_Partial():
        - Deposit 2 ether, withdraw 1 ether
        - Assert remaining == 1 ether

    test_WithdrawSponsoredNative_RevertIf_InsufficientBalance():
        - Deposit 1 ether, try to withdraw 2 ether
        - INSUFFICIENT_SPONSORED_BALANCE

    test_WithdrawSponsoredNative_RevertIf_ZeroAmount():
        - withdrawSponsoredNative(sponsor, 0) -> ZERO_AMOUNT

    test_WithdrawSponsoredNative_RevertIf_WrongAccount():
        - Deposit for account1
        - vm.prank(account2) try to withdraw -> INSUFFICIENT_SPONSORED_BALANCE

    test_WithdrawSponsoredNative_EmitsEvent()

    // === withdrawSponsorDeposit tests ===
    test_WithdrawSponsorDeposit():
        - Deposit 1 ether
        - vm.prank(sponsor)
        - withdrawSponsorDeposit(account, payable(sponsor), 1 ether)
        - Assert sponsoredAmount == 0

    test_WithdrawSponsorDeposit_ToThirdParty():
        - Withdraw to a different address than sponsor

    test_WithdrawSponsorDeposit_RevertIf_InsufficientBalance()
    test_WithdrawSponsorDeposit_RevertIf_ZeroAmount()
    test_WithdrawSponsorDeposit_RevertIf_ZeroAccount()
    test_WithdrawSponsorDeposit_RevertIf_ZeroTo()
    test_WithdrawSponsorDeposit_EmitsEvent()

    // === sponsoredAmount view tests ===
    test_SponsoredAmount_Default():
        - Fresh contract, assert == 0

    test_SponsoredAmount_AfterDeposit()
    test_SponsoredAmount_AfterWithdraw()

    // === Edge cases ===
    test_MultipleSponsorsForSameAccount():
        - sponsor1 deposits 1 ether for account
        - sponsor2 deposits 2 ether for account
        - Assert separate balances

    test_SameSponsorMultipleAccounts():
        - sponsor deposits for account1 and account2
        - Assert separate balances
}
```

---

### 12. `test/unit/hooks/sponsorship/FetchNativeFeeHookTest.t.sol` (NEW)

**Purpose**: Unit tests for FetchNativeFeeHook.

**Directory**: Create `test/unit/hooks/sponsorship/`.

**Test structure** (following ClaimRFLRHookTest patterns):

```
FetchNativeFeeHookTest is Helpers {
    FetchNativeFeeHook public hook;
    address public sponsorship;
    address public account;
    address public sponsor;

    setUp():
        sponsorship = makeAddr("sponsorship");
        account = makeAddr("account");
        sponsor = makeAddr("sponsor");
        hook = new FetchNativeFeeHook(sponsorship);

    // === Constructor tests ===
    test_Constructor():
        - assertEq(hook.hookType(), NONACCOUNTING)
        - assertEq(hook.SPONSORSHIP(), sponsorship)

    test_Constructor_RevertIf_SponsorshipZero():
        - vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector)
        - new FetchNativeFeeHook(address(0))

    // === Build tests ===
    test_Build():
        - Create hook data: abi.encodePacked(sponsor, uint256(1 ether))
        - Call hook.build(address(0), account, data)
        - Assert executions.length == 3 (preExecute + withdrawal + postExecute)
        - Assert executions[1].target == sponsorship
        - Assert executions[1].value == 0
        - Verify calldata matches abi.encodeCall(INativeFeeSponsorship.withdrawSponsoredNative, (sponsor, 1 ether))

    test_Build_RevertIf_DataTooShort():
        - bytes memory shortData = abi.encodePacked(address(0x1));  // only 20 bytes, needs 52
        - vm.expectRevert(FetchNativeFeeHook.INVALID_DATA_LENGTH.selector)
        - hook.build(address(0), account, shortData)

    test_Build_RevertIf_ZeroSponsor():
        - data with address(0) as sponsor
        - vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector)

    test_Build_RevertIf_ZeroAmount():
        - data with amount = 0
        - vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector)

    // === Inspect tests ===
    test_Inspect_ReturnsSponsorshipAddress():
        - bytes memory result = hook.inspect(data)
        - assertEq(result, abi.encodePacked(sponsorship))
        - CRITICAL: verify ONLY address returned, no amounts

    // === Calldata encoding tests ===
    test_CalldataDecoding():
        - Verify various sponsor/amount combinations produce correct calldata

    // === Helper ===
    function _createFetchNativeFeeData(
        address sponsor_,
        uint256 amount_
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(sponsor_, amount_);
    }
}
```

---

### 13. `test/unit/paymaster/SuperNativePaymasterSponsorshipTest.t.sol` (NEW)

**Purpose**: Unit tests specifically for the new `sponsorNativeAndHandleUserOp` function.

**Alternative**: Could also add tests to existing `SuperNativePaymaster.t.sol`, but a separate file keeps things focused and avoids merge conflicts with the existing test file.

**Test structure**:

```
SuperNativePaymasterSponsorshipTest is Helpers {
    SuperNativePaymaster public paymaster;
    MockEntryPoint public mockEntryPoint;
    NativeFeeSponsorship public sponsorship;
    address public bundler;
    address public smartAccount;

    receive() external payable { }

    setUp():
        mockEntryPoint = new MockEntryPoint();
        sponsorship = new NativeFeeSponsorship();
        paymaster = new SuperNativePaymaster(
            IEntryPoint(address(mockEntryPoint)),
            INativeFeeSponsorship(address(sponsorship))
        );
        bundler = makeAddr("bundler");
        smartAccount = makeAddr("smartAccount");
        vm.deal(bundler, 100 ether);
        vm.deal(address(mockEntryPoint), 100 ether);

    // === Constructor tests ===
    test_Constructor_SponsorshipSet():
        - assertEq(address(paymaster.SPONSORSHIP()), address(sponsorship))

    test_Constructor_SponsorshipCanBeZero():
        - Deploy with address(0) sponsorship -- should NOT revert
        - The sponsorship is optional (chains without Stargate)

    // === sponsorNativeAndHandleUserOp tests ===
    test_SponsorNativeAndHandleUserOp():
        - Create a valid PackedUserOperation with smartAccount as sender
        - vm.prank(bundler)
        - paymaster.sponsorNativeAndHandleUserOp{value: 1.5 ether}(op, 0.5 ether)
        - Assert sponsorship.sponsoredAmount(bundler, smartAccount) changes correctly
          (Note: handleOps will trigger UserOp execution which may withdraw the sponsored amount)
        - Assert mockEntryPoint received gas funds (1.0 ether)
        - Assert event emitted

    test_SponsorNativeAndHandleUserOp_ZeroNativeAmount():
        - nativeAmount = 0
        - All msg.value goes to gas
        - Should revert because SPONSORSHIP.depositForAccount requires msg.value > 0
        - OR: We should add a check: if nativeAmount == 0, skip the sponsorship deposit
        - DECISION: If nativeAmount == 0, it doesn't make sense to call this function.
          The bundler should use regular handleOps instead. So we should revert.
        - Add error: ZERO_NATIVE_AMOUNT

    test_SponsorNativeAndHandleUserOp_RevertIf_NativeAmountExceedsValue():
        - msg.value = 1 ether, nativeAmount = 2 ether
        - vm.expectRevert(NATIVE_AMOUNT_EXCEEDS_VALUE.selector)

    test_SponsorNativeAndHandleUserOp_RevertIf_SponsorshipNotSet():
        - Deploy paymaster with SPONSORSHIP = address(0)
        - Call sponsorNativeAndHandleUserOp
        - vm.expectRevert(INVALID_SPONSORSHIP.selector)

    test_SponsorNativeAndHandleUserOp_AllValueToNative():
        - msg.value = 1 ether, nativeAmount = 1 ether
        - gasAmount = 0, no deposit to EntryPoint
        - NOTE: This would likely cause handleOps to fail (no gas funding)
        - The EntryPoint will revert, reverting the whole tx including sponsorship

    test_SponsorNativeAndHandleUserOp_EmitsEvent()

    test_SponsorNativeAndHandleUserOp_AtomicRevert():
        - Simulate handleOps failure (mock EntryPoint to revert)
        - Verify sponsorship deposit is also reverted (check balance == 0)
        - This tests the atomicity guarantee

    // === Backward compatibility ===
    test_ExistingHandleOps_StillWorks():
        - Verify the existing handleOps function still works unchanged
        - Important regression test
}
```

**IMPORTANT NOTE ON CONSTRUCTOR CHANGE**: The existing `SuperNativePaymaster.t.sol` will break because the constructor now requires a second argument. You MUST update the existing test to pass the sponsorship address:

In `test/unit/paymaster/SuperNativePaymaster.t.sol`, update `setUp()`:
```solidity
function setUp() public {
    mockEntryPoint = new MockEntryPoint();
    // Pass address(0) for sponsorship in existing tests (backward compatible)
    paymaster = new SuperNativePaymaster(
        IEntryPoint(address(mockEntryPoint)),
        INativeFeeSponsorship(address(0))
    );
    // ... rest unchanged
}
```

---

## Deployment Considerations

### Chain Support

NativeFeeSponsorship and FetchNativeFeeHook should be deployed on ALL chains where Stargate V2 is available. Stargate V2 supports:
- Ethereum (1)
- Base (8453)
- Arbitrum (42161)
- Optimism (10)
- Polygon (137)
- Avalanche (43114)
- BNB Chain (56)
- Linea (59144)
- And potentially more

The exact list should be confirmed with the team. The deployment is NOT conditional on any external dependency (unlike UniswapV4 which depends on PoolManager) -- NativeFeeSponsorship is a Superform-owned contract with no external dependencies.

### Deployment Order

1. Deploy `NativeFeeSponsorship` (no constructor args)
2. Deploy `FetchNativeFeeHook` (constructor arg: NativeFeeSponsorship address from step 1)
3. Optionally redeploy `SuperNativePaymaster` with NativeFeeSponsorship address (if constructor change approach is chosen)

### SuperNativePaymaster Redeployment Decision

The team must decide:
- **Option A (Recommended for MVP)**: Keep the existing SuperNativePaymaster unchanged. Pass the sponsorship address as a parameter in `sponsorNativeAndHandleUserOp`. This avoids redeployment.
- **Option B (Cleaner long-term)**: Redeploy SuperNativePaymaster with immutable SPONSORSHIP. Requires updating all references and redeployment on all chains.

If **Option A** is chosen, modify the function signature to:
```solidity
function sponsorNativeAndHandleUserOp(
    PackedUserOperation calldata op,
    uint256 nativeAmount,
    address sponsorship
) external payable;
```
And remove the immutable from the contract. Add a validation check that `sponsorship != address(0)`.

**RECOMMENDATION**: Go with Option A for MVP to avoid paymaster redeployment complexity.

---

## Security Considerations

### 1. Atomicity (CRITICAL)
- `sponsorNativeAndHandleUserOp` provides atomicity via `entryPoint.handleOps` reverting on failure
- If UserOp execution fails, the entire transaction reverts, undoing the sponsorship deposit
- No try/catch should be used -- let the revert propagate naturally

### 2. Reentrancy Protection
- NativeFeeSponsorship uses OpenZeppelin's `ReentrancyGuard` on all mutating functions
- Checks-Effects-Interactions pattern in all ETH transfer functions
- State is updated BEFORE ETH transfers

### 3. Race Condition (Accepted Tradeoff)
- Sponsor can reclaim deposit before account withdraws (or vice versa)
- This is by design -- the bundler should only deposit right before calling handleOps
- The atomic `sponsorNativeAndHandleUserOp` mitigates this for the normal flow

### 4. Overfetch (Accepted Tradeoff)
- If FetchNativeFeeHook withdraws more than Stargate needs, excess stays on smart account
- Not recoverable by bundler -- this is the bundler's responsibility to quote correctly
- The off-chain `quoteSend` should provide exact amounts

### 5. No Access Control on Sponsorship
- Anyone can deposit for any account (by design)
- Anyone can call the paymaster's sponsorNativeAndHandleUserOp (existing handleOps is also permissionless)
- The smart account is the only one who can withdraw (msg.sender check)
- The sponsor is the only one who can reclaim (msg.sender check)

### 6. ETH Transfer Failure
- If the smart account cannot receive ETH (no receive/fallback), the withdrawal will revert
- This is handled by the `ETH_TRANSFER_FAILED` error
- Smart accounts in Superform (Nexus, Safe) should always accept ETH

### 7. Integer Overflow
- Solidity 0.8.30 provides built-in overflow protection
- The `sponsoredNative` mapping uses uint256, which is sufficient for any practical ETH amount

---

## Data Encoding Reference

### FetchNativeFeeHook Data Layout (52 bytes total)

```
Offset  | Type    | Field    | Description
--------|---------|----------|----------------------------------
0       | address | sponsor  | The sponsor (bundler) address (20 bytes)
20      | uint256 | amount   | The amount of native ETH to withdraw (32 bytes)
```

Encoding: `abi.encodePacked(address(sponsor), uint256(amount))`

---

## Implementation Order (Recommended)

1. **INativeFeeSponsorship.sol** - Interface first
2. **NativeFeeSponsorship.sol** - Standalone ledger contract
3. **NativeFeeSponsorshipTest.t.sol** - Unit tests for ledger
4. **FetchNativeFeeHook.sol** - Hook contract
5. **FetchNativeFeeHookTest.t.sol** - Unit tests for hook
6. **ISuperNativePaymaster.sol** - Interface update (add new function signature + errors)
7. **SuperNativePaymaster.sol** - Add new function
8. **SuperNativePaymasterSponsorshipTest.t.sol** - Unit tests for new function
9. **Update existing SuperNativePaymaster.t.sol** - Fix constructor if needed
10. **Deployment script changes** - Constants, OtherHooks, bytecode generation
11. **Run full test suite** to verify no regressions

---

## Open Questions for Team Decision

1. **Constructor change vs parameter approach**: Should we redeploy SuperNativePaymaster (immutable SPONSORSHIP) or pass sponsorship address as a function parameter?

2. **Chain deployment list**: Exact list of chains for NativeFeeSponsorship deployment?

3. **Directory structure**: Is `src/sponsorship/` acceptable for NativeFeeSponsorship, or should it go under `src/paymaster/`?

4. **Hook subtype**: Using `HookSubTypes.TOKEN` for FetchNativeFeeHook -- should we add a new `SPONSORSHIP` subtype instead?

5. **Integration tests**: Should we add integration tests that test the full flow (paymaster -> sponsorship -> hook -> Stargate)? This would require Stargate mainnet fork testing.

---

## Diff Summary

| File | Action | Description |
|------|--------|-------------|
| `src/interfaces/INativeFeeSponsorship.sol` | CREATE | Interface for sponsorship ledger |
| `src/sponsorship/NativeFeeSponsorship.sol` | CREATE | Ledger contract |
| `src/hooks/sponsorship/FetchNativeFeeHook.sol` | CREATE | Withdrawal hook |
| `src/interfaces/ISuperNativePaymaster.sol` | MODIFY | Add new function, errors, events |
| `src/paymaster/SuperNativePaymaster.sol` | MODIFY | Add sponsorNativeAndHandleUserOp |
| `test/unit/sponsorship/NativeFeeSponsorshipTest.t.sol` | CREATE | Ledger unit tests |
| `test/unit/hooks/sponsorship/FetchNativeFeeHookTest.t.sol` | CREATE | Hook unit tests |
| `test/unit/paymaster/SuperNativePaymasterSponsorshipTest.t.sol` | CREATE | New function unit tests |
| `test/unit/paymaster/SuperNativePaymaster.t.sol` | MODIFY | Fix constructor (if changed) |
| `script/utils/ConstantsOtherHooks.sol` | MODIFY | Add hook key constants |
| `script/DeployV2OtherHooks.s.sol` | MODIFY | Add deployment function |
| `script/run/regenerate_bytecode.sh` | MODIFY | Add bytecode generation |
| `script/run/deploy_v2_other_hooks_staging_prod.sh` | MODIFY | Add deployment support |
