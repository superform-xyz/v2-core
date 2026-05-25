# rFLR Claiming Hooks - Implementation Plan

## Summary

Two NONACCOUNTING hooks for Flare mainnet (chain 14): ClaimRFLRHook (claims rFLR rewards with fee handling) and WithdrawRFLRHook (converts rFLR to WFLR). Plus a minimal vendor interface IRNat.

## Branch

Must be on `pre-dev` branch. Check current branch and alert user if not.

---

## Phase 1: Core Implementation (3 files to create)

### File 1: `src/vendor/flare/IRNat.sol` (NEW)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IRNat
/// @notice Minimal interface for Flare's RNat (rFLR) reward contract
/// @dev rFLR tokens vest linearly over 12 months. Early withdrawal of locked tokens
///      incurs a 50% penalty (burned). The RNat contract IS the rFLR ERC-20 token.
interface IRNat {
    /// @notice Claims rFLR rewards across specified projects up to a given month
    /// @param projectIds Array of project IDs to claim from
    /// @param month The month up to which to claim (inclusive, cumulative)
    /// @return claimedAmount Total WFLR deposited into caller's RNat account
    function claimRewards(uint256[] calldata projectIds, uint256 month) external returns (uint128 claimedAmount);

    /// @notice Withdraws all funds from the caller's RNat account
    /// @dev 50% penalty on locked (unvested) portion -- half is burned
    /// @param wrap If true returns WFLR (ERC-20); if false returns native FLR
    /// @return withdrawnAmount Total withdrawn after penalty deduction
    function withdrawAll(bool wrap) external returns (uint128 withdrawnAmount);
}
```

**Notes:**
- Directory `src/vendor/flare/` does not exist yet -- must create it.
- Keep minimal: only the two functions we actually call.

---

### File 2: `src/hooks/claim/flare/ClaimRFLRHook.sol` (NEW)

**Key design decisions based on codebase analysis:**

#### Pattern: Follows MerklClaimRewardHook exactly

The MerklClaimRewardHook is the primary reference. Key observations from reading it:

1. **Fee calculation**: MerklClaimRewardHook computes fee as `(claimableAmount * feePercent) / BPS` where claimableAmount is `amounts[i] - alreadyClaimed`. For our hook, we use `expectedClaimAmount` from calldata since there's no on-chain `claimed()` equivalent.

2. **_preExecute/_postExecute**: MerklClaimRewardHook sets outAmount to 0 in both pre and post. It does NOT do balance tracking. This is different from TransferERC20Hook/WithdrawWETHHook which DO balance tracking.

3. **CRITICAL DEVIATION FROM SPEC**: The spec says to use balance snapshot pattern (like TransferERC20Hook). However, MerklClaimRewardHook does NOT do balance snapshots -- it sets outAmount to 0 in both pre and post. I recommend following the spec's balance snapshot approach since:
   - The claimed rFLR amount is unpredictable (depends on accumulated rewards)
   - Balance delta tracking gives accurate outAmount for downstream hook chaining
   - WithdrawRFLRHook needs to know how much rFLR was received to chain properly

4. **inspect()**: MerklClaimRewardHook returns `abi.encodePacked(feeReceiver)` -- ONLY the fee receiver address. The spec matches this. Use `pure` visibility since we only decode from data.

5. **Interfaces**: MerklClaimRewardHook only inherits `BaseHook` (which already includes ISuperHookInspector). It does NOT implement ISuperHookInflowOutflow or ISuperHookContextAware. The spec says to implement ISuperHookInflowOutflow and ISuperHookContextAware but the hook has no `usePrevHookAmount` or `decodeAmount` -- those don't apply to a claim hook where amounts are determined by the protocol. **Deviation: Do NOT implement ISuperHookInflowOutflow or ISuperHookContextAware. Follow MerklClaimRewardHook pattern -- just inherit BaseHook.**

#### Data Layout

```
/// @dev data has the following structure
/// @notice         address feeReceiver = BytesLib.toAddress(data, 0);
/// @notice         uint256 feeBPS = BytesLib.toUint256(data, 20);
/// @notice         uint256 month = BytesLib.toUint256(data, 52);
/// @notice         uint256 expectedClaimAmount = BytesLib.toUint256(data, 84);
/// @notice         uint256 projectIdsLength = BytesLib.toUint256(data, 116);
/// @notice         uint256[] projectIds = [BytesLib.toUint256(data, 148 + i*32) for i in 0..projectIdsLength-1]
```

**Byte offset breakdown:**
- 0-19: feeReceiver (address, 20 bytes)
- 20-51: feeBPS (uint256, 32 bytes)
- 52-83: month (uint256, 32 bytes)
- 84-115: expectedClaimAmount (uint256, 32 bytes)
- 116-147: projectIdsLength (uint256, 32 bytes)
- 148+: projectIds array (N * 32 bytes, tightly packed uint256 values)

#### Position Constants

```solidity
uint256 private constant FEE_RECEIVER_POSITION = 0;
uint256 private constant FEE_BPS_POSITION = 20;
uint256 private constant MONTH_POSITION = 52;
uint256 private constant EXPECTED_AMOUNT_POSITION = 84;
uint256 private constant PROJECT_IDS_LENGTH_POSITION = 116;
uint256 private constant PROJECT_IDS_START_POSITION = 148;
uint256 internal constant BPS = 10_000;
uint256 internal constant MAX_FEE_BPS = 5000;
```

#### Constructor

```solidity
constructor(address rNat_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
    if (rNat_ == address(0)) revert ADDRESS_NOT_VALID();
    RNAT = rNat_;
}
```

**Note:** Uses immutable `RNAT` address (not hardcoded) for multi-chain deployment flexibility.

#### Custom Errors

```solidity
error FEE_NOT_VALID();
error EMPTY_PROJECT_IDS();
```

`ADDRESS_NOT_VALID` and `AMOUNT_NOT_VALID` come from BaseHook.

#### `_buildHookExecutions` Implementation

```solidity
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
    // 1. Decode fee params
    address feeReceiver = BytesLib.toAddress(data, FEE_RECEIVER_POSITION);
    uint256 feeBPS = BytesLib.toUint256(data, FEE_BPS_POSITION);

    // 2. Validate fee
    if (feeBPS > MAX_FEE_BPS) revert FEE_NOT_VALID();
    if (feeBPS > 0 && feeReceiver == address(0)) revert ADDRESS_NOT_VALID();

    // 3. Decode claim params
    uint256 month = BytesLib.toUint256(data, MONTH_POSITION);
    uint256 expectedClaimAmount = BytesLib.toUint256(data, EXPECTED_AMOUNT_POSITION);
    uint256[] memory projectIds = _decodeProjectIds(data);

    // 4. Validate
    if (projectIds.length == 0) revert EMPTY_PROJECT_IDS();

    // 5. Compute fee
    uint256 fee = (expectedClaimAmount * feeBPS) / BPS;

    // 6. Build executions
    if (fee > 0) {
        executions = new Execution[](2);
        executions[1] = Execution({
            target: RNAT,
            value: 0,
            callData: abi.encodeCall(IERC20.transfer, (feeReceiver, fee))
        });
    } else {
        executions = new Execution[](1);
    }

    // Claim goes first (before fee transfer)
    executions[0] = Execution({
        target: RNAT,
        value: 0,
        callData: abi.encodeCall(IRNat.claimRewards, (projectIds, month))
    });
}
```

**IMPORTANT**: The claim execution goes at index 0 (before the fee transfer at index 1). This matches MerklClaimRewardHook where claim is `executions[0]`.

#### `_preExecute` and `_postExecute` - Balance Snapshot Pattern

Following the spec's recommendation (and TransferERC20Hook/WithdrawWETHHook patterns) instead of MerklClaimRewardHook's zero-zero pattern:

```solidity
function _preExecute(address, address account, bytes calldata) internal override {
    asset = RNAT;
    _setOutAmount(IERC20(RNAT).balanceOf(account), account);
}

function _postExecute(address, address account, bytes calldata) internal override {
    _setOutAmount(IERC20(RNAT).balanceOf(account) - getOutAmount(account), account);
}
```

**CRITICAL**: Setting `asset = RNAT` in _preExecute (the transient storage variable from BaseHook). This is needed for the accounting system to know what token the hook operates on. MerklClaimRewardHook does NOT set `asset` because it handles multiple tokens. Our hook handles a single token (rFLR/RNAT).

#### `inspect()`

```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    return abi.encodePacked(BytesLib.toAddress(data, FEE_RECEIVER_POSITION));
}
```

Uses `pure` since it only decodes from calldata. Returns ONLY the feeReceiver address (protocol requirement: inspectors must only return addresses).

#### `_decodeProjectIds` Helper

```solidity
function _decodeProjectIds(bytes calldata data) private pure returns (uint256[] memory projectIds) {
    uint256 length = BytesLib.toUint256(data, PROJECT_IDS_LENGTH_POSITION);
    projectIds = new uint256[](length);
    for (uint256 i; i < length; ++i) {
        projectIds[i] = BytesLib.toUint256(data, PROJECT_IDS_START_POSITION + i * 32);
    }
}
```

#### Full Import List

```solidity
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { IRNat } from "../../../vendor/flare/IRNat.sol";
```

**Note:** No `HookDataDecoder` import needed since we use BytesLib directly (matching MerklClaimRewardHook pattern). No `ISuperHookContextAware` or `ISuperHookInflowOutflow` needed.

#### Directory

`src/hooks/claim/flare/` -- directory does not exist, must create.

---

### File 3: `src/hooks/claim/flare/WithdrawRFLRHook.sol` (NEW)

**Key design decisions based on codebase analysis:**

#### Pattern: Follows WithdrawWETHHook closely

WithdrawWETHHook is the closest reference. Key observations:

1. **No data decoding needed**: The spec says data layout is empty. The hook always calls `IRNat.withdrawAll(true)`.
2. **Balance tracking**: WithdrawWETHHook tracks WETH balance delta. Our hook tracks WFLR balance delta.
3. **Interfaces**: WithdrawWETHHook implements `ISuperHookContextAware`. Since our hook has no user-provided amount (it withdraws ALL), there is no `usePrevHookAmount`. **Deviation: Do NOT implement ISuperHookContextAware.** Just inherit BaseHook.
4. **inspect()**: WithdrawWETHHook returns `abi.encodePacked(WETH)` with `view` visibility. Our hook returns `abi.encodePacked(RNAT)` with `view` visibility (accesses immutable).

#### NatSpec Data Layout

```
/// @dev data has the following structure
/// @notice         (no user-provided data -- all parameters are immutables or hardcoded)
```

Since the hook takes no data, the NatSpec is minimal.

#### Constructor

```solidity
constructor(address rNat_, address wflr_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.CLAIM) {
    if (rNat_ == address(0) || wflr_ == address(0)) revert ADDRESS_NOT_VALID();
    RNAT = rNat_;
    WFLR = wflr_;
}
```

#### `_buildHookExecutions`

```solidity
function _buildHookExecutions(
    address,
    address,
    bytes calldata
)
    internal
    view
    override
    returns (Execution[] memory executions)
{
    executions = new Execution[](1);
    executions[0] = Execution({
        target: RNAT,
        value: 0,
        callData: abi.encodeCall(IRNat.withdrawAll, (true))
    });
}
```

**Note:** No validation needed -- `withdrawAll(true)` always works (may return 0 if no balance). The `prevHook` and `account` params are unused. The `data` param is unused.

#### `_preExecute` and `_postExecute` - WFLR Balance Tracking

```solidity
function _preExecute(address, address account, bytes calldata) internal override {
    asset = WFLR;
    _setOutAmount(IERC20(WFLR).balanceOf(account), account);
}

function _postExecute(address, address account, bytes calldata) internal override {
    _setOutAmount(IERC20(WFLR).balanceOf(account) - getOutAmount(account), account);
}
```

**CRITICAL**: Sets `asset = WFLR` (not RNAT) because the output token is WFLR. The balance tracking is on WFLR since that's what the account receives.

#### `inspect()`

```solidity
function inspect(bytes calldata) external view override returns (bytes memory) {
    return abi.encodePacked(RNAT);
}
```

Uses `view` (not `pure`) because it accesses immutable `RNAT`. Returns the RNat contract address as the key external dependency.

#### NatSpec Warning

Add clear NatSpec warning about the 50% penalty:

```solidity
/// @title WithdrawRFLRHook
/// @author Superform Labs
/// @notice Withdraws all rFLR from RNat and receives WFLR. WARNING: 50% penalty applies
///         to any locked (unvested) portion. Only fully-vested rFLR is penalty-free.
/// @dev Calls IRNat.withdrawAll(true) to receive WFLR (wrapped FLR) instead of native FLR.
///      The penalty is enforced by the RNat contract and cannot be bypassed.
```

#### Full Import List

```solidity
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { IRNat } from "../../../vendor/flare/IRNat.sol";
```

**Note:** No BytesLib needed since we don't decode any data.

---

## Phase 2: Unit Tests (2 files to create)

### File 4: `test/unit/hooks/claim/rflr/ClaimRFLRHookTest.t.sol` (NEW)

**Pattern**: Follows MerklClaimRewardsHook.t.sol closely, using `Helpers` base (not BaseTest for simple unit tests).

**Directory**: `test/unit/hooks/claim/rflr/` -- does not exist, must create.

**Test class**: `ClaimRFLRHookTest is Helpers`

**Setup**:
- Deploy ClaimRFLRHook with a mock rNat address
- No fork needed -- use `vm.mockCall()` for all external interactions

**Test cases** (following MerklClaimRewardHook test patterns):

1. **`test_Constructor()`** -- verify hookType is NONACCOUNTING, RNAT is set correctly
2. **`test_Constructor_RevertIf_RNatZero()`** -- `vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector)`
3. **`test_Build_WithoutFee()`** -- feeBPS=0, verify 3 executions (pre + claim + post), verify claim calldata encodes `claimRewards(projectIds, month)` correctly, verify target is RNAT
4. **`test_Build_WithFee()`** -- feeBPS=1000 (10%), verify 4 executions (pre + claim + fee transfer + post), verify fee transfer amount is `(expectedClaimAmount * 1000) / 10000`
5. **`test_Build_RevertIf_InvalidFee()`** -- feeBPS=6000 (> 5000 max), expect `FEE_NOT_VALID()`
6. **`test_Build_RevertIf_ZeroFeeReceiver()`** -- feeBPS > 0 but feeReceiver is address(0), expect `ADDRESS_NOT_VALID()`
7. **`test_Build_RevertIf_EmptyProjectIds()`** -- projectIdsLength=0, expect `EMPTY_PROJECT_IDS()`
8. **`test_Build_ZeroFeeWhenFeeBPSZero()`** -- even with expectedClaimAmount > 0, fee=0 means no transfer execution
9. **`test_Build_ZeroFeeWhenExpectedAmountZero()`** -- feeBPS > 0 but expectedClaimAmount=0, fee computes to 0, only 1 execution (no transfer)
10. **`test_Build_FeeCalculation_EdgeCases()`** -- small amounts where fee rounds to 0, max fee (5000 BPS = 50%)
11. **`test_PreAndPostExecute()`** -- mock RNAT.balanceOf, call preExecute (stores initial balance), mock increased balance, call postExecute (stores delta). Verify outAmount equals delta. Must call `hook.setExecutionContext(account)` first, then `vm.prank(account)` before each pre/post call.
12. **`test_Inspector()`** -- verify returns 20 bytes, verify decoded address matches feeReceiver
13. **`test_Inspector_DifferentFeeReceivers()`** -- test with various fee receiver addresses
14. **`test_Build_MultipleProjectIds()`** -- verify encoding with 1, 3, 5 project IDs
15. **`test_CalldataDecoding()`** -- verify the claim calldata matches expected `abi.encodeCall(IRNat.claimRewards, (projectIds, month))`

**Data encoding helper**:

```solidity
function _createClaimRFLRData(
    address feeReceiver,
    uint256 feeBPS,
    uint256 month,
    uint256 expectedClaimAmount,
    uint256[] memory projectIds
) internal pure returns (bytes memory data) {
    data = bytes.concat(
        bytes20(feeReceiver),
        abi.encodePacked(feeBPS),
        abi.encodePacked(month),
        abi.encodePacked(expectedClaimAmount),
        abi.encodePacked(projectIds.length)
    );
    for (uint256 i; i < projectIds.length; ++i) {
        data = bytes.concat(data, abi.encodePacked(projectIds[i]));
    }
}
```

**IMPORTANT**: For `test_PreAndPostExecute()`, follow the WithdrawWETHHook test pattern:
1. Call `hook.setExecutionContext(account)` to set up execution context
2. Call `vm.prank(account)` then `hook.preExecute(...)` (must be called by account per BaseHook security)
3. Mock new balance
4. Call `vm.prank(account)` then `hook.postExecute(...)`
5. Assert `hook.getOutAmount(account) == balanceDelta`

Do NOT follow MerklClaimRewardHook test which has a simpler pre/post test (just checks outAmount is 0).

---

### File 5: `test/unit/hooks/claim/rflr/WithdrawRFLRHookTest.t.sol` (NEW)

**Pattern**: Follows WithdrawWETHHook.t.sol closely.

**Test class**: `WithdrawRFLRHookTest is Helpers`

**Setup**:
- Deploy WithdrawRFLRHook with mock rNat and wflr addresses
- No fork needed

**Test cases**:

1. **`test_Constructor()`** -- verify hookType is NONACCOUNTING, RNAT and WFLR are set
2. **`test_Constructor_RevertIf_RNatZero()`** -- expect ADDRESS_NOT_VALID
3. **`test_Constructor_RevertIf_WFLRZero()`** -- expect ADDRESS_NOT_VALID
4. **`test_Constructor_RevertIf_BothZero()`** -- expect ADDRESS_NOT_VALID
5. **`test_Build()`** -- verify 3 executions (pre + withdrawAll + post), verify calldata is `abi.encodeCall(IRNat.withdrawAll, (true))`, target is RNAT
6. **`test_Build_EmptyData()`** -- build with empty data bytes still works (data is unused)
7. **`test_PreAndPostExecute()`** -- mock initial WFLR balance, call preExecute, mock increased WFLR balance, call postExecute, verify outAmount equals delta
8. **`test_Inspector()`** -- verify returns 20 bytes, verify decoded address matches RNAT

**Data encoding**: Since WithdrawRFLRHook takes no data, tests pass empty bytes or arbitrary bytes.

---

## Phase 3: Deployment Scripts (4 files to modify)

### File 6: `script/utils/ConstantsOtherHooks.sol` (MODIFY)

Add rFLR constants following the DETH pattern:

```solidity
// rFLR hook keys
string internal constant CLAIM_RFLR_HOOK_KEY = "ClaimRFLRHook";
string internal constant WITHDRAW_RFLR_HOOK_KEY = "WithdrawRFLRHook";

// rFLR contract addresses (Flare mainnet)
address internal constant RNAT_FLARE = 0x26d460c3Cf931Fb2014FA436a49e3Af08619810e;
address internal constant WFLR_FLARE = 0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d;
```

**Note:** Following the DETH pattern of putting hook keys in ConstantsOtherHooks.sol. The contract addresses belong here too since they are deployment-specific constants (like MORPHO_MAINNET etc).

### File 7: `script/DeployV2OtherHooks.s.sol` (MODIFY)

**Changes needed:**

1. Add struct:
```solidity
struct RFLRHookAddresses {
    address claimRFLRHook;
    address withdrawRFLRHook;
}
```

2. Add `runRFLR` entry point:
```solidity
function runRFLR(uint256 env, uint64 chainId) public broadcast(env) {
    _setConfiguration(env, "");
    console2.log("Deploying rFLR Hooks on chainId: ", chainId);
    _deployRFLRHooks(chainId, env);
    _writeExportedContracts(chainId);
}
```

3. Add to `_deployAllHooks`:
```solidity
// rFLR hooks -- only on Flare
if (chainId == FLARE_CHAIN_ID) {
    console2.log("Deploying rFLR Hooks on chainId: ", chainId);
    _deployRFLRHooks(chainId, env);
}
```

**IMPORTANT**: Place the rFLR block AFTER the Firelight block (which also gates on `FLARE_CHAIN_ID`). This keeps Flare-specific hooks grouped together.

4. Add deployment function:
```solidity
/*//////////////////////////////////////////////////////////////
                      RFLR HOOKS DEPLOYMENT
//////////////////////////////////////////////////////////////*/

/// @notice Deploy 2 rFLR hooks (constructor args: RNAT address, and RNAT+WFLR for withdraw hook)
function _deployRFLRHooks(uint64 chainId, uint256 env) internal returns (RFLRHookAddresses memory) {
    uint256 len = 2;
    HookDeployment[] memory hooks = new HookDeployment[](len);
    address[] memory addresses = new address[](len);

    hooks[0] = HookDeployment(
        CLAIM_RFLR_HOOK_KEY,
        "",
        abi.encodePacked(__getOtherHooksBytecode("ClaimRFLRHook", env), abi.encode(RNAT_FLARE))
    );
    hooks[1] = HookDeployment(
        WITHDRAW_RFLR_HOOK_KEY,
        "",
        abi.encodePacked(__getOtherHooksBytecode("WithdrawRFLRHook", env), abi.encode(RNAT_FLARE, WFLR_FLARE))
    );

    for (uint256 i = 0; i < len; ++i) {
        HookDeployment memory hook = hooks[i];
        string memory saltName = bytes(hook.saltOverride).length > 0 ? hook.saltOverride : hook.name;
        addresses[i] = __deployContract(hook.name, chainId, __getSalt(saltName), hook.creationCode);
    }

    RFLRHookAddresses memory hookAddresses;
    hookAddresses.claimRFLRHook = addresses[0];
    hookAddresses.withdrawRFLRHook = addresses[1];

    require(hookAddresses.claimRFLRHook != address(0), "ClaimRFLRHook not assigned");
    require(hookAddresses.withdrawRFLRHook != address(0), "WithdrawRFLRHook not assigned");

    console2.log("All rFLR hooks deployed and validated successfully.");

    return hookAddresses;
}
```

**Key difference from DETH hooks**: rFLR hooks DO have constructor args (RNAT address for claim, RNAT+WFLR for withdraw). This follows the Morpho/Algebra pattern of `abi.encodePacked(bytecode, abi.encode(args))`.

### File 8: `script/run/regenerate_bytecode.sh` (MODIFY)

Add rFLR hook contracts array and copy logic. Follow the DETH pattern:

1. Add array definition after `DETH_HOOK_CONTRACTS`:
```bash
# rFLR hook contracts (deployed via DeployV2OtherHooks, stored in generated-bytecode-other/)
RFLR_HOOK_CONTRACTS=(
    "ClaimRFLRHook"
    "WithdrawRFLRHook"
)
```

2. Add copy block after the DETH copy block (in the `copy_all_contracts` function):
```bash
# Copy rFLR hook contracts to generated-bytecode-other/
log "INFO" "${BLUE}Copying rFLR hook contracts to generated-bytecode-other/...${NC}"
failed_rflr=0
for contract in "${RFLR_HOOK_CONTRACTS[@]}"; do
    local_source="out/${contract}.sol/${contract}.json"
    local_dest="script/generated-bytecode-other/${contract}.json"
    if [ ! -f "$local_source" ]; then
        log "ERROR" "${RED}Artifact not found for contract: ${contract} at ${local_source}${NC}"
        failed_rflr=$((failed_rflr + 1))
    else
        cp "$local_source" "$local_dest"
        log "INFO" "${GREEN}Copied ${contract} to generated-bytecode-other/${NC}"
    fi
done
```

3. Update the summary `total_contracts` line to include `+ ${#RFLR_HOOK_CONTRACTS[@]}`.

4. Add the rFLR failure warning block after the DETH one.

### File 9: `script/run/deploy_v2_other_hooks_staging_prod.sh` (MODIFY)

Add rFLR deployment section. Follow the DETH/Firelight patterns:

1. Add supported chains:
```bash
# rFLR is only deployed on Flare
RFLR_SUPPORTED_CHAINS=("14")

is_rflr_supported() {
    local chain_id=$1
    for supported in "${RFLR_SUPPORTED_CHAINS[@]}"; do
        if [ "$supported" = "$chain_id" ]; then
            return 0
        fi
    done
    return 1
}
```

2. Add bytecode check:
```bash
# Check bytecode availability for rFLR hooks
echo -e "${BLUE}Checking rFLR hook bytecode availability...${NC}"

RFLR_HOOKS=(
    "ClaimRFLRHook"
    "WithdrawRFLRHook"
)

missing_rflr=0
for hook in "${RFLR_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_rflr=$((missing_rflr + 1))
    fi
done

if [ $missing_rflr -gt 0 ]; then
    echo -e "${YELLOW}  ${missing_rflr} rFLR hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi
```

3. Add deployment block in the per-chain loop (after DETH section):
```bash
# Deploy rFLR hooks if supported on this chain
if is_rflr_supported "$network_id"; then
    has_hooks=true
    echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
    echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
    echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
    echo -e "${YELLOW}   Deploying rFLR hooks...${NC}"

    if forge script script/DeployV2OtherHooks.s.sol:DeployV2OtherHooks \
        --sig 'runRFLR(uint256,uint64)' $FORGE_ENV $network_id \
        --account $ACCOUNT \
        $KEYSTORE_PASSWORD_FLAG \
        --rpc-url ${!rpc_var} \
        --chain $network_id \
        --etherscan-api-key $ETHERSCANV2_API_KEY \
        --verify \
        --verifier-url https://api.routescan.io/v2/network/mainnet/evm/$network_id/etherscan \
        --broadcast \
        $RESUME_FLAG \
        $LEGACY_FLAG \
        $GAS_PRICE_FLAG \
        --timeout 300 \
        -vv; then
        echo -e "${GREEN}   rFLR hooks deployment completed!${NC}"
    else
        echo -e "${RED}   rFLR hooks deployment failed on $network_name, continuing...${NC}"
    fi
fi
```

4. Update the confirmation prompt to include "+ rFLR".

---

## Spec Deviations Summary

| Spec Says | Actual Implementation | Reason |
|-----------|----------------------|--------|
| ClaimRFLRHook implements ISuperHookInflowOutflow, ISuperHookContextAware | Only inherits BaseHook | Claim hooks have no usePrevHookAmount or decodeAmount. Matches MerklClaimRewardHook pattern. |
| WithdrawRFLRHook implements ISuperHookInspector only | Only inherits BaseHook (which already includes ISuperHookInspector) | BaseHook already inherits ISuperHookInspector. No separate import needed. |
| WithdrawRFLRHook inspect returns `abi.encodePacked(RNAT)` | Same: `abi.encodePacked(RNAT)` | Matches spec. Returns the key external dependency address. |
| ClaimRFLRHook inspect returns `abi.encodePacked(feeReceiver)` | Same: `abi.encodePacked(BytesLib.toAddress(data, 0))` | Matches spec and MerklClaimRewardHook. |

---

## Verification Steps

After implementation:

1. **Compile**: `forge build` -- should pass without errors
2. **Unit tests**: `make forge-test TEST=ClaimRFLRHookTest` and `make forge-test TEST=WithdrawRFLRHookTest`
3. **Regenerate bytecode**: `./script/run/regenerate_bytecode.sh` -- verify ClaimRFLRHook.json and WithdrawRFLRHook.json appear in `script/generated-bytecode-other/`
4. **Deployment dry-run**: Not feasible without Flare RPC, but script compilation can be verified with `forge build`

---

## File Creation Order

1. `src/vendor/flare/IRNat.sol` (no dependencies)
2. `src/hooks/claim/flare/ClaimRFLRHook.sol` (depends on IRNat)
3. `src/hooks/claim/flare/WithdrawRFLRHook.sol` (depends on IRNat)
4. `test/unit/hooks/claim/rflr/ClaimRFLRHookTest.t.sol` (depends on ClaimRFLRHook)
5. `test/unit/hooks/claim/rflr/WithdrawRFLRHookTest.t.sol` (depends on WithdrawRFLRHook)
6. Modify `script/utils/ConstantsOtherHooks.sol`
7. Modify `script/DeployV2OtherHooks.s.sol`
8. Modify `script/run/regenerate_bytecode.sh`
9. Modify `script/run/deploy_v2_other_hooks_staging_prod.sh`

---

## Critical Notes for Implementers

1. **Solidity version**: MUST be `0.8.30` everywhere. No exceptions.

2. **Directory creation**: Three new directories need to be created:
   - `src/vendor/flare/`
   - `src/hooks/claim/flare/`
   - `test/unit/hooks/claim/rflr/`

3. **Inspector compliance**: Both inspect() functions MUST only return addresses. Never include amounts, booleans, or other data. This is a PROTOCOL REQUIREMENT.

4. **Function visibility**: ClaimRFLRHook.inspect() is `pure` (only decodes data). WithdrawRFLRHook.inspect() is `view` (accesses immutable RNAT).

5. **Pre/post execute pattern**: Unlike MerklClaimRewardHook (which sets 0/0), our hooks DO balance tracking because the claimed amount is variable and needs to be communicated to downstream hooks via outAmount.

6. **Fee calculation timing**: The fee is calculated using `expectedClaimAmount` from calldata (computed off-chain). The actual claimed amount may differ. The fee transfer uses the pre-computed amount. If the actual claim is less than expected, the fee transfer will still try to transfer the pre-computed fee -- this is acceptable because:
   - The off-chain bundler computes expectedClaimAmount conservatively
   - If insufficient rFLR balance, the ERC20 transfer will revert (fail-safe)

7. **Test structure**: Use `Helpers` inheritance for unit tests (not `BaseTest`). Unit tests should NOT require forks -- use `vm.mockCall()` for all external interactions. Follow the WithdrawWETHHook test pattern for pre/post execute tests with `setExecutionContext`.

8. **Constructor args in deployment**: ClaimRFLRHook takes `(address rNat_)`. WithdrawRFLRHook takes `(address rNat_, address wflr_)`. The deployment script must `abi.encode` these correctly. This differs from DETH hooks which have no constructor args.

9. **RNAT IS the rFLR token**: The RNat contract is both the reward distribution contract AND the ERC-20 token. So `IERC20(RNAT).balanceOf(account)` gives the rFLR balance, and `IRNat(RNAT).claimRewards(...)` claims rewards. Both call the same contract.
