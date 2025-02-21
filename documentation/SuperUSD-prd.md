# Project Overview

You are responsible for building SuperUSD, an Ethereum meta vault that aggregates multiple yield-bearing SuperVault tokens into a single “Savings Dollar” product. SuperUSD enables users to deposit approved SuperVault tokens (e.g., SuperUSDC, SuperUSDT) and receive non-rebasing SuperUSD shares that appreciate in value as yield from underlying strategies and swap fees are reinvested.

SuperUSD provides:
- Simple onboarding: One-transaction deposits of any SuperVault, where users receive SuperUSD shares at a 1:1 USD value adjusted by a multiplier.
- Yield Accrual: A non-rebasing share price mechanism that compounds yield and fees.
- Swaps & Redemption: The ability to swap between different SuperVault tokens (using oracle price feeds) and flexible redemption into any whitelisted SuperStablecoin.
- Governance & Risk Controls: A strategist role and governance framework that can whitelist vault tokens, set fee parameters, execute rapid rebalancing, and trigger circuit breakers in adverse conditions.

You will be using Solidity with foundry for testing/deployment and leveraging openzeppelin-contracts as a library. Integration with the existing SuperVault tokens (adhering to ERC7540 standards) is required.

The repository is structured as follows:
- src/periphery/SuperUSD.sol: Contains the core meta vault code for SuperUSD.
- src/core/accounting/Oracles/SuperOracle.sol: Contains the oracle logic and price feed integrations.

SuperUSD will follow ERC20 with some ERC4626 like capability for multi assets. In this system, the existing ERC7540 SuperVaults serve as the underlying assets, and SuperUSD will manage the mapping between each asset and its associated vault.

---

# Core Functionalities

1. Vault Whitelisting & Governance Controls
   - Whitelisting: Only governance-approved SuperVault tokens (ERC7540 compliant) can be deposited into SuperUSD. This is enforced by a mapping of approved asset addresses to vault addresses.
   - Rapid Updates: Implement functions that allow governance to add or remove vault tokens quickly. These functions will include a short timelock for rapid risk management.
   - Target Allocation Control: Governance sets and updates target allocations for each SuperVault token based on market conditions and risk management requirements.
   - Fee & Parameter Settings: Strategist sets parameters such as swap fees, insurance fund percentages, sigmoid curve parameters (A, α, β) and can reset reference oracle prices as needed. Settings are stored in configurable structs updated via governance calls.

2. Deposit & Mint Functionality
   - User Deposit Flow:
       - Users deposit whitelisted SuperVault tokens
       - Contract verifies the token is whitelisted and calculates the USD value using SuperOracle
       - Minting uses a sigmoid-based mechanism to encourage balanced deposits:
           - Formula: M(i) = 1 + A / (1 + exp(α * ((Ci / Ti) - β))). Where A, α, and β are by default .05, 4, and 1 
           - Where M(i) is the minting multiplier, Ci is current allocation, Ti is target allocation
           - User receives SuperUSD shares of USD value * M(i)
           - Deposits of underweighted assets receive bonus shares (up to 100% more)
           - Deposits of overweighted assets receive near 1:1 shares
           - Users can take advantage of this bonus by depositing large amounts of underweighted assets
       - Minted shares are transferred to the user's wallet
   - Solidity Implementation:
       - Implement deposit() function that accepts SuperVault tokens and amount
       - Include allocation tracking and sigmoid multiplier calculation
       - Update internal accounting of deposits and minted shares

3. Redemption & Burn Functionality
   - User Redemption Flow:
       - Users burn SuperUSD shares
       - Contract calculates the USD value of shares using SuperOracle
       - Users receive underlying SuperVault tokens at 1:1 USD value
       - Note that this is not redeemed at the sigmoid-curve, users can profit instantly by providing underweighted assets
   - Solidity Implementation:
       - Implement redeem() function that accepts SuperUSD shares and desired output token
       - Update internal accounting of burned shares and withdrawn tokens

4. Swap Functionality
   - User Swap Flow:
       - Users can swap between whitelisted SuperVault tokens
       - Contract calculates exchange rate using SuperOracle
       - Small fee charged on swaps, split between insurance fund and yield
   - Solidity Implementation:
       - Implement swap() function that accepts input token, output token, and amount
       - Include fee calculation and distribution logic

5. Insurance Fund & Fee Reinvesting
   - Insurance Fund:
       - Percentage of swap fees allocated to insurance fund
       - Fund used to cover potential losses or imbalances
   - Fee Reinvesting:
       - Reinvest accrued swap fees to drive share price appreciation
       - Implementation of fee collection and distribution logic

6. Oracle Integration
   - Price Data:
       - Integration with SuperOracle for price data
       - Used for calculating deposit values, redemption amounts, and swap rates
   - Solidity Implementation:
       - Implement getPrice() function that fetches latest prices
       - Include fallback mechanisms for oracle failures

7. Circuit Breaker Mechanism
   - Price Deviation Protection:
       - Monitor price deviations using SuperOracle data
       - Pause operations if deviations exceed thresholds
   - Solidity Implementation:
       - Implement circuit breaker flag for each whitelisted vault token
       - Include checks in swap() function that verify token price deviation
       - Allow governance to manually override and reset circuit breaker status