// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

//TODO: update based on MEE composability stack
interface IComposabilityStackWriter {
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Store data
    /// @param id_ The id of the stored data
    /// @param data_ The data to store
    function store(bytes32 id_, bytes memory data_) external;
}
