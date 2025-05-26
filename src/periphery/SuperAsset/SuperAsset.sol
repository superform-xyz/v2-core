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
    address public immutable primaryAsset;

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
    constructor(address asset) ERC20("", "") {
        primaryAsset = asset;
    }

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
    function whitelistERC20(address token) external onlyManager {
        if (token == address(0)) revert ZERO_ADDRESS();
        if (tokenData[token].isSupportedERC20) revert ALREADY_WHITELISTED();
        tokenData[token].isSupportedERC20 = true;

        _tokenOracles[token] = superGovernor.getAddress(superGovernor.SUPER_ORACLE());
        _supportedVaults.add(token);
        _activeAssets.add(token);

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
        if (vault == address(0) || oracle == address(0)) revert ZERO_ADDRESS();
        if (tokenData[vault].isSupportedUnderlyingVault) revert ALREADY_WHITELISTED();

        tokenData[vault].isSupportedUnderlyingVault = true;

        _tokenOracles[vault] = oracle;
        _supportedVaults.add(vault);
        _activeAssets.add(vault);

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
    function setEmergencyPrice(address token, uint256 priceUSD) external onlyManager {
        if (token == address(0)) revert ZERO_ADDRESS();
        emergencyPrices[token] = priceUSD;
        emit EmergencyPriceSet(token, priceUSD);
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
        // First all the non state changing functions
        if (receiver == address(0)) revert ZERO_ADDRESS();
        if (amountTokenToDeposit == 0) revert ZERO_AMOUNT();
        if (!tokenData[yieldSourceShare].isSupportedUnderlyingVault && !tokenData[yieldSourceShare].isSupportedERC20) {
            revert NOT_SUPPORTED_TOKEN();
        }

        // Circuit Breakers preventing deposit
        bool payIncentive = _checkCircuitBreakers(IERC4626(yieldSourceShare).asset());

        // Calculate and settle incentives
        // @notice For deposits, we want strict checks
        bool isSuccess;
        (amountSharesMinted, swapFee, amountIncentiveUSDDeposit, isSuccess) =
            previewDeposit(yieldSourceShare, amountTokenToDeposit, false);
        if (!isSuccess) revert DEPOSIT_FAILED();

        // Slippage Check
        if (amountSharesMinted < minSharesOut) revert SLIPPAGE_PROTECTION();

        // State Changing Functions //

        // Settle Incentives
        if (payIncentive) {
            _settleIncentive(msg.sender, amountIncentiveUSDDeposit);
        }

        // Transfer the tokenIn from the sender to this contract
        IERC20(yieldSourceShare).safeTransferFrom(msg.sender, address(this), amountTokenToDeposit);

        // Transfer swap fees to SuperBank
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
        if (amountSharesToRedeem == 0) revert ZERO_AMOUNT();
        if (!tokenData[tokenOut].isSupportedUnderlyingVault && !tokenData[tokenOut].isSupportedERC20) {
            revert NOT_SUPPORTED_TOKEN();
        }

        // Calculate and settle incentives
        // @notice For redemptions, we want soft checks
        bool isSuccess;
        (amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem, isSuccess) =
            previewRedeem(tokenOut, amountSharesToRedeem, false);
        if (!isSuccess) revert REDEEM_FAILED();

        // Slippage Check
        if (amountTokenOutAfterFees < minTokenOut) revert SLIPPAGE_PROTECTION();

        // State Changing Functions //

        // Settle Incentives
        if (amountIncentiveUSDRedeem > 0) {
            _settleIncentive(msg.sender, amountIncentiveUSDRedeem);
        }

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
        if (tokenIn == address(0) || tokenOut == address(0) || receiver == address(0)) revert ZERO_ADDRESS();

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
        PreviewDeposit memory s;

        if (!tokenData[tokenIn].isSupportedUnderlyingVault && !tokenData[tokenIn].isSupportedERC20) {
            return (0, 0, 0, false);
        }

        // Calculate swap fees (example: 0.1% fee)
        swapFee = Math.mulDiv(amountTokenToDeposit, swapFeeInPercentage, SWAP_FEE_PERC); // 0.1%
        s.amountTokenInAfterFees = amountTokenToDeposit - swapFee;

        amountSharesMinted = _deriveAmountSharesMinted(tokenIn, s.amountTokenInAfterFees);

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

        if (!s.allocations.isSuccess) {
            return (0, 0, 0, false);
        }

        ISuperAssetFactory factory = ISuperAssetFactory(superGovernor.getAddress(_SUPER_ASSET_FACTORY));
        address icc = factory.getIncentiveCalculationContract(address(this));

        // Calculate incentives (via ICC)
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
        PreviewRedeem memory s;

        // Calculate underlying shares to redeem
        s.amountTokenOutBeforeFees = _deriveAmountTokenOutBeforeFees(tokenOut, amountSharesToRedeem);

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

        if (!s.allocations.isSuccess) {
            return (0, 0, 0, false);
        }

        ISuperAssetFactory factory = ISuperAssetFactory(superGovernor.getAddress(_SUPER_ASSET_FACTORY));
        address icc = factory.getIncentiveCalculationContract(address(this));

        // Calculate incentives (via ICC)
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
        uint8 decimalsToken = IERC20Metadata(token).decimals();
        uint256 one = 10 ** decimalsToken;
        uint256 stddev;
        uint256 N;
        uint256 M;

        // @dev Passing oneUnit to get the price of a single unit of asset to check if it has depegged
        try superOracle.getQuoteFromProvider(one, token, USD, AVERAGE_PROVIDER) returns (
            uint256 _priceUSD, uint256 _stddev, uint256 _n, uint256 _m
        ) {
            priceUSD = _priceUSD;
            stddev = _stddev;
            N = _n;
            M = _m;
        } catch {
            priceUSD = emergencyPrices[token];
            isOracleOff = true;
        }

        // Circuit Breaker for Oracle Off
        if (M == 0) {
            isOracleOff = true;
        } else {
            // Circuit Breaker for Depeg - price deviates more than ±2% from expected
            if (priceUSD < DEPEG_LOWER_THRESHOLD || priceUSD > DEPEG_UPPER_THRESHOLD) {
                uint256 oneUnitAsset = 10 ** IERC20Metadata(primaryAsset).decimals();
                uint256 assetPriceUSD;
                try superOracle.getQuoteFromProvider(oneUnitAsset, primaryAsset, USD, AVERAGE_PROVIDER) returns (
                    uint256 _priceUSD, uint256 _stddev, uint256 _n, uint256 _m
                ) {
                    assetPriceUSD = _priceUSD;
                } catch {
                    assetPriceUSD = emergencyPrices[primaryAsset];
                }
                uint256 ratio = Math.mulDiv(priceUSD, PRECISION, assetPriceUSD);
                if (decimalsToken != 1e18) {
                    ratio = Math.mulDiv(ratio, 10 ** (1e18 - decimalsToken), PRECISION);
                }
                if (ratio < DEPEG_LOWER_THRESHOLD || ratio > DEPEG_UPPER_THRESHOLD) {
                    isDepeg = true;
                }
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

        // @notice If token is not in the whitelist, consider it like if it was and add a corresponding target
        // allocation
        // of 0
        // @notice This means adding one slot to the arrays here
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

    /// @dev Fetches the prices of a token and the super asset shares
    /// @param token The address of the token to fetch the prices for
    /// @return priceUSDToken The price of the token in USD
    /// @return priceUSDSuperAssetShares The price of the super asset shares in USD
    function _fetchPrices(address token)
        internal
        view
        returns (uint256 priceUSDToken, uint256 priceUSDSuperAssetShares)
    {
        priceUSDSuperAssetShares = getSuperAssetPPS();
        if (_tokenOracles[token] == superGovernor.getAddress(superGovernor.SUPER_ORACLE())) {
            (priceUSDToken,,,) = getPriceWithCircuitBreakers(token);
        } else {
            uint256 pricePerShare = IYieldSourceOracle(_tokenOracles[token]).getPricePerShare(token);
            (uint256 ppsUSD,,,) = getPriceWithCircuitBreakers(token);
            priceUSDToken = pricePerShare * ppsUSD;
        }
    }

    /// @dev Derives the amount of shares minted in previewDeposit
    /// @param tokenIn The address of the token to derive the amount of shares minted for
    /// @param amountTokenInAfterFees The amount of token in after fees
    /// @return amountSharesMinted The amount of shares minted
    function _deriveAmountSharesMinted(
        address tokenIn,
        uint256 amountTokenInAfterFees
    )
        internal
        view
        returns (uint256 amountSharesMinted)
    {
        // Get price of underlying vault shares in USD
        (uint256 priceUSDTokenIn, uint256 priceUSDSuperAssetShares) = _fetchPrices(tokenIn);

        // Calculate SuperUSD shares to mint
        amountSharesMinted = Math.mulDiv(amountTokenInAfterFees, priceUSDTokenIn, priceUSDSuperAssetShares);

        // Adjust for decimals
        uint8 decimalsTokenIn = IERC20Metadata(tokenIn).decimals();
        if (decimalsTokenIn != 1e18) {
            amountSharesMinted = Math.mulDiv(amountSharesMinted, 10 ** (1e18 - decimalsTokenIn), PRECISION);
        }
    }

    /// @dev Derives the amount of token out before fees in previewRedeem
    /// @param tokenOut The address of the token to derive the amount of token out before fees for
    /// @param amountSharesToRedeem The amount of shares to redeem
    /// @return amountTokenOutBeforeFees The amount of token out before fees
    function _deriveAmountTokenOutBeforeFees(
        address tokenOut,
        uint256 amountSharesToRedeem
    )
        internal
        view
        returns (uint256 amountTokenOutBeforeFees)
    {
        // Get price of underlying vault shares in USD
        (uint256 priceUSDTokenOut, uint256 priceUSDSuperAssetShares) = _fetchPrices(tokenOut);

        amountTokenOutBeforeFees = Math.mulDiv(amountSharesToRedeem, priceUSDSuperAssetShares, priceUSDTokenOut);

        // Adjust for decimals
        uint8 decimalsTokenOut = IERC20Metadata(tokenOut).decimals();
        if (decimalsTokenOut != 1e18) {
            amountTokenOutBeforeFees = Math.mulDiv(amountTokenOutBeforeFees, 10 ** (1e18 - decimalsTokenOut), PRECISION);
        }
    }

    /// @dev Checks the circuit breakers for a token
    /// @param token The address of the token to check the circuit breakers for
    function _checkCircuitBreakers(address token) internal view returns (bool payIncentive) {
        uint256 underlyingSuperVaultAssetPriceUSD;
        bool isDispersion;
        bool isOracleOff;

        (underlyingSuperVaultAssetPriceUSD,, isDispersion, isOracleOff) = getPriceWithCircuitBreakers(token);

        // Circuit Breaker for Dispersion
        if (isDispersion) {
            if (emergencyPrices[token] != 0) {
                payIncentive = true;
            } else {
                payIncentive = false;
            }
        }

        // Circuit Breaker for Oracle Off
        if (underlyingSuperVaultAssetPriceUSD == 0) {
            if (emergencyPrices[token] != 0) {
                payIncentive = true;
            } else {
                payIncentive = false;
            }
        }
        if (isOracleOff) {
            payIncentive = false;
        }

        return payIncentive;
    }
}
