// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title DestinationAdapterSimulationConfig
/// @author Superform Labs
/// @notice Reads per-call adapter configuration appended to simulation runtime bytecode
/// @dev Simulation adapter code must be encoded as:
///      runtime || MAGIC || authorizedCaller || tokenMessaging || destinationExecutor.
///      Each configuration value occupies one left-padded 32-byte word. Across uses
///      address(0) for tokenMessaging. Keeping configuration in a code trailer avoids
///      changing the live adapter's storage while allowing one runtime artifact on all chains.
library DestinationAdapterSimulationConfig {
    /// @notice Identifies a valid version-one destination adapter simulation trailer
    bytes32 internal constant MAGIC = keccak256("superform.destination-adapter-simulation.config.v1");

    /// @notice Four 32-byte words: magic plus three addresses
    uint256 internal constant TRAILER_LENGTH = 128;

    struct Config {
        address authorizedCaller;
        address tokenMessaging;
        address destinationExecutor;
    }

    /// @notice Thrown when the runtime has no valid simulation configuration trailer
    error INVALID_SIMULATION_CONFIG();

    /// @notice Reads and validates the configuration appended to the executing contract's code
    /// @return config The decoded authorized caller, TokenMessaging, and destination executor
    function read() internal pure returns (Config memory config) {
        bytes32 magic;
        bytes32 authorizedCallerWord;
        bytes32 tokenMessagingWord;
        bytes32 destinationExecutorWord;
        uint256 codeSize;

        assembly ("memory-safe") {
            codeSize := codesize()
        }
        if (codeSize < TRAILER_LENGTH) revert INVALID_SIMULATION_CONFIG();

        assembly ("memory-safe") {
            let ptr := mload(0x40)
            codecopy(ptr, sub(codeSize, TRAILER_LENGTH), TRAILER_LENGTH)
            magic := mload(ptr)
            authorizedCallerWord := mload(add(ptr, 0x20))
            tokenMessagingWord := mload(add(ptr, 0x40))
            destinationExecutorWord := mload(add(ptr, 0x60))
            mstore(0x40, add(ptr, TRAILER_LENGTH))
        }

        if (magic != MAGIC) revert INVALID_SIMULATION_CONFIG();
        if (
            uint256(authorizedCallerWord) >> 160 != 0 || uint256(tokenMessagingWord) >> 160 != 0
                || uint256(destinationExecutorWord) >> 160 != 0
        ) {
            revert INVALID_SIMULATION_CONFIG();
        }

        config.authorizedCaller = address(uint160(uint256(authorizedCallerWord)));
        config.tokenMessaging = address(uint160(uint256(tokenMessagingWord)));
        config.destinationExecutor = address(uint160(uint256(destinationExecutorWord)));
    }
}
