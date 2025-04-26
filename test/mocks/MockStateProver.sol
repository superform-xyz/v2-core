// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISuperStateProver } from "../../src/core/interfaces/ISuperStateProver.sol";

/// @title MockStateProver
/// @dev Simple mock state prover for testing
contract MockStateProver is ISuperStateProver {
    bool private _shouldVerify;
    
    constructor(bool shouldVerify_) {
        _shouldVerify = shouldVerify_;
    }
    
    function setShouldVerify(bool shouldVerify_) external {
        _shouldVerify = shouldVerify_;
    }
    
    /// @inheritdoc ISuperStateProver
    function verifyStateTransition(
        bytes calldata,
        bytes calldata,
        bytes calldata,
        bytes calldata
    ) external view returns (bool isValid) {
        return _shouldVerify;
    }
    
    /// @inheritdoc ISuperStateProver
    function proverTypeId() external pure returns (bytes32) {
        return keccak256("MOCK_STATE_PROVER");
    }
}
