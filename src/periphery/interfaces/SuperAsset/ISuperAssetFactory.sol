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
     * @param superAssetManager Address of the manager
     * @param superAssetStrategist Address of the strategist
     * @param incentiveFundManager Address of the incentive fund manager
     */
    struct AssetCreationParams {
        string name;
        string symbol;
        uint256 swapFeeInPercentage;
        uint256 swapFeeOutPercentage;
        address superAssetManager;
        address superAssetStrategist;
        address incentiveFundManager;
    }

    /**
     * @notice Sets roles for a SuperAsset
     * @param superAsset Address of the SuperAsset contract
     * @param superAssetStrategist Address of the strategist
     * @param superAssetManager Address of the manager
     * @param incentiveFundManager Address of the incentive fund manager
     */
    function setRoles(address superAsset, address superAssetStrategist, address superAssetManager, address incentiveFundManager) external;

    /**
     * @notice Gets roles for a SuperAsset
     * @param superAsset Address of the SuperAsset contract
     * @return superAssetStrategist Address of the strategist
     * @return superAssetManager Address of the manager
     * @return incentiveFundManager Address of the incentive fund manager
     */
    function getRoles(address superAsset) external view returns (address superAssetStrategist, address superAssetManager, address incentiveFundManager);

    /**
     * @notice Creates a new SuperAsset instance with its dependencies
     * @param params Parameters for creating the SuperAsset
     * @return superAsset Address of the deployed SuperAsset contract
     * @return incentiveFund Address of the deployed IncentiveFundContract
     */
    function createSuperAsset(AssetCreationParams calldata params) 
        external 
        returns (
            address superAsset,
            address incentiveFund
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

    // --- Errors ---
    // Factory errors
    error ZERO_ADDRESS();
}
