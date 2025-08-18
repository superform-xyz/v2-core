// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

library SignatureTransientStorage {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Storage key for transient signature data
    /// @dev Uses the transient storage pattern to store signature data temporarily
    ///      This is more gas efficient than regular storage for temporary data
    bytes32 internal constant SIGNATURE_KEY_STORAGE = keccak256("transient.signature.bytes.mapping");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Error thrown when more than one user op is detected for signature storage
    error INVALID_USER_OP();

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Stores signature data in transient storage
    /// @dev Uses EVM assembly for efficient transient storage operations
    ///      First stores the length, then each 32-byte chunk of the signature data
    ///      Transient storage (tstore) is used for gas efficiency and temporary data
    /// @param identifier The unique identifier for this signature (derived from account address)
    /// @param data The signature data to store
    function storeSignature(uint256 identifier, bytes calldata data) internal {
        bytes32 storageKey = _makeKey(identifier);

        // only one userOp per account is being executed
        uint256 stored;
        assembly {
            stored := tload(storageKey)
        }

        if (stored != 0) revert INVALID_USER_OP();

        uint256 len = data.length;

        assembly {
            tstore(storageKey, len)
        }

        for (uint256 i; i < len; i += 32) {
            bytes32 word;
            assembly {
                word := calldataload(add(data.offset, i))
                tstore(add(storageKey, div(add(i, 32), 32)), word)
            }
        }
    }

    /// @notice Retrieves signature data from transient storage
    /// @dev Uses EVM assembly for efficient transient storage operations
    ///      First loads the length, then each 32-byte chunk of the signature data
    ///      Transient storage (tload) is used for gas efficiency and temporary data
    /// @param identifier The unique identifier for this signature (derived from account address)
    function loadSignature(uint256 identifier) internal view returns (bytes memory out) {
        bytes32 storageKey = _makeKey(identifier);
        uint256 len;
        assembly {
            len := tload(storageKey)
        }

        out = new bytes(len);

        for (uint256 i; i < len; i += 32) {
            bytes32 word;
            assembly {
                word := tload(add(storageKey, div(add(i, 32), 32)))
            }

            assembly {
                mstore(add(add(out, 0x20), i), word)
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Generates a storage key for transient storage
    /// @dev Combines the base storage key with an identifier (usually account address)
    ///      to create a unique storage location
    /// @param identifier The unique identifier (typically derived from account address)
    /// @return A unique storage key for the transient storage system
    function _makeKey(uint256 identifier) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(SIGNATURE_KEY_STORAGE, identifier));
    }
}
