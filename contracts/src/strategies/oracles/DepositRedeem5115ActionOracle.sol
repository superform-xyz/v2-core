// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { DepositRedeem5115Library } from "../../libraries/strategies/DepositRedeem5115Library.sol";

/// @title DepositRedeem5115ActionOracle
/// @author Superform Labs
/// @notice Oracle for the Deposit and Redeem Action in 5115 Vaults
contract DepositRedeem5115ActionOracle {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() { }

    /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the price per share for a deposit into a 5115 vault
    /// @param asset The address of the asset
    /// @param finalTarget The address of the final target
    /// @return price The price per share
    function getStrategyPrice(address asset, address finalTarget) external view returns (uint256 price) {
        price = DepositRedeem5115Library.getPricePerShare(asset, finalTarget);
    }

    /// @notice Get the price per share for a deposit into multiple 5115 vaults
    /// @param assets The addresses of the assets
    /// @param finalTargets The addresses of the final targets
    /// @return prices The price per share per final target
    function getStrategyPrices(
        address[] memory assets,
        address[] memory finalTargets
    )
        external
        view
        returns (uint256[] memory prices)
    {
        prices = DepositRedeem5115Library.getPricePerShareMultiple(finalTargets, assets);
    }

    // ToDo: Implement this with the metadata library
    /// @notice Get the metadata for a 5115 vault
    /// @return metadata The metadata
    function getVaultStrategyMetadata(address) external pure returns (bytes memory metadata) {
        return "0x0";
    }

    // ToDo: Implement this with the metadata library
    /// @notice Get the metadata for multiple 5115 vaults
    /// @return metadata The metadata per final target
    function getVaultsStrategyMetadata(address[] memory finalTargets) external pure returns (bytes[] memory metadata) {
        return new bytes[](finalTargets.length);
    }
}
