// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { CREATE3 } from "@solady/src/utils/CREATE3.sol";

// Superform
import { ISuperDeployer } from "./ISuperDeployer.sol";

contract SuperDeployer is ISuperDeployer {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ContractDeployed(address indexed deployed, bytes32 indexed salt, address indexed deployer);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a contract using CREATE3 - permissionless deployment
    /// @dev Anyone can deploy with any salt - first deployer wins, others can check if already deployed
    /// @param salt The salt to use for deployment
    /// @param creationCode The contract creation code
    /// @return deployed The address of the deployed contract
    function deploy(bytes32 salt, bytes calldata creationCode) external payable returns (address deployed) {
        deployed = CREATE3.deployDeterministic(msg.value, creationCode, salt);
        emit ContractDeployed(deployed, salt, msg.sender);
    }

    /// @notice Predicts the address of a deployed contract
    /// @param salt The salt to use for deployment
    /// @return The address where the contract will be deployed
    function getDeployed(bytes32 salt) external view returns (address) {
        return CREATE3.predictDeterministicAddress(salt);
    }

    /// @notice Check if a contract is already deployed at the predicted address
    /// @param salt The salt that would be used for deployment
    /// @return True if contract exists at the predicted address
    function isDeployed(bytes32 salt) external view returns (bool) {
        address predicted = CREATE3.predictDeterministicAddress(salt);
        uint256 size;
        assembly {
            size := extcodesize(predicted)
        }
        return size > 0;
    }
}
