## 1. Test Setup Configuration
### 1.1 Vault Creation Setup
- Deploy vault trio using SuperVaultFactory
- Initialize with USDC (6 decimals) as underlying asset
- Set up test roles: manager, strategist, emergency admin

### 1.2 Yield Source Configuration
- Add at least 2 real ERC4626 yield sources
    - Morpho Vault: 0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458
    - Aave Vault: 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6
- Set vaultThreshold = 100_000e6
- Configure vaultCap = 1M, superVaultCap = 5M per yield source
- Set maxAllocationRate = 50% (5_000 bps)

### 1.3 Hook Configuration
- Set hook root containing allowed hooks:
  - Deposit4626Hook
  - Withdraw4626Hook
- Configure merkle proofs for hook validation

## 2. Core Functionality Tests
### 2.1 Deposit Flow
- User1 requests 1000 USDC deposit
   - Verify pendingDepositRequest updated
   - Check USDC transferred to vault
   
- Strategist fulfills deposit with Deposit4626Hook:
   - Allocate to YieldSourceA
   - Verify shares minted to escrow
   - Check maxMint updated
   - Verify deposit event emitted

- User1 claims deposit
   - Verify shares transferred from escrow
   - Check balance updates

### 2.2 Redeem Flow
- User2 requests 500 shares redemption
   - Verify shares escrowed
   - Check pendingRedeemRequest updated

- Strategist fulfills redeem with Withdraw4626Hook:
   - Withdraw from YieldSourceB
   - Verify assets available for withdrawal
   - Check maxWithdraw updated

- User2 claims redemption
   - Verify USDC received
   - Check share burning

## 3. Edge Case Tests
### 3.1 Request Management
- Test deposit cancellation before fulfillment
    - Verify assets returned to user
    - Check pending request cleared

- Test redeem cancellation before fulfillment
    - Verify shares returned to user
    - Check pending request cleared

- Test fulfillment with insufficient assets
    - Should revert with INVALID_AMOUNT

### 3.2 Multi-User Scenarios
- 3 users deposit different amounts (1k, 5k, 10k)
- 2 users redeem different amounts (500, 1500)
- Strategist matches requests:
    - Verify direct share transfer between users
    - Check no yield source interaction
    - Validate partial matches

### 3.3 Allocation Tests
- Strategist allocates 50k USDC to YieldSourceA
    - Verify hook execution
    - Check yield source balance
    - Validate allocation rate compliance

- Attempt overallocation beyond vaultCap
    - Should revert with VAULT_CAP_EXCEEDED

## 4. Configuration Tests
### 4.1 Role-Based Access
- Test non-strategist attempting fulfillment (revert)
- Test non-manager modifying global config (revert)
- Test emergency admin withdrawal when enabled

### 4.2 Configuration Updates
- Update global config:
    - Reduce vaultCap to 500k
    - Test existing allocation compliance
   
- Change fee configuration:
    - Set 100 bps fee
    - Verify fee deduction on profitable redemption

## 5. Special Scenarios
### 5.1 Emergency Mode
- Enable emergency withdrawals
- Emergency admin withdraws free assets
   - Verify bypass normal withdrawal process
   - Check recipient balance update

### 5.2 Yield Source Management
- Deactivate yield source with balance (should revert)
- Withdraw all funds and deactivate
- Reactivate with sufficient threshold

## 6. Verification Points
For All Tests:
- Check vault/strategy/escrow state consistency
- Validate event emissions
- Verify ERC4626 compliance
- Check proper fee calculations
- Validate hook authorization
- Test boundary conditions (max caps, zero values)