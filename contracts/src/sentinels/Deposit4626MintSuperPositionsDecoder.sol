// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { ISentinelDecoder } from "../interfaces/sentinels/ISentinelDecoder.sol";
import { IRelayerSentinel } from "../interfaces/sentinels/IRelayerSentinel.sol";
import { ISuperPositions } from "../interfaces/ISuperPositions.sol";

contract Deposit4626MintSuperPositionsDecoder is ISentinelDecoder {
    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISentinelDecoder
    function extractSentinelData(bytes memory data) external pure override returns (bytes memory sentinelData) {
        (address account, uint256 amount) = abi.decode(data, (address, uint256));

        return abi.encodeWithSelector(ISuperPositions.mint.selector, account, amount);
    }
}
