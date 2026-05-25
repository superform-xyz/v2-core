# CCTP Bridge Hooks - EVM Security Research

## Date: 2026-05-06

## Relevant Vulnerability Patterns

### 1. Cross-Chain Risks (vulnerabilities.md Section 16, 33)
- **Message replay**: CCTP V2 handles replay protection internally via nonces in MessageTransmitter. The hook does not need additional replay protection.
- **Bridge trust model**: CCTP is a trusted burn-and-mint model. Circle is the sole trust root — they control the attestation service. This is a centralization risk but accepted by design.
- **Finality assumptions**: `minFinalityThreshold` allows users to choose between fast (< 2000) and standard (>= 2000) finality. Fast finality has reorg risk on some chains.

### 2. Token Integration (vulnerabilities.md Section 10)
- **USDC only**: CCTP exclusively handles USDC, which is:
  - Non-rebasing (no balance change issues)
  - Standard ERC20 with proper return values
  - Has blocklist (addresses can be blacklisted by Circle)
  - Has pause functionality (Circle can pause all transfers)
  - 6 decimals (not 18)
- **Blocklist risk**: If a user's address is blacklisted between signing and execution, the approve/burn will fail. This is acceptable — the transaction simply reverts.
- **Pause risk**: If USDC is paused globally, all CCTP operations fail. This is a systemic risk, not specific to the hook.

### 3. Approval Race Conditions (vulnerabilities.md Section 10.3)
- **Pattern**: approve(0) → approve(amount) → depositForBurn → approve(0)
- This 4-execution pattern prevents the ERC20 approval race condition
- The reset to 0 after the call prevents lingering approvals

### 4. Reentrancy (vulnerabilities.md Section 1)
- **Low risk**: `_buildHookExecutions` is a view function that only constructs calldata
- Actual execution happens through the account's execution flow with BaseHook's pre/post protection
- USDC does not have ERC-777 callbacks, so no reentrancy via token callbacks

### 5. Access Control (vulnerabilities.md Section 2)
- **destinationCaller**: When set to non-zero, restricts who can call `receiveMessage` on destination
- **Recommendation**: SDK should always set destinationCaller to a Superform-controlled address for security

### 6. Flash Loan Exposure (vulnerabilities.md Section 5)
- **None**: CCTP burn is irreversible within a transaction. Flash-loaned USDC cannot be burned and recovered in the same transaction.

### 7. MEV/Sandwich (vulnerabilities.md Section 6)
- **Low risk**: CCTP is 1:1 mint (minus fee), no slippage or price impact. No sandwich attack vector.

### 8. Data Validation
- Must validate `mintRecipient != bytes32(0)` — burning to zero recipient would lose funds permanently
- Must validate `burnToken != address(0)` — would revert at TokenMessengerV2 but should catch early
- Must validate `amount != 0` — no-op protection

## Exploit Precedents

### Bridge Exploits (vulnerabilities.md Appendix K, L)
- Bridges have 2.6x financial impact vs occurrence (Halborn Top 100)
- Notable bridge exploits: Ronin ($624M), Wormhole ($326M), Nomad ($190M)
- These exploits targeted bridge message verification or admin key compromise
- CCTP's model is different: Circle controls attestation centrally, making it resistant to the typical bridge exploit patterns

### Relevant CCTP-Specific Risks
1. **Circle centralization**: If Circle's attestation service is compromised, arbitrary mints could occur. This is inherent to the trust model.
2. **$10M per-message limit**: Prevents catastrophic loss from a single compromised attestation.
3. **Deprecation risk**: CCTP V1 deprecating July 2026 — must ensure V2 interface is correct.

## Attack Surface Map

| Surface | Risk Level | Mitigation |
|---------|------------|------------|
| Approval front-running | Low | approve(0) pattern |
| Zero recipient burn | Critical | Validate mintRecipient != 0 |
| Data length manipulation | Medium | Strict length validation |
| hookCallData injection | Low | Validator signature verification |
| USDC blocklist DoS | Low | Transaction reverts gracefully |
| Circle attestation compromise | Critical | Outside hook scope (systemic) |

## Recommended Invariant Tests

1. `invariant_approvalAlwaysReset` — After execution, TOKEN_MESSENGER approval should be 0
2. `invariant_noNativeValueSent` — All execution values should be 0
3. `invariant_correctExecutionCount` — Should always produce exactly 4 executions (+ pre/post = 6)
4. `invariant_burnTokenInInspector` — Inspector should always return the burnToken address
