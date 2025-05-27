// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import { IIncentiveFundContract } from "../interfaces/SuperAsset/IIncentiveFundContract.sol";
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperAsset } from "../interfaces/SuperAsset/ISuperAsset.sol";
import { ISuperAssetFactory } from "../interfaces/SuperAsset/ISuperAssetFactory.sol";

/**
 * @title Incentive Fund Contract
 * @author Superform Labs
 * @notice Manages incentive tokens in the SuperAsset system
 * @dev This contract is responsible for handling the incentive fund, including paying and taking incentives.
 * @dev For now it is OK to keep Access Control but it will be managed by SuperGovernor when ready, see
 * https://github.com/superform-xyz/v2-contracts/pull/377#discussion_r2058893391
 */
contract IncentiveFundContract is IIncentiveFundContract {
    using SafeERC20 for IERC20;

    // --- State Variables ---
    address public tokenInIncentive;
    address public tokenOutIncentive;
    ISuperAsset public superAsset;
    ISuperGovernor public superGovernor;
    bool public incentivesEnabled;

    // --- Modifiers ---
    modifier onlyManager() {
        ISuperAssetFactory factory = ISuperAssetFactory(superGovernor.getAddress(superGovernor.SUPER_ASSET_FACTORY()));
        address manager = factory.getIncentiveFundManager(address(superAsset));
        if (msg.sender != manager) revert UNAUTHORIZED();
        _;
    }

    /// @inheritdoc IIncentiveFundContract
    function initialize(
        address _superGovernor,
        address superAsset_,
        address tokenInIncentive_,
        address tokenOutIncentive_
    )
        external
    {
        if (_superGovernor == address(0)) revert ZERO_ADDRESS();
        superGovernor = ISuperGovernor(_superGovernor);

        // Ensure this can only be called once
        if (address(superAsset) != address(0)) revert ALREADY_INITIALIZED();

        if (superAsset_ == address(0)) revert ZERO_ADDRESS();
        if (tokenInIncentive_ == address(0)) revert ZERO_ADDRESS();
        if (tokenOutIncentive_ == address(0)) revert ZERO_ADDRESS();

        superAsset = ISuperAsset(superAsset_);
        tokenInIncentive = tokenInIncentive_;
        tokenOutIncentive = tokenOutIncentive_;
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IIncentiveFundContract
    function setTokenInIncentive(address token) external onlyManager {
        if (token == address(0)) revert ZERO_ADDRESS();
        address[] memory incentiveTokens = superGovernor.getWhitelistedIncentiveTokens();

        bool isWhitelisted = false;
        for (uint256 i; i < incentiveTokens.length; i++) {
            if (incentiveTokens[i] == token) {
                isWhitelisted = true;
                break;
            }
        }

        if (isWhitelisted) {
            tokenInIncentive = token;
        } else {
            revert TOKEN_NOT_WHITELISTED();
        }

        emit SettlementTokenInSet(token);
    }

    /// @inheritdoc IIncentiveFundContract
    function setTokenOutIncentive(address token) external onlyManager {
        if (token == address(0)) revert ZERO_ADDRESS();
        address[] memory incentiveTokens = superGovernor.getWhitelistedIncentiveTokens();

        bool isWhitelisted = false;
        for (uint256 i; i < incentiveTokens.length; i++) {
            if (incentiveTokens[i] == token) {
                isWhitelisted = true;
                break;
            }
        }

        if (isWhitelisted) {
            tokenOutIncentive = token;
        } else {
            revert TOKEN_NOT_WHITELISTED();
        }

        emit SettlementTokenInSet(token);
    }

    /// @inheritdoc IIncentiveFundContract
    function toggleIncentives(bool enabled) external onlyManager {
        incentivesEnabled = enabled;
        emit IncentivesToggled(enabled);
    }

    /// @inheritdoc IIncentiveFundContract
    function payIncentive(address receiver, uint256 amountUSD) external onlyManager returns (uint256 amountToken) {
        if (!incentivesEnabled) {
            return 0;
        }

        _validateInput(receiver, amountUSD);
        if (tokenOutIncentive == address(0)) revert TOKEN_OUT_NOT_SET();

        // Get token price and check circuit breakers
        (uint256 priceUSD,,,) = superAsset.getPriceWithCircuitBreakers(tokenOutIncentive);

        if (priceUSD > 0) {
            // Convert USD amount to token amount using price
            // amountToken = amountUSD / priceUSD
            amountToken = Math.mulDiv(amountUSD, IERC20Metadata(tokenInIncentive).decimals(), priceUSD);

            IERC20(tokenOutIncentive).safeTransfer(receiver, amountToken);
            emit IncentivePaid(receiver, tokenOutIncentive, amountToken);
        }

        emit IncentivePaid(receiver, tokenOutIncentive, 0);
        return 0;
    }

    /// @inheritdoc IIncentiveFundContract
    function takeIncentive(address sender, uint256 amountUSD) external onlyManager returns (uint256 amountToken) {
        if (!incentivesEnabled) {
            return 0;
        }

        _validateInput(sender, amountUSD);
        if (tokenInIncentive == address(0)) revert TOKEN_IN_NOT_SET();

        // Get token price and check circuit breakers
        (uint256 priceUSD,,,) = superAsset.getPriceWithCircuitBreakers(tokenInIncentive);

        if (priceUSD > 0) {
            // Convert USD amount to token amount using price
            // amountToken = amountUSD / priceUSD
            amountToken = Math.mulDiv(amountUSD, IERC20Metadata(tokenInIncentive).decimals(), priceUSD);

            IERC20(tokenInIncentive).safeTransferFrom(sender, address(this), amountToken);
            emit IncentiveTaken(sender, tokenInIncentive, amountToken);
        }

        emit IncentiveTaken(sender, tokenInIncentive, 0);
        return 0;
    }

    /// @inheritdoc IIncentiveFundContract
    function withdraw(address receiver, address tokenOut, uint256 amount) external onlyManager {
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
