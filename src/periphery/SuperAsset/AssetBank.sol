// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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
    ISuperGovernor public immutable _SUPER_GOVERNOR;

    // --- Constructor ---
    constructor(address superGovernor) {
        if (superGovernor == address(0)) revert ZERO_ADDRESS();
        _SUPER_GOVERNOR = ISuperGovernor(superGovernor);

    }

    /// @inheritdoc IAssetBank
    function SUPER_GOVERNOR() external view returns (address) {
        return address(_SUPER_GOVERNOR);
    }

    /// @inheritdoc IAssetBank
    function withdraw(
        address receiver,
        address tokenOut,
        uint256 amount
    )
        external
        override
        onlyRole(_SUPER_GOVERNOR.GUARDIAN_ROLE()) // TODO: Fix it with the right role
    {
        if (receiver == address(0) || tokenOut == address(0)) revert ZERO_ADDRESS();
        if (amount == 0) revert ZERO_AMOUNT();

        IERC20(tokenOut).safeTransfer(receiver, amount);
        emit RebalanceWithdrawal(receiver, tokenOut, amount);
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable { }
}
