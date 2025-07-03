// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { CREATE3 } from "@solady/src/utils/CREATE3.sol";

// Superform
import { ISuperDeployer } from "./ISuperDeployer.sol";

contract SuperDeployer is ISuperDeployer {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The authorized deployer address that can call deploy function
    /// @dev Immutable to prevent changes after deployment
    address public immutable AUTHORIZED_DEPLOYER;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error UNAUTHORIZED_DEPLOYER();
    error INVALID_DEPLOYER();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ContractDeployed(address indexed deployed, bytes32 indexed salt, address indexed deployer);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize SuperDeployer with authorized deployer
    /// @param authorizedDeployer The address authorized to deploy contracts
    constructor(address authorizedDeployer) {
        if (authorizedDeployer == address(0)) revert INVALID_DEPLOYER();
        AUTHORIZED_DEPLOYER = authorizedDeployer;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures only authorized deployer can call protected functions
    modifier onlyAuthorized() {
        if (msg.sender != AUTHORIZED_DEPLOYER) revert UNAUTHORIZED_DEPLOYER();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a contract using CREATE3 with access control
    /// @param salt The salt to use for deployment
    /// @param creationCode The contract creation code
    /// @return deployed The address of the deployed contract
    function deploy(
        bytes32 salt,
        bytes calldata creationCode
    )
        external
        payable
        onlyAuthorized
        returns (address deployed)
    {
        deployed = CREATE3.deployDeterministic(msg.value, creationCode, salt);
        emit ContractDeployed(deployed, salt, msg.sender);
    }

    /// @notice Predicts the address of a deployed contract
    /// @param salt The salt to use for deployment
    /// @return deployed The address of the contract that will be deployed
    function getDeployed(bytes32 salt) external view returns (address) {
        return CREATE3.predictDeterministicAddress(salt);
    }
}
