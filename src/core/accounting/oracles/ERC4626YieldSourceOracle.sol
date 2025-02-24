// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title ERC4626YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for 4626 Vaults
contract ERC4626YieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address _superRegistry) AbstractYieldSourceOracle(_superRegistry) { }

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        return IERC4626(yieldSourceAddress).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(address yieldSourceAddress, uint256 assetsIn) external view override returns (uint256) {
        return IERC4626(yieldSourceAddress).convertToShares(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getAssetOutput(address yieldSourceAddress, uint256 sharesIn) external view override returns (uint256) {
        return IERC4626(yieldSourceAddress).convertToAssets(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        IERC4626 yieldSource = IERC4626(yieldSourceAddress);
        uint256 _decimals = yieldSource.decimals();
        return yieldSource.convertToAssets(10 ** _decimals);
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
        IERC4626 yieldSource = IERC4626(yieldSourceAddress);
        uint256 shares = yieldSource.balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return yieldSource.convertToAssets(shares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        IERC4626 yieldSource = IERC4626(yieldSourceAddress);
        uint256 totalShares = yieldSource.totalSupply();
        if (totalShares == 0) return 0;
        return yieldSource.convertToAssets(totalShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function _validateBaseAsset(address yieldSourceAddress, address base) internal view override {
        if (base != IERC4626(yieldSourceAddress).asset()) revert INVALID_BASE_ASSET();
    }
}
