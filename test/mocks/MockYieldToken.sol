// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MockERC20 } from "./MockERC20.sol";

/// @title MockYieldToken
/// @notice Mock YT token that allows configuring the SY and PT addresses for testing
contract MockYieldToken is MockERC20 {
    address public syAddress;
    address public ptAddress;
    bool public syCallShouldFail;
    bool public expired;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    )
        MockERC20(name_, symbol_, decimals_)
    { }

    function setSY(address sy_) external {
        syAddress = sy_;
    }

    function setPT(address pt_) external {
        ptAddress = pt_;
    }

    function setSYCallShouldFail(bool shouldFail_) external {
        syCallShouldFail = shouldFail_;
    }

    function SY() external view override returns (address) {
        require(!syCallShouldFail, "SY call failed");
        return syAddress;
    }

    function PT() external view returns (address) {
        return ptAddress;
    }

    function setExpired(bool expired_) external {
        expired = expired_;
    }

    function isExpired() external view returns (bool) {
        return expired;
    }

    function expiry() external view returns (uint256) {
        if (expired) return block.timestamp - 1;
        return block.timestamp + 100 days;
    }
}
