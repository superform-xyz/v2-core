// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../../../src/periphery/UP/Up.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { MerkleReader } from "./merkle/helper/MerkleReader.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract UpTest is Test, MerkleReader {
    Up public UpToken;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;
    uint256 public constant MINT_CAP_BPS = 200; // 2%
    uint256 public constant DAYS_PER_YEAR = 365 days;
    uint256 public constant INITIAL_MINT_LOCK = 3 * 365 days; // 3 years

    // Error strings for OpenZeppelin errors
    string constant OWNABLE_ERROR = "Ownable: caller is not the owner";
    string constant OWNABLE2STEP_ERROR = "Ownable2Step: caller is not the new owner";

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        // Deploy contract
        UpToken = new Up(owner);

        // Label addresses for better trace output
        vm.label(owner, "Owner");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(user3, "User3");
    }

    /**
     *
     * Constructor Tests
     *
     */
    function test_Constructor() public view {
        assertEq(UpToken.name(), "Superform");
        assertEq(UpToken.symbol(), "UP");
        assertEq(UpToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(UpToken.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(UpToken.owner(), owner);
        assertEq(UpToken.lastMintTimestamp(), block.timestamp);
    }

    /**
     *
     * Minting Tests
     *
     */
    function test_Mint() public {
        // Warp past initial lock period and 1 year
        vm.warp(block.timestamp + INITIAL_MINT_LOCK + DAYS_PER_YEAR);

        uint256 maxMintAmount = (UpToken.totalSupply() * MINT_CAP_BPS) / 10_000;
        UpToken.mint(user1, maxMintAmount);

        assertEq(UpToken.balanceOf(user1), maxMintAmount);
        assertEq(UpToken.totalSupply(), INITIAL_SUPPLY + maxMintAmount);
    }

    function test_MultipleMints() public {
        // First mint after lock period
        vm.warp(block.timestamp + INITIAL_MINT_LOCK + DAYS_PER_YEAR);
        uint256 maxMintAmount = (UpToken.totalSupply() * MINT_CAP_BPS) / 10_000;
        UpToken.mint(user1, maxMintAmount / 2);

        // Warp to next year for second mint
        vm.warp(block.timestamp + DAYS_PER_YEAR);
        // Should be able to mint up to the new max amount (based on new total supply)
        uint256 newMaxMintAmount = (UpToken.totalSupply() * MINT_CAP_BPS) / 10_000;
        UpToken.mint(user2, newMaxMintAmount / 2);

        assertEq(UpToken.balanceOf(user1), maxMintAmount / 2);
        assertEq(UpToken.balanceOf(user2), newMaxMintAmount / 2);
    }

    function test_RevertWhen_MintingBeforeLockPeriod() public {
        // Try to mint just before lock period ends
        vm.warp(block.timestamp + INITIAL_MINT_LOCK - 1);
        vm.expectRevert(abi.encodeWithSignature("InitialLockPeriodNotOver()"));
        UpToken.mint(user1, 1000);
    }

    function test_RevertWhen_MintingTooEarly() public {
        // First warp past lock period
        vm.warp(block.timestamp + INITIAL_MINT_LOCK + DAYS_PER_YEAR);

        // Do an initial mint
        uint256 maxMintAmount = (UpToken.totalSupply() * MINT_CAP_BPS) / 10_000;
        UpToken.mint(user1, maxMintAmount);

        // Try to mint again before a year has passed
        vm.expectRevert(abi.encodeWithSignature("MintingTooEarly()"));
        UpToken.mint(user2, 1000);
    }

    function test_RevertWhen_MintExceedsMaxAmount() public {
        vm.warp(block.timestamp + INITIAL_MINT_LOCK + DAYS_PER_YEAR);
        uint256 maxMintAmount = (UpToken.totalSupply() * MINT_CAP_BPS) / 10_000;
        vm.expectRevert(abi.encodeWithSignature("MintAmountTooHigh()"));
        UpToken.mint(user1, maxMintAmount + 1);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.warp(block.timestamp + DAYS_PER_YEAR);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        UpToken.mint(user1, 1000);
    }

    /**
     *
     * Ownership Tests
     *
     */
    function test_TransferOwnership() public {
        UpToken.transferOwnership(user1);
        assertEq(UpToken.pendingOwner(), user1);

        vm.prank(user1);
        UpToken.acceptOwnership();
        assertEq(UpToken.owner(), user1);
    }

    function test_RevertWhen_NonOwnerTransfersOwnership() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        UpToken.transferOwnership(user2);
    }

    function test_RevertWhen_NonPendingOwnerAcceptsOwnership() public {
        UpToken.transferOwnership(user1);
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user2));
        UpToken.acceptOwnership();
    }

    /**
     *
     * ERC20 Permit Tests
     *
     */
    function test_Permit() public {
        uint256 privateKey = 1;
        address signer = vm.addr(privateKey);

        vm.prank(address(this));
        UpToken.transfer(signer, 1000);

        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = UpToken.nonces(signer);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer,
                user1,
                1000,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", UpToken.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        UpToken.permit(signer, user1, 1000, deadline, v, r, s);

        assertEq(UpToken.allowance(signer, user1), 1000);
        assertEq(UpToken.nonces(signer), 1);
    }
}
