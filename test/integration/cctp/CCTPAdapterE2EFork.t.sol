// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { CCTPAdapter } from "../../../src/adapters/CCTPAdapter.sol";
import { IMessageTransmitterV2 } from "@pigeon/cctp/interfaces/IMessageTransmitterV2.sol";

/// @dev CCTP V2 TokenMessenger deposit — void return (the vendored ITokenMessengerV2 declares a
///      `bytes` return used only for abi.encodeCall in hooks; decoding it from a direct call reverts).
interface ITokenMessengerV2Call {
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    )
        external;
}

/// @dev Executor stand-in on the destination fork — records the call the adapter makes.
/// @dev Thin harness exposing the adapter's internal token resolver so it can be driven against the REAL
///      Ethereum TokenMessengerV2 → TokenMinterV2 registry without a live attestation.
contract ResolverHarness is CCTPAdapter {
    constructor(address t, address m, address u, address e) CCTPAdapter(t, m, u, e) { }

    function resolve(bytes calldata message) external view returns (address) {
        return _resolveLocalToken(message);
    }
}

contract MockDestinationExecutor {
    /// @dev CCTPAdapter caches this at construction, mirroring AcrossV3AdapterV2
    address public SUPER_DESTINATION_VALIDATOR = address(0xDA11D);

    uint256 public callCount;
    address public lastAccount;
    address public lastTokenSent;

    function processBridgedExecution(
        address tokenSent,
        address account,
        address[] memory,
        uint256[] memory,
        bytes memory,
        bytes memory,
        bytes memory
    )
        external
    {
        callCount++;
        lastAccount = account;
        lastTokenSent = tokenSent;
    }
}

/// @title CCTPAdapterE2EFork
/// @notice Real-transmitter E2E for CCTPAdapter: a genuine depositForBurnWithHook on Ethereum is
///         relayed through the adapter on Base, proving message-offset parsing + mint delivery +
///         executor dispatch against Circle's actual CCTP V2 contracts.
contract CCTPAdapterE2EFork is Test {
    // CCTP V2 (same addresses on every EVM chain via CREATE2)
    address constant TOKEN_MESSENGER_V2 = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address constant MESSAGE_TRANSMITTER_V2 = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;
    address constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EURC_ETH = 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c;
    // USYC: the one non-USDC token linked in Ethereum's TokenMinterV2 today (from BNB, CCTP domain 17)
    address constant USYC_ETH = 0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b;
    address constant USYC_BNB = 0x8D0fA28f221eB5735BC71d3a0Da67EE5bC821311;
    uint32 constant DOMAIN_BNB = 17;
    uint32 constant DOMAIN_BASE = 6;
    bytes32 constant MESSAGE_SENT_TOPIC = keccak256("MessageSent(bytes)");

    uint256 constant ATTESTER_PK = 0xA11CE;

    uint256 internal ethFork;
    uint256 internal baseFork;

    CCTPAdapter internal adapter;
    MockDestinationExecutor internal executor;

    address internal depositor = makeAddr("depositor");
    address internal account = makeAddr("account");

    function setUp() public {
        baseFork = vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        executor = new MockDestinationExecutor();
        adapter = new CCTPAdapter(MESSAGE_TRANSMITTER_V2, TOKEN_MESSENGER_V2, USDC_BASE, address(executor));

        ethFork = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
    }

    function test_Fork_EthToBase_MintForwardedAndExecutorCalled() public {
        uint256 amount = 1000e6;
        (bytes memory message, bytes memory attestation) = _bridgeToBase(amount);

        uint256 accBefore = IERC20(USDC_BASE).balanceOf(account);

        // permissionless: no prank; the adapter itself is the destinationCaller of receiveMessage
        adapter.receiveAndExecute(message, attestation);

        uint256 delivered = IERC20(USDC_BASE).balanceOf(account) - accBefore;
        assertGt(delivered, 0, "USDC minted and forwarded to account");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter holds no residual");
        assertEq(executor.callCount(), 1, "executor dispatched");
        assertEq(executor.lastAccount(), account, "executor received the attested account");
        assertEq(executor.lastTokenSent(), USDC_BASE, "tokenSent == Base USDC");
    }

    function test_Fork_ReplayedMessage_Reverts() public {
        (bytes memory message, bytes memory attestation) = _bridgeToBase(1000e6);

        adapter.receiveAndExecute(message, attestation);

        // CCTP usedNonces: the same attested message cannot be received twice
        vm.expectRevert("Nonce already used");
        adapter.receiveAndExecute(message, attestation);
    }

    function test_Fork_BadAttestation_Reverts() public {
        (bytes memory message,) = _bridgeToBase(1000e6);

        // signed by a key that is not an enabled attester
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(0xBAD), keccak256(message));
        vm.expectRevert("Invalid signature: not attester");
        adapter.receiveAndExecute(message, abi.encodePacked(r, s, v));
    }

    /// @notice The (sourceDomain, burnToken) lookup runs against the REAL TokenMessengerV2 -> TokenMinterV2
    ///         on Base. Ethereum EURC is not registered on the mainnet minter (verified live:
    ///         getLocalToken(0, EURC_ETH) == 0 — Circle routes EURC through a separate CrossChainTokenService,
    ///         never through TokenMinterV2), so such a message must be rejected BEFORE the transmitter
    ///         is touched. Ordering is what this proves: if the lookup did not run first, the tampered
    ///         message would fail attestation ("Invalid signature") instead.
    function test_Fork_UnregisteredBurnToken_RejectedBeforeTransmitter() public {
        (bytes memory message, bytes memory attestation) = _bridgeToBase(1000e6);

        bytes32 eurc = bytes32(uint256(uint160(EURC_ETH)));
        for (uint256 i; i < 32; ++i) {
            message[152 + i] = eurc[i]; // BurnMessageV2.burnToken (148 + 4)
        }
        vm.expectRevert(CCTPAdapter.UNSUPPORTED_BURN_TOKEN.selector);
        adapter.receiveAndExecute(message, attestation);
    }

    /// @notice A real attested burn whose header recipient is rewritten to a non-TokenMessenger address is
    ///         rejected by the adapter's recipient pin BEFORE the transmitter (which would otherwise fail
    ///         attestation on the tampered bytes). Ordering is what this proves.
    function test_Fork_RecipientNotTokenMessenger_RejectedBeforeTransmitter() public {
        (bytes memory message, bytes memory attestation) = _bridgeToBase(1000e6);

        bytes32 other = bytes32(uint256(uint160(makeAddr("notTheMessenger"))));
        for (uint256 i; i < 32; ++i) {
            message[76 + i] = other[i]; // MessageV2.recipient
        }
        vm.expectRevert(CCTPAdapter.RECIPIENT_MISMATCH.selector);
        adapter.receiveAndExecute(message, attestation);
    }

    /// @notice Against the REAL Ethereum registry: a message burning USYC on BNB (domain 17) resolves to
    ///         Ethereum USYC — i.e. the non-USDC escrow branch is the path taken today, not forward-protection —
    ///         while the USDC pair resolves to USDC and an unlinked pair (EURC, which Circle routes through a
    ///         separate CrossChainTokenService) is rejected.
    function test_Fork_Ethereum_RealRegistry_RoutesUsycToNonUsdcBranch() public {
        vm.selectFork(ethFork);
        // the fixture executor lives on the Base fork; the harness needs one on this fork for its constructor
        MockDestinationExecutor ethExecutor = new MockDestinationExecutor();
        ResolverHarness h =
            new ResolverHarness(MESSAGE_TRANSMITTER_V2, TOKEN_MESSENGER_V2, USDC_ETH, address(ethExecutor));

        assertEq(h.resolve(_headerFor(h, DOMAIN_BNB, USYC_BNB)), USYC_ETH, "USYC from BNB -> Ethereum USYC");
        assertEq(h.resolve(_headerFor(h, DOMAIN_BASE, USDC_BASE)), USDC_ETH, "USDC from Base -> Ethereum USDC");
        vm.expectRevert(CCTPAdapter.UNSUPPORTED_BURN_TOKEN.selector);
        h.resolve(_headerFor(h, DOMAIN_BASE, EURC_ETH));
    }

    /// @dev Minimal wire-shaped message: versions, sourceDomain, header recipient = TokenMessengerV2, and burnToken.
    function _headerFor(CCTPAdapter a, uint32 sourceDomain, address burnToken) internal pure returns (bytes memory m) {
        m = new bytes(376);
        m[3] = bytes1(uint8(1)); // header version
        m[151] = bytes1(uint8(1)); // body version
        bytes4 d = bytes4(sourceDomain);
        for (uint256 i; i < 4; ++i) {
            m[4 + i] = d[i];
        }
        bytes32 recipient = bytes32(uint256(uint160(TOKEN_MESSENGER_V2)));
        bytes32 self = bytes32(uint256(uint160(address(a))));
        bytes32 bt = bytes32(uint256(uint160(burnToken)));
        for (uint256 i; i < 32; ++i) {
            m[76 + i] = recipient[i];
            m[108 + i] = self[i]; // destinationCaller
            m[152 + i] = bt[i]; // burnToken
            m[184 + i] = self[i]; // mintRecipient
        }
    }

    function test_Fork_TamperedHookData_Reverts() public {
        (bytes memory message, bytes memory attestation) = _bridgeToBase(1000e6);

        // flip one byte in the hookData tail: the attestation no longer covers the message
        message[400] = message[400] == 0xff ? bytes1(0x00) : bytes1(0xff);
        vm.expectRevert("Invalid signature: not attester");
        adapter.receiveAndExecute(message, attestation);
    }

    /// @dev Runs the full source leg on the Ethereum fork (real depositForBurnWithHook with
    ///      mintRecipient = destinationCaller = adapter), then switches to the Base fork, installs
    ///      the test attester, and finalizes + signs the message. Leaves the Base fork selected.
    function _bridgeToBase(uint256 amount) internal returns (bytes memory message, bytes memory attestation) {
        vm.selectFork(ethFork);
        deal(USDC_ETH, depositor, amount);

        bytes memory hookData = _payload(account, amount);
        bytes32 adapterB32 = bytes32(uint256(uint160(address(adapter))));

        vm.prank(depositor);
        IERC20(USDC_ETH).approve(TOKEN_MESSENGER_V2, amount);

        vm.recordLogs();
        vm.prank(depositor);
        ITokenMessengerV2Call(TOKEN_MESSENGER_V2)
            .depositForBurnWithHook(
                amount,
                DOMAIN_BASE,
                adapterB32, // mintRecipient = adapter
                USDC_ETH,
                adapterB32, // destinationCaller = adapter
                0, // maxFee (finalized)
                2000, // minFinalityThreshold = finalized
                hookData
            );

        message = _extractMessageSent(vm.getRecordedLogs());
        assertGt(message.length, 376, "message carries hookData tail");

        vm.selectFork(baseFork);
        _installAttester();
        _setNonce(message); // attestation service normally assigns the nonce (emitted as 0)
        _setFinalityExecuted(message); // attestation service normally fills this
        attestation = _sign(message);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _payload(address account_, uint256 amount) internal pure returns (bytes memory) {
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = USDC_BASE;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = amount;
        return abi.encode(bytes("init"), bytes("exec"), account_, dstTokens, intentAmounts, bytes("sig"));
    }

    function _extractMessageSent(Vm.Log[] memory logs) internal pure returns (bytes memory) {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 0) continue;
            if (logs[i].topics[0] == MESSAGE_SENT_TOPIC) {
                return abi.decode(logs[i].data, (bytes));
            }
        }
        revert("no MessageSent");
    }

    function _installAttester() internal {
        IMessageTransmitterV2 t = IMessageTransmitterV2(MESSAGE_TRANSMITTER_V2);
        address mgr = t.attesterManager();
        address attester = vm.addr(ATTESTER_PK);
        vm.startPrank(mgr);
        if (!t.isEnabledAttester(attester)) t.enableAttester(attester);
        t.setSignatureThreshold(1);
        vm.stopPrank();
    }

    /// @dev In production the attestation service assigns the nonce (the source event emits it as 0);
    ///      on a fork we stamp a message-derived unique value. Header offset 12 (after version +
    ///      sourceDomain + destinationDomain), 32 bytes.
    function _setNonce(bytes memory message) internal pure {
        require(message.length >= 44, "short");
        bytes32 nonce = keccak256(message);
        assembly {
            mstore(add(message, 44), nonce) // 32 (len prefix) + 12
        }
    }

    /// @dev In production the attestation service fills finalityThresholdExecuted; on a fork we set it
    ///      to minFinalityThreshold so receiveMessage accepts the message. Offsets: 140 = min, 144 = executed.
    function _setFinalityExecuted(bytes memory message) internal pure {
        require(message.length >= 148, "short");
        assembly {
            let minFinality := shr(224, mload(add(message, 172))) // 32 (skip len) + 140
            let word := mload(add(message, 176)) // 32 + 144
            // clear top 4 bytes then OR in minFinality
            word := or(
                and(word, 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff),
                shl(224, minFinality)
            )
            mstore(add(message, 176), word)
        }
    }

    function _sign(bytes memory message) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ATTESTER_PK, digest);
        return abi.encodePacked(r, s, v);
    }
}
