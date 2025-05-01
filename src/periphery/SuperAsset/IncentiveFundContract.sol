// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/SuperAsset/IIncentiveFundContract.sol";
import "../interfaces/SuperAsset/IIncentiveCalculationContract.sol";
import "../interfaces/SuperAsset/ISuperAsset.sol";

/**
 * @author Superform Labs
 * @title Incentive Fund Contract
 * @notice Manages incentive tokens in the SuperAsset system
 * @dev This contract is responsible for handling the incentive fund, including paying and taking incentives.
 * @dev For now it is OK to keep Access Control but it will be managed by SuperGovernor when ready, see
 * https://github.com/superform-xyz/v2-contracts/pull/377#discussion_r2058893391
 */
contract IncentiveFundContract is IIncentiveFundContract, AccessControl {
    using SafeERC20 for IERC20;

    // --- Constants ---
    bytes32 public constant INCENTIVE_FUND_MANAGER = keccak256("INCENTIVE_FUND_MANAGER");

    // --- State Variables ---
    address public tokenInIncentive;
    address public tokenOutIncentive;
    ISuperAsset public superAsset;
    address public assetBank;

    // --- Constructor ---
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Initializes the IncentiveFundContract
     * @param superAsset_ Address of the SuperAsset contract
     * @param assetBank_ Address of the AssetBank contract
     */
    function initialize(address superAsset_, address assetBank_) external {
        // Ensure this can only be called once
        if (address(superAsset) != address(0)) revert ALREADY_INITIALIZED();

        if (superAsset_ == address(0)) revert ZERO_ADDRESS();
        if (assetBank_ == address(0)) revert ZERO_ADDRESS();

        superAsset = ISuperAsset(superAsset_);
        assetBank = assetBank_;
    }

    /*//////////////////////////////////////////////////////////////
                EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IIncentiveFundContract
    function setTokenInIncentive(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZERO_ADDRESS();
        tokenInIncentive = token;
        emit SettlementTokenInSet(token);
    }

    /// @inheritdoc IIncentiveFundContract
    function setTokenOutIncentive(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZERO_ADDRESS();
        tokenOutIncentive = token;
        emit SettlementTokenOutSet(token);
    }

    /// @inheritdoc IIncentiveFundContract
    function payIncentive(
        address receiver,
        uint256 amountUSD
    ) external onlyRole(INCENTIVE_FUND_MANAGER) {
        _validateInput(receiver, amountUSD);
        if (tokenOutIncentive == address(0)) revert TOKEN_NOT_CONFIGURED();

        // Get token price and check circuit breakers
        (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff) = 
            superAsset.getPriceWithCircuitBreakers(tokenOutIncentive);

        // Revert if any circuit breaker is triggered
        if (isDepeg || isDispersion || isOracleOff) revert CIRCUIT_BREAKER_TRIGGERED();
        if (priceUSD == 0) revert PRICE_USD_ZERO();

        // Convert USD amount to token amount using price
        // amountToken = amountUSD / priceUSD
        uint256 amountToken = Math.mulDiv(amountUSD, superAsset.getPrecision(), priceUSD);

        IERC20(tokenOutIncentive).safeTransfer(receiver, amountToken);
        emit IncentivePaid(receiver, tokenOutIncentive, amountToken);
    }

    /// @inheritdoc IIncentiveFundContract
    function takeIncentive(
        address sender,
        uint256 amountUSD
    ) external onlyRole(INCENTIVE_FUND_MANAGER) {
        _validateInput(sender, amountUSD);
        if (tokenInIncentive == address(0)) revert TOKEN_NOT_CONFIGURED();

        // Get token price and check circuit breakers
        (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff) = 
            superAsset.getPriceWithCircuitBreakers(tokenInIncentive);

        // Revert if any circuit breaker is triggered
        if (isDepeg || isDispersion || isOracleOff) revert CIRCUIT_BREAKER_TRIGGERED();
        if (priceUSD == 0) revert PRICE_USD_ZERO();

        // Convert USD amount to token amount using price
        // amountToken = amountUSD / priceUSD
        uint256 amountToken = Math.mulDiv(amountUSD, superAsset.getPrecision(), priceUSD);

        IERC20(tokenInIncentive).safeTransferFrom(sender, address(this), amountToken);
        emit IncentiveTaken(sender, tokenInIncentive, amountToken);
    }

    /// @inheritdoc IIncentiveFundContract
    function withdraw(
        address receiver,
        address tokenOut,
        uint256 amount
    ) external onlyRole(INCENTIVE_FUND_MANAGER) {
        _validateInput(receiver, amount);
        if (tokenOut == address(0)) revert ZERO_ADDRESS();

        IERC20(tokenOut).safeTransfer(receiver, amount);
        emit RebalanceWithdrawal(receiver, tokenOut, amount);
    }


    /*//////////////////////////////////////////////////////////////
                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _validateInput(address user, uint256 amount) internal pure {
        if (user == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();
    }
}
