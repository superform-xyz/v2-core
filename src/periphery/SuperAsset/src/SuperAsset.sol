// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IncentiveCalculationContract.sol";
import "./IncentiveFundContract.sol";
import "./interfaces/ISuperAssetErrors.sol";
import "./interfaces/IIncentiveCalculationContract.sol";
import "./interfaces/IIncentiveFundContract.sol";
import "./interfaces/IAssetBank.sol";
import "./interfaces/ISuperAsset.sol";
import "../../interfaces/ISuperOracle.sol";

/**
 * @title SuperAsset
 * @notice A meta-vault that manages deposits and redemptions across multiple underlying vaults.
 * Implements ERC20 standard for better compatibility with integrators.
 */
contract SuperAsset is AccessControl, ERC20, ISuperAssetErrors, ISuperAsset {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;

    // --- Roles ---
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant SWAP_FEE_MANAGER_ROLE = keccak256("SWAP_FEE_MANAGER_ROLE");
    bytes32 public constant INCENTIVE_FUND_MANAGER = keccak256("INCENTIVE_FUND_MANAGER");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // --- Constants ---
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_SWAP_FEE_PERCENTAGE = 10**4; // Max 10% (1000 basis points)
    uint256 public constant DEPEG_LOWER_THRESHOLD = 98e16; // 0.98
    uint256 public constant DEPEG_UPPER_THRESHOLD = 102e16; // 1.02
    uint256 public constant DISPERSION_THRESHOLD = 1e16; // 1% relative standard deviation threshold
    uint256 public constant SWAP_FEE_PERC = 10**6; 

    // --- State ---
    mapping(address => bool) public isVault;
    mapping(address => bool) public isERC20;
    
    EnumerableSet.AddressSet private _supportedVaults;
    address public immutable incentiveCalculationContract;  // Address of the ICC
    address public immutable incentiveFundContract;      // Address of the Incentive Fund Contract
    address public immutable assetBank;        // Address of the Asset Bank Contract

    mapping(address => uint256) public targetAllocations;
    mapping(address => uint256) public weights;  // Weights for each vault in energy calculation

    address public settlementTokenIn;
    address public settlementTokenOut;
    ISuperOracle public superOracle;

    uint256 public swapFeeInPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public swapFeeOutPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public energyToUSDExchangeRatio;

    mapping(address => uint256) public emergencyPrices; // Used when an oracle is down, managed by us

    // --- Addresses ---
    // TODO: Fix it accordingly
    address public constant USD = 0x0000000000000000000000000000000000000001;

    // SuperOracle related 
    bytes32 public constant AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");

    // --- Modifiers ---
    modifier onlyVault() {
        if (!isVault[msg.sender]) revert NotVault();
        _;
    }

    modifier onlyERC20() {
        if (!isERC20[msg.sender]) revert NotERC20Token();
        _;
    }

    /**
     * @dev Constructor initializes the ERC20 token with name and symbol
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     * @param icc_ Address of the Incentive Calculation Contract
     * @param ifc_ Address of the Incentive Fund Contract
     * @param assetBank_ Address of the Asset Bank Contract
     * @param swapFeeInPercentage_ Swap fee as a percentage (e.g., 10 for 0.1%)
     * @param swapFeeOutPercentage_ Swap fee as a percentage (e.g., 10 for 0.1%)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address icc_,
        address ifc_,
        address assetBank_,
        uint256 swapFeeInPercentage_,
        uint256 swapFeeOutPercentage_
    ) ERC20(name_, symbol_) {
        if (icc_ == address(0)) revert ZeroAddress();
        if (ifc_ == address(0)) revert ZeroAddress();
        if (assetBank_ == address(0)) revert ZeroAddress();
        if (swapFeeInPercentage_ > MAX_SWAP_FEE_PERCENTAGE) revert InvalidSwapFeePercentage();
        if (swapFeeOutPercentage_ > MAX_SWAP_FEE_PERCENTAGE) revert InvalidSwapFeePercentage();
        
        incentiveCalculationContract = icc_;
        incentiveFundContract = ifc_;
        assetBank = assetBank_;
        swapFeeInPercentage = swapFeeInPercentage_;
        swapFeeOutPercentage = swapFeeOutPercentage_;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    /**
     * @dev Mints new tokens. Can only be called by accounts with MINTER_ROLE.
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens. Can only be called by accounts with BURNER_ROLE.
     * @param from The address whose tokens will be burned
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    // NOTE:
    // This is equivalent to also returning the normalized amount since it can be obtained just by doing absoluteAllocation[i] / totalAllocation
    function getAllocations() public view returns (uint256[] memory absoluteCurrentAllocation, uint256 totalCurrentAllocation, uint256[] memory absoluteTargetAllocation, uint256 totalTargetAllocation) {
        // Placeholder for the current allocation normalized
        // This function should return the current allocation of assets in the SuperUSD contract
        // For now, we return an empty array
        uint256 length = _supportedVaults.length();
        absoluteCurrentAllocation = new uint256[](length);
        absoluteTargetAllocation = new uint256[](length);
        for (uint256 i; i < length; i++) {
            address vault = _supportedVaults.at(i);
            absoluteCurrentAllocation[i] = IERC20(vault).balanceOf(address(this));
            totalCurrentAllocation += absoluteCurrentAllocation[i];
            absoluteTargetAllocation[i] = targetAllocations[vault];
            totalTargetAllocation += absoluteTargetAllocation[i];
        }
    }


    function getAllocationsPrePostOperation(address token, int256 deltaToken) public view returns (
        uint256[] memory absoluteAllocationPreOperation, 
        uint256 totalAllocationPreOperation, 
        uint256[] memory absoluteAllocationPostOperation, 
        uint256 totalAllocationPostOperation, 
        uint256[] memory absoluteTargetAllocation, 
        uint256 totalTargetAllocation,
        uint256[] memory vaultWeights) {
        uint256 length = _supportedVaults.length();
        absoluteAllocationPreOperation = new uint256[](length);
        absoluteAllocationPostOperation = new uint256[](length);
        absoluteTargetAllocation = new uint256[](length);
        vaultWeights = new uint256[](length);
        for (uint256 i; i < length; i++) {
            address vault = _supportedVaults.at(i);
            absoluteAllocationPreOperation[i] = IERC20(vault).balanceOf(address(this));
            totalAllocationPreOperation += absoluteAllocationPreOperation[i];
            absoluteAllocationPostOperation[i] = absoluteAllocationPreOperation[i];
            if(token == vault) {
                if (deltaToken < 0 && uint256(-deltaToken) > absoluteAllocationPreOperation[i]) {
                    revert InsufficientBalance();
                }
                absoluteAllocationPostOperation[i] = uint256(int256(absoluteAllocationPreOperation[i]) + deltaToken);
            }
            totalAllocationPostOperation += absoluteAllocationPostOperation[i];
            absoluteTargetAllocation[i] = targetAllocations[vault];
            totalTargetAllocation += absoluteTargetAllocation[i];
            vaultWeights[i] = weights[vault];
        }
    }


    /**
     * @notice Sets the swap fee percentage for deposits (input operations)
     * @param _feePercentage The fee percentage (scaled by SWAP_FEE_PERC)
     */
    function setSwapFeeInPercentage(uint256 _feePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feePercentage > MAX_SWAP_FEE_PERCENTAGE) revert InvalidSwapFeePercentage();
        swapFeeInPercentage = _feePercentage;
    }

    /**
     * @notice Sets the swap fee percentage for redemptions (output operations)
     * @param _feePercentage The fee percentage (scaled by SWAP_FEE_PERC)
     */
    function setSwapFeeOutPercentage(uint256 _feePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feePercentage > MAX_SWAP_FEE_PERCENTAGE) revert InvalidSwapFeePercentage();
        swapFeeOutPercentage = _feePercentage;
    }

    // --- Token Movement Functions ---

    function deposit(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut            // Slippage Protection
    ) public returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit) {
        // First all the non state changing functions 
        if (amountTokenToDeposit == 0) revert ZeroAmount();
        if (!isVault[tokenIn] && !isERC20[tokenIn]) revert NotSupportedToken();
        if (receiver == address(0)) revert ZeroAddress();

        // Calculate and settle incentives
        (amountSharesMinted, swapFee, amountIncentiveUSDDeposit) = previewDeposit(tokenIn, amountTokenToDeposit);
        if (amountSharesMinted == 0) revert ZeroAmount();
        // Slippage Check
        if (amountSharesMinted < minSharesOut) revert SlippageProtection();

        // State Changing Functions //

        // Settle Incentives
        _settleIncentive(msg.sender, amountIncentiveUSDDeposit);

        // Transfer the tokenIn from the sender to this contract
        // For now, assuming shares are held in this contract, maybe they will have to be held in another contract balance sheet
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountTokenToDeposit);

        // Transfer swap fees to Asset Bank while holding the rest in the contract, since the full amount was already transferred in the beginning of the function
        IERC20(tokenIn).safeTransfer(assetBank, swapFee);

        // Mint SuperUSD shares
        _mint(receiver, amountSharesMinted);

        emit Deposit(receiver, tokenIn, amountTokenToDeposit, amountSharesMinted, swapFee, amountIncentiveUSDDeposit);
    }

    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut
    ) public returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem) {
        if (amountSharesToRedeem == 0) revert ZeroAmount();
        if (!isVault[tokenOut] && !isERC20[tokenOut]) revert NotSupportedToken();
        if (receiver == address(0)) revert ZeroAddress();

        // Calculate and settle incentives
        (amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem) = previewRedeem(tokenOut, amountSharesToRedeem);
        if (amountTokenOutAfterFees == 0) revert ZeroAmount();
        // Slippage Check
        if (amountTokenOutAfterFees < minTokenOut) revert SlippageProtection();

        // State Changing Functions //

        // Settle Incentives
        _settleIncentive(msg.sender, amountIncentiveUSDRedeem);

        // Burn SuperUSD shares
        _burn(msg.sender, amountSharesToRedeem);  // Use a proper burning mechanism

        // Transfer swap fees to Asset Bank
        IERC20(tokenOut).safeTransferFrom(address(this), assetBank, swapFee);

        // Transfer assets to receiver
        // For now, assuming shares are held in this contract, maybe they will have to be held in another contract balance sheet
        IERC20(tokenOut).safeTransfer(receiver, amountTokenOutAfterFees);

        emit Redeem(receiver, tokenOut, amountSharesToRedeem, amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem);
    }

    function swap(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        address tokenOut,
        uint256 minTokenOut
    ) external returns (uint256 amountSharesIntermediateStep, uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentivesIn, int256 amountIncentivesOut) {
        if (receiver == address(0)) revert ZeroAddress();
        (amountSharesIntermediateStep, swapFeeIn, amountIncentivesIn) = deposit(address(this), tokenIn, amountTokenToDeposit, 0);
        (amountTokenOutAfterFees, swapFeeOut, amountIncentivesOut) = redeem(receiver, amountSharesIntermediateStep, tokenOut, minTokenOut);
        emit Swap(receiver, tokenIn, amountTokenToDeposit, tokenOut, amountSharesIntermediateStep, amountTokenOutAfterFees, swapFeeIn, swapFeeOut, amountIncentivesIn, amountIncentivesOut);
        return (amountSharesIntermediateStep, amountTokenOutAfterFees, swapFeeIn, swapFeeOut, amountIncentivesIn, amountIncentivesOut);
    }

    // --- Vault Whitelist Management ---
    function whitelistVault(address vault) external onlyRole(VAULT_MANAGER_ROLE) {
        if (vault == address(0)) revert ZeroAddress();
        if (isVault[vault]) revert AlreadyWhitelisted();
        isVault[vault] = true;
        _supportedVaults.add(vault);
        emit VaultWhitelisted(vault);
    }

    function removeVault(address vault) external onlyRole(VAULT_MANAGER_ROLE) {
        if (vault == address(0)) revert ZeroAddress();
        if (!isVault[vault]) revert NotWhitelisted();
        isVault[vault] = false;
        _supportedVaults.remove(vault);
        emit VaultRemoved(vault);
    }

    function whitelistERC20(address token) external onlyRole(VAULT_MANAGER_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (isERC20[token]) revert AlreadyWhitelisted();
        isERC20[token] = true;
        emit ERC20Whitelisted(token);
    }

    function removeERC20(address token) external onlyRole(VAULT_MANAGER_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (!isERC20[token]) revert NotWhitelisted();
        isERC20[token] = false;
        emit ERC20Removed(token);
    }

    // --- View Functions ---
    function previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
    public
    view
    returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSD)
    {
        if (!isVault[tokenIn] && !isERC20[tokenIn]) revert NotSupportedToken();

        // Calculate swap fees (example: 0.1% fee)
        swapFee = Math.mulDiv(amountTokenToDeposit, swapFeeInPercentage, SWAP_FEE_PERC); // 0.1%
        uint256 amountTokenInAfterFees = amountTokenToDeposit - swapFee;

        // Get price of underlying vault shares in USD
        (uint256 priceUSDTokenIn, bool isDepegTokenIn, bool isDispersionTokenIn, bool isOracleOffTokenIn) = getPriceWithCircuitBreakers(tokenIn);
        (uint256 priceUSDThisShares, bool isDepegShares, bool isDispersionShares, bool isOracleOffShares) = getPriceWithCircuitBreakers(address(this));

        // Calculate SuperUSD shares to mint
        amountSharesMinted = Math.mulDiv(amountTokenInAfterFees, priceUSDTokenIn, priceUSDThisShares); // Adjust for decimals

        // Get current and post-operation allocations
        (
            uint256[] memory allocationPreOperation,
            uint256 totalAllocationPreOperation,
            uint256[] memory allocationPostOperation,
            uint256 totalAllocationPostOperation,
            uint256[] memory allocationTarget,
            uint256 totalAllocationTarget,
            uint256[] memory vaultWeights
        ) = getAllocationsPrePostOperation(tokenIn, int256(amountTokenToDeposit));

        // Calculate incentives (using ICC)
        amountIncentiveUSD = IIncentiveCalculationContract(incentiveCalculationContract).calculateIncentive(
            allocationPreOperation,
            totalAllocationPreOperation,
            allocationPostOperation,
            totalAllocationPostOperation,
            allocationTarget,
            totalAllocationTarget,
            vaultWeights,
            energyToUSDExchangeRatio
        );
    }

    function previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
    public
    view
    returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSD)
    {
        if (!isVault[tokenOut] && !isERC20[tokenOut]) revert NotSupportedToken();

        // Get price of underlying vault shares in USD
        (uint256 priceUSDThisShares, bool isDepegShares, bool isDispersionShares, bool isOracleOffShares) = getPriceWithCircuitBreakers(address(this));
        (uint256 priceUSDTokenOut, bool isDepegTokenOut, bool isDispersionTokenOut, bool isOracleOffTokenOut) = getPriceWithCircuitBreakers(tokenOut);

        // Calculate underlying shares to redeem
        uint256 amountTokenOutBeforeFees = Math.mulDiv(amountSharesToRedeem, priceUSDThisShares, priceUSDTokenOut); // Adjust for decimals

        // Calculate swap fees on output (example: 0.1% fee)
        // Calculate swap fees (example: 0.1% fee)
        swapFee = Math.mulDiv(amountTokenOutBeforeFees, swapFeeOutPercentage, SWAP_FEE_PERC); // 0.1%
        amountTokenOutAfterFees = amountTokenOutBeforeFees - swapFee;

        // Get current and post-operation allocations
        (
            uint256[] memory allocationPreOperation,
            uint256 totalAllocationPreOperation,
            uint256[] memory allocationPostOperation,
            uint256 totalAllocationPostOperation,
            uint256[] memory allocationTarget,
            uint256 totalAllocationTarget,
            uint256[] memory vaultWeights
        ) = getAllocationsPrePostOperation(tokenOut, -int256(amountTokenOutBeforeFees));

        // Calculate incentives (using ICC)
        amountIncentiveUSD = IIncentiveCalculationContract(incentiveCalculationContract).calculateIncentive(
            allocationPreOperation,
            totalAllocationPreOperation,
            allocationPostOperation,
            totalAllocationPostOperation,
            allocationTarget,
            totalAllocationTarget,
            vaultWeights,
            energyToUSDExchangeRatio
        );
    }

    function previewSwap(address tokenIn, uint256 amountTokenToDeposit, address tokenOut)
    public
    view
    returns (uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentiveUSDDeposit, int256 amountIncentiveUSDRedeem)
    {
        uint256 amountSharesMinted;
        (amountSharesMinted, swapFeeIn, amountIncentiveUSDDeposit) = previewDeposit(tokenIn, amountTokenToDeposit);
        (amountTokenOutAfterFees, swapFeeOut, amountIncentiveUSDRedeem) = previewRedeem(tokenOut, amountSharesMinted); // incentives are cumulative in this simplified example.
    }

    
    // @dev: This function should not revert, just return booleans for the circuit breakers, it is up to the caller to decide if to revert 
    // @dev: Getting only single unit price
    function getPriceWithCircuitBreakers(address tokenIn) public view returns (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff) {
        if (!isVault[tokenIn] && !isERC20[tokenIn]) revert NotSupportedToken();

        // Get token decimals
        uint256 oneUnit = 10**IERC20(tokenIn).decimals();
        uint256 stddev;
        uint256 N;
        uint256 M;

        // NOTE: We need to pass oneUnit to get the price of a single unit of asset to check if it has depegged since the depeg threshold regards a single asset
        (priceUSD, stddev, N, M) = superOracle.getQuoteFromProvider(
            oneUnit,  
            tokenIn,
            USD,                    // TODO: Add USD definition
            AVERAGE_PROVIDER        // TODO: Add AVERAGE_PROVIDER definition, taking it from SuperOracle
        );

        // Circuit Breaker for Oracle Off
        if (M == 0) {
            priceUSD = emergencyPrices[tokenIn];
            isOracleOff = true;
        } else {
            // Circuit Breaker for Depeg - price deviates more than ±2% from expected
            if (priceUSD < DEPEG_LOWER_THRESHOLD || priceUSD > DEPEG_UPPER_THRESHOLD) {
                isDepeg = true;
            } else {
                // Calculate relative standard deviation
                uint256 relativeStdDev = Math.mulDiv(stddev, PRECISION, priceUSD);

                // Circuit Breaker for Dispersion
                if (relativeStdDev > DISPERSION_THRESHOLD) {
                    isDispersion = true;
                }
            }
        }
        return (priceUSD, isDepeg, isDispersion, isOracleOff);
    }

    // --- Settlement Token Management ---

    function setSettlementTokenIn(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        settlementTokenIn = token;
        emit SettlementTokenInSet(token);
    }

    function setSettlementTokenOut(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        settlementTokenOut = token;
        emit SettlementTokenOutSet(token);
    }

    function setSuperOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (oracle == address(0)) revert ZeroAddress();
        superOracle = ISuperOracle(oracle);
        emit SuperOracleSet(oracle);
    }

    // --- Admin Functions ---
    function setWeight(address vault, uint256 weight) external onlyRole(VAULT_MANAGER_ROLE) {
        if (vault == address(0)) revert ZeroAddress();
        if (!isVault[vault]) revert NotVault();
        weights[vault] = weight;
        emit WeightSet(vault, weight);
    }

    // --- Internal Functions ---
    function _settleIncentive(address user, int256 amountIncentiveUSD) internal {
        // Pay or take incentives based on the sign of amountIncentive
        if (amountIncentiveUSD > 0) {
            IIncentiveFundContract(incentiveFundContract).payIncentive(user, uint256(amountIncentiveUSD));
        } else if (amountIncentiveUSD < 0) {
            IIncentiveFundContract(incentiveFundContract).takeIncentive(user, uint256(-amountIncentiveUSD));
        }
    }

    /**
     * @notice Sets the target allocation for a token
     * @param token The token address
     * @param allocation The target allocation percentage (scaled by PRECISION)
     */
    function setTargetAllocation(address token, uint256 allocation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (!isVault[token] && !isERC20[token]) revert NotSupportedToken();

        // NOTE: I am not sure we need this check since the allocations get normalized inside the ICC 
        if (allocation > PRECISION) revert InvalidAllocation();
        
        targetAllocations[token] = allocation;
        emit TargetAllocationSet(token, allocation);
    }

    /**
     * @notice Sets target allocations for multiple tokens at once
     * @param tokens Array of token addresses
     * @param allocations Array of target allocation percentages (scaled by PRECISION)
     */
    function setTargetAllocations(address[] calldata tokens, uint256[] calldata allocations) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokens.length != allocations.length) revert InvalidInput();
        
        uint256 totalAllocation;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert ZeroAddress();
            if (!isVault[tokens[i]] && !isERC20[tokens[i]]) revert NotSupportedToken();

            // NOTE: I am not sure we need this check since the allocations get normalized inside the ICC 
            // if (allocations[i] > PRECISION) revert InvalidAllocation();

            totalAllocation += allocations[i];
        }

        // NOTE: I am not sure we need this check since the allocations get normalized inside the ICC         
        // if (totalAllocation > PRECISION) revert InvalidTotalAllocation();
        
        for (uint256 i = 0; i < tokens.length; i++) {
            targetAllocations[tokens[i]] = allocations[i];
            emit TargetAllocationSet(tokens[i], allocations[i]);
        }
    }

    /**
     * @notice Sets the exchange ratio between energy units and USD
     * @param newRatio The new exchange ratio (scaled by PRECISION)
     * @dev This is the ratio between energy units and USD
     * @dev No checks on zero on purpose in case we want to disable incentives
     */
    function setEnergyToUSDExchangeRatio(uint256 newRatio) external onlyRole(DEFAULT_ADMIN_ROLE) {
        energyToUSDExchangeRatio = newRatio;
        emit EnergyToUSDExchangeRatioSet(newRatio);
    }
}

// --- Events ---
event VaultWhitelisted(address vault);
event VaultRemoved(address vault);
event ERC20Whitelisted(address token);
event ERC20Removed(address token);
event SettlementTokenInSet(address token);
event SettlementTokenOutSet(address token);
event SuperOracleSet(address oracle);
event TargetAllocationSet(address token, uint256 allocation);
event EnergyToUSDExchangeRatioSet(uint256 newRatio);
event WeightSet(address indexed vault, uint256 weight);
