// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IRelayerSentinel } from "./IRelayerSentinel.sol";

interface ISentinelDecoder {
    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Extract data from the sentinel notification
    /// @param data The data.
    /// @return sentinelData The data to be relayed.
    function extractSentinelData(bytes memory data) external view returns (bytes memory sentinelData);
}
