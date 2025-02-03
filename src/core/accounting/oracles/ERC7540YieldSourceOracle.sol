// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ERC7540YieldSourceOracleLibrary } from "../../libraries/accounting/ERC7540YieldSourceOracleLibrary.sol";

import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";

/// @title ERC7540YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for synchronous deposit and redeem 7540 Vaults
contract ERC7540YieldSourceOracle is IYieldSourceOracle {
    /// @inheritdoc IYieldSourceOracle
    function getTVL(address yieldSourceAddress, address ownerOfShares) public view returns (uint256 tvl) {
        tvl = ERC7540YieldSourceOracleLibrary.getTVL(yieldSourceAddress, ownerOfShares);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) external view returns (uint256 price) {
        price = ERC7540YieldSourceOracleLibrary.getPricePerShare(yieldSourceAddress);
    }

    /// @inheritdoc IYieldSourceOracle
    function getPricePerShareMultiple(address[] memory yieldSourceAddresses)
        external
        view
        returns (uint256[] memory prices)
    {
        prices = ERC7540YieldSourceOracleLibrary.getPricePerShareMultiple(yieldSourceAddresses);
    }
}
