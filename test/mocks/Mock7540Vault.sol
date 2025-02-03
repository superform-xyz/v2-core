// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { MockERC20 } from "test/mocks/MockERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Mock7540Vault {
    MockERC20 assetToken;
    MockERC20 shareToken;

    constructor(IERC20 asset_, string memory name_, string memory symbol_) {
        if (address(asset_) == address(0)) {
            assetToken = new MockERC20(name_, symbol_, 18);
        } else {
            assetToken = MockERC20(address(asset_));
        }
        shareToken = new MockERC20("Share", "SHARE", 18);
    }

    function share() external view returns (address) {
        return address(shareToken);
    }

    function asset() external view returns (address) {
        return address(assetToken);
    }

    function previewDeposit(
        uint256 amountTokenToDeposit
    )
        external
        pure
        returns (uint256 amountSharesOut)
    {
        amountSharesOut = amountTokenToDeposit;
    }

    function previewRedeem(
        uint256 amountSharesToRedeem
    )
        external
        pure
        returns (uint256 amountTokenOut)
    {
        amountTokenOut = amountSharesToRedeem;
    }
}
