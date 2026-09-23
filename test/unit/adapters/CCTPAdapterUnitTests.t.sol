// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CCTPAdapter } from "../../../src/adapters/CCTPAdapter.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

/// @dev Executor stand-in that records calls and can be toggled to revert / returnbomb / reenter.
contract MockDestinationExecutor {
    /// @dev CCTPAdapter caches this at construction, mirroring AcrossV3AdapterV2
    address public SUPER_DESTINATION_VALIDATOR = address(0xDA11D);

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
/// @notice A token whose `transfer` returns a 32-byte word that is NOT a valid bool (`2`).
/// @dev `abi.decode(bytes,(bool))` PANICS on this; a length guard alone does not help.
contract NonBoolWordUSDC {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function transfer(address, uint256) external pure returns (uint256) {
        return 2;
    }
}

contract MockMessageTransmitterV2 {
    MockERC20 public immutable usdc;
    /// @dev The token actually minted by receiveMessage (defaults to usdc; a non-USDC CCTP token in R4 tests)
    MockERC20 public mintToken;
    uint256 public mintAmount;
    uint256 public calls;
    bool public retval = true;

    constructor(MockERC20 usdc_) {
        usdc = usdc_;
        mintToken = usdc_;
    }

    function setMintToken(MockERC20 t) external {
        mintToken = t;
    }

    function setMintAmount(uint256 a) external {
        mintAmount = a;
    }

    function setRetval(bool v) external {
        retval = v;
    }

    function receiveMessage(bytes calldata, bytes calldata) external returns (bool) {
        calls++;
        if (mintAmount > 0) mintToken.mint(msg.sender, mintAmount);
        return retval;
    }
}

/// @dev TokenMinterV2 stand-in: (remoteDomain, remoteToken) => local token, with a default for unset keys
///      (the unit message builder leaves sourceDomain and burnToken zeroed).
contract MockTokenMinterV2 {
    address public defaultToken;
    mapping(bytes32 => address) internal registry;

    constructor(address defaultToken_) {
        defaultToken = defaultToken_;
    }

    function setDefault(address t) external {
        defaultToken = t;
    }

    function setLocalToken(uint32 remoteDomain, bytes32 remoteToken, address local) external {
        registry[keccak256(abi.encode(remoteDomain, remoteToken))] = local;
    }

    function getLocalToken(uint32 remoteDomain, bytes32 remoteToken) external view returns (address) {
        address l = registry[keccak256(abi.encode(remoteDomain, remoteToken))];
        return l != address(0) ? l : defaultToken;
    }
}

/// @dev TokenMessengerV2 stand-in exposing `localMinter()` (rotatable like Circle's) and the transmitter it
///      is wired to (the adapter binds the two at construction).
contract MockTokenMessengerV2 {
    address public localMinter;
    address public localMessageTransmitter;

    constructor(address minter_, address transmitter_) {
        localMinter = minter_;
        localMessageTransmitter = transmitter_;
    }

    function setLocalMinter(address m) external {
        localMinter = m;
    }
}

contract CCTPAdapterUnitTests is Test {
    address internal burner = makeAddr("burner");
    uint256 internal constant DESTINATION_CALLER_OFFSET = 108;
    uint256 internal constant RECIPIENT_OFFSET = 76;
    uint256 internal constant BODY_VERSION_OFFSET = 148;
    uint256 internal constant MESSAGE_SENDER_OFFSET = 248;
    uint256 internal constant MINT_RECIPIENT_OFFSET = 184;
    uint256 internal constant AMOUNT_OFFSET = 216;
    uint256 internal constant FEE_EXECUTED_OFFSET = 312;
    uint256 internal constant HOOKDATA_OFFSET = 376;

    CCTPAdapter internal adapter;
    MockMessageTransmitterV2 internal transmitter;
    MockTokenMessengerV2 internal messenger;
    MockTokenMinterV2 internal minter;
    MockDestinationExecutor internal executor;
    MockERC20 internal usdc;

    uint256 internal constant SOURCE_DOMAIN_OFFSET = 4;
    uint256 internal constant BURN_TOKEN_OFFSET = 152;
    /// @dev Source-chain stand-ins; only their (domain, bytes32) registry key matters to the adapter
    uint32 internal constant SRC_DOMAIN = 0;
    address internal constant REMOTE_USDC = address(0xA0B8);
    /// @dev Stand-in for a non-USDC token registered in TokenMinterV2 (live example: USYC, linked on Ethereum's
    ///      minter from BNB domain 17). NOT EURC — Circle routes EURC through a separate CrossChainTokenService
    ///      that never touches TokenMinterV2.
    address internal constant REMOTE_OTHER = address(0xE0C);

    event TransferFailed(address indexed account, address indexed token, uint256 amount);
    event NonUsdcMintEscrowed(address indexed messageSender, address indexed token, uint256 amount);

    address internal account = makeAddr("account");

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        transmitter = new MockMessageTransmitterV2(usdc);
        messenger = _newMessenger(address(usdc), address(transmitter));
        minter = MockTokenMinterV2(messenger.localMinter());
        executor = new MockDestinationExecutor();
        adapter = new CCTPAdapter(address(transmitter), address(messenger), address(usdc), address(executor));
    }

    /// @dev A messenger wired to `transmitter_` and to a fresh minter whose every lookup resolves to `defaultToken`.
    function _newMessenger(address defaultToken, address transmitter_) internal returns (MockTokenMessengerV2) {
        return new MockTokenMessengerV2(address(new MockTokenMinterV2(defaultToken)), transmitter_);
    }

    /// @dev Re-stamps the header recipient (offset 76) for adapters wired to an ad-hoc messenger.
    function _withRecipient(bytes memory message, address handler) internal pure returns (bytes memory) {
        bytes32 h = bytes32(uint256(uint160(handler)));
        for (uint256 i; i < 32; ++i) {
            message[RECIPIENT_OFFSET + i] = h[i];
        }
        return message;
    }

    /// @dev Stamps the header sourceDomain (offset 4) and body burnToken (offset 152) onto a built message.
    function _withBurnToken(
        bytes memory message,
        uint32 domain,
        address remoteToken
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes4 d = bytes4(domain);
        for (uint256 i; i < 4; ++i) {
            message[SOURCE_DOMAIN_OFFSET + i] = d[i];
        }
        bytes32 t = bytes32(uint256(uint160(remoteToken)));
        for (uint256 i; i < 32; ++i) {
            message[BURN_TOKEN_OFFSET + i] = t[i];
        }
        return message;
    }

    /*//////////////////////////////////////////////////////////////
                              MESSAGE BUILDER
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a CCTP-V2-shaped message: >= 376 bytes, mintRecipient (bytes32) at offset 184,
    ///      hookData at offset 376. Intermediate bytes are irrelevant to the adapter (the mock
    ///      transmitter ignores them).
    /// @dev Builds a wire-shaped CCTP V2 message: version=1 at offset 0, mintRecipient at 184,
    ///      amount at 216 and feeExecuted at 312 (the adapter cross-checks its mint delta against
    ///      `amount - feeExecuted`). `amount` defaults high enough not to clamp the delta.
    function _buildMessage(address mintRecipient, bytes memory hookData) internal view returns (bytes memory) {
        return _buildMessageWithAmount(mintRecipient, hookData, type(uint128).max, 0);
    }

    function _buildMessageWithAmount(
        address mintRecipient,
        bytes memory hookData,
        uint256 amount,
        uint256 feeExecuted
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory head = new bytes(HOOKDATA_OFFSET); // 376 bytes

        // MessageV2 header version = 1 (uint32, big-endian, offset 0)
        head[3] = bytes1(uint8(1));
        // BurnMessageV2 body version = 1 (uint32, big-endian, body offset 0 -> absolute 148)
        head[BODY_VERSION_OFFSET + 3] = bytes1(uint8(1));

        bytes32 recip = bytes32(uint256(uint160(mintRecipient)));
        // header recipient = the TokenMessengerV2 the adapter is wired to (a real burn's handler)
        bytes32 handler = bytes32(uint256(uint160(address(messenger))));
        for (uint256 i; i < 32; ++i) {
            head[MINT_RECIPIENT_OFFSET + i] = recip[i];
            // destinationCaller pins to the same adapter, as the SDK must set it
            head[DESTINATION_CALLER_OFFSET + i] = recip[i];
            head[RECIPIENT_OFFSET + i] = handler[i];
        }

        bytes32 sender = bytes32(uint256(uint160(burner)));
        for (uint256 i; i < 32; ++i) {
            head[MESSAGE_SENDER_OFFSET + i] = sender[i];
        }

        bytes32 amt = bytes32(amount);
        bytes32 fee = bytes32(feeExecuted);
        for (uint256 i; i < 32; ++i) {
            head[AMOUNT_OFFSET + i] = amt[i];
            head[FEE_EXECUTED_OFFSET + i] = fee[i];
        }
        return bytes.concat(head, hookData);
    }

    function _payload(address account_, uint256 intentAmount) internal pure returns (bytes memory) {
        address[] memory dstTokens = new address[](1);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = intentAmount;
        return abi.encode(bytes("init"), bytes("exec"), account_, dstTokens, intentAmounts, bytes("sig"));
    }

    function _message(
        address mintRecipient,
        address account_,
        uint256 intentAmount
    )
        internal
        view
        returns (bytes memory)
    {
        return _buildMessage(mintRecipient, _payload(account_, intentAmount));
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertsOnZero() public {
        vm.expectRevert(CCTPAdapter.ADDRESS_NOT_VALID.selector);
        new CCTPAdapter(address(0), address(messenger), address(usdc), address(executor));
        vm.expectRevert(CCTPAdapter.ADDRESS_NOT_VALID.selector);
        new CCTPAdapter(address(transmitter), address(0), address(usdc), address(executor));
        vm.expectRevert(CCTPAdapter.ADDRESS_NOT_VALID.selector);
        new CCTPAdapter(address(transmitter), address(messenger), address(0), address(executor));
        vm.expectRevert(CCTPAdapter.ADDRESS_NOT_VALID.selector);
        new CCTPAdapter(address(transmitter), address(messenger), address(usdc), address(0));
        // a messenger with no minter wired is not a live TokenMessengerV2
        MockTokenMessengerV2 noMinter = new MockTokenMessengerV2(address(0), address(transmitter));
        vm.expectRevert(CCTPAdapter.TOKEN_MESSENGER_NOT_VALID.selector);
        new CCTPAdapter(address(transmitter), address(noMinter), address(usdc), address(executor));
        // REGRESSION (review R5): a live messenger wired to a DIFFERENT transmitter — e.g. a chain where
        // Circle's CREATE2 address differs and something else sits at the expected address — is rejected
        // at deploy time instead of producing an adapter that reverts on every relay.
        MockTokenMessengerV2 otherTransmitter = new MockTokenMessengerV2(address(minter), makeAddr("otherTransmitter"));
        vm.expectRevert(CCTPAdapter.TOKEN_MESSENGER_NOT_VALID.selector);
        new CCTPAdapter(address(transmitter), address(otherTransmitter), address(usdc), address(executor));
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

    /// @notice A zero `account` in hookData must NOT revert — that would permanently destroy the
    ///         bridged USDC, since the message bytes are immutable and the burn is irreversible.
    ///         Instead the mint is escrowed to the attested `messageSender`.
    function test_AccountZero_EscrowsToMessageSender() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _message(address(adapter), address(0), 500e6);

        adapter.receiveAndExecute(message, "");

        assertEq(adapter.failedTransfers(burner, address(usdc)), 500e6, "escrowed to the attested burner");
        assertEq(executor.callCount(), 0, "no execution attempted");

        vm.prank(burner);
        adapter.claimFailedTransfer(address(usdc), 500e6);
        assertEq(usdc.balanceOf(burner), 500e6, "burner recovered the funds");
        assertEq(usdc.balanceOf(address(adapter)), 0, "nothing stranded");
    }

    /// @notice Malformed hookData is likewise escrowed, never reverted.
    function test_MalformedHookData_EscrowsToMessageSender() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _buildMessage(address(adapter), hex"deadbeef"); // undecodable tail

        adapter.receiveAndExecute(message, "");

        assertEq(adapter.failedTransfers(burner, address(usdc)), 500e6, "escrowed to the attested burner");
        assertEq(usdc.balanceOf(address(adapter)), 500e6, "held pending claim, not destroyed");
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
        // Gas limit must exceed MIN_EXECUTION_GAS (2M) plus the mint/transfer overhead consumed
        // before the floor is checked.
        adapter.receiveAndExecute{ gas: 5_000_000 }(message, "");
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
        CCTPAdapter a = new CCTPAdapter(
            address(t), address(_newMessenger(address(bl), address(t))), address(bl), address(executor)
        );
        t.setMintAmount(500e6);
        bl.setBlacklisted(account, true);

        bytes memory message = _withRecipient(_message(address(a), account, 500e6), address(a.TOKEN_MESSENGER()));
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
                    ROUND-3 REVIEW REGRESSIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice REGRESSION (review P2-1): a 32-byte non-boolean return word must escrow, not panic.
    function test_R3_NonBoolReturnWordEscrowsInsteadOfPanicking() public {
        NonBoolWordUSDC weird = new NonBoolWordUSDC();
        MockMessageTransmitterV2 t2 = new MockMessageTransmitterV2(MockERC20(address(weird)));
        CCTPAdapter a = new CCTPAdapter(
            address(t2), address(_newMessenger(address(weird), address(t2))), address(weird), address(executor)
        );
        t2.setMintAmount(500e6);
        bytes memory message = _withRecipient(_message(address(a), account, 500e6), address(a.TOKEN_MESSENGER()));

        a.receiveAndExecute(message, "");

        assertEq(a.failedTransfers(account, address(weird)), 500e6, "escrowed, not panicked");
    }

    /// @notice REGRESSION (review P3-1): hookData naming the adapter itself must escrow to the attested
    ///         burner — a self-transfer would "succeed", credit nothing, and strand the funds forever.
    function test_R3_SelfAccountEscrowsToMessageSender() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _message(address(adapter), address(adapter), 500e6);

        adapter.receiveAndExecute(message, "");

        assertEq(adapter.failedTransfers(burner, address(usdc)), 500e6, "escrowed to the attested burner");
        assertEq(adapter.failedTransfers(address(adapter), address(usdc)), 0, "never credited to self");
        assertEq(executor.callCount(), 0, "no execution attempted");
        vm.prank(burner);
        adapter.claimFailedTransfer(address(usdc), 500e6);
        assertEq(usdc.balanceOf(burner), 500e6, "burner recovered the funds");
    }

    /// @notice An over-mint surplus is credited to the intent ACCOUNT, not the burner, even when they differ.
    function test_R3_SurplusCreditsAccountNotBurner() public {
        bytes memory message = _buildMessageWithAmount(address(adapter), _payload(account, 1), 400e6, 100e6);
        transmitter.setMintAmount(500e6); // 200 surplus over the attested 300

        adapter.receiveAndExecute(message, "");

        assertEq(adapter.failedTransfers(account, address(usdc)), 200e6, "surplus to the account");
        assertEq(adapter.failedTransfers(burner, address(usdc)), 0, "nothing to the burner");
    }

    /// @notice Forward-compat: an unknown header version (2) is a clean revert, not a misparse.
    function test_R3_HeaderVersion2Rejected() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _message(address(adapter), account, 500e6);
        message[3] = bytes1(uint8(2));
        vm.expectRevert(CCTPAdapter.UNSUPPORTED_MESSAGE_VERSION.selector);
        adapter.receiveAndExecute(message, "");
    }

    /// @notice Forward-compat: an unknown body version (2) is a clean revert, not a misparse.
    function test_R3_BodyVersion2Rejected() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _message(address(adapter), account, 500e6);
        message[BODY_VERSION_OFFSET + 3] = bytes1(uint8(2));
        vm.expectRevert(CCTPAdapter.UNSUPPORTED_BODY_VERSION.selector);
        adapter.receiveAndExecute(message, "");
    }

    /// @notice INVARIANT: delivered + surplus == raw mint delta, and delivered == min(delta, amount - fee).
    function testFuzz_R3_ClampInvariant(uint96 amount, uint96 fee, uint96 mint) public {
        vm.assume(fee < amount);
        vm.assume(mint > 0);
        bytes memory message = _buildMessageWithAmount(address(adapter), _payload(account, 1), amount, fee);
        transmitter.setMintAmount(mint);

        adapter.receiveAndExecute(message, "");

        uint256 claimed = uint256(amount) - fee;
        uint256 expectedDelivered = mint < claimed ? mint : claimed;
        assertEq(usdc.balanceOf(account), expectedDelivered, "delivered == min(delta, amount-fee)");
        assertEq(
            usdc.balanceOf(account) + adapter.failedTransfers(account, address(usdc)),
            mint,
            "delivered + surplus == delta"
        );
    }

    /*//////////////////////////////////////////////////////////////
                R5: HEADER RECIPIENT PINNED TO TOKEN MESSENGER
    //////////////////////////////////////////////////////////////*/

    /// @notice REGRESSION (review R5): a Circle-attested NON-burn message (`sendMessage` is permissionless
    ///         and the transmitter dispatches to any recipient) can carry a BurnMessageV2-shaped body the
    ///         sender fully controls. It must be rejected before any external call.
    function test_R5_RecipientNotTokenMessenger_Rejected() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _message(address(adapter), account, 500e6);
        bytes32 attackerHandler = bytes32(uint256(uint160(makeAddr("attackerHandler"))));
        for (uint256 i; i < 32; ++i) {
            message[RECIPIENT_OFFSET + i] = attackerHandler[i];
        }

        vm.expectRevert(CCTPAdapter.RECIPIENT_MISMATCH.selector);
        adapter.receiveAndExecute(message, "");
        assertEq(transmitter.calls(), 0, "rejected before the transmitter is touched");
    }

    /// @notice A zeroed recipient (the field every earlier builder left blank) is rejected too — the pin is
    ///         an equality check against the wired messenger, not a non-zero check.
    function test_R5_ZeroRecipient_Rejected() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _message(address(adapter), account, 500e6);
        for (uint256 i; i < 32; ++i) {
            message[RECIPIENT_OFFSET + i] = 0;
        }
        vm.expectRevert(CCTPAdapter.RECIPIENT_MISMATCH.selector);
        adapter.receiveAndExecute(message, "");
    }

    /*//////////////////////////////////////////////////////////////
                    R4: NON-USDC CCTP TOKEN ROUTING (P2-2)
    //////////////////////////////////////////////////////////////*/

    /// @notice REGRESSION (review P2-2): a message that minted a registered non-USDC CCTP token used to hit
    ///         `NOTHING_MINTED` forever (destinationCaller pins it here) — the burned funds were unrecoverable.
    ///         It must now consume the message and escrow the minted token to the attested burner, unexecuted.
    function test_R4_NonUsdcMint_EscrowedToBurner_NoExecution() public {
        MockERC20 other = new MockERC20("Other CCTP Token", "OTHR", 6);
        minter.setLocalToken(SRC_DOMAIN, bytes32(uint256(uint160(REMOTE_OTHER))), address(other));
        transmitter.setMintToken(other);
        transmitter.setMintAmount(500e6);
        bytes memory message = _withBurnToken(_message(address(adapter), account, 500e6), SRC_DOMAIN, REMOTE_OTHER);

        vm.expectEmit(true, true, false, true, address(adapter));
        emit TransferFailed(burner, address(other), 500e6);
        vm.expectEmit(true, true, false, true, address(adapter));
        emit NonUsdcMintEscrowed(burner, address(other), 500e6);
        adapter.receiveAndExecute(message, "");

        assertEq(transmitter.calls(), 1, "message consumed");
        assertEq(adapter.failedTransfers(burner, address(other)), 500e6, "escrowed to the attested burner");
        assertEq(adapter.failedTransfers(account, address(other)), 0, "intent account not credited");
        assertEq(adapter.failedTransfers(burner, address(usdc)), 0, "nothing under the USDC key");
        assertEq(other.balanceOf(account), 0, "no direct delivery of a non-intent token");
        assertEq(executor.callCount(), 0, "no execution attempted");

        // only the burner can claim, and it gets the minted token back
        vm.prank(account);
        vm.expectRevert(CCTPAdapter.INSUFFICIENT_FAILED_BALANCE.selector);
        adapter.claimFailedTransfer(address(other), 500e6);
        vm.prank(burner);
        adapter.claimFailedTransfer(address(other), 500e6);
        assertEq(other.balanceOf(burner), 500e6, "burner recovered the funds");
        assertEq(other.balanceOf(address(adapter)), 0, "adapter holds nothing");
    }

    /// @notice A pre-existing / donated balance of the minted token is never creditable — delta only.
    function test_R4_NonUsdcMint_DonationNotCreditable() public {
        MockERC20 other = new MockERC20("Other CCTP Token", "OTHR", 6);
        minter.setLocalToken(SRC_DOMAIN, bytes32(uint256(uint160(REMOTE_OTHER))), address(other));
        other.mint(address(adapter), 1000e6); // donation
        transmitter.setMintToken(other);
        transmitter.setMintAmount(500e6);
        bytes memory message = _withBurnToken(_message(address(adapter), account, 500e6), SRC_DOMAIN, REMOTE_OTHER);

        adapter.receiveAndExecute(message, "");

        assertEq(adapter.failedTransfers(burner, address(other)), 500e6, "only the minted delta is credited");
    }

    /// @notice Non-USDC path with a zero delta reverts (nonce unspent), never a silent success.
    function test_R4_NonUsdcMint_ZeroDelta_Reverts() public {
        MockERC20 other = new MockERC20("Other CCTP Token", "OTHR", 6);
        minter.setLocalToken(SRC_DOMAIN, bytes32(uint256(uint160(REMOTE_OTHER))), address(other));
        transmitter.setMintToken(other);
        transmitter.setMintAmount(0);
        bytes memory message = _withBurnToken(_message(address(adapter), account, 500e6), SRC_DOMAIN, REMOTE_OTHER);

        vm.expectRevert(CCTPAdapter.NOTHING_MINTED.selector);
        adapter.receiveAndExecute(message, "");
    }

    /// @notice A (domain, burnToken) pair the minter does not know is rejected BEFORE the transmitter is
    ///         touched — the transmitter's own mint would revert on the same lookup, so nothing is lost and
    ///         the reason is legible.
    function test_R4_UnregisteredBurnToken_RevertsBeforeTransmitter() public {
        minter.setDefault(address(0));
        transmitter.setMintAmount(500e6);
        bytes memory message = _withBurnToken(_message(address(adapter), account, 500e6), SRC_DOMAIN, REMOTE_OTHER);

        vm.expectRevert(CCTPAdapter.UNSUPPORTED_BURN_TOKEN.selector);
        adapter.receiveAndExecute(message, "");
        assertEq(transmitter.calls(), 0, "transmitter never called");
    }

    /// @notice The USDC happy path resolves through the same registry lookup (explicit key, no default).
    function test_R4_UsdcPath_ResolvesThroughRegistry() public {
        minter.setDefault(address(0));
        minter.setLocalToken(SRC_DOMAIN, bytes32(uint256(uint160(REMOTE_USDC))), address(usdc));
        transmitter.setMintAmount(500e6);
        bytes memory message = _withBurnToken(_message(address(adapter), account, 500e6), SRC_DOMAIN, REMOTE_USDC);

        adapter.receiveAndExecute(message, "");

        assertEq(usdc.balanceOf(account), 500e6, "USDC delivered");
        assertEq(executor.callCount(), 1, "executed");
        assertEq(adapter.failedTransfers(burner, address(usdc)), 0, "nothing escrowed");
    }

    /// @notice If Circle has removed the local minter, the relay fails with a legible reason before the
    ///         transmitter is touched (whose own mint would revert "Local minter is not set" anyway).
    function test_R5_MinterRemoved_LegibleRevertBeforeTransmitter() public {
        messenger.setLocalMinter(address(0));
        transmitter.setMintAmount(500e6);
        bytes memory message = _message(address(adapter), account, 500e6);

        vm.expectRevert(CCTPAdapter.TOKEN_MESSENGER_NOT_VALID.selector);
        adapter.receiveAndExecute(message, "");
        assertEq(transmitter.calls(), 0, "transmitter never called");
    }

    /// @notice The minter is read through the messenger at call time, so a Circle minter rotation is honored
    ///         by this immutable adapter without redeploy.
    function test_R4_MinterRotationHonored() public {
        MockERC20 other = new MockERC20("Other CCTP Token", "OTHR", 6);
        MockTokenMinterV2 rotated = new MockTokenMinterV2(address(usdc));
        rotated.setLocalToken(SRC_DOMAIN, bytes32(uint256(uint160(REMOTE_OTHER))), address(other));
        messenger.setLocalMinter(address(rotated)); // old minter still says "default usdc" for this key

        transmitter.setMintToken(other);
        transmitter.setMintAmount(500e6);
        bytes memory message = _withBurnToken(_message(address(adapter), account, 500e6), SRC_DOMAIN, REMOTE_OTHER);

        adapter.receiveAndExecute(message, "");

        assertEq(adapter.failedTransfers(burner, address(other)), 500e6, "routed by the rotated minter");
        assertEq(executor.callCount(), 0, "no execution");
    }

    /*//////////////////////////////////////////////////////////////
                        HARDENING: VERSION + CROSS-CHECK
    //////////////////////////////////////////////////////////////*/

    /// @notice `destinationCaller` must pin to this adapter — a zero/foreign value is rejected fail-fast.
    /// @dev MessageTransmitterV2 enforces the field only when non-zero, and CCTPSendHook:123 checks only
    ///      mintRecipient, so a zero destinationCaller would let ANY caller receive the message straight
    ///      through the transmitter and strand the mint in this adapter.
    function test_Revert_DestinationCallerZero() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _message(address(adapter), account, 500e6);
        for (uint256 i; i < 32; ++i) {
            message[DESTINATION_CALLER_OFFSET + i] = bytes1(0);
        }

        vm.expectRevert(CCTPAdapter.DESTINATION_CALLER_MISMATCH.selector);
        adapter.receiveAndExecute(message, "");
    }

    /// @notice Backstop: a USDC-resolved message whose mint left the USDC delta at zero must revert so the
    ///         mint unwinds (nonce unspent), never succeed with nothing delivered.
    /// @dev Registered non-USDC tokens no longer reach this check — see the R4 tests: they are routed to
    ///      the escrow path by the TokenMinterV2 lookup before `receiveMessage`.
    function test_Revert_NothingMinted() public {
        transmitter.setMintAmount(0);
        bytes memory message = _message(address(adapter), account, 500e6);

        vm.expectRevert(CCTPAdapter.NOTHING_MINTED.selector);
        adapter.receiveAndExecute(message, "");
    }

    /// @notice An over-mint surplus is credited to the account, not silently retained by the adapter.
    function test_CrossCheck_SurplusIsCreditedNotStranded() public {
        bytes memory message = _buildMessageWithAmount(address(adapter), _payload(account, 1), 400e6, 100e6);
        transmitter.setMintAmount(500e6);

        adapter.receiveAndExecute(message, "");

        assertEq(usdc.balanceOf(account), 300e6, "clamped delivery");
        assertEq(adapter.failedTransfers(account, address(usdc)), 200e6, "surplus is claimable");

        vm.prank(account);
        adapter.claimFailedTransfer(address(usdc), 200e6);
        assertEq(usdc.balanceOf(account), 500e6, "surplus recovered");
        assertEq(usdc.balanceOf(address(adapter)), 0, "nothing stranded");
    }

    /// @notice The BurnMessageV2 BODY version is validated separately from the outer header version.
    /// @dev Circle's own audit (ChainSecurity CS-EVM-CCTP2-013) found an underflow in their reference
    ///      CCTPHookWrapper because a non-BurnMessageV2 body could be sliced with BurnMessageV2
    ///      offsets. Every offset this adapter uses assumes that body layout.
    function test_Revert_UnsupportedBodyVersion() public {
        bytes memory message = _message(address(adapter), account, 500e6);
        message[BODY_VERSION_OFFSET + 3] = bytes1(uint8(0)); // body version -> 0

        vm.expectRevert(CCTPAdapter.UNSUPPORTED_BODY_VERSION.selector);
        adapter.receiveAndExecute(message, "");
    }

    /// @notice `checkDestinationTargets` is external only to enable the self-call panic containment;
    ///         it is not a public API. Guard mirrors StargateAdapterV2.handleCompose (:268).
    function test_Revert_CheckDestinationTargets_NotSelfCalled() public {
        vm.expectRevert(CCTPAdapter.INVALID_SENDER.selector);
        adapter.checkDestinationTargets(bytes(""));
    }

    /// @notice CCTP V1 messages (version 0) carry no hookData and must be rejected before any call.
    function test_Revert_UnsupportedMessageVersion() public {
        bytes memory message = _message(address(adapter), account, 500e6);
        // Zero out the 4-byte version field -> V1
        message[3] = bytes1(uint8(0));

        vm.expectRevert(CCTPAdapter.UNSUPPORTED_MESSAGE_VERSION.selector);
        adapter.receiveAndExecute(message, "");
    }

    /// @notice The forwarded amount is clamped by the attested body's own `amount - feeExecuted`,
    ///         so a transmitter that over-mints can never drain escrowed balances.
    function test_CrossCheck_ClampsToAttestedAmount() public {
        // Body claims 300 delivered (400 - 100 fee) but the transmitter mints 500.
        bytes memory message = _buildMessageWithAmount(address(adapter), _payload(account, 1), 400e6, 100e6);
        transmitter.setMintAmount(500e6);

        adapter.receiveAndExecute(message, "");

        assertEq(usdc.balanceOf(account), 300e6, "clamped to attested amount - feeExecuted");
        assertEq(usdc.balanceOf(address(adapter)), 200e6, "surplus retained, not forwarded");
    }

    /// @notice When the mint delta is the smaller of the two, the delta wins.
    function test_CrossCheck_UsesDeltaWhenSmaller() public {
        bytes memory message = _buildMessageWithAmount(address(adapter), _payload(account, 1), 900e6, 0);
        transmitter.setMintAmount(500e6);

        adapter.receiveAndExecute(message, "");

        assertEq(usdc.balanceOf(account), 500e6, "delta wins when smaller than attested claim");
    }

    /*//////////////////////////////////////////////////////////////
                      HARDENING: EXECUTOR/VALIDATOR TARGETS
    //////////////////////////////////////////////////////////////*/

    function _payloadWithProof(
        address account_,
        uint64 chainId,
        address proofExecutor,
        address proofValidator
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory dstTokens = new address[](1);
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1;

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: chainId,
            info: ISuperValidator.DstInfo({
                account: account_,
                executor: proofExecutor,
                dstTokens: dstTokens,
                intentAmounts: intentAmounts,
                validator: proofValidator,
                data: bytes("exec")
            })
        });

        bytes memory sigData =
            abi.encode(new uint64[](0), uint48(0), uint48(0), bytes32(0), new bytes32[](0), proofDst, new bytes(65));
        return abi.encode(bytes("init"), bytes("exec"), account_, dstTokens, intentAmounts, sigData);
    }

    /// @notice A proof naming a different executor delivers funds and SKIPS execution — it must not
    ///         revert, because the CCTP burn is irreversible and the sigData is immutable, so a revert
    ///         would destroy the USDC permanently.
    function test_ExecutorMismatch_DeliversFundsSkipsExecution() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _buildMessage(
            address(adapter),
            _payloadWithProof(account, uint64(block.chainid), address(0xBAD), executor.SUPER_DESTINATION_VALIDATOR())
        );

        adapter.receiveAndExecute(message, "");

        assertEq(usdc.balanceOf(account), 500e6, "funds delivered");
        assertEq(executor.callCount(), 0, "execution skipped");
    }

    /// @notice Same for a mismatched validator: deliver, skip, never revert.
    function test_ValidatorMismatch_DeliversFundsSkipsExecution() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _buildMessage(
            address(adapter), _payloadWithProof(account, uint64(block.chainid), address(executor), address(0xBAD))
        );

        adapter.receiveAndExecute(message, "");

        assertEq(usdc.balanceOf(account), 500e6, "funds delivered");
        assertEq(executor.callCount(), 0, "execution skipped");
    }

    /// @notice A correctly-targeted proof passes the assertion and funds flow normally.
    function test_MatchingProof_Succeeds() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _buildMessage(
            address(adapter),
            _payloadWithProof(account, uint64(block.chainid), address(executor), executor.SUPER_DESTINATION_VALIDATOR())
        );

        adapter.receiveAndExecute(message, "");
        assertEq(usdc.balanceOf(account), 500e6, "funds delivered");
        assertEq(executor.callCount(), 1, "executor called");
    }

    /// @notice A proof for a DIFFERENT chain is not ours to assert on — deliver funds and let the
    ///         executor no-op, matching StargateAdapterV2's graceful NoDstProofForChain handling.
    function test_ProofForOtherChain_SkipsAssertion_StillDelivers() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _buildMessage(
            address(adapter), _payloadWithProof(account, uint64(block.chainid) + 1, address(0xBAD), address(0xBAD))
        );

        adapter.receiveAndExecute(message, "");
        assertEq(usdc.balanceOf(account), 500e6, "funds still delivered");
    }

    /// @notice Malformed sigData must not revert the relay — abi.decode panics are contained by the
    ///         self-call, and the executor's own signature check handles the rest.
    function test_MalformedSigData_DoesNotRevert() public {
        transmitter.setMintAmount(500e6);
        // _payload() uses bytes("sig"), which is non-empty and undecodable as SignatureData.
        bytes memory message = _message(address(adapter), account, 500e6);

        adapter.receiveAndExecute(message, "");
        assertEq(usdc.balanceOf(account), 500e6, "funds delivered despite undecodable sigData");
    }

    /*//////////////////////////////////////////////////////////////
                            HARDENING: GAS FLOOR
    //////////////////////////////////////////////////////////////*/

    /// @notice A permissionless caller must not be able to starve the executor into the catch branch.
    /// @dev Reverting unwinds the mint, so the CCTP nonce is NOT consumed and the message stays
    ///      retriable by a caller supplying enough gas. This is the whole point of the floor.
    function test_Revert_InsufficientGasForExecution() public {
        transmitter.setMintAmount(500e6);
        bytes memory message = _message(address(adapter), account, 500e6);

        // Well below MIN_EXECUTION_GAS: the floor rejects before the executor is attempted.
        vm.expectRevert(CCTPAdapter.INSUFFICIENT_GAS.selector);
        adapter.receiveAndExecute{ gas: 900_000 }(message, "");
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
