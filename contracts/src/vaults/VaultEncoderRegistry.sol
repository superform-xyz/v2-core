// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { IVaultEncoderRegistry } from "../interfaces/IVaultEncoderRegistry.sol";
import { IHookDataEncoder } from "../interfaces/IHookDataEncoder.sol";

/**
 * @title VaultEncoderRegistry
 * @notice Manages hook data encoders for a specific vault
 * @dev Controlled by the vault's strategist
 */
abstract contract VaultEncoderRegistry is IVaultEncoderRegistry {

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of vault type to encoder
    mapping(string => address) public override encoders;

    /// @notice List of supported types
    string[] private _types;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVaultEncoderRegistry
    function registerEncoder(address encoder) external onlyStrategist {
        if (encoder == address(0)) revert INVALID_ENCODER();
        string memory vaultType = IHookDataEncoder(encoder).getType();
        if (encoders[vaultType] != address(0)) revert TYPE_ALREADY_EXISTS();

        encoders[vaultType] = encoder;
        _types.push(vaultType);
        emit EncoderRegistered(vaultType, encoder);
    }

    /// @inheritdoc IVaultEncoderRegistry
    function removeEncoder(string calldata vaultType) external onlyStrategist {
        if (encoders[vaultType] == address(0)) revert TYPE_NOT_FOUND();

        delete encoders[vaultType];
        // Remove from types array
        for (uint256 i = 0; i < _types.length; i++) {
            if (keccak256(bytes(_types[i])) == keccak256(bytes(vaultType))) {
                _types[i] = _types[_types.length - 1];
                _types.pop();
                break;
            }
        }
        emit EncoderRemoved(vaultType);
    }

    /// @inheritdoc IVaultEncoderRegistry
    function getEncoder(string calldata vaultType) external view returns (address) {
        address encoder = encoders[vaultType];
        if (encoder == address(0)) revert TYPE_NOT_FOUND();
        return encoder;
    }

    /// @inheritdoc IVaultEncoderRegistry
    function getSupportedTypes() external view returns (string[] memory) {
        return _types;
    }

    /// @inheritdoc IVaultEncoderRegistry
    function types(uint256 index) external view returns (string memory) {
        return _types[index];
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Only allow the strategist to call this function
    modifier onlyStrategist() virtual;
} 