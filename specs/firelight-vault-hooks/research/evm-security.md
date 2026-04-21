# EVM Security Analysis: Firelight Vault Hooks

## Critical Findings

### [P0] redeem() Does Not Return Assets Atomically
- Standard ERC-4626 redeem() should transfer assets. Firelight's does not.
- Hook MUST be NONACCOUNTING, not OUTFLOW.
- Balance-delta pattern would produce outAmount=0 if typed as OUTFLOW.

### [P1] maxRedeem()/maxWithdraw() Return Misleading Values
- Returns full balance despite async withdrawal semantics.
- Hooks and oracles MUST NOT rely on these for accounting.

### [P1] RequestId Lifecycle Management
- Can requestId be claimed twice? By another address? Become invalid after upgrade?
- Hook must encode requestId in hookData from trusted off-chain source.

### [P1] Cooldown Window Risks
- ~2 day gap between redeem() and claimWithdraw()
- Vault could be upgraded, paused, or drained during this window.
- Shares already burned — no rollback possible.

### [P1] Upgradeable Vault Proxy
- All function behavior can change via proxy upgrade.
- Precedents: AllianceBlock, Kinto Protocol, Ronin Bridge.
- Monitor proxy admin for upgrade transactions.

## Medium Findings

### [P2] FXRP Token Properties
- Bridged token from XRPL via FAssets system.
- Check for: fee-on-transfer, rebasing, pausable, blacklistable.
- Use balance-delta pattern, not return values.

### [P2] Vault Pause Between Phases
- Shares burned but claim blocked = indefinite lockup.
- Mitigate with off-chain monitoring.

### [P2] External Callback Risk
- Upgradeable vault could add callbacks during redeem/claim.
- BaseHook mutex pattern provides protection.
- Validate balance deltas are sensible in postExecute.

## Low Findings

### [P3] Flare Chain EVM Compatibility
- Verify transient storage (EIP-1153) support — BaseHook depends on it.
- Verify Cancun opcodes available.

### [P3] Cross-Chain Oracle Accuracy
- stXRP positions in cooldown should not be priced at full value.

## Recommended Security Patterns
1. NONACCOUNTING for redeem, OUTFLOW for claim
2. Balance-delta measurement, never trust return values
3. Validate address(0) for all decoded addresses
4. Monitor vault proxy for upgrades during cooldown
5. Verify Flare supports transient storage (EIP-1153)
6. Never rely on maxRedeem()/maxWithdraw()
7. Test with actual tokens on Flare testnet
