// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IERC7540 } from "../../interfaces/vendors/vaults/7540/IERC7540.sol";

// Superform
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title ERC7540YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for synchronous deposit and redeem 7540 Vaults
contract ERC7540YieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address _superRegistry) AbstractYieldSourceOracle(_superRegistry) { }

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        address share = IERC7540(yieldSourceAddress).share();
        return IERC20Metadata(share).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address, address yieldSourceAddress) public view override returns (uint256 pricePerShare) {
        address share = IERC7540(yieldSourceAddress).share();
        uint256 _decimals = IERC20Metadata(share).decimals();
        pricePerShare = IERC7540(yieldSourceAddress).convertToAssets(10 ** _decimals);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress, address ownerOfShares) public view override returns (uint256 tvl) {
        uint256 shares = IERC7540(yieldSourceAddress).balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return IERC7540(yieldSourceAddress).convertToAssets(shares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function _validateBaseAsset(address yieldSourceAddress, address base) internal view override {
        if (base != IERC7540(yieldSourceAddress).asset()) revert INVALID_BASE_ASSET();
    }
}
