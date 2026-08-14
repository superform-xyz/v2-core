# CCTP Destination Adapter Technical Specification

## Overview
Complete Superform's CCTP V2 cross-chain flow by adding the destination-side `CCTPAdapter`. The source leg already exists (`CCTPSendHook` / `ApproveAndCCTPSendHook` → `TokenMessengerV2.depositForBurnWithHook`, packing the executor payload into `hookData`). This adapter is the missing receiver: it mints the bridged USDC, extracts the payload from the attested message, funds the destination account, and drives `SuperDestinationExecutor.processBridgedExecution` — the same terminal call every other adapter makes.

## Problem Statement / Motivation
CCTP is the cheapest native-USDC rail and is already half-integrated (send hook shipped). Without a destination adapter, a CCTP bridge only delivers USDC to a recipient — Superform's destination hooks (deposit-after-bridge) never run, so CCTP can't be used for the "bridge → deposit into vault" flows that Across/deBridge/Relay/Stargate support. This adapter closes that gap.

## Proposed Solution
A stateless (except a failed-transfer escrow) forwarder modeled on the **V2 adapter template** (`RelayAdapter` is the closest analog — permissionless). The one structural novelty: **CCTP has no push callback.** `MessageTransmitterV2.receiveMessage` only mints to `mintRecipient`; it never forwards `hookData`. So the adapter uses a **pull entrypoint** — a relayer calls `receiveAndExecute(message, attestation)`, and the adapter calls `receiveMessage` itself, then acts on the payload it slices from the attested message.

### Flow
```
receiveAndExecute(bytes message, bytes attestation)  // permissionless, nonReentrant
  1. require(message.length >= 376)                         // header 148 + burn body 228
  2. require(_mintRecipient(message) == bytes32(this))      // fail-fast (also enforced by CCTP)
     // destinationCaller is enforced by MessageTransmitterV2 (require caller == destinationCaller)
  3. pre = USDC.balanceOf(this)
  4. bool ok = IMessageTransmitterV2(TRANSMITTER).receiveMessage(message, attestation)
     require(ok)                                            // reverts on bad attestation anyway
  5. minted = USDC.balanceOf(this) - pre                    // == amount - feeExecuted; donation-proof
  6. bytes hookData = message[376:]                         // tail = burn body hookData
     (initData, executorCalldata, account, dstTokens, intentAmounts, sig)
         = abi.decode(hookData, (bytes,bytes,address,address[],uint256[],bytes))
  7. _tryTransfer(USDC, account, minted)                    // low-level; on fail → failedTransfers escrow
     // if transfer succeeded:
  8. try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
         address(USDC), account, dstTokens, intentAmounts, initData, executorCalldata, sig)
     { emit ExecutionSucceeded(account); }
     catch { emit ExecutionFailed(account); }               // returnbomb-safe bare catch
```
`claimFailedTransfer(account, token)` (nonReentrant) drains the escrow if step 7 failed (blacklisted/paused recipient).

## Technical Considerations
- **Trust anchor:** Circle's attestation authenticates the entire message (incl. `account` and `hookData`). `destinationCaller = adapter` (enforced by the transmitter) makes the adapter the only party that can trigger the mint, so mint + execution are atomic. Hook execution is *additionally* gated by the executor's EIP-1271 signature + Merkle-root replay check.
- **No approvals, no arbitrary calls from adapter context** (LI.FI/Socket precedent): the adapter only `safeTransfer`s USDC and calls the immutable executor. All arbitrary execution happens inside the user's account via the executor.
- **Replay is dual-layered and complementary:** CCTP `usedNonces` blocks re-receiving the same message; executor `usedMerkleRoots` blocks re-using the same signed intent across a *different* transport (the SECURITY.md cross-bridge replay case). Keep both.
- **Balance-delta, not gross:** always forward `post − pre`. Immune to `feeExecuted`, donated balance, and any out-of-band mint. Invariant: adapter USDC balance returns to baseline every call (minus escrowed failures).

## Attack Surface Analysis

### Token Risks
- [x] USDC is standard ERC-20; still use **SafeERC20** + low-level `_tryTransfer` (10.3) — matches V2 adapters.
- [x] Fee-on-transfer / `feeExecuted`: handled by **measuring balance delta**, not trusting `amount` (10.1).
- [x] Blocklist/pausable USDC: `account` on Circle's blocklist → `_tryTransfer` fails → `failedTransfers` escrow (no revert, no strand) (10.5).
- [x] >18 decimals / rebasing: N/A (USDC-only, immutable).

### Reentrancy (§1)
- [x] `receiveAndExecute` + `claimFailedTransfer` are `nonReentrant`.
- [x] CEI: mint → measure → fund account → execute; adapter holds no mutable state except the escrow mapping.
- [x] Destination hooks run arbitrary code — `try/catch` around the executor; guard prevents re-entering `receiveAndExecute`.
- [x] Read-only reentrancy: adapter exposes no price/view consumed elsewhere (1.4).

### Cross-Chain (§16, §33)
- [x] Message replay → CCTP `usedNonces` (reverts) (16.1).
- [x] Intent replay across transports → executor `usedMerkleRoots` (SECURITY.md).
- [x] Verification fully delegated to `MessageTransmitterV2` — no home-grown/short-circuit path (Nomad/Wormhole precedent).
- [x] Origin auth via `destinationCaller == adapter` + immutable transmitter (CrossCurve §41.1).
- [x] `account` is inside the attested body → front-run/griefer cannot redirect funds.
- [x] Finality: `minFinalityThreshold` chosen on source; adapter agnostic; fast mode nets `feeExecuted` in the delta.

### Access Control (§2)
- [x] `receiveAndExecute` permissionless by design (attestation is the gate); no admin surface.
- [x] No owner, no upgrade, no `selfdestruct`; immutable `TRANSMITTER`/`USDC`/`EXECUTOR`.

### Parsing / Bounds (§8, §14)
- [x] `require(message.length >= 376)` before slicing.
- [x] `abi.decode` (bounds-checked) for hookData, not assembly; hookData has no internal length prefix (it's the body tail) so "length lying" is impossible.
- [x] Check `receiveMessage` bool return in addition to revert (8.1).
- [x] Assert `mintRecipient == address(this)` fail-fast.

### Exploit Precedent
| Similar | Vector | Our mitigation |
|---|---|---|
| LI.FI / Socket | arbitrary call + leftover approvals | zero approvals; no arbitrary calls from adapter; execution only inside account via executor |
| Nomad | message replay / spoofed root | delegate all verification to CCTP transmitter; no custom root logic |
| Wormhole | signature-verification bypass | never parse/verify attestation ourselves |
| deBridge/Across (repo) | donation / balance sweep | forward measured delta only |

## Acceptance Criteria

### Functional
- [ ] `CCTPAdapter.receiveAndExecute(bytes,bytes)` mints via `MessageTransmitterV2.receiveMessage`, forwards the **balance delta** to the decoded `account`, and calls `processBridgedExecution` with the 6-field payload.
- [ ] `hookData` decoded as `(bytes initData, bytes executorCalldata, address account, address[] dstTokens, uint256[] intentAmounts, bytes signature)`.
- [ ] Fail-fast: `require(message.length >= 376)` and `require(mintRecipient == address(this))`.
- [ ] Executor call wrapped in returnbomb-safe `try/catch { emit ExecutionFailed }`.
- [ ] `_tryTransfer` failure → `failedTransfers` escrow + `claimFailedTransfer(account, token) nonReentrant`.
- [ ] Constructor `(address messageTransmitterV2, address usdc, address superDestinationExecutor)`, all zero-checked → `ADDRESS_NOT_VALID`.
- [ ] `IMessageTransmitterV2` vendored at `src/vendor/bridges/cctp/IMessageTransmitterV2.sol` (`receiveMessage(bytes,bytes) returns (bool)`).

### Security
- [ ] All Attack Surface Analysis items addressed.
- [ ] Invariants (fuzz/unit): INV-1 adapter net USDC balance unchanged per successful call (baseline); INV-2 donated USDC never forwarded; INV-3 delivered amount == `amount − feeExecuted`; INV-4 no residual token approvals; INV-5 replayed message reverts; INV-6 used root no-ops but funds still delivered.
- [ ] Offsets asserted in a unit test against Circle layout (header 148, hookData 376, mintRecipient@184, amount@216, feeExecuted@312).

### Ops / Deployment
- [ ] `CCTPAdapter` wired into `DeployV2Core.s.sol` (struct field + availability bool + `configuration.messageTransmittersV2[chain]` + USDC + executor), CREATE2 deploy + `_checkAdapterContracts`, `Constants.sol` key, locked-bytecode artifact. **Not** in `hook-sizing-manifest.json` (adapters aren't hooks).
- [ ] Backend/OMS sets the send hook's `mintRecipient` **and** `destinationCaller` to the destination `CCTPAdapter` (config-only; no hook Solidity change).

## Dependencies & Risks
- CCTP V2 chain-availability must match where `CCTPSendHook` is enabled (V2 live on all EVM chains; MessageTransmitterV2 `0x81D4…4B64`, TokenMessengerV2 `0x28b5…cf5d`, same address every chain).
- Design decision (accepted): permissionless + `destinationCaller`-locked means a blacklisted/reverting `account` or malformed hookData would strand the burn — mitigated by the `failedTransfers` escrow for the transfer leg and `try/catch` for the execution leg.
- Confirm `MessageTransmitterV2.receiveMessage` returns `bool` and reverts on bad attestation (framework research: yes).

## Implementation

### src/vendor/bridges/cctp/IMessageTransmitterV2.sol
```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;
interface IMessageTransmitterV2 {
    /// @notice Verifies attestation, marks nonce used, routes to recipient handler (mints). Reverts on bad attestation.
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool success);
}
```

### src/adapters/CCTPAdapter.sol (skeleton — model on RelayAdapter/AcrossV3AdapterV2)
```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IMessageTransmitterV2 } from "../vendor/bridges/cctp/IMessageTransmitterV2.sol";
import { ISuperDestinationExecutor } from "../interfaces/ISuperDestinationExecutor.sol";

/// @title CCTPAdapter
/// @author Superform Labs
/// @notice Destination receiver for CCTP V2 depositForBurnWithHook. Pulls the message (no push callback),
///         mints USDC, forwards the exact mint delta to the account, and runs the SuperDestinationExecutor.
contract CCTPAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IMessageTransmitterV2 public immutable MESSAGE_TRANSMITTER;
    IERC20 public immutable USDC;
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;

    // CCTP V2 wire offsets (MessageV2 header = 148; BurnMessageV2 body fixed = 228)
    uint256 internal constant MINT_RECIPIENT_OFFSET = 184; // 148 + 36
    uint256 internal constant HOOKDATA_OFFSET = 376;       // 148 + 228

    mapping(address account => mapping(address token => uint256 amount)) public failedTransfers;

    error ADDRESS_NOT_VALID();
    error MESSAGE_TOO_SHORT();
    error MINT_RECIPIENT_MISMATCH();
    error RECEIVE_MESSAGE_FAILED();
    error NOTHING_TO_CLAIM();

    event ExecutionSucceeded(address indexed account);
    event ExecutionFailed(address indexed account);
    event TransferFailed(address indexed account, address indexed token, uint256 amount);
    event FailedTransferClaimed(address indexed account, address indexed token, uint256 amount);

    constructor(address messageTransmitter_, address usdc_, address superDestinationExecutor_) {
        if (messageTransmitter_ == address(0) || usdc_ == address(0) || superDestinationExecutor_ == address(0)) {
            revert ADDRESS_NOT_VALID();
        }
        MESSAGE_TRANSMITTER = IMessageTransmitterV2(messageTransmitter_);
        USDC = IERC20(usdc_);
        SUPER_DESTINATION_EXECUTOR = ISuperDestinationExecutor(superDestinationExecutor_);
    }

    function receiveAndExecute(bytes calldata message, bytes calldata attestation) external nonReentrant {
        if (message.length < HOOKDATA_OFFSET) revert MESSAGE_TOO_SHORT();
        bytes32 mintRecipient = bytes32(message[MINT_RECIPIENT_OFFSET:MINT_RECIPIENT_OFFSET + 32]);
        if (mintRecipient != bytes32(uint256(uint160(address(this))))) revert MINT_RECIPIENT_MISMATCH();

        uint256 pre = USDC.balanceOf(address(this));
        if (!MESSAGE_TRANSMITTER.receiveMessage(message, attestation)) revert RECEIVE_MESSAGE_FAILED();
        uint256 minted = USDC.balanceOf(address(this)) - pre;

        (
            bytes memory initData,
            bytes memory executorCalldata,
            address account,
            address[] memory dstTokens,
            uint256[] memory intentAmounts,
            bytes memory sig
        ) = abi.decode(message[HOOKDATA_OFFSET:], (bytes, bytes, address, address[], uint256[], bytes));

        if (!_tryTransfer(account, minted)) {
            failedTransfers[account][address(USDC)] += minted;
            emit TransferFailed(account, address(USDC), minted);
            return;
        }

        try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
            address(USDC), account, dstTokens, intentAmounts, initData, executorCalldata, sig
        ) { emit ExecutionSucceeded(account); }
        catch { emit ExecutionFailed(account); }
    }

    function claimFailedTransfer(address account, address token) external nonReentrant {
        uint256 amount = failedTransfers[account][token];
        if (amount == 0) revert NOTHING_TO_CLAIM();
        failedTransfers[account][token] = 0;
        IERC20(token).safeTransfer(account, amount);
        emit FailedTransferClaimed(account, token, amount);
    }

    function _tryTransfer(address to, uint256 amount) internal returns (bool) {
        (bool ok, bytes memory ret) =
            address(USDC).call(abi.encodeCall(IERC20.transfer, (to, amount)));
        return ok && (ret.length == 0 || abi.decode(ret, (bool)));
    }
}
```

### Tests — test/integration/cctp/CCTPAdapterE2EFork.t.sol
- Fork; use `lib/pigeon/src/cctp/CctpV2Helper.sol` (`_setupTestAttester`, `_signMessage`, `help`) — already imported in `test/.../CCTPHooksFork.t.sol`.
- Craft a real message with `hookData`; sign with the installed attester; call `receiveAndExecute`; assert mint delta forwarded + destination hook (vault deposit) ran.
- Negative/fuzz (from evm-security, 17 cases): wrong attestation, replayed message (revert), used root (no-op + funds delivered), truncated/garbage hookData, `message.length < 376`, `account ≠ signature`, pre-seeded/donated USDC not swept, `mintRecipient`/`destinationCaller` mismatch, executor revert → `ExecutionFailed`, reentrant hook, blacklisted recipient → escrow + claim, cross-bridge replay.
- Unit test asserting the byte offsets (184/216/312/376) against a hand-built CCTP V2 message.

## References & Research
- `research/repo-analysis.md` — V2 adapter template (`RelayAdapter`, `AcrossV3AdapterV2`, `StargateAdapter`), payload contract, deploy wiring, test patterns, `lib/pigeon` CCTP helper.
- `research/framework-docs.md` — CCTP V2 `receiveMessage`, MessageV2/BurnMessageV2 offsets, attester mechanics, addresses/domains.
- `research/evm-security.md` — 9 invariants, 17 tests, precedent mapping (`vulnerabilities.md` §1/§8/§10/§16/§22/§41).
- `research/specflow-analysis.md` — flow + edge-case matrix.
- Code: `src/hooks/bridges/cctp/CCTPSendHook.sol`, `src/adapters/DebridgeAdapter.sol` / `RelayAdapter.sol` / `AcrossV3AdapterV2.sol`, `src/interfaces/ISuperDestinationExecutor.sol`, `src/vendor/bridges/cctp/ITokenMessengerV2.sol`, `lib/pigeon/src/cctp/interfaces/IMessageTransmitterV2.sol`.
