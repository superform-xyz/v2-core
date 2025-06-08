// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IBundlerRegistry {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when the bundler address is invalid
    error INVALID_BUNDLER_ADDRESS();
    /// @notice Thrown when the bundler is already registered
    error BUNDLER_ALREADY_REGISTERED();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a bundler is registered
    event BundlerRegistered(uint256 indexed id, address indexed bundler);
    /// @notice Emitted when the address of a bundler is updated
    event BundlerAddressUpdated(uint256 indexed id, address indexed oldBundler, address indexed newBundler);
    /// @notice Emitted when the extra data of a bundler is updated
    event BundlerExtraDataUpdated(uint256 indexed id, address indexed bundler, bytes extraData);
    /// @notice Emitted when the status of a bundler is changed
    event BundlerStatusChanged(uint256 indexed id, address indexed bundler, bool isActive);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Bundler {
        uint256 id; //unique identifier for the bundler
        address bundlerAddress; //address of the bundler
        bool isActive; //whether the bundler is active
        bytes extraData; //extra data for off-chain use
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Check if a bundler is registered
    /// @param bundler The address of the bundler
    /// @return True if the bundler is registered, false otherwise
    function isBundlerRegistered(address bundler) external view returns (bool);

    /// @notice Check if a bundler is active
    /// @param bundler The address of the bundler
    /// @return True if the bundler is active, false otherwise
    function isBundlerActive(address bundler) external view returns (bool);

    /// @notice Get a bundler by its id
    /// @param _bundlerId The id of the bundler
    /// @return The bundler
    function getBundler(uint256 _bundlerId) external view returns (Bundler memory);

    /// @notice Get a bundler by its address
    /// @param _addr The address of the bundler
    /// @return The bundler
    function getBundlerByAddress(address _addr) external view returns (Bundler memory);
}
