// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract ChainAgnosticHashDebugTest is Test {
    /// @notice Chain-agnostic domain separator type hash
    bytes32 private constant CHAIN_AGNOSTIC_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
    /// @notice Fixed chain ID for cross-chain signature 1271 compatibility
    uint256 private constant FIXED_CHAIN_ID = 1;
    /// @notice Domain name and version for cross-chain 1271 signatures
    string private constant DOMAIN_NAME = "SuperformSafe";
    string private constant DOMAIN_VERSION = "1.0.0";

    function test_debugChainAgnosticHash() public {
        // Use the same values from the JS test
        address safe = 0x25fF5dA92586A0878b9D9825a30eec8bcfCAf217;
        bytes32 rawHash = 0xbf814820f81900b70b22fcb45f4d82859fd10cca99e4f137db4eb6d649037abb;

        console.log("=== Debug Chain Agnostic Hash Calculation ===");
        console.log("Safe address:", safe);
        console.logBytes32(rawHash);
        console.log("Raw hash (hex):");
        console.logBytes32(rawHash);

        // Step 1: Calculate domain separator components
        console.log("\n=== Domain Separator Components ===");
        console.log("CHAIN_AGNOSTIC_DOMAIN_TYPEHASH:");
        console.logBytes32(CHAIN_AGNOSTIC_DOMAIN_TYPEHASH);
        
        bytes32 domainNameHash = keccak256(bytes(DOMAIN_NAME));
        console.log("Domain name hash:");
        console.logBytes32(domainNameHash);
        
        bytes32 domainVersionHash = keccak256(bytes(DOMAIN_VERSION));
        console.log("Domain version hash:");
        console.logBytes32(domainVersionHash);
        
        console.log("Fixed chain ID:", FIXED_CHAIN_ID);

        // Step 2: Calculate domain separator
        bytes32 domainSeparator = keccak256(
            abi.encode(
                CHAIN_AGNOSTIC_DOMAIN_TYPEHASH,
                domainNameHash,
                domainVersionHash,
                FIXED_CHAIN_ID,
                safe
            )
        );
        console.log("\n=== Domain Separator ===");
        console.log("Domain separator:");
        console.logBytes32(domainSeparator);

        // Step 3: Calculate SafeMessage components
        console.log("\n=== SafeMessage Components ===");
        bytes32 safeMessageTypehash = keccak256("SafeMessage(bytes message)");
        console.log("SafeMessage typehash:");
        console.logBytes32(safeMessageTypehash);
        
        bytes32 rawHashEncoded = keccak256(abi.encode(rawHash));
        console.log("Raw hash encoded:");
        console.logBytes32(rawHashEncoded);
        
        bytes32 safeMessageStructHash = keccak256(abi.encode(safeMessageTypehash, rawHashEncoded));
        console.log("SafeMessage struct hash:");
        console.logBytes32(safeMessageStructHash);

        // Step 4: Calculate final chain-agnostic hash
        bytes32 chainAgnosticHash = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator,
                safeMessageStructHash
            )
        );
        console.log("\n=== Final Result ===");
        console.log("Chain agnostic hash:");
        console.logBytes32(chainAgnosticHash);

        // Additional debug: show the packed data
        bytes memory packedData = abi.encodePacked(
            bytes1(0x19),
            bytes1(0x01),
            domainSeparator,
            safeMessageStructHash
        );
        console.log("\nPacked data length:", packedData.length);
        console.log("Expected length: 66 bytes (1 + 1 + 32 + 32)");
    }

    function test_compareWithExpectedHash() public {
        // The hash that Solidity should produce (from production logs)
        bytes32 expectedHash = 0x01a4bda7a68f6669f85afc69998565ecf6241009c616a607bba50e3a8fae9a3c;
        
        // Calculate our hash
        address safe = 0x25fF5dA92586A0878b9D9825a30eec8bcfCAf217;
        bytes32 rawHash = 0xbf814820f81900b70b22fcb45f4d82859fd10cca99e4f137db4eb6d649037abb;
        
        bytes32 domainSeparator = keccak256(
            abi.encode(
                CHAIN_AGNOSTIC_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                FIXED_CHAIN_ID,
                safe
            )
        );
        
        bytes32 chainAgnosticHash = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator,
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(rawHash))))
            )
        );
        
        console.log("\n=== Hash Comparison ===");
        console.log("Expected hash:");
        console.logBytes32(expectedHash);
        console.log("Calculated hash:");
        console.logBytes32(chainAgnosticHash);
        console.log("Hashes match:", expectedHash == chainAgnosticHash);
        
        // This should pass if our calculation is correct
        assertEq(chainAgnosticHash, expectedHash, "Chain agnostic hash should match expected value");
    }

    function test_signatureRecovery() public {
        // Test signature recovery with the actual signature from JavaScript
        bytes32 dataHash = 0x01a4bda7a68f6669f85afc69998565ecf6241009c616a607bba50e3a8fae9a3c;
        bytes memory signature = hex"1c5ec9c4d46971f0e497b552a860fd9a858794177da775d1536c23ba81a6cb704b61fa13c4bde086a96f95aa53d54a4a3cfb3b7e803f9f5b2166430144494cdf1b";
        
        console.log("\n=== Signature Recovery Debug ===");
        console.log("Data hash:");
        console.logBytes32(dataHash);
        console.log("Signature:");
        console.logBytes(signature);
        console.log("Signature length:", signature.length);
        
        // Parse signature components
        uint8 v;
        bytes32 r;
        bytes32 s;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        
        console.log("v:", v);
        console.log("r:");
        console.logBytes32(r);
        console.log("s:");
        console.logBytes32(s);
        
        // Test different recovery methods
        console.log("\n=== Recovery Methods ===");
        
        // Method 1: Direct ECDSA recovery
        address recovered1 = ecrecover(dataHash, v, r, s);
        console.log("Direct ECDSA recovery:", recovered1);
        
        // Method 2: eth_sign recovery (what Solidity uses for v > 30)
        if (v > 30) {
            bytes32 ethSignHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
            address recovered2 = ecrecover(ethSignHash, v - 4, r, s);
            console.log("eth_sign recovery (v-4):", recovered2);
        }
        
        // Method 3: Standard eth_sign recovery
        bytes32 ethSignHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
        address recovered3 = ecrecover(ethSignHash, v, r, s);
        console.log("eth_sign recovery (v):", recovered3);
    }
}
