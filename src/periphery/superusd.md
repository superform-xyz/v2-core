---

# Product Requirements Document: SuperUSD.sol

## 1. Overview

The goal of this product is to deploy a SuperUSD accepts deposits in any of the underlying assets supported by our individual SuperVaults (for example, USDC, USDT, DAI, etc.). Depositors receive a common share token that represents their proportional claim on the total USD–valued deposits across all underlying vaults. The Aggregator Vault leverages asynchronous deposit/redemption flows per ERC‑7540 and multi-asset vault support as defined in ERC‑7575.

**References:**
- [ERC‑7540: Asynchronous ERC‑4626 Tokenized Vaults](https://eips.ethereum.org/EIPS/eip-7540)
- [ERC‑7575: Multi-Asset ERC‑4626 Vaults](https://eips.ethereum.org/EIPS/eip-7575)

## 2. Scope

Assume individual SuperVaults for each supported stablecoin (e.g., SuperUSDC, SuperUSDT, SuperDAI, etc.) exist.

- **Create an Aggregator Vault Product:**  
  - The Aggregator Vault will accept deposits from various stablecoins.
  - The vault uses asynchronous deposit and redemption flows (ERC‑7540) with the multi-asset enhancements outlined in ERC‑7575.
  - It will route incoming deposits to the corresponding underlying SuperVault(s) via a mapping (or “pipe”) mechanism.

- **Dynamic Asset Support:**  
  Ability to add new underlying vaults as new stablecoins or yield sources become available. Optionally, include conversion pipes (or adapters) that can standardize deposits into a common form if needed.

## 3. Functional Requirements

### 3.1. Deposit Flow

- **Supported Assets & Routing:**
  - The Aggregator Vault will maintain a mapping of supported assets. Each asset will be linked to:
    - Its underlying SuperVault instance.
    - Optionally, a pipe (adapter) used to convert the asset into another collateral if the underlying vault requires it.
    - Oracle parameters (or a reference to a pricing oracle like SuperOracle) for price feeds.
  
- **Request Deposit (ERC‑7540 Asynchronous Flow):**
  - Users call `requestDeposit(assets, controller, owner)` to deposit a supported asset.
  - The contract calls `transferFrom` on the deposited asset which is then directed to the appropriate underlying SuperVault.
  - The deposited amount is measured in the asset’s native decimals. Before minting shares, a conversion step is required.

- **Conversion to USD Value:**
  - Use an oracle (see the SuperOracle approach) to fetch the asset’s USD price at deposit time.
  - Normalize the deposit amount using `convertToShares` logic:
    - **Calculation:**  
      Share Minted = (Deposit USD value) / (Current USD per share)  
      Where “Current USD per share” is derived from the total value locked (TVL) in USD terms.
  - Record a pending deposit request (as per ERC‑7540) so that the strategist later calls `fulfillDepositRequests`.

- **Share Token Minting:**
  - Once the deposit request moves to Claimable, the Aggregator Vault mints common shares (inherited via ERC‑20 implementation or via an external share token contract).
  - The `share()` method (as required by ERC‑7575) will return the share token’s address (which can be the Aggregator Vault’s own address).

### 3.2. Redemption Flow

- **Request Redemption (ERC‑7540 Asynchronous Flow):**
  - Users call a `requestRedeem(shareAmount, controller, owner)` function to request withdrawal of their shares.
  - Shares are either locked or burned immediately depending on our design.
  - The redemption request is recorded in a pending state, and later the strategist calls `fulfillRedeemRequests`.

- **Fulfillment & Payout Validations:**
  - When the strategist fulfills redeem requests, they can choose which underlying asset to use for the payout.
  - The conversion from shares back to assets is calculated using a function similar to `convertToAssets`.
  - **Key Requirement:**  
    `totalAssets` should be computed as `convertToAssets(shareToken.totalSupply())` so that the share-to-asset conversion always reflects the current USD value of the vault.

### 3.3. Conversion Functions

- **Normalization & Denormalization:**
  - Implement helper functions similar to `_normalizeAsset` and `_denormalizeAsset` that factor in differences in decimals between stablecoins.  
    For example, if USDC is chosen as the primary unit (6 decimals), convert USDT and DAI amounts to 6–decimal equivalents based on oracle pricing.
  
- **Core Functions:**
  - `convertToShares(uint256 assets)`: Converts an amount of USD–valued assets (in normalized terms) to shares.
  - `convertToAssets(uint256 shares)`: Converts a given number of shares back into an asset amount.  
    _Note:_ `totalAssets()` should be implemented as:
    ```solidity
    totalAssets = convertToAssets(IERC20(shareToken).totalSupply());
    ```
  
- **Price Oracles:**
  - Use oracles (e.g., the SuperOracle contract) to get up-to-date USD prices.
  - Validate the oracle data (staleness, zero or negative responses, etc.) before executing conversions.
  - You may need to integrate safety checks, similar to those seen in SuperOracle (e.g., maximum staleness periods).

### 3.4. Strategist Actions

- **Deposit Fulfillment:**
  - The strategist can call `fulfillDepositRequests` (similar to SuperVaultStrategy) to finalize deposit requests: mint shares to users, update internal variables, route deposits into underlying vaults, etc.
  - Because deposits come in different tokens, the strategist will use the oracle prices to determine the correct share yield for the deposit.
  
- **Redemption Fulfillment:**
  - Similarly, the strategist can process redemption requests with `fulfillRedeemRequests` by choosing the asset to return to the user.
  - The payout asset may differ from the asset deposited; conversion logic (using oracle data) is used to compute the correct amount.
  
- **Pipes/Adapters:**
  - Strategist libraries or permitted functions may include “pipes” to convert between assets if needed. This provides additional routing flexibility when depositing to a SuperVault that expects a different collateral than what was received.

## 4. Non-Functional Requirements

- **Standards Compliance:**
  - The Aggregator Vault must fully comply with ERC‑7540 for asynchronous workflows.
  - It must implement the extensions from ERC‑7575, including the `share()` method and ERC‑165 interface support.
  
- **Security & Auditability:**
  - All external functions that move funds must be thoroughly access–control checked (e.g., only allowed strategist calls for fulfillment).
  - Use safe mathematical operations for conversion calculations.
  - Integrate oracle price validation to avoid flash loan manipulation or stale-price use.

- **Modularity & Upgradeability:**
  - New underlying vaults (SuperVaults) can be added or removed from the supported assets mapping.
  - The use of pipes or adapters should allow future asset types to be integrated with minimal changes.

## 5. External Interfaces & Integration

- **ERC‑7540:**  
  - Deposit and redemption flows are asynchronous.  
  - Preview functions (e.g., `previewDeposit`, `previewRedeem`) should revert as specified by ERC‑7540 to enforce proper request/claim procedures.

- **ERC‑7575:**  
  - Support a multi-asset setup by including a `share()` method and a `vault(asset)` lookup function.
  - Implement ERC‑165’s `supportsInterface` to include both the operator management and multi-asset requirements.

- **Oracle Integration:**  
  - Integrate with a SuperOracle–like contract for reliable pricing.
  - Ensure that the price data is validated (e.g., using max staleness checks).

## 6. Example Flow

1. **Deposit Example:**
   - A user requestDeposits 100 USDT.
   - The Aggregator Vault verifies that USDT is supported
   - A deposit request is recorded per ERC‑7540 and later claimed via `fulfillDepositRequests` by the strategist.
 - Before the deposit, its USD price is fetched from the SuperOracle.
   - The USDT is normalized to a common unit (say, 6 decimals) and then converted to a USD value.
   - The vault calculates how many shares to mint based on the current total USD TVL versus the new deposit.

2. **Redemption Example:**
   - A user requests redemption of 50 shares.
   - The Aggregator Vault enters a redemption request; the shares are locked or burned.
   - When the strategist fulfills the redemption (via `fulfillRedeemRequests`), the contract converts 50 shares to their equivalent USD value.
   - The strategist chooses a payout asset (e.g., USDC), and the oracle price is used to determine the USDC payout amount.
   - Funds are withdrawn from the relevant underlying SuperVault and transferred to the user.

## 7. Summary

The Multi-Collateral Aggregator Vault will serve as a unified deposit/withdrawal interface across multiple underlying SuperVaults while abstracting away the differences between various stablecoins. By leveraging ERC‑7540 for asynchronous flows, ERC‑7575 for multi-asset vault support, integrated price oracles for fair value conversions, and flexible pipes to route funds, the product meets the requirements for dynamic, secure, and upgradeable vault strategies deployable in a decentralized finance ecosystem.
