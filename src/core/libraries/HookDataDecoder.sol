// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import { BytesLib } from "../../vendor/BytesLib.sol";

/// @title HookDataDecoder
/// @author Superform Labs
/// @notice Library for decoding hook data
library HookDataDecoder {
    function extractYieldSourceOracleId(bytes memory data) internal pure returns (bytes4) {
        return bytes4(BytesLib.slice(data, 0, 4));
    }

    function extractYieldSource(bytes memory data) internal pure returns (address) {
        return BytesLib.toAddress(data, 4);
    }
}
