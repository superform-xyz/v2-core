// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Surl } from "@surl/Surl.sol";
import { strings } from "@stringutils/strings.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/StdUtils.sol";

import { BaseAPIParser } from "./BaseAPIParser.sol";

/// @title OpenOceanAPIParser
/// @notice Helper for calling the OpenOcean V4 swap API from Solidity tests via Surl.
abstract contract OpenOceanAPIParser is StdUtils, BaseAPIParser {
    using Surl for *;
    using Strings for uint256;
    using Strings for address;
    using strings for *;

    string internal constant OPENOCEAN_V4_FLARE_SWAP_URL = "https://open-api-pro.openocean.finance/v4/14/swap";

    struct OpenOceanSwapResponse {
        bytes txData;
        address to;
        uint256 value;
        uint256 inAmount;
        uint256 minOutAmount;
    }

    function surlCallOpenOceanSwap(
        address tokenIn_,
        address tokenOut_,
        string memory amount_,
        address account_
    )
        internal
        returns (OpenOceanSwapResponse memory response)
    {
        string memory url = string.concat(
            OPENOCEAN_V4_FLARE_SWAP_URL,
            "?chain=14",
            "&inTokenAddress=",
            toChecksumString(tokenIn_),
            "&outTokenAddress=",
            toChecksumString(tokenOut_),
            "&amount=",
            amount_,
            "&gasPrice=100.00",
            "&slippage=1",
            "&account=",
            toChecksumString(account_),
            "&enabledDexIds=6"
        );

        (uint256 status, bytes memory data) = url.get();
        if (status != 200) revert("OpenOceanAPIParser: swap call failed");

        string memory json = string(data);
        response.txData = fromHex(_extractQuotedString(json, '"data":"'));
        response.to = _parseAddress(_extractQuotedString(json, '"to":"'));
        response.value = _stringToUint(_extractQuotedString(json, '"value":"'));
        response.inAmount = _stringToUint(_extractQuotedString(json, '"inAmount":"'));
        response.minOutAmount = _stringToUint(_extractQuotedString(json, '"minOutAmount":"'));
    }

    function surlCallOpenOceanDynamicSwap(
        address tokenIn_,
        address tokenOut_,
        string memory amountDecimals_,
        address account_,
        address referrer_,
        string memory slippage_
    )
        internal
        returns (OpenOceanSwapResponse memory response)
    {
        string memory url = string.concat(
            OPENOCEAN_V4_FLARE_SWAP_URL,
            "?chain=14",
            "&inTokenAddress=",
            toChecksumString(tokenIn_),
            "&outTokenAddress=",
            toChecksumString(tokenOut_),
            "&amountDecimals=",
            amountDecimals_,
            "&gasPriceDecimals=100000000000",
            "&slippage=",
            slippage_,
            "&account=",
            toChecksumString(account_),
            "&referrer=",
            toChecksumString(referrer_),
            "&enabledDexIds=6"
        );

        (uint256 status, bytes memory data) = url.get();
        if (status != 200) {
            revert(string.concat("OpenOceanAPIParser: dynamic swap call failed: ", status.toString()));
        }

        return _parseSwapResponse(data);
    }

    function surlCallOpenOceanProDynamicSwap(
        string memory apiKey_,
        address tokenIn_,
        address tokenOut_,
        string memory amountDecimals_,
        address account_,
        address referrer_,
        string memory slippage_
    )
        internal
        returns (OpenOceanSwapResponse memory response)
    {
        string memory url = string.concat(
            OPENOCEAN_V4_FLARE_SWAP_URL,
            "?chain=14",
            "&inTokenAddress=",
            toChecksumString(tokenIn_),
            "&outTokenAddress=",
            toChecksumString(tokenOut_),
            "&amountDecimals=",
            amountDecimals_,
            "&gasPriceDecimals=100000000000",
            "&slippage=",
            slippage_,
            "&account=",
            toChecksumString(account_),
            "&referrer=",
            toChecksumString(referrer_),
            "&enabledDexIds=6"
        );

        (uint256 status, bytes memory data) = url.get(_openOceanProHeaders(apiKey_));
        if (status != 200) {
            revert(string.concat("OpenOceanAPIParser: pro dynamic swap call failed: ", status.toString()));
        }

        return _parseSwapResponse(data);
    }

    function _openOceanProHeaders(string memory apiKey_) internal pure returns (string[] memory headers) {
        headers = new string[](2);
        headers[0] = "accept: application/json";
        headers[1] = string.concat("Authorization: Bearer ", apiKey_);
    }

    function _parseSwapResponse(bytes memory data_) private pure returns (OpenOceanSwapResponse memory response) {
        string memory json = string(data_);
        response.txData = fromHex(_extractQuotedString(json, '"data":"'));
        response.to = _parseAddress(_extractQuotedString(json, '"to":"'));
        response.value = _stringToUint(_extractQuotedString(json, '"value":"'));
        response.inAmount = _stringToUint(_extractQuotedString(json, '"inAmount":"'));
        response.minOutAmount = _stringToUint(_extractQuotedString(json, '"minOutAmount":"'));
    }

    function _extractQuotedString(string memory json_, string memory key_) internal pure returns (string memory) {
        strings.slice memory jsonSlice = json_.toSlice();
        strings.slice memory key = key_.toSlice();
        strings.slice memory afterKey = jsonSlice.find(key).beyond(key);
        strings.slice memory value = afterKey.split('"'.toSlice());
        return value.toString();
    }

    function _parseAddress(string memory address_) internal pure returns (address parsed) {
        bytes memory raw = fromHex(address_);
        require(raw.length == 20, "OpenOceanAPIParser: invalid address");

        uint160 value;
        for (uint256 i; i < raw.length; ++i) {
            value = (value << 8) | uint8(raw[i]);
        }

        parsed = address(value);
    }

    function _stringToUint(string memory s_) internal pure returns (uint256 result) {
        bytes memory b = bytes(s_);
        for (uint256 i; i < b.length; ++i) {
            require(uint8(b[i]) >= 48 && uint8(b[i]) <= 57, "OpenOceanAPIParser: not a digit");
            result = result * 10 + (uint8(b[i]) - 48);
        }
    }
}
