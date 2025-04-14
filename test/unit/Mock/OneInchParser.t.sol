// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Helpers } from "../../utils/Helpers.sol";
import { OneInchAPIParser } from "../../utils/parsers/OneInchAPIParser.sol";
import "forge-std/console2.sol";

contract OneInchParser is Helpers, OneInchAPIParser {
    string authKey;

    function setUp() public {
        authKey = vm.envString(ONE_INCH_API_KEY);
    }

    function test_OneInchAPIParser_SwapCalldataCall() external {
        OneInchSwapCalldataRequest memory request = OneInchSwapCalldataRequest({
            chainId: 1,
            src: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
            dst: 0x111111111117dC0aa78b770fA6A738034120C302,
            amount: 10000000000000000,
            from: address(this),
            origin: address(this),
            slippage: 10
        });

        (string memory dstAmount, string memory txData) = surlCallSwapCalldata(authKey, request);
        console2.log("dstAmount", dstAmount);
        console2.log("txData", txData);
    }

    function test_OneInchAPIParser_GetRouterCall() external {
        string memory spender = surlCallGetRouter(authKey, 1);
        console2.log("spender", spender);
    }   

    function test_OneInchAPIParser_GetApproveCallDataCall() external {
        string memory txData = surlCallGetApproveCallData(authKey, 1, 0x111111111117dC0aa78b770fA6A738034120C302, 10000000000000000);
        console2.log("txData", txData);
    }
}