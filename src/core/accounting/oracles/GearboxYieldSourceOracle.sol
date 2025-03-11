// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IGearboxFarmingPool, Info } from "../../../vendor/gearbox/IGearboxFarmingPool.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title GearboxYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Gearbox Staking
contract GearboxYieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address _superRegistry) AbstractYieldSourceOracle(_superRegistry) { }

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        address rewardsToken = IGearboxFarmingPool(yieldSourceAddress).rewardsToken();
        return IERC20Metadata(rewardsToken).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        return _getRewardPerToken(yieldSourceAddress);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) {
        return assetsIn;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getAssetOutput(address, address, uint256 sharesIn) external pure override returns (uint256) {
        return sharesIn;
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
        return IGearboxFarmingPool(yieldSourceAddress).balanceOf(ownerOfShares);
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
        return IGearboxFarmingPool(yieldSourceAddress).balanceOf(ownerOfShares) * _getRewardPerToken(yieldSourceAddress);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        uint256 totalShares = IERC20Metadata(yieldSourceAddress).totalSupply();
        if (totalShares == 0) return 0;
        return totalShares * _getRewardPerToken(yieldSourceAddress);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function _validateBaseAsset(address yieldSourceAddress, address base) internal view override {
        if (base != IGearboxFarmingPool(yieldSourceAddress).stakingToken()) revert INVALID_BASE_ASSET();
    }

    function _getRewardPerToken(address yieldSourceAddress) internal view returns (uint256) {
        return uint256(IGearboxFarmingPool(yieldSourceAddress).farmInfo().reward);
    }
}
