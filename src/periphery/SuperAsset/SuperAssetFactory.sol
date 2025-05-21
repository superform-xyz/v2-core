// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "../interfaces/SuperAsset/ISuperAssetFactory.sol";
import "./SuperAsset.sol";
import "./IncentiveFundContract.sol";
import "./IncentiveCalculationContract.sol";
import "../SuperGovernor.sol";

/**
 * @title SuperAssetFactory
 * @author Superform Labs
 * @notice Factory contract that deploys SuperAsset and its dependencies
 */
contract SuperAssetFactory is ISuperAssetFactory {
    using Clones for address;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    address public immutable superAssetImplementation;
    address public immutable incentiveFundImplementation;
    // Single instances
    address public immutable incentiveCalculationContract;
    address public immutable superGovernor;

    mapping(address superAsset => SuperAssetRoles roles) public roles;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _superGovernor, address _incentiveCalculationContract) {
        if (_superGovernor == address(0)) revert ZERO_ADDRESS();
        superGovernor = _superGovernor;

        superAssetImplementation = address(new SuperAsset());
        incentiveFundImplementation = address(new IncentiveFundContract());

        // Deploy single instances
        incentiveCalculationContract = _incentiveCalculationContract;
    }

    /// @inheritdoc ISuperAssetFactory
    function setSuperAssetManager(address superAsset, address _superAssetManager) external {
        if (_superAssetManager == address(0)) revert ZERO_ADDRESS();
        ISuperGovernor _superGovernor = ISuperGovernor(superGovernor);
        if(
            (msg.sender != roles[superAsset].superAssetManager) &&
            (msg.sender != _superGovernor.getAddress(_superGovernor.SUPERASSET_FACTORY_DEPLOYER())) // NOTE: This role can take over
        ) revert UNAUTHORIZED();
        roles[superAsset].superAssetManager = _superAssetManager;
    }

    /// @inheritdoc ISuperAssetFactory
    function setSuperAssetStrategist(address superAsset, address _superAssetStrategist) external {
        if (_superAssetStrategist == address(0)) revert ZERO_ADDRESS();
        if(msg.sender != roles[superAsset].superAssetManager) revert UNAUTHORIZED();
        roles[superAsset].superAssetStrategist = _superAssetStrategist;
    }

    /// @inheritdoc ISuperAssetFactory
    function setIncentiveFundManager(address superAsset, address _incentiveFundManager) external {
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
        returns (address superAsset, address incentiveFund)
    {
        ISuperGovernor _superGovernor = ISuperGovernor(superGovernor);
        if(msg.sender != _superGovernor.getAddress(_superGovernor.SUPERASSET_FACTORY_DEPLOYER())) revert UNAUTHORIZED();
        // Deploy IncentiveFund (this one needs to be unique per SuperAsset)
        incentiveFund = incentiveFundImplementation.clone();

        // Deploy SuperAsset with its dependencies
        superAsset = superAssetImplementation.clone();
        SuperAsset(superAsset).initialize(
            params.name,
            params.symbol,
            incentiveCalculationContract, // Use single instance
            incentiveFund,
            superGovernor,
            address(this),
            params.swapFeeInPercentage,
            params.swapFeeOutPercentage
        );

        // Initialize IncentiveFund
        IncentiveFundContract(incentiveFund).initialize(superGovernor, superAsset);

        roles[superAsset] = SuperAssetRoles({
            superAssetManager: params.superAssetManager,
            superAssetStrategist: params.superAssetStrategist,
            incentiveFundManager: params.incentiveFundManager
        });


        // Return addresses (using existing instances for ICC and AssetBank)
        // incentiveCalc = incentiveCalculationContract;

        emit SuperAssetCreated(
            superAsset, incentiveFund, incentiveCalculationContract, params.name, params.symbol
        );
    }
}
