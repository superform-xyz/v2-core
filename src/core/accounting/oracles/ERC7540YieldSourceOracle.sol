// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC7540} from "../../../vendor/vaults/7540/IERC7540.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import {AbstractYieldSourceOracle} from "./AbstractYieldSourceOracle.sol";

/// @title ERC7540YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for synchronous deposit and redeem 7540 Vaults
contract ERC7540YieldSourceOracle is AbstractYieldSourceOracle {
    constructor() AbstractYieldSourceOracle() {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        address share = IERC7540(yieldSourceAddress).share();
        return IERC20Metadata(share).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(address yieldSourceAddress, address, uint256 assetsIn)
        external
        view
        override
        returns (uint256)
    {
        return IERC7540(yieldSourceAddress).convertToShares(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getAssetOutput(address yieldSourceAddress, address, uint256 sharesIn)
        external
        view
        override
        returns (uint256)
    {
        return IERC7540(yieldSourceAddress).convertToAssets(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        address share = IERC7540(yieldSourceAddress).share();
        uint256 _decimals = IERC20Metadata(share).decimals();
        return IERC7540(yieldSourceAddress).convertToAssets(10 ** _decimals);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getBalanceOfOwner(address yieldSourceAddress, address ownerOfShares)
        public
        view
        override
        returns (uint256)
    {
        return IERC20(IERC7540(yieldSourceAddress).share()).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVLByOwnerOfShares(address yieldSourceAddress, address ownerOfShares)
        public
        view
        override
        returns (uint256)
    {
        uint256 shares = IERC20(IERC7540(yieldSourceAddress).share()).balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return IERC7540(yieldSourceAddress).convertToAssets(shares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return IERC7540(yieldSourceAddress).totalAssets();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function isValidUnderlyingAsset(address yieldSourceAddress, address expectedUnderlying)
        public
        view
        override
        returns (bool)
    {
        return IERC7540(yieldSourceAddress).asset() == expectedUnderlying;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function isValidUnderlyingAssets(address[] memory yieldSourceAddresses, address[] memory expectedUnderlying)
        external
        view
        override
        returns (bool[] memory isValid)
    {
        uint256 length = yieldSourceAddresses.length;
        if (length != expectedUnderlying.length) revert ARRAY_LENGTH_MISMATCH();

        isValid = new bool[](length);
        for (uint256 i; i < length; ++i) {
            isValid[i] = isValidUnderlyingAsset(yieldSourceAddresses[i], expectedUnderlying[i]);
        }
    }
}
