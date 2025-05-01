// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/SuperAsset/IIncentiveCalculationContract.sol";
import "../interfaces/SuperAsset/IIncentiveFundContract.sol";
import "../interfaces/SuperAsset/IAssetBank.sol";
import "../interfaces/SuperAsset/ISuperAsset.sol";
import "../interfaces/ISuperOracle.sol";

/**
 * @author Superform Labs
 * @title SuperAsset
 * @notice A meta-vault that manages deposits and redemptions across multiple underlying vaults.
 * Implements ERC20 standard for better compatibility with integrators.
 */
contract SuperAsset is AccessControl, ERC20, ISuperAsset {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;

    // --- Storage for ERC20 name/symbol ---
    string private tokenName;
    string private tokenSymbol;

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
    mapping(address token => bool isSupported) public isSupportedUnderlyingVault;
    mapping(address token => bool isSupported) public isSupportedERC20;
    
    EnumerableSet.AddressSet private _supportedVaults;
    address public incentiveCalculationContract;  // Address of the ICC
    address public incentiveFundContract;      // Address of the Incentive Fund Contract
    address public assetBank;        // Address of the Asset Bank Contract

    mapping(address token => uint256 allocation) public targetAllocations;
    mapping(address token => uint256 allocation) public weights;  // Weights for each vault in energy calculation

    ISuperOracle public superOracle;

    uint256 public swapFeeInPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public swapFeeOutPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public energyToUSDExchangeRatio;

    mapping(address token => uint256 priceUSD) public emergencyPrices; // Used when an oracle is down, managed by us

    // --- Addresses ---
    address public constant USD = address(840);

    // SuperOracle related 
    bytes32 public constant AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");

    // --- Modifiers ---
    modifier onlyVault() {
        if (!isSupportedUnderlyingVault[msg.sender]) revert NOT_VAULT();
        _;
    }

    modifier onlyERC20() {
        if (!isSupportedERC20[msg.sender]) revert NOT_ERC20_TOKEN();
        _;
    }

    /**
     * @dev Empty constructor since we're using initialize pattern with Clones
     */
    constructor() ERC20("", "") {
    }

    /**
     * @dev Override name() to use storage variable
     */
    function name() public view override returns (string memory) {
        return tokenName;
    }

    /**
     * @dev Override symbol() to use storage variable
     */
    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        address icc_,
        address ifc_,
        address assetBank_,
        uint256 swapFeeInPercentage_,
        uint256 swapFeeOutPercentage_
    ) external {
        // Ensure this can only be called once
        require(incentiveCalculationContract == address(0), "Already initialized");

        if (icc_ == address(0)) revert ZERO_ADDRESS();
        if (ifc_ == address(0)) revert ZERO_ADDRESS();
        if (assetBank_ == address(0)) revert ZERO_ADDRESS();
        if (swapFeeInPercentage_ > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();
        if (swapFeeOutPercentage_ > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();
        
        incentiveCalculationContract = icc_;
        incentiveFundContract = ifc_;
        assetBank = assetBank_;
        swapFeeInPercentage = swapFeeInPercentage_;
        swapFeeOutPercentage = swapFeeOutPercentage_;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);

        // Initialize ERC20 name and symbol
        tokenName = name_;
        tokenSymbol = symbol_;
    }

    /*//////////////////////////////////////////////////////////////
                EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ISuperAsset
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function setSwapFeeInPercentage(uint256 _feePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feePercentage > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();
        swapFeeInPercentage = _feePercentage;
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function setSwapFeeOutPercentage(uint256 _feePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feePercentage > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();
        swapFeeOutPercentage = _feePercentage;
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function setSuperOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (oracle == address(0)) revert ZERO_ADDRESS();
        superOracle = ISuperOracle(oracle);
        emit SuperOracleSet(oracle);
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function setWeight(address vault, uint256 weight) external onlyRole(VAULT_MANAGER_ROLE) {
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (!isSupportedUnderlyingVault[vault]) revert NOT_VAULT();
        weights[vault] = weight;
        emit WeightSet(vault, weight);
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function setTargetAllocations(address[] calldata tokens, uint256[] calldata allocations) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokens.length != allocations.length) revert INVALID_INPUT();
        
        uint256 totalAllocation;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert ZERO_ADDRESS();
            if (!isSupportedUnderlyingVault[tokens[i]] && !isSupportedERC20[tokens[i]]) revert NOT_SUPPORTED_TOKEN();
            totalAllocation += allocations[i];
        }
        
        for (uint256 i = 0; i < tokens.length; i++) {
            targetAllocations[tokens[i]] = allocations[i];
            emit TargetAllocationSet(tokens[i], allocations[i]);
        }
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function setTargetAllocation(address token, uint256 allocation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZERO_ADDRESS();
        if (!isSupportedUnderlyingVault[token] && !isSupportedERC20[token]) revert NOT_SUPPORTED_TOKEN();

        // NOTE: I am not sure we need this check since the allocations get normalized inside the ICC 
        if (allocation > PRECISION) revert INVALID_ALLOCATION();
        
        targetAllocations[token] = allocation;
        emit TargetAllocationSet(token, allocation);
    }


    /**
     * @inheritdoc ISuperAsset
     */
    function setEnergyToUSDExchangeRatio(uint256 newRatio) external onlyRole(DEFAULT_ADMIN_ROLE) {
        energyToUSDExchangeRatio = newRatio;
        emit EnergyToUSDExchangeRatioSet(newRatio);
    }


    // --- Token Movement Functions ---

    /**
     * @inheritdoc ISuperAsset
     */
    function deposit(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut            // Slippage Protection
    ) public returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit) {
        // First all the non state changing functions 
        if (amountTokenToDeposit == 0) revert ZERO_AMOUNT();
        if (!isSupportedUnderlyingVault[tokenIn] && !isSupportedERC20[tokenIn]) revert NOT_SUPPORTED_TOKEN();
        if (receiver == address(0)) revert ZERO_ADDRESS();

        // Calculate and settle incentives
        (amountSharesMinted, swapFee, amountIncentiveUSDDeposit) = previewDeposit(tokenIn, amountTokenToDeposit);
        if (amountSharesMinted == 0) revert ZERO_AMOUNT();
        // Slippage Check
        if (amountSharesMinted < minSharesOut) revert SLIPPAGE_PROTECTION();

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

    /**
     * @inheritdoc ISuperAsset
     */
    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut
    ) public returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem) {
        if (amountSharesToRedeem == 0) revert ZERO_AMOUNT();
        if (!isSupportedUnderlyingVault[tokenOut] && !isSupportedERC20[tokenOut]) revert NOT_SUPPORTED_TOKEN();
        if (receiver == address(0)) revert ZERO_ADDRESS();

        // Calculate and settle incentives
        (amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem) = previewRedeem(tokenOut, amountSharesToRedeem);
        if (amountTokenOutAfterFees == 0) revert ZERO_AMOUNT();
        // Slippage Check
        if (amountTokenOutAfterFees < minTokenOut) revert SLIPPAGE_PROTECTION();

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

    /**
     * @inheritdoc ISuperAsset
     */
    function swap(
        address receiver,
        address tokenIn,
        uint256 amountTokenToDeposit,
        address tokenOut,
        uint256 minTokenOut
    ) external returns (uint256 amountSharesIntermediateStep, uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentivesIn, int256 amountIncentivesOut) {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        (amountSharesIntermediateStep, swapFeeIn, amountIncentivesIn) = deposit(address(this), tokenIn, amountTokenToDeposit, 0);
        (amountTokenOutAfterFees, swapFeeOut, amountIncentivesOut) = redeem(receiver, amountSharesIntermediateStep, tokenOut, minTokenOut);
        emit Swap(receiver, tokenIn, amountTokenToDeposit, tokenOut, amountSharesIntermediateStep, amountTokenOutAfterFees, swapFeeIn, swapFeeOut, amountIncentivesIn, amountIncentivesOut);
        return (amountSharesIntermediateStep, amountTokenOutAfterFees, swapFeeIn, swapFeeOut, amountIncentivesIn, amountIncentivesOut);
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function whitelistVault(address vault) external onlyRole(VAULT_MANAGER_ROLE) {
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (isSupportedUnderlyingVault[vault]) revert ALREADY_WHITELISTED();
        isSupportedUnderlyingVault[vault] = true;
        _supportedVaults.add(vault);
        emit VaultWhitelisted(vault);
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function removeVault(address vault) external onlyRole(VAULT_MANAGER_ROLE) {
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (!isSupportedUnderlyingVault[vault]) revert NOT_WHITELISTED();
        isSupportedUnderlyingVault[vault] = false;
        _supportedVaults.remove(vault);
        emit VaultRemoved(vault);
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function whitelistERC20(address token) external onlyRole(VAULT_MANAGER_ROLE) {
        if (token == address(0)) revert ZERO_ADDRESS();
        if (isSupportedERC20[token]) revert ALREADY_WHITELISTED();
        isSupportedERC20[token] = true;
        emit ERC20Whitelisted(token);
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function removeERC20(address token) external onlyRole(VAULT_MANAGER_ROLE) {
        if (token == address(0)) revert ZERO_ADDRESS();
        if (!isSupportedERC20[token]) revert NOT_WHITELISTED();
        isSupportedERC20[token] = false;
        emit ERC20Removed(token);
    }

    /**
     * @inheritdoc ISuperAsset
     * @dev This is equivalent to also returning the normalized amount since it can be obtained just by doing absoluteAllocation[i] / totalAllocation
     */
    function getAllocations() public view returns (uint256[] memory absoluteCurrentAllocation, uint256 totalCurrentAllocation, uint256[] memory absoluteTargetAllocation, uint256 totalTargetAllocation) {
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

    /**
     * @inheritdoc ISuperAsset
     */
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
                    revert INSUFFICIENT_BALANCE();
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
     * @inheritdoc ISuperAsset
     */
    function previewDeposit(address tokenIn, uint256 amountTokenToDeposit)
    public
    view
    returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSD)
    {
        if (!isSupportedUnderlyingVault[tokenIn] && !isSupportedERC20[tokenIn]) revert NOT_SUPPORTED_TOKEN();

        // Calculate swap fees (example: 0.1% fee)
        swapFee = Math.mulDiv(amountTokenToDeposit, swapFeeInPercentage, SWAP_FEE_PERC); // 0.1%
        uint256 amountTokenInAfterFees = amountTokenToDeposit - swapFee;

        // Get price of underlying vault shares in USD
        (uint256 priceUSDTokenIn, , , ) = getPriceWithCircuitBreakers(tokenIn);
        (uint256 priceUSDThisShares, , , ) = getPriceWithCircuitBreakers(address(this));

        if (priceUSDTokenIn == 0 || priceUSDThisShares == 0) revert PRICE_USD_ZERO();

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
            allocationPostOperation,
            allocationTarget,
            vaultWeights,
            totalAllocationPreOperation,
            totalAllocationPostOperation,
            totalAllocationTarget,
            energyToUSDExchangeRatio
        );
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function previewRedeem(address tokenOut, uint256 amountSharesToRedeem)
    public
    view
    returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSD)
    {
        if (!isSupportedUnderlyingVault[tokenOut] && !isSupportedERC20[tokenOut]) revert NOT_SUPPORTED_TOKEN();

        // Get price of underlying vault shares in USD
        (uint256 priceUSDThisShares, , , ) = getPriceWithCircuitBreakers(address(this));
        (uint256 priceUSDTokenOut, , , ) = getPriceWithCircuitBreakers(tokenOut);

        // Calculate underlying shares to redeem
        uint256 amountTokenOutBeforeFees = Math.mulDiv(amountSharesToRedeem, priceUSDThisShares, priceUSDTokenOut); // Adjust for decimals

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
            allocationPostOperation,
            allocationTarget,
            vaultWeights,   
            totalAllocationPreOperation,
            totalAllocationPostOperation,
            totalAllocationTarget,
            energyToUSDExchangeRatio
        );
    }

    /**
     * @inheritdoc ISuperAsset
     */
    function previewSwap(address tokenIn, uint256 amountTokenToDeposit, address tokenOut)
    external
    view
    returns (uint256 amountTokenOutAfterFees, uint256 swapFeeIn, uint256 swapFeeOut, int256 amountIncentiveUSDDeposit, int256 amountIncentiveUSDRedeem)
    {
        uint256 amountSharesMinted;
        (amountSharesMinted, swapFeeIn, amountIncentiveUSDDeposit) = previewDeposit(tokenIn, amountTokenToDeposit);
        (amountTokenOutAfterFees, swapFeeOut, amountIncentiveUSDRedeem) = previewRedeem(tokenOut, amountSharesMinted); // incentives are cumulative in this simplified example.
    }

    
    /**
     * @inheritdoc ISuperAsset
     */
    function getPriceWithCircuitBreakers(address tokenIn) public view returns (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff) {
        if (!isSupportedUnderlyingVault[tokenIn] && !isSupportedERC20[tokenIn]) revert NOT_SUPPORTED_TOKEN();

        // Get token decimals
        uint256 one = 10**IERC20Metadata(tokenIn).decimals();
        uint256 stddev;
        uint256 N;
        uint256 M;

        // NOTE: We need to pass oneUnit to get the price of a single unit of asset to check if it has depegged since the depeg threshold regards a single asset
        (priceUSD, stddev, N, M) = superOracle.getQuoteFromProvider(
            one,
            tokenIn,
            USD,
            AVERAGE_PROVIDER
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

    /*//////////////////////////////////////////////////////////////
                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _settleIncentive(address user, int256 amountIncentiveUSD) internal {
        // Pay or take incentives based on the sign of amountIncentive
        if (amountIncentiveUSD > 0) {
            IIncentiveFundContract(incentiveFundContract).payIncentive(user, uint256(amountIncentiveUSD));
        } else if (amountIncentiveUSD < 0) {
            IIncentiveFundContract(incentiveFundContract).takeIncentive(user, uint256(-amountIncentiveUSD));
        }
    }

}
