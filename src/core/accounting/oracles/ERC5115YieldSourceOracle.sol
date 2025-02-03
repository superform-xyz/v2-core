// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ERC5115YieldSourceOracleLibrary } from "../../libraries/accounting/ERC5115YieldSourceOracleLibrary.sol";

import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";

/// @title ERC5115YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for 5115 Vaults
contract ERC5115YieldSourceOracle is IYieldSourceOracle {
    /// @inheritdoc IYieldSourceOracle
    function getTVL(address yieldSourceAddress, address ownerOfShares) external view returns (uint256 tvl) {
        tvl = ERC5115YieldSourceOracleLibrary.getTVL(yieldSourceAddress, ownerOfShares);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256 price) {
        price = ERC5115YieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory prices)
    {
        prices = ERC5115YieldSourceOracleLibrary.getPricePerShareMultiple(yieldSourceAddresses);
    }
}
