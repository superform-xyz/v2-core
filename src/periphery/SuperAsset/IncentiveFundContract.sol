// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IIncentiveFundContract } from "../interfaces/SuperAsset/IIncentiveFundContract.sol";
import { IIncentiveCalculationContract } from "../interfaces/SuperAsset/IIncentiveCalculationContract.sol";
import { ISuperAsset } from "../interfaces/SuperAsset/ISuperAsset.sol";
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperAssetFactory } from "../interfaces/SuperAsset/ISuperAssetFactory.sol";

/// @title Incentive Fund Contract
/// @author Superform Labs
/// @notice Manages incentive tokens in the SuperAsset system
/// @dev This contract is responsible for handling the incentive fund, including paying and taking incentives.
/// @dev For now it is OK to keep Access Control but it will be managed by SuperGovernor when ready, see
/// https://github.com/superform-xyz/v2-contracts/pull/377#discussion_r2058893391
contract IncentiveFundContract is IIncentiveFundContract {
    using SafeERC20 for IERC20;

    // --- State Variables ---
    address public tokenInIncentive;
    address public tokenOutIncentive;
    ISuperAsset public superAsset;
    ISuperGovernor public _SUPER_GOVERNOR;
    ISuperAssetFactory public _SUPER_ASSET_FACTORY;

    // Timelock
    uint256 public constant setTokenTimelock = 7 days;
    address public proposedTokenIn;
    uint256 public newTokenInEffectiveTime;
    address public proposedTokenOut;
    uint256 public newTokenOutEffectiveTime;

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
        _SUPER_GOVERNOR = ISuperGovernor(_superGovernor);

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
    function proposeSetTokenInIncentive(address token) external {
        ISuperAssetFactory factory =
            ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_GOVERNOR.SUPER_ASSET_FACTORY()));
        address manager = factory.getIncentiveFundManager(address(superAsset));
        if (manager != msg.sender) revert UNAUTHORIZED();
        // Allowing to deselect token
        // if (token == address(0)) revert ZERO_ADDRESS();
        proposedTokenIn = token;
        newTokenInEffectiveTime = block.timestamp + setTokenTimelock;
    }

    /// @inheritdoc IIncentiveFundContract
    function executeSetTokenInIncentive() external {
        if (proposedTokenIn == address(0)) revert NO_PENDING_CHANGE();
        if (block.timestamp < newTokenInEffectiveTime) revert TIMELOCK_NOT_EXPIRED();
        tokenInIncentive = proposedTokenIn;
        proposedTokenIn = address(0);
        emit SettlementTokenInSet(tokenInIncentive);
    }

    /// @inheritdoc IIncentiveFundContract
    function proposeSetTokenOutIncentive(address token) external {
        ISuperAssetFactory factory =
            ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_GOVERNOR.SUPER_ASSET_FACTORY()));
        address manager = factory.getIncentiveFundManager(address(superAsset));
        if (manager != msg.sender) revert UNAUTHORIZED();
        // Allowing to deselect token
        // if (token == address(0)) revert ZERO_ADDRESS();
        proposedTokenOut = token;
        newTokenOutEffectiveTime = block.timestamp + setTokenTimelock;
    }

    /// @inheritdoc IIncentiveFundContract
    function executeSetTokenOutIncentive() external {
        if (proposedTokenOut == address(0)) revert NO_PENDING_CHANGE();
        if (block.timestamp < newTokenOutEffectiveTime) revert TIMELOCK_NOT_EXPIRED();
        tokenOutIncentive = proposedTokenOut;
        proposedTokenOut = address(0);
        emit SettlementTokenOutSet(tokenOutIncentive);
    }

    /// @inheritdoc IIncentiveFundContract
    function payIncentive(address receiver, uint256 amountUSD) external returns (uint256 amountToken) {
        ISuperAssetFactory factory =
            ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_GOVERNOR.SUPER_ASSET_FACTORY()));
        address manager = factory.getIncentiveFundManager(address(superAsset));
        if (manager != msg.sender) revert UNAUTHORIZED();
        _validateInput(receiver, amountUSD);
        // NOTE: In case the tokenOut is not set, no incentive is paid
        if (tokenOutIncentive != address(0)) {
            // Get token price and check circuit breakers
            (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff) =
                superAsset.getPriceWithCircuitBreakers(tokenOutIncentive);

            // Revert if any circuit breaker is triggered
            // Question: do we want to revert if circuit breaker is triggered?
            if (isDepeg || isDispersion || isOracleOff) revert CIRCUIT_BREAKER_TRIGGERED();
            if (priceUSD == 0) revert PRICE_USD_ZERO();

            // Convert USD amount to token amount using price
            // amountToken = amountUSD / priceUSD
            uint256 amountTokenDesired = Math.mulDiv(amountUSD, superAsset.getPrecision(), priceUSD);
            // NOTE: Pay incentives as long as there is money available for it
            amountToken = amountTokenDesired <= IERC20(tokenOutIncentive).balanceOf(address(this))
                ? amountTokenDesired
                : IERC20(tokenOutIncentive).balanceOf(address(this));

            if (amountToken > 0) IERC20(tokenOutIncentive).safeTransfer(receiver, amountToken);
        }

        emit IncentivePaid(receiver, tokenOutIncentive, amountToken);
    }

    /// @inheritdoc IIncentiveFundContract
    function takeIncentive(address sender, uint256 amountUSD) external returns (uint256 amountToken) {
        ISuperAssetFactory factory =
            ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_GOVERNOR.SUPER_ASSET_FACTORY()));
        address manager = factory.getIncentiveFundManager(address(superAsset));
        if (manager != msg.sender) revert UNAUTHORIZED();
        _validateInput(sender, amountUSD);
        if (tokenInIncentive != address(0)) {
            // Get token price and check circuit breakers
            (uint256 priceUSD, bool isDepeg, bool isDispersion, bool isOracleOff) =
                superAsset.getPriceWithCircuitBreakers(tokenInIncentive);

            // Revert if any circuit breaker is triggered
            // Question: do we want to revert if circuit breaker is triggered?
            if (isDepeg || isDispersion || isOracleOff) revert CIRCUIT_BREAKER_TRIGGERED();
            if (priceUSD == 0) revert PRICE_USD_ZERO();

            // Convert USD amount to token amount using price
            // amountToken = amountUSD / priceUSD
            amountToken = Math.mulDiv(amountUSD, superAsset.getPrecision(), priceUSD);

            if (amountToken > 0) IERC20(tokenInIncentive).safeTransferFrom(sender, address(this), amountToken);
        }
        emit IncentiveTaken(sender, tokenInIncentive, amountToken);
    }

    /// @inheritdoc IIncentiveFundContract
    function withdraw(address receiver, address tokenOut, uint256 amount) external {
        ISuperAssetFactory factory =
            ISuperAssetFactory(_SUPER_GOVERNOR.getAddress(_SUPER_GOVERNOR.SUPER_ASSET_FACTORY()));
        address manager = factory.getIncentiveFundManager(address(superAsset));
        if (manager != msg.sender) revert UNAUTHORIZED();
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
