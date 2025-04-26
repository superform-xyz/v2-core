// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperResultVerifier } from "../../src/core/interfaces/ISuperResultVerifier.sol";

/// @title MockResultVerifier
/// @dev Simple mock result verifier for testing
contract MockResultVerifier is ISuperResultVerifier {
    bool private _shouldVerify;
    
    constructor(bool shouldVerify_) {
        _shouldVerify = shouldVerify_;
    }
    
    function setShouldVerify(bool shouldVerify_) external {
        _shouldVerify = shouldVerify_;
    }
    
    /// @inheritdoc ISuperResultVerifier
    function verifyResults(
        address,
        address,
        bytes calldata,
        bytes calldata
    ) external view returns (bool isValid) {
        return _shouldVerify;
    }
    
    /// @inheritdoc ISuperResultVerifier
    function verifierTypeId() external pure returns (bytes32) {
        return keccak256("MOCK_RESULT_VERIFIER");
    }
}
