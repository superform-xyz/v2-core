# Aave V4 Spoke Interface Research

## CRITICAL: Position Manager Requirement

All Spoke functions are protected by `onlyPositionManager(onBehalfOf)`. The Superform smart account must either:
1. Be governance-registered as a Position Manager on each Spoke, OR
2. Route through an existing Position Manager (NativeTokenGateway or SignatureGateway)

## Core Function Signatures

```solidity
function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
```

All return `(uint256, uint256)` — likely `(amount, shares)`.

## Token Flow
- **Supply/Repay**: tokens transferred from msg.sender to Hub via `safeTransferFrom`
- **Withdraw/Borrow**: tokens sent from Hub to user
- **Approval target**: Need to verify — likely the Spoke or Hub

## Reserve System
- `reserveId` is sequential uint256, per-Spoke (separate from Hub's `assetId`)
- Reserve struct: `underlying`, `assetId`, `decimals`, `paused`, `frozen`, `borrowable`, `collateralRisk`
- `mapping(uint256 reserveId => Reserve) internal _reserves`

## Position Manager System
- NativeTokenGateway: wraps/unwraps ETH
- SignatureGateway: ERC-20 permits and EIP-712 meta-transactions
- Users must authorize Position Managers to act on their behalf

## Deployed Addresses
- Ethereum mainnet only (chain 1)
- Three Hubs: Core, Prime, Plus
- Spoke partners: Lido, EtherFi, Kelp, Ethena, Lombard
- Use `forge install aave-dao/aave-address-book` for addresses

## Next Steps
- Run `forge install aave/aave-v4` to get exact interface files
- Read `src/spoke/interfaces/ISpoke.sol` (~520 lines) and `ISpokeBase.sol` (~235 lines)
- Verify Position Manager requirement and approval target
