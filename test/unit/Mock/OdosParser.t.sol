// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.30;

// import { Helpers } from "../../utils/Helpers.sol";
// import { OdosAPIParser } from "../../utils/parsers/OdosAPIParser.sol";
// import "forge-std/console2.sol";

// contract OdosParser is Helpers, OdosAPIParser {
//     function test_OdosAPIParser_QuoteV2Call() external {
//         QuoteInputToken[] memory inputTokens = new QuoteInputToken[](1);
//         inputTokens[0] = QuoteInputToken({ tokenAddress: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, amount: 1e6 });
//         QuoteOutputToken[] memory outputTokens = new QuoteOutputToken[](1);
//         outputTokens[0] = QuoteOutputToken({ tokenAddress: 0xaD55aebc9b8c03FC43cd9f62260391c13c23e7c0, proportion: 1 });

//         string memory pathId = surlCallQuoteV2(inputTokens, outputTokens, address(this), 1, true);
//         console2.log("pathId", pathId);
//     }

//     function test_OdosAPIParser_AssembleCall() external {
//         // get pathId
//         QuoteInputToken[] memory inputTokens = new QuoteInputToken[](1);
//         inputTokens[0] = QuoteInputToken({ tokenAddress: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, amount: 1e6 });
//         QuoteOutputToken[] memory outputTokens = new QuoteOutputToken[](1);
//         outputTokens[0] = QuoteOutputToken({ tokenAddress: 0xaD55aebc9b8c03FC43cd9f62260391c13c23e7c0, proportion: 1 });
//         string memory pathId = surlCallQuoteV2(inputTokens, outputTokens, address(this), 1, true);
//         console2.log("pathId", pathId);

//         // get assemble data
//         string memory swapCompactData = surlCallAssemble(pathId, address(this));
//         console2.log("swapCompactData", swapCompactData);
//     }

//     function test_OdosAPIParser_DecodeCompactSwap() external {
//         // get pathId
//         QuoteInputToken[] memory inputTokens = new QuoteInputToken[](1);
//         inputTokens[0] = QuoteInputToken({ tokenAddress: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, amount: 1e6 });
//         QuoteOutputToken[] memory outputTokens = new QuoteOutputToken[](1);
//         outputTokens[0] = QuoteOutputToken({ tokenAddress: 0xaD55aebc9b8c03FC43cd9f62260391c13c23e7c0, proportion: 1 });
//         string memory pathId = surlCallQuoteV2(inputTokens, outputTokens, address(this), 1, false);

//         // get assemble data
//         string memory swapCompactData = surlCallAssemble(pathId, address(this));
//         //decodeCompactSwap(data);
//         decodeOdosSwapCalldata(fromHex(swapCompactData));
//     }

//     function test_OdosAPIParser_DecodeCompactSwap_Hardcoded() external {
//         // get pathId
//         QuoteInputToken[] memory inputTokens = new QuoteInputToken[](1);
//         inputTokens[0] = QuoteInputToken({ tokenAddress: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, amount: 1e6 });
//         QuoteOutputToken[] memory outputTokens = new QuoteOutputToken[](1);
//         outputTokens[0] = QuoteOutputToken({ tokenAddress: 0xaD55aebc9b8c03FC43cd9f62260391c13c23e7c0, proportion: 1 });
//         string memory pathId = surlCallQuoteV2(inputTokens, outputTokens, address(this), 1, false);

//         // get assemble data
//         string memory swapCompactData = surlCallAssemble(pathId, address(this));
//         decodeOdosSwapCalldata(fromHex(swapCompactData));
//     }
// }
