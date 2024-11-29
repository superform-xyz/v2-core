// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

//TODO: update based on MEE composability stack
interface IComposabilityStackReader {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error KEYS_NOT_SET();
    error KEY_NOT_FOUND();
    error ADDRESS_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the stored data
    /// @param target_ The target address
    /// @param selector_ The selector of the function
    /// @return The stored data
    function get(address target_, bytes4 selector_) external view returns (bytes memory);
}
