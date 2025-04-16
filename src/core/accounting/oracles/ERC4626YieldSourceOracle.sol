// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title ERC4626YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for 4626 Vaults
contract ERC4626YieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address _oracle) AbstractYieldSourceOracle(_oracle) { }

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        return IERC4626(yieldSourceAddress).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        return IERC4626(yieldSourceAddress).previewDeposit(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getAssetOutput(
        address yieldSourceAddress,
        address,
        uint256 sharesIn
    )
        external
        view
        override
        returns (uint256)
    {
        return IERC4626(yieldSourceAddress).previewRedeem(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        IERC4626 yieldSource = IERC4626(yieldSourceAddress);
        uint256 _decimals = yieldSource.decimals();
        return yieldSource.convertToAssets(10 ** _decimals);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        return IERC4626(yieldSourceAddress).balanceOf(ownerOfShares);
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
        return IERC4626(yieldSourceAddress).totalAssets();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function _validateBaseAsset(address yieldSourceAddress, address base) internal view override {
        if (base != IERC4626(yieldSourceAddress).asset()) revert INVALID_BASE_ASSET();
    }
}
