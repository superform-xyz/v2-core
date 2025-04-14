// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { Surl } from "@surl/Surl.sol";
import { strings } from "@stringutils/strings.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/StdUtils.sol";

import "../../../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";

import { BaseAPIParser } from "./BaseAPIParser.sol";

import "forge-std/console2.sol";
abstract contract OneInchAPIParser is StdUtils, BaseAPIParser {
    using Surl for *;
    using Strings for uint256;
    using Strings for address;
    using strings for *;
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/
    struct OneInchSwapCalldataRequest {
        uint256 chainId;
        address src;
        address dst;
        uint256 amount;
        address from;
        address origin;
        uint256 slippage;
    }
 
    string constant BASE_URL = "https://api.1inch.dev/swap/v6.0/";
    string constant SWAP_CALLDATA_URL_PATH = "swap"; // `BASE_URL` + `chain id` + `SWAP_CALLDATA_URL_PATH`
    string constant GET_ROUTER_URL_PATH = "approve/spender";
    string constant GET_APPROVE_CALLDATA = "approve/transaction";
    
    /*//////////////////////////////////////////////////////////////
                            SWAP_CALLDATA_URL_PATH
    //////////////////////////////////////////////////////////////*/
    function buildSwapCallDataRequestUrl(OneInchSwapCalldataRequest memory request) internal pure returns (string memory) { 
        return string.concat(
            BASE_URL,
            request.chainId.toString(),
            "/",
            SWAP_CALLDATA_URL_PATH,
            "?src=", toChecksumString(request.src),
            "&dst=", toChecksumString(request.dst),
            "&amount=", request.amount.toString(),
            "&from=", toChecksumString(request.from),
            "&origin=", toChecksumString(request.origin),
            "&slippage=", request.slippage.toString()
        );
    }
    
    function surlCallSwapCalldata(string memory authKey, OneInchSwapCalldataRequest memory request) internal returns (string memory dstAmount, string memory txData) {
        string memory url = buildSwapCallDataRequestUrl(request);
        console2.log("url", url);

        string[] memory headers = _getHeaders(authKey);

        (uint256 status, bytes memory data) = url.get(headers);
        if (status != 200) {
            revert("OneInchAPIParser: surlCallSwapCalldata failed");
        }
        string memory json = string(data);
        console2.log("json", json);

        strings.slice memory jsonSlice = json.toSlice();

        // dstAmount
        strings.slice memory dstKey = '"dstAmount":"'.toSlice();
        strings.slice memory afterDstKey = jsonSlice.find(dstKey).beyond(dstKey);
        dstAmount = afterDstKey.split('"'.toSlice()).toString();

        // tx.data
        strings.slice memory dataKey = '"data":"'.toSlice();
        strings.slice memory afterDataKey = jsonSlice.find(dataKey).beyond(dataKey);
        txData = afterDataKey.split('"'.toSlice()).toString();
    }

    /*//////////////////////////////////////////////////////////////
                            GET_ROUTER_URL_PATH
    //////////////////////////////////////////////////////////////*/
    function buildGetRouterUrl(uint256 chainId) internal pure returns (string memory) {
        return string.concat(
            BASE_URL,
            chainId.toString(),
            "/",
            GET_ROUTER_URL_PATH
        );
    }

    function surlCallGetRouter(string memory authKey, uint256 chainId) internal returns (string memory spender) {
        string memory url = buildGetRouterUrl(chainId);
        console2.log("url", url);

        string[] memory headers = _getHeaders(authKey);

        (uint256 status, bytes memory data) = url.get(headers);
        if (status != 200) {
            revert("OneInchAPIParser: surlCallGetRouter failed");
        }

        string memory json = string(data);
        console2.log("json", json);

        strings.slice memory jsonSlice = json.toSlice();
        strings.slice memory spenderKey = '"address":"'.toSlice();
        strings.slice memory afterSpenderKey = jsonSlice.find(spenderKey).beyond(spenderKey);
        spender = afterSpenderKey.split('"'.toSlice()).toString();
    }

    /*//////////////////////////////////////////////////////////////
                            GET_APPROVE_CALLDATA
    //////////////////////////////////////////////////////////////*/
    function buildGetApproveCallDataUrl(uint256 chainId, address tokenAddress, uint256 amount) internal pure returns (string memory) {
        return string.concat(
            BASE_URL,
            chainId.toString(),
            "/",
            GET_APPROVE_CALLDATA,
            "?tokenAddress=", toChecksumString(tokenAddress),
            "&amount=", amount.toString()
        );
    }

    function surlCallGetApproveCallData(string memory authKey, uint256 chainId, address tokenAddress, uint256 amount) internal returns (string memory txData) {
        string memory url = buildGetApproveCallDataUrl(chainId, tokenAddress, amount);
        console2.log("url", url);
        
        string[] memory headers = _getHeaders(authKey);

        (uint256 status, bytes memory data) = url.get(headers);
        if (status != 200) {
            revert("OneInchAPIParser: surlCallGetApproveCallData failed");
        }

        string memory json = string(data);  
        console2.log("json", json);
        
        strings.slice memory jsonSlice = json.toSlice();
        strings.slice memory txDataKey = '"data":"'.toSlice();
        strings.slice memory afterTxDataKey = jsonSlice.find(txDataKey).beyond(txDataKey);
        txData = afterTxDataKey.split('"'.toSlice()).toString();
    }


    /*//////////////////////////////////////////////////////////////
                            PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _getHeaders(string memory authKey) internal pure returns (string[] memory headers) {
        headers = new string[](2);
        headers[0] = "accept: application/json";
        headers[1] = string.concat("Authorization: Bearer ", authKey);
    }
}