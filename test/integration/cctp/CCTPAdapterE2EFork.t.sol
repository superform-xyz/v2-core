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
    ) external;
}

/// @dev Executor stand-in on the destination fork — records the call the adapter makes.
contract MockDestinationExecutor {
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
        adapter = new CCTPAdapter(MESSAGE_TRANSMITTER_V2, USDC_BASE, address(executor));

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
        ITokenMessengerV2Call(TOKEN_MESSENGER_V2).depositForBurnWithHook(
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
            word := or(and(word, 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff), shl(224, minFinality))
            mstore(add(message, 176), word)
        }
    }

    function _sign(bytes memory message) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ATTESTER_PK, digest);
        return abi.encodePacked(r, s, v);
    }
}
