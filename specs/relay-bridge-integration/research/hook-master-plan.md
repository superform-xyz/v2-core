# Relay (relay.link) Bridge Integration — Hook Master Implementation Plan

**Author:** superform-hook-master
**Date:** 2026-08-07
**Session:** `.claude/sessions/context_session_32.md`
**Status:** PLAN ONLY — no implementation performed

---

## 0. Critical pre-flight notes (read these even if you know the codebase)

1. **BRANCH ALERT:** Current branch is `feat/rh-deployment`. Hook development is required to happen on `pre-dev`. Branch off `pre-dev` (or coordinate with the RH launch work) before implementing.
2. **The hook interface surface has evolved — outdated knowledge will produce wrong code.** Hooks now implement:
   - `decodeAmounts(bytes) → uint256[]` (plural, NOT `decodeAmount → uint256`)
   - `amountRoles(bytes) → AmountMeta[]` (Direction IN/OUT + Denomination TOKEN/ASSETS/SHARES)
   - `replaceCalldataAmounts(bytes, uint256[])` (plural, NOT `replaceCalldataAmount`)
   - `_supportsSizingInterface()` override returning `true` (enables ERC-165 sizing detection in `BaseHook.supportsInterface`)
   - `name()` and `description()` (mandatory, parsed by `tooling/generate_hook_manifest.py` via regex — must be literal string returns)
   - `getOutAmount(address caller)` / `getOutToken(address caller)` are per-caller-context (transient storage keyed by caller), not plain `outAmount()`.
3. **Manifest tooling:** `make build` runs `python3 tooling/generate_hook_manifest.py` + `lint_hook_manifest.py`. Every new `*Hook.sol` under `src/hooks/` MUST have an entry in `tooling/hook-classification.yaml` or lint fails.
4. **Verified Relay contract facts (fetched from `github.com/relayprotocol/relay-depository`, `packages/ethereum-vm/src/RelayDepository.sol`)** — do not guess these:
   - `function depositNative(address depositor, bytes32 id) external payable` — just emits `RelayNativeDeposit(depositorOrSender, msg.value, id)`; `depositor == address(0)` credits `msg.sender`.
   - `function depositErc20(address depositor, address token, uint256 amount, bytes32 id) public` — `safeTransferFrom(msg.sender → depository, amount)` then emits `RelayErc20Deposit(...)`. **Pulls from `msg.sender` — approval to the depository is required**, exactly like Across SpokePool.
   - Overload `depositErc20(address depositor, address token, bytes32 id)` uses the caller's full allowance — we will NOT use this (explicit-amount variant only).
   - Withdrawals/fills: allocator-EIP712-signed `execute(CallRequest, signature)` executing `Call{to, data, value, allowFailure}[]` — this is how the solver runs the destination `txs[]` **atomically in one tx** when `allowFailure == false`. This atomicity is what makes a strict (reverting) adapter safe.
   - Events carry **no indexed params**: `RelayNativeDeposit(address,uint256,bytes32)`, `RelayErc20Deposit(address,address,uint256,bytes32)` — relevant to the pigeon facilitator log filter.
   - Canonical prod depository address `0x4Cd00E387622C35Bddb9b4c962C136462338bC31` on most EVM chains via CREATE2 (`deployments/addresses.prod.json`); **not universal** (e.g. Cronos = `0x59916da825d2d2ec1bf878d71c88826f6633ecca`). Verify per chain at deploy time; chain list is deferred per interview decision.
5. **Architecture recap (from interview):** Relay has NO destination receiver-callback. The solver executes off-chain-quoted `txs[]`. Primary destination path = solver calls `SuperDestinationExecutor.processBridgedExecution` directly (it is `msg.sender`-agnostic; safety = user's signed intent + balance validation). The `RelayAdapter` is the **optional robustness path**, permissionless, following `AcrossV3AdapterV2` internal rules.

---

## 1. Files to create / change

### New source files
| File | Purpose |
|---|---|
| `src/vendor/bridges/relay/IRelayDepository.sol` | Minimal vendor interface (2 deposit functions) |
| `src/hooks/bridges/relay/RelaySendFundsAndExecuteOnDstHook.sol` | Source hook, ERC20 (pre-approved) + native |
| `src/hooks/bridges/relay/ApproveAndRelaySendFundsAndExecuteOnDstHook.sol` | Source hook, ERC20-only with approve-0/approve/deposit/approve-0 |
| `src/adapters/RelayAdapter.sol` | Permissionless destination adapter (optional path) |

### New test files
| File | Purpose |
|---|---|
| `test/mocks/MockRelayDepository.sol` | Mock depository (records calls, pulls ERC20, emits Relay events) |
| `test/unit/hooks/bridges/RelayHooks.t.sol` | Unit tests for both hooks (Helpers-based, mirrors `AcrossHooksV2.t.sol`) |
| `test/unit/adapters/RelayAdapterUnitTests.t.sol` | Unit tests for adapter (mirrors `AdaptersUnitTests.sol` patterns) |
| `test/integration/relay/RelayAdapterE2EFork.t.sol` | Base-fork e2e mirroring `AcrossV3AdapterV2E2EFork.t.sol` |
| `test/integration/relay/RelayHooksFork.t.sol` | Fork test: hook executions against real depository `0x4Cd0…bC31` |

### Modified files (deploy/config/tooling wiring)
| File | Change |
|---|---|
| `script/utils/Constants.sol` | `RELAY_ADAPTER_KEY`, `RELAY_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY`, `APPROVE_AND_RELAY_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY` + per-chain `RELAY_DEPOSITORY_*` constants |
| `script/utils/ConfigBase.sol` | `mapping(uint64 chainId => address relayDepository) relayDepositories;` in `EnvironmentData` |
| `script/utils/ConfigCore.sol` | Per-chain depository assignments (pattern only now; enablement at deploy time) |
| `script/DeployV2Core.s.sol` | Availability flag + check, hooks array `len += 2`, conditional hook deployments, adapter deployment block, address population, post-deploy asserts |
| `script/run/regenerate_bytecode.sh` | Add the 3 contract names |
| `tooling/hook-classification.yaml` | Entries for both hooks |
| `SECURITY.md` | Relay liveness/refund trust assumption |
| Pigeon repo (`/Users/cosming/1.Coding/Superform/pigeon`) | New `src/relay/` facilitator (separate repo task — see §8) |

---

## 2. Vendor interface — `src/vendor/bridges/relay/IRelayDepository.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IRelayDepository
/// @notice Minimal interface for Relay Protocol's RelayDepository (origin-side deposits)
/// @dev Source: github.com/relayprotocol/relay-depository packages/ethereum-vm/src/RelayDepository.sol
interface IRelayDepository {
    /// @notice Deposit native tokens, credited to `depositor` under order `id`
    function depositNative(address depositor, bytes32 id) external payable;

    /// @notice Deposit ERC20 tokens (transferFrom msg.sender), credited to `depositor` under order `id`
    function depositErc20(address depositor, address token, uint256 amount, bytes32 id) external;

    /// @notice The allocator authorized to sign withdrawal/fill requests
    function allocator() external view returns (address);
}
```

Only the explicit-amount `depositErc20` overload is declared (the full-allowance overload is intentionally excluded — explicit amounts are safer and match the approve-exact pattern).

---

## 3. Hook 1 — `RelaySendFundsAndExecuteOnDstHook`

### 3.1 Shape
- `contract RelaySendFundsAndExecuteOnDstHook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow`
- `BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE)`
- **Constructor:** `constructor(address relayDepository_)` → zero-check (`ADDRESS_NOT_VALID` from BaseHook), set `address public immutable RELAY_DEPOSITORY`.
- **No `VALIDATOR` immutable, no sigData handling.** This is the key difference from `AcrossSendFundsAndExecuteOnDstHookV2`: Relay's origin deposit carries **no destination message** — only the `bytes32 id`. The destination `txs[]` (including `initData`/`sigData`) are composed off-chain by the SuperBundler which already possesses the signed intent, so there is nothing to append on-chain.
- `name()` → `"Relay Bridge"`; `description()` → `"Bridges tokens via Relay depository with destination execution by Relay solvers"` (literal strings, manifest parser requirement).

### 3.2 Data layout (52-byte strategy header + hook-specific), total 137 bytes

```solidity
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address token = BytesLib.toAddress(data, 52);
/// @notice         uint256 amount = BytesLib.toUint256(data, 72);
/// @notice         bytes32 depositId = BytesLib.toBytes32(data, 104);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 136);
```

| Field | Type | Offset | Size | Notes |
|---|---|---|---|---|
| placeholder0 | bytes32 | 0 | 32 | reserved header |
| placeholder1 | address | 32 | 20 | reserved header |
| token | address | 52 | 20 | `address(0)` sentinel = native ETH path |
| amount | uint256 | 72 | 32 | input amount; `AMOUNT_POSITION = 72` |
| depositId | bytes32 | 104 | 32 | Relay order id from `/quote` API (generated off-chain by Relay; links deposit → fill → refund) |
| usePrevHookAmount | bool | 136 | 1 | `USE_PREV_HOOK_AMOUNT_POSITION = 136` |

No `value` field (unlike Across): value is derived — `token == address(0) ? amount : 0`. No `destinationChainId` / `outputAmount` / `fillDeadline` fields: Relay binds all of that off-chain to `depositId` in the quote.

Constants:
```solidity
uint256 private constant AMOUNT_POSITION = 72;
uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 136;
uint256 private constant MIN_DATA_LENGTH = 137;
```

### 3.3 `_buildHookExecutions(address prevHook, address account, bytes calldata data)`

```
1. if (data.length < 137) revert DATA_NOT_VALID();                  // custom error, mirror Across
2. decode token@52, amount@72, depositId@104, usePrevHookAmount@136
3. if (usePrevHookAmount) amount = ISuperHookResult(prevHook).getOutAmount(account);
4. if (amount == 0) revert AMOUNT_NOT_VALID();                      // covers prev-hook-amount-zero too
5. if (depositId == bytes32(0)) revert ID_NOT_VALID();              // zero id = unattributable deposit → funds
                                                                    // could not be credited/refunded by Relay
6. executions = new Execution[](1);
   if (token == address(0)) {
       // native
       executions[0] = Execution({
           target: RELAY_DEPOSITORY,
           value: amount,
           callData: abi.encodeCall(IRelayDepository.depositNative, (account, depositId))
       });
   } else {
       // ERC20 — requires prior approval of RELAY_DEPOSITORY (chain an approve hook,
       // or use ApproveAndRelaySendFundsAndExecuteOnDstHook)
       executions[0] = Execution({
           target: RELAY_DEPOSITORY,
           value: 0,
           callData: abi.encodeCall(IRelayDepository.depositErc20, (account, token, amount, depositId))
       });
   }
```

**`depositor` is ALWAYS `account`, never taken from hookData.** This pins Relay's off-chain credit/refund attribution to the smart account, so hookData cannot redirect refunds to an attacker address. (`msg.sender` at execution time is the account anyway, but being explicit removes any ambiguity and matches Relay's `depositor == address(0) → msg.sender` semantics without relying on it.)

Note there is no Across-style `wrappedNativeToken()` staticcall in the chaining path — the native path uses `token == address(0)`, so `build()` makes zero external calls other than `getOutAmount` on chaining. Keep `_buildHookExecutions` `view`.

### 3.4 Sizing/context interface implementations (MANDATORY, current forms)

```solidity
function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
    return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
}

function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
    amounts = new uint256[](1);
    amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
}

function amountRoles(bytes memory) external pure override returns (AmountMeta[] memory meta) {
    meta = new AmountMeta[](1);
    meta[0] = AmountMeta(Direction.IN, Denomination.TOKEN);
}

function _supportsSizingInterface() internal pure override returns (bool) { return true; }

function replaceCalldataAmounts(bytes memory data, uint256[] memory amounts)
    external pure override returns (bytes memory)
{
    if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();   // error inherited from BaseHook
    return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
}
```

### 3.5 `inspect()`

```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    return abi.encodePacked(BytesLib.toAddress(data, 52)); // token only — addresses ONLY, protocol requirement
}
```
`depositId` is not an address and MUST NOT appear in inspect output. Note `pure` is correct here (no immutables read); if you later include `RELAY_DEPOSITORY`, switch to `view`.

### 3.6 Pipe/lifecycle
- No `_preExecute`/`_postExecute`/`_pipeMode` overrides — identical to the Across V2 bridge hooks (default TRANSFORM; bridge hooks are terminal on source, `outAmount` remains 0).

### 3.7 Errors (hook-local)
```solidity
error DATA_NOT_VALID();   // data.length < 137
error ID_NOT_VALID();     // depositId == bytes32(0)
// AMOUNT_NOT_VALID / ADDRESS_NOT_VALID / INVALID_AMOUNTS_LENGTH inherited from BaseHook
```

---

## 4. Hook 2 — `ApproveAndRelaySendFundsAndExecuteOnDstHook`

Identical data layout, constants, sizing methods, `inspect`, and errors as Hook 1 (offsets unchanged: token@52, amount@72, depositId@104, bool@136; length ≥ 137). Differences:

- `name()` → `"Approve and Relay Bridge"`; `description()` → `"Approves and bridges tokens via Relay depository with destination execution by Relay solvers"`.
- **ERC20-only:** after decoding, `if (token == address(0)) revert ADDRESS_NOT_VALID();` (native needs no approval — use Hook 1).
- **Approval hygiene — exact repo pattern from `ApproveAndAcrossSendFundsAndExecuteOnDstHookV2` (approve 0 → approve amount → deposit → approve 0):**

```
executions = new Execution[](4);
executions[0] = { target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (RELAY_DEPOSITORY, 0)) };
executions[1] = { target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (RELAY_DEPOSITORY, amount)) };
executions[2] = { target: RELAY_DEPOSITORY, value: 0,
                  callData: abi.encodeCall(IRelayDepository.depositErc20, (account, token, amount, depositId)) };
executions[3] = { target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (RELAY_DEPOSITORY, 0)) };
```

The leading approve-to-zero handles USDT-style tokens that revert on nonzero→nonzero approvals; the trailing approve-to-zero guarantees no residual allowance to the depository. `abi.encodeCall(IERC20.approve, …)` is fine for USDT because the ERC-7579 account execution does not decode return data (same as the Across hook). The depository itself pulls with Solady `SafeTransferLib`, so non-returning tokens work; **fee-on-transfer / rebasing tokens remain unsupported** (documented limitation, consistent with Across/deBridge).

- Use a private `_buildBridgeExecution(d, account)` helper mirroring the Across ApproveAnd hook to avoid stack pressure.

---

## 5. Destination — `RelayAdapter` (`src/adapters/RelayAdapter.sol`)

### 5.1 Role and trust model
- **Optional robustness path.** Primary path: the Relay solver's `txs[]` (executed atomically via `RelayDepository.execute` with `allowFailure = false`) transfers output funds directly to the account and then calls `SuperDestinationExecutor.processBridgedExecution` directly. Nothing in this plan gates that path.
- The adapter exists for the "atomic pull → forward → best-effort execute (+ self-claim fallback)" flow, mirroring `AcrossV3AdapterV2` internals, but **permissionless** (no `msg.sender` gate — Relay has no on-chain caller we could authenticate; there is no SpokePool equivalent guaranteeing `amount` was just delivered). That permissionlessness forces two additions relative to the Across adapter (see 5.4): a **received-funds guard** and an **escrow accounting guard**.

### 5.2 Contract shape

```solidity
contract RelayAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    /// account => token => amount   (token == address(0) is native ETH)
    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    /// token => total currently escrowed in failedTransfers (protects escrow from permissionless sweeps)
    mapping(address token => uint256 amount) public totalEscrowed;

    struct ExtractedData {         // identical to AcrossV3AdapterV2 / StargateAdapterV2
        address account;
        bytes executorCalldata;
        address[] dstTokens;
        uint256[] intentAmounts;
        bool found;
    }

    constructor(address superDestinationExecutor_) { /* zero-check → ADDRESS_NOT_VALID */ }

    receive() external payable { }   // accepts native pre-funding by the solver in a prior batch call
}
```

No depository reference — deposits are origin-side; the adapter is destination-side and Relay's destination executor address is not a stable authentication anchor.

### 5.3 Entrypoint

```solidity
/// @notice Forwards Relay-filled funds to the intent account and best-effort executes the signed intent
/// @param tokenSent The output token delivered by the Relay fill (address(0) for native)
/// @param amount    The amount delivered for this intent
/// @param message   abi.encode(bytes initData, bytes sigData) — identical 2-field V2 format used by
///                  AcrossV3AdapterV2 / StargateAdapterV2
function processRelayExecution(address tokenSent, uint256 amount, bytes calldata message)
    external
    payable
    nonReentrant
```

Flow (numbered to mirror `AcrossV3AdapterV2.handleV3AcrossMessage`):

```
1. if (amount == 0) revert ZERO_AMOUNT();
2. if (tokenSent != address(0) && msg.value != 0) revert MSG_VALUE_NOT_ALLOWED();  // no stranded ETH
3. (bytes memory initData, bytes memory sigDataRaw) = abi.decode(message, (bytes, bytes));
4. ExtractedData memory extracted = _extractFromSigData(sigDataRaw);
5. if (!extracted.found) revert NO_DST_PROOF_FOR_CHAIN();
   //  Reverting is SAFE and desirable: Relay fill calls are independent txs, and when batched
   //  atomically (allowFailure=false) the revert also unwinds the funds-delivery leg. Same
   //  reasoning as the Across adapter comment (vs Stargate, which must not revert).
6. if (extracted.account == address(0)) revert ACCOUNT_NOT_VALID();
7. // PERMISSIONLESS GUARD — funds must actually be here, excluding other users' escrow:
   uint256 balance = tokenSent == address(0)
       ? address(this).balance                       // includes msg.value
       : IERC20(tokenSent).balanceOf(address(this));
   if (balance - totalEscrowed[tokenSent] < amount) revert INSUFFICIENT_FUNDS_RECEIVED();
8. bool ok = _tryTransfer(tokenSent, extracted.account, amount);   // Stargate-style, native-aware
   if (!ok) {
       failedTransfers[extracted.account][tokenSent] += amount;
       totalEscrowed[tokenSent] += amount;
       emit TransferFailed(extracted.account, tokenSent, amount);
   } else {
       emit TransferSucceeded(extracted.account, tokenSent, amount);
   }
9. try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
       tokenSent, extracted.account, extracted.dstTokens, extracted.intentAmounts,
       initData, extracted.executorCalldata, sigDataRaw
   ) { } catch {
       emit ExecutionFailed(extracted.account);
       // revert reason intentionally discarded (returnbomb/EIP-150 concern, see StargateAdapterV2)
   }
```

`_extractFromSigData` and `_tryTransfer` are **verbatim copies** of `StargateAdapterV2`'s versions (`_tryTransfer` is the native-aware one; `AcrossV3AdapterV2`'s is ERC20-only):

```solidity
(,,,,, ISuperValidator.DstProof[] memory proofDst,) =
    abi.decode(sigDataRaw, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));
// iterate for proofDst[i].dstChainId == uint64(block.chainid); pull info.account, info.data,
// info.dstTokens, info.intentAmounts
```

### 5.4 Why the two extra guards (deviations from AcrossV3AdapterV2 — security-critical)

The Across adapter can trust `amount` because only the SpokePool may call it and the SpokePool has just delivered exactly `amount`. A permissionless adapter cannot:

- **Phantom-credit attack (blocked by step 7):** without the balance check, anyone could call with `amount` larger than what the adapter holds; `_tryTransfer` would fail and credit `failedTransfers[account][token] += amount` with money that doesn't exist, later drained via `claimFailedTransfer` against other users' in-flight funds.
- **Escrow-sweep attack (blocked by `totalEscrowed` in step 7):** an attacker can always produce a *valid* message for their *own* account (they sign their own intent; `processBridgedExecution` validates their signature over their account). Without escrow accounting, they could point `amount` at ERC20/native sitting in the adapter that belongs to *other users' failed transfers* and have it forwarded to themselves. `available = balance − totalEscrowed[token]` excludes escrowed funds. `totalEscrowed` is incremented on failed-transfer credit and decremented in `claimFailedTransfer`.
- **Residual exposure (document, don't fix):** funds parked in the adapter *between* separate txs (non-atomic solver flows) are claimable by any valid message until the legit second leg lands. Mitigation is procedural: the destination `txs[]` MUST be one atomic batch (`allowFailure = false`). Documented in the bundler contract (§7) and NatSpec.

### 5.5 Claim function (native-aware — Stargate pattern, plus escrow bookkeeping)

```solidity
function claimFailedTransfer(address token, uint256 amount) external nonReentrant {
    if (amount == 0) revert ZERO_AMOUNT();
    uint256 available = failedTransfers[msg.sender][token];
    if (available < amount) revert INSUFFICIENT_FAILED_BALANCE();
    failedTransfers[msg.sender][token] = available - amount;
    totalEscrowed[token] -= amount;
    if (token == address(0)) {
        (bool success,) = msg.sender.call{ value: amount }("");
        if (!success) revert ETH_TRANSFER_FAILED();
    } else {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
    emit FailedTransferClaimed(msg.sender, token, amount);
}
```

### 5.6 Errors & events

Errors: `ADDRESS_NOT_VALID`, `ZERO_AMOUNT`, `MSG_VALUE_NOT_ALLOWED`, `NO_DST_PROOF_FOR_CHAIN`, `ACCOUNT_NOT_VALID`, `INSUFFICIENT_FUNDS_RECEIVED`, `INSUFFICIENT_FAILED_BALANCE`, `ETH_TRANSFER_FAILED`.

Events (mirror Across/Stargate V2 naming): `TransferSucceeded(address indexed account, address indexed tokenSent, uint256 amount)`, `TransferFailed(address indexed account, address indexed token, uint256 amount)`, `ExecutionFailed(address indexed account)`, `FailedTransferClaimed(address indexed account, address indexed token, uint256 amount)`.

### 5.7 Byte-compatibility with what the validators sign

- `message = abi.encode(bytes initData, bytes sigData)` — the exact compact 2-field V2 format shared with `AcrossV3AdapterV2`/`StargateAdapterV2`.
- `sigData` is the **raw, opaque `SignatureData` blob** — `abi.encode(uint64[] , uint48, uint48, bytes32 merkleRoot, bytes32[] proofSrc, DstProof[] proofDst, bytes signature)` — exactly what `SuperValidatorBase._decodeSignatureData` expects and what `SuperDestinationValidator.isValidDestinationSignature` verifies inside `processBridgedExecution`. The adapter only *reads* `proofDst` for routing and **forwards `sigDataRaw` untouched**; it never re-encodes, so signatures/Merkle proofs stay valid.
- **Transport asymmetry vs Across (important):** Across V2 hooks fetch `sigData` from the validator's transient `retrieveSignatureData(account)` at source-execution time and pack it into the on-chain bridge message. Relay's origin deposit carries no message, so the **SuperBundler** supplies `abi.encode(initData, sigData)` as destination calldata in the Relay `/quote` `txs[]`. The bundler already possesses the full signed blob (it built the userOp), so no new signing flow is required — only new orchestration (out of scope; separate backend workstream).

---

## 6. Edge cases matrix

| Case | Behavior |
|---|---|
| Hook data `< 137` bytes | `DATA_NOT_VALID` revert in `build()` |
| `amount == 0` (static or after `usePrevHookAmount`) | `AMOUNT_NOT_VALID` |
| `usePrevHookAmount` with `prevHook == address(0)` | `getOutAmount` call on zero address reverts at build — acceptable, matches Across |
| `depositId == bytes32(0)` | `ID_NOT_VALID` (deposit would be unattributable in Relay's system) |
| ApproveAnd hook with `token == address(0)` | `ADDRESS_NOT_VALID` |
| Native hook path: account lacks ETH | account execution reverts at runtime (value transfer) — no hook-level check possible in `view` build |
| ERC20 plain hook without prior approval | `depositErc20`'s `safeTransferFrom` reverts at runtime (documented; chain an approve hook or use ApproveAnd) |
| Adapter: `amount == 0` | `ZERO_AMOUNT` |
| Adapter: ERC20 call with `msg.value > 0` | `MSG_VALUE_NOT_ALLOWED` |
| Adapter: malformed `message` | `abi.decode` revert (safe — atomic batch unwinds fund leg) |
| Adapter: no DstProof for `block.chainid` | `NO_DST_PROOF_FOR_CHAIN` revert (Across rationale: fills independent, revert prevents loss) |
| Adapter: `account == address(0)` | `ACCOUNT_NOT_VALID` |
| Adapter: funds not (fully) delivered | `INSUFFICIENT_FUNDS_RECEIVED` |
| Adapter: account can't receive (non-payable AA / blacklisted token) | credit `failedTransfers` + `totalEscrowed`, emit `TransferFailed`, still attempt executor |
| Adapter: executor reverts | funds already forwarded; `ExecutionFailed` emitted; user's balance intact |
| Adapter replay of consumed message | funds no longer available → step 7 reverts; executor-level replay independently blocked by root marking |
| Unfilled origin deposit | funds sit with Relay depository; refund via Relay's off-chain Oracle/Allocator — **trust assumption**, add to SECURITY.md |

---

## 7. Bundler destination `txs[]` contract (documentation for backend team — no code here)

Per intent, one atomic Relay fill batch (`allowFailure = false` on every call):

**Primary (direct) path:**
1. `Call{ to: outputToken, data: transfer(account, amount) }` (or `Call{ to: account, value: amount }` for native)
2. `Call{ to: SuperDestinationExecutor, data: processBridgedExecution(tokenSent, account, dstTokens, intentAmounts, initData, executorCalldata, sigData) }`

**Adapter (robustness) path:**
1. `Call{ to: outputToken, data: transfer(RelayAdapter, amount) }` (native: skip, put value on call 2)
2. `Call{ to: RelayAdapter, value: nativeAmountOr0, data: processRelayExecution(tokenSent, amount, abi.encode(initData, sigData)) }`

Ordering is mandatory (executor balance checks / adapter funds guard). `depositId` from `/quote` must equal the `depositId` in the source hook data.

---

## 8. Testing plan

### 8.1 Unit — hooks (`test/unit/hooks/bridges/RelayHooks.t.sol`, inherits `Helpers`)
Mirror `AcrossHooksV2.t.sol` structure. `build()` here needs **no `vm.mockCall`** (no external staticcalls except `getOutAmount` on chaining — use existing `test/mocks/MockHook.sol` as prevHook).
- Constructor: zero depository reverts; immutable set; `hookType == NONACCOUNTING`; `subtype() == HookSubTypes.BRIDGE`; `name`/`description` non-empty.
- `build()` ERC20: returns 3 executions total (BaseHook wraps pre/post) with middle = `depositErc20(account, token, amount, id)`, value 0, target = depository.
- `build()` native: middle execution target depository, `value == amount`, calldata `depositNative(account, id)`.
- ApproveAnd: 6 executions total (pre + 4 + post); assert approve-0 / approve-amount / deposit / approve-0 ordering and targets; native token reverts.
- Reverts: short data, zero amount, zero depositId, chained zero prev amount.
- Chaining: `usePrevHookAmount = true` — set MockHook outAmount, assert amount + native value substitution.
- Sizing surface: `decodeAmounts` returns `[amount]`; `amountRoles` `[IN, TOKEN]`; `replaceCalldataAmounts` round-trip (fuzz `uint256` new amount → re-decode); `decodeUsePrevHookAmount`; `supportsInterface(ISuperHookInflowOutflow/ISuperHookOutflow/ISuperHook/ISuperHookInspector/IERC165)`.
- `inspect()` returns exactly 20 bytes = token.

### 8.2 Unit — adapter (`test/unit/adapters/RelayAdapterUnitTests.t.sol`, inherits `Helpers`)
Follow `AdaptersUnitTests.sol` patterns (test contract can play the executor; `NonPayableContract` for native-transfer failure; `MockERC20`; a false-returning/reverting token for ERC20 failure). Build `sigData` with the same helper shape as `MockAcrossSignatureStorageV2` (7-tuple with `DstProof[]`).
- Happy path ERC20: pre-fund adapter, call, assert account received, `TransferSucceeded`, executor called with exact forwarded `sigDataRaw`/`initData` bytes.
- Happy path native: `msg.value == amount`; also native pre-funded via `receive()` then zero-value call.
- Reverts: zero amount; ERC20 + msg.value; malformed message; no DstProof for chain; zero account; `INSUFFICIENT_FUNDS_RECEIVED` (phantom-credit attempt).
- Escrow-sweep regression: create a failed transfer (escrow), then attacker submits own valid message targeting escrowed balance → `INSUFFICIENT_FUNDS_RECEIVED`.
- Failed transfer paths: ERC20 transfer failure → `failedTransfers`/`totalEscrowed` credited, executor still attempted; native to `NonPayableContract` account.
- Claims: partial/full, zero amount, over-claim, native claim, `ETH_TRANSFER_FAILED` when claimer non-payable, `totalEscrowed` decrement.
- Executor revert → `ExecutionFailed` emitted, funds retained by account.
- Fuzz: amounts, message garbage bytes.

### 8.3 Fork integration (`test/integration/relay/`)
- `RelayAdapterE2EFork.t.sol` — mirror `AcrossV3AdapterV2E2EFork.t.sol`: Base fork, deploy `RelayAdapter` against deployed `SUPER_DST_EXECUTOR_BASE` (`0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF`), `deal` USDC to a pranked "solver", solver transfers to adapter then calls `processRelayExecution`; use `MerkleTreeHelper` to build a real signable intent where feasible (follow the Across E2E's sigData construction).
- `RelayHooksFork.t.sol` — Base/Mainnet fork against real depository `0x4Cd00E387622C35Bddb9b4c962C136462338bC31`: execute hook-built executions from a funded account, assert `RelayErc20Deposit`/`RelayNativeDeposit` events (use `vm.recordLogs`; both events have all-non-indexed params — decode from `data`).

### 8.4 Pigeon facilitator (separate repo: `/Users/cosming/1.Coding/Superform/pigeon`)
Pigeon has no relay module (verified: across, axelar, cctp, celer, debridge, hyperlane, layerzero, layerzero-v2, wormhole). New `src/relay/lib.sol` must simulate what Relay does off-chain:
1. **Origin capture:** from `vm.getRecordedLogs()`, filter `topic0 ∈ { keccak256("RelayErc20Deposit(address,address,uint256,bytes32)"), keccak256("RelayNativeDeposit(address,uint256,bytes32)") }` emitted by the given depository address; decode from `log.data` (no indexed params).
2. **Destination fill:** unlike Across, the origin event carries NO destination payload — only `id`. So the facilitator API must accept the destination instructions as parameters, e.g. `helpRelay(address depository, uint256 dstForkId, address outputToken, uint256 outputAmount, Call[] memory dstTxs)`: select dst fork, `deal` output funds to a synthetic solver, prank the solver, execute `dstTxs` in order in one loop (revert on first failure → models `allowFailure=false` atomicity), restore fork.
3. Optional convenience wrappers: `helpRelayDirect(...)` (transfer to account + `processBridgedExecution`) and `helpRelayViaAdapter(...)` (transfer to adapter + `processRelayExecution`).
4. Then v2-core cross-chain e2e test (post-MVP) consumes it like the across facilitator tests do, bumping `lib/pigeon`.

---

## 9. Deployment wiring (follow the UniswapV4/Across precedent in `DeployV2Core.s.sol`)

1. `Constants.sol`: add keys `RELAY_ADAPTER_KEY = "RelayAdapter"`, `RELAY_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "RelaySendFundsAndExecuteOnDstHook"`, `APPROVE_AND_RELAY_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "ApproveAndRelaySendFundsAndExecuteOnDstHook"`; per-chain `RELAY_DEPOSITORY_<CHAIN>` constants as they are approved.
2. `ConfigBase.sol`: `mapping(uint64 chainId => address relayDepository) relayDepositories;` in `EnvironmentData`.
3. `ConfigCore.sol`: assignments mirroring `acrossSpokePoolV3s` block; unconfigured chains stay `address(0)` (auto-skip). Canonical prod address `0x4Cd00E387622C35Bddb9b4c962C136462338bC31` on most EVM chains (CREATE2) — **verify each chain against `relay-depository/packages/ethereum-vm/deployments/addresses.prod.json` at deploy time** (Cronos differs). Chain enablement is a deploy-time decision per interview.
4. `DeployV2Core.s.sol`: availability flag `relayHooks` gated on `relayDepositories[chainId] != address(0)`; hooks array `len += 2`; conditional `HookDeployment`s with `abi.encode(configuration.relayDepositories[chainId])` constructor args; adapter deployed in the adapters section with `abi.encode(superDestinationExecutor)`; populate `HookAddresses`; post-deploy asserts (`RELAY_DEPOSITORY() == configured`, `SUPER_DESTINATION_EXECUTOR() == expected`); skip logs.
5. `script/run/regenerate_bytecode.sh`: add `RelaySendFundsAndExecuteOnDstHook`, `ApproveAndRelaySendFundsAndExecuteOnDstHook`, `RelayAdapter`.
6. `tooling/hook-classification.yaml`:
   ```yaml
   RelaySendFundsAndExecuteOnDstHook:
     actionTypes: [{intent: bridge, stage: instant}]
     legSizing: [sized]
   ApproveAndRelaySendFundsAndExecuteOnDstHook:
     actionTypes: [{intent: bridge, stage: instant}]
     legSizing: [sized]
   ```
   then `make manifest` (runs generator + lint).
7. `SECURITY.md`: add "Relay fill liveness & off-chain refunds" trade-off (unfilled deposits held by Relay depository; refunds depend on Relay's Oracle/Allocator; user-fund *execution* safety anchored in Superform's dst signature + balance validation, Relay affects liveness only).

---

## 10. Task breakdown (MVP-first)

**Phase 1 — MVP contracts + unit tests (self-contained in v2-core, on `pre-dev`):**
1. `IRelayDepository.sol` vendor interface.
2. `RelaySendFundsAndExecuteOnDstHook.sol`.
3. `ApproveAndRelaySendFundsAndExecuteOnDstHook.sol`.
4. `MockRelayDepository.sol` + `RelayHooks.t.sol`.
5. `RelayAdapter.sol`.
6. `RelayAdapterUnitTests.t.sol`.
7. `tooling/hook-classification.yaml` entries + `make manifest` green; `forge build` green.

**Phase 2 — fork integration:**
8. `RelayAdapterE2EFork.t.sol` (Base).
9. `RelayHooksFork.t.sol` (real depository).

**Phase 3 — deploy wiring:**
10. Constants/ConfigBase/ConfigCore/DeployV2Core/regenerate_bytecode changes; dry-run `forge script script/DeployV2Core.s.sol --fork-url ...`.

**Phase 4 — cross-chain e2e (depends on external repo):**
11. Pigeon `src/relay/` facilitator (in the pigeon repo).
12. v2-core cross-chain e2e test consuming it; bump `lib/pigeon`.

**Deferred / out of scope:** SuperBundler `/quote` orchestration (backend workstream, contract documented in §7); non-EVM origins; chain enablement list; fee-on-transfer/rebasing tokens.

---

## 11. Key review points for the implementer (things outdated knowledge gets wrong)

- Use `decodeAmounts`/`amountRoles`/`replaceCalldataAmounts` (array forms) + `_supportsSizingInterface() → true`; the old singular `decodeAmount`/`replaceCalldataAmount` interface no longer exists.
- `getOutAmount(account)` takes the caller context; `MockHook` in tests must be primed accordingly.
- `build()` returns hook executions **wrapped** by BaseHook pre/post — unit tests must expect `n + 2` executions.
- Manifest generator regexes require literal-string `name()`/`description()` and a direct `BaseHook(HookType.X, HookSubTypes.Y)` constructor call.
- The adapter's `sigData` 7-tuple decode must exactly mirror `SuperValidatorBase._decodeSignatureData` and the blob must be forwarded byte-identical.
- Relay hooks take NO validator address (no on-chain sigData append) — do not copy that part of the Across V2 hooks.
- The permissionless adapter MUST keep the `INSUFFICIENT_FUNDS_RECEIVED` + `totalEscrowed` guards; dropping either reintroduces the phantom-credit / escrow-sweep attacks described in §5.4.
- Solidity `0.8.30`, custom errors, NatSpec on all public/external functions, Foundry ≥ 1.3.0, `make forge-test TEST=...` for targeted runs.
