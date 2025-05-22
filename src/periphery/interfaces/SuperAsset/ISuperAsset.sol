// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ISuperAsset
 * @notice Interface for SuperAsset contract which manages deposits and redemptions across multiple
 * underlying vaults. It implements ERC20 standard and provides functionality for asset management,
 * fee handling, and incentive calculations.
 */
interface ISuperAsset is IERC20 {

    struct TokenData {
        bool isSupportedUnderlyingVault;
        bool isSupportedERC20;
        uint256 targetAllocations;
        uint256 weights;
    }

    struct PreviewErrors {
        bool isDepeg;
        bool isDispersion;
        bool isOracleOff;
    }

    struct GetAllocationsPrePostOperations {
        uint256 length;
        uint256 extendedLength;
        uint256 extraSlot;
        address vault;
        uint256 priceUSD;
        bool isDepeg;
        bool isDispersion;
        bool isOracleOff;
        uint256 balance;
        uint256 absDeltaValue;
        int256 deltaValue;
        uint256 absDeltaToken;
    }

    struct GetPrePostAllocationReturnValues {
        uint256[] absoluteAllocationPreOperation;
        uint256 totalAllocationPreOperation;
        uint256[] absoluteAllocationPostOperation;
        uint256 totalAllocationPostOperation;
        uint256[] absoluteTargetAllocation;
        uint256 totalTargetAllocation;
        uint256[] vaultWeights;
        bool isSuccess;
    }

    struct PreviewDeposit {
        GetPrePostAllocationReturnValues allocations;
        uint256 amountTokenInAfterFees;
        uint256 priceUSDTokenIn;
        uint256 priceUSDThisShares;
    }

    struct PreviewRedeem {
        GetPrePostAllocationReturnValues allocations;
        uint256 priceUSDThisShares;
        uint256 priceUSDTokenOut;
        uint256 amountTokenOutBeforeFees;
    }

    /**
     * @notice Initializes the SuperAsset contract
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param icc_ Address of the IncentiveCalculationContract
     * @param ifc_ Address of the IncentiveFundContract
     * @param superGovernor_ Address of the SuperGovernor contract
     * @param swapFeeInPercentage_ Initial swap fee percentage for deposits
     * @param swapFeeOutPercentage_ Initial swap fee percentage for redemptions
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        address icc_,
        address ifc_,
        address superGovernor_,
        uint256 swapFeeInPercentage_,
        uint256 swapFeeOutPercentage_
    )
        external;
        
    /**
     * @notice Returns the token data for a given token
     * @param token The token address
     * @return TokenData structure containing the token data
     */
    function getTokenData(address token) external view returns (TokenData memory);

    /**
     * @notice Returns the PPS of the SuperAsset
     * @return PPS of the SuperAsset
     */
    function getPPS() external view returns(uint256);

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
    function getAllocations()
        external
        view
        returns (
            uint256[] memory absoluteCurrentAllocation,
            uint256 totalCurrentAllocation,
            uint256[] memory absoluteTargetAllocation,
            uint256 totalTargetAllocation
        );

    /**
     * @notice Gets the allocations before and after an operation
     * @param token The token address involved in the operation
     * @param deltaToken The change in token amount (positive for deposit, negative for withdrawal)
     * @param isSoft Whether the operation is soft or strict on checks
     * @return absoluteAllocationPreOperation Array of pre-operation absolute allocations
     * @return totalAllocationPreOperation Sum of all pre-operation allocations
     * @return absoluteAllocationPostOperation Array of post-operation absolute allocations
     * @return totalAllocationPostOperation Sum of all post-operation allocations
     * @return absoluteTargetAllocation Array of target absolute allocations
     * @return totalTargetAllocation Sum of all target allocations
     * @return vaultWeights Array of vault weights
     * @return isSuccess Whether the operation was successful
     */
    function getAllocationsPrePostOperation(
        address token,
        int256 deltaToken,
        bool isSoft
    )
        external
        view
        returns (
            uint256[] memory absoluteAllocationPreOperation,
            uint256 totalAllocationPreOperation,
            uint256[] memory absoluteAllocationPostOperation,
            uint256 totalAllocationPostOperation,
            uint256[] memory absoluteTargetAllocation,
            uint256 totalTargetAllocation,
            uint256[] memory vaultWeights,
            bool isSuccess
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
        uint256 minSharesOut // Slippage Protection
    )
        external
        returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit);

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
    )
        external
        returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem);

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
    )
        external
        returns (
            uint256 amountSharesIntermediateStep,
            uint256 amountTokenOutAfterFees,
            uint256 swapFeeIn,
            uint256 swapFeeOut,
            int256 amountIncentivesIn,
            int256 amountIncentivesOut
        );

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
     * @notice Sets the oracle contract address
     * @param oracle Address of the new oracle contract
     */
    function setSuperOracle(address oracle) external;

    /**
     * @notice Preview a deposit.
     * @param tokenIn The address of the underlying asset to deposit.
     * @param amountTokenToDeposit The amount of the underlying asset to deposit.
     * @param isSoft Whether the operation is soft or strict on checks
     * @return amountSharesMinted The amount of SuperUSD shares that would be minted.
     * @return swapFee The amount of swap fee paid.
     * @return amountIncentiveUSD The amount of incentives in USD.
     * @return isSuccess Whether the preview was successful
     */
    function previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit,
        bool isSoft
    )
        external
        view
        returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess);

    /**
     * @notice Preview a redemption.
     * @param tokenOut The address of the underlying asset to redeem for.
     * @param amountSharesToRedeem The amount of SuperUSD shares to redeem.
     * @param isSoft Whether the operation is soft or strict on checks
     * @return amountTokenOutAfterFees The amount of the underlying asset that would be received.
     * @return swapFee The amount of swap fee paid.
     * @return amountIncentiveUSD The amount of incentives in USD.
     * @return isSuccess Whether the preview was successful
     */
    function previewRedeem(
        address tokenOut,
        uint256 amountSharesToRedeem,
        bool isSoft
    )
        external
        view
        returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess);

    /**
     * @notice Preview a swap.
     * @param tokenIn The address of the input asset.
     * @param amountTokenToDeposit The amount of the input asset to deposit.
     * @param tokenOut The address of the output asset.
     * @param isSoft Whether the operation is soft or strict on checks
     * @return amountTokenOutAfterFees The amount of the output asset that would be received.
     * @return swapFeeIn The amount of swap fee paid for the input asset.
     * @return swapFeeOut The amount of swap fee paid for the output asset.
     * @return amountIncentiveUSDDeposit The amount of incentives paid for the input asset.
     * @return amountIncentiveUSDRedeem The amount of incentives paid for the output asset.
     * @return isSuccess Whether the preview was successful
     */
    function previewSwap(
        address tokenIn,
        uint256 amountTokenToDeposit,
        address tokenOut,
        bool isSoft
    )
        external
        view
        returns (
            uint256 amountTokenOutAfterFees,
            uint256 swapFeeIn,
            uint256 swapFeeOut,
            int256 amountIncentiveUSDDeposit,
            int256 amountIncentiveUSDRedeem,
            bool isSuccess
        );

    /**
     * @notice Gets the price of a token in USD with circuit breakers
     * @dev This function should not revert, just return booleans for the circuit breakers, it is up to the caller to
     * decide if to revert
     * @dev Getting only single unit price
     * @param tokenIn The address of the token to get the price of
     * @return priceUSD The price of the token in USD
     * @return isDepeg Whether the token is depegged
     * @return isDispersion Whether the token is dispersed
     * @return isOracleOff Whether the oracle is off
     */
    function getPriceWithCircuitBreakers(address tokenIn)
        external
        view
        returns (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff);

    /**
     * @notice Gets the precision constant used for percentage calculations
     * @return The precision constant (e.g., 10000 for 4 decimal places)
     */
    function getPrecision() external pure returns (uint256);

    /**
     * @notice Sets the weight for a vault
     * @param vault The vault address
     * @param weight The weight percentage (scaled by PRECISION)
     */
    function setWeight(address vault, uint256 weight) external;

    /**
     * @notice Sets target allocations for multiple tokens at once
     * @param tokens Array of token addresses
     * @param allocations Array of target allocation percentages (scaled by PRECISION)
     */
    function setTargetAllocations(address[] calldata tokens, uint256[] calldata allocations) external;

    /**
     * @notice Sets the target allocation for a token
     * @param token The token address
     * @param allocation The target allocation percentage (scaled by PRECISION)
     */
    function setTargetAllocation(address token, uint256 allocation) external;

    /**
     * @notice Sets the exchange ratio between energy units and USD
     * @param newRatio The new exchange ratio (scaled by PRECISION)
     * @dev This is the ratio between energy units and USD
     * @dev No checks on zero on purpose in case we want to disable incentives
     */
    function setEnergyToUSDExchangeRatio(uint256 newRatio) external;

    // --- Events ---
    event Deposit(
        address indexed receiver,
        address indexed tokenIn,
        uint256 amountTokenToDeposit,
        uint256 amountSharesOut,
        uint256 swapFee,
        int256 amountIncentives
    );
    event Redeem(
        address indexed receiver,
        address indexed tokenOut,
        uint256 amountSharesToRedeem,
        uint256 amountTokenOut,
        uint256 swapFee,
        int256 amountIncentives
    );
    event Swap(
        address indexed receiver,
        address indexed tokenIn,
        uint256 amountTokenToDeposit,
        address indexed tokenOut,
        uint256 amountSharesIntermediateStep,
        uint256 amountTokenOutAfterFees,
        uint256 swapFeeIn,
        uint256 swapFeeOut,
        int256 amountIncentivesIn,
        int256 amountIncentivesOut
    );
    event VaultWhitelisted(address indexed vault);
    event VaultRemoved(address indexed vault);
    event ERC20Whitelisted(address indexed token);
    event ERC20Removed(address indexed token);
    event SettlementTokenInSet(address indexed token);
    event SettlementTokenOutSet(address indexed token);
    event SuperOracleSet(address indexed oracle);
    event TargetAllocationSet(address indexed token, uint256 allocation);
    event EnergyToUSDExchangeRatioSet(uint256 newRatio);
    event WeightSet(address indexed vault, uint256 weight);

    // --- Errors ---
    /// @notice Thrown when an address parameter is zero
    error ZERO_ADDRESS();

    /// @notice Thrown when token is not in the ERC20 whitelist
    error NOT_ERC20_TOKEN();

    /// @notice Thrown when a token is not supported (neither vault nor ERC20)
    error NOT_SUPPORTED_TOKEN();

    /// @notice Thrown when vault is not in the vault whitelist
    error NOT_VAULT();

    /// @notice Thrown when vault is already whitelisted
    error ALREADY_WHITELISTED();

    /// @notice Thrown when contract is already initialized
    error ALREADY_INITIALIZED();

    /// @notice Thrown when vault or token is not whitelisted
    error NOT_WHITELISTED();

    /// @notice Thrown when swap fee percentage is too high
    error INVALID_SWAP_FEE_PERCENTAGE();

    /// @notice Thrown when amount is zero
    error ZERO_AMOUNT();

    /// @notice Thrown when insufficient balance for operation
    error INSUFFICIENT_BALANCE();

    /// @notice Thrown when insufficient allowance for transfer
    error INSUFFICIENT_ALLOWANCE();

    /// @notice Thrown when slippage tolerance is exceeded
    error SLIPPAGE_PROTECTION();

    /// @notice Thrown when oracle price is invalid
    error INVALID_ORACLE_PRICE();

    /// @notice Thrown when allocation is invalid
    error INVALID_ALLOCATION();

    /// @notice Thrown when the contract is paused
    error CONTRACT_PAUSED();

    /// @notice Thrown when emergency price is not set
    error EMERGENCY_PRICE_NOT_SET();

    /// @notice Thrown when caller is not authorized
    error UNAUTHORIZED();

    /// @notice Thrown when operation would result in invalid state
    error INVALID_OPERATION();

    /// @notice Thrown when incentive calculation fails
    error INCENTIVE_CALCULATION_FAILED();

    /// @notice Thrown when input arrays have mismatched lengths in batch operations
    error INVALID_INPUT();

    /// @notice Thrown when the sum of all allocations exceeds 100% (PRECISION)
    error INVALID_TOTAL_ALLOCATION();

    /// @notice Thrown when price in USD is zero
    error PRICE_USD_ZERO();

    /// @notice Thrown when underlying SV asset price is zero
    error UNDERLYING_SV_ASSET_PRICE_ZERO();

    /// @notice Thrown when underlying SV asset price is depegged
    error UNDERLYING_SV_ASSET_PRICE_DEPEG();

    /// @notice Thrown when underlying SV asset price is dispersed
    error UNDERLYING_SV_ASSET_PRICE_DISPERSION();

    /// @notice Thrown when underlying SV asset price is oracle off
    error UNDERLYING_SV_ASSET_PRICE_ORACLE_OFF();
}
