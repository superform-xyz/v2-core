// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Surl } from "@surl/Surl.sol";
import { strings } from "@stringutils/strings.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/StdUtils.sol";

import { IOdosRouterV2 } from "../../../src/vendor/odos/IOdosRouterV2.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";

import { BaseAPIParser } from "./BaseAPIParser.sol";

import "forge-std/console2.sol";
abstract contract OdosAPIParser is StdUtils, BaseAPIParser {
    using Surl for *;
    using Strings for uint256;
    using Strings for address;
    using strings for *;
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/
    struct QuoteInputToken {
        address tokenAddress;
        uint256 amount;
    }

    struct QuoteOutputToken {
        address tokenAddress;
        uint256 proportion;
    }

    struct OdosDecodedSwap {
       IOdosRouterV2.swapTokenInfo tokenInfo;
       bytes pathDefinition;
       address executor;
       uint32 referralCode;
    }

    string constant API_QUOTE_URL = "https://api.odos.xyz/sor/quote/v2";
    string constant API_ASSEMBLE_URL = "https://api.odos.xyz/sor/assemble";

    
    /*//////////////////////////////////////////////////////////////
                            API_QUOTE_URL
    //////////////////////////////////////////////////////////////*/
    function buildQuoteV2RequestBody(QuoteInputToken[] memory _inputTokens, QuoteOutputToken[] memory _outputTokens, address _account, uint256 _chainId, bool _compact) internal pure returns (string memory) {
        string memory inputTokensStr = "[";
        for (uint256 i = 0; i < _inputTokens.length; i++) {
            inputTokensStr = string.concat(
                inputTokensStr,
                i > 0 ? "," : "",
                '{"tokenAddress":"', toChecksumString(_inputTokens[i].tokenAddress), '",',
                '"amount":"', _inputTokens[i].amount.toString(), '"}'
            );
        }
        inputTokensStr = string.concat(inputTokensStr, "]");

        string memory outputTokensStr = "[";
        for (uint256 i = 0; i < _outputTokens.length; i++) {
            outputTokensStr = string.concat(
                outputTokensStr,
                i > 0 ? "," : "",
                '{"tokenAddress":"', toChecksumString(_outputTokens[i].tokenAddress), '",',
                '"proportion":', _outputTokens[i].proportion.toString(), '}'
            );
        }
        outputTokensStr = string.concat(outputTokensStr, "]");

        return string.concat(
            "{",
                '"chainId":', _chainId.toString(), ",",
                '"inputTokens":', inputTokensStr, ",",
                '"outputTokens":', outputTokensStr, ",",
                '"slippageLimitPercent":0.3,',
                '"userAddr":"', toChecksumString(_account), '",',
                '"referralCode":0,',
                '"disableRFQs":true,',
                '"compact":', _compact ? "true" : "false",
            "}"
        );
    }
    function surlCallQuoteV2(QuoteInputToken[] memory _inputTokens, QuoteOutputToken[] memory _outputTokens, address _account, uint256 _chainId, bool _compact) internal returns (string memory) {
        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";

        string memory body = buildQuoteV2RequestBody(_inputTokens, _outputTokens, _account, _chainId, _compact);
        (uint256 status, bytes memory data) = API_QUOTE_URL.post(headers, body);
        if (status != 200) {
            revert("OdosAPIParser: surlCallQuoteV2 failed");
        }
        string memory json = string(data);
        console2.log("json", json);

        // get `pathId`
        strings.slice memory jsonSlice = json.toSlice();
        strings.slice memory key = '"pathId":"'.toSlice();
        strings.slice memory afterKey = jsonSlice.find(key).beyond(key);
        strings.slice memory pathId = afterKey.split('"'.toSlice());

        return pathId.toString();
    }

    /*//////////////////////////////////////////////////////////////
                            API_ASSEMBLE_URL
    //////////////////////////////////////////////////////////////*/
    function buildAssembleRequestBody(string memory _pathId, address _userAddr) internal pure returns (string memory) {
        return string.concat(
            "{",
                '"pathId":"', _pathId, '",',
                '"userAddr":"', toChecksumString(_userAddr), '",',
                '"simulate":false'
            "}"
        );
    }
    function surlCallAssemble(string memory _pathId, address _userAddr) internal returns (string memory) {
        string[] memory headers = new string[](1);
        headers[0] = "Content-Type: application/json";  

        string memory body = buildAssembleRequestBody(_pathId, _userAddr);
        console2.log("body", body);
        (uint256 status, bytes memory data) = API_ASSEMBLE_URL.post(headers, body);
        if (status != 200) {
            revert("OdosAPIParser: surlCallAssemble failed");
        }
        string memory json = string(data);
        console2.log("json assemble", json);
        strings.slice memory jsonSlice = json.toSlice();
        strings.slice memory key = '"data":"'.toSlice();
        strings.slice memory afterKey = jsonSlice.find(key).beyond(key);
        strings.slice memory swapData = afterKey.split('"'.toSlice());

        return swapData.toString();
    }


    /*//////////////////////////////////////////////////////////////
                            DECODE SWAP
    //////////////////////////////////////////////////////////////*/
    function decodeCompactSwap(bytes memory txData) internal pure returns (OdosDecodedSwap memory decoded) {
        if (txData.length < 4) {
            revert("OdosAPIParser: invalid tx data length");
        }

        bytes4 selector = bytes4(txData.slice(0, 4));
        console2.log("selector");
        console2.logBytes4(selector);
        if (selector != IOdosRouterV2.swap.selector) {
            revert("OdosAPIParser: invalid selector");
        }

        
        bytes memory data = txData.slice(4, txData.length - 4);
        (decoded.tokenInfo, decoded.pathDefinition, decoded.executor, decoded.referralCode) = abi.decode(data, (IOdosRouterV2.swapTokenInfo, bytes, address, uint32));

        return decoded;
    }
}

