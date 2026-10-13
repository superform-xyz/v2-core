# LiquidMesh Swap Hook — Pre-Interview Research

Date: 2026-10-02. Sources: v2-core source, Binance Web3 dev-docs, BSC chain state.
Explicitly NOT sourced solely from the Notion brief.

## 1. Opaque-calldata passthrough IS established precedent

Correction to earlier analysis. Three shipped hooks forward API-returned calldata verbatim:

| Hook | Execution | inspect() commits |
|---|---|---|
| `SwapKyberSwapHook.sol:122` | `Execution({target: KYBER_ROUTER, callData: txData_})` | `outputToken` |
| `SwapOpenOceanHook.sol:126` | `Execution({target: OPENOCEAN_ROUTER, callData: updatedTxData})` | `outputToken` |
| `Swap1InchHook.sol:114` | `Execution({target: AGGREGATION_ROUTER, callData: txData_})` | `outputToken, dstReceiver` |

`SwapOdosV3Hook` is the exception, not the rule: it builds the call via
`abi.encodeCall(IOdosRouterV3.swap, ...)` at `:134`.

**Invariant across all of them: the router is an immutable constructor arg.**
Never caller-supplied. This is the line that matters, not the opacity of the payload.

## 2. Binance /swap returns a DYNAMIC router

Per Binance Web3 dev-docs, `/swap` returns `from, to, data, value, gas, gasPrice`.
The `to` is API-chosen per quote. Quote responses also carry `approveTarget`;
approval responses carry `dexContractAddress`.

This is the real reason the Notion brief put `address router` in calldata — and it
directly conflicts with the immutable-router invariant above. Primary design decision.

## 3. The Binance DEX Router is a selector-dispatch diamond

> **Superseded:** `0xb300…028d` is the generic Binance dispatcher, not the router the hook pins. The pinned router is the LiquidMesh diamond `0xB444…DA5` — see `technical-spec.md` §"Corrections after implementation".

`0xb300000b72DEAEb607a12d5f54773D1C19c7028d` — same address on BSC, Ethereum,
Arbitrum, Optimism, Base (vanity/deterministic deploy). On BSC: **codesize 180 bytes**.

Decompiled dispatcher:
- Reads calldata selector, looks up `keccak(selector, 0x5e12654f390e4153c4f63b3dfcc122cf7876a5cdfb496dccf7284c10517a35c5)`
- `delegatecall`s the address found there; reverts if zero
- EIP-1967 impl slot: `0x0` (empty). EIP-1967 admin slot: `0x0` (empty).

**Implication:** per-selector implementations are mutable by whoever controls that
mapping, with no standard `Upgraded` event to monitor. Code behind a selector we
have validated can change without any observable signal.

NOTE: a web search summary asserted a LiquidMesh router at
`0xB44446b0c8E56988c34f7Ff73Ae904982b5FdDA5`. Unverified — not backed by any source
in that result set. Do not use without on-chain confirmation. *(Later confirmed on-chain and
pinned; see `technical-spec.md` §"Corrections after implementation".)*

## 4. No scaling helper exists for Binance calldata

`SwapKyberSwapHook` supports `usePrevHookAmount` only because KyberSwap ships an
on-chain `IScaleHelper`; the hook calls `KyberSwapScaler.updateTxDataAmounts(...)`
at `:116` to rewrite amounts inside the opaque blob.

Binance dev-docs mention no equivalent. Without one, `usePrevHookAmount` cannot be
supported the Kyber way — the embedded amount in `data` cannot be safely rescaled.

## 5. outputMin is NOT enforced by any aggregator hook

`SwapCalldataLayout.OUTPUT_MIN_OFFSET = 156` exists, but across the aggregator family
it is only *exposed* (`decodeOutputMin`) and packed into the swap header for off-chain
use. Only `PendleUnifiedHook:184` actually enforces (`if (outputMin == 0) revert
MIN_OUT_NOT_VALID()`).

Aggregator slippage protection therefore lives in two places, neither in the hook:
1. the router's own minOut embedded in the opaque calldata
2. `SuperVaultStrategy._processSingleHookExecution:763`
   `if (actualOutput < expectedAssetsOrSharesOut) revert MINIMUM_OUTPUT_AMOUNT_ASSETS_NOT_MET();`
   measured as balance delta via `getOutAmount`.

Source comment on (2): *"this is not to protect the user but rather a honest manager
from doing a mistake"* — manager-supplied sanity check, not a security control.
Also skipped entirely when `usePrevHookAmount` is true.

## 6. Kyber's calldata validation needs an ABI we may not have

`SwapKyberSwapHook:109-111` decodes the opaque blob and enforces the destination token:
```solidity
IMetaAggregationRouterV2.SwapExecutionParams memory swapParams =
    abi.decode(BytesLib.slice(txData_, 4, txData_.length - 4), (SwapExecutionParams));
if (address(swapParams.desc.dstToken) != outputToken) revert OUTPUT_TOKEN_MISMATCH();
```
Replicating this for Binance requires a stable published struct per selector. Given
finding (3) — mutable per-selector diamond, no verified ABI retrieved — this is the
main open technical risk.

## 7. "LiquidMesh" is a vendor name, not a router

Binance dev-docs reference LiquidMesh only as a vendor shortcut for the
`/quote-and-swap` convenience endpoint, alongside `PcsXRfq` for the RFQ path
("Pcs" ≈ PancakeSwap). The Notion brief's "Binance's LiquidMesh DEX router on BSC"
conflates a routing vendor with a contract. Naming in the spec should follow the
contract we actually pin, not the vendor label.

## 8. Other relevant strategy-level facts

- Hooks are blocked from calling SuperVaultAggregator directly (`SuperVaultStrategy:752`)
- Every swap family ships both `SwapXHook` and `ApproveAndSwapXHook` variants
- Shared `SwapCalldataLayout`: header 52B, inputToken 52, outputToken 72, inputAmount 92,
  outputQuote 124, outputMin 156, usePrevHookAmount 188, payloadLength 189, payload 221
