// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ISuperAsset
 * @notice Interface for SuperAsset contract which manages deposits and redemptions across multiple
 * underlying vaults. It implements ERC20 standard and provides functionality for asset management,
 * fee handling, and incentive calculations.
 */
interface ISuperAsset is IERC20 {
    /**
     * @notice Mints new tokens. Can only be called by accounts with MINTER_ROLE.
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Burns tokens. Can only be called by accounts with BURNER_ROLE.
     * @param from The address whose tokens will be burned
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external;

    /**
     * @notice Gets the current and target allocations of assets
     * @return absoluteCurrentAllocation Array of current absolute allocations
     * @return totalCurrentAllocation Sum of all current allocations
     * @return absoluteTargetAllocation Array of target absolute allocations
     * @return totalTargetAllocation Sum of all target allocations
     */
    function getAllocations() external view returns (
        uint256[] memory absoluteCurrentAllocation,
        uint256 totalCurrentAllocation,
        uint256[] memory absoluteTargetAllocation,
        uint256 totalTargetAllocation
    );

    /**
     * @notice Gets the allocations before and after an operation
     * @param token The token address involved in the operation
     * @param deltaToken The change in token amount (positive for deposit, negative for withdrawal)
     * @return absoluteCurrentAllocation Array of current absolute allocations
     * @return totalCurrentAllocation Sum of all current allocations
     * @return absoluteTargetAllocation Array of target absolute allocations
     * @return totalTargetAllocation Sum of all target allocations
     */
    function getAllocationsPrePostOperation(
        address token,
        int256 deltaToken
    ) external view returns (
        uint256[] memory absoluteCurrentAllocation,
        uint256 totalCurrentAllocation,
        uint256[] memory absoluteTargetAllocation,
        uint256 totalTargetAllocation
    );

    /**
     * @notice Sets the swap fee percentage for deposits (input operations)
     * @param _feePercentage The fee percentage (scaled by SWAP_FEE_PERC)
     */
    function setSwapFeeInPercentage(uint256 _feePercentage) external;

    /**
     * @notice Sets the swap fee percentage for redemptions (output operations)
     * @param _feePercentage The fee percentage (scaled by SWAP_FEE_PERC)
     */
    function setSwapFeeOutPercentage(uint256 _feePercentage) external;

    /**
     * @notice Deposits an underlying asset into a whitelisted vault and mints SuperUSD shares.
     * @param receiver The address to receive the output shares.
     * @param tokenIn The address of the underlying asset to deposit.
     * @param amountTokenToDeposit The amount of the underlying asset to deposit.
     * @param minSharesOut The minimum amount of SuperUSD shares to receive.
     * @return amountSharesMinted The amount of SuperUSD shares minted.
     * @return swapFee The amount of swap fee paid.
     * @return amountIncentiveUSDDeposit The amount of incentives paid.
     */
    function deposit(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut            // Slippage Protection
    ) external returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit);

    /**
     * @notice Redeems SuperUSD shares for underlying assets from a whitelisted vault.
     * @param receiver The address to receive the output assets.
     * @param amountSharesToRedeem The amount of SuperUSD shares to redeem.
     * @param tokenOut The address of the underlying asset to redeem for.
     * @param minTokenOut The minimum amount of the underlying asset to receive.
     * @return amountTokenOutAfterFees The amount of the underlying asset received.
     * @return swapFee The amount of swap fee paid.
     * @return amountIncentiveUSDRedeem The amount of incentives paid.
     */
    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut
    ) external returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem);

    /**
     * @notice Swaps an underlying asset for another.
     * @param receiver The address to receive the output assets.
     * @param tokenIn The address of the input asset.
     * @param amountTokenToDeposit The amount of the input asset to deposit.
     * @param tokenOut The address of the output asset.
     * @param minTokenOut The minimum amount of the output asset to receive.
     * @return amountSharesIntermediateStep The amount of shares received in the intermediate step.
     * @return amountTokenOutAfterFees The amount of the output asset received.
     * @return swapFeeIn The amount of swap fee paid for the input asset.
     * @return swapFeeOut The amount of swap fee paid for the output asset.
     * @return amountIncentivesIn The amount of incentives paid for the input asset.
     * @return amountIncentivesOut The amount of incentives paid for the output asset.
     */
    function swap(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        address tokenOut,
        uint256 minTokenOut
    ) external returns (uint256 amountSharesIntermediateStep, uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentivesIn, int256 amountIncentivesOut);

    /**
     * @notice Whitelists a vault
     * @param vault Address of the vault to whitelist
     */
    function whitelistVault(address vault) external;

    /**
     * @notice Removes a vault from whitelist
     * @param vault Address of the vault to remove
     */
    function removeVault(address vault) external;

    /**
     * @notice Whitelists an ERC20 token
     * @param token Address of the token to whitelist
     */
    function whitelistERC20(address token) external;

    /**
     * @notice Removes an ERC20 token from whitelist
     * @param token Address of the token to remove
     */
    function removeERC20(address token) external;

    /**
     * @notice Sets the settlement token for deposits
     * @param token Address of the token to set as settlement token
     */
    function setSettlementTokenIn(address token) external;

    /**
     * @notice Sets the settlement token for redemptions
     * @param token Address of the token to set as settlement token
     */
    function setSettlementTokenOut(address token) external;

    /**
     * @notice Sets the oracle contract address
     * @param oracle Address of the new oracle contract
     */
    function setSuperOracle(address oracle) external;

    /**
     * @notice Preview a deposit.
     * @param tokenIn The address of the underlying asset to deposit.
     * @param amountTokenToDeposit The amount of the underlying asset to deposit.
     * @return amountSharesMinted The amount of SuperUSD shares that would be minted.
     * @return swapFee The amount of swap fee paid.
     * @return amountIncentiveUSD The amount of incentives in USD.
     */
    function previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
    external 
    view
    returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSD);

    /**
     * @notice Preview a redemption.
     * @param tokenOut The address of the underlying asset to redeem for.
     * @param amountSharesToRedeem The amount of SuperUSD shares to redeem.
     * @return amountTokenOutAfterFees The amount of the underlying asset that would be received.
     * @return swapFee The amount of swap fee paid.
     * @return amountIncentiveUSD The amount of incentives in USD.
     */
    function previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
    external
    view
    returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSD);

    /**
     * @notice Preview a swap.
     * @param tokenIn The address of the input asset.
     * @param amountTokenToDeposit The amount of the input asset to deposit.
     * @param tokenOut The address of the output asset.
     * @return amountTokenOutAfterFees The amount of the output asset that would be received.
     * @return swapFeeIn The amount of swap fee paid for the input asset.
     * @return swapFeeOut The amount of swap fee paid for the output asset.
     * @return amountIncentiveUSDDeposit The amount of incentives paid for the input asset.
     * @return amountIncentiveUSDRedeem The amount of incentives paid for the output asset.
     */
    function previewSwap(address tokenIn, uint256 amountTokenToDeposit, address tokenOut)
    external
    view
    returns (uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentiveUSDDeposit, int256 amountIncentiveUSDRedeem);

    // --- Events ---
    event Deposit(address receiver, address tokenIn, uint256 amountTokenToDeposit, uint256 amountSharesOut, uint256 swapFee, int256 amountIncentives);
    event Redeem(address receiver, address tokenOut, uint256 amountSharesToRedeem, uint256 amountTokenOut, uint256 swapFee, int256 amountIncentives);
    event Swap(address receiver, address tokenIn, uint256 amountTokenToDeposit, address tokenOut, uint256 amountSharesIntermediateStep, uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentivesIn, int256 amountIncentivesOut);
    event VaultWhitelisted(address vault);
    event VaultRemoved(address vault);
    event ERC20Whitelisted(address token);
    event ERC20Removed(address token);
    event SettlementTokenInSet(address token);
    event SettlementTokenOutSet(address token);
    event SuperOracleSet(address oracle);
    event TargetAllocationSet(address token, uint256 allocation);
    event EnergyToUSDExchangeRatioSet(uint256 newRatio);
}
