# Best Practices: LZ Message Size Minimization & Compact Encoding

## 1. LayerZero V2 Message Size Limit

**Default: 10,000 bytes**, enforced in `SendUln302._payWorkers()`.
- Configurable via `ExecutorConfig.maxMessageSize` per OApp per pathway
- Value of 0 = use default (10,000)
- Stargate controls the OApp config — Superform cannot unilaterally increase
- Budget ~8-9 KB for composeMsg to leave room for OFT envelope and LZ protocol overhead

## 2. Encoding Strategy Comparison

| Approach | Size Savings | Decode Gas | Security | Complexity |
|----------|-------------|------------|----------|------------|
| `abi.encode` (fewer fields) | Good (1.5-5.5 KB) | Lowest | Best | Lowest |
| `abi.encodePacked` (flat) | Better (~200-400B more) | Medium | Collision risk | Medium |
| Custom assembly | Best | Highest | Must audit carefully | Highest |

**Recommendation: `abi.encode(initData, sigData)` — 2-tuple.**
- Primary savings come from eliminating duplicate data (1-5 KB), not encoding format
- `abi.encodePacked` with two `bytes` fields is ambiguous (can't determine boundary without length prefix)
- `abi.decode` is safe, compiler-generated, ~800-1,500 gas for two bytes fields
- Assembly saves ~400-700 gas — negligible for a cross-chain operation costing 100K+ gas

## 3. Gas Implications

| Method | Est. Gas | Notes |
|--------|----------|-------|
| `abi.decode` (2-tuple) | ~800-1,500 | Compiler bounds checking, safe |
| BytesLib slicing | ~600-1,200 | Memory copies, good API |
| Inline assembly | ~400-800 | No bounds checking, hard to audit |

**Use `abi.decode`.** The 400-700 gas difference is negligible vs. the 100K+ gas for the full compose execution.

## 4. Security: Extracting from sigData vs Separate Fields

**Trust model is unchanged:**
- Executor validates the full signature chain regardless of data source
- Adapter already transfers tokens before validation (accepted design)
- `account`, `executorCalldata`, `dstTokens`, `intentAmounts` extracted from sigData are the same values the validator verifies against the merkle tree
- If adapter picks wrong DstProof entry (chainId mismatch), executor rejects — liveness issue, not security

## 5. How Other Protocols Handle LZ Size Constraints

- **Stargate internally**: Uses `abi.encodePacked` for OFTComposeMsgCodec header, treats composeMsg as opaque bytes
- **OFT standard**: Recommends lightweight compose messages with command ID + minimal parameters
- **LZ design patterns**: "minimal envelope" — only send data that can't be derived on destination

Our approach aligns with the "minimal envelope" pattern — sigData already contains all the redundant fields.

## 6. Stargate Compose Requirements

1. **Taxi mode (mode 0) required** for compose — bus mode doesn't trigger lzCompose()
2. **Adequate compose gas** via `extraOptions` — default 200K may be insufficient
3. **lzCompose must not revert** after sender validation — preserve try/catch pattern
4. **Validate `_from` is registered pool** — `TOKEN_MESSAGING.assetIds(_from)` check

## 7. Future Optimization Paths (if 2-field approach is still tight)

1. Strip `proofSrc` from sigData (unused by destination validator): ~128 bytes
2. Filter `proofDst` to current chain only: ~500+ bytes per extra chain
3. These can be done later as secondary optimizations

## Sources
- [LZ V2 Protocol Overview](https://docs.layerzero.network/v2/developers/evm/protocol-contracts-overview)
- [LZ V2 Default Config](https://docs.layerzero.network/v2/developers/evm/protocol-gas-settings/default-config)
- [LZ V2 Design Patterns](https://docs.layerzero.network/v2/developers/evm/oapp/message-design-patterns)
- [OFT Patterns and Extensions](https://docs.layerzero.network/v2/developers/evm/oft/oft-patterns-extensions)
- [Stargate V2 Composability](https://stargateprotocol.gitbook.io/stargate/v2-developer-docs/integrate-with-stargate/composability)
- [LZ V2 Security Checklist](https://github.com/windhustler/Interoperability-Protocol-Security-Checklist/blob/main/audit-checklists/LayerZeroV2.md)
- [Solidity ABI Spec](https://docs.soliditylang.org/en/latest/abi-spec.html)
