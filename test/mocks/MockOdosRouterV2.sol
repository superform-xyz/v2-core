// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IOdosRouterV2} from "../../src/vendor/odos/IOdosRouterV2.sol";

import "forge-std/console2.sol";

contract MockOdosRouterV2 {
    function swap(IOdosRouterV2.swapTokenInfo memory tokenInfo, bytes calldata, address, uint32)
        external
        payable
        returns (uint256 amountOut)
    {
        if (tokenInfo.inputToken != address(0)) {
            ERC20(tokenInfo.inputToken).transferFrom(msg.sender, address(this), tokenInfo.inputAmount);
        }

        console2.log("tokenInfo.outputToken", tokenInfo.outputToken);
        if (tokenInfo.outputToken != address(0)) {
            ERC20(tokenInfo.outputToken).transfer(
                msg.sender, tokenInfo.outputQuote - (tokenInfo.outputQuote * 50 / 10_000)
            ); // 0.5%
        } else {
            console2.log(" transferring eth to", msg.sender);
            console2.log("balance of this ", address(this).balance);
            console2.log("Amount to transfer ", tokenInfo.outputQuote);
            payable(msg.sender).transfer(tokenInfo.outputQuote);
            console2.log("transferred eth");
        }

        return tokenInfo.outputMin;
    }

    function swapCompact() external payable returns (uint256) {
        return 0;
    }
}
