// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// external
import { CREATE3 } from "@solady/src/utils/CREATE3.sol";

// Superform
import { ISuperDeployer } from "./ISuperDeployer.sol";

contract SuperDeployer is ISuperDeployer {
    //TODO: protect by a EOA `deployer` address
    //      otherwise, others can take the `salt` and deploy the same contract with CREATE3
    function deploy(bytes32 salt, bytes calldata creationCode) external payable returns (address) {
        return CREATE3.deployDeterministic(msg.value, creationCode, salt);
    }

    function getDeployed(bytes32 salt) external view returns (address) {
        return CREATE3.predictDeterministicAddress(salt);
    }
}
