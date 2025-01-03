// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Looped4626DepositYieldSourceOracleLibrary } from
    "../../libraries/accounting/Looped4626DepositYieldSourceOracleLibrary.sol";

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

    /// @notice Get the price per share for a single yield source over a number of loops
    /// @param yieldSourceAddress The address of the yield source
    /// @param loops The number of loops
    /// @return price The price per share
    function getPricePerShare(address yieldSourceAddress, uint256 loops) public view returns (uint256 price) {
        price = Looped4626DepositYieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress, loops);
    }

    /// @notice Get the price per share for a list of vaults over a number of loops
    /// @param yieldSourceAddresses The addresses of the yield sources
    /// @param loops The number of loops
    /// @return prices The prices per share
    function getPricePerShareMultiple(
        address[] memory yieldSourceAddresses,
        uint256[] memory loops
    )
        external
        view
        returns (uint256[] memory prices)
    {
        prices = new uint256[](yieldSourceAddresses.length);
        uint256 length = yieldSourceAddresses.length;
        for (uint256 i; i < length;) {
            prices[i] = getPricePerShare(yieldSourceAddresses[i], loops[i]);
            unchecked {
                ++i;
            }
        }
    }

    // ToDo: Implement this with the metadata library
    /// @notice Get the metadata for a single yield source
    /// @return metadata The metadata
    function getYieldSourceMetadata(address) external pure returns (bytes memory metadata) {
        return "0x0";
    }

    // ToDo: Implement this with the metadata library
    /// @notice Get the metadata for a list of vaults
    /// @param yieldSourceAddresses The addresses of the final targets
    /// @return metadata The metadata
    function getVaultsStrategyMetadata(address[] memory yieldSourceAddresses)
        external
        pure
        returns (bytes[] memory metadata)
    {
        return new bytes[](yieldSourceAddresses.length);
    }
}
