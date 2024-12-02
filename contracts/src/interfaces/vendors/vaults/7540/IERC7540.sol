// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IERC7540 is IERC4626 {
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Request a deposit of assets
    /// @param assets The amount of assets to deposit
    /// @param operator The address of the operator
    function requestDeposit(uint256 assets, address operator) external;

    /// @notice Request a redeem of shares
    /// @param shares The amount of shares to redeem
    /// @param operator The address of the operator
    /// @param owner The address of the owner
    function requestRedeem(uint256 shares, address operator, address owner) external;
}
