// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { IAssetBank } from "../interfaces/SuperAsset/IAssetBank.sol";

/**
 * @author Superform Labs
 * @title AssetBank
 * @notice Manages asset holdings and withdrawals for the SuperAsset system
 */
contract AssetBank is AccessControl, IAssetBank {
    using SafeERC20 for IERC20;
    ISuperGovernor public immutable SUPER_GOVERNOR;

    // --- Roles ---
    bytes32 public constant INCENTIVE_FUND_MANAGER = keccak256("INCENTIVE_FUND_MANAGER");

    // --- Constructor ---
    constructor(address admin, address superGovernor) {
        if (admin == address(0) || superGovernor == address(0)) revert ZERO_ADDRESS();
        SUPER_GOVERNOR = ISuperGovernor(superGovernor);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(INCENTIVE_FUND_MANAGER, admin);
        // _grantRole(_SUPER_GOVERNOR_ROLE, superGovernor);
    }

    /// @inheritdoc IAssetBank
    function withdraw(
        address receiver,
        address tokenOut,
        uint256 amount
    )
        external
        override
        onlyRole(INCENTIVE_FUND_MANAGER)
    {
        if (receiver == address(0) || tokenOut == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();

        IERC20(tokenOut).safeTransfer(receiver, amount);
        emit RebalanceWithdrawal(receiver, tokenOut, amount);
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable { }
}
