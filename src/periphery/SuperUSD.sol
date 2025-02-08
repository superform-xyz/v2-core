// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ISuperUSD } from "./interfaces/ISuperUSD.sol";
import { ISuperVault } from "./interfaces/ISuperVault.sol";
import { ISuperOracle } from "../core/interfaces/accounting/ISuperOracle.sol";
import { IERC7575, IERC7575Share } from "./interfaces/IERC7575.sol";
import { IERC7540Vault, IERC7540Operator, IERC7540Deposit, IERC7540Redeem } from "./interfaces/IERC7540Vault.sol";

/// @title SuperUSD
/// @notice Stablecoin vault implementing ERC-7575 and ERC-7540
/// @author SuperForm Labs

/// @dev TODO: need to implement pipes to go from USDC to AUSD, etc. as is the deposit asset must go directly to the appropriate vault
/// @dev perhaps easiest to not have multiasset support at all, and just have a single asset vault (USDC) with pipes to go to the appropriate vault
contract SuperUSD is ERC20, ISuperUSD {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant REQUEST_ID = 0;
    uint256 private constant ONE_HUNDRED_PERCENT = 10_000;
    uint8 private constant NORMALIZED_DECIMALS = 18; // Use 18 decimals for maximum precision

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    // Core components
    ISuperOracle private immutable _oracle;
    address private immutable _manager;
    address private immutable _strategist;

    // Fee configuration
    FeeConfig private _feeConfig;

    // Asset management
    mapping(address asset => address vault) private _assetToVault;

    // Request tracking
    mapping(address => SuperUSDState) private _superUSDState;

    // Operator management
    mapping(address owner => mapping(address operator => bool)) private _isOperator;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address manager_,
        address strategist_,
        address oracle_,
        FeeConfig memory feeConfig_
    ) ERC20("SuperUSD", "sUSD") {
        if (manager_ == address(0)) revert INVALID_MANAGER();
        if (strategist_ == address(0)) revert INVALID_STRATEGIST();
        if (oracle_ == address(0)) revert INVALID_ORACLE();
        if (feeConfig_.feeBps > ONE_HUNDRED_PERCENT) revert INVALID_FEE();
        if (feeConfig_.recipient == address(0)) revert INVALID_FEE_RECIPIENT();

        _manager = manager_;
        _strategist = strategist_;
        _oracle = ISuperOracle(oracle_);
        _feeConfig = feeConfig_;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function oracle() external view returns (ISuperOracle) {
        return _oracle;
    }

    function manager() external view returns (address) {
        return _manager;
    }

    function strategist() external view returns (address) {
        return _strategist;
    }

    function assetToVault(address asset) external view returns (address) {
        return _assetToVault[asset];
    }

    function sharePricePoints(
        address account,
        uint256 index
    ) external view returns (uint256 shares, uint256 pricePerShare) {
        SharePricePoint storage point = _superUSDState[account].sharePricePoints[index];
        return (point.shares, point.pricePerShare);
    }

    function sharePricePointCursor(address account) external view returns (uint256) {
        return _superUSDState[account].sharePricePointCursor;
    }

    function isOperator(address owner, address operator) external view returns (bool) {
        return _isOperator[owner][operator];
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function addVault(address vault) external {
        if (msg.sender != _manager) revert UNAUTHORIZED();
        if (vault == address(0)) revert INVALID_VAULT();

        address asset = IERC4626(vault).asset();
        if (asset == address(0)) revert INVALID_ASSET();
        if (_assetToVault[asset] != address(0)) revert ASSET_ALREADY_SUPPORTED();

        _assetToVault[asset] = vault;
        emit VaultUpdate(asset, vault);
    }

    function removeVault(address vault) external {
        if (msg.sender != _manager) revert UNAUTHORIZED();
        if (vault == address(0)) revert INVALID_VAULT();

        address asset = IERC4626(vault).asset();
        if (_assetToVault[asset] != vault) revert ASSET_NOT_SUPPORTED();

        delete _assetToVault[asset];
        emit VaultUpdate(asset, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/REDEEM REQUESTS
    //////////////////////////////////////////////////////////////*/
    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256) {
        if (assets == 0) revert ZERO_AMOUNT();
        if (owner == address(0) || controller == address(0)) revert ZERO_ADDRESS();

        address asset = msg.sender;
        if (_assetToVault[asset] == address(0)) revert ASSET_NOT_SUPPORTED();
        if (_superUSDState[asset].pendingDepositRequest != 0) revert REQUEST_EXISTS();

        IERC20(asset).safeTransferFrom(owner, address(this), assets);
        _superUSDState[asset].pendingDepositRequest = assets;

        IERC20(asset).forceApprove(address(_assetToVault[asset]), assets);
        IERC7540Vault(address(_assetToVault[asset])).requestDeposit(assets, address(this), address(this));
        IERC20(asset).forceApprove(address(_assetToVault[asset]), 0);

        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    function cancelDeposit(address controller) external {
        if (msg.sender != controller && !_isOperator[controller][msg.sender]) revert INVALID_CONTROLLER();

        // Get assets from state
        uint256 assets = _superUSDState[msg.sender].pendingDepositRequest;
        if (assets == 0) revert REQUEST_NOT_FOUND();

        // Clear request
        delete _superUSDState[msg.sender].pendingDepositRequest;

        // Return assets to user
        IERC20(msg.sender).safeTransfer(controller, assets);

        emit DepositRequestCancelled(controller, msg.sender);
    }

    function requestRedeem(uint256 shares) external {
        if (shares == 0) revert INVALID_AMOUNT();
        if (_superUSDState[msg.sender].pendingRedeemRequest != 0) revert REQUEST_EXISTS();

        _transfer(msg.sender, address(this), shares);

        uint256 currentPricePerShare = _getSuperVaultPPS();
        _superUSDState[msg.sender].sharePricePoints.push(SharePricePoint({
            shares: shares,
            pricePerShare: currentPricePerShare
        }));

        _superUSDState[msg.sender].pendingRedeemRequest = shares;
        emit RedeemRequest(msg.sender, msg.sender, REQUEST_ID, msg.sender, shares);
    }

    function cancelRedeem(address controller) external {
        if (msg.sender != controller && !_isOperator[controller][msg.sender]) revert INVALID_CONTROLLER();

        uint256 shares = _superUSDState[msg.sender].pendingRedeemRequest;
        if (shares == 0) revert REQUEST_NOT_FOUND();

        // Clear request
        delete _superUSDState[msg.sender].pendingRedeemRequest;

        // Return shares to user
        _transfer(address(this), controller, shares);

        emit RedeemRequestCancelled(controller, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/REDEEM CLAIMS
    //////////////////////////////////////////////////////////////*/
    function deposit(uint256 assets, address receiver, address controller) external returns (uint256 shares) {
        if (msg.sender != controller && !_isOperator[controller][msg.sender]) revert INVALID_CONTROLLER();

        address asset = msg.sender;
        if (_assetToVault[asset] == address(0)) revert ASSET_NOT_SUPPORTED();

        uint256 maxMintAmount = _superUSDState[asset].maxMint;
        if (maxMintAmount == 0) revert REQUEST_NOT_FOUND();

        delete _superUSDState[asset].maxMint;
        _mint(receiver, maxMintAmount);

        emit Deposit(msg.sender, receiver, assets, maxMintAmount);
        return maxMintAmount;
    }

    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets) {
        if (msg.sender != controller && !_isOperator[controller][msg.sender]) revert INVALID_CONTROLLER();

        address asset = msg.sender;
        if (_assetToVault[asset] == address(0)) revert ASSET_NOT_SUPPORTED();

        uint256 maxWithdrawAmount = _superUSDState[asset].maxWithdraw;
        if (maxWithdrawAmount == 0) revert REQUEST_NOT_FOUND();

        delete _superUSDState[asset].maxWithdraw;
        _burn(address(this), shares);

        IERC20(asset).safeTransfer(receiver, maxWithdrawAmount);

        emit Withdraw(msg.sender, receiver, controller, maxWithdrawAmount, shares);
        return maxWithdrawAmount;
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function setOperator(address operator, bool approved) external returns (bool) {
        if (msg.sender == operator) revert UNAUTHORIZED();
        _isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC7575 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/
    function asset() external pure returns (address) {
        return address(0); // Multi-asset vault
    }

    function share() external view returns (address) {
        return address(this);
    }

    function vault(address asset) external view returns (address) {
        return _assetToVault[asset];
    }

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedeem(address owner) external view returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    function previewMint(uint256 shares) external view returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        revert NOT_IMPLEMENTED();
    }

    /*//////////////////////////////////////////////////////////////
                        CONVERSION FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function convertToShares(uint256 usdValue) public view returns (uint256 shares) {
        uint256 supply = totalSupply();
        if (supply == 0 || usdValue == 0) {
            return usdValue;
        }

        uint256 totalUsdValue = totalAssets();
        shares = usdValue.mulDiv(supply, totalUsdValue, Math.Rounding.Floor);
    }

    function convertToAssets(uint256 shares) public view returns (uint256 usdValue) {
        uint256 supply = totalSupply();
        if (supply == 0 || shares == 0) {
            return shares;
        }

        uint256 totalUsdValue = totalAssets();
        usdValue = shares.mulDiv(totalUsdValue, supply, Math.Rounding.Floor);
    }

    function totalAssets() public view returns (uint256 total) {
        address[] memory supportedAssets = _getSupportedAssets();
        for (uint256 i = 0; i < supportedAssets.length;) {
            address asset = supportedAssets[i];
            address vault = _assetToVault[asset];
            if (vault != address(0)) {
                uint256 vaultAssets = IERC4626(vault).totalAssets();
                if (vaultAssets > 0) {
                    total += _getUSDValue(asset, vaultAssets);
                }
            }
            unchecked { ++i; }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        FEE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function updateFeeConfig(uint256 feeBps, address recipient) external {
        if (msg.sender != _manager) revert UNAUTHORIZED();
        if (feeBps > ONE_HUNDRED_PERCENT) revert INVALID_FEE();
        if (recipient == address(0)) revert INVALID_FEE_RECIPIENT();

        _feeConfig = FeeConfig({ feeBps: feeBps, recipient: recipient });
        emit FeeConfigUpdated(feeBps, recipient);
    }

    function getFeeConfig() external view returns (FeeConfig memory) {
        return _feeConfig;
    }

    /*//////////////////////////////////////////////////////////////
                        STRATEGIST FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function fulfillDepositRequests(
        address[] calldata users
    ) external {
        if (msg.sender != _strategist) revert UNAUTHORIZED();
        uint256 usersLength = users.length;
        if (usersLength == 0) revert ZERO_LENGTH();

        uint256 currentPricePerShare = _getSuperVaultPPS();

        // Process each user's deposit request
        for (uint256 i; i < usersLength;) {
            address user = users[i];
            SuperUSDState storage state = _superUSDState[user];
            uint256 requestedAmount = state.pendingDepositRequest;
            if (requestedAmount == 0) revert REQUEST_NOT_FOUND();

            // Calculate shares at current price
            uint256 shares = requestedAmount.mulDiv(10 ** NORMALIZED_DECIMALS, currentPricePerShare);

            // Add share price point
            state.sharePricePoints.push(SharePricePoint({
                shares: shares,
                pricePerShare: currentPricePerShare
            }));

            // Move request to claimable state
            state.pendingDepositRequest = 0;
            state.maxMint += shares;

            // Mint shares to escrow
            _mint(address(this), shares);

            emit DepositRequest(user, user, REQUEST_ID, address(this), requestedAmount);
            unchecked { ++i; }
        }
    }

    function fulfillRedeemRequests(
        address[] calldata users
    ) external {
        if (msg.sender != _strategist) revert UNAUTHORIZED();
        uint256 usersLength = users.length;
        if (usersLength == 0) revert ZERO_LENGTH();

        uint256 currentPricePerShare = _getSuperVaultPPS();

        // Process each user's redeem request
        for (uint256 i; i < usersLength;) {
            address user = users[i];
            SuperUSDState storage state = _superUSDState[user];
            uint256 requestedShares = state.pendingRedeemRequest;
            if (requestedShares == 0) revert REQUEST_NOT_FOUND();

            // Calculate historical assets and process fees
            (uint256 finalAssets, uint256 lastConsumedIndex) = 
                _calculateHistoricalAssetsAndProcessFees(user, requestedShares, currentPricePerShare);

            // Update state
            state.sharePricePointCursor = lastConsumedIndex;
            state.pendingRedeemRequest = 0;
            state.maxWithdraw += finalAssets;

            emit RedeemRequest(user, user, REQUEST_ID, address(this), requestedShares);
            unchecked { ++i; }
        }
    }

    function matchRequests(
        address[] calldata redeemUsers,
        address[] calldata depositUsers
    ) external {
        if (msg.sender != _strategist) revert UNAUTHORIZED();
        uint256 redeemLength = redeemUsers.length;
        uint256 depositLength = depositUsers.length;
        if (redeemLength == 0 || depositLength == 0) revert ZERO_LENGTH();

        uint256 currentPricePerShare = _getSuperVaultPPS();
        uint256[] memory sharesUsedByRedeemer = new uint256[](redeemLength);

        // Process deposits first, matching with redeem requests
        for (uint256 i; i < depositLength;) {
            address depositor = depositUsers[i];
            SuperUSDState storage depositState = _superUSDState[depositor];
            uint256 depositAssets = depositState.pendingDepositRequest;
            if (depositAssets == 0) revert REQUEST_NOT_FOUND();

            // Calculate shares needed at current price
            uint256 sharesNeeded = depositAssets.mulDiv(10 ** NORMALIZED_DECIMALS, currentPricePerShare);
            uint256 remainingShares = sharesNeeded;

            // Try to fulfill with redeem requests
            for (uint256 j; j < redeemLength && remainingShares > 0;) {
                address redeemer = redeemUsers[j];
                SuperUSDState storage redeemState = _superUSDState[redeemer];
                uint256 redeemShares = redeemState.pendingRedeemRequest;
                if (redeemShares == 0) {
                    unchecked { ++j; }
                    continue;
                }

                // Calculate how many shares we can take from this redeemer
                uint256 sharesToUse = redeemShares > remainingShares ? remainingShares : redeemShares;

                // Update redeemer's state and accumulate shares used
                redeemState.pendingRedeemRequest -= sharesToUse;
                sharesUsedByRedeemer[j] += sharesToUse;

                remainingShares -= sharesToUse;
                unchecked { ++j; }
            }

            // Verify deposit was fully matched
            if (remainingShares > 0) revert INCOMPLETE_DEPOSIT_MATCH();

            // Add share price point for the deposit
            depositState.sharePricePoints.push(
                SharePricePoint({ shares: sharesNeeded, pricePerShare: currentPricePerShare })
            );

            // Clear deposit request and update state
            depositState.pendingDepositRequest = 0;
            depositState.maxMint += sharesNeeded;

            emit DepositRequest(depositor, depositor, REQUEST_ID, address(this), depositAssets);
            unchecked { ++i; }
        }

        // Process accumulated shares for redeemers
        for (uint256 i; i < redeemLength;) {
            uint256 sharesUsed = sharesUsedByRedeemer[i];
            if (sharesUsed > 0) {
                address redeemer = redeemUsers[i];
                SuperUSDState storage redeemState = _superUSDState[redeemer];

                // Calculate historical assets and process fees
                (uint256 finalAssets, uint256 lastConsumedIndex) = 
                    _calculateHistoricalAssetsAndProcessFees(redeemer, sharesUsed, currentPricePerShare);

                // Update state
                redeemState.sharePricePointCursor = lastConsumedIndex;
                redeemState.maxWithdraw += finalAssets;

                emit RedeemRequest(redeemer, redeemer, REQUEST_ID, address(this), sharesUsed);
            }
            unchecked { ++i; }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE SUPPORT
    //////////////////////////////////////////////////////////////*/
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC7575).interfaceId || 
               interfaceId == type(IERC7540Vault).interfaceId ||
               interfaceId == type(IERC7575Share).interfaceId ||
               interfaceId == type(IERC165).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getUSDValue(address asset, uint256 amount) internal view returns (uint256 usdValue) {
        if (amount == 0) return 0;
        return _oracle.getQuoteFromProvider(amount, asset, address(840), 0); // 840 is USD ISO code, use provider 0
    }

    function _getAssetAmount(address asset, uint256 usdValue) internal view returns (uint256 amount) {
        if (usdValue == 0) return 0;

        // Get decimals directly from the asset contract
        uint8 assetDecimals = ERC20(asset).decimals();
        uint256 oneUnit = 10 ** assetDecimals;
        uint256 pricePerUnit = _oracle.getQuoteFromProvider(oneUnit, asset, address(840), 0);
        amount = usdValue.mulDiv(oneUnit, pricePerUnit, Math.Rounding.Floor);
    }

    function _getSuperVaultPPS() internal view returns (uint256 pricePerShare) {
        uint256 totalSupplyAmount = totalSupply();

        if (totalSupplyAmount == 0) {
            // For first deposit, set initial PPS to 1 unit in normalized decimals
            pricePerShare = 10 ** NORMALIZED_DECIMALS;
        } else {
            // Calculate current PPS
            pricePerShare = totalAssets().mulDiv(10 ** NORMALIZED_DECIMALS, totalSupplyAmount);
        }
    }

    function _getSupportedAssets() internal view returns (address[] memory assets) {
        // Count supported assets first
        uint256 count;
        address[] memory tempAssets = new address[](100); // Reasonable max limit
        
        // Iterate through potential asset addresses
        for (uint256 i = 0; i < tempAssets.length && count < tempAssets.length;) {
            address asset = address(uint160(i + 1)); // Skip address(0)
            if (_assetToVault[asset] != address(0)) {
                tempAssets[count] = asset;
                unchecked { ++count; }
            }
            unchecked { ++i; }
        }

        // Create correctly sized array
        assets = new address[](count);
        for (uint256 i = 0; i < count;) {
            assets[i] = tempAssets[i];
            unchecked { ++i; }
        }
    }

    function _calculateAndTransferFee(uint256 currentAssets, uint256 historicalAssets) internal returns (uint256) {
        if (currentAssets > historicalAssets) {
            uint256 profit = currentAssets - historicalAssets;
            uint256 fee = profit.mulDiv(_feeConfig.feeBps, ONE_HUNDRED_PERCENT);
            currentAssets -= fee;

            // Transfer fee to recipient if non-zero
            if (fee > 0) {
                IERC20(address(this)).safeTransfer(_feeConfig.recipient, fee);
            }
        }
        return currentAssets;
    }

    function _calculateHistoricalAssetsAndProcessFees(
        address controller,
        uint256 requestedShares,
        uint256 currentPricePerShare
    )
        internal
        returns (uint256 finalAssets, uint256 lastConsumedIndex)
    {
        uint256 historicalAssets = 0;
        uint256 sharePricePointsLength = _superUSDState[controller].sharePricePoints.length;
        uint256 remainingShares = requestedShares;
        uint256 currentIndex = _superUSDState[controller].sharePricePointCursor;
        lastConsumedIndex = currentIndex;

        for (uint256 j = currentIndex; j < sharePricePointsLength && remainingShares > 0;) {
            SharePricePoint memory point = _superUSDState[controller].sharePricePoints[j];
            uint256 sharesFromPoint = point.shares > remainingShares ? remainingShares : point.shares;
            historicalAssets += sharesFromPoint.mulDiv(point.pricePerShare, 10 ** NORMALIZED_DECIMALS);

            if (sharesFromPoint == point.shares) {
                lastConsumedIndex = j + 1;
            } else if (sharesFromPoint < point.shares) {
                _superUSDState[controller].sharePricePoints[j].shares -= sharesFromPoint;
            }

            remainingShares -= sharesFromPoint;
            unchecked { ++j; }
        }

        // Calculate current value and process fees
        uint256 currentAssets = requestedShares.mulDiv(currentPricePerShare, 10 ** NORMALIZED_DECIMALS);
        finalAssets = _calculateAndTransferFee(currentAssets, historicalAssets);
        return (finalAssets, lastConsumedIndex);
    }
}
