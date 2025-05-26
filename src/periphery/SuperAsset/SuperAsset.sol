// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import { ISuperOracle } from "../interfaces/ISuperOracle.sol";
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperAsset } from "../interfaces/SuperAsset/ISuperAsset.sol";
import { ISuperAssetFactory } from "../interfaces/SuperAsset/ISuperAssetFactory.sol";
import { IYieldSourceOracle } from "../../../src/core/interfaces/accounting/IYieldSourceOracle.sol";
import { IIncentiveCalculationContract } from "../interfaces/SuperAsset/IIncentiveCalculationContract.sol";
import { IIncentiveFundContract } from "../interfaces/SuperAsset/IIncentiveFundContract.sol";

/**
 * @title SuperAsset
 * @author Superform Labs
 * @notice A meta-vault that manages deposits and redemptions across multiple underlying vaults.
 * Implements ERC20 standard for compatibility with integrators.
 */
contract SuperAsset is AccessControl, ERC20, ISuperAsset {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using Math for uint256;

    // --- Storage for ERC20 variables ---
    string private tokenName;
    string private tokenSymbol;

    // --- Interfaces ---
    ISuperOracle public superOracle;
    ISuperGovernor public superGovernor;

    // --- Constants ---
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_SWAP_FEE_PERCENTAGE = 10 ** 4; // Max 10% (1000 basis points)
    uint256 public constant DEPEG_LOWER_THRESHOLD = 98e16; // 0.98
    uint256 public constant DEPEG_UPPER_THRESHOLD = 102e16; // 1.02
    uint256 public constant DISPERSION_THRESHOLD = 1e16; // 1% relative standard deviation threshold
    uint256 public constant SWAP_FEE_PERC = 10 ** 6;

    // --- State ---
    mapping(address token => TokenData data) public tokenData;
    mapping(address token => address oracle) private _tokenOracles;

    // @notice Contains supported Vaults shares and standard ERC20s
    EnumerableSet.AddressSet private _supportedVaults;
    EnumerableSet.AddressSet private _activeAssets;

    uint256 public swapFeeInPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public swapFeeOutPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public energyToUSDExchangeRatio;

    mapping(address token => uint256 priceUSD) public emergencyPrices; // Used when an oracle is down, managed by us

    // --- Addresses ---
    address public constant USD = address(840);

    bytes32 public _SUPER_ASSET_FACTORY;

    // SuperOracle related
    bytes32 public constant AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");

    // --- Modifiers ---
    modifier onlyVault() {
        if (!tokenData[msg.sender].isSupportedUnderlyingVault) revert NOT_VAULT();
        _;
    }

    modifier onlyERC20() {
        if (!tokenData[msg.sender].isSupportedERC20) revert NOT_ERC20_TOKEN();
        _;
    }

    modifier onlyStrategist() {
        ISuperAssetFactory factory = ISuperAssetFactory(superGovernor.getAddress(superGovernor.SUPER_ASSET_FACTORY()));
        if (msg.sender != factory.getSuperAssetStrategist(address(this))) revert UNAUTHORIZED();
        _;
    }

    modifier onlyManager() {
        ISuperAssetFactory factory = ISuperAssetFactory(superGovernor.getAddress(superGovernor.SUPER_ASSET_FACTORY()));
        if (msg.sender != factory.getSuperAssetManager(address(this))) revert UNAUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    constructor() ERC20("", "") { }

    /// @inheritdoc ISuperAsset
    function initialize(
        string memory name_,
        string memory symbol_,
        address superGovernor_,
        uint256 swapFeeInPercentage_,
        uint256 swapFeeOutPercentage_
    )
        external
    {
        // Ensure this can only be called once
        if (address(superGovernor) != address(0)) revert ALREADY_INITIALIZED();

        if (swapFeeInPercentage_ > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();
        if (swapFeeOutPercentage_ > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();

        swapFeeInPercentage = swapFeeInPercentage_;
        swapFeeOutPercentage = swapFeeOutPercentage_;

        // Initialize ERC20 name and symbol
        tokenName = name_;
        tokenSymbol = symbol_;

        superGovernor = ISuperGovernor(superGovernor_);
        _SUPER_ASSET_FACTORY = superGovernor.SUPER_ASSET_FACTORY();
    }

    /*//////////////////////////////////////////////////////////////
                            MANAGER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperAsset
    function whitelistERC20(address token, address oracle) external onlyManager {
        if (token == address(0)) revert ZERO_ADDRESS();
        if (tokenData[token].isSupportedERC20) revert ALREADY_WHITELISTED();
        tokenData[token].isSupportedERC20 = true;

        _supportedVaults.add(token);
        _activeAssets.add(token);

        if (oracle != address(0)) {
            _tokenOracles[token] = oracle;
        } else {
            _tokenOracles[token] = superGovernor.getAddress(superGovernor.SUPER_ORACLE());
        }
        emit ERC20Whitelisted(token);
    }

    /// @inheritdoc ISuperAsset
    function removeERC20(address token) external onlyManager {
        if (token == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[token].isSupportedERC20) revert NOT_WHITELISTED();

        tokenData[token].isSupportedERC20 = false;
        _supportedVaults.remove(token);

        if (IERC20(token).balanceOf(address(this)) == 0) {
            _activeAssets.remove(token);
            _tokenOracles[token] = address(0);
        }
        emit ERC20Removed(token);
    }

    /// @inheritdoc ISuperAsset
    function whitelistVault(address vault, address oracle) external onlyManager {
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (tokenData[vault].isSupportedUnderlyingVault) revert ALREADY_WHITELISTED();

        tokenData[vault].isSupportedUnderlyingVault = true;

        _supportedVaults.add(vault);
        _activeAssets.add(vault);

        if (oracle != address(0)) {
            _tokenOracles[vault] = oracle;
        } else {
            _tokenOracles[vault] = superGovernor.getAddress(superGovernor.SUPER_ORACLE());
        }
        emit VaultWhitelisted(vault);
    }

    /// @inheritdoc ISuperAsset
    function removeVault(address vault) external onlyManager {
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[vault].isSupportedUnderlyingVault) revert NOT_WHITELISTED();

        tokenData[vault].isSupportedUnderlyingVault = false;
        _supportedVaults.remove(vault);

        if (IERC20(vault).balanceOf(address(this)) == 0) {
            _activeAssets.remove(vault);
            _tokenOracles[vault] = address(0);
        }
        emit VaultRemoved(vault);
    }

    /// @inheritdoc ISuperAsset
    function setSwapFeeInPercentage(uint256 _feePercentage) external onlyManager {
        if (_feePercentage > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();
        swapFeeInPercentage = _feePercentage;
    }

    /// @inheritdoc ISuperAsset
    function setSwapFeeOutPercentage(uint256 _feePercentage) external onlyManager {
        if (_feePercentage > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();
        swapFeeOutPercentage = _feePercentage;
    }

    /// @inheritdoc ISuperAsset
    function setSuperOracle(address oracle) external onlyManager {
        if (oracle == address(0)) revert ZERO_ADDRESS();
        superOracle = ISuperOracle(oracle);
        emit SuperOracleSet(oracle);
    }

    /// @inheritdoc ISuperAsset
    function setWeight(address vault, uint256 weight) external onlyManager {
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[vault].isSupportedUnderlyingVault) revert NOT_VAULT();
        tokenData[vault].weights = weight;
        emit WeightSet(vault, weight);
    }

    /// @inheritdoc ISuperAsset
    function setEnergyToUSDExchangeRatio(uint256 newRatio) external onlyManager {
        energyToUSDExchangeRatio = newRatio;
        emit EnergyToUSDExchangeRatioSet(newRatio);
    }

    /// @inheritdoc ISuperAsset
    function mint(address to, uint256 amount) external onlyManager {
        _mint(to, amount);
    }

    /// @inheritdoc ISuperAsset
    function burn(address from, uint256 amount) external onlyManager {
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          STRATEGIST FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperAsset
    function setTargetAllocations(address[] calldata tokens, uint256[] calldata allocations) external onlyStrategist {
        if (tokens.length != allocations.length) revert INVALID_INPUT();

        uint256 totalAllocation;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert ZERO_ADDRESS();
            if (!tokenData[tokens[i]].isSupportedUnderlyingVault && !tokenData[tokens[i]].isSupportedERC20) {
                revert NOT_SUPPORTED_TOKEN();
            }
            totalAllocation += allocations[i];
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            tokenData[tokens[i]].targetAllocations = allocations[i];
            emit TargetAllocationSet(tokens[i], allocations[i]);
        }
    }

    /// @inheritdoc ISuperAsset
    function setTargetAllocation(address token, uint256 allocation) external onlyStrategist {
        if (token == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[token].isSupportedUnderlyingVault && !tokenData[token].isSupportedERC20) {
            revert NOT_SUPPORTED_TOKEN();
        }

        // @dev Allocations get normalized inside the ICC so we dont need to additional checks here
        tokenData[token].targetAllocations = allocation;
        emit TargetAllocationSet(token, allocation);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperAsset
    function deposit(
        address receiver,
        address yieldSourceShare,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut // Slippage Protection
    )
        public
        returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit)
    {
        PreviewErrors memory errors;
        // First all the non state changing functions
        if (receiver == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[yieldSourceShare].isSupportedUnderlyingVault && !tokenData[yieldSourceShare].isSupportedERC20) {
            revert NOT_SUPPORTED_TOKEN();
        }

        // Circuit Breakers preventing deposit
        uint256 underlyingSuperVaultAssetPriceUSD;
        (underlyingSuperVaultAssetPriceUSD, errors.isDepeg, errors.isDispersion, errors.isOracleOff) =
            getPriceWithCircuitBreakers(IERC4626(yieldSourceShare).asset());
        if (underlyingSuperVaultAssetPriceUSD == 0) revert UNDERLYING_SV_ASSET_PRICE_ZERO();
        if (errors.isDepeg) revert UNDERLYING_SV_ASSET_PRICE_DEPEG();
        if (errors.isDispersion) revert UNDERLYING_SV_ASSET_PRICE_DISPERSION();
        if (errors.isOracleOff) revert UNDERLYING_SV_ASSET_PRICE_ORACLE_OFF();

        bool isSuccess;

        // Calculate and settle incentives
        // NOTE: For deposits, we want strict checks
        (amountSharesMinted, swapFee, amountIncentiveUSDDeposit, isSuccess) =
            previewDeposit(yieldSourceShare, amountTokenToDeposit, false);
        if (amountSharesMinted == 0) revert ZERO_AMOUNT();
        // Slippage Check
        if (amountSharesMinted < minSharesOut) revert SLIPPAGE_PROTECTION();

        // State Changing Functions //

        // Settle Incentives
        _settleIncentive(msg.sender, amountIncentiveUSDDeposit);
        // Transfer the tokenIn from the sender to this contract
        // For now, assuming shares are held in this contract, maybe they will have to be held in another contract
        // balance sheet
        IERC20(yieldSourceShare).safeTransferFrom(msg.sender, address(this), amountTokenToDeposit);

        address superbank = superGovernor.getAddress(superGovernor.SUPER_BANK());
        IERC20(yieldSourceShare).safeTransfer(superbank, swapFee);

        // Mint SuperUSD shares
        _mint(receiver, amountSharesMinted);

        emit Deposit(
            receiver, yieldSourceShare, amountTokenToDeposit, amountSharesMinted, swapFee, amountIncentiveUSDDeposit
        );
    }

    /// @inheritdoc ISuperAsset
    function redeem(
        address receiver,
        uint256 amountSharesToRedeem,
        address tokenOut,
        uint256 minTokenOut
    )
        public
        returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem)
    {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[tokenOut].isSupportedUnderlyingVault && !tokenData[tokenOut].isSupportedERC20) {
            revert NOT_SUPPORTED_TOKEN();
        }

        bool isSuccess;

        // Calculate and settle incentives
        // NOTE: For redemptions, we want soft checks
        (amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem, isSuccess) =
            previewRedeem(tokenOut, amountSharesToRedeem, false);
        if (amountTokenOutAfterFees == 0) revert ZERO_AMOUNT();
        // Slippage Check
        if (amountTokenOutAfterFees < minTokenOut) revert SLIPPAGE_PROTECTION();

        // State Changing Functions //
        
        // Settle Incentives
        _settleIncentive(msg.sender, amountIncentiveUSDRedeem);

        // Burn SuperUSD shares
        _burn(msg.sender, amountSharesToRedeem); // Use a proper burning mechanism

        // Transfer swap fees to Asset Bank
        address superbank = superGovernor.getAddress(superGovernor.SUPER_BANK());
        IERC20(tokenOut).safeTransfer(superbank, swapFee);

        // Transfer assets to receiver
        // For now, assuming shares are held in this contract, maybe they will have to be held in another contract
        // balance sheet
        IERC20(tokenOut).safeTransfer(receiver, amountTokenOutAfterFees);

        emit Redeem(
            receiver, tokenOut, amountSharesToRedeem, amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem
        );
    }

    /// @inheritdoc ISuperAsset
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
        )
    {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        if (tokenIn == address(0) || tokenOut == address(0)) revert ZERO_ADDRESS();

        (amountSharesIntermediateStep, swapFeeIn, amountIncentivesIn) =
            deposit(msg.sender, tokenIn, amountTokenToDeposit, 0);

        (amountTokenOutAfterFees, swapFeeOut, amountIncentivesOut) =
            redeem(receiver, amountSharesIntermediateStep, tokenOut, minTokenOut);

        emit Swap(
            receiver,
            tokenIn,
            amountTokenToDeposit,
            tokenOut,
            amountSharesIntermediateStep,
            amountTokenOutAfterFees,
            swapFeeIn,
            swapFeeOut,
            amountIncentivesIn,
            amountIncentivesOut
        );
        return (
            amountSharesIntermediateStep,
            amountTokenOutAfterFees,
            swapFeeIn,
            swapFeeOut,
            amountIncentivesIn,
            amountIncentivesOut
        );
    }

    /*//////////////////////////////////////////////////////////////
                            PREVIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperAsset
    /// @notice This function should not revert
    function previewDeposit(
        address tokenIn,
        uint256 amountTokenToDeposit,
        bool isSoft
    )
        public
        view
        returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess)
    {   
        if (amountTokenToDeposit == 0) return (0, 0, 0, false);

        PreviewDeposit memory s;
        if (!tokenData[tokenIn].isSupportedUnderlyingVault && !tokenData[tokenIn].isSupportedERC20) {
            return (0, 0, 0, false);
        }

        // Calculate swap fees (example: 0.1% fee)
        swapFee = Math.mulDiv(amountTokenToDeposit, swapFeeInPercentage, SWAP_FEE_PERC); // 0.1%
        s.amountTokenInAfterFees = amountTokenToDeposit - swapFee;

        // Get price of underlying vault shares in USD
        (s.priceUSDTokenIn,,,) = getPriceWithCircuitBreakers(tokenIn);
        (s.priceUSDSuperAssetShares) = getSuperAssetPPS();

        if (s.priceUSDTokenIn == 0 || s.priceUSDSuperAssetShares == 0) return (0, 0, 0, false);

        // Calculate SuperUSD shares to mint
        amountSharesMinted = Math.mulDiv(s.amountTokenInAfterFees, s.priceUSDTokenIn, s.priceUSDSuperAssetShares);  
        
        // Adjust for decimals
        uint8 decimalsTokenIn = IERC20Metadata(tokenIn).decimals();
        if (decimalsTokenIn != 1e18) {
            amountSharesMinted = Math.mulDiv(amountSharesMinted, 10 ** (1e18 - decimalsTokenIn), PRECISION);
        }

        // Get current and post-operation allocations
        (
            s.allocations.absoluteAllocationPreOperation,
            s.allocations.totalAllocationPreOperation,
            s.allocations.absoluteAllocationPostOperation,
            s.allocations.totalAllocationPostOperation,
            s.allocations.absoluteTargetAllocation,
            s.allocations.totalTargetAllocation,
            s.allocations.vaultWeights,
            s.allocations.isSuccess
        ) = getAllocationsPrePostOperation(tokenIn, int256(amountTokenToDeposit), isSoft);

        // TODO: Handle the case where isSuccess is false

        ISuperAssetFactory factory = ISuperAssetFactory(superGovernor.getAddress(_SUPER_ASSET_FACTORY));
        address icc = factory.getIncentiveCalculationContract(address(this));

        // Calculate incentives (using ICC)
        (amountIncentiveUSD, s.allocations.isSuccess) = IIncentiveCalculationContract(icc).calculateIncentive(
            s.allocations.absoluteAllocationPreOperation,
            s.allocations.absoluteAllocationPostOperation,
            s.allocations.absoluteTargetAllocation,
            s.allocations.vaultWeights,
            s.allocations.totalAllocationPreOperation,
            s.allocations.totalAllocationPostOperation,
            s.allocations.totalTargetAllocation,
            energyToUSDExchangeRatio
        );
        return (amountSharesMinted, swapFee, amountIncentiveUSD, s.allocations.isSuccess);
    }

    /// @inheritdoc ISuperAsset
    /// @notice This function should not revert
    function previewRedeem(
        address tokenOut,
        uint256 amountSharesToRedeem,
        bool isSoft
    )
        public
        view
        returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess)
    {
        if (amountSharesToRedeem == 0) return (0, 0, 0, false);

        PreviewRedeem memory s;

        // Get price of underlying vault shares in USD
        (s.priceUSDSuperAssetShares) = getSuperAssetPPS();
        (s.priceUSDTokenOut,,,) = getPriceWithCircuitBreakers(tokenOut);

        // Calculate underlying shares to redeem
        s.amountTokenOutBeforeFees 
        = Math.mulDiv(amountSharesToRedeem, s.priceUSDSuperAssetShares, s.priceUSDTokenOut);

        // Adjust for decimals
        uint8 decimalsTokenOut = IERC20Metadata(tokenOut).decimals();
        if (decimalsTokenOut != 1e18) {
            s.amountTokenOutBeforeFees = Math.mulDiv(s.amountTokenOutBeforeFees, 10 ** (1e18 - decimalsTokenOut), PRECISION);
        }

        swapFee = Math.mulDiv(s.amountTokenOutBeforeFees, swapFeeOutPercentage, SWAP_FEE_PERC); // 0.1%
        amountTokenOutAfterFees = s.amountTokenOutBeforeFees - swapFee;

        // Get current and post-operation allocations
        (
            s.allocations.absoluteAllocationPreOperation,
            s.allocations.totalAllocationPreOperation,
            s.allocations.absoluteAllocationPostOperation,
            s.allocations.totalAllocationPostOperation,
            s.allocations.absoluteTargetAllocation,
            s.allocations.totalTargetAllocation,
            s.allocations.vaultWeights,
            s.allocations.isSuccess
        ) = getAllocationsPrePostOperation(tokenOut, -int256(s.amountTokenOutBeforeFees), isSoft);

        ISuperAssetFactory factory = ISuperAssetFactory(superGovernor.getAddress(_SUPER_ASSET_FACTORY));
        address icc = factory.getIncentiveCalculationContract(address(this));

        // Calculate incentives (using ICC)
        (amountIncentiveUSD, s.allocations.isSuccess) = IIncentiveCalculationContract(icc).calculateIncentive(
            s.allocations.absoluteAllocationPreOperation,
            s.allocations.absoluteAllocationPostOperation,
            s.allocations.absoluteTargetAllocation,
            s.allocations.vaultWeights,
            s.allocations.totalAllocationPreOperation,
            s.allocations.totalAllocationPostOperation,
            s.allocations.totalTargetAllocation,
            energyToUSDExchangeRatio
        );
        return (amountTokenOutAfterFees, swapFee, amountIncentiveUSD, s.allocations.isSuccess);
    }

    /// @inheritdoc ISuperAsset
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
        )
    {
        uint256 amountSharesMinted;
        bool isSuccessDeposit;
        bool isSuccessRedeem;
        (amountSharesMinted, swapFeeIn, amountIncentiveUSDDeposit, isSuccessDeposit) =
            previewDeposit(tokenIn, amountTokenToDeposit, isSoft);
        (amountTokenOutAfterFees, swapFeeOut, amountIncentiveUSDRedeem, isSuccessRedeem) =
            previewRedeem(tokenOut, amountSharesMinted, isSoft); // incentives are cumulative in this simplified example.
        isSuccess = isSuccessDeposit && isSuccessRedeem;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperAsset
    function getTokenData(address token) external view returns (TokenData memory) {
        return tokenData[token];
    }

    /// @inheritdoc ISuperAsset
    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperAsset
    /// @dev This function should not revert
    function getPriceWithCircuitBreakers(address token)
        public
        view
        returns (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff)
    {
        // Get token decimals
        uint256 one = 10 ** IERC20Metadata(token).decimals();
        uint256 stddev;
        uint256 N;
        uint256 M;

        // @dev Passing oneUnit to get the price of a single unit of asset to check if it has depegged
        (priceUSD, stddev, N, M) = superOracle.getQuoteFromProvider(one, token, USD, AVERAGE_PROVIDER);

        // Circuit Breaker for Oracle Off
        if (M == 0) {
            priceUSD = emergencyPrices[token];
            isOracleOff = true;
        } else {
            // Circuit Breaker for Depeg - price deviates more than ±2% from expected
            if (priceUSD < DEPEG_LOWER_THRESHOLD || priceUSD > DEPEG_UPPER_THRESHOLD) {
                isDepeg = true;
            }
            // Calculate relative standard deviation
            uint256 relativeStdDev = Math.mulDiv(stddev, PRECISION, priceUSD);

            // Circuit Breaker for Dispersion
            if (relativeStdDev > DISPERSION_THRESHOLD) {
                isDispersion = true;
            }
        }
        return (priceUSD, isDepeg, isDispersion, isOracleOff);
    }

    /// @inheritdoc ISuperAsset
    function getSuperAssetPPS() public view returns (uint256 pps) {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) return PRECISION;

        uint256 totalValueUSD;
        uint256 len = _activeAssets.length();

        for (uint256 i = 0; i < len; i++) {
            address token = _activeAssets.at(i);
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance == 0) continue;

            uint256 priceUSD;
            if (_tokenOracles[token] == superGovernor.getAddress(superGovernor.SUPER_ORACLE())) {
                (priceUSD,,,) = getPriceWithCircuitBreakers(token);
            } else {
                uint256 pricePerShare = IYieldSourceOracle(_tokenOracles[token]).getPricePerShare(token);
                (uint256 ppsUSD,,,) = getPriceWithCircuitBreakers(token);
                priceUSD = pricePerShare * ppsUSD;
            }

            uint256 decimals = IERC20Metadata(token).decimals();
            uint256 valueUSD = Math.mulDiv(balance, priceUSD, 10 ** decimals);
            totalValueUSD += valueUSD;
        }

        // PPS = Total Value in USD / Total Supply, normalized to PRECISION
        pps = Math.mulDiv(totalValueUSD, PRECISION, totalSupply_);
    }

    /// @inheritdoc ISuperAsset
    function getAllocations()
        public
        view
        returns (
            uint256[] memory absoluteCurrentAllocation,
            uint256 totalCurrentAllocation,
            uint256[] memory absoluteTargetAllocation,
            uint256 totalTargetAllocation
        )
    {
        uint256 length = _supportedVaults.length();
        absoluteCurrentAllocation = new uint256[](length);
        absoluteTargetAllocation = new uint256[](length);
        for (uint256 i; i < length; i++) {
            address vault = _supportedVaults.at(i);
            absoluteCurrentAllocation[i] = IERC20(vault).balanceOf(address(this));
            totalCurrentAllocation += absoluteCurrentAllocation[i];
            absoluteTargetAllocation[i] = tokenData[vault].targetAllocations;
            totalTargetAllocation += absoluteTargetAllocation[i];
        }
    }

    /// @inheritdoc ISuperAsset
    function getAllocationsPrePostOperation(
        address token,
        int256 deltaToken,
        bool isSoft
    )
        public
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
        )
    {
        GetAllocationsPrePostOperations memory s;
        if (deltaToken < 0 && uint256(-deltaToken) > IERC20(token).balanceOf(address(this))) {
            // NOTE: Since we do not want this function to revert, we re-set the amount out to the max possible amount
            // out which is the balance of this token
            // NOTE: This should be OK since the user can control the min amount out they desire with the slippage
            // protection
            deltaToken = -int256(IERC20(token).balanceOf(address(this)));
        }

        // NOTE: If token is not in the whitelist, consider it like if it was and add a corresponding target allocation
        // of 0
        // NOTE: This means adding one slot to the arrays here
        s.extraSlot = (_supportedVaults.contains(token) ? 0 : 1);
        s.length = _supportedVaults.length();
        s.extendedLength = _supportedVaults.length() + s.extraSlot;
        absoluteAllocationPreOperation = new uint256[](s.length);
        absoluteAllocationPostOperation = new uint256[](s.length);
        absoluteTargetAllocation = new uint256[](s.length);
        vaultWeights = new uint256[](s.length);

        for (uint256 i; i < s.extendedLength; i++) {
            s.vault = (i < s.length) ? _supportedVaults.at(i) : token;
            (s.priceUSD, s.isDepeg, s.isDispersion, s.isOracleOff) = getPriceWithCircuitBreakers(s.vault);
            if (!isSoft && (s.isDepeg || s.isDispersion || s.isOracleOff)) {
                isSuccess = false;
                return (
                    absoluteAllocationPreOperation,
                    totalAllocationPreOperation,
                    absoluteAllocationPostOperation,
                    totalAllocationPostOperation,
                    absoluteTargetAllocation,
                    totalTargetAllocation,
                    vaultWeights,
                    isSuccess
                );
            }
            s.balance = IERC20(s.vault).balanceOf(address(this));

            // Convert balance to USD value using price
            absoluteAllocationPreOperation[i] =
                Math.mulDiv(s.balance, s.priceUSD, 10 ** IERC20Metadata(s.vault).decimals());
            totalAllocationPreOperation += absoluteAllocationPreOperation[i];
            absoluteAllocationPostOperation[i] = absoluteAllocationPreOperation[i];
            if (token == s.vault) {
                s.absDeltaToken = (deltaToken >= 0) ? uint256(deltaToken) : uint256(-deltaToken);
                s.absDeltaValue = Math.mulDiv(s.absDeltaToken, s.priceUSD, 10 ** IERC20Metadata(s.vault).decimals());
                s.deltaValue = (deltaToken >= 0) ? int256(s.absDeltaValue) : -int256(s.absDeltaValue);
                absoluteAllocationPostOperation[i] = uint256(int256(absoluteAllocationPreOperation[i]) + s.deltaValue);
            }
            totalAllocationPostOperation += absoluteAllocationPostOperation[i];
            absoluteTargetAllocation[i] = tokenData[s.vault].targetAllocations;
            totalTargetAllocation += absoluteTargetAllocation[i];
            vaultWeights[i] = tokenData[s.vault].weights;
        }
        isSuccess = true;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OVERRIDES
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ERC20
    function name() public view override returns (string memory) {
        return tokenName;
    }

    /// @inheritdoc ERC20
    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @dev Settles incentives for a user
    /// @param user The address of the user to settle incentives for
    /// @param amountIncentiveUSD The amount of incentives to settle
    function _settleIncentive(address user, int256 amountIncentiveUSD) internal {
        // Pay or take incentives based on the sign of amountIncentive
        if (amountIncentiveUSD > 0) {
            ISuperAssetFactory factory = ISuperAssetFactory(superGovernor.getAddress(_SUPER_ASSET_FACTORY));
            IIncentiveFundContract(factory.getIncentiveFundContract(address(this))).payIncentive(
                user, uint256(amountIncentiveUSD)
            );
        } else if (amountIncentiveUSD < 0) {
            ISuperAssetFactory factory = ISuperAssetFactory(superGovernor.getAddress(_SUPER_ASSET_FACTORY));
            IIncentiveFundContract(factory.getIncentiveFundContract(address(this))).takeIncentive(
                user, uint256(-amountIncentiveUSD)
            );
        }
    }
}
