// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { NativeFeeSponsorship } from "../../../src/sponsorship/NativeFeeSponsorship.sol";
import { INativeFeeSponsorship } from "../../../src/interfaces/INativeFeeSponsorship.sol";
import { Helpers } from "../../utils/Helpers.sol";

contract NativeFeeSponsorshipTest is Helpers {
    NativeFeeSponsorship public sponsorship;
    address public sponsor;
    address public account;

    receive() external payable { }

    function setUp() public {
        sponsorship = new NativeFeeSponsorship();
        sponsor = makeAddr("sponsor");
        account = makeAddr("account");
        vm.deal(address(this), 100 ether);
        vm.deal(sponsor, 100 ether);
        vm.deal(account, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          depositForAccount
    //////////////////////////////////////////////////////////////*/

    function test_DepositForAccount() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        assertEq(sponsorship.sponsoredAmount(sponsor, account), 1 ether);
        assertEq(address(sponsorship).balance, 1 ether);
    }

    function test_DepositForAccount_MultipleDeposits() public {
        vm.startPrank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);
        sponsorship.depositForAccount{ value: 2 ether }(sponsor, account);
        vm.stopPrank();

        assertEq(sponsorship.sponsoredAmount(sponsor, account), 3 ether);
        assertEq(address(sponsorship).balance, 3 ether);
    }

    function test_DepositForAccount_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit INativeFeeSponsorship.NativeDeposited(sponsor, account, 1 ether);

        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);
    }

    function test_DepositForAccount_RevertIf_ZeroSponsor() public {
        vm.expectRevert(INativeFeeSponsorship.ZERO_ADDRESS.selector);
        sponsorship.depositForAccount{ value: 1 ether }(address(0), account);
    }

    function test_DepositForAccount_RevertIf_ZeroAccount() public {
        vm.expectRevert(INativeFeeSponsorship.ZERO_ADDRESS.selector);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, address(0));
    }

    function test_DepositForAccount_RevertIf_ZeroValue() public {
        vm.expectRevert(INativeFeeSponsorship.ZERO_AMOUNT.selector);
        sponsorship.depositForAccount{ value: 0 }(sponsor, account);
    }

    function test_DepositForAccount_ThirdPartyCanDepositOnBehalfOfSponsor() public {
        address intermediary = makeAddr("intermediary");
        vm.deal(intermediary, 10 ether);

        vm.prank(intermediary);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        assertEq(sponsorship.sponsoredAmount(sponsor, account), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                       withdrawSponsoredNative
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawSponsoredNative() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        uint256 accountBalBefore = account.balance;

        vm.prank(account);
        sponsorship.withdrawSponsoredNative(sponsor, 1 ether);

        assertEq(sponsorship.sponsoredAmount(sponsor, account), 0);
        assertEq(account.balance, accountBalBefore + 1 ether);
        assertEq(address(sponsorship).balance, 0);
    }

    function test_WithdrawSponsoredNative_Partial() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 2 ether }(sponsor, account);

        vm.prank(account);
        sponsorship.withdrawSponsoredNative(sponsor, 1 ether);

        assertEq(sponsorship.sponsoredAmount(sponsor, account), 1 ether);
        assertEq(address(sponsorship).balance, 1 ether);
    }

    function test_WithdrawSponsoredNative_EmitsEvent() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        vm.expectEmit(true, true, false, true);
        emit INativeFeeSponsorship.NativeWithdrawnByAccount(sponsor, account, 1 ether);

        vm.prank(account);
        sponsorship.withdrawSponsoredNative(sponsor, 1 ether);
    }

    function test_WithdrawSponsoredNative_RevertIf_InsufficientBalance() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        vm.expectRevert(INativeFeeSponsorship.INSUFFICIENT_SPONSORED_BALANCE.selector);
        vm.prank(account);
        sponsorship.withdrawSponsoredNative(sponsor, 2 ether);
    }

    function test_WithdrawSponsoredNative_RevertIf_ZeroAmount() public {
        vm.expectRevert(INativeFeeSponsorship.ZERO_AMOUNT.selector);
        vm.prank(account);
        sponsorship.withdrawSponsoredNative(sponsor, 0);
    }

    function test_WithdrawSponsoredNative_RevertIf_WrongAccount() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        address wrongAccount = makeAddr("wrongAccount");
        vm.expectRevert(INativeFeeSponsorship.INSUFFICIENT_SPONSORED_BALANCE.selector);
        vm.prank(wrongAccount);
        sponsorship.withdrawSponsoredNative(sponsor, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                       withdrawSponsorDeposit
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawSponsorDeposit() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        uint256 sponsorBalBefore = sponsor.balance;

        vm.prank(sponsor);
        sponsorship.withdrawSponsorDeposit(account, payable(sponsor), 1 ether);

        assertEq(sponsorship.sponsoredAmount(sponsor, account), 0);
        assertEq(sponsor.balance, sponsorBalBefore + 1 ether);
    }

    function test_WithdrawSponsorDeposit_ToThirdParty() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        address payable thirdParty = payable(makeAddr("thirdParty"));

        vm.prank(sponsor);
        sponsorship.withdrawSponsorDeposit(account, thirdParty, 1 ether);

        assertEq(sponsorship.sponsoredAmount(sponsor, account), 0);
        assertEq(thirdParty.balance, 1 ether);
    }

    function test_WithdrawSponsorDeposit_EmitsEvent() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        vm.expectEmit(true, true, true, true);
        emit INativeFeeSponsorship.NativeWithdrawnBySponsor(sponsor, account, sponsor, 1 ether);

        vm.prank(sponsor);
        sponsorship.withdrawSponsorDeposit(account, payable(sponsor), 1 ether);
    }

    function test_WithdrawSponsorDeposit_RevertIf_InsufficientBalance() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        vm.expectRevert(INativeFeeSponsorship.INSUFFICIENT_SPONSORED_BALANCE.selector);
        vm.prank(sponsor);
        sponsorship.withdrawSponsorDeposit(account, payable(sponsor), 2 ether);
    }

    function test_WithdrawSponsorDeposit_RevertIf_ZeroAmount() public {
        vm.expectRevert(INativeFeeSponsorship.ZERO_AMOUNT.selector);
        vm.prank(sponsor);
        sponsorship.withdrawSponsorDeposit(account, payable(sponsor), 0);
    }

    function test_WithdrawSponsorDeposit_RevertIf_ZeroAccount() public {
        vm.expectRevert(INativeFeeSponsorship.ZERO_ADDRESS.selector);
        vm.prank(sponsor);
        sponsorship.withdrawSponsorDeposit(address(0), payable(sponsor), 1 ether);
    }

    function test_WithdrawSponsorDeposit_RevertIf_ZeroTo() public {
        vm.expectRevert(INativeFeeSponsorship.ZERO_ADDRESS.selector);
        vm.prank(sponsor);
        sponsorship.withdrawSponsorDeposit(account, payable(address(0)), 1 ether);
    }

    function test_WithdrawSponsorDeposit_RevertIf_WrongSponsor() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);

        address wrongSponsor = makeAddr("wrongSponsor");
        vm.expectRevert(INativeFeeSponsorship.INSUFFICIENT_SPONSORED_BALANCE.selector);
        vm.prank(wrongSponsor);
        sponsorship.withdrawSponsorDeposit(account, payable(wrongSponsor), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          sponsoredAmount
    //////////////////////////////////////////////////////////////*/

    function test_SponsoredAmount_DefaultZero() public view {
        assertEq(sponsorship.sponsoredAmount(sponsor, account), 0);
    }

    /*//////////////////////////////////////////////////////////////
                          Edge Cases
    //////////////////////////////////////////////////////////////*/

    function test_MultipleSponsorsForSameAccount() public {
        address sponsor2 = makeAddr("sponsor2");
        vm.deal(sponsor2, 100 ether);

        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);
        vm.prank(sponsor2);
        sponsorship.depositForAccount{ value: 2 ether }(sponsor2, account);

        assertEq(sponsorship.sponsoredAmount(sponsor, account), 1 ether);
        assertEq(sponsorship.sponsoredAmount(sponsor2, account), 2 ether);
    }

    function test_SameSponsorMultipleAccounts() public {
        address account2 = makeAddr("account2");

        vm.startPrank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, account);
        sponsorship.depositForAccount{ value: 2 ether }(sponsor, account2);
        vm.stopPrank();

        assertEq(sponsorship.sponsoredAmount(sponsor, account), 1 ether);
        assertEq(sponsorship.sponsoredAmount(sponsor, account2), 2 ether);
    }

    function test_SponsorIsSameAsAccount() public {
        vm.prank(sponsor);
        sponsorship.depositForAccount{ value: 1 ether }(sponsor, sponsor);

        assertEq(sponsorship.sponsoredAmount(sponsor, sponsor), 1 ether);

        vm.prank(sponsor);
        sponsorship.withdrawSponsoredNative(sponsor, 1 ether);

        assertEq(sponsorship.sponsoredAmount(sponsor, sponsor), 0);
    }

    function test_RejectDirectETH() public {
        (bool success,) = address(sponsorship).call{ value: 1 ether }("");
        assertFalse(success);
    }
}
