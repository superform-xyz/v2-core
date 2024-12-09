// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// external
import { AccountInstance } from "modulekit/ModuleKit.sol";

import { Types } from "./utils/Types.sol";
import { Events } from "./utils/Events.sol";
import { Helpers } from "./utils/Helpers.sol";

abstract contract BaseTest is Types, Events, Helpers {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public user1;
    address public user2;

    uint256 public mainnetFork;
    uint256 public arbitrumFork;
    string public mainnetUrl = vm.envString("ETHEREUM_RPC_URL");
    string public arbitrumUrl = vm.envString("ARBITRUM_RPC_URL");

    function setUp() public virtual {
        arbitrumFork = vm.createSelectFork(arbitrumUrl);
        mainnetFork = vm.createSelectFork(mainnetUrl);

        // deploy accounts
        user1 = _deployAccount(USER1_KEY, "USER1");
        user2 = _deployAccount(USER2_KEY, "USER2");
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/
    function _bound(uint256 amount_) internal pure returns (uint256) {
        amount_ = bound(amount_, SMALL, LARGE);
        return amount_;
    }

    /*//////////////////////////////////////////////////////////////
                                 MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier inRange(uint256 amount_) {
        vm.assume(amount_ > SMALL && amount_ <= LARGE);
        _;
    }

    modifier whenAccountHasTokens(AccountInstance memory instance_, address token_) {
        _getTokens(token_, instance_.account, EXTRA_LARGE);
        _;
    }
}
