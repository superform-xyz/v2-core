// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { FluidYieldSourceOracleLibrary } from "../../libraries/accounting/FluidYieldSourceOracleLibrary.sol";

/// @title FluidYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Fluid yield source
contract FluidYieldSourceOracle is IYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() { }

    /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view returns (uint256 price) {
        price = FluidYieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultiple(
        address[] memory yieldSourceAddresses,
        address underlyingAsset
    )
        external
        view
        returns (uint256[] memory prices)
    {
        prices = FluidYieldSourceOracleLibrary.getPricePerShareMultiple(yieldSourceAddresses, underlyingAsset);
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
