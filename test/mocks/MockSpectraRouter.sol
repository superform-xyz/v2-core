// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockSpectraRouter {
    address public immutable ptToken;

    constructor(address _ptToken) {
        ptToken = _ptToken;
    }

    function execute(bytes calldata, bytes[] calldata) external payable {
        IERC20(ptToken).transfer(msg.sender, 1e6);
    }

    function execute(bytes calldata, bytes[] calldata, uint256) external payable {
        IERC20(ptToken).transfer(msg.sender, 1e6);
    }
}

contract MockSpectraRedeemRouter {
    address public immutable assetToken;
    address public immutable ptToken;

    constructor(address _assetToken, address _ptToken) {
        assetToken = _assetToken;
        ptToken = _ptToken;
    }

    function execute(bytes calldata, bytes[] calldata) external payable {
        uint256 balance = IERC20(ptToken).balanceOf(msg.sender);
        IERC20(ptToken).transferFrom(msg.sender, address(this), balance);
        IERC20(assetToken).transfer(msg.sender, balance);
    }
}
