# SuperVault

SuperVault is an advanced ERC-4626 vault implementation that enables dynamic allocation across multiple yield sources. It provides vault strategists with powerful tools for managing assets while maintaining high security standards and operational efficiency.

## Core Capabilities for Vault Strategists

### 1. Yield Source Management

Strategists can:
- **Add New Yield Sources** (`addYieldSource`)
  - Define a yield source address and its associated oracle
  - Configure deposit and redeem hook pathways
  - Each yield source must have a valid oracle for TVL tracking
  - Hook pathways must end with the SuperLedger hook for accounting

- **Remove Yield Sources** (`removeYieldSource`)
  - Remove yield sources that are no longer desired
  - Only possible when the yield source has 0 allocation
  - Helps maintain a clean and efficient vault configuration

- **Update Hook Pathways** (`updateYieldSourcePathway`)
  - Modify deposit and redeem hook sequences for any yield source
  - Useful for upgrading strategies or fixing issues
  - All hooks must be whitelisted for security

### 2. Asset Allocation Control

- **Set Target Proportions** (`setTargetProportions`)
  - Define percentage allocations across yield sources
  - Proportions must sum to 100% (10000 basis points)
  - Each allocation must be below `maxAllocationRate`
  - Changes affect future deposits/withdrawals

### 3. Vault Configuration Management

Strategists can configure:
- `vaultCap`: Maximum assets per individual yield source
- `superVaultCap`: Maximum total assets across all yield sources
- `maxAllocationRate`: Maximum allocation percentage per yield source
- `vaultThreshold`: Minimum amount for rebalancing operations

### 4. Fee Management

All fee accounting is handled through SuperLedger:
- Management and performance fees tracked per yield source
- Fees calculated and collected through mandatory SuperLedger hook
- Centralized accounting ensures accurate fee distribution
- Transparent fee tracking across all vault operations

### 5. Access Control

- **Transfer Strategist Role** (`transferStrategist`)
  - Transfer strategist permissions to a new address
  - Critical for vault management succession
  - Cannot transfer to zero address

## Deposit Flow

When a user deposits assets into SuperVault:

1. **Initial Validation**
   - Check if deposit amount is within `superVaultCap`
   - Verify sufficient shares can be minted

2. **Asset Transfer**
   - Transfer underlying tokens from user to SuperVault
   - Calculate shares to mint based on current vault value

3. **Allocation Calculation**
   - Calculate deposit amounts per yield source based on target proportions
   - Example: If target is 60%/40% split between two sources and deposit is 100 tokens:
     - Yield Source 1: 60 tokens
     - Yield Source 2: 40 tokens

4. **Hook Execution Per Yield Source**
   - For each yield source with non-zero allocation:
     1. Verify deposit amount is within `vaultCap`
     2. Encode hook data using appropriate encoder (based on vault type)
     3. Execute deposit hook pathway in sequence:
        - Call `preExecute` on each hook
        - Execute hook-specific logic via `build`
        - Call `postExecute` for cleanup
        - Last hook must be SuperLedger for accounting

5. **Share Minting**
   - Mint ERC-4626 vault shares to depositor
   - Shares represent proportional ownership of all yield sources

## Withdrawal Flow

When a user requests a withdrawal:

1. **Initial Validation**
   - Verify sufficient shares are owned/approved
   - Calculate total assets to withdraw based on shares

2. **Withdrawal Calculation**
   - Calculate withdrawal amounts per yield source based on current allocations
   - Example: If current split is 70%/30% and withdrawing 100 tokens worth:
     - Yield Source 1: 70 tokens
     - Yield Source 2: 30 tokens

3. **Hook Execution Per Yield Source**
   - For each yield source with non-zero withdrawal:
     1. Encode withdrawal data using appropriate encoder
     2. Execute redeem hook pathway in sequence:
        - Call `preExecute` on each hook
        - Execute withdrawal logic via `build`
        - Call `postExecute` for cleanup
        - SuperLedger hook records the withdrawal

4. **Share Burning**
   - Burn the redeemed shares
   - Transfer withdrawn assets to recipient

## Security Features

- **Hook Whitelisting**: Only approved hooks can be used in pathways
- **Oracle Integration**: Each yield source requires a price oracle
- **Caps and Limits**: Both per-source and total vault caps
- **Access Control**: Strict strategist-only functions
- **Hook Validation**: No duplicate hooks, required SuperLedger hook

## Example Hook Pathways

A typical deposit pathway might include:
1. Deposit Execution Hook: Handles actual deposit into yield source
2. Stake Execution Hook: Handles actual staking of vault shares into yield source
3. SuperLedger Hook: Records the transaction

A withdrawal pathway could include:
1. Withdrawal Execution Hook: Handles actual withdrawal
2. SuperLedger Hook: Records the transaction

## Future Improvements

### 1. Rebalancing System
- Automated rebalancing of assets across yield sources when the proportions change
- Threshold-based rebalancing triggers
- Gas-optimized rebalancing operations
- Gradual rebalancing to minimize slippage

### 2. Emergency Controls
- Emergency pause functionality
- Circuit breakers for unusual TVL changes
- Timelocked parameter changes
- Emergency withdrawal mechanisms

### 3. Advanced Yield Source Management
- Batch operations for multiple yield sources
- Performance-based scoring system
- Automatic rotation of underperforming sources
- Gradual phase-out mechanism for yield sources

### 4. Enhanced Hook System
- Hook composition for reusable combinations
- Priority-based execution ordering
- Conditional hook execution
- Configurable hook parameters

### 5. Gas Optimizations
- Optimized hook pathway execution
- Batch deposit/withdrawal operations
- Gas cost estimation functions
- Diamond pattern for upgrades