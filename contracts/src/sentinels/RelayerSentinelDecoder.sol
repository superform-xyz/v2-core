// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import { IRelayerDecoder } from "../interfaces/sentinels/IRelayerDecoder.sol";
import { IRelayerSentinel } from "../interfaces/sentinels/IRelayerSentinel.sol";

contract RelayerSentinelDecoder is IRelayerDecoder {
    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IRelayerDecoder
    function extractRelayerMessage(
        bytes memory input,
        bytes memory output,
        IRelayerSentinel.ModuleNotificationType sentinelType
    )
        external
        pure
        override
        returns (bytes memory relayerData)
    {
        if (sentinelType == IRelayerSentinel.ModuleNotificationType.Deposit4626) {
            relayerData = _extractDeposit4626Data(input, output, sentinelType);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _extractDeposit4626Data(
        bytes memory data_,
        bytes memory output_,
        IRelayerSentinel.ModuleNotificationType sentinelType
    )
        private
        pure
        returns (bytes memory)
    {
        (address account, uint256 amountIn) = abi.decode(data_, (address, uint256));
        uint256 amountOut = abi.decode(output_, (uint256));

        return abi.encode(account, sentinelType, amountIn, amountOut);
    }
}
