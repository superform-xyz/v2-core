// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../vendor/BytesLib.sol";

/// @title HookDataDecoder
/// @author Superform Labs
/// @notice Library for decoding hook data
library HookDataDecoder {
    function extractYieldSourceOracleId(bytes memory data) internal pure returns (bytes32) {
        return bytes32(BytesLib.slice(data, 0, 32));
    }

    function extractYieldSource(bytes memory data) internal pure returns (address) {
        return BytesLib.toAddress(data, 32);
    }
}
