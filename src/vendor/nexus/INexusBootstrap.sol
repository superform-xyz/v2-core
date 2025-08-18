// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "./IERC7484.sol";
import "modulekit/accounts/common/lib/ModeLib.sol";

struct BootstrapConfig {
    address module;
    bytes data;
}

struct BootstrapPreValidationHookConfig {
    uint256 hookType;
    address module;
    bytes data;
}

struct RegistryConfig {
    IERC7484 registry;
    address[] attesters;
    uint8 threshold;
}

interface INexusBootstrap7702 {
    /// @notice Initializes the Nexus account with multiple modules.
    /// @dev Intended to be called by the Nexus with a delegatecall.
    /// @param validators The configuration array for validator modules. Should not contain the default validator.
    /// @param executors The configuration array for executor modules.
    /// @param hook The configuration for the hook module.
    /// @param fallbacks The configuration array for fallback handler modules.
    /// @param preValidationHooks The configuration array for pre-validation hooks.
    /// @param registryConfig The registry configuration.
    function initNexus(
        BootstrapConfig[] calldata validators,
        BootstrapConfig[] calldata executors,
        BootstrapConfig calldata hook,
        BootstrapConfig[] calldata fallbacks,
        BootstrapPreValidationHookConfig[] calldata preValidationHooks,
        RegistryConfig memory registryConfig
    )
        external
        payable;
}

interface INexusBootstrap {
    /// @notice Initializes the Nexus account with multiple modules.
    /// @dev Intended to be called by the Nexus with a delegatecall.
    /// @param validators The configuration array for validator modules.
    /// @param executors The configuration array for executor modules.
    /// @param hook The configuration for the hook module.
    /// @param fallbacks The configuration array for fallback handler modules.
    function initNexus(
        BootstrapConfig[] calldata validators,
        BootstrapConfig[] calldata executors,
        BootstrapConfig calldata hook,
        BootstrapConfig[] calldata fallbacks,
        IERC7484 registry,
        address[] calldata attesters,
        uint8 threshold
    )
        external;

    /// @notice Prepares calldata for the initNexusScoped function.
    /// @param validators The configuration array for validator modules.
    /// @param hook The configuration for the hook module.
    /// @return init The prepared calldata for initNexusScoped.
    function getInitNexusScopedCalldata(
        BootstrapConfig[] calldata validators,
        BootstrapConfig calldata hook,
        IERC7484 registry,
        address[] calldata attesters,
        uint8 threshold
    )
        external
        view
        returns (bytes memory init);

    /// @notice Prepares calldata for the initNexus function.
    /// @param validators The configuration array for validator modules.
    /// @param executors The configuration array for executor modules.
    /// @param hook The configuration for the hook module.
    /// @param fallbacks The configuration array for fallback handler modules.
    /// @return init The prepared calldata for initNexus.
    function getInitNexusCalldata(
        BootstrapConfig[] calldata validators,
        BootstrapConfig[] calldata executors,
        BootstrapConfig calldata hook,
        BootstrapConfig[] calldata fallbacks,
        IERC7484 registry,
        address[] calldata attesters,
        uint8 threshold
    )
        external
        view
        returns (bytes memory init);
}
