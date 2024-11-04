// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// external

// Superform
import {Types} from "./utils/Types.sol";
import {Events} from "./utils/Events.sol";
import {Helpers} from "./utils/Helpers.sol";
import {Constants} from "./utils/Constants.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";

abstract contract Base_Test is Types, Events, Helpers {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public user1;
    address public user2;

    ERC20Mock public wethMock;
    function setUp() public virtual {
        // deploy accounts
        user1 = _deployAccount(USER1_KEY, "USER1");
        user2 = _deployAccount(USER2_KEY, "USER2");

         // deploy tokens
        wethMock = _deployToken("Wrapped Ether", "WETH", 18);

    }

    modifier calledBy(address from_) {
        _resetCaller(from_);
        _;
    }

    modifier inRange(uint256 _value, uint256 _min, uint256 _max) {
        vm.assume(_value >= _min && _value <= _max);
        _;
    }

    modifier targetApproved(address token_, address target_, address user_, uint256 amount_) {
        approveErc20(token_, user_, target_, amount_);
        _;
    }

}