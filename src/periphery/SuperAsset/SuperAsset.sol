// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/SuperAsset/IIncentiveCalculationContract.sol";
import "../interfaces/SuperAsset/IIncentiveFundContract.sol";
import "../interfaces/SuperAsset/ISuperAsset.sol";
import "../interfaces/ISuperOracle.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";

import { ISuperAssetFactory } from "../interfaces/SuperAsset/ISuperAssetFactory.sol";

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

    // --- Constants ---
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_SWAP_FEE_PERCENTAGE = 10 ** 4; // Max 10% (1000 basis points)
    uint256 public constant DEPEG_LOWER_THRESHOLD = 98e16; // 0.98
    uint256 public constant DEPEG_UPPER_THRESHOLD = 102e16; // 1.02
    uint256 public constant DISPERSION_THRESHOLD = 1e16; // 1% relative standard deviation threshold
    uint256 public constant SWAP_FEE_PERC = 10 ** 6;

    // --- State ---
    mapping(address token => bool isSupported) public isSupportedUnderlyingVault;
    mapping(address token => bool isSupported) public isSupportedERC20;

    // NOTE: Actually it does not contain only supported Vaults shares but also standard ERC20
    EnumerableSet.AddressSet private _supportedVaults;
    address public incentiveCalculationContract; // Address of the ICC
    address public incentiveFundContract; // Address of the Incentive Fund Contract

    mapping(address token => uint256 allocation) public targetAllocations;
    mapping(address token => uint256 allocation) public weights; // Weights for each vault in energy calculation

    ISuperOracle public superOracle;
    ISuperGovernor public _SUPER_GOVERNOR;

    uint256 public swapFeeInPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public swapFeeOutPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public energyToUSDExchangeRatio;

    mapping(address token => uint256 priceUSD) public emergencyPrices; // Used when an oracle is down, managed by us

    // --- Addresses ---
    address public constant USD = address(840);

    // SuperOracle related
    bytes32 public constant AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");

    bytes32 public _SUPER_ASSET_FACTORY;

    // --- Modifiers ---
    modifier onlyVault() {
        if (!isSupportedUnderlyingVault[msg.sender]) revert NOT_VAULT();
        _;
    }

    modifier onlyERC20() {
        if (!isSupportedERC20[msg.sender]) revert NOT_ERC20_TOKEN();
        _;
    }

    constructor() ERC20("", "") { }

    /// @inheritdoc ERC20
    function name() public view override returns (string memory) {
        return tokenName;
    }

    /// @inheritdoc ERC20
    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    /// @inheritdoc ISuperAsset
    function initialize(
        string memory name_,
        string memory symbol_,
        address icc_,
        address ifc_,
        address superGovernor_,
        uint256 swapFeeInPercentage_,
        uint256 swapFeeOutPercentage_
    )
        external
    {
        // Ensure this can only be called once
        if (incentiveCalculationContract != address(0)) revert ALREADY_INITIALIZED();

        if (icc_ == address(0)) revert ZERO_ADDRESS();
        if (ifc_ == address(0)) revert ZERO_ADDRESS();
        if (swapFeeInPercentage_ > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();
        if (swapFeeOutPercentage_ > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();

        incentiveCalculationContract = icc_;
        incentiveFundContract = ifc_;
        swapFeeInPercentage = swapFeeInPercentage_;
        swapFeeOutPercentage = swapFeeOutPercentage_;
        
        // Initialize ERC20 name and symbol
        tokenName = name_;
        tokenSymbol = symbol_;

        _SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
        _SUPER_ASSET_FACTORY = _SUPER_GOVERNOR.SUPER_ASSET_FACTORY();
    }

    /*//////////////////////////////////////////////////////////////
                EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperAsset
    function getPPS() public view returns(uint256 pps) {
        // TODO: Improve the implementation of this function to handle the case for de-whitelisted tokens for which the SuperAsset has still non-zero exposure 
        // TODO: Use this function in the calculations instead of the PPS value got from the SuperOracle 
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) return 0; 

        uint256 totalValueUSD;
        // TODO: We need to iterate over all the historically whitelisted vaults and not just the currently whitelisted ones
        // NOTE: This means we also need to track the historically whitelisted vaults
        uint256 len = _supportedVaults.length();
        for (uint256 i = 0; i < len; i++) {
            address token = _supportedVaults.at(i);
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance == 0) continue;

            (uint256 priceUSD,,,) = getPriceWithCircuitBreakers(token);
            uint256 decimals = IERC20Metadata(token).decimals();
            uint256 valueUSD = (balance * priceUSD) / (10 ** decimals);
            totalValueUSD += valueUSD;
        }

        // PPS = Total Value in USD / Total Supply, normalized to PRECISION
        pps = (totalValueUSD * PRECISION) / totalSupply_;
    }

    /// @inheritdoc ISuperAsset
    function getIncentiveFundContract() external view returns (address) {
        return incentiveFundContract;
    }

    /// @inheritdoc ISuperAsset
    function mint(address to, uint256 amount) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_ASSET_FACTORY));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        _mint(to, amount);
    }

    /// @inheritdoc ISuperAsset
    function burn(address from, uint256 amount) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_ASSET_FACTORY));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        _burn(from, amount);
    }

    /// @inheritdoc ISuperAsset
    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    /// @inheritdoc ISuperAsset
    function setSwapFeeInPercentage(uint256 _feePercentage) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_ASSET_FACTORY));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        if (_feePercentage > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();
        swapFeeInPercentage = _feePercentage;
    }

    /// @inheritdoc ISuperAsset
    function setSwapFeeOutPercentage(uint256 _feePercentage) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_ASSET_FACTORY));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        if (_feePercentage > MAX_SWAP_FEE_PERCENTAGE) revert INVALID_SWAP_FEE_PERCENTAGE();
        swapFeeOutPercentage = _feePercentage;
    }

    /// @inheritdoc ISuperAsset
    function setSuperOracle(address oracle) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_ASSET_FACTORY));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        if (oracle == address(0)) revert ZERO_ADDRESS();
        superOracle = ISuperOracle(oracle);
        emit SuperOracleSet(oracle);
    }

    /// @inheritdoc ISuperAsset
    function setWeight(address vault, uint256 weight) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_ASSET_FACTORY));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (!isSupportedUnderlyingVault[vault]) revert NOT_VAULT();
        weights[vault] = weight;
        emit WeightSet(vault, weight);
    }

    /// @inheritdoc ISuperAsset
    function setTargetAllocations(address[] calldata tokens, uint256[] calldata allocations) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_ASSET_FACTORY));
        address strategist = factory.getSuperAssetStrategist(address(this));
        if (strategist != msg.sender) revert UNAUTHORIZED();
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


    /// @inheritdoc ISuperAsset
    function setTargetAllocation(address token, uint256 allocation) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_ASSET_FACTORY));
        address strategist = factory.getSuperAssetStrategist(address(this));
        if (strategist != msg.sender) revert UNAUTHORIZED();
        if (token == address(0)) revert ZERO_ADDRESS();
        if (!isSupportedUnderlyingVault[token] && !isSupportedERC20[token]) revert NOT_SUPPORTED_TOKEN();

        // NOTE: I am not sure we need this check since the allocations get normalized inside the ICC
        if (allocation > PRECISION) revert INVALID_ALLOCATION();

        targetAllocations[token] = allocation;
        emit TargetAllocationSet(token, allocation);
    }

    /// @inheritdoc ISuperAsset
    function setEnergyToUSDExchangeRatio(uint256 newRatio) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_ASSET_FACTORY));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        energyToUSDExchangeRatio = newRatio;
        emit EnergyToUSDExchangeRatioSet(newRatio);
    }

    // --- Token Movement Functions ---

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
        if (amountTokenToDeposit == 0) revert ZERO_AMOUNT();
        if (!isSupportedUnderlyingVault[yieldSourceShare] && !isSupportedERC20[yieldSourceShare]) {
            revert NOT_SUPPORTED_TOKEN();
        }
        if (receiver == address(0)) revert ZERO_ADDRESS();

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

        // Transfer swap fees to Asset Bank while holding the rest in the contract, since the full amount was already
        // transferred in the beginning of the function
        // TODO: Fix this by transfering money to SuperBank
        IERC20(yieldSourceShare).safeTransfer(address(incentiveFundContract), swapFee);

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
        if (amountSharesToRedeem == 0) revert ZERO_AMOUNT();
        if (!isSupportedUnderlyingVault[tokenOut] && !isSupportedERC20[tokenOut]) revert NOT_SUPPORTED_TOKEN();
        if (receiver == address(0)) revert ZERO_ADDRESS();

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
        // TODO: Fix this by transfering money to SuperBank
        IERC20(tokenOut).safeTransfer(address(incentiveFundContract), swapFee);

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

    /// @inheritdoc ISuperAsset
    function whitelistVault(address vault) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_GOVERNOR.SUPER_ASSET_FACTORY()));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (isSupportedUnderlyingVault[vault]) revert ALREADY_WHITELISTED();
        isSupportedUnderlyingVault[vault] = true;
        _supportedVaults.add(vault);
        emit VaultWhitelisted(vault);
    }

    /// @inheritdoc ISuperAsset
    function removeVault(address vault) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_GOVERNOR.SUPER_ASSET_FACTORY()));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (!isSupportedUnderlyingVault[vault]) revert NOT_WHITELISTED();
        isSupportedUnderlyingVault[vault] = false;
        _supportedVaults.remove(vault);
        emit VaultRemoved(vault);
    }

    /// @inheritdoc ISuperAsset
    function whitelistERC20(address token) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_GOVERNOR.SUPER_ASSET_FACTORY()));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        if (token == address(0)) revert ZERO_ADDRESS();
        if (isSupportedERC20[token]) revert ALREADY_WHITELISTED();
        isSupportedERC20[token] = true;
        _supportedVaults.add(token);
        emit ERC20Whitelisted(token);
    }

    /// @inheritdoc ISuperAsset
    function removeERC20(address token) external {
        ISuperAssetFactory factory =  ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_GOVERNOR.SUPER_ASSET_FACTORY()));
        address manager = factory.getSuperAssetManager(address(this));
        if (manager != msg.sender) revert UNAUTHORIZED();
        if (token == address(0)) revert ZERO_ADDRESS();
        if (!isSupportedERC20[token]) revert NOT_WHITELISTED();
        isSupportedERC20[token] = false;
        _supportedVaults.remove(token);
        emit ERC20Removed(token);
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
            absoluteTargetAllocation[i] = targetAllocations[vault];
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
            absoluteTargetAllocation[i] = targetAllocations[s.vault];
            totalTargetAllocation += absoluteTargetAllocation[i];
            vaultWeights[i] = weights[s.vault];
        }
        isSuccess = true;
    }

    /// @inheritdoc ISuperAsset
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
        // NOTE: Preview Function should not revert
        if (!isSupportedUnderlyingVault[tokenIn] && !isSupportedERC20[tokenIn]) return (0, 0, 0, false);

        // Calculate swap fees (example: 0.1% fee)
        swapFee = Math.mulDiv(amountTokenToDeposit, swapFeeInPercentage, SWAP_FEE_PERC); // 0.1%
        s.amountTokenInAfterFees = amountTokenToDeposit - swapFee;

        // Get price of underlying vault shares in USD
        (s.priceUSDTokenIn,,,) = getPriceWithCircuitBreakers(tokenIn);
        (s.priceUSDThisShares,,,) = getPriceWithCircuitBreakers(address(this));

        // NOTE: Preview Function should not revert
        if (s.priceUSDTokenIn == 0 || s.priceUSDThisShares == 0) return (0, 0, 0, false);

        // Calculate SuperUSD shares to mint
        amountSharesMinted = Math.mulDiv(s.amountTokenInAfterFees, s.priceUSDTokenIn, s.priceUSDThisShares); // Adjust
            // for decimals

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

        // Calculate incentives (using ICC)
        (amountIncentiveUSD, s.allocations.isSuccess) = IIncentiveCalculationContract(incentiveCalculationContract)
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
        return (amountSharesMinted, swapFee, amountIncentiveUSD, s.allocations.isSuccess);
    }

    /// @inheritdoc ISuperAsset
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
        // NOTE: Handle the case of a token that was whitelisted, now it is not whitelisted anymore but still this
        // contract holds some exposure to this token

        // Get price of underlying vault shares in USD
        (s.priceUSDThisShares,,,) = getPriceWithCircuitBreakers(address(this));
        (s.priceUSDTokenOut,,,) = getPriceWithCircuitBreakers(tokenOut);

        // Calculate underlying shares to redeem
        s.amountTokenOutBeforeFees = Math.mulDiv(amountSharesToRedeem, s.priceUSDThisShares, s.priceUSDTokenOut); // Adjust
            // for decimals

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

        // TODO: Handle the case where isSuccess is false

        // Calculate incentives (using ICC)
        (amountIncentiveUSD, s.allocations.isSuccess) = IIncentiveCalculationContract(incentiveCalculationContract)
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

    /// @inheritdoc ISuperAsset
    function getPriceWithCircuitBreakers(address token)
        public
        view
        returns (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff)
    {
        // NOTE: Also this function should not revert
        // NOTE: We do not need this check here, since price request can also regard non-whitelisted tokens like
        // integrated SuperVaults underlying assets, this price is required to check if a depeg, dispersion, oracle off
        // happened
        // if (!isSupportedUnderlyingVault[token] && !isSupportedERC20[token]) revert NOT_SUPPORTED_TOKEN();

        // Get token decimals
        uint256 one = 10 ** IERC20Metadata(token).decimals();
        uint256 stddev;
        uint256 N;
        uint256 M;

        // NOTE: We need to pass oneUnit to get the price of a single unit of asset to check if it has depegged since
        // the depeg threshold regards a single asset
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
