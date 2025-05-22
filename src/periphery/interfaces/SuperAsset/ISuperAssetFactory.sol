// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

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
     * @notice Data for a SuperAsset
     * @param superAssetStrategist Address of the strategist
     * @param superAssetManager Address of the manager
     * @param incentiveFundManager Address of the incentive fund manager
     */
    struct SuperAssetData {
        address superAssetStrategist;
        address superAssetManager;
        address incentiveFundManager;
        address incentiveCalculationContract;
    }

    /**
     * @notice Sets the manager for a SuperAsset
     * @param superAsset Address of the SuperAsset contract
     * @param _superAssetManager Address of the manager
     */
    function setSuperAssetManager(address superAsset, address _superAssetManager) external;

    /**
     * @notice Sets the strategist for a SuperAsset
     * @param superAsset Address of the SuperAsset contract
     * @param _superAssetStrategist Address of the strategist
     */
    function setSuperAssetStrategist(address superAsset, address _superAssetStrategist) external;

    /**
     * @notice Sets the incentive fund manager for a SuperAsset
     * @param superAsset Address of the SuperAsset contract
     * @param _incentiveFundManager Address of the incentive fund manager
     */
    function setIncentiveFundManager(address superAsset, address _incentiveFundManager) external;

    /**
     * @notice Sets the incentive calculation contract for a SuperAsset
     * @param superAsset Address of the SuperAsset contract
     * @param incentiveCalculationContract Address of the incentive calculation contract
     */
    function setIncentiveCalculationContract(address superAsset, address incentiveCalculationContract) external;

    /**
     * @notice Gets the manager for a SuperAsset
     * @param superAsset Address of the SuperAsset contract
     * @return superAssetManager Address of the manager
     */
    function getSuperAssetManager(address superAsset) external view returns (address);

    /**
     * @notice Gets the strategist for a SuperAsset
     * @param superAsset Address of the SuperAsset contract
     * @return superAssetStrategist Address of the strategist
     */
    function getSuperAssetStrategist(address superAsset) external view returns (address);

    /**
     * @notice Gets the incentive fund manager for a SuperAsset
     * @param superAsset Address of the SuperAsset contract
     * @return incentiveFundManager Address of the incentive fund manager
     */
    function getIncentiveFundManager(address superAsset) external view returns (address);

    /** 
     * @notice Gets the incentive calculation contract for a SuperAsset
     * @param superAsset Address of the SuperAsset contract
     * @return incentiveCalculationContract Address of the incentive calculation contract
     */
    function getIncentiveCalculationContract(address superAsset) external view returns (address);

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
     * @param incentiveFund Address of the deployed IncentiveFundContract
     * @param incentiveCalc Address of the deployed IncentiveCalculationContract
     * @param name Name of the SuperAsset token
     * @param symbol Symbol of the SuperAsset token
     */
    event SuperAssetCreated(
        address indexed superAsset,
        address indexed incentiveFund,
        address incentiveCalc,
        string name,
        string symbol
    );

    // --- Errors ---
    // Factory errors
    error ZERO_ADDRESS();

    // Unauthorized errors
    error UNAUTHORIZED();
}
