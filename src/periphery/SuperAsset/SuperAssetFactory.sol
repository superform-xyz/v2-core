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
    address public immutable incentiveCalculationContract;
    address public immutable superGovernor;

    // --- Roles ---
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address admin) {
        // Deploy SuperGovernor first
        superGovernor = address(new SuperGovernor(
            admin, // superGovernor role
            admin, // governor role
            admin, // bankManager role
            admin, // treasury (using admin for simplicity)
            admin  // prover (using admin for simplicity)
        ));

        superAssetImplementation = address(new SuperAsset());
        incentiveFundImplementation = address(new IncentiveFundContract(superGovernor));

        // Deploy single instances
        assetBank = address(new AssetBank(superGovernor));
        incentiveCalculationContract = address(new IncentiveCalculationContract());

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEPLOYER_ROLE, msg.sender);
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

        // Return addresses (using existing instances for ICC and AssetBank)
        // assetBank_ = assetBank;
        // incentiveCalc = incentiveCalculationContract;

        emit SuperAssetCreated(
            superAsset, assetBank, incentiveFund, incentiveCalculationContract, params.name, params.symbol
        );
    }
}
