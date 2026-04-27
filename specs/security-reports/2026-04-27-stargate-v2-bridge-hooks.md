# Security Analysis Report

## Metadata
- **Target:** `src/hooks/bridges/stargate/StargateV2SendHook.sol`, `src/hooks/bridges/stargate/ApproveAndStargateV2SendHook.sol`
- **Mode:** review
- **Date:** 2026-04-27
- **Contract Types Detected:** Bridge (LayerZero OFT / Stargate V2)
- **Files Analyzed:** 2 target files + 4 context files (BaseHook, IOFT, BytesLib, Across hooks)
- **Sources:** Vulnerability pattern database, OpenZeppelin audits, LayerZero V2 security checklists, Code4rena reports, Stargate documentation

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 2 | Yes |
| P2 Medium | 4 | No |
| P3 Low | 8 | No |

## Verdict
**FAIL** - 2 blocking findings (P1) should be evaluated before merge. Both are protocol-level/infrastructure concerns rather than contract-level bugs, so they may be accepted as known trade-offs after review.

---

## P0 Findings (Critical - Must Fix)

None found.

---

## P1 Findings (High - Must Fix)

### [P1-1] DVN Configuration Risk -- Single Verifier Exploitability (KelpDAO Attack Pattern)

- **File:** Protocol infrastructure (not contract-level)
- **SWC:** N/A
- **Severity:** P1 High
- **Category:** Cross-Chain / Infrastructure
- **Description:** The hook contracts interact with Stargate V2 OFT pools which rely on LayerZero's DVN (Decentralized Verifier Network) for cross-chain message validation. Stargate V2 uses a 2/2 DVN configuration (Nethermind + LayerZero). If either DVN is compromised, messages could be delayed. If both collude, fraudulent messages can be injected. The hooks append validator signatures to `composeMsg` for destination chain execution, meaning a fraudulent inbound message on the destination could trigger unauthorized SuperDestinationExecutor operations. The $292M KelpDAO exploit (April 2026) demonstrated that compromised DVN infrastructure is a viable attack vector for state-level adversaries.
- **Exploit Scenario:** An attacker compromises both DVNs in the Stargate pathway. They inject a fraudulent cross-chain message with a crafted `composeMsg` that the destination chain's `lzCompose` handler processes, triggering unauthorized operations on the SuperDestinationExecutor.
- **Real-World Precedent:** KelpDAO exploit (April 2026) -- $292M loss via compromised LayerZero DVN infrastructure, attributed to Lazarus Group.
- **Mitigation:** This is an infrastructure-level concern outside the hook contract's control. Superform should: (a) verify all Stargate V2 OFT pools have multi-DVN configs with independent verifiers, (b) implement destination-side validation beyond DVN verification, (c) monitor DVN health via tools like Blockaid's LayerZero DVN audit tool.
- **Reference:** OpenZeppelin -- Lessons from KelpDAO Hack; Chainalysis -- Inside the KelpDAO Bridge Exploit

### [P1-2] composeMsg Impersonation via Nested Compose Messages

- **File:** Destination-side concern (affects `StargateV2SendHook.sol:119-121` and `ApproveAndStargateV2SendHook.sol:122-124`)
- **SWC:** N/A
- **Severity:** P1 High
- **Category:** Cross-Chain / Bridge-Specific
- **Description:** The Tapioca audit revealed that senders have full control over compose messages and can specify nested messages, which allowed anyone to execute operations on behalf of OFT tokens. The Superform hooks encode `composeMsg` with the appended validator signature. On the destination side, the `lzCompose` receiver must validate that the `from` parameter matches the expected OFT contract and `msg.sender` is the EndpointV2 contract. If the destination executor does not properly validate these parameters, a malicious compose message could trigger unauthorized execution.
- **Exploit Scenario:** An attacker sends a crafted OFT transfer with a nested compose message that impersonates the expected Superform compose format. If the destination's `lzCompose` handler doesn't strictly validate `from == expectedOFT && msg.sender == EndpointV2`, the attacker's message could trigger unauthorized SuperDestinationExecutor operations.
- **Real-World Precedent:** Tapioca OFT impersonation vulnerability (Composable Security audit).
- **Mitigation:** Ensure the destination chain's SuperDestinationExecutor strictly validates: (a) `msg.sender == EndpointV2`, (b) `from == expected OFT contract`, (c) the decoded signature in `composeMsg` passes Merkle proof validation before executing any operations. The source-side hooks correctly append signatures, but the destination decoder is the critical validation point.
- **Reference:** Composable Security -- Tapioca OFT Impersonation via lzCompose; LayerZero V2 Interoperability Security Checklist

---

## P2 Findings (Medium - Should Fix)

### [P2-1] Missing `value` Update When `usePrevHookAmount` is True for Native ETH Bridging

- **File:** `StargateV2SendHook.sol:104-113`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Bridge-Specific / Logic
- **Description:** When `usePrevHookAmount` is true, the hook updates `amountLD` to the previous hook's output but does NOT update `d.value` (the native ETH sent with the transaction). For native token OFT pools, the `value` field sent to `IOFT.send()` must account for the bridged amount. If the previous hook's output differs from the original `amountLD`, the `value` will be stale. Compare with `AcrossSendFundsAndExecuteOnDstHook` which handles native token value adjustments.
- **Exploit Scenario:** A user chains a swap hook before `StargateV2SendHook` to bridge native ETH. The swap output differs from the pre-estimated `amountLD`. The `amountLD` gets updated but `value` remains at the original estimate. The transaction either sends excess ETH (stuck in OFT contract) or reverts due to insufficient value.
- **Vulnerable Code:**
```solidity
// StargateV2SendHook.sol lines 104-113
if (d.usePrevHookAmount) {
    uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);
    if (d.amountLD > 0 && d.minAmountLD > 0) {
        d.minAmountLD = Math.mulDiv(d.minAmountLD, outAmount, d.amountLD);
    }
    d.amountLD = outAmount;
    // NOTE: d.value is NOT updated here
}
```
- **Secure Pattern:** For `StargateV2SendHook` (which handles native tokens), consider whether `d.value` should be adjusted proportionally when `usePrevHookAmount` is true, or document that `value` represents only LayerZero messaging fees and not the bridged amount. Note: For `ApproveAndStargateV2SendHook`, this is lower risk since it's ERC20-only and `value` only covers messaging fees.

### [P2-2] OFT Dust Removal Causes Amount Mismatch with minAmountLD

- **File:** `StargateV2SendHook.sol:108-109`, `ApproveAndStargateV2SendHook.sol:111-112`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Bridge-Specific / Arithmetic
- **Description:** LayerZero's OFTCore internally calls `_removeDust()` which truncates amounts not perfectly divisible by the `decimalConversionRate` (10^12 for 18-local / 6-shared decimals). When `usePrevHookAmount` is true and the previous hook returns an amount with trailing precision, the actual `amountSentLD` after dust removal will be less than the provided `amountLD`. If `minAmountLD` was scaled from the pre-dust-removal amount, the transaction may revert because `amountReceivedLD < minAmountLD`.
- **Exploit Scenario:** Previous hook returns 1000000000000000001 (1e18 + 1 wei). Dust removal truncates to 1000000000000000000. The scaled `minAmountLD` expects the pre-truncation amount, causing the OFT to revert.
- **Mitigation:** The SuperBundler should pre-compute dust-removed amounts before encoding `minAmountLD`. Document that `minAmountLD` must account for LayerZero's dust removal behavior.
- **Reference:** OpenZeppelin -- Across Protocol OFT Integration Differential Audit; Code4rena Brix Money Audit

### [P2-3] Missing Bounds Validation in `_decodeBytes`

- **File:** `StargateV2SendHook.sol:179-195`, `ApproveAndStargateV2SendHook.sol:213-229`
- **SWC:** SWC-128
- **Severity:** P2 Medium
- **Category:** Data Encoding / DoS
- **Description:** The `_decodeBytes` function reads `uint256 len` from data at `offset`, then reads `len` bytes via `BytesLib.slice()`. There is no validation that `offset + 32 + len <= data.length` before the slice call. While `BytesLib.slice()` has its own bounds check, the error message will be an opaque `slice_outOfBounds` rather than the descriptive `DATA_NOT_VALID()` error. Additionally, `newOffset = offset + len` could overflow with a crafted `len` value (Solidity 0.8.30 reverts on overflow, but with an opaque panic).
- **Vulnerable Code:**
```solidity
function _decodeBytes(bytes calldata data, uint256 offset)
    private pure returns (bytes memory result, uint256 newOffset)
{
    uint256 len = BytesLib.toUint256(data, offset);
    offset += 32;
    if (len > 0) {
        result = BytesLib.slice(data, offset, len);
    }
    newOffset = offset + len;
}
```
- **Secure Pattern:**
```solidity
function _decodeBytes(bytes calldata data, uint256 offset)
    private pure returns (bytes memory result, uint256 newOffset)
{
    if (offset + 32 > data.length) revert DATA_NOT_VALID();
    uint256 len = BytesLib.toUint256(data, offset);
    offset += 32;
    if (offset + len > data.length) revert DATA_NOT_VALID();
    if (len > 0) {
        result = BytesLib.slice(data, offset, len);
    }
    newOffset = offset + len;
}
```

### [P2-4] lzCompose Execution Separation -- Stuck Funds Risk

- **File:** Protocol architecture (affects both hooks)
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Cross-Chain / Bridge-Specific
- **Description:** In LayerZero V2, tokens are credited first via `lzReceive`, then `lzCompose` executes in a **separate transaction**. If the compose message execution fails (e.g., SuperDestinationExecutor reverts due to invalid Merkle proof, expired signature, or gas issues), tokens will be sitting in the receiving contract without being processed by the destination executor. The tokens are not lost -- they can be recovered -- but the user's cross-chain operation will be incomplete.
- **Mitigation:** Ensure the destination contract implements retry/recovery logic for failed compose executions. LayerZero V2 provides a `lzComposeAlert` mechanism for monitoring. Superform should have operational monitoring for stuck compose messages and manual recovery procedures.
- **Reference:** LayerZero V2 Documentation; LayerZero V2 Interoperability Security Checklist

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] `minAmountLD` Not Recalculated When Original `amountLD` is Zero with `usePrevHookAmount`

- **File:** `StargateV2SendHook.sol:108-113`, `ApproveAndStargateV2SendHook.sol:111-116`
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Arithmetic / Logic
- **Description:** When `usePrevHookAmount` is true and original `amountLD == 0`, the scaling condition `if (d.amountLD > 0 && d.minAmountLD > 0)` is false, so `minAmountLD` retains its stale value while `amountLD` gets replaced with `outAmount`. If `minAmountLD > outAmount`, the OFT send will always revert. The bundler should prevent this configuration, and the existing `amountLD == 0` check on line 115 catches the case where `outAmount` is also 0.
- **Mitigation:** Document that when `usePrevHookAmount=true`, `amountLD` and `minAmountLD` should be set to establish the correct ratio for scaling.

### [P3-2] `_appendSignature` Reverts with Opaque Error on Malformed `composeMsg`

- **File:** `StargateV2SendHook.sol:166-176`, `ApproveAndStargateV2SendHook.sol:199-210`
- **SWC:** SWC-110
- **Severity:** P3 Low
- **Category:** Data Encoding / DoS
- **Description:** `abi.decode(composeMsg, (bytes, bytes, address, address[], uint256[]))` will revert with a generic EVM error if the `composeMsg` is non-empty but malformed. Since data is bundler-constructed and user-signed, this is unlikely in practice but makes debugging harder.
- **Mitigation:** Consider adding a minimum length check before the decode (e.g., `if (composeMsg.length < 160) revert DATA_NOT_VALID()`).

### [P3-3] `inspect()` Returns Minimal Information Compared to Across Pattern

- **File:** `StargateV2SendHook.sol:157-159`, `ApproveAndStargateV2SendHook.sol:160-162`
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Pattern Consistency
- **Description:** Both hooks return only `abi.encodePacked(OFT_CONTRACT)` from `inspect()`. The Across hooks return multiple addresses (recipient, inputToken, outputToken, exclusiveRelayer). This limits off-chain safety tooling's ability to validate hook parameters before signing. The `to` (bytes32 destination) and `dstEid` (destination endpoint) are not inspectable.
- **Secure Pattern:**
```solidity
function inspect(bytes calldata data) external view override returns (bytes memory) {
    if (data.length < MIN_DATA_LENGTH) revert DATA_NOT_VALID();
    return abi.encodePacked(
        OFT_CONTRACT,
        BytesLib.toUint32(data, 32),   // dstEid
        BytesLib.toBytes32(data, 36)    // to
    );
}
```

### [P3-4] `ApproveAndStargateV2SendHook` Does Not Validate `approvalRequired()`

- **File:** `ApproveAndStargateV2SendHook.sol:66-70`
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Token Integration
- **Description:** IOFT exposes `approvalRequired()` which returns false for native/mint-burn OFTs. The constructor does not validate this, so deploying `ApproveAndStargateV2SendHook` for a native-token OFT wastes gas on 3 unnecessary approval calls. The NatSpec correctly documents "For native token transfers, use StargateV2SendHook instead" which mitigates the risk.
- **Secure Pattern:** Add `if (!IOFT(oft_).approvalRequired()) revert ADDRESS_NOT_VALID();` in the constructor.

### [P3-5] Cross-Chain Message Replay via Signature Reuse (Accepted Trade-off)

- **File:** `StargateV2SendHook.sol:119-121`
- **SWC:** N/A
- **Severity:** P3 Low (accepted per SECURITY.md)
- **Category:** Cross-Chain
- **Description:** Per SECURITY.md Known Issue #1, "a user's signed bridging intent may still be executed on the destination chain even after it has been canceled on the source chain." The signature embedded in `composeMsg` could theoretically be extracted and replayed. The destination validator's Merkle root marking mechanism provides some protection.
- **Mitigation:** Already documented as accepted trade-off. Consider adding bridge-specific nonces to compose messages for per-bridge replay protection.

### [P3-6] Code Duplication Across Both Hooks

- **File:** Both files
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Code Quality
- **Description:** `_appendSignature`, `_decodeBytes`, `StargateV2SendData` struct, constants (`USE_PREV_HOOK_AMOUNT_POSITION`, `MIN_DATA_LENGTH`), and `DATA_NOT_VALID()` error are identically duplicated. While consistent with the Across hooks pattern, these are security-critical functions where a fix in one file could be missed in the other.
- **Mitigation:** Extract shared code into a `StargateV2Base` contract or library. This ensures future bug fixes are applied in one location.

### [P3-7] Missing NatSpec on Constructors and Custom Errors

- **File:** Both files (constructors at line 63/66, errors at line 61/64)
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Code Quality
- **Description:** Constructors lack `@param` NatSpec and custom errors lack `@notice` documentation. The BaseHook documents every error with NatSpec annotations. This is consistent with the Across hooks (same gap) but violates the stated coding standard.

### [P3-8] Fee-on-Transfer Token Incompatibility

- **File:** `ApproveAndStargateV2SendHook.sol:139`
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Token Integration
- **Description:** If a fee-on-transfer token is used, the approved `amountLD` will differ from the actual amount transferred to the OFT after fee deduction. Stargate V2 OFTs generally only support standard tokens (USDC, USDT, ETH, STG) which are not fee-on-transfer, so this is a theoretical concern.
- **Mitigation:** Document that fee-on-transfer tokens are not supported.

---

## Attack Surface Summary

- **External Entry Points:** `build()` (view, via BaseHook), `preExecute()`, `postExecute()`, `setExecutionContext()`, `setOutAmount()`, `resetExecutionState()`, `decodeUsePrevHookAmount()`, `inspect()` -- all inherited from BaseHook with proper access control
- **Value Transfer Points:** ETH forwarded via `d.value` to OFT contract for messaging fees; ERC20 approval + OFT send for token bridging
- **Oracle Dependencies:** None -- amounts are bundler-computed and user-signed
- **Cross-Contract Interactions:** `IOFT.send()` (Stargate V2 OFT), `IOFT.token()` (token address query), `IERC20.approve()` (token approval), `ISuperHookResult.getOutAmount()` (previous hook), `ISuperSignatureStorage.retrieveSignatureData()` (validator)
- **Upgrade Mechanisms:** None -- hooks are immutable (no proxy pattern)

---

## Coding Standards Findings

| Standard | Status | Notes |
|---|---|---|
| Locked pragma 0.8.30 | PASS | Both files |
| NatSpec completeness | PARTIAL | Missing on constructors, custom errors |
| Custom errors | PASS | Uses `DATA_NOT_VALID()`, inherits `AMOUNT_NOT_VALID()`, `ADDRESS_NOT_VALID()` |
| Events for state changes | N/A | View/pure hooks with no state changes |
| Checks-Effects-Interactions | PASS | Validations before execution construction |
| OpenZeppelin usage | PASS | `Math.mulDiv`, `IERC20` |
| Import organization | PASS | External first, then Superform |
| Pattern consistency with Across | MOSTLY | Minor deviation on `inspect()` mutability |
| Code duplication | NEEDS WORK | 3 functions + struct + constants duplicated |

---

## Security Knowledge Sources
- **OpenZeppelin:** Across Protocol OFT Integration Differential Audit, KelpDAO Hack Analysis
- **LayerZero V2:** Interoperability Security Checklist (windhustler/GitHub), OFT Documentation
- **Audit Reports:** Zellic -- LayerZero Stargate Audit, Composable Security -- Tapioca OFT
- **Code4rena:** Decent Findings #174 (refund address), #613 (rebalancing fees), Brix Money audit
- **Exploit Analysis:** KelpDAO ($292M, April 2026), Chainalysis report
- **Standards:** SWC-114, SWC-128, SWC-110, ERC-7579
