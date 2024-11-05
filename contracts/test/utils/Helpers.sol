// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// external
import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { Constants } from "./Constants.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

abstract contract Helpers is Test, Constants {
    /*//////////////////////////////////////////////////////////////
                                 HELPER METHODS
    //////////////////////////////////////////////////////////////*/
    function _resetCaller(address from_) internal {
        vm.stopPrank();
        vm.startPrank(from_);
    }

    function approveErc20(address token_, address from_, address operator_, uint256 amount_) internal {
        _resetCaller(from_);
        IERC20(token_).approve(operator_, amount_);
    }

    function _getTokens(address token_, address to_, uint256 amount_) internal {
        ERC20Mock(token_).mint(to_, amount_);
    }

    /*//////////////////////////////////////////////////////////////
                                 DEPLOYERS
    //////////////////////////////////////////////////////////////*/
    function _deployToken(string memory name_, string memory symbol_, uint8 decimals_) internal returns (ERC20Mock) {
        ERC20Mock _token = new ERC20Mock(name_, symbol_, decimals_);
        vm.label(address(_token), name_);
        return _token;
    }

    function _deployAccount(uint256 key_, string memory name_) internal returns (address) {
        address _user = vm.addr(key_);
        vm.deal(_user, LARGE);
        vm.label(_user, name_);
        return _user;
    }
}
