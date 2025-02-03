// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { ERC4626YieldSourceOracleLibrary } from "../../libraries/accounting/ERC4626YieldSourceOracleLibrary.sol";

/// @title ERC4626YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for 4626 Vaults
contract ERC4626YieldSourceOracle is IYieldSourceOracle {
    /*//////////////////////////////////////////////////////////////
                           VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IYieldSourceOracle
    function getTVL(address yieldSourceAddress, address ownerOfShares) public view returns (uint256 tvl) {
        tvl = ERC4626YieldSourceOracleLibrary.getTVL(yieldSourceAddress, ownerOfShares);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view returns (uint256 price) {
        price = ERC4626YieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory prices)
    {
        prices = ERC4626YieldSourceOracleLibrary.getPricePerShareMultiple(yieldSourceAddresses);
    }
}
