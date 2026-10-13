// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { CommonBase } from "forge-std/Base.sol";
import { strings } from "@stringutils/strings.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import { BaseAPIParser } from "./BaseAPIParser.sol";

/// @title BinanceAPIParser
/// @notice Helper for calling the Binance Web3 Trading API (DEX aggregator) from Solidity tests.
/// @dev The API requires an HMAC-signed GET (`X-OC-APIKEY` / `X-OC-TIMESTAMP` / `X-OC-SIGN`), which
///      surl cannot produce, so the request goes through `vm.ffi` → `binance_quote_and_swap.sh`
///      (curl + openssl). The script prints the raw JSON body; this contract extracts `data.tx`.
///      Env: `BINANCE_WEB3_API_KEY`, `BINANCE_WEB3_SECRET_KEY`, optional `BINANCE_WEB3_API_BASE`.
abstract contract BinanceAPIParser is CommonBase, BaseAPIParser {
    using Strings for uint256;
    using strings for *;

    string internal constant BINANCE_API_KEY_ENV = "BINANCE_WEB3_API_KEY";
    string internal constant BINANCE_SECRET_KEY_ENV = "BINANCE_WEB3_SECRET_KEY";
    string internal constant BINANCE_FFI_SCRIPT = "test/utils/parsers/binance_quote_and_swap.sh";

    /// @dev The subset of `data.tx` the hook needs.
    struct BinanceSwapTx {
        address to;
        bytes data;
        uint256 value;
        uint256 minReceiveAmount;
    }

    function binanceCredentialsPresent() internal view returns (bool) {
        return bytes(vm.envOr(BINANCE_API_KEY_ENV, string(""))).length != 0
            && bytes(vm.envOr(BINANCE_SECRET_KEY_ENV, string(""))).length != 0;
    }

    /// @notice GET /api/v1/dex/aggregator/quote-and-swap with `vendor=LiquidMesh` and `enableRfq=false`
    ///         (bStock pairs default to RFQ ON; the AMM hook must never receive RFQ settlement calldata).
    /// @param chainId Binance chain id (56 = BSC)
    /// @param fromToken Sell token
    /// @param toToken Buy token
    /// @param amount Sell amount, smallest unit
    /// @param wallet Transaction sender / receiver
    /// @param slippagePercent e.g. "1" for 1%
    function binanceQuoteAndSwap(
        uint64 chainId,
        address fromToken,
        address toToken,
        uint256 amount,
        address wallet,
        string memory slippagePercent
    )
        internal
        returns (BinanceSwapTx memory swapTx)
    {
        string[] memory cmd = new string[](8);
        cmd[0] = "bash";
        cmd[1] = BINANCE_FFI_SCRIPT;
        cmd[2] = uint256(chainId).toString();
        cmd[3] = toChecksumString(fromToken);
        cmd[4] = toChecksumString(toToken);
        cmd[5] = amount.toString();
        cmd[6] = toChecksumString(wallet);
        cmd[7] = slippagePercent;

        string memory json = string(vm.ffi(cmd));
        // Transport-level failure (no body at all) → callers may SKIP. Everything else is a FAILURE:
        // an API error body, a changed response shape or a parse problem must never read as green.
        if (bytes(json).length == 0) revert EmptyResponse();
        // Error bodies look like {"data":"","code":40101,"timestamp":...,"msg":"Invalid API Key"}
        if (!_contains(json, '"tx":{')) revert ApiError(json);

        swapTx.to = vm.parseAddress(_extractString(json, '"to":"'));
        swapTx.data = fromHex(_extractString(json, '"data":"0x', "0x"));
        swapTx.value = _extractNumber(json, '"value":');
        swapTx.minReceiveAmount = _extractNumber(json, '"minReceiveAmount":');
    }

    /// @notice Transport failure: the ffi command produced no body. The only condition a test may skip on.
    error EmptyResponse();
    /// @notice The API answered without a `tx` object (error body or changed shape).
    error ApiError(string body);
    /// @notice A required numeric field is missing.
    error MissingField(string key);

    /// @dev Reads a JSON number that may be serialised either quoted ("123") or bare (123). Reverts if absent.
    function _extractNumber(string memory json, string memory key) internal pure returns (uint256) {
        strings.slice memory s = json.toSlice();
        if (!s.contains(key.toSlice())) revert MissingField(key);
        s.find(key.toSlice());
        strings.slice memory afterKey = s.beyond(key.toSlice());
        string memory rest = afterKey.toString();
        bytes memory b = bytes(rest);
        uint256 i = 0;
        if (b.length != 0 && b[0] == '"') i = 1; // quoted form
        uint256 value;
        bool any;
        for (; i < b.length; i++) {
            bytes1 c = b[i];
            if (c < "0" || c > "9") break;
            value = value * 10 + (uint8(c) - 48);
            any = true;
        }
        if (!any) revert MissingField(key);
        return value;
    }

    /*//////////////////////////////////////////////////////////////
                              JSON HELPERS
    //////////////////////////////////////////////////////////////*/

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        return haystack.toSlice().contains(needle.toSlice());
    }

    /// @dev Returns the string value following `key` up to the next `"`. Reverts if absent.
    function _extractString(string memory json, string memory key) internal pure returns (string memory) {
        return _extractString(json, key, "");
    }

    function _extractString(
        string memory json,
        string memory key,
        string memory prefix
    )
        internal
        pure
        returns (string memory)
    {
        strings.slice memory s = json.toSlice();
        require(s.contains(key.toSlice()), string.concat("BinanceAPIParser: key not found: ", key));
        s.find(key.toSlice());
        strings.slice memory afterKey = s.beyond(key.toSlice());
        strings.slice memory value = afterKey.split('"'.toSlice());
        return string.concat(prefix, value.toString());
    }

    function _extractUintOr(
        string memory json,
        string memory key,
        uint256 fallbackValue
    )
        internal
        pure
        returns (uint256)
    {
        strings.slice memory s = json.toSlice();
        if (!s.contains(key.toSlice())) return fallbackValue;
        s.find(key.toSlice());
        strings.slice memory afterKey = s.beyond(key.toSlice());
        strings.slice memory value = afterKey.split('"'.toSlice());
        string memory v = value.toString();
        if (bytes(v).length == 0) return fallbackValue;
        return vm.parseUint(v);
    }
}
