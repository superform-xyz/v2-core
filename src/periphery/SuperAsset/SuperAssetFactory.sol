// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/SuperAsset/ISuperAssetFactory.sol";
import "./SuperAsset.sol";
import "./AssetBank.sol";
import "./IncentiveFundContract.sol";
import "./IncentiveCalculationContract.sol";
import "../SuperGovernor.sol";

/**
 * @title SuperAssetFactory
 * @author Superform Labs
 * @notice Factory contract that deploys SuperAsset and its dependencies
 */
contract SuperAssetFactory is ISuperAssetFactory, AccessControl {
    using Clones for address;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    address public immutable superAssetImplementation;
    address public immutable incentiveFundImplementation;
    // Single instances
    address public immutable assetBank;
    address public incentiveCalculationContract;
    address public immutable superGovernor;

    mapping(address superAsset => SuperAssetRoles roles) public roles;

    // --- Roles ---
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _superGovernor, address _incentiveCalculationContract, address _assetBank) {
        if (_superGovernor == address(0)) revert ZERO_ADDRESS();
        superGovernor = _superGovernor;

        superAssetImplementation = address(new SuperAsset());
        incentiveFundImplementation = address(new IncentiveFundContract(superGovernor));

        // Deploy single instances
        assetBank = _assetBank;
        incentiveCalculationContract = _incentiveCalculationContract;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEPLOYER_ROLE, msg.sender);
    }

    /// @inheritdoc ISuperAssetFactory
    function setSuperAssetManager(address superAsset, address _superAssetManager) external onlyRole(DEPLOYER_ROLE) {
        if (_superAssetManager == address(0)) revert ZERO_ADDRESS();
        if(msg.sender != roles[superAsset].superAssetManager) revert UNAUTHORIZED();
        roles[superAsset].superAssetManager = _superAssetManager;
    }

    /// @inheritdoc ISuperAssetFactory
    function setSuperAssetStrategist(address superAsset, address _superAssetStrategist) external onlyRole(DEPLOYER_ROLE) {
        if (_superAssetStrategist == address(0)) revert ZERO_ADDRESS();
        if(msg.sender != roles[superAsset].superAssetManager) revert UNAUTHORIZED();
        roles[superAsset].superAssetStrategist = _superAssetStrategist;
    }

    /// @inheritdoc ISuperAssetFactory
    function setIncentiveFundManager(address superAsset, address _incentiveFundManager) external onlyRole(DEPLOYER_ROLE) {
        if (_incentiveFundManager == address(0)) revert ZERO_ADDRESS();
        if(msg.sender != roles[superAsset].superAssetManager) revert UNAUTHORIZED();
        roles[superAsset].incentiveFundManager = _incentiveFundManager;
    }

    /// @inheritdoc ISuperAssetFactory
    function getSuperAssetManager(address superAsset) external view returns (address) {
        return roles[superAsset].superAssetManager;
    }

    /// @inheritdoc ISuperAssetFactory
    function getSuperAssetStrategist(address superAsset) external view returns (address) {
        return roles[superAsset].superAssetStrategist;
    }

    /// @inheritdoc ISuperAssetFactory
    function getIncentiveFundManager(address superAsset) external view returns (address) {
        return roles[superAsset].incentiveFundManager;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperAssetFactory
    function createSuperAsset(AssetCreationParams calldata params)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address superAsset, address incentiveFund)
    {
        // Deploy IncentiveFund (this one needs to be unique per SuperAsset)
        incentiveFund = incentiveFundImplementation.clone();

        // Deploy SuperAsset with its dependencies
        superAsset = superAssetImplementation.clone();
        SuperAsset(superAsset).initialize(
            params.name,
            params.symbol,
            incentiveCalculationContract, // Use single instance
            incentiveFund,
            assetBank, // Use single instance
            superGovernor,
            address(this),
            params.swapFeeInPercentage,
            params.swapFeeOutPercentage
        );

        // Initialize IncentiveFund
        IncentiveFundContract(incentiveFund).initialize(superAsset, assetBank, superGovernor, address(this));

        roles[superAsset] = SuperAssetRoles({
            superAssetManager: params.superAssetManager,
            superAssetStrategist: params.superAssetStrategist,
            incentiveFundManager: params.incentiveFundManager
        });


        // Return addresses (using existing instances for ICC and AssetBank)
        // assetBank_ = assetBank;
        // incentiveCalc = incentiveCalculationContract;

        emit SuperAssetCreated(
            superAsset, assetBank, incentiveFund, incentiveCalculationContract, params.name, params.symbol
        );
    }
}
