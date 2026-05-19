// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { NativeFeeSponsorship } from "../../../src/sponsorship/NativeFeeSponsorship.sol";
import { INativeFeeSponsorship } from "../../../src/interfaces/INativeFeeSponsorship.sol";
import { FetchNativeFeeHook } from "../../../src/hooks/sponsorship/FetchNativeFeeHook.sol";

/// @title MockSponsorshipAccount
/// @notice Minimal ERC-4337 account that validates any UserOp and can execute arbitrary calls
contract MockSponsorshipAccount {
    IEntryPoint public immutable entryPoint;

    constructor(IEntryPoint ep) {
        entryPoint = ep;
    }

    function validateUserOp(
        PackedUserOperation calldata,
        bytes32,
        uint256 missingAccountFunds
    )
        external
        returns (uint256)
    {
        if (missingAccountFunds > 0) {
            (bool ok,) = payable(msg.sender).call{ value: missingAccountFunds }("");
            require(ok, "prefund failed");
        }
        return 0;
    }

    /// @notice Execute arbitrary call — UserOp callData targets this
    function execute(address target, uint256 value, bytes calldata data) external {
        require(msg.sender == address(entryPoint), "only entrypoint");
        (bool ok,) = target.call{ value: value }(data);
        require(ok, "exec failed");
    }

    function doNothing() external { }

    receive() external payable { }
}

/// @title NativeFeeSponsorshipForkTest
/// @notice Fork tests validating the full sponsorNativeAndHandleOps flow through the real ERC-4337 v0.7 EntryPoint
/// @dev Mirrors the pattern in test/integration/paymaster/SuperSponsorshipPaymaster.fork.t.sol
contract NativeFeeSponsorshipForkTest is Test {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address constant ENTRYPOINT_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    IEntryPoint public entryPoint;
    SuperNativePaymaster public paymaster;
    NativeFeeSponsorship public sponsorship;
    FetchNativeFeeHook public fetchHook;

    MockSponsorshipAccount public account;
    MockSponsorshipAccount public account2;

    address public bundler;

    /*//////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        entryPoint = IEntryPoint(ENTRYPOINT_ADDR);

        // Deploy contracts fresh on the fork
        sponsorship = new NativeFeeSponsorship();
        paymaster = new SuperNativePaymaster(entryPoint);
        fetchHook = new FetchNativeFeeHook(address(sponsorship));

        // Deploy mock accounts
        account = new MockSponsorshipAccount(entryPoint);
        account2 = new MockSponsorshipAccount(entryPoint);
        vm.label(address(account), "Account1");
        vm.label(address(account2), "Account2");

        // Setup bundler and fund accounts
        bundler = makeAddr("bundler");
        vm.deal(bundler, 100 ether);
        vm.deal(address(account), 10 ether);
        vm.deal(address(account2), 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
        TEST 1: Full sponsorNativeAndHandleOps flow
    //////////////////////////////////////////////////////////////*/

    /// @notice Bundler → paymaster deposits to sponsorship → EntryPoint processes UserOp
    ///         → account withdraws from sponsorship → paymaster refunds gas
    function test_Fork_SponsorNativeAndHandleOps() public {
        uint256 sponsorAmount = 0.1 ether;
        uint256 gasAmount = 1 ether;

        // Build UserOp that withdraws sponsored ETH during execution
        bytes memory withdrawCall = abi.encodeCall(
            INativeFeeSponsorship.withdrawSponsoredNative, (address(paymaster), sponsorAmount)
        );
        bytes memory callData =
            abi.encodeCall(MockSponsorshipAccount.execute, (address(sponsorship), 0, withdrawCall));

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(address(account), 0, callData);

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] =
            ISuperNativePaymaster.NativeFeeDeposit({ account: address(account), amount: sponsorAmount });

        uint256 accountBalBefore = address(account).balance;
        uint256 bundlerBalBefore = bundler.balance;

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: sponsorAmount + gasAmount }(
            ops, deposits, address(sponsorship)
        );

        // Sponsorship drained
        assertEq(sponsorship.sponsoredAmount(address(paymaster), address(account)), 0, "sponsorship drained");

        // Account received sponsored ETH (may also get gas refund from postOp)
        assertTrue(
            address(account).balance >= accountBalBefore + sponsorAmount, "account received sponsored ETH"
        );

        // Bundler got gas refund (spent less than gasAmount on gas)
        assertTrue(
            bundler.balance > bundlerBalBefore - sponsorAmount - gasAmount, "bundler received gas refund"
        );
    }

    /*//////////////////////////////////////////////////////////////
        TEST 2: Multiple accounts with separate deposits
    //////////////////////////////////////////////////////////////*/

    /// @notice Two accounts with separate deposits, each UserOp withdraws its own sponsorship
    function test_Fork_SponsorNativeAndHandleOps_MultipleAccounts() public {
        uint256 amount1 = 0.1 ether;
        uint256 amount2 = 0.05 ether;
        uint256 gasAmount = 2 ether;

        // Build UserOps — each withdraws its own sponsored ETH
        bytes memory withdrawCall1 = abi.encodeCall(
            INativeFeeSponsorship.withdrawSponsoredNative, (address(paymaster), amount1)
        );
        bytes memory withdrawCall2 = abi.encodeCall(
            INativeFeeSponsorship.withdrawSponsoredNative, (address(paymaster), amount2)
        );

        PackedUserOperation[] memory ops = new PackedUserOperation[](2);
        ops[0] = _buildUserOp(
            address(account),
            0,
            abi.encodeCall(MockSponsorshipAccount.execute, (address(sponsorship), 0, withdrawCall1))
        );
        ops[1] = _buildUserOp(
            address(account2),
            0,
            abi.encodeCall(MockSponsorshipAccount.execute, (address(sponsorship), 0, withdrawCall2))
        );

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](2);
        deposits[0] = ISuperNativePaymaster.NativeFeeDeposit({ account: address(account), amount: amount1 });
        deposits[1] =
            ISuperNativePaymaster.NativeFeeDeposit({ account: address(account2), amount: amount2 });

        uint256 account1BalBefore = address(account).balance;
        uint256 account2BalBefore = address(account2).balance;

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: amount1 + amount2 + gasAmount }(
            ops, deposits, address(sponsorship)
        );

        // Both sponsorships drained
        assertEq(sponsorship.sponsoredAmount(address(paymaster), address(account)), 0);
        assertEq(sponsorship.sponsoredAmount(address(paymaster), address(account2)), 0);

        // Both accounts received their ETH
        assertTrue(address(account).balance >= account1BalBefore + amount1);
        assertTrue(address(account2).balance >= account2BalBefore + amount2);
    }

    /*//////////////////////////////////////////////////////////////
        TEST 3: Empty deposits (backward compat with sponsorship path)
    //////////////////////////////////////////////////////////////*/

    /// @notice No sponsorship deposits, all msg.value goes to gas. UserOp does doNothing().
    function test_Fork_SponsorNativeAndHandleOps_EmptyDeposits() public {
        uint256 gasAmount = 1 ether;

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(
            address(account), 0, abi.encodeWithSelector(MockSponsorshipAccount.doNothing.selector)
        );

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](0);

        uint256 bundlerBalBefore = bundler.balance;

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: gasAmount }(ops, deposits, address(sponsorship));

        // Bundler gets gas refund
        assertTrue(bundler.balance > bundlerBalBefore - gasAmount, "bundler should get refund");
    }

    /*//////////////////////////////////////////////////////////////
        TEST 4: Insufficient native reverts
    //////////////////////////////////////////////////////////////*/

    /// @notice Total deposit amounts exceed msg.value — pre-validation reverts before any ETH is sent
    function test_Fork_SponsorNativeAndHandleOps_InsufficientNative_Reverts() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(
            address(account), 0, abi.encodeWithSelector(MockSponsorshipAccount.doNothing.selector)
        );

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] =
            ISuperNativePaymaster.NativeFeeDeposit({ account: address(account), amount: 5 ether });

        // msg.value (1 ether) < totalNative (5 ether)
        vm.prank(bundler);
        vm.expectRevert(ISuperNativePaymaster.NATIVE_AMOUNT_EXCEEDS_VALUE.selector);
        paymaster.sponsorNativeAndHandleOps{ value: 1 ether }(ops, deposits, address(sponsorship));
    }

    /*//////////////////////////////////////////////////////////////
        TEST 5: Reclaim after handleOps
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit for account via sponsorNativeAndHandleOps, then owner reclaims unused portion
    function test_Fork_ReclaimAfterHandleOps() public {
        uint256 sponsorAmount = 0.5 ether;
        uint256 gasAmount = 1 ether;

        // UserOp does NOT withdraw from sponsorship — leaves deposit for reclaim
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(
            address(account), 0, abi.encodeWithSelector(MockSponsorshipAccount.doNothing.selector)
        );

        ISuperNativePaymaster.NativeFeeDeposit[] memory deposits =
            new ISuperNativePaymaster.NativeFeeDeposit[](1);
        deposits[0] =
            ISuperNativePaymaster.NativeFeeDeposit({ account: address(account), amount: sponsorAmount });

        vm.prank(bundler);
        paymaster.sponsorNativeAndHandleOps{ value: sponsorAmount + gasAmount }(
            ops, deposits, address(sponsorship)
        );

        // Sponsorship retains deposit (account didn't withdraw)
        assertEq(
            sponsorship.sponsoredAmount(address(paymaster), address(account)),
            sponsorAmount,
            "sponsorship retains deposit"
        );

        // Owner reclaims (test contract is the owner since it deployed the paymaster)
        address recipient = makeAddr("recipient");
        paymaster.reclaimSponsorship(
            address(sponsorship), address(account), payable(recipient), sponsorAmount
        );

        assertEq(sponsorship.sponsoredAmount(address(paymaster), address(account)), 0, "drained after reclaim");
        assertEq(recipient.balance, sponsorAmount, "recipient received reclaimed ETH");
    }

    /*//////////////////////////////////////////////////////////////
        TEST 6: handleOps backward compat (no sponsorship)
    //////////////////////////////////////////////////////////////*/

    /// @notice Existing handleOps still works through the real EntryPoint
    function test_Fork_HandleOps_BackwardCompat() public {
        uint256 gasAmount = 1 ether;

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(
            address(account), 0, abi.encodeWithSelector(MockSponsorshipAccount.doNothing.selector)
        );

        uint256 bundlerBalBefore = bundler.balance;

        vm.prank(bundler);
        paymaster.handleOps{ value: gasAmount }(ops);

        // Bundler gets gas refund
        assertTrue(bundler.balance > bundlerBalBefore - gasAmount, "bundler should get refund");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a UserOp for the SuperNativePaymaster with the real EntryPoint.
    ///      paymasterAndData layout:
    ///        [0:20]  paymaster address
    ///        [20:36] paymasterVerificationGasLimit (uint128)
    ///        [36:52] paymasterPostOpGasLimit (uint128)
    ///        [52:]   abi.encode(maxGasLimit, nodeOperatorPremium, postOpGas)
    function _buildUserOp(
        address sender,
        uint256 nonce,
        bytes memory callData_
    )
        internal
        view
        returns (PackedUserOperation memory)
    {
        bytes memory paymasterData = abi.encode(
            uint256(1_000_000), // maxGasLimit
            uint256(0), // nodeOperatorPremium (0%)
            uint256(50_000) // postOpGas
        );
        bytes memory paymasterAndData = abi.encodePacked(
            address(paymaster),
            uint128(500_000), // paymaster verification gas
            uint128(200_000), // paymaster postOp gas
            paymasterData
        );

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: "",
            callData: callData_,
            accountGasLimits: bytes32(abi.encodePacked(uint128(500_000), uint128(500_000))),
            preVerificationGas: 100_000,
            gasFees: bytes32(abi.encodePacked(uint128(2 gwei), uint128(10 gwei))),
            paymasterAndData: paymasterAndData,
            signature: ""
        });
    }
}
