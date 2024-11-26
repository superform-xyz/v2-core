// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Types } from "./utils/Types.sol";
import { Events } from "./utils/Events.sol";
import { Helpers } from "./utils/Helpers.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { console } from "forge-std/console.sol";

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
}
