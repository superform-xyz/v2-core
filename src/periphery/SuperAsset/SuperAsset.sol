// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { console } from "forge-std/console.sol";
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
        if (receiver == address(0) || tokenIn == address(0)) revert ZERO_ADDRESS();
        if (amountTokenToDeposit == 0) revert ZERO_AMOUNT();
        if (!tokenData[tokenIn].isSupportedUnderlyingVault && !tokenData[tokenIn].isSupportedERC20) {
            revert NOT_SUPPORTED_TOKEN();
        }

        // Calculate and settle incentives
        // @notice For deposits, we want strict checks
        address assetWithBreakerTriggered;
        uint256 oraclePriceUSD;
        bool isDepeg;
        bool isDispersion;
        bool isOracleOff;
        bool tokenInFound;
        bool incentiveCalculationSuccess;

        (
            amountSharesMinted,
            swapFee,
            amountIncentiveUSDDeposit,
            assetWithBreakerTriggered,
            oraclePriceUSD,
            isDepeg,
            isDispersion,
            isOracleOff,
            tokenInFound,
            incentiveCalculationSuccess
        ) = previewDeposit(tokenIn, amountTokenToDeposit, false);

        // incentiveCalculationSuccess == false but totalSupply == 0 for the first deposit, this check allows for the
        // first deposit
        // (in which case calculateIncentive() will fail) to pass
        if (!incentiveCalculationSuccess && totalSupply() != 0) revert INCENTIVE_CALCULATION_FAILED();

        // Slippage Check
        if (amountSharesMinted < minSharesOut) revert SLIPPAGE_PROTECTION();

        if (assetWithBreakerTriggered != address(0)) {
            // Circuit Breaker Checks
            if (isDepeg) {
                revert SUPPORTED_ASSET_PRICE_DEPEG(assetWithBreakerTriggered);
            }
            if (isOracleOff) {
                revert SUPPORTED_ASSET_PRICE_ORACLE_OFF(assetWithBreakerTriggered);
            }
            if (isDispersion) {
                revert SUPPORTED_ASSET_PRICE_DISPERSION(assetWithBreakerTriggered);
            }
            if (oraclePriceUSD == 0) {
                revert SUPPORTED_ASSET_PRICE_ZERO(assetWithBreakerTriggered);
            }
        }

        if (!tokenInFound) {
            revert NOT_SUPPORTED_TOKEN();
        }

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
    /// @param receiver_ The address to receive the output assets.
    /// @param amountSharesToRedeem_ The amount of SuperUSD shares to redeem.
    /// @param tokenOut_ The address of the underlying asset to redeem for.
    /// @param minTokenOut_ The minimum amount of the output asset to receive (slippage protection).
    /// @return amountTokenOutAfterFees The amount of the output asset received after fees.
    /// @return swapFee The amount of swap fee paid.
    /// @return amountIncentiveUSDRedeem The amount of incentives paid in USD.
    function redeem(
        address receiver_,
        uint256 amountSharesToRedeem_,
        address tokenOut_,
        uint256 minTokenOut_
    )
        public
        returns (uint256 amountTokenOutAfterFees, uint256 swapFee, int256 amountIncentiveUSDRedeem)
    {
        // --- Initial checks ---
        if (receiver_ == address(0)) revert ZERO_ADDRESS();
        if (amountSharesToRedeem_ == 0) revert ZERO_AMOUNT();
        if (!tokenData[tokenOut_].isSupportedUnderlyingVault && !tokenData[tokenOut_].isSupportedERC20) {
            revert NOT_SUPPORTED_TOKEN();
        }

        // --- Preview redeem operation ---
        address assetWithBreakerTriggered;
        uint256 oraclePriceUSD;
        bool tokenOutFound; // Renamed from first tokenInFound for clarity
        bool isDepeg;
        bool isDispersion;
        bool isOracleOff;
        bool redundantTokenInFound; // Second tokenInFound, currently unused
        bool incentiveCalculationSuccess;

        (
            amountTokenOutAfterFees,
            swapFee,
            amountIncentiveUSDRedeem,
            assetWithBreakerTriggered,
            oraclePriceUSD,
            tokenOutFound, // Mapped from first tokenInFound
            isDepeg,
            isDispersion,
            isOracleOff,
            redundantTokenInFound, // Mapped from second tokenInFound
            incentiveCalculationSuccess
        ) = previewRedeem(tokenOut_, amountSharesToRedeem_, false); // isSoft = false for hard checks

        // --- Post-preview checks (mimicking deposit) ---
        // incentiveCalculationSuccess == false but totalSupply == 0 for the first deposit, this check allows for the
        // first deposit
        // (in which case calculateIncentive() will fail) to pass. Similar logic applies to redeem.
        if (!incentiveCalculationSuccess && totalSupply() != 0) revert INCENTIVE_CALCULATION_FAILED();

        // Slippage Check
        if (amountTokenOutAfterFees < minTokenOut_) revert SLIPPAGE_PROTECTION();

        // Circuit Breaker Checks
        if (assetWithBreakerTriggered != address(0)) {
            if (isDepeg) {
                revert SUPPORTED_ASSET_PRICE_DEPEG(assetWithBreakerTriggered);
            }
            if (isOracleOff) {
                revert SUPPORTED_ASSET_PRICE_ORACLE_OFF(assetWithBreakerTriggered);
            }
            if (isDispersion) {
                revert SUPPORTED_ASSET_PRICE_DISPERSION(assetWithBreakerTriggered);
            }
            if (oraclePriceUSD == 0) {
                revert SUPPORTED_ASSET_PRICE_ZERO(assetWithBreakerTriggered);
            }
        }

        if (!tokenOutFound) {
            revert NOT_SUPPORTED_TOKEN(); // Or a more specific error if tokenOut_ was expected to be found by preview
        }

        // --- State Changing Operations ---

        // Settle Incentives
        if (amountIncentiveUSDRedeem > 0) {
            // Assuming _settleIncentive expects uint256 for the amount, and positive int256 can be cast.
            _settleIncentive(msg.sender, uint256(amountIncentiveUSDRedeem));
        }

        // Burn SuperUSD shares from the sender
        _burn(msg.sender, amountSharesToRedeem_);

        // Transfer swap fees to SuperBank
        address superbank = superGovernor.getAddress(superGovernor.SUPER_BANK());
        IERC20(tokenOut_).safeTransfer(superbank, swapFee);

        // Transfer assets to receiver
        IERC20(tokenOut_).safeTransfer(receiver_, actualAmountTokenOutAfterFees);

        // --- Emit event and set return values ---
        emit Redeem(
            receiver_, tokenOut_, amountSharesToRedeem_, amountTokenOutAfterFees, swapFee, amountIncentiveUSDRedeem
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
        if (receiver == address(0) || tokenIn == address(0) || tokenOut == address(0)) revert ZERO_ADDRESS();

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
        returns (
            uint256 amountSharesMinted,
            uint256 swapFee,
            int256 amountIncentiveUSDDeposit,
            address assetWithBreakerTriggered,
            uint256 oraclePriceUSD,
            bool tokenInFound,
            bool isDepeg,
            bool isDispersion,
            bool isOracleOff,
            bool tokenInFound,
            bool incentiveCalculationSuccess
        )
    {
        PreviewDeposit memory s;

        // Calculate swap fees
        swapFee = Math.mulDiv(amountTokenToDeposit, swapFeeInPercentage, SWAP_FEE_PERC);
        s.amountTokenInAfterFees = amountTokenToDeposit - swapFee;

        // todo why is there a difference between delta and token in?
        // Get current and post-operation allocations
        (
            s.allocations.absoluteAllocationPreOperation,
            s.allocations.totalAllocationPreOperation,
            s.allocations.absoluteAllocationPostOperation,
            s.allocations.totalAllocationPostOperation,
            s.allocations.absoluteTargetAllocation,
            s.allocations.totalTargetAllocation,
            s.allocations.vaultWeights,
            amountSharesMinted,
            assetWithBreakerTriggered,
            oraclePriceUSD,
            isDepeg,
            isDispersion,
            isOracleOff,
            tokenInFound
        ) = getAllocationsPrePostOperationDeposit(
            tokenIn, int256(amountTokenToDeposit), s.amountTokenInAfterFees, isSoft
        );

        if ((isDepeg || isDispersion || isOracleOff || oraclePriceUSD == 0)) {
            return (
                0,
                0,
                0,
                assetWithBreakerTriggered,
                oraclePriceUSD,
                isDepeg,
                isDispersion,
                isOracleOff,
                tokenInFound,
                false
            );
        }

        address ifc = factory.getIncentiveFundContract(address(this));

        // Calculate incentives (via ICC)
        if (IIncentiveFundContract(ifc).incentivesEnabled()) {
            address icc = factory.getIncentiveCalculationContract(address(this));

            (amountIncentiveUSDDeposit, incentiveCalculationSuccess) = IIncentiveCalculationContract(icc)
                .calculateIncentive(
                s.allocations.absoluteAllocationPreOperation,
                s.allocations.absoluteAllocationPostOperation,
                s.allocations.absoluteTargetAllocation,
                s.allocations.vaultWeights,
                s.allocations.totalAllocationPreOperation,
                s.allocations.totalAllocationPostOperation,
                s.allocations.totalTargetAllocation,
                energyToUSDExchangeRatio
            );
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
        returns (
            uint256 amountTokenOutAfterFees,
            uint256 swapFee,
            int256 amountIncentiveUSD,
            address assetWithBreakerTriggered,
            uint256 oraclePriceUSD,
            bool tokenInFound,
            bool isDepeg,
            bool isDispersion,
            bool isOracleOff,
            bool tokenInFound,
            bool incentiveCalculationSuccess
        )
    {
        PreviewRedeem memory s;

        // Get current and post-operation allocations
        (
            s.allocations.absoluteAllocationPreOperation,
            s.allocations.totalAllocationPreOperation,
            s.allocations.absoluteAllocationPostOperation,
            s.allocations.totalAllocationPostOperation,
            s.allocations.absoluteTargetAllocation,
            s.allocations.totalTargetAllocation,
            s.allocations.vaultWeights,
            s.amountTokenOutBeforeFees,
            assetWithBreakerTriggered,
            oraclePriceUSD,
            isDepeg,
            isDispersion,
            isOracleOff,
            tokenInFound
        ) = getAllocationsPrePostOperationRedeem(tokenOut, amountTokenOutToRedeem, isSoft);

        if ((isDepeg || isDispersion || isOracleOff || oraclePriceUSD == 0)) {
            return (
                0,
                0,
                0,
                assetWithBreakerTriggered,
                oraclePriceUSD,
                isDepeg,
                isDispersion,
                isOracleOff,
                tokenInFound,
                false
            );
        }

        // Calculate swap fee
        swapFee = Math.mulDiv(s.amountTokenOutBeforeFees, swapFeeOutPercentage, SWAP_FEE_PERC); // 0.1%
        amountTokenOutAfterFees = s.amountTokenOutBeforeFees - swapFee;

        address ifc = factory.getIncentiveFundContract(address(this));

        // Calculate incentives (via ICC)
        if (IIncentiveFundContract(ifc).incentivesEnabled()) {
            address icc = factory.getIncentiveCalculationContract(address(this));

            (amountIncentiveUSD, incentiveCalculationSuccess) = IIncentiveCalculationContract(icc).calculateIncentive(
                s.allocations.absoluteAllocationPreOperation,
                s.allocations.absoluteAllocationPostOperation,
                s.allocations.absoluteTargetAllocation,
                s.allocations.vaultWeights,
                s.allocations.totalAllocationPreOperation,
                s.allocations.totalAllocationPostOperation,
                s.allocations.totalTargetAllocation,
                energyToUSDExchangeRatio
            );
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
        uint256 M;

        // @dev Passing oneUnit to get the price of a single unit of asset to check if it has depegged
        address superOracleAddress = superGovernor.getAddress(superGovernor.SUPER_ORACLE());
        ISuperOracle superOracle = ISuperOracle(superOracleAddress);
        if (tokenData[token].isSupportedERC20) {
            try superOracle.getQuoteFromProvider(one, token, USD, AVERAGE_PROVIDER) returns (
                uint256 _priceUSD, uint256 _stddev, uint256, uint256 _m
            ) {
                priceUSD = _priceUSD;
                stddev = _stddev;
                M = _m;
            } catch {
                priceUSD = superOracle.getEmergencyPrice(token);
                M = 0;
            }
        } else if (tokenData[token].isSupportedUnderlyingVault) {
            (priceUSD, stddev, M) = _derivePriceFromUnderlyingVault(token);
            console.log("----vaultPriceUSD", priceUSD);
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
            console.log("----assetPriceUSD", assetPriceUSD);
            isDepeg = _isTokenDepeg(token, priceUSD, assetPriceUSD);

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
        uint256 len = _activeAssets.length();
        activeTokens = new address[](len);
        pricePerTokenUSD = new uint256[](len);
        isDepeg = new bool[](len);
        isDispersion = new bool[](len);
        isOracleOff = new bool[](len);

        uint256 totalValueUSD;
        for (uint256 i; i < len; i++) {
            address token = _activeAssets.at(i);
            activeTokens[i] = token;

            (uint256 priceUSD, bool isTokenDepeg, bool isTokenDispersion, bool isTokenOracleOff) =
                getPriceWithCircuitBreakers(token);
            console.log("----priceUSD", priceUSD);

            pricePerTokenUSD[i] = priceUSD;
            isDepeg[i] = isTokenDepeg;
            isDispersion[i] = isTokenDispersion;
            isOracleOff[i] = isTokenOracleOff;

            uint256 balance = IERC20(token).balanceOf(address(this));

            if (balance > 0) {
                totalValueUSD += Math.mulDiv(balance, priceUSD, 10 ** IERC20Metadata(token).decimals());
            }
        }

        uint256 totalSupply_ = totalSupply();
        console.log("----totalSupply_", totalSupply_);
        // PPS = Total Value in USD / Total Supply, normalized to PRECISION
        if (totalSupply_ == 0) {
            pps = PRECISION;
        } else {
            pps = Math.mulDiv(totalValueUSD, PRECISION, totalSupply_);
            console.log("----totalValueUSD", totalValueUSD);
            console.log("----pps", pps);
        }
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
    function getAllocationsPrePostOperationDeposit(
        address token,
        int256 deltaToken,
        uint256 amountToken,
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
            uint256 amountShares,
            address assetWithBreakerTriggered,
            uint256 oraclePriceUSD,
            bool isDepeg,
            bool isDispersion,
            bool isOracleOff,
            bool tokenInFound
        )
    {
        GetAllocationsPrePostOperations memory s;

        s.extendedLength = _supportedAssets.length();
        absoluteAllocationPreOperation = new uint256[](s.extendedLength);
        absoluteAllocationPostOperation = new uint256[](s.extendedLength);
        absoluteTargetAllocation = new uint256[](s.extendedLength);
        vaultWeights = new uint256[](s.extendedLength);
        uint256 totalValueUSD;
        uint256 priceUSDToken;

        for (uint256 i; i < s.extendedLength; i++) {
            s.tokent = _supportedAssets.at(i);
            (oraclePriceUSD, isDepeg, isDispersion, isOracleOff) = getPriceWithCircuitBreakers(s.token);

            if (!isSoft && (isDepeg || isDispersion || isOracleOff || oraclePriceUSD == 0)) {
                return (
                    absoluteAllocationPreOperation,
                    totalAllocationPreOperation,
                    absoluteAllocationPostOperation,
                    totalAllocationPostOperation,
                    absoluteTargetAllocation,
                    totalTargetAllocation,
                    vaultWeights,
                    amountSharesMinted,
                    supportedAsset,
                    oraclePriceUSD,
                    isDepeg,
                    isDispersion,
                    isOracleOff,
                    tokenInFound
                );
            }

            s.balance = IERC20(s.token).balanceOf(address(this));
            uint256 decimals = IERC20Metadata(s.token).decimals();
            if (s.balance > 0) {
                totalValueUSD += Math.mulDiv(s.balance, oraclePriceUSD, 10 ** decimals);
            }
            // Convert balance to USD value using price
            absoluteAllocationPreOperation[i] = Math.mulDiv(s.balance, oraclePriceUSD, 10 ** decimals);
            totalAllocationPreOperation += absoluteAllocationPreOperation[i];
            absoluteAllocationPostOperation[i] = absoluteAllocationPreOperation[i];
            if (s.token == tokenIn) {
                priceUSDToken = oraclePriceUSD;
                tokenInFound = true;
                s.absDeltaToken = uint256(deltaToken);
                s.absDeltaValue = Math.mulDiv(s.absDeltaToken, oraclePriceUSD, 10 ** decimal);
                s.deltaValue = int256(s.absDeltaValue);
                absoluteAllocationPostOperation[i] = uint256(int256(absoluteAllocationPreOperation[i]) + s.deltaValue);
            }
            totalAllocationPostOperation += absoluteAllocationPostOperation[i];
            absoluteTargetAllocation[i] = tokenData[s.token].targetAllocations;
            totalTargetAllocation += absoluteTargetAllocation[i];
            vaultWeights[i] = tokenData[s.token].weights;
        }

        uint256 superAssetPPS;
        uint256 totalSupply_ = totalSupply();
        console.log("----totalSupply_", totalSupply_);
        // PPS = Total Value in USD / Total Supply, normalized to PRECISION
        if (totalSupply_ == 0) {
            superAssetPPS = PRECISION;
        } else {
            superAssetPPS = Math.mulDiv(totalValueUSD, PRECISION, totalSupply_);
            console.log("----totalValueUSD", totalValueUSD);
            console.log("----superAssetPPS", superAssetPPS);
        }

        amountShares = Math.mulDiv(amountToken, priceUSDToken, superAssetPPS);

        uint8 decimalsToken = IERC20Metadata(token).decimals();

        // Adjust for decimals
        if (decimalsToken < DECIMALS) {
            amountShares = Math.mulDiv(amountShares, 10 ** (DECIMALS - decimalsToken), PRECISION);
        } else if (decimalsToken > DECIMALS) {
            amountShares = Math.mulDiv(amountShares, 10 ** (decimalsToken - DECIMALS), PRECISION);
        }
    }

    /// @inheritdoc ISuperAsset
    function getAllocationsPrePostOperationRedeem(
        address token,
        uint256 amountToken,
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
            uint256 amountAssets,
            address assetWithBreakerTriggered,
            uint256 oraclePriceUSD,
            bool isDepeg,
            bool isDispersion,
            bool isOracleOff,
            bool tokenInFound
        )
    {
        // 1. if deposit, deltaToken is amountTokenToDeposit (that the user sent)
        // 2. however, if redeem, all prices are fetched first (priceUSD of token out and superAsset PPS)
        // 2.1 then, these prices are used to calculate amountTokenOutBeforeFees, which is the delta token
        GetAllocationsPrePostOperations memory s;

        s.extendedLength = _supportedAssets.length();
        uint256[] memory oraclePriceUSDs = new uint256[](s.extendedLength);
        uint256[] memory balances = new uint256[](s.extendedLength);
        uint256[] memory decimals = new uint256[](s.extendedLength);
        bool[] memory isDepegs = new bool[](s.extendedLength);
        bool[] memory isDispersions = new bool[](s.extendedLength);
        bool[] memory isOracleOffs = new bool[](s.extendedLength);
        uint256 totalValueUSD;
        uint256 priceUSDToken;

        for (uint256 i; i < s.extendedLength; i++) {
            s.tokent = _supportedAssets.at(i);
            (oraclePriceUSDs[i], isDepegs[i], isDispersions[i], isOracleOffs[i]) = getPriceWithCircuitBreakers(s.token);

            if (!isSoft && (isDepegs[i] || isDispersions[i] || isOracleOffs[i] || oraclePriceUSDs[i] == 0)) {
                return (
                    absoluteAllocationPreOperation,
                    totalAllocationPreOperation,
                    absoluteAllocationPostOperation,
                    totalAllocationPostOperation,
                    absoluteTargetAllocation,
                    totalTargetAllocation,
                    vaultWeights,
                    amountSharesMinted,
                    supportedAsset,
                    oraclePriceUSDs[i],
                    isDepegs[i],
                    isDispersions[i],
                    isOracleOffs[i],
                    tokenInFound
                );
            }

            balances[i] = IERC20(s.token).balanceOf(address(this));
            decimals[i] = IERC20Metadata(s.token).decimals();
            if (balances[i] > 0) {
                totalValueUSD += Math.mulDiv(balances[i], oraclePriceUSDs[i], 10 ** decimals[i]);
            }
            if (s.token == tokenIn) {
                priceUSDToken = oraclePriceUSD;
                tokenInFound = true;
            }
        }

        absoluteAllocationPreOperation = new uint256[](s.extendedLength);
        absoluteAllocationPostOperation = new uint256[](s.extendedLength);
        absoluteTargetAllocation = new uint256[](s.extendedLength);
        vaultWeights = new uint256[](s.extendedLength);

        uint256 superAssetPPS;
        uint256 totalSupply_ = totalSupply();
        console.log("----totalSupply_", totalSupply_);
        // PPS = Total Value in USD / Total Supply, normalized to PRECISION
        if (totalSupply_ == 0) {
            superAssetPPS = PRECISION;
        } else {
            superAssetPPS = Math.mulDiv(totalValueUSD, PRECISION, totalSupply_);
            console.log("----totalValueUSD", totalValueUSD);
            console.log("----superAssetPPS", superAssetPPS);
        }

        int256 deltaToken = Math.mulDiv(amountToken, superAssetPPS, priceUSDToken);

        uint8 decimalsToken = IERC20Metadata(token).decimals();

        // Adjust for decimals
        if (decimalsToken < DECIMALS) {
            deltaToken = Math.mulDiv(deltaToken, 10 ** (DECIMALS - decimalsToken), PRECISION);
        } else if (decimalsToken > DECIMALS) {
            deltaToken = Math.mulDiv(deltaToken, 10 ** (decimalsToken - DECIMALS), PRECISION);
        }

        if (uint256(-deltaToken) > IERC20(token).balanceOf(address(this))) {
            // NOTE: Since we do not want this function to revert, we re-set the amount out to the max possible amount
            // out which is the balance of this token
            // NOTE: This should be OK since the user can control the min amount out they desire with the slippage
            // protection
            deltaToken = -int256(IERC20(token).balanceOf(address(this)));
        }

        for (uint256 i; i < s.extendedLength; i++) {
            s.token = _supportedAssets.at(i);
            // Convert balance to USD value using price
            absoluteAllocationPreOperation[i] = Math.mulDiv(balances[i], oraclePriceUSDs[i], 10 ** decimals[i]);
            totalAllocationPreOperation += absoluteAllocationPreOperation[i];
            absoluteAllocationPostOperation[i] = absoluteAllocationPreOperation[i];
            if (s.token == tokenIn) {
                priceUSDToken = oraclePriceUSDs[i];
                tokenInFound = true;
                s.absDeltaToken = uint256(-deltaToken);
                s.absDeltaValue = Math.mulDiv(s.absDeltaToken, oraclePriceUSDs[i], 10 ** decimals[i]);
                s.deltaValue = -int256(s.absDeltaValue);
                absoluteAllocationPostOperation[i] = uint256(int256(absoluteAllocationPreOperation[i]) + s.deltaValue);
            }
            totalAllocationPostOperation += absoluteAllocationPostOperation[i];
            absoluteTargetAllocation[i] = tokenData[s.token].targetAllocations;
            totalTargetAllocation += absoluteTargetAllocation[i];
            vaultWeights[i] = tokenData[s.token].weights;
        }
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

    /// @dev Gets the price of the token in and the price of the super asset shares
    /// @param tokenIn The address of the token to get the price of
    /// @return priceUSDTokenIn The price of the token in
    /// @return priceUSDSuperAssetShares The price of the super asset shares
    /// @return isTokenInDepeg Whether the token in is depegged
    /// @return isTokenInDispersion Whether the token in is dispersed
    /// @return isTokenInOracleOff Whether the token in is oracle off
    function _getTokenInPriceWithCircuitBreakers(address tokenIn)
        internal
        view
        returns (
            uint256 priceUSDTokenIn,
            uint256 priceUSDSuperAssetShares,
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

        (activeTokens, pricePerTokenUSD, isDepeg, isDispersion, isOracleOff, priceUSDSuperAssetShares) =
            getSuperAssetPPS();

        for (uint256 i; i < activeTokens.length; i++) {
            if (activeTokens[i] == tokenIn) {
                priceUSDTokenIn = pricePerTokenUSD[i];
                if (tokenData[tokenIn].isSupportedUnderlyingVault) {
                    // NOTE TODO WARNING checks the price of a share directly - this doesn't seem supported?
                    isSuccess = _checkUnderlyingVaultStatus(tokenIn);
                    if (!isSuccess) {
                        return (
                            priceUSDTokenIn,
                            priceUSDSuperAssetShares,
                            isTokenInDepeg,
                            isTokenInDispersion,
                            isTokenInOracleOff,
                            isSuccess
                        );
                    }
                } else if (tokenData[tokenIn].isSupportedERC20) {
                    if (isDepeg[i]) {
                        isTokenInDepeg = true;
                        isSuccess = false;
                        return (
                            priceUSDTokenIn,
                            priceUSDSuperAssetShares,
                            isTokenInDepeg,
                            isTokenInDispersion,
                            isTokenInOracleOff,
                            isSuccess
                        );
                    }
                }
                if (isOracleOff[i]) {
                    isSuccess = false;
                    isTokenInOracleOff = true;
                    return (
                        priceUSDTokenIn,
                        priceUSDSuperAssetShares,
                        isTokenInDepeg,
                        isTokenInDispersion,
                        isTokenInOracleOff,
                        isSuccess
                    );
                }
                if (isDispersion[i]) {
                    isSuccess = false;
                    isTokenInDispersion = true;
                    return (
                        priceUSDTokenIn,
                        priceUSDSuperAssetShares,
                        isTokenInDepeg,
                        isTokenInDispersion,
                        isTokenInOracleOff,
                        isSuccess
                    );
                }
            } else {
                // Not supported active token
                isSuccess = false;
                return (
                    priceUSDTokenIn,
                    priceUSDSuperAssetShares,
                    isTokenInDepeg,
                    isTokenInDispersion,
                    isTokenInOracleOff,
                    isSuccess
                );
            }
        }
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
        (uint256 priceTokenOutUSD, uint256 priceUSDSuperAssetShares, bool success) =
            _getTokenOutPriceWithCircuitBreakers(tokenOut);
        console.log("----priceUSDSuperAssetShares", priceUSDSuperAssetShares);

        isSuccess = success;

        amountTokenOutBeforeFees = Math.mulDiv(amountTokenOutToRedeem, priceUSDSuperAssetShares, priceTokenOutUSD);

        // Adjust for decimals
        uint8 decimalsTokenOut = IERC20Metadata(tokenOut).decimals();
        if (decimalsTokenOut != DECIMALS) {
            amountTokenOutBeforeFees =
                Math.mulDiv(amountTokenOutBeforeFees, 10 ** (DECIMALS - decimalsTokenOut), PRECISION);
        }
    }

    /// @dev Gets the price of the token out and the price of the super asset shares
    /// @param tokenOut The address of the token to get the price of
    /// @return priceUSDTokenOut The price of the token out
    /// @return priceUSDSuperAssetShares The price of the super asset shares
    /// @return isSuccess Whether the price was successfully retrieved
    function _getTokenOutPriceWithCircuitBreakers(address tokenOut)
        internal
        view
        returns (uint256 priceUSDTokenOut, uint256 priceUSDSuperAssetShares, bool isSuccess)
    {
        address[] memory activeTokens;
        uint256[] memory pricePerTokenUSD;
        bool[] memory isDepeg;
        bool[] memory isDispersion;
        bool[] memory isOracleOff;

        (activeTokens, pricePerTokenUSD, isDepeg, isDispersion, isOracleOff, priceUSDSuperAssetShares) =
            getSuperAssetPPS();
        console.log("----priceUSDSuperAssetShares", priceUSDSuperAssetShares);

        for (uint256 i; i < activeTokens.length; i++) {
            if (activeTokens[i] == tokenOut) {
                priceUSDTokenOut = pricePerTokenUSD[i];
                if (tokenData[tokenOut].isSupportedUnderlyingVault) {
                    isSuccess = _checkUnderlyingVaultStatus(tokenOut);
                    console.log("----isSuccessVaultStatus", isSuccess);
                    if (!isSuccess) {
                        return (priceUSDTokenOut, priceUSDSuperAssetShares, isSuccess);
                    }
                } else if (tokenData[tokenOut].isSupportedERC20) {
                    if (isDepeg[i]) {
                        isSuccess = false;
                        return (priceUSDTokenOut, priceUSDSuperAssetShares, isSuccess);
                    }
                }
                if (isOracleOff[i]) {
                    isSuccess = false;
                    return (priceUSDTokenOut, priceUSDSuperAssetShares, isSuccess);
                }
                if (isDispersion[i]) {
                    isSuccess = false;
                    return (priceUSDTokenOut, priceUSDSuperAssetShares, isSuccess);
                }
            }
        }
    }

    /// @dev Derives the price of the token from the underlying vault
    /// @param token The address of the token to derive the price of
    /// @return priceUSD The price of the token in USD
    /// @return stddev The standard deviation of the token
    /// @return M The number of quote providers
    function _derivePriceFromUnderlyingVault(address token)
        internal
        view
        returns (uint256 priceUSD, uint256 stddev, uint256 M)
    {
        address vaultAsset = IERC4626(token).asset();
        address tokenOracle = tokenData[token].oracle;
        uint256 unitVaultAsset = 10 ** IERC20Metadata(vaultAsset).decimals();

        ISuperOracle superOracle = ISuperOracle(superGovernor.getAddress(superGovernor.SUPER_ORACLE()));
        try superOracle.getQuoteFromProvider(unitVaultAsset, vaultAsset, USD, AVERAGE_PROVIDER) returns (
            uint256 _priceUSD, uint256 _stddev, uint256, uint256 _m
        ) {
            priceUSD = _priceUSD;
            stddev = _stddev;
            M = _m;
            console.log("----try");
            console.log("----_m", _m);
        } catch {
            priceUSD = superOracle.getEmergencyPrice(vaultAsset);
            stddev = 0;
            M = 0;
            console.log("----catch");
        }

        uint256 pricePerShare = IYieldSourceOracle(tokenOracle).getPricePerShare(token);
        console.log("----pricePerShare", pricePerShare);
        if (priceUSD > 0) {
            // TODO DECIMALS PROBLEM?
            console.log("----priceUSD", priceUSD);
            priceUSD = pricePerShare * priceUSD;
            console.log("----priceUSD*pricePerShare", priceUSD);
        }
    }

    /// @dev Checks if the vault is depegged, dispersed, or oracle off
    /// @param vaultAsset The address of the vault asset to check the status of
    /// @return isSuccess Whether the vault is depegged, dispersed, or oracle off
    function _checkUnderlyingVaultStatus(address vaultAsset) internal view returns (bool isSuccess) {
        (, bool isTokenDepeg, bool isTokenDispersion, bool isTokenOracleOff) = getPriceWithCircuitBreakers(vaultAsset);
        console.log("----isTokenDepeg", isTokenDepeg);
        console.log("----isTokenDispersion", isTokenDispersion);
        console.log("----isTokenOracleOff", isTokenOracleOff);
        if (isTokenDepeg || isTokenDispersion || isTokenOracleOff) {
            isSuccess = false;
            return (isSuccess);
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

    /// @dev Checks if the token is depegged
    /// @param token The address of the token to check the status of
    /// @param priceUSD The price of the token in USD
    /// @param assetPriceUSD The price of the asset in USD
    /// @return isDepeg True if the token is depegged
    function _isTokenDepeg(
        address token,
        uint256 priceUSD,
        uint256 assetPriceUSD
    )
        internal
        view
        returns (bool isDepeg)
    {
        uint256 ratio = Math.mulDiv(priceUSD, PRECISION, assetPriceUSD);

        // Adjust for decimals
        uint8 decimalsToken = IERC20Metadata(token).decimals();
        if (decimalsToken != DECIMALS) {
            ratio = Math.mulDiv(ratio, 10 ** (DECIMALS - decimalsToken), PRECISION);
        }
        if (ratio < DEPEG_LOWER_THRESHOLD || ratio > DEPEG_UPPER_THRESHOLD) {
            isDepeg = true;
        }
    }
}
