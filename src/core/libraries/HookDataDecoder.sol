// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import {BytesLib} from "./BytesLib.sol";

library HookDataDecoder {
    function extractYieldSourceOracleId(bytes memory data) internal pure returns (bytes32) {
        return BytesLib.toBytes32(BytesLib.slice(data, 0, 32), 0);
    }

    function extractYieldSource(bytes memory data) internal pure returns (address) {
        return BytesLib.toAddress(BytesLib.slice(data, 32, 20), 0);
    }

}
