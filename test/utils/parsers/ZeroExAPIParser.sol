// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Surl } from "@surl/Surl.sol";
import { strings } from "@stringutils/strings.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/StdUtils.sol";
import { BaseAPIParser } from "./BaseAPIParser.sol";
import "forge-std/console2.sol";

/// @title ZeroExAPIParser
/// @author Superform Labs
/// @notice Parser for 0x Protocol v2 Swap API integration
/// @dev Based on 0x API v2 documentation: https://0x.org/docs/0x-swap-api/introduction
abstract contract ZeroExAPIParser is StdUtils, BaseAPIParser {
    using Surl for *;
    using Strings for uint256;
    using Strings for address;
    using strings for *;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice 0x API base URL for mainnet
    string constant API_BASE_URL = "https://api.0x.org";

    /// @notice API endpoints
    string constant ALLOWANCE_HOLDER_QUOTE_ENDPOINT = "/swap/allowance-holder/quote";

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Quote response from 0x API
    struct ZeroExQuoteResponse {
        address allowanceTarget;
        string blockNumber;
        uint256 buyAmount;
        address buyToken;
        uint256 gas;
        string gasPrice;
        uint256 minBuyAmount;
        bytes transaction;
        string value;
        string zid;
    }

    /*//////////////////////////////////////////////////////////////
                            API METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get quote from 0x AllowanceHolder API for smart contract integration
    /// @param sellToken Address of token to sell
    /// @param buyToken Address of token to buy
    /// @param sellAmount Amount of sell token (in wei)
    /// @param taker Address of the taker (smart account)
    /// @param chainId Chain ID (1 for mainnet)
    /// @param slippageBps Slippage tolerance in basis points (0-10000, where 500 = 5%)
    /// @param zeroExApiKey 0x API key
    /// @return quoteResponse Parsed quote response containing transaction data
    function getZeroExQuote(
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        address taker,
        uint256 chainId,
        uint256 slippageBps,
        string memory zeroExApiKey
    )
        internal
        returns (ZeroExQuoteResponse memory quoteResponse)
    {
        return
            getZeroExQuoteWithSlippage(sellToken, buyToken, sellAmount, taker, chainId, slippageBps, "", zeroExApiKey);
    }

    /// @notice Get quote with additional parameters
    /// @param sellToken Address of token to sell
    /// @param buyToken Address of token to buy
    /// @param sellAmount Amount of sell token (in wei)
    /// @param taker Address of the taker (smart account)
    /// @param chainId Chain ID (1 for mainnet)
    /// @param slippageBps Slippage tolerance in basis points (0-10000, where 500 = 5%)
    /// @param excludeSources Comma-separated list of sources to exclude
    /// @param zeroExApiKey 0x API key
    /// @return quoteResponse Parsed quote response containing transaction data
    function getZeroExQuoteWithSlippage(
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        address taker,
        uint256 chainId,
        uint256 slippageBps,
        string memory excludeSources,
        string memory zeroExApiKey
    )
        internal
        returns (ZeroExQuoteResponse memory quoteResponse)
    {
        // Build the API request URL
        string memory requestUrl =
            _buildQuoteURL(sellToken, buyToken, sellAmount, taker, chainId, slippageBps, excludeSources);

        // Make the API request
        string memory response = _makeAPIRequest(requestUrl, zeroExApiKey);

        // Parse the JSON response
        quoteResponse = _parseQuoteResponse(response);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Build the complete quote request URL
    /// @param sellToken Address of token to sell
    /// @param buyToken Address of token to buy
    /// @param sellAmount Amount of sell token (in wei)
    /// @param taker Address of the taker (smart account)
    /// @param chainId Chain ID (1 for mainnet)
    /// @param slippageBps Slippage tolerance in basis points (0-10000)
    /// @param excludeSources Comma-separated list of sources to exclude
    /// @return Complete request URL
    function _buildQuoteURL(
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        address taker,
        uint256 chainId,
        uint256 slippageBps,
        string memory excludeSources
    )
        internal
        pure
        returns (string memory)
    {
        string memory baseUrl = string.concat(API_BASE_URL, ALLOWANCE_HOLDER_QUOTE_ENDPOINT);

        string memory queryParams = string.concat(
            "?sellToken=",
            toChecksumString(sellToken),
            "&buyToken=",
            toChecksumString(buyToken),
            "&sellAmount=",
            sellAmount.toString(),
            "&taker=",
            toChecksumString(taker),
            "&chainId=",
            chainId.toString()
        );

        if (slippageBps > 0) {
            queryParams = string.concat(queryParams, "&slippageBps=", slippageBps.toString());
        }

        if (bytes(excludeSources).length > 0) {
            queryParams = string.concat(queryParams, "&excludeSources=", excludeSources);
        }

        return string.concat(baseUrl, queryParams);
    }

    /// @notice Make API request to 0x using Surl
    /// @param requestUrl The complete request URL
    /// @param zeroExApiKey 0x API key
    /// @return response JSON response string
    function _makeAPIRequest(
        string memory requestUrl,
        string memory zeroExApiKey
    )
        internal
        returns (string memory response)
    {
        console2.log("====0X API REQUEST URL====");
        console2.log(requestUrl);
        console2.log("====0X API REQUEST URL====");

        string[] memory headers = new string[](2);
        headers[0] = string.concat("0x-api-key: ", zeroExApiKey);
        headers[1] = "0x-version: v2";

        (uint256 status, bytes memory data) = requestUrl.get(headers);
        if (status != 200) {
            revert("ZeroExAPIParser: API request failed");
        }

        response = string(data);
        console2.log("====FULL 0X API RESPONSE====");
        console2.log(response);
        console2.log("====FULL 0X API RESPONSE====");
    }

    /// @notice Parse JSON response from 0x API
    /// @param response JSON response string from API
    /// @return quoteResponse Parsed quote data
    function _parseQuoteResponse(string memory response)
        internal
        pure
        returns (ZeroExQuoteResponse memory quoteResponse)
    {
        console2.log("====0X QUOTE RESPONSE====\n");

        // Use fresh slices for each field to avoid slice consumption issues
        quoteResponse.allowanceTarget = _parseAddressField(response.toSlice(), '"allowanceTarget":"');
        quoteResponse.blockNumber = _parseStringField(response.toSlice(), '"blockNumber":"');
        console2.log("blockNumber", quoteResponse.blockNumber);

        quoteResponse.buyAmount = _parseUintField(response.toSlice(), '"buyAmount":"');
        console2.log("buyAmount", quoteResponse.buyAmount);

        quoteResponse.buyToken = _parseAddressField(response.toSlice(), '"buyToken":"');
        console2.log("buyToken", quoteResponse.buyToken);

        quoteResponse.gas = _parseUintField(response.toSlice(), '"gas":"');
        quoteResponse.gasPrice = _parseStringField(response.toSlice(), '"gasPrice":"');

        quoteResponse.minBuyAmount = _parseUintField(response.toSlice(), '"minBuyAmount":"');
        console2.log("minBuyAmount", quoteResponse.minBuyAmount);

        // Parse transaction data from nested object using fresh slice
        string memory transactionDataHex = _parseTransactionData(response.toSlice());
        quoteResponse.transaction = fromHex(transactionDataHex);

        quoteResponse.value = _parseStringField(response.toSlice(), '"value":"');
        quoteResponse.zid = _parseStringField(response.toSlice(), '"zid":"');
        console2.log("====0X QUOTE RESPONSE====\n");
    }

    /// @notice Parse transaction data from nested transaction object
    /// @param jsonSlice JSON slice to parse
    /// @return Transaction data as hex string
    function _parseTransactionData(strings.slice memory jsonSlice) internal pure returns (string memory) {
        // Find the "transaction" object
        strings.slice memory transactionKey = '"transaction":{'.toSlice();
        strings.slice memory afterTransaction = jsonSlice.find(transactionKey).beyond(transactionKey);

        // Find the "data" field within the transaction object
        strings.slice memory dataKey = '"data":"'.toSlice();
        strings.slice memory afterData = afterTransaction.find(dataKey).beyond(dataKey);
        strings.slice memory dataValue = afterData.split('"'.toSlice());

        string memory hexData = dataValue.toString();

        // Check if hex data already starts with 0x
        bytes memory hexBytes = bytes(hexData);
        if (hexBytes.length >= 2 && hexBytes[0] == "0" && hexBytes[1] == "x") {
            return hexData;
        }

        // Add 0x prefix if not present
        return string(abi.encodePacked("0x", hexData));
    }

    /// @notice Parse address field from JSON
    /// @param jsonSlice JSON slice to parse
    /// @param key The key to search for
    /// @return Parsed address
    function _parseAddressField(strings.slice memory jsonSlice, string memory key) internal pure returns (address) {
        strings.slice memory keySlice = key.toSlice();
        strings.slice memory afterKey = jsonSlice.find(keySlice).beyond(keySlice);
        strings.slice memory value = afterKey.split('"'.toSlice());
        return _parseAddress(value.toString());
    }

    /// @notice Parse string field from JSON
    /// @param jsonSlice JSON slice to parse
    /// @param key The key to search for
    /// @return Parsed string value
    function _parseStringField(
        strings.slice memory jsonSlice,
        string memory key
    )
        internal
        pure
        returns (string memory)
    {
        strings.slice memory keySlice = key.toSlice();
        strings.slice memory afterKey = jsonSlice.find(keySlice).beyond(keySlice);
        strings.slice memory value = afterKey.split('"'.toSlice());
        return value.toString();
    }

    /// @notice Parse uint field from JSON
    /// @param jsonSlice JSON slice to parse
    /// @param key The key to search for
    /// @return Parsed uint256 value
    function _parseUintField(strings.slice memory jsonSlice, string memory key) internal pure returns (uint256) {
        strings.slice memory keySlice = key.toSlice();
        strings.slice memory afterKey = jsonSlice.find(keySlice).beyond(keySlice);
        strings.slice memory value = afterKey.split('"'.toSlice());
        return _parseStringToUint(value.toString());
    }

    /// @notice Parse address from hex string
    /// @param addressStr Hex string representation of address
    /// @return Parsed address
    function _parseAddress(string memory addressStr) internal pure returns (address) {
        bytes memory addressBytes = fromHex(addressStr);
        require(addressBytes.length == 20, "ZeroExAPIParser: invalid address length");

        address result;
        assembly {
            result := mload(add(addressBytes, 20))
        }
        return result;
    }

    /*//////////////////////////////////////////////////////////////
                            UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create hook data for 0x swap using API response
    /// @param quoteResponse Response from 0x API
    /// @param dstReceiver Destination receiver (0 for account)
    /// @param usePrevHookAmount Whether to use previous hook amount
    /// @return hookData Encoded hook data for Swap0xV2Hook
    function createHookDataFromQuote(
        ZeroExQuoteResponse memory quoteResponse,
        address dstReceiver,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        uint256 value = _parseStringToUint(quoteResponse.value);

        hookData = abi.encodePacked(
            quoteResponse.buyToken, // bytes 0-20: dstToken
            dstReceiver, // bytes 20-40: dstReceiver
            value, // bytes 40-72: value (ETH)
            usePrevHookAmount ? bytes1(uint8(1)) : bytes1(uint8(0)), // byte 72: usePrevHookAmount
            quoteResponse.transaction // bytes 73+: AllowanceHolder calldata
        );
    }

    /// @notice Parse string number to uint256
    /// @param str String representation of number
    /// @return parsed Parsed uint256 value
    function _parseStringToUint(string memory str) internal pure returns (uint256 parsed) {
        bytes memory b = bytes(str);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint8 digit = uint8(b[i]);
            require(digit >= 48 && digit <= 57, "ZeroExAPIParser: Invalid number string");
            result = result * 10 + (digit - 48);
        }
        return result;
    }
}
