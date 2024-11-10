// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISentinelDecoder } from "../interfaces/sentinels/ISentinelDecoder.sol";
import { IRelayerSentinel } from "../interfaces/sentinels/IRelayerSentinel.sol";

contract Deposit4626MintSuperPositionsDecoder is ISentinelDecoder {
    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinelDecoder
    function extractSentinelData(bytes memory data) external pure override returns (bytes memory sentinelData) {
        uint256 amountOut = abi.decode(data, (uint256));

        return abi.encode(amountOut);
    }
}
