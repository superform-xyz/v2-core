// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ISentinelData } from "src/interfaces/sentinel/ISentinelData.sol";

interface ISentinelProcessor {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NO_DATA_FOUND();
    error ADDRESS_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Process the data
    /// @param target_ The target address of the function associated with the data
    /// @param selector_ The selector of the function associated with the data
    /// @param data_ The data to process
    function process(address target_, bytes4 selector_, bytes memory data_) external;
}
