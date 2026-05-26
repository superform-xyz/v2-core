# EVM Security Analysis: StargateAdapter Compose Receiver

## 1. RELEVANT VULNERABILITY PATTERNS

### 1.1 Reentrancy via ETH Forwarding -- SEVERITY: MEDIUM

The adapter executes `account.call{value: address(this).balance}("")` for native ETH, followed by `processBridgedExecution()`. The `call{value}` forwards all gas to the recipient.

**Why Medium (not Critical):**
- LZ EndpointV2 provides compose-level replay protection via `composeQueue` hash
- `SuperDestinationExecutor` marks merkle roots used BEFORE `_execute()` (line 127-130)
- `_processHook` has `nonReentrant` modifier
- Existing adapters (AcrossV3, Debridge) use same pattern WITHOUT ReentrancyGuard

**Recommendation**: Maintain consistency with existing adapters. Layered defense is sufficient.

### 1.2 Token Balance Inflation / Donation Attack -- SEVERITY: MEDIUM-HIGH

**The Two-Transaction Gap**: `lzReceive` and `lzCompose` execute in SEPARATE transactions. Between them, an attacker CAN send additional tokens to the adapter, inflating what gets transferred.

**Impact is LIMITED because:**
- Extra tokens go to the user's account (not attacker)
- `processBridgedExecution()` validates `intentAmounts` independently
- Attacker loses donated tokens
- Real risk: **dust from failed composes** swept to next compose's target

**Recommendation**: Accept balance-based transfer per design decision. Document dust behavior.

### 1.3 Compose Message Authentication -- SEVERITY: CRITICAL (if mishandled)

Two mandatory validations per LZ V2 Security Checklist:
1. `msg.sender == LZ_ENDPOINT` (NON-NEGOTIABLE)
2. `_from` validation (optional per interview decision)

**Assessment**: Endpoint-only validation sufficient because:
- Endpoint verifies compose hash before calling `lzCompose`
- `processBridgedExecution()` validates merkle root signature independently
- An attacker would need valid user signature even with forged compose

### 1.4 Cross-Chain Message Replay -- SEVERITY: LOW

LZ endpoint provides built-in replay protection:
- `composeQueue[_from][_to][_guid][_index]` stores message hash
- Cleared after execution, preventing replay
- `SuperDestinationExecutor.usedMerkleRoots` provides second layer

**No adapter-level replay protection needed.**

### 1.5 ETH Handling Edge Cases -- SEVERITY: MEDIUM

- **Non-payable accounts**: `call{value}` fails -> compose reverts -> stays in queue for retry (safe degradation)
- **`receive()` required**: StargatePoolNative `_credit()` sends ETH via `call{value}`. Without `receive()`, `lzReceive` reverts permanently
- **Gas limits**: `call{value: balance}("")` forwards all gas (correct per ConsenSys guidance)
- **Unexpected ETH**: Anyone can send ETH to adapter -> swept to next compose target

### 1.6 `_from.token()` Call Reliability -- SEVERITY: LOW

- `_from` set by LZ endpoint from compose queue (populated during legitimate `lzReceive`)
- Attacker cannot manipulate `_from` without controlling LZ infrastructure
- If `token()` reverts, compose reverts but is retryable (liveness issue, not fund loss)

## 2. EXPLOIT PRECEDENTS

| Protocol | Date | Loss | Attack | Relevance to StargateAdapter |
|----------|------|------|--------|------------------------------|
| Nomad Bridge | Aug 2022 | $190M | Auth bypass via zero trusted root | `msg.sender` check prevents. LZ endpoint is immutable CREATE2. |
| Wormhole | Feb 2022 | $326M | Signature verification bypass | Two-layer verification (LZ endpoint + merkle root) mitigates. |
| Ronin Bridge | Mar 2022 | $625M | Validator key compromise | LZ DVN infrastructure is trust assumption. Not code-level risk. |
| KelpDAO/LZ | Apr 2026 | $292M | Single-verifier DVN compromise | DVN config is Stargate's responsibility, not adapter's. |
| LZ MPT Vuln | 2022 | N/A | Malformed proof bypass | Fixed in LZ V2. |

## 3. ATTACK SURFACE MAP

```
[EXTERNAL CALLERS]
      |
      v
+-----------------------+
| lzCompose()           |  <-- Entry point
|  GATE 1: msg.sender   |  <-- Must be LZ_ENDPOINT
|  GATE 2: _from        |  <-- Not validated (design decision)
+-----------+-----------+
            |
            v
+-----------------------+
| OFTComposeMsgCodec    |
| decode _message[76:]  |  <-- RISK: Malformed message -> OOB reads
+-----------+-----------+
            |
     +------+------+
     |             |
     v             v
  [ETH PATH]    [ERC20 PATH]
  call{value}   safeTransfer
  to account    to account
     |             |
     +------+------+
            |
            v
+-----------------------+
| processBridgedExecution|
|  GATE 3: Signature    |  <-- Merkle root + signature validation
|  GATE 4: Balance      |  <-- intentAmounts vs actual
|  GATE 5: Replay       |  <-- usedMerkleRoots dedup
|  GATE 6: Reentrancy   |  <-- nonReentrant on _processHook
+-----------------------+

Trust Assumptions:
1. LZ EndpointV2 (0x1a44...728c) is secure/immutable
2. LZ DVN/Executor infrastructure not compromised
3. _from.token() returns accurate results
4. SuperDestinationExecutor validation is sound
```

## 4. RECOMMENDED SECURITY PATTERNS

### MUST IMPLEMENT
- `msg.sender == LZ_ENDPOINT` check
- `receive() external payable {}` for native ETH
- ETH transfer failure handling with revert
- `SafeERC20.safeTransfer` for ERC20

### RECOMMENDED (Defense-in-Depth)
- Validate `_message.length >= 76` before OFTComposeMsgCodec decode
- Consider validating `_from.code.length > 0`

### NOT NEEDED
- ReentrancyGuard (inconsistent with existing adapters, layered defense sufficient)
- Replay protection (LZ endpoint + executor handle this)
- `_from` whitelist (endpoint validation sufficient)

## 5. TESTING RECOMMENDATIONS

### Fuzz Tests
- Message length fuzzing (should revert for < 76 bytes)
- Token amount fuzzing (full balance transfer)
- ETH amount fuzzing (full balance forwarded)

### Invariant Tests
- No funds stuck after successful compose
- Only LZ endpoint can call lzCompose

### Exploit Scenario Tests
- Token donation before compose (extra tokens go to account)
- Reentrancy via malicious account receive()
- Failed compose retry with dust accumulation
- Unauthorized caller reverts
- Non-payable account ETH transfer failure
- Zero-balance compose (executor handles gracefully)

### Flash Loan Assessment
**NOT a viable attack vector**: Attacker doesn't control when `lzCompose` is called, can't combine with flash loan in same tx.

## Sources
- [LZ V2 Security Checklist](https://github.com/windhustler/Interoperability-Protocol-Security-Checklist/blob/main/audit-checklists/LayerZeroV2.md)
- [Solodit Donation Attack Checklist](https://www.cyfrin.io/blog/solodit-checklist-explained-3-donation-attacks)
- [ConsenSys: Stop Using transfer()](https://consensys.io/diligence/blog/2019/09/stop-using-soliditys-transfer-now/)
- [KelpDAO LZ Exploit Analysis](https://www.cryptotimes.io/2026/05/20/layerzero-details-single-verifier-flaw-behind-292m-kelpdao-exploit/)
