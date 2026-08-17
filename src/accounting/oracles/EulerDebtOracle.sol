// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// euler vendor
import { IEVault } from "../../vendor/euler/IEVault.sol";

// superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";

/// @title EulerDebtOracle
/// @author Superform Labs
/// @notice Oracle for Euler V2 debt positions (borrow side)
/// @dev Uses identity mapping (PPS = 1:1) since Euler V2's debtOf() returns accrued debt directly in asset units.
///      The yieldSourceAddress parameter is the controller EVault (the vault the account borrowed from).
///      Interest auto-accrues in debtOf() and totalBorrows() — no manual accrual logic needed.
contract EulerDebtOracle is AbstractYieldSourceOracle {
    constructor(address superLedgerConfiguration_) AbstractYieldSourceOracle(superLedgerConfiguration_) { }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        return IEVault(yieldSourceAddress).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        return 10 ** uint256(IEVault(yieldSourceAddress).decimals());
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) {
        return assetsIn;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getWithdrawalShareOutput(address, address, uint256 assetsIn) external pure override returns (uint256) {
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
        return IEVault(yieldSourceAddress).debtOf(ownerOfShares);
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
        return IEVault(yieldSourceAddress).debtOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return IEVault(yieldSourceAddress).totalBorrows();
    }
}
