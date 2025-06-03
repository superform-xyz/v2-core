// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperAsset } from "../interfaces/SuperAsset/ISuperAsset.sol";
import { SuperAssetPriceLib } from "../libraries/SuperAssetPriceLib.sol";
import { ISuperAssetFactory } from "../interfaces/SuperAsset/ISuperAssetFactory.sol";
import { IIncentiveCalculationContract } from "../interfaces/SuperAsset/IIncentiveCalculationContract.sol";
import { IIncentiveFundContract } from "../interfaces/SuperAsset/IIncentiveFundContract.sol";

import { console } from "forge-std/console.sol";

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
    ISuperGovernor private superGovernor;
    ISuperAssetFactory private factory;

    // --- Constants ---
    uint256 private constant PRECISION = 1e18;
    uint256 private constant DECIMALS = 18;
    uint256 private constant DEPEG_LOWER_THRESHOLD = 98e16; // 0.98
    uint256 private constant DEPEG_UPPER_THRESHOLD = 102e16; // 1.02
    uint256 private constant DISPERSION_THRESHOLD = 1e16; // 1% relative standard deviation threshold

    // --- Fee Constants ---
    uint256 public constant SWAP_FEE_PERC = 10 ** 6;
    uint256 public constant MAX_SWAP_FEE_PERC = 10 ** 4; // Max 10% (1000 basis points)

    // --- State Variables ---
    mapping(address token => TokenData data) private tokenData;

    // @notice Contains supported Vaults shares and standard ERC20s
    EnumerableSet.AddressSet private _supportedAssets;

    uint256 public swapFeeInPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public swapFeeOutPercentage; // Swap fee as a percentage (e.g., 10 for 0.1%)
    uint256 public energyToUSDExchangeRatio;

    // --- Addresses ---
    address private constant USD = address(840);
    address public primaryAsset;

    // SuperOracle related
    bytes32 private constant AVERAGE_PROVIDER = keccak256("AVERAGE_PROVIDER");

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

        if (swapFeeInPercentage_ > MAX_SWAP_FEE_PERC) revert INVALID_SWAP_FEE_PERCENTAGE();
        if (swapFeeOutPercentage_ > MAX_SWAP_FEE_PERC) revert INVALID_SWAP_FEE_PERCENTAGE();

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
    function whitelistERC20(address token) external {
        _onlyManager();
        if (token == address(0)) revert ZERO_ADDRESS();
        if (tokenData[token].isSupportedERC20) revert ALREADY_WHITELISTED();

        // Set token as supported and active
        tokenData[token].isSupportedERC20 = true;
        tokenData[token].isActive = true;

        tokenData[token].oracle = superGovernor.getAddress(superGovernor.SUPER_ORACLE());
        _supportedAssets.add(token);

        emit ERC20Whitelisted(token);
    }

    /// @inheritdoc ISuperAsset
    function removeERC20(address token) external {
        _onlyManager();
        if (token == address(0)) revert ZERO_ADDRESS();

        // Mark token as inactive
        tokenData[token].isActive = false;

        // Prevent full purge if token has 0 balance
        if (IERC20(token).balanceOf(address(this)) == 0) {
            // Full removal - clear all data
            _supportedAssets.remove(token);
            tokenData[token].oracle = address(0);
            tokenData[token].isSupportedERC20 = false;
        }

        emit ERC20Removed(token);
    }

    /// @inheritdoc ISuperAsset
    function activateERC20(address token) external {
        _onlyManager();
        if (token == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[token].isSupportedERC20) revert TOKEN_NOT_SUPPORTED();
        if (tokenData[token].isActive) revert TOKEN_ALREADY_ACTIVE();

        // Reactivate the token
        tokenData[token].isActive = true;

        emit ERC20Activated(token);
    }

    /// @inheritdoc ISuperAsset
    function whitelistVault(address vault, address yieldSourceOracle) external {
        _onlyManager();
        if (vault == address(0) || yieldSourceOracle == address(0)) revert ZERO_ADDRESS();
        if (tokenData[vault].isSupportedUnderlyingVault) revert ALREADY_WHITELISTED();

        // Set vault as supported and active
        tokenData[vault].isSupportedUnderlyingVault = true;
        tokenData[vault].isActive = true;

        tokenData[vault].oracle = yieldSourceOracle;
        _supportedAssets.add(vault);

        emit VaultWhitelisted(vault);
    }

    /// @inheritdoc ISuperAsset
    function removeVault(address vault) external {
        _onlyManager();
        if (vault == address(0)) revert ZERO_ADDRESS();

        // Mark vault as inactive
        tokenData[vault].isActive = false;

        // Prevent full purge if vault has 9 balance
        if (IERC20(vault).balanceOf(address(this)) == 0) {
            // Full removal - clear all data
            _supportedAssets.remove(vault);
            tokenData[vault].oracle = address(0);
            tokenData[vault].isSupportedUnderlyingVault = false;
        }

        emit VaultRemoved(vault);
    }

    /// @inheritdoc ISuperAsset
    function activateVault(address vault) external {
        _onlyManager();
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[vault].isSupportedUnderlyingVault) revert VAULT_NOT_SUPPORTED();
        if (tokenData[vault].isActive) revert TOKEN_ALREADY_ACTIVE();

        // Reactivate the vault
        tokenData[vault].isActive = true;

        emit VaultActivated(vault);
    }

    /// @inheritdoc ISuperAsset
    function setSwapFeeInPercentage(uint256 _feePercentage) external {
        _onlyManager();
        if (_feePercentage > MAX_SWAP_FEE_PERC) revert INVALID_SWAP_FEE_PERCENTAGE();
        swapFeeInPercentage = _feePercentage;
    }

    /// @inheritdoc ISuperAsset
    function setSwapFeeOutPercentage(uint256 _feePercentage) external {
        _onlyManager();
        if (_feePercentage > MAX_SWAP_FEE_PERC) revert INVALID_SWAP_FEE_PERCENTAGE();
        swapFeeOutPercentage = _feePercentage;
    }

    /// @inheritdoc ISuperAsset
    function setWeight(address vault, uint256 weight) external {
        _onlyManager();
        if (vault == address(0)) revert ZERO_ADDRESS();
        if (!tokenData[vault].isSupportedUnderlyingVault && !tokenData[vault].isSupportedERC20) revert NOT_SUPPORTED_TOKEN();
        tokenData[vault].weights = weight;
        emit WeightSet(vault, weight);
    }

    /// @inheritdoc ISuperAsset
    function setEnergyToUSDExchangeRatio(uint256 newRatio) external {
        _onlyManager();
        energyToUSDExchangeRatio = newRatio;
        emit EnergyToUSDExchangeRatioSet(newRatio);
    }

    /// @inheritdoc ISuperAsset
    function mint(address to, uint256 amount) external {
        _onlyManager();
        _mint(to, amount);
    }

    /// @inheritdoc ISuperAsset
    function burn(address from, uint256 amount) external {
        _onlyManager();
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          STRATEGIST FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperAsset
    function setTargetAllocations(address[] calldata tokens, uint256[] calldata allocations) external {
        _onlyStrategist();
        uint256 lenTokens = tokens.length;
        if (lenTokens != allocations.length) revert INVALID_INPUT();

        for (uint256 i; i < lenTokens; i++) {
            if (tokens[i] == address(0)) revert ZERO_ADDRESS();
            if (!tokenData[tokens[i]].isSupportedUnderlyingVault && !tokenData[tokens[i]].isSupportedERC20) {
                revert NOT_SUPPORTED_TOKEN();
            }
        }

        for (uint256 i; i < lenTokens; i++) {
            tokenData[tokens[i]].targetAllocations = allocations[i];
            emit TargetAllocationSet(tokens[i], allocations[i]);
        }
    }

    /// @inheritdoc ISuperAsset
    function setTargetAllocation(address token, uint256 allocation) external {
        _onlyStrategist();
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
    function deposit(DepositArgs memory args) public returns (DepositReturnVars memory ret) {
        // First all the non state changing functions
        if (args.receiver == address(0) || args.tokenIn == address(0)) revert ZERO_ADDRESS();
        if (args.amountTokenToDeposit == 0) revert ZERO_AMOUNT();
        if (
            !tokenData[args.tokenIn].isSupportedERC20 && !tokenData[args.tokenIn].isSupportedUnderlyingVault
                || !tokenData[args.tokenIn].isActive
        ) {
            revert NOT_SUPPORTED_TOKEN();
        }

        // Create preview deposit args
        PreviewDepositArgs memory previewArgs = PreviewDepositArgs({
            tokenIn: args.tokenIn,
            amountTokenToDeposit: args.amountTokenToDeposit,
            isSoft: false
        });

        // Call previewDeposit with the new struct approach
        PreviewDepositReturnVars memory previewRet = previewDeposit(previewArgs);

        // Store results in return variable
        ret.amountSharesMinted = previewRet.amountSharesMinted;
        ret.swapFee = previewRet.swapFee;
        ret.amountIncentiveUSDDeposit = previewRet.amountIncentiveUSDDeposit;

        // incentiveCalculationSuccess == false but totalSupply == 0 for the first deposit, this check allows for the
        // first deposit (in which case calculateIncentive() will fail) to pass
        if (!previewRet.incentiveCalculationSuccess && totalSupply() != 0) revert INCENTIVE_CALCULATION_FAILED();

        // Slippage Check
        if (ret.amountSharesMinted < args.minSharesOut) revert SLIPPAGE_PROTECTION();

        if (previewRet.assetWithBreakerTriggered != address(0)) {
            // Circuit Breaker Checks
            if (previewRet.isDepeg) {
                revert SUPPORTED_ASSET_PRICE_DEPEG(previewRet.assetWithBreakerTriggered);
            }
            if (previewRet.isOracleOff) {
                revert SUPPORTED_ASSET_PRICE_ORACLE_OFF(previewRet.assetWithBreakerTriggered);
            }
            if (previewRet.isDispersion) {
                revert SUPPORTED_ASSET_PRICE_DISPERSION(previewRet.assetWithBreakerTriggered);
            }
            if (previewRet.oraclePriceUSD == 0) {
                revert SUPPORTED_ASSET_PRICE_ZERO(previewRet.assetWithBreakerTriggered);
            }
        }

        if (!previewRet.tokenInFound) {
            revert NOT_SUPPORTED_TOKEN();
        }

        // Settle Incentives
        if (ret.amountIncentiveUSDDeposit > 0) {
            _settleIncentive(args.receiver, ret.amountIncentiveUSDDeposit);
        }

        console.log("deposit() T6");

        // Transfer the tokenIn from the sender to this contract
        IERC20(args.tokenIn).safeTransferFrom(msg.sender, address(this), args.amountTokenToDeposit);

        // Transfer swap fees to SuperBank
        IERC20(args.tokenIn).safeTransfer(superGovernor.getAddress(superGovernor.SUPER_BANK()), ret.swapFee);
        // Mint SuperUSD shares
        _mint(args.receiver, ret.amountSharesMinted);

        console.log("deposit() T12");

        emit Deposit(
            args.receiver,
            args.tokenIn,
            args.amountTokenToDeposit,
            ret.amountSharesMinted,
            ret.swapFee,
            ret.amountIncentiveUSDDeposit
        );
        console.log("deposit() End");

    }

    /// @inheritdoc ISuperAsset
    function redeem(RedeemArgs memory args) public returns (RedeemReturnVars memory ret) {
        // First validate parameters
        console.log("redeem() Start");
        if (args.receiver == address(0) || args.tokenOut == address(0)) revert ZERO_ADDRESS();
        if (args.amountSharesToRedeem == 0) revert ZERO_AMOUNT();

        // NOTE: Removing a token from the whitelist just prevents SuperAsset to increase its exposure to it but 
        // it should not prevent to reduce its exposure to it 
        // So these checks should not be applied in the case of the redeem
        // if (
        //     !tokenData[args.tokenOut].isSupportedERC20 && !tokenData[args.tokenOut].isSupportedUnderlyingVault
        //         || !tokenData[args.tokenOut].isActive
        // ) {
        //     revert NOT_SUPPORTED_TOKEN();
        // }

        // TODO: Maybe check if the outToken.balanceOf(SuperAsset) == 0 in which case revert with a clean error there

        // Create preview redeem args
        PreviewRedeemArgs memory previewArgs = PreviewRedeemArgs({
            tokenOut: args.tokenOut,
            amountSharesToRedeem: args.amountSharesToRedeem,
            isSoft: false // isSoft = false for hard checks
         });

        console.log("redeem() T1");
        // Call previewRedeem with the new struct approach
        PreviewRedeemReturnVars memory previewRet = previewRedeem(previewArgs);
        console.log("redeem() T3");

        // Store results in return variable
        ret.amountTokenOutAfterFees = previewRet.amountTokenOutAfterFees;
        ret.swapFee = previewRet.swapFee;
        ret.amountIncentiveUSDRedeem = previewRet.amountIncentiveUSDRedeem;

        // --- Post-preview checks ---
        // incentiveCalculationSuccess == false but totalSupply == 0 for the first deposit, this check allows for the
        // first deposit (in which case calculateIncentive() will fail) to pass. Similar logic applies to redeem.
        if (!previewRet.incentiveCalculationSuccess && totalSupply() != 0) revert INCENTIVE_CALCULATION_FAILED();

        // Slippage Check
        if (ret.amountTokenOutAfterFees < args.minTokenOut) revert SLIPPAGE_PROTECTION();

        // Circuit Breaker Checks
        if (previewRet.assetWithBreakerTriggered != address(0)) {
            if (previewRet.isDepeg) {
                revert SUPPORTED_ASSET_PRICE_DEPEG(previewRet.assetWithBreakerTriggered);
            }
            if (previewRet.isOracleOff) {
                revert SUPPORTED_ASSET_PRICE_ORACLE_OFF(previewRet.assetWithBreakerTriggered);
            }
            if (previewRet.isDispersion) {
                revert SUPPORTED_ASSET_PRICE_DISPERSION(previewRet.assetWithBreakerTriggered);
            }
            if (previewRet.oraclePriceUSD == 0) {
                revert SUPPORTED_ASSET_PRICE_ZERO(previewRet.assetWithBreakerTriggered);
            }
        }

        if (!previewRet.tokenOutFound) {
            revert NOT_SUPPORTED_TOKEN(); // Or a more specific error if tokenOut_ was expected to be found by preview
        }

        // --- State Changing Operations ---

        // Settle Incentives
        if (ret.amountIncentiveUSDRedeem > 0) {
            _settleIncentive(args.receiver, ret.amountIncentiveUSDRedeem);
        }
        // Burn SuperUSD shares from the sender
        _burn(msg.sender, args.amountSharesToRedeem);

        // Transfer swap fees to SuperBank
        IERC20(args.tokenOut).safeTransfer(superGovernor.getAddress(superGovernor.SUPER_BANK()), ret.swapFee);

        // Transfer assets to receiver
        IERC20(args.tokenOut).safeTransfer(args.receiver, ret.amountTokenOutAfterFees);

        // --- Emit event and set return values ---
        emit Redeem(
            args.receiver,
            args.tokenOut,
            args.amountSharesToRedeem,
            ret.amountTokenOutAfterFees,
            ret.swapFee,
            ret.amountIncentiveUSDRedeem
        );
    }

    /// @inheritdoc ISuperAsset
    function swap(SwapArgs memory args) external returns (SwapReturnVars memory ret) {
        if (args.receiver == address(0) || args.tokenIn == address(0) || args.tokenOut == address(0)) {
            revert ZERO_ADDRESS();
        }

        // Create deposit args from swap args
        DepositArgs memory depositArgs = DepositArgs({
            receiver: msg.sender,
            tokenIn: args.tokenIn,
            amountTokenToDeposit: args.amountTokenToDeposit,
            minSharesOut: 0
        });
        DepositReturnVars memory depositRet = deposit(depositArgs);

        // Create redeem args from swap args and deposit result
        RedeemArgs memory redeemArgs = RedeemArgs({
            receiver: args.receiver,
            amountSharesToRedeem: depositRet.amountSharesMinted,
            tokenOut: args.tokenOut,
            minTokenOut: args.minTokenOut
        });
        RedeemReturnVars memory redeemRet = redeem(redeemArgs);

        // Fill the return struct
        ret.amountSharesIntermediateStep = depositRet.amountSharesMinted;
        ret.amountTokenOutAfterFees = redeemRet.amountTokenOutAfterFees;
        ret.swapFeeIn = depositRet.swapFee;
        ret.swapFeeOut = redeemRet.swapFee;
        ret.amountIncentivesIn = depositRet.amountIncentiveUSDDeposit;
        ret.amountIncentivesOut = redeemRet.amountIncentiveUSDRedeem;

        emit Swap(
            args.receiver,
            args.tokenIn,
            args.amountTokenToDeposit,
            args.tokenOut,
            ret.amountSharesIntermediateStep,
            ret.amountTokenOutAfterFees,
            ret.swapFeeIn,
            ret.swapFeeOut,
            ret.amountIncentivesIn,
            ret.amountIncentivesOut
        );
    }

    /*//////////////////////////////////////////////////////////////
                            PREVIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperAsset
    function previewDeposit(PreviewDepositArgs memory args) public view returns (PreviewDepositReturnVars memory ret) {
        // Calculate swap fees
        ret.swapFee = Math.mulDiv(args.amountTokenToDeposit, swapFeeInPercentage, SWAP_FEE_PERC);

        // Get current and post-operation allocations using the struct-based return value
        ISuperAsset.AllocationOperationReturnVars memory allocRet = getAllocationsPrePostOperationDeposit(
            args.tokenIn, args.amountTokenToDeposit, args.amountTokenToDeposit - ret.swapFee, args.isSoft
        );

        // Copy values from allocation return struct to our local variable
        ret.amountSharesMinted = allocRet.amountAssets;

        // Copy circuit breaker info to return struct
        ret.assetWithBreakerTriggered = allocRet.assetWithBreakerTriggered;
        ret.oraclePriceUSD = allocRet.oraclePriceUSD;
        ret.isDepeg = allocRet.isDepeg;
        ret.isDispersion = allocRet.isDispersion;
        ret.isOracleOff = allocRet.isOracleOff;
        ret.tokenInFound = allocRet.tokenFound;

        if ((ret.isDepeg || ret.isDispersion || ret.isOracleOff || ret.oraclePriceUSD == 0)) {
            // Early return with empty result but with circuit breaker info
            ret.amountSharesMinted = 0;
            ret.swapFee = 0;
            ret.amountIncentiveUSDDeposit = 0;
            ret.incentiveCalculationSuccess = false;

            return ret;
        }

        // Calculate incentives (via ICC)
        if (IIncentiveFundContract(factory.getIncentiveFundContract(address(this))).incentivesEnabled()) {
            (ret.amountIncentiveUSDDeposit, ret.incentiveCalculationSuccess) = IIncentiveCalculationContract(
                factory.getIncentiveCalculationContract(address(this))
            ).calculateIncentive(
                allocRet.absoluteAllocationPreOperation,
                allocRet.absoluteAllocationPostOperation,
                allocRet.absoluteTargetAllocation,
                allocRet.vaultWeights,
                allocRet.totalAllocationPreOperation,
                allocRet.totalAllocationPostOperation,
                allocRet.totalTargetAllocation,
                energyToUSDExchangeRatio
            );
        } else {
            // if incentives disabled, soft return incentiveCalculationSuccess as true
            ret.incentiveCalculationSuccess = true;
        }
    }

    /// @inheritdoc ISuperAsset
    function previewRedeem(PreviewRedeemArgs memory args) public view returns (PreviewRedeemReturnVars memory ret) {
        console.log("previewRedeem() Start");
        // Get current and post-operation allocations using the struct-based return value
        ISuperAsset.AllocationOperationReturnVars memory allocRet =
            getAllocationsPrePostOperationRedeem(args.tokenOut, args.amountSharesToRedeem, args.isSoft);
        console.log("previewRedeem() T1");
        // Copy circuit breaker info to return struct
        ret.assetWithBreakerTriggered = allocRet.assetWithBreakerTriggered;
        ret.oraclePriceUSD = allocRet.oraclePriceUSD;
        ret.isDepeg = allocRet.isDepeg;
        ret.isDispersion = allocRet.isDispersion;
        ret.isOracleOff = allocRet.isOracleOff;
        ret.tokenOutFound = allocRet.tokenFound;

        if ((ret.isDepeg || ret.isDispersion || ret.isOracleOff || ret.oraclePriceUSD == 0)) {
            // Early return with empty result but with circuit breaker info
            ret.amountTokenOutAfterFees = 0;
            ret.swapFee = 0;
            ret.amountIncentiveUSDRedeem = 0;
            ret.incentiveCalculationSuccess = false;

            return ret;
        }

        console.log("previewRedeem() T2");
        // Calculate swap fee
        ret.swapFee = Math.mulDiv(allocRet.amountAssets, swapFeeOutPercentage, SWAP_FEE_PERC); // 0.1%
        ret.amountTokenOutAfterFees = allocRet.amountAssets - ret.swapFee;

        console.log("previewRedeem() T3");
        // Calculate incentives (via ICC)
        if (IIncentiveFundContract(factory.getIncentiveFundContract(address(this))).incentivesEnabled()) {
            (ret.amountIncentiveUSDRedeem, ret.incentiveCalculationSuccess) = IIncentiveCalculationContract(
                factory.getIncentiveCalculationContract(address(this))
            ).calculateIncentive(
                allocRet.absoluteAllocationPreOperation,
                allocRet.absoluteAllocationPostOperation,
                allocRet.absoluteTargetAllocation,
                allocRet.vaultWeights,
                allocRet.totalAllocationPreOperation,
                allocRet.totalAllocationPostOperation,
                allocRet.totalTargetAllocation,
                energyToUSDExchangeRatio
            );
        } else {
            // if incentives disabled, soft return incentiveCalculationSuccess as true
            ret.incentiveCalculationSuccess = true;
        }

        console.log("previewRedeem() T5");
    }

    /// @inheritdoc ISuperAsset
    function previewSwap(PreviewSwapArgs memory args) external view returns (PreviewSwapReturnVars memory ret) {
        uint256 amountSharesMinted;
        // Create preview deposit args
        PreviewDepositArgs memory depositArgs = PreviewDepositArgs({
            tokenIn: args.tokenIn,
            amountTokenToDeposit: args.amountTokenToDeposit,
            isSoft: args.isSoft
        });

        // Call previewDeposit with the new struct approach
        PreviewDepositReturnVars memory depositRet = previewDeposit(depositArgs);

        // Store results
        amountSharesMinted = depositRet.amountSharesMinted;
        ret.swapFeeIn = depositRet.swapFee;
        ret.amountIncentiveUSDDeposit = depositRet.amountIncentiveUSDDeposit;
        ret.assetWithBreakerTriggered = depositRet.assetWithBreakerTriggered;
        ret.oraclePriceUSD = depositRet.oraclePriceUSD;
        ret.isDepeg = depositRet.isDepeg;
        ret.isDispersion = depositRet.isDispersion;
        ret.isOracleOff = depositRet.isOracleOff;
        ret.tokenInFound = depositRet.tokenInFound;
        ret.incentiveCalculationSuccess = depositRet.incentiveCalculationSuccess;

        if (
            !ret.tokenInFound || ret.isDepeg || ret.isDispersion || ret.isOracleOff || !ret.incentiveCalculationSuccess
                || ret.oraclePriceUSD == 0
        ) {
            // Return empty result but with circuit breaker info
            ret.amountTokenOutAfterFees = 0;
            ret.swapFeeOut = 0;
            ret.amountIncentiveUSDRedeem = 0;
            return ret;
        }

        // note: it is possible to optimize the calls to oracle if the logic is extracted inside the preview functions

        // Create preview redeem args
        PreviewRedeemArgs memory redeemArgs = PreviewRedeemArgs({
            tokenOut: args.tokenOut,
            amountSharesToRedeem: amountSharesMinted,
            isSoft: args.isSoft
        });

        // Call previewRedeem with the new struct approach
        PreviewRedeemReturnVars memory redeemRet = previewRedeem(redeemArgs);

        // Store results
        ret.amountTokenOutAfterFees = redeemRet.amountTokenOutAfterFees;
        ret.swapFeeOut = redeemRet.swapFee;
        ret.amountIncentiveUSDRedeem = redeemRet.amountIncentiveUSDRedeem;
        ret.assetWithBreakerTriggered = redeemRet.assetWithBreakerTriggered;
        ret.oraclePriceUSD = redeemRet.oraclePriceUSD;
        ret.isDepeg = redeemRet.isDepeg;
        ret.isDispersion = redeemRet.isDispersion;
        ret.isOracleOff = redeemRet.isOracleOff;
        ret.tokenInFound = redeemRet.tokenOutFound; // Mapped from tokenOutFound
        ret.incentiveCalculationSuccess = redeemRet.incentiveCalculationSuccess;
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
    function getPriceAndCircuitBreakers(address token)
        public
        view
        returns (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff)
    {
        address superOracle = superGovernor.getAddress(superGovernor.SUPER_ORACLE());

        return SuperAssetPriceLib.getPriceWithCircuitBreakers(
            ISuperAsset.PriceArgs({
                superOracle: superOracle,
                superAsset: address(this),
                token: token,
                usd: USD,
                depegLowerThreshold: DEPEG_LOWER_THRESHOLD,
                depegUpperThreshold: DEPEG_UPPER_THRESHOLD,
                dispersionThreshold: DISPERSION_THRESHOLD
            })
        );
    }

    /// @inheritdoc ISuperAsset
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
        )
    {
        uint256 len = _supportedAssets.length();
        activeTokens = new address[](len);
        pricePerTokenUSD = new uint256[](len);
        isDepeg = new bool[](len);
        isDispersion = new bool[](len);
        isOracleOff = new bool[](len);

        uint256 totalValueUSD;
        for (uint256 i; i < len; i++) {
            address token = _supportedAssets.at(i);
            activeTokens[i] = token;

            (uint256 priceUSD, bool isTokenDepeg, bool isTokenDispersion, bool isTokenOracleOff) =
                getPriceAndCircuitBreakers(token);

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
        // PPS = Total Value in USD / Total Supply, normalized to PRECISION
        if (totalSupply_ == 0) {
            pps = PRECISION;
        } else {
            pps = Math.mulDiv(totalValueUSD, PRECISION, totalSupply_);
        }
    }

    /// @inheritdoc ISuperAsset
    function getAllocations()
        external
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
        uint256 deltaToken,
        uint256 amountToken,
        bool isSoft
    )
        public
        view
        returns (ISuperAsset.AllocationOperationReturnVars memory ret)
    {
        GetAllocationsPrePostOperationsDeposit memory s;

        uint256 length = _supportedAssets.length();
        s.extendedLength = length + (_supportedAssets.contains(token) ? 0 : 1);
        // Initialize the arrays in the return struct
        ret.absoluteAllocationPreOperation = new uint256[](s.extendedLength);
        ret.absoluteAllocationPostOperation = new uint256[](s.extendedLength);
        ret.absoluteTargetAllocation = new uint256[](s.extendedLength);
        ret.vaultWeights = new uint256[](s.extendedLength);
        s.totalValueUSD = 0;
        s.priceUSDToken = 0;

        for (uint256 i; i < length; i++) {
            s.token = _supportedAssets.at(i);
            (ret.oraclePriceUSD, ret.isDepeg, ret.isDispersion, ret.isOracleOff) = getPriceAndCircuitBreakers(s.token);

            if (!isSoft && (ret.isDepeg || ret.isDispersion || ret.isOracleOff || ret.oraclePriceUSD == 0)) {
                // Return early with circuit breaker information
                ret.assetWithBreakerTriggered = s.token;
                return ret;
            }

            s.balance = IERC20(s.token).balanceOf(address(this));
            uint256 decimals = IERC20Metadata(s.token).decimals();
            if (s.balance > 0) {
                s.totalValueUSD += Math.mulDiv(s.balance, ret.oraclePriceUSD, 10 ** decimals);
            }
            // Convert balance to USD value using price
            ret.absoluteAllocationPreOperation[i] = Math.mulDiv(s.balance, ret.oraclePriceUSD, 10 ** decimals);
            ret.totalAllocationPreOperation += ret.absoluteAllocationPreOperation[i];
            ret.absoluteAllocationPostOperation[i] = ret.absoluteAllocationPreOperation[i];
            if (s.token == token) {
                s.priceUSDToken = ret.oraclePriceUSD;
                ret.tokenFound = true;
                s.absDeltaValue = Math.mulDiv(deltaToken, s.priceUSDToken, 10 ** decimals);
                s.deltaValue = int256(s.absDeltaValue);
                ret.absoluteAllocationPostOperation[i] =
                    uint256(int256(ret.absoluteAllocationPreOperation[i]) + s.deltaValue);
            }
            ret.totalAllocationPostOperation += ret.absoluteAllocationPostOperation[i];
            ret.absoluteTargetAllocation[i] = tokenData[s.token].targetAllocations;
            ret.totalTargetAllocation += ret.absoluteTargetAllocation[i];
            ret.vaultWeights[i] = tokenData[s.token].weights;
        }

        if(s.extendedLength > length) {
            uint256 i = length;
            s.token = token;
            (ret.oraclePriceUSD, ret.isDepeg, ret.isDispersion, ret.isOracleOff) = getPriceAndCircuitBreakers(s.token);
            s.balance = IERC20(s.token).balanceOf(address(this));
            uint256 decimals = IERC20Metadata(s.token).decimals();
            if (s.balance > 0) {
                s.totalValueUSD += Math.mulDiv(s.balance, ret.oraclePriceUSD, 10 ** decimals);
            }


            // Convert balance to USD value using price
            ret.absoluteAllocationPreOperation[i] = Math.mulDiv(s.balance, ret.oraclePriceUSD, 10 ** decimals);
            ret.totalAllocationPreOperation += ret.absoluteAllocationPreOperation[i];
            ret.absoluteAllocationPostOperation[i] = ret.absoluteAllocationPreOperation[i];
            if (s.token == token) {
                s.priceUSDToken = ret.oraclePriceUSD;
                ret.tokenFound = true;
                s.absDeltaValue = Math.mulDiv(deltaToken, s.priceUSDToken, 10 ** decimals);
                s.deltaValue = int256(s.absDeltaValue);
                ret.absoluteAllocationPostOperation[i] =
                    uint256(int256(ret.absoluteAllocationPreOperation[i]) + s.deltaValue);
            }
            ret.totalAllocationPostOperation += ret.absoluteAllocationPostOperation[i];
            ret.absoluteTargetAllocation[i] = tokenData[s.token].targetAllocations;
            ret.totalTargetAllocation += ret.absoluteTargetAllocation[i];
            ret.vaultWeights[i] = tokenData[s.token].weights;
        }

        uint256 superAssetPPS;
        uint256 totalSupply_ = totalSupply();
        // PPS = Total Value in USD / Total Supply, normalized to PRECISION
        if (totalSupply_ == 0) {
            superAssetPPS = PRECISION;
        } else {
            superAssetPPS = Math.mulDiv(s.totalValueUSD, PRECISION, totalSupply_);
        }

        ret.amountAssets = Math.mulDiv(amountToken, s.priceUSDToken, superAssetPPS);

        uint8 decimalsToken = IERC20Metadata(token).decimals();

        // Adjust for decimals
        if (decimalsToken < DECIMALS) {
            ret.amountAssets = Math.mulDiv(ret.amountAssets, 10 ** (DECIMALS - decimalsToken), PRECISION);
        } else if (decimalsToken > DECIMALS) {
            ret.amountAssets = Math.mulDiv(ret.amountAssets, 10 ** (decimalsToken - DECIMALS), PRECISION);
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
        returns (ISuperAsset.AllocationOperationReturnVars memory ret)
    {
        console.log("getAllocationsPrePostOperationRedeem() Start");
        // 1. if deposit, deltaToken is amountTokenToDeposit (that the user sent)
        // 2. however, if redeem, all prices are fetched first (priceUSD of token out and superAsset PPS)
        // 2.1 then, these prices are used to calculate amountTokenOutBeforeFees, which is the delta token
        GetAllocationsPrePostOperationsRedeem memory s;

        uint256 length = _supportedAssets.length();
        s.extendedLength = length + (_supportedAssets.contains(token) ? 0 : 1);
        s.oraclePriceUSDs = new uint256[](s.extendedLength);
        s.balances = new uint256[](s.extendedLength);
        s.decimals = new uint256[](s.extendedLength);
        s.isDepegs = new bool[](s.extendedLength);
        s.isDispersions = new bool[](s.extendedLength);
        s.isOracleOffs = new bool[](s.extendedLength);
        s.totalValueUSD = 0;
        s.priceUSDToken = 0;

    
        console.log("getAllocationsPrePostOperationRedeem() T1");

        for (uint256 i; i < length; i++) {
            s.token = _supportedAssets.at(i);
            (s.oraclePriceUSDs[i], s.isDepegs[i], s.isDispersions[i], s.isOracleOffs[i]) =
                getPriceAndCircuitBreakers(s.token);

            if (!isSoft && (s.isDepegs[i] || s.isDispersions[i] || s.isOracleOffs[i] || s.oraclePriceUSDs[i] == 0)) {
                // Return early with circuit breaker information
                ret.assetWithBreakerTriggered = s.token;
                ret.oraclePriceUSD = s.oraclePriceUSDs[i];
                ret.isDepeg = s.isDepegs[i];
                ret.isDispersion = s.isDispersions[i];
                ret.isOracleOff = s.isOracleOffs[i];
                return ret;
            }

            s.balances[i] = IERC20(s.token).balanceOf(address(this));
            s.decimals[i] = IERC20Metadata(s.token).decimals();
            console.log("i = ", i);
            console.log("s.balances[i] = ", s.balances[i]);
            if (s.balances[i] > 0) {
                s.totalValueUSD += Math.mulDiv(s.balances[i], s.oraclePriceUSDs[i], 10 ** s.decimals[i]);
            }
            if (s.token == token) {
                console.log("T11 s.token = ", s.token);
                s.priceUSDToken = s.oraclePriceUSDs[i];
                console.log("T11 s.priceUSDToken = ", s.priceUSDToken);
                ret.tokenFound = true;
            }

            if (i == s.extendedLength - 1) {
                // Assign critical info to re-assure no breaker triggered
                ret.assetWithBreakerTriggered = s.token;
                ret.oraclePriceUSD = s.oraclePriceUSDs[i];
                ret.isDepeg = s.isDepegs[i];
                ret.isDispersion = s.isDispersions[i];
                ret.isOracleOff = s.isOracleOffs[i];
            }
        }

        console.log("getAllocationsPrePostOperationRedeem() T3");

        if(s.extendedLength > length) {
            s.token = token;
            (s.oraclePriceUSDs[length], s.isDepegs[length], s.isDispersions[length], s.isOracleOffs[length]) =
                getPriceAndCircuitBreakers(token);
            s.balances[length] = IERC20(token).balanceOf(address(this));
            s.decimals[length] = IERC20Metadata(token).decimals();
            if (s.balances[length] > 0) {
                s.totalValueUSD += Math.mulDiv(s.balances[length], s.oraclePriceUSDs[length], 10 ** s.decimals[length]);
            }
            if (s.token == token) {
                s.priceUSDToken = s.oraclePriceUSDs[length];
                ret.tokenFound = true;
            }
        }

        // Initialize the arrays in the return struct
        ret.absoluteAllocationPreOperation = new uint256[](s.extendedLength);
        ret.absoluteAllocationPostOperation = new uint256[](s.extendedLength);
        ret.absoluteTargetAllocation = new uint256[](s.extendedLength);
        ret.vaultWeights = new uint256[](s.extendedLength);

        uint256 totalSupply_ = totalSupply();
        // PPS = Total Value in USD / Total Supply, normalized to PRECISION
        if (totalSupply_ == 0) {
            s.superAssetPPS = PRECISION;
        } else {
            s.superAssetPPS = Math.mulDiv(s.totalValueUSD, PRECISION, totalSupply_);
        }
        console.log("getAllocationsPrePostOperationRedeem() T5");
        console.log("s.priceUSDToken = ", s.priceUSDToken);
        ret.amountAssets = Math.mulDiv(amountToken, s.superAssetPPS, s.priceUSDToken);

        s.decimalsToken = IERC20Metadata(token).decimals();
        console.log("getAllocationsPrePostOperationRedeem() T6");

        // Adjust for decimals
        if (s.decimalsToken < DECIMALS) {
            ret.amountAssets = Math.mulDiv(ret.amountAssets, 10 ** (DECIMALS - s.decimalsToken), PRECISION);
        } else if (s.decimalsToken > DECIMALS) {
            ret.amountAssets = Math.mulDiv(ret.amountAssets, 10 ** (s.decimalsToken - DECIMALS), PRECISION);
        }
        console.log("getAllocationsPrePostOperationRedeem() T7");

        s.balanceOfDeltaToken = IERC20(token).balanceOf(address(this));
        if (ret.amountAssets > s.balanceOfDeltaToken) {
            // NOTE: Since we do not want this function to revert, we re-set the amount out to the max possible amount
            // out which is the balance of this token
            // NOTE: This should be OK since the user can control the min amount out they desire with the slippage
            // protection
            s.deltaToken = s.balanceOfDeltaToken;
        } else {
            s.deltaToken = ret.amountAssets;
        }

        console.log("getAllocationsPrePostOperationRedeem() T11");

        for (uint256 i; i < length; i++) {
            s.token = _supportedAssets.at(i);
            // Convert balance to USD value using price
            ret.absoluteAllocationPreOperation[i] =
                Math.mulDiv(s.balances[i], s.oraclePriceUSDs[i], 10 ** s.decimals[i]);
            ret.totalAllocationPreOperation += ret.absoluteAllocationPreOperation[i];
            ret.absoluteAllocationPostOperation[i] = ret.absoluteAllocationPreOperation[i];
            if (s.token == token) {
                s.absDeltaValue = Math.mulDiv(s.deltaToken, s.oraclePriceUSDs[i], 10 ** s.decimals[i]);
                s.deltaValue = -int256(s.absDeltaValue);
                ret.absoluteAllocationPostOperation[i] =
                    uint256(int256(ret.absoluteAllocationPreOperation[i]) + s.deltaValue);
            }
            ret.totalAllocationPostOperation += ret.absoluteAllocationPostOperation[i];
            ret.absoluteTargetAllocation[i] = tokenData[s.token].targetAllocations;
            ret.totalTargetAllocation += ret.absoluteTargetAllocation[i];
            ret.vaultWeights[i] = tokenData[s.token].weights;
        }

        console.log("getAllocationsPrePostOperationRedeem() T12");
        
        if(s.extendedLength > length) {
            uint256 i = length;
            s.token = token;
            ret.absoluteAllocationPreOperation[i] =
                Math.mulDiv(s.balances[i], s.oraclePriceUSDs[i], 10 ** s.decimals[i]);
            ret.totalAllocationPreOperation += ret.absoluteAllocationPreOperation[i];
            ret.absoluteAllocationPostOperation[i] = ret.absoluteAllocationPreOperation[i];
            if (s.token == token) {
                s.absDeltaValue = Math.mulDiv(s.deltaToken, s.oraclePriceUSDs[i], 10 ** s.decimals[i]);
                s.deltaValue = -int256(s.absDeltaValue);
                ret.absoluteAllocationPostOperation[i] =
                    uint256(int256(ret.absoluteAllocationPreOperation[i]) + s.deltaValue);
            }
            ret.totalAllocationPostOperation += ret.absoluteAllocationPostOperation[i];
            ret.absoluteTargetAllocation[i] = tokenData[s.token].targetAllocations;
            ret.totalTargetAllocation += ret.absoluteTargetAllocation[i];
            ret.vaultWeights[i] = tokenData[s.token].weights;
        }
    }

    /// @inheritdoc ISuperAsset
    function getPrimaryAsset() external view returns (address) {
        return primaryAsset;
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

    // --- Modifiers ---
    function _onlyStrategist() internal view {
        if (msg.sender != factory.getSuperAssetStrategist(address(this))) revert UNAUTHORIZED();
    }

    function _onlyManager() internal view {
        if (msg.sender != factory.getSuperAssetManager(address(this))) revert UNAUTHORIZED();
    }
}