// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IOdosRouterV2 } from "../../src/core/interfaces/vendors/odos/IOdosRouterV2.sol";

contract MockOdosRouterV2 {
    function swap(
        IOdosRouterV2.swapTokenInfo memory tokenInfo,
        bytes calldata,
        address,
        uint32
    )
        external
        payable
        returns (uint256 amountOut)
    {
        ERC20(tokenInfo.inputToken).transferFrom(msg.sender, address(this), tokenInfo.inputAmount);
        ERC20(tokenInfo.outputToken).transfer(msg.sender, tokenInfo.outputMin);

        return tokenInfo.outputMin;
    }
}
