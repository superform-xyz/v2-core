// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/SuperAsset/ISuperAssetFactory.sol";
import "./SuperAsset.sol";
import "./AssetBank.sol";
import "./IncentiveFundContract.sol";
import "./IncentiveCalculationContract.sol";

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
    address public immutable assetBankImplementation;
    address public immutable incentiveFundImplementation;
    address public immutable incentiveCalcImplementation;

    // --- Roles ---
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        superAssetImplementation = address(new SuperAsset());
        assetBankImplementation = address(new AssetBank());
        incentiveFundImplementation = address(new IncentiveFundContract());
        incentiveCalcImplementation = address(new IncentiveCalculationContract());

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DEPLOYER_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ISuperAssetFactory
     */
    function createSuperAsset(AssetCreationParams calldata params)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (
            address superAsset,
            address assetBank,
            address incentiveFund,
            address incentiveCalc
        )
    {
        // Deploy dependencies first
        incentiveCalc = incentiveCalcImplementation.clone();
        assetBank = assetBankImplementation.clone();
        incentiveFund = incentiveFundImplementation.clone();

        // Deploy SuperAsset with its dependencies
        superAsset = superAssetImplementation.clone();
        SuperAsset(superAsset).initialize(
            params.name,
            params.symbol,
            incentiveCalc,
            incentiveFund,
            assetBank,
            params.swapFeeInPercentage,
            params.swapFeeOutPercentage
        );

        // Initialize IncentiveFundContract with SuperAsset address
        IncentiveFundContract(incentiveFund).initialize(superAsset, assetBank);

        emit SuperAssetCreated(
            superAsset,
            assetBank,
            incentiveFund,
            incentiveCalc,
            params.name,
            params.symbol
        );

        return (superAsset, assetBank, incentiveFund, incentiveCalc);
    }
}
