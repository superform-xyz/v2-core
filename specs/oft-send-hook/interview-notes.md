# OFT Send Hook - Interview Notes

## Date: 2026-05-26

## Feature Summary
Extend the existing Stargate bridge hooks (`StargateSendHook` and `ApproveAndStargateSendHook`) to also support generic LayerZero V2 OFT/OFTAdapter tokens. The immediate use case is the UP OFT token, but the solution should be generic enough for any IOFT-compatible contract.

## Key Decision: Extend, Don't Create New Hooks
Instead of creating separate `OFTSendHook` contracts, add a **mode flag** in the hook's calldata to switch between:
- **Mode 0 (Stargate):** Calls `IStargate.sendToken()` with Stargate-specific `SendParam` (includes `oftCmd` for bus/taxi mode)
- **Mode 1 (OFT):** Calls `IOFT.send()` with standard LayerZero V2 OFT `SendParam` (no `oftCmd`)

## Technical Decisions

### Interface Approach
- Use the standard `@layerzerolabs/oft-evm` `IOFT` interface with `IOFT.send()` for OFT mode
- Call `IOFT.send()` directly (not low-level call) — import both `IStargate` and `IOFT` interfaces
- The two `SendParam` structs are identical except Stargate adds `oftCmd`; use the OFT one as the base

### Data Layout
- Maximize shared layout between Stargate and OFT modes since `dstEid`, `to`, `amountLD`, `minAmountLD`, `extraOptions`, `composeMsg` are identical
- Mode flag placement: let research determine optimal position (early in data for fast branching vs end for backward compat)
- Bundler update will be coordinated in sync with hook redeployment, so no backward compat needed

### Deployment Strategy
- **Replace existing** Stargate hooks in-place (same deployment keys, regenerate bytecode)
- Stargate hooks ARE deployed to production, but bundler update is coordinated
- No new hook keys needed — existing `StargateSendHook` and `ApproveAndStargateSendHook` keys remain

### Compose Message Support
- Full compose message support (same pattern as current Stargate hooks)
- Signature appending from validator transient storage for destination execution

### Token Compatibility
- UP is a standard ERC20 (no fee-on-transfer, rebasing, etc.)
- On Ethereum: `UpOFTAdapter` (0x722ff7C0665F4b1823c9C4cFcDF73A43de5865BD) — wraps existing ERC20, locks tokens before sending
- On Base: `UpOFT` (0x5b2193fDc451C1f847bE09CA9d13A4Bf60f8c86B)
- On HyperEVM: `UpOFT` (0x642fFC3496AcA19106BAB7A42F1F221a329654fe)
- On Flare: `UpOFT` (0xe030A89fd2b7f858c8aA47725679CA25D467dFD1)

## Acceptance Criteria
- [ ] StargateSendHook supports both `IStargate.sendToken()` and `IOFT.send()` via mode flag
- [ ] ApproveAndStargateSendHook supports both modes
- [ ] Existing Stargate tests continue to pass (backward compatible behavior for mode=0)
- [ ] New unit tests for OFT mode
- [ ] Fork integration tests using real UP OFT contracts
- [ ] ComposeMsg signature appending works in OFT mode
- [ ] IStargate interface (IOFT vendor interface added)
- [ ] Bytecode regenerated for updated hooks
- [ ] Mode 0 (Stargate) is the default/unchanged behavior

## UP OFT Addresses (Production)
| Chain | Contract | Address |
|-------|----------|---------|
| Ethereum (1) | UpOFTAdapter | 0x722ff7C0665F4b1823c9C4cFcDF73A43de5865BD |
| Base (8453) | UpOFT | 0x5b2193fDc451C1f847bE09CA9d13A4Bf60f8c86B |
| HyperEVM (999) | UpOFT | 0x642fFC3496AcA19106BAB7A42F1F221a329654fe |
| Flare (14) | UpOFT | 0xe030A89fd2b7f858c8aA47725679CA25D467dFD1 |

## Security Considerations
- Extending production hooks — must ensure Stargate mode is unaffected
- OFTAdapter on Ethereum: approval target is the OFTAdapter itself (it pulls tokens via transferFrom)
- Standard OFT on other chains: no approval needed for native OFT sends (tokens are burned by the OFT contract)
- Cross-chain message trust: same LayerZero V2 trust model as Stargate
- The `stargatePool` field in data layout serves double duty: Stargate pool address OR OFT/OFTAdapter address depending on mode
