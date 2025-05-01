// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ISuperAssetFactory
 * @notice Interface for the SuperAssetFactory contract which deploys SuperAsset and its dependencies
 */
interface ISuperAssetFactory {
    /**
     * @notice Parameters required for creating a new SuperAsset
     * @param name Name of the SuperAsset token
     * @param symbol Symbol of the SuperAsset token
     * @param swapFeeInPercentage Initial swap fee percentage for deposits
     * @param swapFeeOutPercentage Initial swap fee percentage for redemptions
     */
    struct AssetCreationParams {
        string name;
        string symbol;
        uint256 swapFeeInPercentage;
        uint256 swapFeeOutPercentage;
    }

    /**
     * @notice Creates a new SuperAsset instance with its dependencies
     * @param params Parameters for creating the SuperAsset
     * @return superAsset Address of the deployed SuperAsset contract
     * @return assetBank Address of the deployed AssetBank contract
     * @return incentiveFund Address of the deployed IncentiveFundContract
     * @return incentiveCalc Address of the deployed IncentiveCalculationContract
     */
    function createSuperAsset(AssetCreationParams calldata params) 
        external 
        returns (
            address superAsset,
            address assetBank,
            address incentiveFund,
            address incentiveCalc
        );

    // --- Events ---
    /**
     * @notice Emitted when a new SuperAsset and its dependencies are created
     * @param superAsset Address of the deployed SuperAsset contract
     * @param assetBank Address of the deployed AssetBank contract
     * @param incentiveFund Address of the deployed IncentiveFundContract
     * @param incentiveCalc Address of the deployed IncentiveCalculationContract
     * @param name Name of the SuperAsset token
     * @param symbol Symbol of the SuperAsset token
     */
    event SuperAssetCreated(
        address indexed superAsset,
        address indexed assetBank,
        address incentiveFund,
        address incentiveCalc,
        string name,
        string symbol
    );
}
