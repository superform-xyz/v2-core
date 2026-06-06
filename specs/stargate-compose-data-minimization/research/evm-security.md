# EVM Security Research: Stargate Compose Data Minimization

## 1. CROSS-CHAIN RISKS

### 1a. Message Replay Protection — LOW (unchanged)
- `usedMerkleRoots[account][merkleRoot]` in executor prevents replay
- V2 adapter still passes full sigData to executor — protection intact

### 1b. Compose Message Manipulation (Permissionless sendCompose) — MEDIUM (existing)
- LZ V2's `sendCompose()` is permissionless — anyone can queue compose
- V2 compact format is slightly easier to craft, but sigData still needs valid ECDSA signature
- **MUST retain** `TOKEN_MESSAGING.assetIds(_from) == 0` check

### 1c. Version Mismatch Between Hook and Adapter — MEDIUM (deployment risk)
- V2 hook sending to V1 adapter: decode panics, caught by try/catch, tokens stuck in failedTransfers
- **Consider** adding version discriminator byte to compose format

## 2. TOKEN TRANSFER RISKS

### 2a. Transfer-Before-Validation — MEDIUM (existing accepted risk)
- Current adapter already transfers before validation — same trust model
- V2 extracts `account` from sigData instead of top-level field
- If wrong DstProof is selected, tokens go to wrong account but executor rejects

**Mitigations:**
- Preserve `preBalance` check pattern
- Add `account != address(0)` check after extraction
- Retain `composeFrom` fallback for zero-account case

### 2b. Empty DstProof / Missing Chain Match — HIGH (new V2 risk)
- If no DstProof matches `block.chainid`, adapter must NOT revert
- **MUST** emit event and return gracefully to avoid blocking compose queue

## 3. DATA PARSING RISKS

### 3a. abi.decode Panic on Malformed Data — MEDIUM (well-mitigated)
- V2 has deeper nesting: 2-level decode + DstProof iteration
- All decoding inside `handleCompose` — panics caught by try/catch in `lzCompose`
- **MUST use bare `catch {}`** — no `bytes memory` (returnbomb protection)

### 3b. ABI Decode Flexible Offset Exploitation — LOW
- Standard `abi.decode` throughout — no mixed assembly/decode
- Validator independently decodes same sigData bytes
- **MUST use `abi.decode` exclusively** — no assembly for sigData parsing

### 3c. DstProof Iteration: Wrong Chain Selection — MEDIUM
- Must iterate proofDst to find `dstChainId == block.chainid`
- Duplicate entries for same chain: adapter uses first match
- **MUST cast `block.chainid` to `uint64` explicitly**
- **Consider** verifying `dstProof.info.executor == address(SUPER_DESTINATION_EXECUTOR)`

## 4. REENTRANCY — LOW (unchanged)
- ERC-20 transfer reentrancy: Stargate pools use standard tokens (USDC, USDT, ETH)
- `handleCompose` gated by `msg.sender == address(this)` — blocks re-entry
- LZ endpoint uses ordered nonce system
- Retain `nonReentrant` on `claimFailedTransfer`

## 5. RETURNBOMB — LOW (existing protection adequate)
- V1's three try/catch boundaries with bare `catch {}` absorb returnbomb
- V2 adds no new external calls in decode path
- **MUST keep all sigData parsing as pure memory operations**

## 6. DOS VECTORS

### 6a. Memory Expansion Gas Bomb — HIGH (most significant new risk)
- Crafted sigData with inflated array lengths can trigger massive memory expansion in `abi.decode`
- V2 decodes deeply nested structure: `SignatureData → DstProof[] → DstInfo` (7+ dynamic fields, 3 nesting levels)
- Primary mitigation: `try this.handleCompose(...) catch {}` absorbs OOG
- 1/64 gas remaining (EIP-150) must be enough for emit + return (~1,400 gas × 64 = 89,600 minimum)

**Mitigations:**
- Add minimum inner payload length check (>= 256 bytes) before deep decode
- Add sanity cap on `proofDst.length` (<= 20 entries)
- Optionally add maximum payload length check (<= 12000 bytes)

## 7. EXPLOIT PRECEDENTS

| Exploit | Relevance | Lesson |
|---------|-----------|--------|
| KelpDAO $292M (2026) | MEDIUM | DVN configuration — ensure 3/3+ DVN setup |
| Tapioca OFT lzCompose (2024) | MEDIUM | Don't trust sender context in compose callbacks |
| CrossCurve $3M (2026) | HIGH | Adapter MUST verify msg.sender == LZ_ENDPOINT |
| UniswapV4Router04 ABI flex (2025) | LOW | Use abi.decode exclusively, no mixed assembly |

## Priority Summary

### MUST HAVE
1. Retain `msg.sender == LZ_ENDPOINT` check
2. Retain `TOKEN_MESSAGING.assetIds(_from) == 0` check
3. Retain `try this.handleCompose(...) catch {}` with bare catch
4. Retain `preBalance` check before failedTransfers credits
5. Retain `account == address(0)` guard with composeFrom fallback
6. Use explicit `uint64(block.chainid)` cast
7. Handle "no matching DstProof" gracefully — emit + return, no revert
8. Keep all sigData parsing as pure memory operations

### RECOMMENDED
9. Minimum inner payload length check (>= 256 bytes)
10. Sanity cap on `proofDst.length` (<= 20)
11. Verify `dstProof.info.executor == address(SUPER_DESTINATION_EXECUTOR)`
12. Version discriminator byte for forward compatibility
13. Retain `nonReentrant` on `claimFailedTransfer`

## Sources
- [KelpDAO Exploit](https://www.coindesk.com/tech/2026/05/09/layerzero-says-it-made-a-mistake-in-usd292-million-kelp-exploit)
- [Tapioca lzCompose](https://composable-security.com/blog/tapioca-oft-can-be-impersonated-through-_lzcompose-with-multiple-compose-messages/)
- [CrossCurve Bridge Exploit](https://blockeden.xyz/blog/2026/03/16/crosscurve-3m-bridge-exploit-axelar-gateway-fabricated-cross-chain-messages/)
- [ABI Decode Gas Bomb](https://medium.com/@0xdeadbeef0x/the-double-edged-sword-of-abi-decode-f81529e62bcc)
- [LZ V2 Security Checklist](https://github.com/windhustler/Interoperability-Protocol-Security-Checklist/blob/main/audit-checklists/LayerZeroV2.md)
- [EIP-150 63/64 Rule](https://rareskills.io/post/eip-150-and-the-63-64-rule-for-gas)
