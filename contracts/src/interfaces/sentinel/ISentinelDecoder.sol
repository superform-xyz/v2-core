// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ISentinelData } from "src/interfaces/sentinel/ISentinelData.sol";

interface ISentinelDecoder {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NO_DATA_FOUND();
    error ADDRESS_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Decode the data
    /// @param target_ The target address of the function associated with the data
    /// @param data_ The data to decode
    function decode(address target_, bytes memory data_) external;
    //TODO: should we add selector as a parameter? that way decoders are more generic and not so specific
}
