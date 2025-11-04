// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MockERC20 } from "./MockERC20.sol";

/// @title MockYieldToken
/// @notice Mock YT token that allows configuring the SY address for testing
contract MockYieldToken is MockERC20 {
    address public syAddress;
    bool public syCallShouldFail;

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

    function setSYCallShouldFail(bool shouldFail_) external {
        syCallShouldFail = shouldFail_;
    }

    function SY() external view override returns (address) {
        require(!syCallShouldFail, "SY call failed");
        return syAddress;
    }
}
