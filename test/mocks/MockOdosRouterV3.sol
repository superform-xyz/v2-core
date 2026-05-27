// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IOdosRouterV3 } from "../../src/vendor/odos/IOdosRouterV3.sol";

contract MockOdosRouterV3 {
    function swap(
        IOdosRouterV3.swapTokenInfo memory tokenInfo,
        bytes calldata,
        address,
        IOdosRouterV3.swapReferralInfo memory
    )
        external
        payable
        returns (uint256 amountOut)
    {
        if (tokenInfo.inputToken != address(0)) {
            ERC20(tokenInfo.inputToken).transferFrom(msg.sender, address(this), tokenInfo.inputAmount);
        }

        if (tokenInfo.outputToken != address(0)) {
            ERC20(tokenInfo.outputToken).transfer(
                msg.sender, tokenInfo.outputQuote - (tokenInfo.outputQuote * 50 / 10_000)
            ); // 0.5%
        } else {
            payable(msg.sender).transfer(tokenInfo.outputQuote);
        }

        return tokenInfo.outputMin;
    }

    receive() external payable { }
}
