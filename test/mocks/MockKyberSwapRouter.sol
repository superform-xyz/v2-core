// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IMetaAggregationRouterV2 } from "../../src/vendor/kyberswap/IMetaAggregationRouterV2.sol";

interface IMintable {
    function mint(address to, uint256 amount) external;
}

contract MockKyberSwapRouter is IMetaAggregationRouterV2 {
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev SUP-21772: when set, the route mints vault shares mid-swap (what a nested SuperVault.deposit does)
    address public midSwapMintVault;
    uint256 public midSwapMintAmount;

    function setMidSwapMint(address vault, uint256 amount) external {
        midSwapMintVault = vault;
        midSwapMintAmount = amount;
    }

    function swap(SwapExecutionParams calldata execution)
        external
        payable
        override
        returns (uint256 returnAmount, uint256 gasUsed)
    {
        address srcToken = address(execution.desc.srcToken);
        address dstToken = address(execution.desc.dstToken);

        if (srcToken != NATIVE) {
            ERC20(srcToken).transferFrom(msg.sender, address(this), execution.desc.amount);
        }

        if (midSwapMintVault != address(0)) IMintable(midSwapMintVault).mint(address(this), midSwapMintAmount);
        // Return 99.5% of minReturnAmount to simulate realistic slippage
        returnAmount = execution.desc.minReturnAmount;

        if (dstToken != NATIVE) {
            ERC20(dstToken).transfer(msg.sender, returnAmount);
        } else {
            payable(msg.sender).transfer(returnAmount);
        }

        gasUsed = 0;
    }
}
