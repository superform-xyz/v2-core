# OFT Send Hook - EVM Security Research

## Executive Summary

Extending StargateSendHook/ApproveAndStargateSendHook to support generic OFT tokens via a mode flag introduces several security risk categories. The most critical are: (1) approval target divergence, (2) msg.value semantic differences, and (3) DVN trust model variability.

## 1. Cross-Chain Bridge Risks

### DVN Trust Model
- LayerZero V2 delegates security config to the application layer (DVN selection per OApp/OFT)
- Different OFTs may have wildly different DVN configs (some 1-of-1 DVN = compromisable)
- **KelpDAO exploit (Apr 2026, $292M)**: 1-of-1 DVN, compromised RPC nodes
- Hook cannot validate DVN quality — trust inherited from OFT deployer

### Message Replay & Finality
- LZ V2 uses nonce-based ordering at Endpoint level
- Existing SECURITY.md item #1 applies equally to both modes

## 2. Token Approval Patterns — Critical

### Stargate Mode
- Approval target: **Stargate pool** (well-known, audited)
- Pool validates via `IStargate.token()` matching inputToken

### OFT Mode — Different Trust Model
- **OFTAdapter**: Approval target is the OFTAdapter contract itself
- **Native OFT**: No approval needed (OFT burns from caller directly)
- **Risk**: A malicious contract implementing IOFT interface could drain approved tokens
- **Mitigation**: Whitelist verified OFT addresses, or validate `IOFT.endpoint()` returns canonical endpoint

### Three Distinct Approval Patterns
| Mode | Approval Target | Approval Needed? |
|------|----------------|-----------------|
| Stargate (ERC20) | Stargate pool | Yes |
| OFTAdapter | OFTAdapter contract | Yes |
| Native OFT | N/A | No |

## 3. Mode Flag Security

### Calldata Mode Switching Attack
- Same bytes interpreted differently depending on mode
- If mode changes field semantics, wrong-mode execution could approve wrong contract
- **Mitigation**: Place mode flag early, validate strictly, revert on unknown values

### Calldata Injection
- Hook holds approvals and makes calls with user-controlled data — fits the injection pattern
- $17M+ lost in Jan 2026 from similar patterns
- Mode flag adds dimension of user-controlled behavior

## 4. Native Token (msg.value) — Critical Divergence

| Mode | msg.value |
|------|-----------|
| Stargate native pool | `lzNativeFee + amountLD` |
| Generic OFT / OFTAdapter | `lzNativeFee` only |

**Wrong msg.value consequences:**
- Sending `lzNativeFee + amountLD` to OFT: excess ETH stuck in OFT contract (potential permanent loss)
- Sending only `lzNativeFee` to Stargate native: revert (safe, but DoS)

## 5. OFT-Specific Risks

### Burn/Mint vs Lock/Unlock
- OFT burns are irreversible on source; if destination mint fails, tokens destroyed until retry
- Stargate/OFTAdapter lock tokens safely in pool/adapter

### Dust and Decimal Conversion
- OFT shared decimals (default 6) truncate precision
- `uint64` cast in `_toSD` silently truncates amounts > ~18.4 tokens (18 decimals)
- minAmountLD may pass on source but destination receives truncated amount

## 6. Compose Message Trust

- Both modes use LZ compose pattern
- Destination `lzCompose` receives `from` = source OFT/pool address
- Destination executor must accept compose from both Stargate pools AND OFT contracts
- Same compose message format: `abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)`

## 7. Production Replacement Risks

- Locked bytecode system: "prevents contract modification post-audit"
- CREATE2 with same salt + different bytecode = different address = new deployment anyway
- Existing signed intents referencing old hook addresses unaffected (new address)

## 8. Gas Impact

Mode branching overhead: ~100-300 gas total — **negligible** compared to bridge call (100,000+ gas).

## 9. Known Exploits

| Exploit | Date | Amount | Relevance |
|---------|------|--------|-----------|
| KelpDAO rsETH | Apr 2026 | $292M | 1-of-1 DVN compromise |
| Calldata Injection | Jan 2026 | $17M+ | Contracts with approvals + user-controlled data |
| Cork Protocol (Uni V4 hooks) | May 2025 | $11M | Hook callback authorization bypass |

## 10. Recommendations

### Must Have
1. **Validate mode flag strictly** — revert on unknown values
2. **Separate msg.value computation per mode** — critical for fund safety
3. **Clean approval patterns per mode** — correct target, always reset to 0
4. **Token validation per mode** — OFTAdapter: `IOFT.token() == inputToken`

### Recommended
5. **Document DVN trust assumptions** — security depends on OFT deployer's DVN config
6. **Verify compose message from-address on destination** — update executor whitelist

### Note on Whitelist
The security research strongly recommends whitelisting OFT addresses. However, the existing Stargate hooks also don't whitelist pool addresses — they rely on `IStargate.token()` validation and bundler trust. The same trust model can apply to OFT mode with `IOFT.token()` validation.
