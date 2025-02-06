// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { IStandardizedYield } from "../../interfaces/vendors/pendle/IStandardizedYield.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title ERC5115YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for 5115 Vaults
contract ERC5115YieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address _superRegistry) AbstractYieldSourceOracle(_superRegistry) { }

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address /*yieldSourceAddress*/ ) external pure override returns (uint8) {
        return 18;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256 pricePerShare) {
        // Get the exchange rate from the StandardizedYield contract
        // This represents how many assets (in 1e18) one SY token is worth
        pricePerShare = IStandardizedYield(yieldSourceAddress).exchangeRate();

        // Note: exchangeRate is already normalized to 1e18, so no additional scaling needed
        // If exchangeRate is 2e18, it means 1 SY token = 2 asset tokens
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress, address ownerOfShares) public view override returns (uint256 tvl) {
        IStandardizedYield yieldSource = IStandardizedYield(yieldSourceAddress);
        uint256 shares = yieldSource.balanceOf(ownerOfShares);
        if (shares == 0) return 0;
        return (shares * yieldSource.exchangeRate()) / 1e18;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function _validateBaseAsset(address yieldSourceAddress, address base) internal view override {
        address[] memory tokensIn = IStandardizedYield(yieldSourceAddress).getTokensOut();
        bool isValid = false;

        for (uint256 i = 0; i < tokensIn.length;) {
            if (tokensIn[i] == base) {
                isValid = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (!isValid) revert INVALID_BASE_ASSET();
    }
}
