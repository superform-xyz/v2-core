// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title MockEIP1271Contract
/// @notice A mock contract that implements EIP-1271 signature validation (not a Safe)
/// @dev Used for testing non-Safe EIP-1271 contracts as owners of 7579 accounts
contract MockEIP1271Contract is IERC1271 {
    /// @notice Magic value returned when a signature is valid according to EIP-1271
    bytes4 public constant EIP1271_MAGIC_VALUE = 0x1626ba7e;
    
    /// @notice The owner who can sign on behalf of this contract
    address public owner;
    
    /// @notice Whether this contract should behave maliciously (always return invalid)
    bool public isMalicious;
    
    constructor(address _owner) {
        owner = _owner;
        isMalicious = false;
    }
    
    /// @notice Set malicious behavior for testing
    function setMalicious(bool _malicious) external {
        isMalicious = _malicious;
    }
    
    /// @notice Change the owner
    function setOwner(address _newOwner) external {
        require(msg.sender == owner, "Only owner can change owner");
        owner = _newOwner;
    }
    
    /// @notice EIP-1271 signature validation
    /// @dev This is a simple implementation - signs the raw message hash
    function isValidSignature(bytes32 hash, bytes memory signature) external view override returns (bytes4) {
        if (isMalicious) {
            return bytes4(0xffffffff); // Return invalid magic value
        }
        
        // Convert hash to Ethereum signed message hash
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(hash);
        
        // Recover signer from signature
        address recovered = ECDSA.recover(ethSignedMessageHash, signature);
        
        // Check if recovered address matches owner
        if (recovered == owner) {
            return EIP1271_MAGIC_VALUE;
        }
        
        return bytes4(0xffffffff); // Invalid signature
    }
}
