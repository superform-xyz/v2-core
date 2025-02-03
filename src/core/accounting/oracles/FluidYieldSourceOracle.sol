// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { FluidYieldSourceOracleLibrary } from "../../libraries/accounting/FluidYieldSourceOracleLibrary.sol";

/// @title FluidYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Fluid yield source
contract FluidYieldSourceOracle is IYieldSourceOracle {
    /// @inheritdoc IYieldSourceOracle
    function getTVL(address yieldSourceAddress, address ownerOfShares) public view returns (uint256 tvl) {
        revert("Not implemented");
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view returns (uint256 price) {
        price = FluidYieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory prices)
    {
        prices = FluidYieldSourceOracleLibrary.getPricePerShareMultiple(yieldSourceAddresses);
    }
}
