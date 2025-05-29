// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ISuperOracle } from "../interfaces/oracles/ISuperOracle.sol";
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperAsset } from "../interfaces/SuperAsset/ISuperAsset.sol";
import { ISuperAssetFactory } from "../interfaces/SuperAsset/ISuperAssetFactory.sol";
import { IYieldSourceOracle } from "../../../src/core/interfaces/accounting/IYieldSourceOracle.sol";
import { IIncentiveCalculationContract } from "../interfaces/SuperAsset/IIncentiveCalculationContract.sol";
import { IIncentiveFundContract } from "../interfaces/SuperAsset/IIncentiveFundContract.sol";

/// @title SuperAsset
/// @author Superform Labs
/// @notice A meta-vault that manages deposits and redemptions across multiple underlying vaults.
/// @dev Implements ERC20 standard for better compatibility with integrators.
contract SuperAsset is ERC20, ISuperAsset {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using Math for uint256;

    // --- Storage for ERC20 variables ---
    string private tokenName;
    string private tokenSymbol;

    // --- Interfaces ---
    ISuperGovernor public superGovernor;
    ISuperAssetFactory public factory;

    // --- Constants ---
    uint256 public constant PRECISION = 1e18;
    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SWAP_FEE_PERCENTAGE = 10 ** 4; // Max 10% (1000 basis points)
    uint256 public constant DEPEG_LOWER_THRESHOLD = 98e16; // 0.98
    uint256 public constant DEPEG_UPPER_THRESHOLD = 102e16; // 1.02
    uint256 public constant DISPERSION_THRESHOLD = 1e16; // 1% relative standard deviation threshold
    uint256 public constant SWAP_FEE_PERC = 10 ** 6;

    // --- State ---
    mapping(address token => TokenData data) public tokenData;

    // @notice Contains supported Vaults shares and standard ERC20s
    EnumerableSet.AddressSet private _supportedAssets;
    EnumerableSet.AddressSet private _activeAssets;

    uint256 public swapFeeInPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public swapFeeOutPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public energyToUSDExchangeRatio;

    // --- Addresses ---
    address public constant USD = address(840);
    address public primaryAsset;

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
        if (msg.sender != factory.getSuperAssetStrategist(address(this))) revert UNAUTHORIZED();
        _;
    }

    modifier onlyManager() {
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
        address asset,
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

        primaryAsset = asset;

        superGovernor = ISuperGovernor(superGovernor_);
        factory = ISuperAssetFactory(superGovernor.getAddress(superGovernor.SUPER_ASSET_FACTORY()));
    }

    /*//////////////////////////////////////////////////////////////
                            MANAGER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperAsset
    function whitelistERC20(address token) external onlyManager {
        if (token == address(0)) revert ZERO_ADDRESS();
        if (tokenData[token].isSupportedERC20) revert ALREADY_WHITELISTED();
        tokenData[token].isSupportedERC20 = true;

        tokenData[token].oracle = superGovernor.getAddress(superGovernor.SUPER_ORACLE());
        _supportedAssets.add(token);
        _activeAssets.add(token);

        emit ERC20Whitelisted(token);
    }

    /// @inheritdoc ISuperAsset
    function removeERC20(address token) external onlyManager {
        if (token == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[token].isSupportedERC20) revert NOT_WHITELISTED();

        tokenData[token].isSupportedERC20 = false;
        _supportedAssets.remove(token);

        if (IERC20(token).balanceOf(address(this)) == 0) {
            _activeAssets.remove(token);
            tokenData[token].oracle = address(0);
        }

        emit ERC20Removed(token);
    }

    /// @inheritdoc ISuperAsset
    function whitelistVault(address vault, address yieldSourceOracle) external onlyManager {
        if (vault == address(0) || yieldSourceOracle == address(0)) revert ZERO_ADDRESS();
        if (tokenData[vault].isSupportedUnderlyingVault) revert ALREADY_WHITELISTED();

        tokenData[vault].isSupportedUnderlyingVault = true;

        tokenData[vault].oracle = yieldSourceOracle;
        _supportedAssets.add(vault);
        _activeAssets.add(vault);

        emit VaultWhitelisted(vault);
    }

    /// @inheritdoc ISuperAsset
    function removeVault(address vault) external onlyManager {
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[vault].isSupportedUnderlyingVault) revert NOT_WHITELISTED();

        tokenData[vault].isSupportedUnderlyingVault = false;
        _supportedAssets.remove(vault);

        if (IERC20(vault).balanceOf(address(this)) == 0) {
            _activeAssets.remove(vault);
            tokenData[vault].oracle = address(0);
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
        address tokenIn,
        uint256 amountTokenToDeposit,
        uint256 minSharesOut // Slippage Protection
    )
        public
        returns (uint256 amountSharesMinted, uint256 swapFee, int256 amountIncentiveUSDDeposit)
    {
        // First all the non state changing functions
        if (receiver == address(0)) revert ZERO_ADDRESS();
        if (amountTokenToDeposit == 0) revert ZERO_AMOUNT();

        // Calculate and settle incentives
        // @notice For deposits, we want strict checks
        bool isSuccess;
        bool isTokenInDepeg;
        bool isTokenInDispersion;
        bool isTokenInOracleOff;
        (
            amountSharesMinted,
            swapFee,
            amountIncentiveUSDDeposit,
            isTokenInDepeg,
            isTokenInDispersion,
            isTokenInOracleOff,
            isSuccess
        ) = previewDeposit(tokenIn, amountTokenToDeposit, false);

        // isSuccess == false but totalSupply == 0 for the first deposit, this check allows for the first deposit
        // (in which case calculateIncentive() will fail) to pass
        if (!isSuccess && totalSupply() != 0) revert DEPOSIT_FAILED();

        // Slippage Check
        if (amountSharesMinted < minSharesOut) revert SLIPPAGE_PROTECTION();

        if (isTokenInDepeg) {
            revert UNDERLYING_SV_ASSET_PRICE_DEPEG();
        }
        if (isTokenInOracleOff) {
            revert UNDERLYING_SV_ASSET_PRICE_ORACLE_OFF();
        }
        if (isTokenInDispersion) {
            revert UNDERLYING_SV_ASSET_PRICE_DISPERSION();
        }

        // State Changing Functions //

        // Settle Incentives
        if (amountIncentiveUSDDeposit > 0) {
            _settleIncentive(msg.sender, amountIncentiveUSDDeposit);
        }

        // Transfer the tokenIn from the sender to this contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountTokenToDeposit);

        // Transfer swap fees to SuperBank
        address superbank = superGovernor.getAddress(superGovernor.SUPER_BANK());
        IERC20(tokenIn).safeTransfer(superbank, swapFee);

        // Mint SuperUSD shares
        _mint(receiver, amountSharesMinted);

        emit Deposit(receiver, tokenIn, amountTokenToDeposit, amountSharesMinted, swapFee, amountIncentiveUSDDeposit);
    }

    /// @inheritdoc ISuperAsset
    function redeem(
        address receiver,
        uint256 amountTokenOutToRedeem,
        address tokenOut,
        uint256 minTokenOut
    )
        public
        returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem)
    {
        if (receiver == address(0)) revert ZERO_ADDRESS();
        if (amountTokenOutToRedeem == 0) revert ZERO_AMOUNT();

        // Calculate and settle incentives
        // @notice For redemptions, we want hard checks
        bool isSuccess;
        (amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem, isSuccess) =
            previewRedeem(tokenOut, amountTokenOutToRedeem, false);

        if (!isSuccess) revert REDEEM_FAILED();

        // Slippage Check
        if (amountTokenOutAfterFees < minTokenOut) revert SLIPPAGE_PROTECTION();

        // State Changing Functions //

        // Settle Incentives
        if (amountIncentiveUSDRedeem > 0) {
            _settleIncentive(msg.sender, amountIncentiveUSDRedeem);
        }

        // Burn SuperUSD shares
        _burn(msg.sender, amountTokenOutToRedeem); // Use a proper burning mechanism

        // Transfer swap fees to Asset Bank
        address superbank = superGovernor.getAddress(superGovernor.SUPER_BANK());
        IERC20(tokenOut).safeTransfer(superbank, swapFee);

        // Transfer assets to receiver
        // For now, assuming shares are held in this contract, maybe they will have to be held in another contract
        // balance sheet
        IERC20(tokenOut).safeTransfer(receiver, amountTokenOutAfterFees);

        emit Redeem(
            receiver, tokenOut, amountTokenOutToRedeem, amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem
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
        if (tokenIn == address(0) || tokenOut == address(0)) revert ZERO_ADDRESS();

        (amountSharesIntermediateStep, swapFeeIn, amountIncentivesIn) =
            deposit(msg.sender, tokenIn, amountTokenToDeposit, 0); // TODO: does deposit have to return so much info?

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
        returns (
            uint256 amountSharesMinted,
            uint256 swapFee,
            int256 amountIncentiveUSDDeposit,
            bool isTokenInDepeg,
            bool isTokenInDispersion,
            bool isTokenInOracleOff,
            bool isSuccess
        )
    {
        PreviewDeposit memory s;

        // Calculate swap fees (example: 0.1% fee)
        swapFee = Math.mulDiv(amountTokenToDeposit, swapFeeInPercentage, SWAP_FEE_PERC); // 0.1%
        s.amountTokenInAfterFees = amountTokenToDeposit - swapFee;

        (amountSharesMinted, isTokenInDepeg, isTokenInDispersion, isTokenInOracleOff, isSuccess) =
            _previewAmountSharesMinted(tokenIn, s.amountTokenInAfterFees);

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
        ) = getAllocationsPrePostOperation(tokenIn, int256(amountTokenToDeposit), !isSuccess, isSoft);

        if (!s.allocations.isSuccess) {
            return (0, 0, 0, false, false, false, false);
        }

        address icc = factory.getIncentiveCalculationContract(address(this));
        address ifc = factory.getIncentiveFundContract(address(this));

        // Calculate incentives (via ICC)
        if (IIncentiveFundContract(ifc).incentivesEnabled()) {
            (amountIncentiveUSDDeposit, s.allocations.isSuccess) = IIncentiveCalculationContract(icc).calculateIncentive(
                s.allocations.absoluteAllocationPreOperation,
                s.allocations.absoluteAllocationPostOperation,
                s.allocations.absoluteTargetAllocation,
                s.allocations.vaultWeights,
                s.allocations.totalAllocationPreOperation,
                s.allocations.totalAllocationPostOperation,
                s.allocations.totalTargetAllocation,
                energyToUSDExchangeRatio
            );
            return (
                amountSharesMinted,
                swapFee,
                amountIncentiveUSDDeposit,
                isTokenInDepeg,
                isTokenInDispersion,
                isTokenInOracleOff,
                s.allocations.isSuccess
            );
        } else {
            return (amountSharesMinted, swapFee, 0, isTokenInDepeg, isTokenInDispersion, isTokenInOracleOff, true);
        }
    }

    /// @inheritdoc ISuperAsset
    /// @notice This function should not revert
    function previewRedeem(
        address tokenOut,
        uint256 amountTokenOutToRedeem,
        bool isSoft
    )
        public
        view
        returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSD, bool isSuccess)
    {
        PreviewRedeem memory s;

        // Calculate underlying shares to redeem
        (s.amountTokenOutBeforeFees, isSuccess) = _previewAmountTokenOutBeforeFees(tokenOut, amountTokenOutToRedeem);

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
        ) = getAllocationsPrePostOperation(tokenOut, -int256(s.amountTokenOutBeforeFees), !isSuccess, isSoft);

        if (!s.allocations.isSuccess) {
            return (0, 0, 0, false);
        }

        address icc = factory.getIncentiveCalculationContract(address(this));
        address ifc = factory.getIncentiveFundContract(address(this));

        // Calculate incentives (via ICC)
        if (IIncentiveFundContract(ifc).incentivesEnabled()) {
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
        } else {
            return (amountTokenOutAfterFees, swapFee, 0, true);
        }
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
        (amountSharesMinted, swapFeeIn, amountIncentiveUSDDeposit,,,, isSuccessDeposit) =
            previewDeposit(tokenIn, amountTokenToDeposit, isSoft);

        if (!isSuccessDeposit) {
            return (0, 0, 0, 0, 0, false);
        }

        (amountTokenOutAfterFees, swapFeeOut, amountIncentiveUSDRedeem, isSuccessRedeem) =
            previewRedeem(tokenOut, amountSharesMinted, isSoft);

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
        uint8 decimalsToken = IERC20Metadata(token).decimals();
        uint256 one = 10 ** decimalsToken;
        uint256 stddev;
        uint256 N;
        uint256 M;

        // @dev Passing oneUnit to get the price of a single unit of asset to check if it has depegged
        ISuperOracle superOracle = ISuperOracle(superGovernor.getAddress(superGovernor.SUPER_ORACLE()));
        try superOracle.getQuoteFromProvider(one, token, USD, AVERAGE_PROVIDER) returns (
            uint256 _priceUSD, uint256 _stddev, uint256 _n, uint256 _m
        ) {
            priceUSD = _priceUSD;
            stddev = _stddev;
            N = _n;
            M = _m;
        } catch {
            priceUSD = superOracle.getEmergencyPrice(token);
            isOracleOff = true;
        }

        // Circuit Breaker for Oracle Off
        if (M == 0) {
            isOracleOff = true;
        } else {
            if (primaryAsset == USD) {
                return (PRECISION, false, false, false);
            }

            // Circuit Breaker for Depeg - price deviates more than ±2% from expected
            uint256 assetPriceUSD;
            uint256 oneUnitAsset = 10 ** IERC20Metadata(primaryAsset).decimals();
            try superOracle.getQuoteFromProvider(oneUnitAsset, primaryAsset, USD, AVERAGE_PROVIDER) returns (
                uint256 _priceUSD, uint256, uint256, uint256
            ) {
                assetPriceUSD = _priceUSD;
            } catch {
                assetPriceUSD = superOracle.getEmergencyPrice(primaryAsset);
            }
            uint256 ratio = Math.mulDiv(priceUSD, PRECISION, assetPriceUSD);

            if (decimalsToken != DECIMALS) {
                ratio = Math.mulDiv(ratio, 10 ** (DECIMALS - decimalsToken), PRECISION);
            }
            if (ratio < DEPEG_LOWER_THRESHOLD || ratio > DEPEG_UPPER_THRESHOLD) {
                isDepeg = true;
            }

            // Calculate relative standard deviation
            isDispersion = _isSTDDevDegged(stddev, priceUSD);
        }
        return (priceUSD, isDepeg, isDispersion, isOracleOff);
    }

    /// @inheritdoc ISuperAsset
    function getSuperAssetPPS()
        public
        view
        returns (
            address[] memory activeTokens,
            uint256[] memory pricePerTokenUSD,
            bool[] memory isDepeg,
            bool[] memory isDispersion,
            bool[] memory isOracleOff,
            uint256 pps
        )
    {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) return (activeTokens, pricePerTokenUSD, isDepeg, isDispersion, isOracleOff, pps);

        uint256 totalValueUSD;
        uint256 len = _activeAssets.length();

        for (uint256 i; i < len; i++) {
            address token = _activeAssets.at(i);
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance == 0) continue;

            activeTokens[i] = token;

            (uint256 priceUSD, bool isTokenDepeg, bool isTokenDispersion, bool isTokenOracleOff) =
                getPriceWithCircuitBreakers(token);

            pricePerTokenUSD[i] = priceUSD;
            isDepeg[i] = isTokenDepeg;
            isDispersion[i] = isTokenDispersion;
            isOracleOff[i] = isTokenOracleOff;

            uint256 valueUSD = Math.mulDiv(balance, priceUSD, 10 ** IERC20Metadata(token).decimals());
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
        uint256 length = _supportedAssets.length();
        absoluteCurrentAllocation = new uint256[](length);
        absoluteTargetAllocation = new uint256[](length);
        for (uint256 i; i < length; i++) {
            address vault = _supportedAssets.at(i);
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
        bool circuitBreakerTriggered,
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

        // @notice If token is not in the whitelist, consider it like if it was and add a corresponding target
        // allocation
        // of 0
        // @notice This means adding one slot to the arrays here
        s.extraSlot = (_supportedAssets.contains(token) ? 0 : 1);
        s.length = _supportedAssets.length();
        s.extendedLength = _supportedAssets.length() + s.extraSlot;
        absoluteAllocationPreOperation = new uint256[](s.length);
        absoluteAllocationPostOperation = new uint256[](s.length);
        absoluteTargetAllocation = new uint256[](s.length);
        vaultWeights = new uint256[](s.length);

        for (uint256 i; i < s.extendedLength; i++) {
            s.vault = (i < s.length) ? _supportedAssets.at(i) : token;
            if (!isSoft && circuitBreakerTriggered) {
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
            IIncentiveFundContract(factory.getIncentiveFundContract(address(this))).payIncentive(
                user, uint256(amountIncentiveUSD)
            );
        } else if (amountIncentiveUSD < 0) {
            IIncentiveFundContract(factory.getIncentiveFundContract(address(this))).takeIncentive(
                user, uint256(-amountIncentiveUSD)
            );
        }
    }

    /// @dev Previews the amount of shares minted in previewDeposit
    /// @param tokenIn The address of the token to derive the amount of shares minted for
    /// @param amountTokenInAfterFees The amount of token in after fees
    /// @return amountSharesMinted The amount of shares minted
    /// @return isTokenInDepeg Whether the token in is depegged.
    /// @return isTokenInDispersion Whether the token in is dispersed.
    /// @return isTokenInOracleOff Whether the token in is oracle off.
    /// @return isSuccess Whether the preview was successful
    function _previewAmountSharesMinted(
        address tokenIn,
        uint256 amountTokenInAfterFees
    )
        internal
        view
        returns (
            uint256 amountSharesMinted,
            bool isTokenInDepeg,
            bool isTokenInDispersion,
            bool isTokenInOracleOff,
            bool isSuccess
        )
    {
        address[] memory activeTokens;
        uint256[] memory pricePerTokenUSD;
        bool[] memory isDepeg;
        bool[] memory isDispersion;
        bool[] memory isOracleOff;
        uint256 priceUSDSuperAssetShares;
        (activeTokens, pricePerTokenUSD, isDepeg, isDispersion, isOracleOff, priceUSDSuperAssetShares) =
            getSuperAssetPPS();

        uint256 priceUSDTokenIn;
        bool isActiveToken;
        for (uint256 i; i < activeTokens.length; i++) {
            if (activeTokens[i] == tokenIn) {
                if (isDepeg[i]) {
                    isSuccess = false;
                    isTokenInDepeg = true;
                    return (amountSharesMinted, isTokenInDepeg, isTokenInDispersion, isTokenInOracleOff, isSuccess);
                }
                if (isOracleOff[i]) {
                    isSuccess = false;
                    isTokenInOracleOff = true;
                    return (amountSharesMinted, isTokenInDepeg, isTokenInDispersion, isTokenInOracleOff, isSuccess);
                }
                if (isDispersion[i]) {
                    isSuccess = false;
                    isTokenInDispersion = true;
                    return (amountSharesMinted, isTokenInDepeg, isTokenInDispersion, isTokenInOracleOff, isSuccess);
                }
                isActiveToken = true;
                priceUSDTokenIn = pricePerTokenUSD[i];
            }
        }

        // Check that tokenIn is allowed to be deposited
        if (!isActiveToken) {
            isSuccess = false;
            return (amountSharesMinted, isTokenInDepeg, isTokenInDispersion, isTokenInOracleOff, isSuccess);
        }

        // Calculate SuperUSD shares to mint
        amountSharesMinted = Math.mulDiv(amountTokenInAfterFees, priceUSDTokenIn, priceUSDSuperAssetShares);

        // Adjust for decimals
        uint8 decimalsTokenIn = IERC20Metadata(tokenIn).decimals();
        if (decimalsTokenIn != DECIMALS) {
            amountSharesMinted = Math.mulDiv(amountSharesMinted, 10 ** (DECIMALS - decimalsTokenIn), PRECISION);
        }

        isSuccess = true;
    }

    /// @dev Previews the amount of token out before fees in previewRedeem
    /// @param tokenOut The address of the token to preview the amount of token out before fees for
    /// @param amountTokenOutToRedeem The amount of shares to redeem
    /// @return amountTokenOutBeforeFees The amount of token out before fees
    /// @return isSuccess Whether the preview was successful
    function _previewAmountTokenOutBeforeFees(
        address tokenOut,
        uint256 amountTokenOutToRedeem
    )
        internal
        view
        returns (uint256 amountTokenOutBeforeFees, bool isSuccess)
    {
        (
            address[] memory activeTokens,
            uint256[] memory pricePerTokenUSD,
            bool[] memory isDepeg,
            bool[] memory isDispersion,
            bool[] memory isOracleOff,
            uint256 priceUSDSuperAssetShares
        ) = getSuperAssetPPS();

        uint256 priceUSDTokenOut;
        bool isActiveToken;
        for (uint256 i; i < activeTokens.length; i++) {
            if (activeTokens[i] == tokenOut) {
                if (isDepeg[i]) {
                    isSuccess = false;
                    return (amountTokenOutBeforeFees, isSuccess);
                }
                if (isOracleOff[i]) {
                    isSuccess = false;
                    return (amountTokenOutBeforeFees, isSuccess);
                }
                if (isDispersion[i]) {
                    isSuccess = false;
                    return (amountTokenOutBeforeFees, isSuccess);
                }
                isActiveToken = true;
                priceUSDTokenOut = pricePerTokenUSD[i];
            }
        }

        // Check that tokenOut is allowed to be redeemed
        if (!isActiveToken) {
            isSuccess = false;
            return (amountTokenOutBeforeFees, isSuccess);
        }

        amountTokenOutBeforeFees = Math.mulDiv(amountTokenOutToRedeem, priceUSDSuperAssetShares, priceUSDTokenOut);

        // Adjust for decimals
        uint8 decimalsTokenOut = IERC20Metadata(tokenOut).decimals();
        if (decimalsTokenOut != DECIMALS) {
            amountTokenOutBeforeFees =
                Math.mulDiv(amountTokenOutBeforeFees, 10 ** (DECIMALS - decimalsTokenOut), PRECISION);
        }

        isSuccess = true;
    }

    /// @dev Checks if the standard deviation is greater than the dispersion threshold
    /// @param stddev The standard deviation
    /// @param priceUSD The price in USD
    /// @return isDispersion True if the standard deviation is greater than the dispersion threshold
    function _isSTDDevDegged(uint256 stddev, uint256 priceUSD) internal pure returns (bool) {
        // Calculate relative standard deviation
        uint256 relativeStdDev = Math.mulDiv(stddev, PRECISION, priceUSD);

        // Circuit Breaker for Dispersion
        if (relativeStdDev > DISPERSION_THRESHOLD) {
            return true;
        }
        return false;
    }
}
