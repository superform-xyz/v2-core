// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IOdosRouterV2 } from "../../../src/vendor/odos/IOdosRouterV2.sol";
import { IOdosRouterV3 } from "../../../src/vendor/odos/IOdosRouterV3.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";

import { OdosAPIParser } from "./OdosAPIParser.sol";

/// @title OdosV3APIParser
/// @notice Extends OdosAPIParser to decode Odos router calldata (V2 or V3) into a unified V3-compatible struct.
///         When the API returns V2 calldata, the V2 referral code is mapped to V3 referralInfo with fee=0.
abstract contract OdosV3APIParser is OdosAPIParser {
    using BytesLib for bytes;

    struct OdosV3DecodedSwap {
        IOdosRouterV3.swapTokenInfo tokenInfo;
        bytes pathDefinition;
        address executor;
        IOdosRouterV3.swapReferralInfo referralInfo;
    }

    /// @notice Decode swap calldata returned by the Odos API into V3-compatible format.
    ///         Handles both V2 and V3 swap selectors. V2 compact is also supported via the parent parser.
    /// @param txData Raw transaction calldata (with 4-byte selector)
    function decodeOdosV3SwapCalldata(bytes memory txData) internal view returns (OdosV3DecodedSwap memory decoded) {
        if (txData.length < 4) {
            revert("OdosV3APIParser: invalid tx data length");
        }

        bytes4 selector = bytes4(txData.slice(0, 4));
        bytes memory data = txData.slice(4, txData.length - 4);

        if (selector == IOdosRouterV3.swap.selector) {
            // Native V3 calldata
            (decoded.tokenInfo, decoded.pathDefinition, decoded.executor, decoded.referralInfo) =
                abi.decode(data, (IOdosRouterV3.swapTokenInfo, bytes, address, IOdosRouterV3.swapReferralInfo));
        } else if (selector == IOdosRouterV2.swap.selector) {
            // V2 calldata: decode and map to V3 format
            IOdosRouterV2.swapTokenInfo memory v2TokenInfo;
            uint32 referralCode;
            (v2TokenInfo, decoded.pathDefinition, decoded.executor, referralCode) =
                abi.decode(data, (IOdosRouterV2.swapTokenInfo, bytes, address, uint32));

            // Map V2 swapTokenInfo to V3 (identical struct layout)
            decoded.tokenInfo = IOdosRouterV3.swapTokenInfo({
                inputToken: v2TokenInfo.inputToken,
                inputAmount: v2TokenInfo.inputAmount,
                inputReceiver: v2TokenInfo.inputReceiver,
                outputToken: v2TokenInfo.outputToken,
                outputQuote: v2TokenInfo.outputQuote,
                outputMin: v2TokenInfo.outputMin,
                outputReceiver: v2TokenInfo.outputReceiver
            });

            // Map V2 referralCode to V3 referralInfo (no fee)
            decoded.referralInfo = IOdosRouterV3.swapReferralInfo({
                code: uint64(referralCode),
                fee: 0,
                feeRecipient: address(0)
            });
        } else if (selector == IOdosRouterV2.swapCompact.selector) {
            // V2 compact calldata: use parent parser, then convert
            OdosDecodedSwap memory v2Decoded = decodeOdosSwapCalldata(txData);

            decoded.tokenInfo = IOdosRouterV3.swapTokenInfo({
                inputToken: v2Decoded.tokenInfo.inputToken,
                inputAmount: v2Decoded.tokenInfo.inputAmount,
                inputReceiver: v2Decoded.tokenInfo.inputReceiver,
                outputToken: v2Decoded.tokenInfo.outputToken,
                outputQuote: v2Decoded.tokenInfo.outputQuote,
                outputMin: v2Decoded.tokenInfo.outputMin,
                outputReceiver: v2Decoded.tokenInfo.outputReceiver
            });

            decoded.pathDefinition = v2Decoded.pathDefinition;
            decoded.executor = v2Decoded.executor;
            decoded.referralInfo = IOdosRouterV3.swapReferralInfo({
                code: uint64(v2Decoded.referralCode),
                fee: 0,
                feeRecipient: address(0)
            });
        } else {
            revert("OdosV3APIParser: unknown selector");
        }
    }
}
