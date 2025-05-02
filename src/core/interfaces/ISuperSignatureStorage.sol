// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ISuperSignatureStorage {
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Retrieve signature data
    /// @param account The smart account address
    function retrieveSignatureData(address account) external view returns (bytes memory);
}