// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IActionOracle } from "../../interfaces/strategies/IActionOracle.sol";
import { DepositRedeem4626Library } from "../../libraries/strategies/DepositRedeem4626Library.sol";

/// @title DepositRedeem4626ActionOracle
/// @author Superform Labs
/// @notice Oracle for the Deposit and Redeem Action in 4626 Vaults
contract DepositRedeem4626ActionOracle is IActionOracle {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() { }

    /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IActionOracle
    function getStrategyPrice(address finalTarget) public view returns (uint256 price) {
        price = DepositRedeem4626Library.getPricePerShare(finalTarget);
    }

    /// @inheritdoc IActionOracle
    function getStrategyPrices(
        address[] memory finalTargets,
        address underlyingAsset
    )
        external
        view
        returns (uint256[] memory prices)
    {
        prices = DepositRedeem4626Library.getPricePerShareMultiple(finalTargets, underlyingAsset);
    }

    // ToDo: Implement this with the metadata library
    /// @inheritdoc IActionOracle
    function getVaultStrategyMetadata(address) external pure returns (bytes memory metadata) {
        return "0x0";
    }

    // ToDo: Implement this with the metadata library
    /// @inheritdoc IActionOracle
    function getVaultsStrategyMetadata(address[] memory finalTargets) external pure returns (bytes[] memory metadata) {
        return new bytes[](finalTargets.length);
    }
}
