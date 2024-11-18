// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ISuperformExecutionModule {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the name of the module.
    /// @return The name of the module.
    function name() external view returns (string memory);

    /// @notice Get the version of the module.
    /// @return The version of the module.
    function version() external view returns (string memory);

    /// @notice Get the author of the module.
    /// @return The author of the module.
    function author() external view returns (address);
}
