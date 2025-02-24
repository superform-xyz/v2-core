// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IERC7540 } from "../../../vendor/vaults/7540/IERC7540.sol";

// Superform
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

    function getShareOutput(address yieldSourceAddress, address, uint256 assetsIn) external view override returns (uint256) {
        return IERC7540(yieldSourceAddress).convertToShares(assetsIn);  
    }

    function getAssetOutput(address yieldSourceAddress, address, uint256 sharesIn) external view override returns (uint256) {
        return IERC7540(yieldSourceAddress).convertToAssets(sharesIn);
    }
    
    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        address share = IERC7540(yieldSourceAddress).share();
        uint256 _decimals = IERC20Metadata(share).decimals();
        return IERC7540(yieldSourceAddress).convertToAssets(10 ** _decimals);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        uint256 shares = IERC7540(yieldSourceAddress).balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return IERC7540(yieldSourceAddress).convertToAssets(shares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        address share = IERC7540(yieldSourceAddress).share();
        uint256 totalShares = IERC20Metadata(share).totalSupply();
        if (totalShares == 0) return 0;
        return IERC7540(yieldSourceAddress).convertToAssets(totalShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function _validateBaseAsset(address yieldSourceAddress, address base) internal view override {
        if (base != IERC7540(yieldSourceAddress).asset()) revert INVALID_BASE_ASSET();
    }
}
