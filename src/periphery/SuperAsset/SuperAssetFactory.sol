// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { ISuperAssetFactory } from "../interfaces/SuperAsset/ISuperAssetFactory.sol";
import { SuperAsset } from "./SuperAsset.sol";
import { IncentiveFundContract } from "./IncentiveFundContract.sol";
import { IncentiveCalculationContract } from "./IncentiveCalculationContract.sol";

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
    address public immutable superGovernor;

    mapping(address superAsset => SuperAssetData data) public data;
    mapping(address icc => bool isValid) public incentiveCalculationContractsWhitelist;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _superGovernor) {
        if (_superGovernor == address(0)) revert ZERO_ADDRESS();
        superGovernor = _superGovernor;

        superAssetImplementation = address(new SuperAsset());
        incentiveFundImplementation = address(new IncentiveFundContract());
    }

    /// @inheritdoc ISuperAssetFactory
    function addICCToWhitelist(address icc) external {
        if (msg.sender != superGovernor) revert UNAUTHORIZED();
        incentiveCalculationContractsWhitelist[icc] = true;
    }

    /// @inheritdoc ISuperAssetFactory
    function removeICCFromWhitelist(address icc) external {
        if (msg.sender != superGovernor) revert UNAUTHORIZED();
        incentiveCalculationContractsWhitelist[icc] = false;
    }

    /// @inheritdoc ISuperAssetFactory
    function isICCWhitelisted(address icc) external view returns (bool) {
        return incentiveCalculationContractsWhitelist[icc];
    }

    /// @inheritdoc ISuperAssetFactory
    function setSuperAssetManager(address superAsset, address _superAssetManager) external {
        if (_superAssetManager == address(0)) revert ZERO_ADDRESS();
        if (
            (msg.sender != data[superAsset].superAssetManager) && (msg.sender != superGovernor) // NOTE: This role can
                // take over
        ) revert UNAUTHORIZED();
        data[superAsset].superAssetManager = _superAssetManager;
    }

    /// @inheritdoc ISuperAssetFactory
    function setSuperAssetStrategist(address superAsset, address _superAssetStrategist) external {
        if (_superAssetStrategist == address(0)) revert ZERO_ADDRESS();
        if (msg.sender != data[superAsset].superAssetManager) revert UNAUTHORIZED();
        data[superAsset].superAssetStrategist = _superAssetStrategist;
    }

    /// @inheritdoc ISuperAssetFactory
    function setIncentiveFundManager(address superAsset, address _incentiveFundManager) external {
        if (_incentiveFundManager == address(0)) revert ZERO_ADDRESS();
        if (msg.sender != data[superAsset].superAssetManager) revert UNAUTHORIZED();
        data[superAsset].incentiveFundManager = _incentiveFundManager;
    }

    /// @inheritdoc ISuperAssetFactory
    function setIncentiveCalculationContract(address superAsset, address _incentiveCalculationContract) external {
        if (_incentiveCalculationContract == address(0)) revert ZERO_ADDRESS();
        if (!incentiveCalculationContractsWhitelist[_incentiveCalculationContract]) revert ICC_NOT_WHITELISTED();
        if (msg.sender != data[superAsset].superAssetManager) revert UNAUTHORIZED();
        data[superAsset].incentiveCalculationContract = _incentiveCalculationContract;
    }

    /// @inheritdoc ISuperAssetFactory
    function getSuperAssetManager(address superAsset) external view returns (address) {
        return data[superAsset].superAssetManager;
    }

    /// @inheritdoc ISuperAssetFactory
    function getSuperAssetStrategist(address superAsset) external view returns (address) {
        return data[superAsset].superAssetStrategist;
    }

    /// @inheritdoc ISuperAssetFactory
    function getIncentiveFundManager(address superAsset) external view returns (address) {
        return data[superAsset].incentiveFundManager;
    }

    /// @inheritdoc ISuperAssetFactory
    function getIncentiveCalculationContract(address superAsset) external view returns (address) {
        return data[superAsset].incentiveCalculationContract;
    }

    /// @inheritdoc ISuperAssetFactory
    function getIncentiveFundContract(address superAsset) external view returns (address) {
        return data[superAsset].incentiveFundContract;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperAssetFactory
    function createSuperAsset(AssetCreationParams calldata params)
        external
        returns (address superAsset, address incentiveFundContract)
    {
        // TODO: Decide whether to make this method permissionless or permissioned

        if (params.incentiveCalculationContract == address(0)) revert ZERO_ADDRESS();
        if (!incentiveCalculationContractsWhitelist[params.incentiveCalculationContract]) revert ICC_NOT_WHITELISTED();

        // Deploy IncentiveFund (this one needs to be unique per SuperAsset)
        incentiveFundContract = incentiveFundImplementation.clone();

        // Deploy SuperAsset with its dependencies
        superAsset = superAssetImplementation.clone();
        SuperAsset(superAsset).initialize(
            params.name, params.symbol, superGovernor, params.swapFeeInPercentage, params.swapFeeOutPercentage
        );

        // Initialize IncentiveFund
        IncentiveFundContract(incentiveFundContract).initialize(
            superGovernor, superAsset, params.tokenInIncentive, params.tokenOutIncentive
        );

        data[superAsset] = SuperAssetData({
            superAssetManager: params.superAssetManager,
            superAssetStrategist: params.superAssetStrategist,
            incentiveFundManager: params.incentiveFundManager,
            incentiveCalculationContract: params.incentiveCalculationContract,
            incentiveFundContract: incentiveFundContract
        });

        emit SuperAssetCreated(
            superAsset, incentiveFundContract, params.incentiveCalculationContract, params.name, params.symbol
        );
    }
}
