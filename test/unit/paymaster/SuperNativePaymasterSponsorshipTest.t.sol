// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { UserOperationLib } from "@account-abstraction/core/UserOperationLib.sol";

// Superform
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { NativeFeeSponsorship } from "../../../src/sponsorship/NativeFeeSponsorship.sol";
import { INativeFeeSponsorship } from "../../../src/interfaces/INativeFeeSponsorship.sol";
import { MockEntryPoint } from "../../mocks/MockEntryPoint.sol";
import { Helpers } from "../../utils/Helpers.sol";

contract SuperNativePaymasterSponsorshipTest is Helpers {
    using UserOperationLib for PackedUserOperation;

    SuperNativePaymaster public paymaster;
    MockEntryPoint public mockEntryPoint;
    NativeFeeSponsorship public sponsorship;
    address public bundler;
    address public smartAccount;

    receive() external payable { }

    function setUp() public {
        mockEntryPoint = new MockEntryPoint();
        sponsorship = new NativeFeeSponsorship();
        paymaster = new SuperNativePaymaster(IEntryPoint(address(mockEntryPoint)));

        bundler = makeAddr("bundler");
        smartAccount = makeAddr("smartAccount");
        vm.deal(bundler, 100 ether);
        vm.deal(address(mockEntryPoint), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    sponsorNativeAndHandleOps
    //////////////////////////////////////////////////////////////*/

    function test_SponsorNativeAndHandleOps() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp(smartAccount);

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: smartAccount, amount: 0.5 ether });

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1.5 ether }(ops, deposits, address(sponsorship));

        // Sponsorship deposit was made by paymaster (paymaster is sponsor of record)
        assertEq(sponsorship.sponsoredAmount(address(paymaster), smartAccount), 0.5 ether);
    }

    function test_SponsorNativeAndHandleOps_MultipleDeposits() public {
        address smartAccount2 = makeAddr("smartAccount2");

        PackedUserOperation[] memory ops = new PackedUserOperation[](2);
        ops[0] = _createUserOp(smartAccount);
        ops[1] = _createUserOp(smartAccount2);

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](2);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: smartAccount, amount: 0.3 ether });
        deposits[1] = ISuperNativePaymaster.NativeFeeDeposit({ account: smartAccount2, amount: 0.2 ether });

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1.5 ether }(ops, deposits, address(sponsorship));

        assertEq(sponsorship.sponsoredAmount(address(paymaster), smartAccount), 0.3 ether);
        assertEq(sponsorship.sponsoredAmount(address(paymaster), smartAccount2), 0.2 ether);
    }

    function test_SponsorNativeAndHandleOps_EmptyDeposits() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp(smartAccount);

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](0);

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1 ether }(ops, deposits, address(sponsorship));

        // All value goes to gas, no sponsorship deposits
        assertEq(sponsorship.sponsoredAmount(address(paymaster), smartAccount), 0);
    }

    function test_SponsorNativeAndHandleOps_EmitsEvent() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp(smartAccount);

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: smartAccount, amount: 0.5 ether });

        vm.expectEmit(true, false, false, true);
        emit ISuperNativePaymaster.SponsorNativeAndHandleOps(bundler, 0.5 ether, 1);

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1.5 ether }(ops, deposits, address(sponsorship));
    }

    function test_SponsorNativeAndHandleOps_RevertIf_NativeAmountExceedsValue() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp(smartAccount);

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: smartAccount, amount: 2 ether });

        vm.expectRevert();
        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1 ether }(ops, deposits, address(sponsorship));
    }

    function test_SponsorNativeAndHandleOps_RevertIf_SponsorshipZero() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp(smartAccount);

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: smartAccount, amount: 0.5 ether });

        vm.expectRevert(ISuperNativePaymaster.INVALID_SPONSORSHIP.selector);
        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1.5 ether }(ops, deposits, address(0));
    }

    function test_SponsorNativeAndHandleOps_RevertIf_TooManyDeposits() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp(smartAccount);

        // Create 51 deposits (exceeds MAX_DEPOSITS = 50)
        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](51);
        for (uint256 i; i < 51; i++) {
            deposits[i] = ISuperNativePaymaster.NativeFeeDeposit({
                account: address(uint160(i + 1)),
                amount: 0.01 ether
            });
        }

        vm.expectRevert(ISuperNativePaymaster.TOO_MANY_DEPOSITS.selector);
        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1 ether }(ops, deposits, address(sponsorship));
    }

    /*//////////////////////////////////////////////////////////////
                       reclaimSponsorship
    //////////////////////////////////////////////////////////////*/

    function test_ReclaimSponsorship() public {
        // 1. Deposit via paymaster
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _createUserOp(smartAccount);

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: smartAccount, amount: 0.5 ether });

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: 1.5 ether }(ops, deposits, address(sponsorship));

        assertEq(sponsorship.sponsoredAmount(address(paymaster), smartAccount), 0.5 ether);

        // 2. Owner reclaims
        address payable recipient = payable(makeAddr("recipient"));
        paymaster.reclaimSponsorship(address(sponsorship), smartAccount, recipient, 0.5 ether);

        assertEq(sponsorship.sponsoredAmount(address(paymaster), smartAccount), 0);
        assertEq(recipient.balance, 0.5 ether);
    }

    function test_ReclaimSponsorship_RevertIf_NotOwner() public {
        vm.expectRevert();
        vm.prank(bundler);
        paymaster.reclaimSponsorship(address(sponsorship), smartAccount, payable(bundler), 0.5 ether);
    }

    function test_ReclaimSponsorship_RevertIf_SponsorshipZero() public {
        vm.expectRevert(ISuperNativePaymaster.INVALID_SPONSORSHIP.selector);
        paymaster.reclaimSponsorship(address(0), smartAccount, payable(bundler), 0.5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                       Backward Compatibility
    //////////////////////////////////////////////////////////////*/

    function test_ExistingHandleOps_StillWorks() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        paymaster.handleOps{ value: 1 ether }(ops);

        assertEq(mockEntryPoint.depositAmount(), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                          Helpers
    //////////////////////////////////////////////////////////////*/

    function _createUserOp(address sender) internal view returns (PackedUserOperation memory) {
        PackedUserOperation memory op;
        op.sender = sender;
        op.nonce = uint256(1);
        op.initCode = "";
        op.callData = "";
        op.accountGasLimits = bytes32(abi.encodePacked(uint128(100_000), uint128(150_000)));
        op.preVerificationGas = 50_000;
        op.gasFees = bytes32(abi.encodePacked(uint128(10 gwei), uint128(5 gwei)));
        op.paymasterAndData = abi.encodePacked(address(paymaster));
        op.signature = "";
        return op;
    }
}
