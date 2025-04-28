// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IncentiveCalculationContract.sol";
import "./interfaces/IIncentiveFundContract.sol";
import "./interfaces/IIncentiveFundErrors.sol";

/**
 * @title Incentive Fund Contract
 * @notice Manages incentive tokens in the SuperAsset system
 * @dev This contract is responsible for handling the incentive fund, including paying and taking incentives.
 * @dev For now it is OK to keep Access Control but it will be managed by SuperGovernor when ready, see
 * https://github.com/superform-xyz/v2-contracts/pull/377#discussion_r2058893391
 */
contract IncentiveFundContract is AccessControl, IIncentiveFundContract, IIncentiveFundErrors {
    using SafeERC20 for IERC20;

    // --- Roles ---
    bytes32 public constant override INCENTIVE_FUND_MANAGER = keccak256("INCENTIVE_FUND_MANAGER");

    // --- State ---
    address public override tokenInIncentive;  // The token users send incentives to
    address public override tokenOutIncentive; // The token we pay incentives with

    // --- Events ---
    event IncentivePaid(address receiver, address tokenOut, uint256 amount);
    event IncentiveTaken(address sender, address tokenIn, uint256 amount);
    event RebalanceWithdrawal(address receiver, address tokenOut, uint256 amount);
    event SettlementTokenInSet(address token);
    event SettlementTokenOutSet(address token);

    // --- Constructor ---
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(INCENTIVE_FUND_MANAGER, msg.sender);
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
        uint256 amount
    ) external override onlyRole(INCENTIVE_FUND_MANAGER) {
        _validateInput(receiver, amount);
        if (tokenOutIncentive == address(0)) revert TOKEN_NOT_CONFIGURED();

        IERC20(tokenOutIncentive).safeTransfer(receiver, amount);
        emit IncentivePaid(receiver, tokenOutIncentive, amount);
    }

    /**
     * @inheritdoc IIncentiveFundContract
     */
    function takeIncentive(
        address sender,
        uint256 amount
    ) external override onlyRole(INCENTIVE_FUND_MANAGER) {
        _validateInput(sender, amount);
        if (tokenInIncentive == address(0)) revert TOKEN_NOT_CONFIGURED();

        IERC20(tokenInIncentive).safeTransferFrom(sender, address(this), amount);
        emit IncentiveTaken(sender, tokenInIncentive, amount);
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

    /**
     * @inheritdoc IIncentiveFundContract
     */
    function setSettlementTokenIn(
        address token
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZERO_ADDRESS();
        tokenInIncentive = token;
        emit SettlementTokenInSet(token);
    }

    /**
     * @inheritdoc IIncentiveFundContract
     */
    function setSettlementTokenOut(
        address token
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZERO_ADDRESS();
        tokenOutIncentive = token;
        emit SettlementTokenOutSet(token);
    }
}
