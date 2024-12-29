// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Looped4626DepositLibrary } from "../../libraries/strategies/Looped4626DepositLibrary.sol";

/// @title LoopedDeposit4626ActionOracle
/// @author Superform Labs
/// @notice Oracle for the Looped Deposit Action in 4626 Vaults
contract Looped4626DepositActionOracle {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() { }

    /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the price per share for a single vault over a number of loops
    /// @param finalTarget The address of the final target
    /// @param loops The number of loops
    /// @return price The price per share
    function getStrategyPrice(address finalTarget, uint256 loops) public view returns (uint256 price) {
        price = Looped4626DepositLibrary.getPricePerShare(finalTarget, loops);
    }

    /// @notice Get the price per share for a list of vaults over a number of loops
    /// @param finalTargets The addresses of the final targets
    /// @param loops The number of loops
    /// @return prices The prices per share
    function getStrategyPrices(
        address[] memory finalTargets,
        uint256[] memory loops
    )
        external
        view
        returns (uint256[] memory prices)
    {
        prices = new uint256[](finalTargets.length);
        for (uint256 i = 0; i < finalTargets.length; i++) {
            prices[i] = getStrategyPrice(finalTargets[i], loops[i]);
        }
    }

    // ToDo: Implement this with the metadata library
    /// @notice Get the metadata for a single vault
    /// @return metadata The metadata
    function getVaultStrategyMetadata(address) external pure returns (bytes memory metadata) {
        return "0x0";
    }

    // ToDo: Implement this with the metadata library
    /// @notice Get the metadata for a list of vaults
    /// @param finalTargets The addresses of the final targets
    /// @return metadata The metadata
    function getVaultsStrategyMetadata(address[] memory finalTargets) external pure returns (bytes[] memory metadata) {
        return new bytes[](finalTargets.length);
    }
}
