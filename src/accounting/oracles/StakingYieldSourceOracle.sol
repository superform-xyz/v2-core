// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title StakingYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Staking Yield Sources
contract StakingYieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address) external pure override returns (uint8) {
        return 18;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address) public pure override returns (uint256) {
        return 1e18;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) {
        return assetsIn;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getAssetOutput(address, address, uint256 sharesIn) public pure override returns (uint256) {
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
        return IERC20(yieldSourceAddress).balanceOf(ownerOfShares);
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
        return IERC20(yieldSourceAddress).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return IERC20(yieldSourceAddress).totalSupply();
    }


}
