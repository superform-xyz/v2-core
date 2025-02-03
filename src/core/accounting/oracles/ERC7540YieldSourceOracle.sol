// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { ERC7540YieldSourceOracleLibrary } from "../../libraries/accounting/ERC7540YieldSourceOracleLibrary.sol";

/// @title ERC7540YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for synchronous deposit and redeem 7540 Vaults
contract ERC7540YieldSourceOracle is IYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() { }

    /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the price per share for a deposit into a yield source
    /// @param yieldSourceAddress The address of the yield source
    /// @return price The price per share
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256 price) {
        price = ERC7540YieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress);
    }

    /// @notice Get the price per share for a deposit into multiple yield sources
    /// @param yieldSourceAddresses The addresses of the yield sources
    /// @param underlyingAsset The address of the underlying asset
    /// @return prices The price per share per yield source
    function getPricePerShareMultiple(
        address[] memory yieldSourceAddresses,
        address underlyingAsset
    )
        external
        view
        returns (uint256[] memory prices)
    {
        prices = ERC7540YieldSourceOracleLibrary.getPricePerShareMultiple(yieldSourceAddresses, underlyingAsset);
    }

    // ToDo: Implement this with the metadata library
    /// @inheritdoc IYieldSourceOracle
    function getYieldSourceMetadata(address) external pure returns (bytes memory metadata) {
        return "0x0";
    }

    // ToDo: Implement this with the metadata library
    /// @inheritdoc IYieldSourceOracle
    function getYieldSourceMetadata(address[] memory yieldSourceAddresses, bytes32[] memory) 
        external 
        pure 
        returns (bytes[] memory metadata) 
    {
        return new bytes[](yieldSourceAddresses.length);
    }   

    // ToDo: Implement this with the metadata library
    /// @inheritdoc IYieldSourceOracle
    function getYieldSourcesMetadata(address[] memory yieldSourceAddresses)
        external
        pure
        returns (bytes[] memory metadata)
    {
        return new bytes[](yieldSourceAddresses.length);
    }
}