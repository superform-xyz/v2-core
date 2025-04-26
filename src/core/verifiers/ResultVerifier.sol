// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { ISuperResultVerifier } from "../interfaces/ISuperResultVerifier.sol";

/// @title ResultVerifier
/// @author Superform Labs
/// @notice Implementation of execution result verification
/// @dev This implementation focuses on validating that the on-chain execution
///      results match the predicted results from off-chain computation
contract ResultVerifier is ISuperResultVerifier {
    using Math for uint256;
    
    /// Tolerance parameters for comparing results
    uint256 private constant TOLERANCE_BASIS_POINTS = 5; // 0.05% tolerance
    uint256 private constant BASIS_POINTS_DENOMINATOR = 10_000; // 100% in basis points
    
    /// @inheritdoc ISuperResultVerifier
    function verifyResults(
        address _account,
        address _hook,
        bytes calldata expectedResult,
        bytes calldata actualResult
    ) external pure returns (bool isValid) {
        // Validate format of both results
        if (expectedResult.length == 0 || actualResult.length == 0) {
            revert INVALID_RESULT_FORMAT();
        }
        
        // General numeric result verification approach
        if (expectedResult.length == 32 && actualResult.length == 32) {
            // For uint256 results, allow a small tolerance
            uint256 expected = abi.decode(expectedResult, (uint256));
            uint256 actual = abi.decode(actualResult, (uint256));
            
            return _isWithinTolerance(expected, actual);
        } else if (expectedResult.length == 64 && actualResult.length == 64) {
            // For 2-tuples of uint256, check both values within tolerance
            (uint256 expected1, uint256 expected2) = abi.decode(expectedResult, (uint256, uint256));
            (uint256 actual1, uint256 actual2) = abi.decode(actualResult, (uint256, uint256));
            
            return _isWithinTolerance(expected1, actual1) && _isWithinTolerance(expected2, actual2);
        } else {
            // For all other formats, expect exact match
            bytes32 expectedHash = keccak256(expectedResult);
            bytes32 actualHash = keccak256(actualResult);
            
            return expectedHash == actualHash;
        }
    }
    
    /// @inheritdoc ISuperResultVerifier
    function verifierTypeId() external pure returns (bytes32) {
        return keccak256("RESULT_VERIFIER");
    }
    
    /// @notice Check if actual value is within tolerance of expected value
    /// @param expected The expected value
    /// @param actual The actual value
    /// @return isWithinTolerance True if actual value is within tolerance
    function _isWithinTolerance(uint256 expected, uint256 actual) internal pure returns (bool) {
        if (expected == 0) {
            return actual == 0;
        }
        
        uint256 allowedDeviation = expected.mulDiv(TOLERANCE_BASIS_POINTS, BASIS_POINTS_DENOMINATOR);
        
        return (
            actual >= expected - allowedDeviation &&
            actual <= expected + allowedDeviation
        );
    }
}
