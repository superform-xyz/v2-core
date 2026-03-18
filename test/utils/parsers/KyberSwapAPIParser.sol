// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Surl } from "@surl/Surl.sol";
import { strings } from "@stringutils/strings.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/StdUtils.sol";

import { BaseAPIParser } from "./BaseAPIParser.sol";

/// @title KyberSwapAPIParser
/// @notice Helper for calling the KyberSwap Aggregator API from Solidity tests via Surl
/// @dev Used for end-to-end integration tests that need real routing data from KyberSwap
abstract contract KyberSwapAPIParser is StdUtils, BaseAPIParser {
    using Surl for *;
    using Strings for uint256;
    using strings for *;

    string constant KYBER_API_BASE = "https://aggregator-api.kyberswap.com/";
    string constant KYBER_CLIENT_ID = "superform";

    /*//////////////////////////////////////////////////////////////
                            GET /routes
    //////////////////////////////////////////////////////////////*/

    /// @notice Call KyberSwap GET /routes to find a swap route
    /// @param tokenIn Source token address (use 0xEeee...eE for native ETH)
    /// @param tokenOut Destination token address
    /// @param amountIn Amount of source token in smallest units
    /// @param chain Chain name (e.g., "ethereum", "base", "arbitrum")
    /// @return routeSummaryJson The routeSummary JSON object as a string
    function surlCallRoutes(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        string memory chain
    )
        internal
        returns (string memory routeSummaryJson)
    {
        return surlCallRoutes(tokenIn, tokenOut, amountIn, chain, "");
    }

    /// @notice Call KyberSwap GET /routes with optional excluded sources
    /// @param tokenIn Source token address
    /// @param tokenOut Destination token address
    /// @param amountIn Amount of source token in smallest units
    /// @param chain Chain name (e.g., "ethereum", "base", "arbitrum")
    /// @param excludedSources Comma-separated DEX IDs to exclude (e.g., "ekubo,uniswapv4")
    /// @return routeSummaryJson The routeSummary JSON object as a string
    function surlCallRoutes(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        string memory chain,
        string memory excludedSources
    )
        internal
        returns (string memory routeSummaryJson)
    {
        string[] memory headers = new string[](1);
        headers[0] = string.concat("X-Client-Id: ", KYBER_CLIENT_ID);

        string memory url = string.concat(
            KYBER_API_BASE,
            chain,
            "/api/v1/routes?tokenIn=",
            toChecksumString(tokenIn),
            "&tokenOut=",
            toChecksumString(tokenOut),
            "&amountIn=",
            amountIn.toString()
        );

        // Append excludedSources if provided
        if (bytes(excludedSources).length > 0) {
            url = string.concat(url, "&excludedSources=", excludedSources);
        }

        (uint256 status, bytes memory data) = url.get(headers);
        require(status == 200, "KyberSwapAPIParser: routes call failed");

        string memory json = string(data);
        routeSummaryJson = _extractJsonObject(json, '"routeSummary"');
    }

    /*//////////////////////////////////////////////////////////////
                          POST /route/build
    //////////////////////////////////////////////////////////////*/

    /// @notice Call KyberSwap POST /route/build to get encoded swap calldata
    /// @param routeSummaryJson The routeSummary JSON from surlCallRoutes
    /// @param sender Address that will execute the swap
    /// @param recipient Address that will receive output tokens
    /// @param slippageTolerance Slippage in bps (e.g., 200 = 2%)
    /// @param chain Chain name (e.g., "ethereum")
    /// @return txDataHex Encoded swap calldata as hex string with 0x prefix
    function surlCallBuild(
        string memory routeSummaryJson,
        address sender,
        address recipient,
        uint256 slippageTolerance,
        string memory chain
    )
        internal
        returns (string memory txDataHex)
    {
        string[] memory headers = new string[](2);
        headers[0] = "Content-Type: application/json";
        headers[1] = string.concat("X-Client-Id: ", KYBER_CLIENT_ID);

        string memory body = string.concat(
            '{"routeSummary":',
            routeSummaryJson,
            ',"sender":"',
            toChecksumString(sender),
            '","recipient":"',
            toChecksumString(recipient),
            '","slippageTolerance":',
            slippageTolerance.toString(),
            ',"deadline":999999999999}'
        );

        string memory url = string.concat(KYBER_API_BASE, chain, "/api/v1/route/build");

        (uint256 status, bytes memory data) = url.post(headers, body);
        require(status == 200, "KyberSwapAPIParser: build call failed");

        string memory json = string(data);

        // Extract encoded calldata: find "data":"0x... (inner data field, not outer response wrapper)
        // The outer "data" field is an object ("data":{...}), so "data":"0x only matches the inner calldata
        strings.slice memory jsonSlice = json.toSlice();
        jsonSlice.find('"data":"0x'.toSlice());
        strings.slice memory afterKey = jsonSlice.beyond('"data":"'.toSlice());
        strings.slice memory hexValue = afterKey.split('"'.toSlice());

        txDataHex = hexValue.toString();
    }

    /*//////////////////////////////////////////////////////////////
                          JSON HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Extract amountOut from a routeSummary JSON string
    function extractAmountOut(string memory routeSummaryJson) internal pure returns (uint256) {
        strings.slice memory jsonSlice = routeSummaryJson.toSlice();
        strings.slice memory key = '"amountOut":"'.toSlice();
        strings.slice memory afterKey = jsonSlice.find(key).beyond(key);
        strings.slice memory amountStr = afterKey.split('"'.toSlice());
        return _stringToUint(amountStr.toString());
    }

    /// @notice Extract a nested JSON object by key using brace counting
    /// @dev Handles nested objects and arrays; ignores braces inside quoted strings
    function _extractJsonObject(string memory json, string memory key) internal pure returns (string memory) {
        bytes memory jsonBytes = bytes(json);
        bytes memory keyBytes = bytes(key);

        uint256 keyPos = _findInBytes(jsonBytes, keyBytes);
        require(keyPos != type(uint256).max, "KyberSwapAPIParser: key not found");

        // Skip past key to find opening brace
        uint256 pos = keyPos + keyBytes.length;
        while (pos < jsonBytes.length && jsonBytes[pos] != '{') {
            pos++;
        }
        require(pos < jsonBytes.length, "KyberSwapAPIParser: no opening brace");

        uint256 start = pos;
        uint256 depth = 0;
        bool inString = false;

        for (uint256 i = start; i < jsonBytes.length; i++) {
            bytes1 c = jsonBytes[i];

            if (c == '"' && (i == 0 || jsonBytes[i - 1] != '\\')) {
                inString = !inString;
                continue;
            }

            if (!inString) {
                if (c == '{') {
                    depth++;
                } else if (c == '}') {
                    depth--;
                    if (depth == 0) {
                        bytes memory result = new bytes(i - start + 1);
                        for (uint256 j = 0; j < result.length; j++) {
                            result[j] = jsonBytes[start + j];
                        }
                        return string(result);
                    }
                }
            }
        }

        revert("KyberSwapAPIParser: unmatched braces");
    }

    /// @notice Find first occurrence of needle in haystack (byte-level search)
    function _findInBytes(bytes memory haystack, bytes memory needle) internal pure returns (uint256) {
        if (needle.length > haystack.length) return type(uint256).max;

        uint256 maxPos = haystack.length - needle.length;
        for (uint256 i = 0; i <= maxPos; i++) {
            bool found = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return i;
        }
        return type(uint256).max;
    }

    /// @notice Convert a decimal number string to uint256
    function _stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            require(uint8(b[i]) >= 48 && uint8(b[i]) <= 57, "KyberSwapAPIParser: not a digit");
            result = result * 10 + (uint8(b[i]) - 48);
        }
        return result;
    }
}
