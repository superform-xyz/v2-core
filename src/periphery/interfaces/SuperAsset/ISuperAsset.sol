// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ISuperAsset
/// @notice Interface for SuperAsset contract which manages deposits and redemptions across multiple
/// underlying vaults. It implements ERC20 standard and provides functionality for asset management,
/// fee handling, and incentive calculations.
interface ISuperAsset is IERC20 {
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
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

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

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

    /// @notice Thrown when caller is not authorized
    error UNAUTHORIZED();

    /// @notice Thrown when operation would result in invalid state
    error INVALID_OPERATION();

    /// @notice Thrown when input arrays have mismatched lengths in batch operations
    error INVALID_INPUT();

    /// @notice Thrown when the sum of all allocations exceeds 100% (PRECISION)
    error INVALID_TOTAL_ALLOCATION();

    /// @notice Thrown when price in USD is zero
    error PRICE_USD_ZERO();

    /// @notice Thrown when a supported asset price is oracle off
    error SUPPORTED_ASSET_PRICE_ORACLE_OFF(address assetWithBreakerTriggered);

    /// @notice Thrown when a supported asset price is depegged
    error SUPPORTED_ASSET_PRICE_DEPEG(address assetWithBreakerTriggered);

    /// @notice Thrown when a supported asset price is dispersed
    error SUPPORTED_ASSET_PRICE_DISPERSION(address assetWithBreakerTriggered);

    /// @notice Thrown when a supported asset price is 0
    error SUPPORTED_ASSET_PRICE_ZERO(address assetWithBreakerTriggered);

    /// @notice Thrown when incentive calculation fails (only if totalSupply != 0)
    error INCENTIVE_CALCULATION_FAILED();

    /// @notice Thrown when redeem fails
    error REDEEM_FAILED();

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Token data structure
    /// @param isSupportedUnderlyingVault Whether the token is a supported underlying vault
    /// @param isSupportedERC20 Whether the token is a supported ERC20
    /// @param oracle Address of the oracle to use to fetch token prices
    /// @param targetAllocations Target allocations for the token
    /// @param weights Weights for the token
    struct TokenData {
        bool isSupportedUnderlyingVault;
        bool isSupportedERC20;
        address oracle;
        uint256 targetAllocations;
        uint256 weights;
    }

    /// @notice Structure used for getting allocations pre and post operations
    /// @param length Length of the array
    /// @param extendedLength Extended length of the array
    /// @param extraSlot Extra slot for the array
    /// @param token Address of the token
    /// @param priceUSD Price of the token in USD
    /// @param isDepeg Whether the token is depegged
    /// @param isDispersion Whether the token is dispersed
    /// @param isOracleOff Whether the oracle is off
    /// @param balance Balance of the token
    /// @param absDeltaValue Absolute delta value
    /// @param deltaValue Delta value
    /// @notice Struct for deposit operations when calculating allocations
    /// @param extendedLength Length of supported assets array
    /// @param token Current token being processed
    /// @param priceUSD Price of token in USD
    /// @param balance Balance of token
    /// @param absDeltaValue Absolute delta value for deposit calculation
    /// @param deltaValue Signed delta value for deposit calculation
    /// @param totalValueUSD Total value in USD of all assets
    /// @param priceUSDToken Price of the specific token in USD
    struct GetAllocationsPrePostOperationsDeposit {
        uint256 extendedLength;
        address token;
        uint256 priceUSD;
        uint256 balance;
        uint256 absDeltaValue;
        int256 deltaValue;
        uint256 totalValueUSD;
        uint256 priceUSDToken;
    }

    /// @notice Struct for redeem operations when calculating allocations
    /// @param extendedLength Length of supported assets array
    /// @param token Current token being processed
    /// @param deltaToken Amount of token to redeem (calculated from shares)
    /// @param totalValueUSD Total value in USD of all assets
    /// @param priceUSDToken Price of the specific token in USD
    /// @param oraclePriceUSDs Array of oracle prices in USD
    /// @param balances Array of balances
    /// @param decimals Array of token decimals
    /// @param isDepegs Array of depeg flags
    /// @param isDispersions Array of dispersion flags
    /// @param isOracleOffs Array of oracle off flags
    /// @param superAssetPPS Price per share of the SuperAsset
    /// @param decimalsToken Decimals of the output token
    /// @param balanceOfDeltaToken Balance of the token being redeemed
    /// @param absDeltaValue Absolute delta value
    /// @param deltaValue Signed delta value
    struct GetAllocationsPrePostOperationsRedeem {
        uint256 extendedLength;
        address token;
        uint256 deltaToken;
        uint256 totalValueUSD;
        uint256 priceUSDToken;
        uint256[] oraclePriceUSDs;
        uint256[] balances;
        uint256[] decimals;
        bool[] isDepegs;
        bool[] isDispersions;
        bool[] isOracleOffs;
        uint256 superAssetPPS;
        uint8 decimalsToken;
        uint256 balanceOfDeltaToken;
        uint256 absDeltaValue;
        int256 deltaValue;
    }

    /// @notice Structure used for getting allocations pre and post operations
    /// @param absoluteAllocationPreOperation Array of pre-operation absolute allocations
    /// @param totalAllocationPreOperation Sum of all pre-operation allocations
    /// @param absoluteAllocationPostOperation Array of post-operation absolute allocations
    /// @param totalAllocationPostOperation Sum of all post-operation allocations
    /// @param absoluteTargetAllocation Array of target absolute allocations
    /// @param totalTargetAllocation Sum of all target allocations
    /// @param vaultWeights Array of vault weights
    struct GetPrePostAllocationReturnValues {
        uint256[] absoluteAllocationPreOperation;
        uint256 totalAllocationPreOperation;
        uint256[] absoluteAllocationPostOperation;
        uint256 totalAllocationPostOperation;
        uint256[] absoluteTargetAllocation;
        uint256 totalTargetAllocation;
        uint256[] vaultWeights;
    }

    /// @notice Structure used for previewing deposit
    /// @param allocations GetPrePostAllocationReturnValues structure
    /// @param amountTokenInAfterFees Amount of token in after fees
    /// @param priceUSDTokenIn Price of token in in USD
    /// @param priceUSDSuperAssetShares Price of SuperAsset shares in USD
    struct PreviewDeposit {
        GetPrePostAllocationReturnValues allocations;
        uint256 amountTokenInAfterFees;
        uint256 priceUSDTokenIn;
        uint256 priceUSDSuperAssetShares;
    }

    /// @notice Structure used for previewing redeem
    /// @param allocations GetPrePostAllocationReturnValues structure
    /// @param priceUSDSuperAssetShares Price of SuperAsset shares in USD
    /// @param priceUSDTokenOut Price of token out in USD
    /// @param amountTokenOutBeforeFees Amount of token out before fees
    struct PreviewRedeem {
        GetPrePostAllocationReturnValues allocations;
        uint256 priceUSDSuperAssetShares;
        uint256 priceUSDTokenOut;
        uint256 amountTokenOutBeforeFees;
    }

    /// @notice Structure to store deposit operation results to avoid stack too deep
    /// @param amountSharesMinted Amount of SuperUSD shares minted
    /// @param swapFee Amount of swap fee paid
    /// @param amountIncentiveUSDDeposit Amount of incentives paid in USD
    struct DepositReturnVars {
        uint256 amountSharesMinted;
        uint256 swapFee;
        int256 amountIncentiveUSDDeposit;
    }

    /// @notice Structure to store redeem operation results to avoid stack too deep
    /// @param amountTokenOutAfterFees Amount of the output asset received after fees
    /// @param swapFee Amount of swap fee paid
    /// @param amountIncentiveUSDRedeem Amount of incentives paid in USD
    struct RedeemReturnVars {
        uint256 amountTokenOutAfterFees;
        uint256 swapFee;
        int256 amountIncentiveUSDRedeem;
    }

    /// @notice Structure to store deposit function arguments to avoid stack too deep
    /// @param receiver Address to receive the minted tokens
    /// @param tokenIn Address of the token to deposit
    /// @param amountTokenToDeposit Amount of token to deposit
    /// @param minSharesOut Minimum amount of shares to receive (slippage protection)
    struct DepositArgs {
        address receiver;
        address tokenIn;
        uint256 amountTokenToDeposit;
        uint256 minSharesOut;
    }

    /// @notice Structure to store redeem function arguments to avoid stack too deep
    /// @param receiver Address to receive the redeemed tokens
    /// @param amountSharesToRedeem Amount of shares to redeem
    /// @param tokenOut Address of the token to redeem to
    /// @param minTokenOut Minimum amount of tokens to receive (slippage protection)
    struct RedeemArgs {
        address receiver;
        uint256 amountSharesToRedeem;
        address tokenOut;
        uint256 minTokenOut;
    }

    /// @notice Structure to store swap function arguments to avoid stack too deep
    /// @param receiver Address to receive the output tokens
    /// @param tokenIn Address of the token to swap from
    /// @param amountTokenToDeposit Amount of token to deposit
    /// @param tokenOut Address of the token to swap to
    /// @param minTokenOut Minimum amount of tokens to receive (slippage protection)
    struct SwapArgs {
        address receiver;
        address tokenIn;
        uint256 amountTokenToDeposit;
        address tokenOut;
        uint256 minTokenOut;
    }

    /// @notice Structure to store swap operation results to avoid stack too deep
    /// @param amountSharesIntermediateStep Amount of shares minted in the intermediate step
    /// @param amountTokenOutAfterFees Amount of tokens received after fees
    /// @param swapFeeIn Amount of swap fee paid for deposit
    /// @param swapFeeOut Amount of swap fee paid for redeem
    /// @param amountIncentivesIn Amount of incentives paid for deposit
    /// @param amountIncentivesOut Amount of incentives paid for redeem
    struct SwapReturnVars {
        uint256 amountSharesIntermediateStep;
        uint256 amountTokenOutAfterFees;
        uint256 swapFeeIn;
        uint256 swapFeeOut;
        int256 amountIncentivesIn;
        int256 amountIncentivesOut;
    }

    /// @notice Structure to store preview swap function arguments to avoid stack too deep
    /// @param tokenIn Address of the token to swap from
    /// @param amountTokenToDeposit Amount of token to deposit
    /// @param tokenOut Address of the token to swap to
    /// @param isSoft Whether to use soft or strict checks
    struct PreviewSwapArgs {
        address tokenIn;
        uint256 amountTokenToDeposit;
        address tokenOut;
        bool isSoft;
    }

    /// @notice Structure to store preview swap operation results to avoid stack too deep
    /// @param amountTokenOutAfterFees Amount of tokens received after fees
    /// @param swapFeeIn Amount of swap fee paid for deposit
    /// @param swapFeeOut Amount of swap fee paid for redeem
    /// @param amountIncentiveUSDDeposit Amount of incentives paid for deposit
    /// @param amountIncentiveUSDRedeem Amount of incentives paid for redeem
    /// @param assetWithBreakerTriggered The asset that triggered a circuit breaker (if any)
    /// @param oraclePriceUSD The oracle price in USD
    /// @param isDepeg Whether the asset is depegged
    /// @param isDispersion Whether the asset has price dispersion
    /// @param isOracleOff Whether the oracle is off
    /// @param tokenInFound Whether the token was found
    /// @param incentiveCalculationSuccess Whether incentive calculation succeeded
    struct PreviewSwapReturnVars {
        uint256 amountTokenOutAfterFees;
        uint256 swapFeeIn;
        uint256 swapFeeOut;
        int256 amountIncentiveUSDDeposit;
        int256 amountIncentiveUSDRedeem;
        address assetWithBreakerTriggered;
        uint256 oraclePriceUSD;
        bool isDepeg;
        bool isDispersion;
        bool isOracleOff;
        bool tokenInFound;
        bool incentiveCalculationSuccess;
    }

    /// @notice Return values for allocation operations used in deposit and redeem functions
    struct AllocationOperationReturnVars {
        // Array of absolute allocations before operation
        uint256[] absoluteAllocationPreOperation;
        // Total allocation before operation
        uint256 totalAllocationPreOperation;
        // Array of absolute allocations after operation
        uint256[] absoluteAllocationPostOperation;
        // Total allocation after operation
        uint256 totalAllocationPostOperation;
        // Array of absolute target allocations
        uint256[] absoluteTargetAllocation;
        // Total target allocation
        uint256 totalTargetAllocation;
        // Array of vault weights
        uint256[] vaultWeights;
        // Amount of assets (for deposit: shares minted, for redeem: token out before fees)
        uint256 amountAssets;
        // Asset with breaker triggered
        address assetWithBreakerTriggered;
        // Oracle price in USD
        uint256 oraclePriceUSD;
        // Is depeg
        bool isDepeg;
        // Is dispersion
        bool isDispersion;
        // Is oracle off
        bool isOracleOff;
        // Token found (for deposit: tokenIn, for redeem: tokenOut)
        bool tokenFound;
    }

    /// @notice Structure to store preview deposit function arguments to avoid stack too deep
    /// @param tokenIn Address of the token to deposit
    /// @param amountTokenToDeposit Amount of token to deposit
    /// @param isSoft Whether to use soft or strict checks
    struct PreviewDepositArgs {
        address tokenIn;
        uint256 amountTokenToDeposit;
        bool isSoft;
    }

    /// @notice Structure to store preview deposit operation results to avoid stack too deep
    /// @param amountSharesMinted Amount of shares minted
    /// @param swapFee Amount of swap fee paid
    /// @param amountIncentiveUSDDeposit Amount of incentives paid
    /// @param assetWithBreakerTriggered The asset that triggered a circuit breaker (if any)
    /// @param oraclePriceUSD The oracle price in USD
    /// @param isDepeg Whether the asset is depegged
    /// @param isDispersion Whether the asset has price dispersion
    /// @param isOracleOff Whether the oracle is off
    /// @param tokenInFound Whether the token was found
    /// @param incentiveCalculationSuccess Whether incentive calculation succeeded
    struct PreviewDepositReturnVars {
        uint256 amountSharesMinted;
        uint256 swapFee;
        int256 amountIncentiveUSDDeposit;
        address assetWithBreakerTriggered;
        uint256 oraclePriceUSD;
        bool isDepeg;
        bool isDispersion;
        bool isOracleOff;
        bool tokenInFound;
        bool incentiveCalculationSuccess;
    }

    /// @notice Structure to store preview redeem function arguments to avoid stack too deep
    /// @param tokenOut Address of the token to redeem to
    /// @param amountSharesToRedeem Amount of shares to redeem
    /// @param isSoft Whether to use soft or strict checks
    struct PreviewRedeemArgs {
        address tokenOut;
        uint256 amountSharesToRedeem;
        bool isSoft;
    }

    /// @notice Structure to store preview redeem operation results to avoid stack too deep
    /// @param amountTokenOutAfterFees Amount of tokens received after fees
    /// @param swapFee Amount of swap fee paid
    /// @param amountIncentiveUSDRedeem Amount of incentives paid
    /// @param assetWithBreakerTriggered The asset that triggered a circuit breaker (if any)
    /// @param oraclePriceUSD The oracle price in USD
    /// @param isDepeg Whether the asset is depegged
    /// @param isDispersion Whether the asset has price dispersion
    /// @param isOracleOff Whether the oracle is off
    /// @param tokenOutFound Whether the token was found
    /// @param incentiveCalculationSuccess Whether incentive calculation succeeded
    struct PreviewRedeemReturnVars {
        uint256 amountTokenOutAfterFees;
        uint256 swapFee;
        int256 amountIncentiveUSDRedeem;
        address assetWithBreakerTriggered;
        uint256 oraclePriceUSD;
        bool isDepeg;
        bool isDispersion;
        bool isOracleOff;
        bool tokenOutFound;
        bool incentiveCalculationSuccess;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the SuperAsset contract
    /// @param name_ Name of the token
    /// @param symbol_ Symbol of the token
    /// @param asset_ Address of the primary asset
    /// @param superGovernor_ Address of the SuperGovernor contract
    /// @param swapFeeInPercentage_ Initial swap fee percentage for deposits
    /// @param swapFeeOutPercentage_ Initial swap fee percentage for redemptions
    function initialize(
        string memory name_,
        string memory symbol_,
        address asset_,
        address superGovernor_,
        uint256 swapFeeInPercentage_,
        uint256 swapFeeOutPercentage_
    )
        external;

    /// @notice Returns the token data for a given token
    /// @param token The token address
    /// @return TokenData structure containing the token data
    function getTokenData(address token) external view returns (TokenData memory);

    /// @notice Returns the PPS of the SuperAsset and the prices of the tokens in USD
    /// @return activeTokens Array of active tokens
    /// @return pricePerTokenUSD Array of prices in USD
    /// @return isDepeg Array of depeg breakers
    /// @return isDispersion Array of dispersion breakers
    /// @return isOracleOff Array of oracle off breakers
    /// @return pps PPS of the SuperAsset
    function getSuperAssetPPS()
        external
        view
        returns (
            address[] memory activeTokens,
            uint256[] memory pricePerTokenUSD,
            bool[] memory isDepeg,
            bool[] memory isDispersion,
            bool[] memory isOracleOff,
            uint256 pps
        );

    /// @notice Mints new tokens. Can only be called by accounts with MINTER_ROLE.
    /// @param to The address that will receive the minted tokens
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice Burns tokens. Can only be called by accounts with BURNER_ROLE.
    /// @param from The address whose tokens will be burned
    /// @param amount The amount of tokens to burn
    function burn(address from, uint256 amount) external;

    /// @notice Gets the current and target allocations of assets
    /// @return absoluteCurrentAllocation Array of current absolute allocations
    /// @return totalCurrentAllocation Sum of all current allocations
    /// @return absoluteTargetAllocation Array of target absolute allocations
    /// @return totalTargetAllocation Sum of all target allocations
    function getAllocations()
        external
        view
        returns (
            uint256[] memory absoluteCurrentAllocation,
            uint256 totalCurrentAllocation,
            uint256[] memory absoluteTargetAllocation,
            uint256 totalTargetAllocation
        );

    /// @notice Gets the allocations before and after an operation deposit
    /// @param token The token address involved in the operation
    /// @param deltaToken The delta token (this is amountTokenToDeposit)
    /// @param amountToken The amount of the token after fees
    /// @param isSoft Whether the operation is soft or strict on checks
    /// @return ret The allocation operation return variables containing:
    /// - absoluteAllocationPreOperation: Array of pre-operation absolute allocations
    /// - totalAllocationPreOperation: Total pre-operation allocation
    /// - absoluteAllocationPostOperation: Array of post-operation absolute allocations
    /// - totalAllocationPostOperation: Total post-operation allocation
    /// - absoluteTargetAllocation: Array of target absolute allocations
    /// - totalTargetAllocation: Total target allocation
    /// - vaultWeights: Array of vault weights
    /// - amountAssets: Amount of shares (for deposit) or tokens (for redeem)
    /// - assetWithBreakerTriggered: Address of the asset with the breaker triggered
    /// - oraclePriceUSD: Oracle price in USD
    /// - isDepeg: Whether the asset is depegged
    /// - isDispersion: Whether the asset is dispersed
    /// - isOracleOff: Whether the asset is oracle off
    /// - tokenFound: Whether the token in/out was found
    function getAllocationsPrePostOperationDeposit(
        address token,
        uint256 deltaToken,
        uint256 amountToken,
        bool isSoft
    )
        external
        view
        returns (AllocationOperationReturnVars memory ret);

    /// @notice Gets the allocations before and after an operation redeem
    /// @param token The token address involved in the operation
    /// @param amountToken The amount of the token to redeem
    /// @param isSoft Whether the operation is soft or strict on checks
    /// @return ret The allocation operation return variables containing:
    /// - absoluteAllocationPreOperation: Array of pre-operation absolute allocations
    /// - totalAllocationPreOperation: Total pre-operation allocation
    /// - absoluteAllocationPostOperation: Array of post-operation absolute allocations
    /// - totalAllocationPostOperation: Total post-operation allocation
    /// - absoluteTargetAllocation: Array of target absolute allocations
    /// - totalTargetAllocation: Total target allocation
    /// - vaultWeights: Array of vault weights
    /// - amountAssets: Amount of assets (tokens to redeem)
    /// - assetWithBreakerTriggered: Address of the asset with the breaker triggered
    /// - oraclePriceUSD: Oracle price in USD
    /// - isDepeg: Whether the asset is depegged
    /// - isDispersion: Whether the asset is dispersed
    /// - isOracleOff: Whether the asset is oracle off
    /// - tokenFound: Whether the token out was found
    function getAllocationsPrePostOperationRedeem(
        address token,
        uint256 amountToken,
        bool isSoft
    )
        external
        view
        returns (AllocationOperationReturnVars memory ret);

    /// @notice Sets the swap fee percentage for deposits (input operations)
    /// @param _feePercentage The fee percentage (scaled by SWAP_FEE_PERC)
    function setSwapFeeInPercentage(uint256 _feePercentage) external;

    /// @notice Sets the swap fee percentage for redemptions (output operations)
    /// @param _feePercentage The fee percentage (scaled by SWAP_FEE_PERC)
    function setSwapFeeOutPercentage(uint256 _feePercentage) external;

    /// @notice Deposits underlying assets to the vault and mints SuperUSD shares.
    /// @param args The deposit arguments (receiver, tokenIn, amountTokenToDeposit, minSharesOut)
    /// @return ret The deposit return variables.
    function deposit(DepositArgs memory args) external returns (DepositReturnVars memory ret);

    /// @notice Redeems SuperUSD shares for underlying assets from a whitelisted vault.
    /// @param args The redeem arguments (receiver, amountSharesToRedeem, tokenOut, minTokenOut)
    /// @return ret The redeem return variables.
    function redeem(RedeemArgs memory args) external returns (RedeemReturnVars memory ret);

    /// @notice Swaps an underlying asset for another.
    /// @param args The swap arguments (receiver, tokenIn, amountTokenToDeposit, tokenOut, minTokenOut)
    /// @return ret The swap return variables
    function swap(SwapArgs memory args) external returns (SwapReturnVars memory ret);

    /// @notice Whitelists a vault
    /// @param vault Address of the vault to whitelist
    /// @param oracle Address of the oracle to use to fetch vault prices
    function whitelistVault(address vault, address oracle) external;

    /// @notice Removes a vault from whitelist
    /// @param vault Address of the vault to remove
    function removeVault(address vault) external;

    /// @notice Whitelists an ERC20 token
    /// @param token Address of the token to whitelist
    function whitelistERC20(address token) external;

    /// @notice Removes an ERC20 token from whitelist
    /// @param token Address of the token to remove
    function removeERC20(address token) external;

    /// @notice Preview a deposit.
    /// @notice Preview deposit to SuperAsset.
    /// @param args The preview deposit arguments (tokenIn, amountTokenToDeposit, isSoft)
    /// @return ret The preview deposit return variables
    function previewDeposit(PreviewDepositArgs memory args)
        external
        view
        returns (PreviewDepositReturnVars memory ret);

    /// @notice Preview a redemption.
    /// @notice Preview redeem from SuperAsset.
    /// @param args The preview redeem arguments (tokenOut, amountSharesToRedeem, isSoft)
    /// @return ret The preview redeem return variables
    function previewRedeem(PreviewRedeemArgs memory args) external view returns (PreviewRedeemReturnVars memory ret);

    /// @notice Preview a swap.
    /// @notice This function should not revert
    /// @param args The preview swap arguments (tokenIn, amountTokenToDeposit, tokenOut, isSoft)
    /// @return ret The preview swap return variables
    function previewSwap(PreviewSwapArgs memory args) external view returns (PreviewSwapReturnVars memory ret);

    /// @notice Gets the price of a token in USD with circuit breakers
    /// @dev This function should not revert, just return booleans for the circuit breakers, it is up to the caller to
    /// decide if to revert
    /// @dev Getting only single unit price
    /// @param tokenIn The address of the token to get the price of
    /// @return priceUSD The price of the token in USD
    /// @return isDepeg Whether the token is depegged
    /// @return isDispersion Whether the token is dispersed
    /// @return isOracleOff Whether the oracle is off
    function getPriceWithCircuitBreakers(address tokenIn)
        external
        view
        returns (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff);

    /// @notice Gets the precision constant used for percentage calculations
    /// @return The precision constant (e.g., 10000 for 4 decimal places)
    function getPrecision() external pure returns (uint256);

    /// @notice Sets the weight for a vault
    /// @param vault The vault address
    /// @param weight The weight percentage (scaled by PRECISION)
    function setWeight(address vault, uint256 weight) external;

    /// @notice Sets target allocations for multiple tokens at once
    /// @param tokens Array of token addresses
    /// @param allocations Array of target allocation percentages (scaled by PRECISION)
    function setTargetAllocations(address[] calldata tokens, uint256[] calldata allocations) external;

    /// @notice Sets the target allocation for a token
    /// @param token The token address
    /// @param allocation The target allocation percentage (scaled by PRECISION)
    function setTargetAllocation(address token, uint256 allocation) external;

    /// @notice Sets the exchange ratio between energy units and USD
    /// @param newRatio The new exchange ratio (scaled by PRECISION)
    /// @dev This is the ratio between energy units and USD
    /// @dev No checks on zero on purpose in case we want to disable incentives
    function setEnergyToUSDExchangeRatio(uint256 newRatio) external;
}
