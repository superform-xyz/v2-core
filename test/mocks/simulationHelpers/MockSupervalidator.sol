// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// Superform
import {ISuperSignatureStorage} from "../interfaces/ISuperSignatureStorage.sol";
import {SignatureTransientStorage} from "../libraries/SignatureTransientStorage.sol";

/// @title SuperSignatureStorageOverride
/// @author Superform Labs
/// @notice Contract for signature storage operations using transient storage
/// @dev This contract is designed to be compiled but not deployed - bytecode will be overwritten during eth_call
///      Provides both retrieval and storage functionality for signature data
contract SuperSignatureStorageOverride is ISuperSignatureStorage {
    using SignatureTransientStorage for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperSignatureStorage
    function retrieveSignatureData(
        address account
    ) external view returns (bytes memory) {
        uint256 identifier = uint256(uint160(account));

        // Load signature data from transient storage
        return identifier.loadSignature();
    }

    /// @notice Store signature data for a specific account
    /// @dev Takes a signature and address, creates identifier and stores the signature in transient storage
    /// @param signature The signature data to store
    /// @param account The account address to associate with the signature
    function storeSignatureData(
        bytes calldata signature,
        address account
    ) external {
        uint256 identifier = uint256(uint160(account));
        identifier.storeSignature(signature);
    }
}
