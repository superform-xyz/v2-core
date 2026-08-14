// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CCTPAdapter } from "../../../src/adapters/CCTPAdapter.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

/// @dev Executor stand-in that records calls and can be toggled to revert / returnbomb / reenter.
contract MockDestinationExecutor {
    bool public shouldRevert;
    bool public shouldReturnbomb;
    bool public shouldReenter;
    address public reentrancyTarget;
    uint256 public callCount;

    address public lastTokenSent;
    address public lastAccount;
    bytes public lastInitData;
    bytes public lastExecutorCalldata;
    bytes public lastSigData;

    function setShouldRevert(bool v) external {
        shouldRevert = v;
    }

    function setShouldReturnbomb(bool v) external {
        shouldReturnbomb = v;
    }

    function setShouldReenter(bool v, address target) external {
        shouldReenter = v;
        reentrancyTarget = target;
    }

    function processBridgedExecution(
        address tokenSent,
        address account,
        address[] memory,
        uint256[] memory,
        bytes memory initData,
        bytes memory executorCalldata,
        bytes memory userSignatureData
    )
        external
    {
        if (shouldReenter) {
            // Attempt to reenter the adapter; nonReentrant must reject it.
            CCTPAdapter(reentrancyTarget).receiveAndExecute("", "");
        }
        if (shouldRevert) {
            if (shouldReturnbomb) revert(string(new bytes(100_000)));
            revert("EXECUTOR_REVERT");
        }
        callCount++;
        lastTokenSent = tokenSent;
        lastAccount = account;
        lastInitData = initData;
        lastExecutorCalldata = executorCalldata;
        lastSigData = userSignatureData;
    }
}

/// @dev MessageTransmitterV2 stand-in: mints a configurable USDC amount to msg.sender (the adapter)
///      and returns a configurable bool from receiveMessage.
contract MockMessageTransmitterV2 {
    MockERC20 public immutable usdc;
    uint256 public mintAmount;
    bool public retval = true;

    constructor(MockERC20 usdc_) {
        usdc = usdc_;
    }

    function setMintAmount(uint256 a) external {
        mintAmount = a;
    }

    function setRetval(bool v) external {
        retval = v;
    }

    function receiveMessage(bytes calldata, bytes calldata) external returns (bool) {
        if (mintAmount > 0) usdc.mint(msg.sender, mintAmount);
        return retval;
    }
}

contract CCTPAdapterUnitTests is Test {
    uint256 internal constant MINT_RECIPIENT_OFFSET = 184;
    uint256 internal constant HOOKDATA_OFFSET = 376;

    CCTPAdapter internal adapter;
    MockMessageTransmitterV2 internal transmitter;
    MockDestinationExecutor internal executor;
    MockERC20 internal usdc;

    address internal account = makeAddr("account");

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        transmitter = new MockMessageTransmitterV2(usdc);
        executor = new MockDestinationExecutor();
        adapter = new CCTPAdapter(address(transmitter), address(usdc), address(executor));
    }

    /*//////////////////////////////////////////////////////////////
                              MESSAGE BUILDER
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a CCTP-V2-shaped message: >= 376 bytes, mintRecipient (bytes32) at offset 184,
    ///      hookData at offset 376. Intermediate bytes are irrelevant to the adapter (the mock
    ///      transmitter ignores them).
    function _buildMessage(address mintRecipient, bytes memory hookData) internal pure returns (bytes memory) {
        bytes memory head = new bytes(HOOKDATA_OFFSET); // 376 zero bytes
        bytes32 recip = bytes32(uint256(uint160(mintRecipient)));
        for (uint256 i; i < 32; ++i) {
            head[MINT_RECIPIENT_OFFSET + i] = recip[i];
        }
        return bytes.concat(head, hookData);
    }

    function _payload(address account_, uint256 intentAmount) internal pure returns (bytes memory) {
        address[] memory dstTokens = new address[](1);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = intentAmount;
        return abi.encode(
            bytes("init"), bytes("exec"), account_, dstTokens, intentAmounts, bytes("sig")
        );
    }

    function _message(address mintRecipient, address account_, uint256 intentAmount)
        internal
        pure
        returns (bytes memory)
    {
        return _buildMessage(mintRecipient, _payload(account_, intentAmount));
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertsOnZero() public {
        vm.expectRevert(CCTPAdapter.ADDRESS_NOT_VALID.selector);
        new CCTPAdapter(address(0), address(usdc), address(executor));
        vm.expectRevert(CCTPAdapter.ADDRESS_NOT_VALID.selector);
        new CCTPAdapter(address(transmitter), address(0), address(executor));
        vm.expectRevert(CCTPAdapter.ADDRESS_NOT_VALID.selector);
        new CCTPAdapter(address(transmitter), address(usdc), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                                HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    function test_ReceiveAndExecute_ForwardsMintedDelta_AndCallsExecutor() public {
        transmitter.setMintAmount(1000e6);
        bytes memory message = _message(address(adapter), account, 1000e6);

        adapter.receiveAndExecute(message, "");

        assertEq(usdc.balanceOf(account), 1000e6, "account funded with minted delta");
        assertEq(usdc.balanceOf(address(adapter)), 0, "adapter holds no residual");
        assertEq(executor.callCount(), 1, "executor called once");
        assertEq(executor.lastTokenSent(), address(usdc), "tokenSent == USDC");
        assertEq(executor.lastAccount(), account, "account forwarded");
        assertEq(executor.lastInitData(), bytes("init"), "initData decoded");
        assertEq(executor.lastExecutorCalldata(), bytes("exec"), "executorCalldata decoded");
        assertEq(executor.lastSigData(), bytes("sig"), "sigData decoded");
    }

    /// @notice INV-2: a donated / pre-seeded adapter balance is never forwarded — only the mint delta.
    function test_DonationProof_OnlyMintDeltaForwarded() public {
        usdc.mint(address(adapter), 5_000_000e6); // large donated buffer
        transmitter.setMintAmount(1e6); // tiny real mint
        bytes memory message = _message(address(adapter), account, 1e6);

        adapter.receiveAndExecute(message, "");

        assertEq(usdc.balanceOf(account), 1e6, "only the 1 USDC delta forwarded, not the donation");
        assertEq(usdc.balanceOf(address(adapter)), 5_000_000e6, "donated buffer untouched");
    }

    /*//////////////////////////////////////////////////////////////
                                 REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_Revert_MessageTooShort() public {
        vm.expectRevert(CCTPAdapter.MESSAGE_TOO_SHORT.selector);
        adapter.receiveAndExecute(new bytes(HOOKDATA_OFFSET - 1), "");
    }

    function test_Revert_MintRecipientMismatch() public {
        bytes memory message = _message(makeAddr("notAdapter"), account, 1e6);
        vm.expectRevert(CCTPAdapter.MINT_RECIPIENT_MISMATCH.selector);
        adapter.receiveAndExecute(message, "");
    }

    function test_Revert_ReceiveMessageFalse() public {
        transmitter.setRetval(false);
        bytes memory message = _message(address(adapter), account, 1e6);
        vm.expectRevert(CCTPAdapter.RECEIVE_MESSAGE_FAILED.selector);
        adapter.receiveAndExecute(message, "");
    }

    function test_Revert_AccountZero() public {
        transmitter.setMintAmount(1e6);
        bytes memory message = _message(address(adapter), address(0), 1e6);
        vm.expectRevert(CCTPAdapter.ACCOUNT_NOT_VALID.selector);
        adapter.receiveAndExecute(message, "");
    }

    /*//////////////////////////////////////////////////////////////
                           EXECUTOR FAILURE
    //////////////////////////////////////////////////////////////*/

    function test_ExecutorRevert_EmitsExecutionFailed_ButFundsDelivered() public {
        transmitter.setMintAmount(1000e6);
        executor.setShouldRevert(true);
        bytes memory message = _message(address(adapter), account, 1000e6);

        vm.expectEmit(true, false, false, false);
        emit CCTPAdapter.ExecutionFailed(account);
        adapter.receiveAndExecute(message, "");

        assertEq(usdc.balanceOf(account), 1000e6, "funds delivered despite executor revert");
        assertEq(executor.callCount(), 0, "executor did not complete");
    }

    function test_ExecutorReturnbomb_DoesNotOOG() public {
        transmitter.setMintAmount(1000e6);
        executor.setShouldRevert(true);
        executor.setShouldReturnbomb(true);
        bytes memory message = _message(address(adapter), account, 1000e6);

        // Should not run out of gas copying the 100KB revert payload (bare catch).
        adapter.receiveAndExecute{ gas: 2_000_000 }(message, "");
        assertEq(usdc.balanceOf(account), 1000e6, "funds delivered");
    }

    function test_ReentrantExecutor_Rejected_ExecutionFailed() public {
        transmitter.setMintAmount(1000e6);
        executor.setShouldReenter(true, address(adapter));
        bytes memory message = _message(address(adapter), account, 1000e6);

        // Reentry into receiveAndExecute hits nonReentrant → reverts → caught → ExecutionFailed.
        vm.expectEmit(true, false, false, false);
        emit CCTPAdapter.ExecutionFailed(account);
        adapter.receiveAndExecute(message, "");
        assertEq(usdc.balanceOf(account), 1000e6, "funds still delivered");
    }

    /*//////////////////////////////////////////////////////////////
                        FAILED TRANSFER + CLAIM
    //////////////////////////////////////////////////////////////*/

    /// @notice A blacklisted/reverting recipient escrows the funds instead of stranding them;
    ///         the recipient can claim once transfers succeed again.
    function test_FailedTransfer_Escrows_ThenClaim() public {
        BlacklistUSDC bl = new BlacklistUSDC();
        BlacklistTransmitter t = new BlacklistTransmitter(bl);
        CCTPAdapter a = new CCTPAdapter(address(t), address(bl), address(executor));
        t.setMintAmount(500e6);
        bl.setBlacklisted(account, true);

        bytes memory message = _message(address(a), account, 500e6);
        vm.expectEmit(true, true, false, true);
        emit CCTPAdapter.TransferFailed(account, address(bl), 500e6);
        a.receiveAndExecute(message, "");

        assertEq(a.failedTransfers(account, address(bl)), 500e6, "escrowed");

        // Recipient claims after being un-blacklisted.
        bl.setBlacklisted(account, false);
        vm.prank(account);
        a.claimFailedTransfer(address(bl), 500e6);
        assertEq(bl.balanceOf(account), 500e6, "claimed");
        assertEq(a.failedTransfers(account, address(bl)), 0, "escrow cleared");
    }

    function test_Claim_Reverts_OnZeroAndInsufficient() public {
        vm.prank(account);
        vm.expectRevert(CCTPAdapter.ZERO_AMOUNT.selector);
        adapter.claimFailedTransfer(address(usdc), 0);

        vm.prank(account);
        vm.expectRevert(CCTPAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        adapter.claimFailedTransfer(address(usdc), 1);
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @notice INV-1/INV-3: exactly the mint delta is delivered; adapter returns to baseline.
    function testFuzz_ExactDelivery(uint256 mintAmount, uint256 donation) public {
        mintAmount = bound(mintAmount, 1, 1e30);
        donation = bound(donation, 0, 1e30);
        usdc.mint(address(adapter), donation);
        transmitter.setMintAmount(mintAmount);

        bytes memory message = _message(address(adapter), account, mintAmount);
        adapter.receiveAndExecute(message, "");

        assertEq(usdc.balanceOf(account), mintAmount, "exact delta delivered");
        assertEq(usdc.balanceOf(address(adapter)), donation, "adapter back to donated baseline");
    }
}

/// @dev USDC-like token with a blacklist that makes transfers to blacklisted accounts return false.
contract BlacklistUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => bool) public blacklisted;

    function setBlacklisted(address a, bool v) external {
        blacklisted[a] = v;
    }

    function mintTo(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (blacklisted[to]) return false;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @dev Transmitter that mints the blacklist token to the adapter on receiveMessage.
contract BlacklistTransmitter {
    BlacklistUSDC public immutable token;
    uint256 public mintAmount;

    constructor(BlacklistUSDC token_) {
        token = token_;
    }

    function setMintAmount(uint256 a) external {
        mintAmount = a;
    }

    function receiveMessage(bytes calldata, bytes calldata) external returns (bool) {
        token.mintTo(msg.sender, mintAmount);
        return true;
    }
}
