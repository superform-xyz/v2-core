// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IComposabilityStackKeys {
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the key for the composability stack
    /// @param target_ The target address
    /// @param selector_ The selector of the function
    /// @return The key for the composability stack
    function getKey(address target_, bytes4 selector_) external view returns (bytes32);
}
