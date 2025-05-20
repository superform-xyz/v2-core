// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

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

    mapping(address superAsset => address superAssetStrategist) public superAssetStrategist;
    mapping(address superAsset => address superAssetManager) public superAssetManager;
    mapping(address superAsset => address incentiveFundManager) public incentiveFundManager;

    // --- Roles ---
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _superGovernor, address _incentiveCalculationContract, address _assetBank) {
        require(_superGovernor != address(0), "SuperAssetFactory: zero address");
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
    function setRoles(address superAsset, address _superAssetStrategist, address _superAssetManager, address _incentiveFundManager) external onlyRole(DEPLOYER_ROLE) {
        if (_superAssetStrategist == address(0)) revert ZERO_ADDRESS();
        if (_superAssetManager == address(0)) revert ZERO_ADDRESS();
        if (_incentiveFundManager == address(0)) revert ZERO_ADDRESS();
        
        superAssetStrategist[superAsset] = _superAssetStrategist;
        superAssetManager[superAsset] = _superAssetManager;
        incentiveFundManager[superAsset] = _incentiveFundManager;
    }

    /// @inheritdoc ISuperAssetFactory
    function getRoles(address superAsset) external view returns (address _superAssetStrategist, address _superAssetManager, address _incentiveFundManager) {
        return (superAssetStrategist[superAsset], superAssetManager[superAsset], incentiveFundManager[superAsset]);
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
            params.swapFeeInPercentage,
            params.swapFeeOutPercentage
        );

        // Initialize IncentiveFund
        IncentiveFundContract(incentiveFund).initialize(superAsset, assetBank, superGovernor);

        superAssetManager[superAsset] = params.superAssetManager;
        superAssetStrategist[superAsset] = params.superAssetStrategist;
        incentiveFundManager[superAsset] = params.incentiveFundManager;


        // Return addresses (using existing instances for ICC and AssetBank)
        // assetBank_ = assetBank;
        // incentiveCalc = incentiveCalculationContract;

        emit SuperAssetCreated(
            superAsset, assetBank, incentiveFund, incentiveCalculationContract, params.name, params.symbol
        );
    }
}
