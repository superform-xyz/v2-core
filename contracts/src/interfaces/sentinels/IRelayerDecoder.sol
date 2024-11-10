// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IRelayerSentinel } from "./IRelayerSentinel.sol";

interface IRelayerDecoder {
    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Extract the relayer message from the input and output.
    /// @param input The input data.
    /// @param output The output data.
    /// @param sentinelType The sentinel type.
    /// @return relayerData The relayer data.
    function extractRelayerMessage(
        bytes memory input,
        bytes memory output,
        IRelayerSentinel.ModuleNotificationType sentinelType
    )
        external
        view
        returns (bytes memory relayerData);
}
