// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
import { Constants } from "./Constants.sol";

abstract contract Helpers is Test, Constants {
    address public user1;
    address public user2;
    address public MANAGER;
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
        deal(token_, to_, amount_);
    }

    /*//////////////////////////////////////////////////////////////
                                 DEPLOYERS
    //////////////////////////////////////////////////////////////*/

    function _deployAccount(uint256 key_, string memory name_) internal returns (address) {
        address _user = vm.addr(key_);
        vm.deal(_user, LARGE);
        vm.label(_user, name_);
        return _user;
    }

    /*//////////////////////////////////////////////////////////////
                                 HOOK DATA CREATORS
    //////////////////////////////////////////////////////////////*/

    function _createApproveHookData(
        address token,
        address spender,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(token, spender, amount, usePrevHookAmount);
    }

    function _createDepositHookData(
        address receiver,
        bytes32 yieldSourceId,
        address vault,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(receiver, yieldSourceId, vault, amount, usePrevHookAmount);
    }

    function _createWithdrawHookData(
        address receiver,
        bytes32 yieldSourceId,
        address vault,
        address owner,
        uint256 shares,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory hookData)
    {
        hookData = abi.encodePacked(receiver, yieldSourceId, vault, owner, shares, usePrevHookAmount);
    }
}
