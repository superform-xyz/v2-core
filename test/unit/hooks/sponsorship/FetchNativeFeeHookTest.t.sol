// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { FetchNativeFeeHook } from "../../../../src/hooks/sponsorship/FetchNativeFeeHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { INativeFeeSponsorship } from "../../../../src/interfaces/INativeFeeSponsorship.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { Helpers } from "../../../utils/Helpers.sol";

contract FetchNativeFeeHookTest is Helpers {
    FetchNativeFeeHook public hook;
    address public sponsorshipAddr;
    address public account;
    address public sponsor;

    function setUp() public {
        sponsorshipAddr = makeAddr("sponsorship");
        account = makeAddr("account");
        sponsor = makeAddr("sponsor");
        hook = new FetchNativeFeeHook(sponsorshipAddr);
    }

    /*//////////////////////////////////////////////////////////////
                          Constructor
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(uint8(hook.hookType()), uint8(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SPONSORSHIP(), sponsorshipAddr);
        assertEq(hook.SUB_TYPE(), HookSubTypes.TOKEN);
    }

    function test_Constructor_RevertIf_SponsorshipZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new FetchNativeFeeHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          Build
    //////////////////////////////////////////////////////////////*/

    function test_Build() public view {
        bytes memory data = _createHookData(sponsor, 1 ether);

        // build() wraps with preExecute + postExecute
        Execution[] memory executions = hook.build(address(0), account, data);

        // Should be 3: preExecute + withdrawal + postExecute
        assertEq(executions.length, 3);

        // Middle execution = the withdrawal call
        Execution memory withdrawal = executions[1];
        assertEq(withdrawal.target, sponsorshipAddr);
        assertEq(withdrawal.value, 0);
        assertEq(
            withdrawal.callData,
            abi.encodeCall(INativeFeeSponsorship.withdrawSponsoredNative, (sponsor, 1 ether))
        );
    }

    function test_Build_RevertIf_DataTooShort() public {
        bytes memory shortData = abi.encodePacked(address(0x1)); // only 20 bytes

        vm.expectRevert(FetchNativeFeeHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(0), account, shortData);
    }

    function test_Build_RevertIf_ZeroSponsor() public {
        bytes memory data = _createHookData(address(0), 1 ether);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertIf_ZeroAmount() public {
        bytes memory data = _createHookData(sponsor, 0);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), account, data);
    }

    function test_Build_RevertIf_EmptyData() public {
        vm.expectRevert(FetchNativeFeeHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(0), account, "");
    }

    /*//////////////////////////////////////////////////////////////
                          Inspect
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_ReturnsSponsorshipAddress() public view {
        bytes memory data = _createHookData(sponsor, 1 ether);
        bytes memory result = hook.inspect(data);

        assertEq(result, abi.encodePacked(sponsorshipAddr));
    }

    /*//////////////////////////////////////////////////////////////
                          Helpers
    //////////////////////////////////////////////////////////////*/

    function test_DecodeAmount() public view {
        bytes memory data = _createHookData(sponsor, 1 ether);
        assertEq(hook.decodeAmount(data), 1 ether);
    }

    function test_ReplaceCalldataAmount() public view {
        bytes memory data = _createHookData(sponsor, 1 ether);
        uint256 newAmount = 2e18;
        bytes memory result = hook.replaceCalldataAmount(data, newAmount);
        assertEq(result.length, data.length);
        assertEq(hook.decodeAmount(result), newAmount);
    }

    function testFuzz_ReplaceCalldataAmount(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _createHookData(sponsor, 1 ether);
        bytes memory result = hook.replaceCalldataAmount(data, fuzzAmount);
        assertEq(hook.decodeAmount(result), fuzzAmount);
    }

    function _createHookData(address sponsor_, uint256 amount_) internal pure returns (bytes memory) {
        return abi.encodePacked(sponsor_, amount_);
    }
}
