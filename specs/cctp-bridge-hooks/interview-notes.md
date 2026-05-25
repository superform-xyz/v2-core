# CCTP Bridge Hooks - Interview Notes

## Date: 2026-05-05

## Feature Summary
Build CCTP V2 (Circle Cross-Chain Transfer Protocol) bridge hooks for cross-chain USDC transfers with destination execution support. Similar to existing Stargate and Across bridge hooks but using Circle's burn-and-mint mechanism.

## Key Decisions

### CCTP Version & Token Scope
- **CCTP V2** with TokenMessengerV2 (latest, supports fast finality)
- **USDC only** (no EURC support needed for now)

### Destination Execution
- **With destination execution** — same pattern as Stargate hooks: append validator signature to composeMsg for executing operations on the destination chain after USDC is received
- This enables cross-chain yield strategies (bridge USDC → deposit into vault on destination)

### Architecture Pattern
- **Across model** — TokenMessengerV2 address as immutable constructor arg
- Safer than having it in user data since CCTP has a single canonical TokenMessenger per chain
- Constructor: `(address tokenMessenger, address validator)`

### CCTP V2 Parameters
- **destinationCaller**: User-configurable in packed hook data (bytes32). Allows restricting who can call receiveMessage on destination.
- **minFinalityThreshold**: User-configurable in packed hook data (uint32). SDK sets appropriate value per chain for fast vs standard finality.
- **maxBurnAmountPerMessage**: User-configurable in packed hook data (uint256). SDK can set based on per-route limits.

### Hook Scope
- **Send-side hooks only** — no receive hook needed
- Circle's attestation service + off-chain relayers handle the receive side (calling receiveMessage on MessageTransmitter)
- Two hooks following existing patterns:
  1. `CCTPSendHook` — for native flow (if applicable, but USDC is ERC20 so this may not apply)
  2. `ApproveAndCCTPSendHook` — approve + depositForBurn pattern (primary hook since USDC is ERC20)

### Testing Strategy
- **Fork tests + unit tests** (same as Stargate pattern)
- Unit tests with mock TokenMessenger for logic validation
- Fork tests against real TokenMessengerV2 on mainnet for integration

## Security Considerations (Auto-enabled: cross-chain + token)
- CCTP is trusted burn-and-mint — Circle is the trust root
- Approval pattern must follow: approve(0) → approve(amount) → depositForBurn → approve(0)
- destinationCaller restriction prevents unauthorized message claiming
- No oracle dependencies
- No flash loan exposure (burn is irreversible)
- Token is always USDC (no weird token behavior concerns)
