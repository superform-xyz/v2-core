## Contract 1 : SuperUSD

### 1.0: Followed Interface

We won't follow any specific standard, just taking inspiration from EIP5115 since it is a multi-assets Vault 

### 1.1. State

1.1.1 Underlying Vault Whitelist 

1.1.2 For Pricing 

```
mapping(address => boolean) isVault; 
mapping(address => boolean) isERC20;
```

### 1.2. State Changing Functions

1.2.1 Token Movement 

1.2.1.1 Deposit 

```solidity
function deposit(
address receiver,
address tokenIn,
uint256 amountTokenToDeposit,
uint256 minSharesOut,
// bool depositFromInternalBalance // Can ignore? 
    ) external returns (uint256 amountSharesOut);

```

- Implementation
    - Shares
        - Deposit one of the underlying whitelisted assets
        - Swap Fees
            - SwapFees should be charged on input token, as it was discussed to keep in the Swap Fees Fund only the underlying vault shares and no SuperUSD shares
            - Swap Fees need to be sent to the Swap Fees Fund defined below here
        - For the amount of input shares, subtracting swap fees, an equivalent amount of SuperUSD shares is minted to the user according to the underlying vault shares price, obtained by calling the getPrice() function (see below)
    - Incentives
        - Incentives are calculated by calling the ICC Contract and
        - Incentives Settled calling the function of the Incentive Fund Contract

1.2.1.2 Redeem 

```solidity
function redeem(
address receiver,
uint256 amountSharesToRedeem,
address tokenOut,
uint256 minTokenOut,
// bool burnFromInternalBalance // Can ignore? 
    ) external returns (uint256 amountTokenOut);
```

- Implementation
    - Shares
        - Deposit SuperUSD shares and specifies output underlying vault shares
        - The equivalent amount of underlying vault shares is calculated calling the getPrice() function
        - Swap Fees
            - SwapFees should be charged on output token, as it was discussed to keep in the Swap Fees Fund only the underlying vault shares and no SuperUSD shares
            - Swap Fees and to be sent to the Swap Fees Fund defined below here
        - SuperUSD shares are burned and the equivalent amount of underlying vault shares, subtracting swap fees, is sent to the user
    - Incentives
        - Incentives are calculated by calling the ICC Contract and
        - Incentives Settled calling the function of the Incentive Fund Contract

1.2.1.3 Swap()  

```solidity
function swap(
address receiver,
address tokenIn,
uint256 amountTokenToDeposit,
address tokenOut,
uint256 minSharesOut,
uint256 minTokenOut,
bool depositFromInternalBalance // Can ignore
    ) external returns (uint256 amountTokenOut) {
    
    uint256 amountSharesOut = deposit(address(this), tokenIn, amountTokenToDeposit, minSharesout);
    amountTokenOut = redeem(receiver, tokenOut, amountSharesOut, minTokenOut);
    
    
    }

```

Its implementation is going to consist of just chaining deposit() and redeem() 

1.2.2 Underlying Vault Shares Whitelist Management 

TBD but pretty simple whitelist management logic 

### 1.3. View Functions

1.3.1 Preview Functions  corresponding to the state changing ons 

```solidity
function previewDeposit(address tokenIn,uint256 amountTokenToDeposit)
external view returns (uint256 amountSharesOut, int256 amountIncentives);

function previewRedeem(address tokenOut,uint256 amountSharesToRedeem)
external view returns (uint256 amountTokenOut, int256 amountIncentives);

function previewSwap(address tokenIn, uint256 amountTokenToDeposit, address tokeOut) external view returns (uint256 amountSharesOut, int256 amountIncentives);

```

Same calculation logic as in the mint() and redeem() functions explained above, but only the view part of it so no token transfers 

- Note
    - It is important to return in the preview functions both the amount of assets or shares and the incentives but this would break the interface so the proposal is to create an extension to it
    - The preview should include swap fees.

1.3.2 Circuit Breaker Functions 

1.3.2.1 Has underlying stable depegged

```solidity
function isDepeg(
address tokenIn
) public returns (bools res);

```

- Implementation
    - Check in the tokenIn related SuperOracle if the under-underlying stable has depegged

1.3.2.2 Is uncertainty too high 

```solidity
function isDispersion(
address tokenIn
) public returns (bool res);

```

- Implementation
    - Check in the tokenIn related SuperOracle if the dispersion measure is too high

1.3.2.3 Is SuperOracle Up 

```solidity
function isSuperOracleUp(
address tokenIn
) public returns (bool res);

```

- Implementation
    - Check in the underlying SuperOracle if M=0 in which case it means the superOracle is not up

## 1.3.3 Pricing

```solidity
function getPrice(address tokenIn) external view returns (uint256 amountUSD, uint256 stddev, uint256 N, uint256 M) {

if(isVault[tokenIn]) return getPPS(tokenIn) else 
if(isERC20[tokenIn]) return getPriceERC20(tokenIn) else
revert error("Unsupported tokenIn");

}

```

- Notes
    - Returns the price of a SuperUSD underlying asset, which can be an EIP7540, EIP4626 and ERC20 in USD
    - The EIP7540 and EIP4626 are priced in the same way while ERC20 requires a different way
    - To discriminate whether the input address is a vault share or an ERC20 we can have a mapping

So 

```solidity
function getPPS(address share) public view returns (uint256 ppsMu, uint256 ppsSigma, uint256 N, uint256 M);
```

- Implementation
    - Calls the underlying SuperVault convertToAssets() for 1 shareThe above does not contradict what Vik said about having a percentage of the swap fees contributing to incentive, this could be done in the manual rebalance or replenish of this fund
    - Notes
        - This assumes there is no slippage in the price calculation, which is a common assumption
        - If there are cases where the price is a function of the amount i.e. with slippage, we need to change the interface
    - Since the assumption is the underlying SuperVault is single asset, this function should return the amount $A$ of that single asset corresponding to 1 share
    - Gets the SuperOracle for this underlying SuperVault single asset and calls getMeanPrice() which should return $\mu, \sigma, N, M$ and
    - Returns $\mu_{PPS} = A \mu$ and $\sigma_{PPS} = A \sigma$ and $N,M$

```solidity
function getPriceERC20(address tokenIn) public view returns (uint256 mu, uint256 sigma, uin256 N, uint256 M);
```

- Implementation
    - Gets the SuperOracle for this ERC20 and calls getMeanPrice() which should return $\mu, \sigma, N, M$ and
    - Returns them

## Standard EIP7540 and EIP4626 Interface

https://eips.ethereum.org/EIPS/eip-7540

https://eips.ethereum.org/EIPS/eip-4626

## Settlement Token Management

### Functions

- Notes
    - The assumption is we will have 2 whitelists of 1 single element each, one for the incentive settlement token of incentives paid by the user and one for the incentive settlement token of incentives paid to the user
    - setSettlementTokenIn(address tokenIn)
        - The settlement token SuperUSD wants to receive
        - Initially it can be SUPER token
    - setSettlementTokenOut(address tokenOut)
        - The settlement token SuperUSD wants to pay with
        - Initially it will be USDC to reduce sell pressure on SUPER token

## Incentives

This involves 2 separate contracts  

### Contracts

List

- Incentive Calculation Contract (ICC)
    - Description
        - A stateless library-like contract that contains the calculation logic for the incentive
        - The reason to keep it as a separate contract is this likely going to be the most flexible / less stable part of the whole system, as we will have to calibrate the incentive based on how effective they are, so the idea is to only upgrade this contract or just deploy a new version of it and change the pointer in SuperUSD contract
- Incentive Funds
    - Description
        - A "Safe" contract that keeps the incentives tokens and contains the incentive capping logic

## Contract 2 : Incentive Calculation Contract (ICC)

### 2.0 Followed Interface

Custom 

### 2.1 State

None 

### 2.2 State Changing Functions

None 

This is just a calculation contract 

### 2.3 View Functions

Calculation Logic

- Atm they are in Python, will spec this out here but it’s separate from the core mechanics

Will add it here asap 

2.3.1 Energy Function

```solidity
function energy(
uint256[] allocationPreOperation,
uint256[] allocationTarget,
uint256[] weights,
) public returns (uint256 energy);

```

Corresponding Python Implementation 

```python
def energy(current_allocation_normalized, target_allocation_normalized, weights):
  """Calculates the incentive based on the current and target allocation.

  Returns:
    The sum of the square root of the difference between each element of
    current_allocation and target_allocation weighted by the related weights.
  """
  diff = current_allocation_normalized - target_allocation_normalized
  energy_terms = np.square(np.abs(diff)) * weights
  return np.sum(energy_terms)

```

The concept of energy is used in the incentive calculation function 

2.3.2 Incentive Calculation Fundion 

```solidity
function calculateIncentive(
uint256[] allocationPreOperation,
uint256[] allocationPostOperation,
uint256[] allocationTarget,
) external returns (uint256 incentive);

```

Corresponding Python Implementation 

```python
  def calculate_incentives(self, current_allocation, new_allocation, target_allocation):
    energy_before = energy(current_allocation, target_allocation, self.coeffs)
    energy_after = energy(new_allocation, target_allocation, self.coeffs)
    uncapped_incentive = (energy_before - energy_after) * self.energy_to_economic_incentive_factor
    return uncapped_incentive

```

### Contract 3 : Incentive Fund Contract

### 3.1 State

```
// The token users send incentives to
// Initially SUPER
address tokenInIncentive;

// The token we pay incentives to 
// Initially USDC
address tokenOutIncentive;

```

### 3.2 State Changing Functions

3.2.1 Money Movement Logic 

3.2.1.1 PayIncentive()

```

// OnlyRole Protected Method

function payIncentive(
address receiver,
address tokenOut,
uint256 amount
) external onlyRole() returns (uint256 amountOut) {

amountOut = previewPayIncentive(tokenOut, amount);

tokenOut.transfer(receiver, amountOut);

}

```

Pays incentives in tokenOut to receiver, the amount represents the requested amount and the returned amountOut represents the amount effectively paid out 

3.2.1.2 takeIncentinve()

```
function takeIncentives(
address from,
address tokenIn,
uint256 amount,
uint256 amountMaxPaid
) external onlyRole() {

tokenIn.transferFrom(from, address(this), amount);

}

```

3.2.1.3 settleIncentive()

```
function settleIncentive(
address user,
int256 amount,
uint256 amountMaxPaid,
) internal {

if(amount > 0) payIncentive(user, tokenOutIncentives, uint256(amount)) else 
if(amount < 0) takeIncentive(user, tokenInIncentives, uint256(-amount)) 

// If amount=0 we do nothing

}

```

3.2.2 Rebalance 

3.2.2.1 Withdraw() 

```

// OnlyRole Protected Function 

function withdraw(
address receiver,
address tokenOut,
uint256 amountOut

) external onlyRole(INCENTIVE_FUND_MANAGER) {

tokenOut.transfer(receiver, amount);

}

```

This is going to be used for manually rebalance the fund 

### 3.3 View Functions

3.3.1 Incentives 

3.3.1.1 previewIncentive()

```
function previewPayIncentive(
address tokenOut,
uint256 amount
) public view returns (uint256 amountOut) {

amountOut = cappingLogic(tokenOut, amount);

}
```

It returns the actual amount of incentive paid in tokenOut, so applying the capping logic on the input amount 

3.3.1.2 _cappingLogic() 

```
function _cappingLogic(
address tokenOut,
uint256 amountOut,
) internal returns (uint256 cappedAmountOut) {

// TBD
// It could be something no more than X% of the remaining availability for tokenOut

}
```

## Contract 4 : Swap Fee Fund

### 4.1 State

None 

### 4.2 State changing function

4.2.1 Rebalance 

4.2.1.1 Withdraw() 

```

// OnlyRole Protected Function 

function withdraw(
address receiver,
address tokenOut,
uint256 amountOut

) external onlyRole(INCENTIVE_FUND_MANAGER) {

tokenOut.transfer(receiver, amount);

}

```

This is going to be used for manually rebalance the fund 

### 4.3 View Functions

None
