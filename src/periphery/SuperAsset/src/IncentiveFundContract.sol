// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IIncentiveFundContract.sol";
import "./interfaces/IIncentiveFundErrors.sol";
import "./IncentiveCalculationContract.sol";
import "./SuperAsset.sol";

/**
 * @title Incentive Fund Contract
 * @notice Manages incentive tokens in the SuperAsset system
 * @dev This contract is responsible for handling the incentive fund, including paying and taking incentives.
 * @dev For now it is OK to keep Access Control but it will be managed by SuperGovernor when ready, see
 * https://github.com/superform-xyz/v2-contracts/pull/377#discussion_r2058893391
 */
contract IncentiveFundContract is IIncentiveFundContract, IIncentiveFundErrors, AccessControl {
    using SafeERC20 for IERC20;

    // --- Constants ---
    bytes32 public constant INCENTIVE_FUND_MANAGER = keccak256("INCENTIVE_FUND_MANAGER");

    // --- State Variables ---
    address public override tokenInIncentive;
    address public override tokenOutIncentive;
    SuperAsset public superAsset;

    // --- Events ---
    event IncentivePaid(address indexed receiver, address indexed token, uint256 amount);
    event IncentiveTaken(address indexed sender, address indexed token, uint256 amount);
    event RebalanceWithdrawal(address receiver, address tokenOut, uint256 amount);
    event SettlementTokenInSet(address token);
    event SettlementTokenOutSet(address token);

    // --- Constructor ---
    constructor(address _superAsset) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(INCENTIVE_FUND_MANAGER, msg.sender);
        if (_superAsset == address(0)) revert ZERO_ADDRESS();
        superAsset = SuperAsset(_superAsset);
    }

    // --- External Functions ---
    function setTokenInIncentive(address token) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZERO_ADDRESS();
        tokenInIncentive = token;
        emit SettlementTokenInSet(token);
    }

    function setTokenOutIncentive(address token) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZERO_ADDRESS();
        tokenOutIncentive = token;
        emit SettlementTokenOutSet(token);
    }

    // --- Internal Functions ---
    function _validateInput(address user, uint256 amount) internal pure {
        if (user == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();
    }

    /**
     * @inheritdoc IIncentiveFundContract
     */
    function payIncentive(
        address receiver,
        uint256 amountUSD
    ) external override onlyRole(INCENTIVE_FUND_MANAGER) {
        _validateInput(receiver, amountUSD);
        if (tokenOutIncentive == address(0)) revert TOKEN_NOT_CONFIGURED();

        // Get token price and check circuit breakers
        (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff) = 
            superAsset.getPriceWithCircuitBreakers(tokenOutIncentive);

        // Revert if any circuit breaker is triggered
        if (isDepeg || isDispersion || isOracleOff) revert CIRCUIT_BREAKER_TRIGGERED();

        // Convert USD amount to token amount using price
        // amountToken = amountUSD / priceUSD
        uint256 amountToken = Math.mulDiv(amountUSD, superAsset.PRECISION(), priceUSD);

        IERC20(tokenOutIncentive).safeTransfer(receiver, amountToken);
        emit IncentivePaid(receiver, tokenOutIncentive, amountToken);
    }

    /**
     * @inheritdoc IIncentiveFundContract
     */
    function takeIncentive(
        address sender,
        uint256 amountUSD
    ) external override onlyRole(INCENTIVE_FUND_MANAGER) {
        _validateInput(sender, amountUSD);
        if (tokenInIncentive == address(0)) revert TOKEN_NOT_CONFIGURED();

        // Get token price and check circuit breakers
        (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff) = 
            superAsset.getPriceWithCircuitBreakers(tokenInIncentive);

        // Revert if any circuit breaker is triggered
        if (isDepeg || isDispersion || isOracleOff) revert CIRCUIT_BREAKER_TRIGGERED();

        // Convert USD amount to token amount using price
        // amountToken = amountUSD / priceUSD
        uint256 amountToken = Math.mulDiv(amountUSD, superAsset.PRECISION(), priceUSD);

        IERC20(tokenInIncentive).safeTransferFrom(sender, address(this), amountToken);
        emit IncentiveTaken(sender, tokenInIncentive, amountToken);
    }

    /**
     * @inheritdoc IIncentiveFundContract
     */
    function withdraw(
        address receiver,
        address tokenOut,
        uint256 amount
    ) external override onlyRole(INCENTIVE_FUND_MANAGER) {
        _validateInput(receiver, amount);
        if (tokenOut == address(0)) revert ZERO_ADDRESS();

        IERC20(tokenOut).safeTransfer(receiver, amount);
        emit RebalanceWithdrawal(receiver, tokenOut, amount);
    }
}
