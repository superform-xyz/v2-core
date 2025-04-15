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
    uint256 private constant addressListStart = 
        80084422859880547211683076133703299733277748156566366325829078699459944778998;
    
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
    function decodeOdosSwapCalldata(bytes memory txData) internal view returns (OdosDecodedSwap memory decoded) {
        if (txData.length < 4) {
            revert("OdosAPIParser: invalid tx data length");
        }

        bytes4 selector = bytes4(txData.slice(0, 4));
        console2.log("selector");
        console2.logBytes4(selector);
        console2.log("IOdosRouterV2.swap.selector");
        console2.logBytes4(IOdosRouterV2.swap.selector);
        console2.log("IOdosRouterV2.swapCompact.selector");
        console2.logBytes4(IOdosRouterV2.swapCompact.selector);
        bytes memory data = txData.slice(4, txData.length - 4);
        if (selector == IOdosRouterV2.swap.selector) {
            (decoded.tokenInfo, decoded.pathDefinition, decoded.executor, decoded.referralCode) = abi.decode(data, (IOdosRouterV2.swapTokenInfo, bytes, address, uint32));
        } else if (selector == IOdosRouterV2.swapCompact.selector) {
            (decoded.executor, decoded.referralCode, decoded.pathDefinition, decoded.tokenInfo) = _decode(data);
        }

        return decoded;
    }
    
    /*//////////////////////////////////////////////////////////////
                            PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decode(bytes memory rawData) private view returns (address executor, uint32 referralCode, bytes memory pathDefinition, IOdosRouterV2.swapTokenInfo memory tokenInfo) {
        bytes memory data = rawData;

        tokenInfo = IOdosRouterV2.swapTokenInfo({
            inputToken: address(0),
            inputAmount: 0,
            inputReceiver: address(0),
            outputToken: address(0),
            outputQuote: 0,
            outputMin: 0,
            outputReceiver: address(0)
        });
        pathDefinition = new bytes(0);

        address msgSender = msg.sender;

        assembly {
            let dataPtr := add(data, 0x20)

            tokenInfo := mload(0x40)
            mstore(0x40, add(tokenInfo, 0xE0)) // Reserve 7 * 32 bytes
            let tokenInfoPtr := tokenInfo
            let pos := 0

            function getAddress(currPos, ptr) -> result, newPos {
                let inputPos := shr(240, mload(add(ptr, currPos)))
                switch inputPos
                case 0x0000 {
                    result := 0
                    newPos := add(currPos, 2)
                }
                case 0x0001 {
                    result := and(shr(80, mload(add(ptr, currPos))), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                    newPos := add(currPos, 22)
                }
                default {
                    result := sload(add(addressListStart, sub(inputPos, 2)))
                    newPos := add(currPos, 2)
                }
            }

            let tmp := 0

            tmp, pos := getAddress(pos, dataPtr)
            mstore(tokenInfo, tmp) // inputToken

            tmp, pos := getAddress(pos, dataPtr)
            mstore(add(tokenInfo, 0x60), tmp) // outputToken

            // inputAmount
            let inputLen := shr(248, mload(add(dataPtr, pos)))
            pos := add(pos, 1)
            if inputLen {
                mstore(add(tokenInfoPtr, 0x20), shr(mul(sub(32, inputLen), 8), mload(add(dataPtr, pos))))
                pos := add(pos, inputLen)
            }

            // outputQuote
            let quoteLen := shr(248, mload(add(dataPtr, pos)))
            pos := add(pos, 1)
            let quote := shr(mul(sub(32, quoteLen), 8), mload(add(dataPtr, pos)))
            mstore(add(tokenInfoPtr, 0x80), quote)
            pos := add(pos, quoteLen)

            // outputMin from slippage
            {
                let slip := shr(232, mload(add(dataPtr, pos))) // 3 bytes
                mstore(add(tokenInfoPtr, 0xA0), div(mul(quote, sub(0xFFFFFF, slip)), 0xFFFFFF))
            }
            pos := add(pos, 3)

            executor, pos := getAddress(pos, dataPtr)

            tmp, pos := getAddress(pos, dataPtr)
            if eq(tmp, 0) {
                tmp := executor
            }
            mstore(add(tokenInfoPtr, 0x40), tmp) // inputReceiver

            tmp, pos := getAddress(pos, dataPtr)
            if eq(tmp, 0) {
                tmp := msgSender
            }
            mstore(add(tokenInfoPtr, 0xC0), tmp) // outputReceiver

            referralCode := shr(224, mload(add(dataPtr, pos)))
            pos := add(pos, 4)

            let pathLen := mul(shr(248, mload(add(dataPtr, pos))), 32)
            pathDefinition := mload(0x40)
            mstore(pathDefinition, pathLen)
            let dest := add(pathDefinition, 0x20)
            mstore(0x40, add(dest, pathLen))
            let pathData := add(add(dataPtr, pos), 1)
            for { let i := 0 } lt(i, pathLen) { i := add(i, 32) } {
                mstore(add(dest, i), mload(add(pathData, i)))
            }
        }

        console2.log("inputToken", tokenInfo.inputToken);
        console2.log("inputAmount", tokenInfo.inputAmount);
        console2.log("inputReceiver", tokenInfo.inputReceiver);
        console2.log("outputToken", tokenInfo.outputToken);
        console2.log("outputQuote", tokenInfo.outputQuote);
        console2.log("outputMin", tokenInfo.outputMin);
        console2.log("outputReceiver", tokenInfo.outputReceiver);
        console2.log("executor", executor);
        console2.log("referralCode", referralCode);
        console2.log("pathDefinition.length", pathDefinition.length);
    }

}

