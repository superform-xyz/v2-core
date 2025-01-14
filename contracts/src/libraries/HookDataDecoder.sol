// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import {BytesLib} from "./BytesLib.sol";

library HookDataDecoder {
    function extractAccount(bytes memory data) internal pure returns (address) {
        return BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
    }

    function extractYieldSourceOracleId(bytes memory data) internal pure returns (bytes32) {
        return BytesLib.toBytes32(BytesLib.slice(data, 20, 32), 0);
    }

    function extractYieldSource(bytes memory data) internal pure returns (address) {
        return BytesLib.toAddress(BytesLib.slice(data, 52, 20), 0);
    }

}
