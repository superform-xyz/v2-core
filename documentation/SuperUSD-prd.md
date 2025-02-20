# Project Overview

You are responsible for building SuperUSD on Ethereum meta vault that aggregates multiple yield-bearing SuperVault tokens into a single “Savings Dollar” product. SuperUSD enables users to deposit approved SuperVault tokens (e.g., SuperUSDC, SuperUSDT) and receive non-rebasing SuperUSD shares that appreciate in value as yield from underlying strategies and swap fees are reinvested.

SuperUSD provides:
- Simple onboarding: One-transaction deposits, where users receive SuperUSD shares at a 1:1 USD value.
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
   - Rapid Updates: Implement functions that allow governance (or designated strategist roles) to add or remove vault tokens quickly. These functions will include a short timelock for rapid risk management.
   - Fee & Parameter Settings: Governance sets parameters such as swap fees, insurance fund percentages, and can reset reference oracle prices as needed. Settings are stored in configurable structs updated via governance calls.
2. Deposit & Mint Functionality
   - User Deposit Flow:
       1. The user selects one or more approved SuperVault tokens (for example, SuperUSDC).
       2. Upon deposit, the contract uses the SuperOracle to fetch the USD value of the deposit.
       3. The system mints SuperUSD shares on a 1:1 USD basis.
   - Solidity Implementation:
       - Implement a deposit() function, similar to deposit ERC4626, and making sure it supports multiple assets being deposited and convert the asset to SuperUSD shares via oracle prices.
       - Ensure that internal accounting (e.g., totalAssets, convertToShares) adheres to ERC4626 logic for simplification
3. Yield Accrual Mechanism
   - Yield Accrual: Yield from underlying SuperVault strategies and swap fees is continuously reinvested, causing the value (price per share) of SuperUSD to appreciate.
   - Solidity Implementation:
       - Integrate functions to update the vault’s total assets based on yield harvests from underlying SuperVaults.
       - Maintain a non-rebasing share model by updating a “price per share” variable that reflects the accumulated yield.
       - Refer to ERC4626’s accounting methods (such as convertToAssets and convertToShares) to track yield accrual transparently.
4. Swap Functionality at Oracle Prices
   - User Swap Flow:
       1. Users can swap from one SuperVault token to another (for example, from SuperUSDC to SuperUSDT) through SuperUSD.
       2. The contract uses SuperOracle to determine the current USD value for each token.
       3. A swap fee (approximately 0.04%) is applied, with the fee being reinvested in the meta vault to boost the share price.
   - Solidity Implementation:
       - Develop a swap() function that accepts source and destination asset addresses, verifies that both are whitelisted, and then uses oracle price feeds from SuperOracle.sol to calculate the equivalent amounts.
       - Integrate fee deduction logic and update the vault’s total assets accordingly.
       - Emit events for swap actions to enable off-chain monitoring.
5. Flexible Redemption Process
   - A special redeem function is provided based on the ERC4626's redeem version. This non-standard function allows users to specify the underlying vault token (e.g., USDT or USDC) they wish to receive when exiting.
   - Solidity Implementation:
       - Implement redeem() allowing an output of any asset. This function will calculate the USD value from the SuperUSD shares using current oracle pricing and convert that into the corresponding amount of the desired vault token.
       - Ensure that the function updates internal accounting correctly
6. Strategist Functions & Automated Yield Reinvestment
   - Strategist Controls:
       - Functions that allow the strategist to reallocate assets from underperforming vaults into higher-yield or safer vaults.
       - Automated functions to harvest yield from underlying SuperVault strategies and compound it back into the meta vault.
       - Reinvest accrued swap fees to drive share price appreciation (claim and compound)
   - Solidity Implementation:
       - Create a function (for example, harvestYield()) that interacts with underlying vault contracts to claim yield.
       - Create a function that allows the strategist to rebalance the vault by redeeming assets from one source and depositing them into another.
       - Provide functions to update internal state variables, such as the yield accumulator or “price per share,” based on harvested yield.
7. Insurance Fund Allocation
   - Risk Mitigation: A predetermined fraction of yield and swap fees is diverted to an insurance fund.
   - DAO Controlled: The insurance reserve acts as a backstop against potential shortfalls or strategy failures.
   - Solidity Implementation:
       - Integrate a mechanism in the yield accrual process that diverts a set percentage of yield and fees to a dedicated insurance fund address.
       - Use a dedicated variable or mapping to track accumulated insurance funds and provide withdrawal functions restricted to DAO or governance roles.
8. Circuit Breakers
   - Circuit Breakers: An off-chain enabled mechanism to freeze swaps if a token’s price deviates beyond set thresholds (e.g., ±2%), preventing exploitative trades.
   - Solidity Implementation:
       - Implement a circuit breaker flag for each whitelisted vault token.
       - Include checks in the swap() function that verify each token’s price deviation against preset thresholds using data from SuperOracle.
       - Allow governance or the strategist to manually override and reset the circuit breaker status via dedicated functions.