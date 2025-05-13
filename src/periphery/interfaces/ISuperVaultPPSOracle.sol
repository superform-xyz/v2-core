// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperVaultPPSOracle
/// @notice Interface for the contract providing the reference PPS calculation logic.
/// @author Superform Labs
interface ISuperVaultPPSOracle {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error OracleCalculationFailed();
    error VaultNotSupported();

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the reference Price Per Share (PPS) for a given SuperVault.
    /// @dev This function replicates the logic previously used on-chain to calculate totalAssets.
    /// It should be designed to be callable off-chain for simulation or potentially on-chain by an adjudicator during
    /// dispute resolution.
    /// The implementation should be modular to support different asset calculation strategies.
    /// @param vault The address of the SuperVault (or its strategy) to calculate the PPS for.
    /// @return pps The calculated reference PPS value, scaled by 1e18.
    function calculateReferencePPS(address vault) external view returns (uint256 pps);
}
