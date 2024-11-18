// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { CREATE3 } from "@solady/src/utils/CREATE3.sol";
import { ICreate3Deployer } from "./ICreate3Deployer.sol";

contract Create3Deployer is ICreate3Deployer {
    /// @inheritdoc	ICreate3Deployer
    function deploy(bytes32 salt, bytes calldata creationCode) external payable override returns (address) {
        return CREATE3.deployDeterministic(msg.value, creationCode, salt);
    }

    /// @inheritdoc	ICreate3Deployer
    function getDeployed(bytes32 salt) external view override returns (address) {
        return CREATE3.predictDeterministicAddress(salt);
    }
}
