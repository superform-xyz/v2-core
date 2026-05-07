// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ApproveAndCCTPSendHook } from "../../../src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol";
import { ITokenMessengerV2 } from "../../../src/vendor/bridges/cctp/ITokenMessengerV2.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { Helpers } from "../../utils/Helpers.sol";

import { Vm } from "forge-std/Vm.sol";
import "forge-std/console2.sol";
import { CctpV2Helper } from "@pigeon/cctp/CctpV2Helper.sol";

/// @dev Mock signature storage for fork tests
contract MockCCTPForkSignatureStorage {
    function retrieveSignatureData(address) external view returns (bytes memory) {
        uint48 validUntil = uint48(block.timestamp + 3600);
        bytes32 merkleRoot = keccak256("test_merkle_root");
        bytes32[] memory proofSrc = new bytes32[](1);
        proofSrc[0] = keccak256("src1");
        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](0);
        bytes memory signature = hex"abcdef";
        return abi.encode(new uint64[](0), validUntil, 0, merkleRoot, proofSrc, proofDst, signature);
    }
}

/// @title CCTPHooksFork
/// @notice Integration tests for CCTP V2 bridge hook using mainnet fork
/// @dev Tests real TokenMessengerV2 interactions on forked Ethereum mainnet
/// @dev NOTE: depositForBurnWithHook requires non-empty hookData on the real contract,
///      so all execution tests provide hookCallData. Empty hookData tests are view-only.
contract CCTPHooksFork is Helpers {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // CCTP V2 TokenMessengerV2 (same address on all EVM chains via CREATE2)
    address public constant TOKEN_MESSENGER_V2 = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;

    // USDC on Ethereum mainnet
    address public constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // USDC on Base (for hookCallData recipient)
    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // CCTP Domain IDs (NOT EVM chain IDs)
    uint32 public constant DOMAIN_ETHEREUM = 0;
    uint32 public constant DOMAIN_BASE = 6;
    uint32 public constant DOMAIN_ARBITRUM = 3;
    uint32 public constant DOMAIN_OPTIMISM = 2;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    ApproveAndCCTPSendHook public cctpHook;
    MockCCTPForkSignatureStorage public mockSignatureStorage;

    address public account;
    uint256 public ethForkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        ethForkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        mockSignatureStorage = new MockCCTPForkSignatureStorage();
        cctpHook = new ApproveAndCCTPSendHook(TOKEN_MESSENGER_V2, address(mockSignatureStorage));

        account = makeAddr("account");
        vm.deal(account, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    FORK VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify the TokenMessengerV2 contract exists and has code on mainnet
    function test_Fork_TokenMessengerV2IsDeployed() public view {
        assertTrue(TOKEN_MESSENGER_V2.code.length > 0, "TokenMessengerV2 should be deployed on mainnet");
    }

    /// @notice Verify USDC contract is accessible on the fork
    function test_Fork_USDCIsAccessible() public view {
        string memory name = IERC20Metadata(USDC_ETH).name();
        assertEq(name, "USD Coin", "Should be USDC");
        assertEq(IERC20Metadata(USDC_ETH).decimals(), 6, "USDC should have 6 decimals");
    }

    /// @notice Verify the hook was constructed with the real TokenMessengerV2 address
    function test_Fork_HookConstructedWithRealAddress() public view {
        assertEq(cctpHook.TOKEN_MESSENGER(), TOKEN_MESSENGER_V2);
    }

    /*//////////////////////////////////////////////////////////////
            BUILD TESTS WITH REAL ADDRESSES (VIEW-ONLY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Build hook executions using real USDC and TokenMessengerV2 addresses
    function test_Fork_Build_USDC_EthToBase() public view {
        uint256 amount = 1000e6;
        bytes memory hookCallData = _createMockComposeMsg(account);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            amount,
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            1e6,
            2000,
            false,
            hookCallData
        );

        Execution[] memory executions = cctpHook.build(address(0), account, data);

        // preExecute + 4 hook executions + postExecute = 6
        assertEq(executions.length, 6, "Should have 6 executions");

        // Execution 1: approve(TokenMessengerV2, 0)
        assertEq(executions[1].target, USDC_ETH);
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (TOKEN_MESSENGER_V2, 0)));

        // Execution 2: approve(TokenMessengerV2, amount)
        assertEq(executions[2].target, USDC_ETH);
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (TOKEN_MESSENGER_V2, amount)));

        // Execution 3: depositForBurnWithHook
        assertEq(executions[3].target, TOKEN_MESSENGER_V2);
        assertEq(executions[3].value, 0, "No native ETH for CCTP");
        assertEq(bytes4(executions[3].callData), ITokenMessengerV2.depositForBurnWithHook.selector);

        // Execution 4: approve(TokenMessengerV2, 0) cleanup
        assertEq(executions[4].target, USDC_ETH);
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (TOKEN_MESSENGER_V2, 0)));
    }

    /// @notice All executions must have value = 0 (CCTP deducts fee from amount)
    function test_Fork_Build_AllValuesZero() public view {
        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            1000e6,
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            1e6,
            2000,
            false,
            _createMockComposeMsg(account)
        );

        Execution[] memory executions = cctpHook.build(address(0), account, data);

        for (uint256 i = 0; i < executions.length; i++) {
            assertEq(executions[i].value, 0, "All CCTP executions should have value = 0");
        }
    }

    /// @notice Verify the real contract rejects empty hookData for depositForBurnWithHook
    function test_Fork_Build_EmptyHookDataRevertsOnRealContract() public {
        uint256 amount = 1000e6;

        deal(USDC_ETH, account, amount);

        // Build with empty hookCallData
        bytes memory data = _encodeCCTPData(
            USDC_ETH, amount, DOMAIN_BASE, bytes32(uint256(uint160(account))), bytes32(0), 5e6, 2000, false, ""
        );

        Execution[] memory executions = cctpHook.build(address(0), account, data);

        // The build succeeds (hook allows empty hookCallData), but execution reverts
        vm.startPrank(account);
        // preExecute
        (bool s,) = executions[0].target.call(executions[0].callData);
        assertTrue(s);
        // approve(0)
        (s,) = executions[1].target.call(executions[1].callData);
        assertTrue(s);
        // approve(amount)
        (s,) = executions[2].target.call(executions[2].callData);
        assertTrue(s);
        // depositForBurnWithHook with empty hookData reverts on the real contract
        (s,) = executions[3].target.call(executions[3].callData);
        assertFalse(s, "Real TokenMessengerV2 should reject empty hookData");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
            EXECUTE: REAL depositForBurnWithHook ON FORK
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute a real USDC burn via CCTP V2 on forked Ethereum mainnet (ETH -> Base)
    function test_Fork_Execute_USDC_EthToBase() public {
        _executeAndVerify(1000e6, DOMAIN_BASE, 5e6, 2000);
        console2.log("Successfully burned 1000 USDC via CCTP V2 (ETH -> Base)");
    }

    /// @notice Execute with fast finality threshold (< 2000)
    function test_Fork_Execute_USDC_FastFinality() public {
        _executeAndVerify(500e6, DOMAIN_BASE, 5e6, 1000);
        console2.log("Successfully burned 500 USDC with fast finality via CCTP V2");
    }

    /// @notice Execute to Arbitrum domain (domain 3)
    function test_Fork_Execute_USDC_EthToArbitrum() public {
        _executeAndVerify(2000e6, DOMAIN_ARBITRUM, 5e6, 2000);
        console2.log("Successfully burned 2000 USDC (ETH -> Arbitrum)");
    }

    /// @notice Execute to Optimism domain (domain 2)
    function test_Fork_Execute_USDC_EthToOptimism() public {
        _executeAndVerify(750e6, DOMAIN_OPTIMISM, 5e6, 2000);
    }

    /*//////////////////////////////////////////////////////////////
            EDGE CASE: PREV HOOK AMOUNT ON FORK
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute using prevHook amount (chaining from a swap hook)
    function test_Fork_Execute_WithPrevHookAmount() public {
        uint256 encodedAmount = 1000e6; // This gets overridden
        uint256 prevHookOutput = 2500e6; // The actual amount from prevHook

        deal(USDC_ETH, account, prevHookOutput);

        MockHook prevHook = new MockHook(ISuperHook.HookType.INFLOW, USDC_ETH);
        prevHook.setOutAmount(prevHookOutput, account);

        bytes memory hookCallData = _createMockComposeMsg(account);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            encodedAmount,
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            5e6,
            2000,
            true, // usePrevHookAmount
            hookCallData
        );

        Execution[] memory executions = cctpHook.build(address(prevHook), account, data);

        // Verify the approve uses prevHookOutput, NOT encodedAmount
        assertEq(
            executions[2].callData,
            abi.encodeCall(IERC20.approve, (TOKEN_MESSENGER_V2, prevHookOutput)),
            "Should approve prevHook output amount"
        );

        _executePrank(executions);

        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "All USDC should have been burned");
        console2.log("Successfully used prevHook amount (2500 USDC) for CCTP burn");
    }

    /// @notice PrevHook returning zero should revert at build time
    function test_Fork_Execute_WithPrevHookAmount_RevertIf_Zero() public {
        MockHook prevHook = new MockHook(ISuperHook.HookType.INFLOW, USDC_ETH);
        prevHook.setOutAmount(0, account);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            1000e6,
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            5e6,
            2000,
            true,
            _createMockComposeMsg(account)
        );

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        cctpHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
            EDGE CASE: DESTINATION CALLER RESTRICTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute with a restricted destinationCaller (only specific address can relay on dst)
    function test_Fork_Execute_WithDestinationCaller() public {
        uint256 amount = 1000e6;
        address restrictedCaller = makeAddr("restricted_relayer");
        bytes32 destinationCaller = bytes32(uint256(uint160(restrictedCaller)));

        deal(USDC_ETH, account, amount);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            amount,
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            destinationCaller,
            5e6,
            2000,
            false,
            _createMockComposeMsg(account)
        );

        Execution[] memory executions = cctpHook.build(address(0), account, data);
        _executePrank(executions);

        assertEq(IERC20(USDC_ETH).balanceOf(account), 0);
        console2.log("Successfully burned with restricted destinationCaller");
    }

    /*//////////////////////////////////////////////////////////////
            EDGE CASE: HOOK CALL DATA + PREV HOOK COMBINED
    //////////////////////////////////////////////////////////////*/

    /// @notice Build with hookCallData AND prevHookAmount combined
    function test_Fork_Execute_WithHookCallDataAndPrevHookAmount() public {
        uint256 prevHookOutput = 3000e6;

        deal(USDC_ETH, account, prevHookOutput);

        MockHook prevHook = new MockHook(ISuperHook.HookType.INFLOW, USDC_ETH);
        prevHook.setOutAmount(prevHookOutput, account);

        bytes memory hookCallData = _createMockComposeMsg(account);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            1000e6, // overridden by prevHook
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            5e6,
            2000,
            true, // usePrevHookAmount
            hookCallData
        );

        Execution[] memory executions = cctpHook.build(address(prevHook), account, data);

        // Verify it uses prevHookOutput
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (TOKEN_MESSENGER_V2, prevHookOutput)));

        _executePrank(executions);

        assertEq(IERC20(USDC_ETH).balanceOf(account), 0);
        console2.log("Successfully combined prevHookAmount + hookCallData");
    }

    /*//////////////////////////////////////////////////////////////
            EDGE CASE: VARIOUS AMOUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Small amount burn (10 USDC - near minimum)
    function test_Fork_Execute_SmallAmount() public {
        _executeAndVerify(10e6, DOMAIN_BASE, 1e6, 2000);
    }

    /// @notice Large amount burn (1M USDC)
    function test_Fork_Execute_LargeAmount() public {
        _executeAndVerify(1_000_000e6, DOMAIN_BASE, 50e6, 2000);
        console2.log("Successfully burned 1M USDC via CCTP V2");
    }

    /// @notice maxFee = 0 (zero fee)
    function test_Fork_Execute_ZeroMaxFee() public {
        _executeAndVerify(1000e6, DOMAIN_BASE, 0, 2000);
    }

    /*//////////////////////////////////////////////////////////////
            EDGE CASE: APPROVAL CLEANUP VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify that approvals are properly cleaned up step by step
    function test_Fork_Execute_ApprovalCleanup() public {
        uint256 amount = 1000e6;

        deal(USDC_ETH, account, amount);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            amount,
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            5e6,
            2000,
            false,
            _createMockComposeMsg(account)
        );

        Execution[] memory executions = cctpHook.build(address(0), account, data);

        vm.startPrank(account);

        // preExecute
        (bool success,) = executions[0].target.call(executions[0].callData);
        assertTrue(success);

        // approve(0) - reset
        (success,) = executions[1].target.call(executions[1].callData);
        assertTrue(success);
        assertEq(IERC20(USDC_ETH).allowance(account, TOKEN_MESSENGER_V2), 0, "Allowance should be 0 after reset");

        // approve(amount)
        (success,) = executions[2].target.call(executions[2].callData);
        assertTrue(success);
        assertEq(IERC20(USDC_ETH).allowance(account, TOKEN_MESSENGER_V2), amount, "Allowance should be amount");

        // depositForBurnWithHook
        (success,) = executions[3].target.call(executions[3].callData);
        assertTrue(success, "depositForBurnWithHook should succeed");

        // approve(0) - cleanup
        (success,) = executions[4].target.call(executions[4].callData);
        assertTrue(success);
        assertEq(IERC20(USDC_ETH).allowance(account, TOKEN_MESSENGER_V2), 0, "Allowance should be 0 after cleanup");

        // postExecute
        (success,) = executions[5].target.call(executions[5].callData);
        assertTrue(success);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
            EDGE CASE: INSPECTOR ON REAL ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify inspect() returns correct burnToken and mintRecipient from real addresses
    function test_Fork_Inspector_RealAddresses() public view {
        address recipient = address(0xdead);
        bytes32 mintRecipient = bytes32(uint256(uint160(recipient)));

        bytes memory data = _encodeCCTPData(
            USDC_ETH, 1000e6, DOMAIN_BASE, mintRecipient, bytes32(0), 1e6, 2000, false, ""
        );

        bytes memory result = cctpHook.inspect(data);
        assertEq(result, abi.encodePacked(USDC_ETH, recipient));
    }

    /*//////////////////////////////////////////////////////////////
            EDGE CASE: CONSECUTIVE BURNS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify build works correctly for multiple domains in sequence (view-only)
    /// @dev Full execution of consecutive burns requires SuperExecutor to reset hook mutex
    ///      between operations. Direct prank calls share transient storage within one test.
    function test_Fork_Build_MultipleDomains() public view {
        uint256 amount = 1000e6;
        bytes memory hookCallData = _createMockComposeMsg(account);

        // Build for Base
        bytes memory dataBase = _encodeCCTPData(
            USDC_ETH,
            amount,
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            5e6,
            2000,
            false,
            hookCallData
        );
        Execution[] memory execBase = cctpHook.build(address(0), account, dataBase);
        assertEq(execBase.length, 6);

        // Build for Arbitrum
        bytes memory dataArb = _encodeCCTPData(
            USDC_ETH,
            amount,
            DOMAIN_ARBITRUM,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            5e6,
            2000,
            false,
            hookCallData
        );
        Execution[] memory execArb = cctpHook.build(address(0), account, dataArb);
        assertEq(execArb.length, 6);

        // Build for Optimism
        bytes memory dataOp = _encodeCCTPData(
            USDC_ETH,
            amount,
            DOMAIN_OPTIMISM,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            5e6,
            2000,
            false,
            hookCallData
        );
        Execution[] memory execOp = cctpHook.build(address(0), account, dataOp);
        assertEq(execOp.length, 6);

        // All target the same TokenMessengerV2
        assertEq(execBase[3].target, TOKEN_MESSENGER_V2);
        assertEq(execArb[3].target, TOKEN_MESSENGER_V2);
        assertEq(execOp[3].target, TOKEN_MESSENGER_V2);
    }

    /*//////////////////////////////////////////////////////////////
            EVENT VERIFICATION: CROSS-CHAIN MESSAGE PROOF
    //////////////////////////////////////////////////////////////*/

    /// @dev DepositForBurn event topic0 from real TokenMessengerV2
    bytes32 private constant DEPOSIT_FOR_BURN_TOPIC =
        0x0c8c1cbdc5190613ebd485511d4e2812cfa45eecb79d845893331fedad5130a5;

    /// @dev MessageSent event topic0 from real MessageTransmitterV2
    bytes32 private constant MESSAGE_SENT_TOPIC = keccak256("MessageSent(bytes)");

    /// @notice Verify that a real CCTP burn emits DepositForBurn with correct parameters
    /// @dev This proves the cross-chain message was correctly constructed for Circle's attestation service
    /// @dev DepositForBurn event has indexed: burnToken(topic1), depositor(topic2), nonce(topic3)
    ///      Non-indexed data: amount, mintRecipient, destinationDomain, destTokenMessenger,
    ///                        destinationCaller, maxFee, hookCallData
    function test_Fork_EventVerification_DepositForBurn_EthToBase() public {
        uint256 amount = 1000e6;

        deal(USDC_ETH, account, amount);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            amount,
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            5e6,
            2000,
            false,
            _createMockComposeMsg(account)
        );

        Execution[] memory executions = cctpHook.build(address(0), account, data);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        Vm.Log memory evt = _findEvent(logs, DEPOSIT_FOR_BURN_TOPIC, TOKEN_MESSENGER_V2);
        assertTrue(evt.data.length > 0, "DepositForBurn event must be emitted");

        // Indexed topics: burnToken, depositor
        assertEq(address(uint160(uint256(evt.topics[1]))), USDC_ETH, "Event: burnToken (indexed)");
        assertEq(address(uint160(uint256(evt.topics[2]))), account, "Event: depositor (indexed)");

        // Non-indexed data: amount, mintRecipient, destinationDomain, destTokenMessenger, destinationCaller, maxFee
        _verifyDepositForBurnData(evt.data, amount, account, DOMAIN_BASE, bytes32(0), 5e6);
        console2.log("DepositForBurn event verified: 1000 USDC, ETH->Base");
    }

    /// @notice Verify MessageSent event is emitted (this is the actual cross-chain message)
    /// @dev Circle's attestation service picks up this event to relay the message to the destination chain
    function test_Fork_EventVerification_MessageSent_EthToBase() public {
        uint256 amount = 1000e6;

        deal(USDC_ETH, account, amount);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            amount,
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            5e6,
            2000,
            false,
            _createMockComposeMsg(account)
        );

        Execution[] memory executions = cctpHook.build(address(0), account, data);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the MessageSent event
        bool foundMessageSent = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == MESSAGE_SENT_TOPIC) {
                foundMessageSent = true;

                // MessageSent(bytes message) — the raw cross-chain message bytes
                bytes memory message = abi.decode(logs[i].data, (bytes));
                assertTrue(message.length > 0, "Cross-chain message should be non-empty");

                // CCTP V2 message format:
                //   version (4) | sourceDomain (4) | destinationDomain (4) | nonce (8) | sender (32) | recipient (32)
                //   | destinationCaller (32) | messageBody (variable)
                // Verify destinationDomain is encoded in the message at offset 8 (after version + sourceDomain)
                uint32 msgDestDomain;
                assembly {
                    msgDestDomain := shr(224, mload(add(message, 40)))
                }
                assertEq(msgDestDomain, DOMAIN_BASE, "Message: destinationDomain should be Base (6)");

                // Verify sourceDomain (Ethereum = 0)
                uint32 msgSrcDomain;
                assembly {
                    msgSrcDomain := shr(224, mload(add(message, 36)))
                }
                assertEq(msgSrcDomain, DOMAIN_ETHEREUM, "Message: sourceDomain should be Ethereum (0)");

                console2.log("MessageSent event verified:");
                console2.log("  message length:", message.length);
                console2.log("  sourceDomain:", msgSrcDomain);
                console2.log("  destinationDomain:", msgDestDomain);
                break;
            }
        }
        assertTrue(foundMessageSent, "MessageSent event must be emitted for cross-chain relay");
    }

    /// @notice Verify USDC Transfer events show the burn flow: account -> burner -> zero
    function test_Fork_EventVerification_USDCBurnFlow() public {
        uint256 amount = 1000e6;

        deal(USDC_ETH, account, amount);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            amount,
            DOMAIN_BASE,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            5e6,
            2000,
            false,
            _createMockComposeMsg(account)
        );

        Execution[] memory executions = cctpHook.build(address(0), account, data);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Track USDC Transfer events (ERC20 Transfer topic)
        bytes32 transferTopic = keccak256("Transfer(address,address,uint256)");
        uint256 transferCount = 0;
        bool foundBurnToZero = false;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == transferTopic && logs[i].emitter == USDC_ETH) {
                transferCount++;
                address to = address(uint160(uint256(logs[i].topics[2])));

                // A transfer to address(0) is the actual USDC burn
                if (to == address(0)) {
                    foundBurnToZero = true;
                    uint256 burnAmount = abi.decode(logs[i].data, (uint256));
                    assertEq(burnAmount, amount, "Burned amount should match the full amount");
                    console2.log("USDC burn verified: amount =", burnAmount, "to address(0)");
                }
            }
        }

        assertTrue(transferCount >= 2, "Should have at least 2 USDC transfers (to burner + to zero)");
        assertTrue(foundBurnToZero, "USDC must be burned (transferred to address(0))");
    }

    /// @notice Verify events for Arbitrum destination contain correct domain
    function test_Fork_EventVerification_DepositForBurn_EthToArbitrum() public {
        uint256 amount = 2000e6;

        deal(USDC_ETH, account, amount);

        bytes memory data = _encodeCCTPData(
            USDC_ETH, amount, DOMAIN_ARBITRUM, bytes32(uint256(uint160(account))), bytes32(0), 5e6, 2000, false,
            _createMockComposeMsg(account)
        );

        Execution[] memory executions = cctpHook.build(address(0), account, data);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        Vm.Log memory evt = _findEvent(logs, DEPOSIT_FOR_BURN_TOPIC, TOKEN_MESSENGER_V2);
        assertTrue(evt.data.length > 0, "DepositForBurn event must be emitted for Arbitrum");

        _verifyDepositForBurnData(evt.data, amount, account, DOMAIN_ARBITRUM, bytes32(0), 5e6);
        console2.log("DepositForBurn verified: 2000 USDC, ETH->Arbitrum");
    }

    /// @notice Verify that prevHookAmount is reflected in the emitted event
    function test_Fork_EventVerification_PrevHookAmount() public {
        uint256 prevHookOutput = 2500e6;

        deal(USDC_ETH, account, prevHookOutput);

        MockHook prevHook = new MockHook(ISuperHook.HookType.INFLOW, USDC_ETH);
        prevHook.setOutAmount(prevHookOutput, account);

        bytes memory data = _encodeCCTPData(
            USDC_ETH, 1000e6, DOMAIN_BASE, bytes32(uint256(uint160(account))), bytes32(0), 5e6, 2000, true,
            _createMockComposeMsg(account)
        );

        Execution[] memory executions = cctpHook.build(address(prevHook), account, data);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        Vm.Log memory evt = _findEvent(logs, DEPOSIT_FOR_BURN_TOPIC, TOKEN_MESSENGER_V2);
        assertTrue(evt.data.length > 0, "DepositForBurn event must be emitted");

        // Verify event uses prevHook amount (2500), NOT the encoded amount (1000)
        // maxFee is also scaled proportionally: 5e6 * 2500e6 / 1000e6 = 12.5e6
        uint256 scaledMaxFee = (5e6 * prevHookOutput) / 1000e6;
        _verifyDepositForBurnData(evt.data, prevHookOutput, account, DOMAIN_BASE, bytes32(0), scaledMaxFee);
        console2.log("PrevHook amount in event verified: 2500 USDC (not 1000), maxFee scaled to", scaledMaxFee);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Find a log entry by topic0 and emitter, returns a Vm.Log (check data.length > 0 for found)
    function _findEvent(
        Vm.Log[] memory logs,
        bytes32 topic0,
        address emitter
    )
        internal
        pure
        returns (Vm.Log memory)
    {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == topic0 && logs[i].emitter == emitter) {
                return logs[i];
            }
        }
        // Return empty log (data.length == 0 signals not found)
        Vm.Log memory empty;
        return empty;
    }

    /// @dev Verify DepositForBurn non-indexed data fields
    /// @dev Data layout (after indexed burnToken, depositor, nonce are in topics):
    ///      slot 0: amount (uint256)
    ///      slot 1: mintRecipient (bytes32)
    ///      slot 2: destinationDomain (uint32)
    ///      slot 3: destinationTokenMessenger (address)
    ///      slot 4: destinationCaller (bytes32)
    ///      slot 5: maxFee (uint256)
    ///      slot 6+: hookCallData offset + dynamic data
    function _verifyDepositForBurnData(
        bytes memory eventData,
        uint256 expectedAmount,
        address expectedMintRecipient,
        uint32 expectedDestDomain,
        bytes32 expectedDestCaller,
        uint256 expectedMaxFee
    )
        internal
        pure
    {
        uint256 amount;
        bytes32 mintRecipient;
        uint256 destDomain;
        bytes32 destCaller;
        uint256 maxFee;

        assembly {
            let base := add(eventData, 32) // skip bytes length prefix
            amount := mload(base) // slot 0
            mintRecipient := mload(add(base, 0x20)) // slot 1
            destDomain := mload(add(base, 0x40)) // slot 2
            // slot 3 = destinationTokenMessenger (skip)
            destCaller := mload(add(base, 0x80)) // slot 4
            maxFee := mload(add(base, 0xA0)) // slot 5
        }

        assert(amount == expectedAmount);
        assert(address(uint160(uint256(mintRecipient))) == expectedMintRecipient);
        assert(destDomain == uint256(expectedDestDomain));
        assert(destCaller == expectedDestCaller);
        assert(maxFee == expectedMaxFee);
    }

    /// @dev Shortcut: deal USDC, encode data with hookCallData, build, execute, verify balance = 0
    function _executeAndVerify(
        uint256 amount,
        uint32 destinationDomain,
        uint256 maxFee,
        uint32 minFinalityThreshold
    )
        internal
    {
        deal(USDC_ETH, account, amount);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            amount,
            destinationDomain,
            bytes32(uint256(uint160(account))),
            bytes32(0),
            maxFee,
            minFinalityThreshold,
            false,
            _createMockComposeMsg(account)
        );

        Execution[] memory executions = cctpHook.build(address(0), account, data);
        _executePrank(executions);

        assertEq(IERC20(USDC_ETH).balanceOf(account), 0, "All USDC should have been burned");
        assertEq(IERC20(USDC_ETH).allowance(account, TOKEN_MESSENGER_V2), 0, "Approval should be cleaned up");
    }

    /// @dev Execute all executions from the account
    function _executePrank(Execution[] memory executions) internal {
        vm.startPrank(account);
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string.concat("Execution ", vm.toString(i), " failed"));
        }
        vm.stopPrank();
    }

    function _encodeCCTPData(
        address burnToken,
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bool usePrevHookAmount,
        bytes memory hookCallData
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            burnToken,
            amount,
            destinationDomain,
            mintRecipient,
            destinationCaller,
            maxFee,
            minFinalityThreshold,
            usePrevHookAmount,
            uint256(hookCallData.length),
            hookCallData
        );
    }

    function _createMockComposeMsg(address _account) internal pure returns (bytes memory) {
        bytes memory initData = abi.encode(bytes("init"));
        bytes memory executorCalldata = abi.encode(bytes("executor"));
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC on Base
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1000e6;

        return abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts);
    }
}

/// @dev Minimal interface for USDC metadata queries
interface IERC20Metadata {
    function name() external view returns (string memory);
    function decimals() external view returns (uint8);
}

/// @title CCTPHooksForkE2E
/// @notice End-to-end cross-chain tests: burn USDC on ETH, relay via CctpV2Helper, verify mint on Base
contract CCTPHooksForkE2E is Helpers {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address public constant TOKEN_MESSENGER_V2 = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address public constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    uint32 public constant DOMAIN_ETH = 0;
    uint32 public constant DOMAIN_BASE = 6;
    uint32 public constant DOMAIN_ARBITRUM = 3;

    /// @dev USDC FiatTokenV2 balance mapping storage slot
    uint256 constant USDC_BALANCE_SLOT = 9;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    ApproveAndCCTPSendHook public cctpHook;
    MockCCTPForkSignatureStorage public mockSignatureStorage;
    CctpV2Helper public cctpHelper;

    address public account;
    uint256 public ethForkId;
    uint256 public baseForkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        ethForkId = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        mockSignatureStorage = new MockCCTPForkSignatureStorage();
        cctpHook = new ApproveAndCCTPSendHook(TOKEN_MESSENGER_V2, address(mockSignatureStorage));
        cctpHelper = new CctpV2Helper(0);

        baseForkId = vm.createFork(vm.envString("BASE_RPC_URL"));

        account = makeAddr("account");
        vm.deal(account, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
            E2E: BURN ON ETH → RELAY → VERIFY MINT ON BASE
    //////////////////////////////////////////////////////////////*/

    /// @notice Full cross-chain: burn 1000 USDC on ETH via hook, relay to Base, verify 1000 USDC minted
    function test_Fork_E2E_BurnAndRelay_EthToBase() public {
        uint256 amount = 1000e6;

        // Source chain: burn USDC via hook
        vm.selectFork(ethForkId);
        _dealUsdc(USDC_ETH, account, amount);

        Execution[] memory executions = _buildHookExecutions(amount, DOMAIN_BASE, bytes32(0), 0, 2000, false, 0);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Record balance on Base before relay
        vm.selectFork(baseForkId);
        uint256 balanceBefore = IERC20(USDC_BASE).balanceOf(account);
        vm.selectFork(ethForkId);

        // Relay via pigeon helper
        cctpHelper.help(DOMAIN_BASE, baseForkId, logs);

        // Verify on Base
        vm.selectFork(baseForkId);
        uint256 balanceAfter = IERC20(USDC_BASE).balanceOf(account);
        assertGt(balanceAfter, balanceBefore, "USDC should be minted on Base");
        assertEq(balanceAfter - balanceBefore, amount, "Full amount should be minted (maxFee=0)");
    }

    /// @notice E2E with maxFee deducted: verify recipient gets amount minus fee
    function test_Fork_E2E_WithMaxFee_EthToBase() public {
        uint256 amount = 1000e6;
        uint256 maxFee = 5e6;

        vm.selectFork(ethForkId);
        _dealUsdc(USDC_ETH, account, amount);

        Execution[] memory executions = _buildHookExecutions(amount, DOMAIN_BASE, bytes32(0), maxFee, 2000, false, 0);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        vm.selectFork(baseForkId);
        uint256 balanceBefore = IERC20(USDC_BASE).balanceOf(account);
        vm.selectFork(ethForkId);

        cctpHelper.help(DOMAIN_BASE, baseForkId, logs);

        vm.selectFork(baseForkId);
        uint256 minted = IERC20(USDC_BASE).balanceOf(account) - balanceBefore;
        assertGe(minted, amount - maxFee, "Should receive at least amount minus maxFee");
    }

    /// @notice E2E with restricted destinationCaller
    function test_Fork_E2E_WithDestinationCaller_EthToBase() public {
        uint256 amount = 500e6;
        address relayer = makeAddr("restricted_relayer");
        bytes32 destinationCaller = bytes32(uint256(uint160(relayer)));

        vm.selectFork(ethForkId);
        _dealUsdc(USDC_ETH, account, amount);

        Execution[] memory executions =
            _buildHookExecutions(amount, DOMAIN_BASE, destinationCaller, 0, 2000, false, 0);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Helper should prank as destinationCaller to relay
        cctpHelper.help(DOMAIN_BASE, baseForkId, logs);

        vm.selectFork(baseForkId);
        uint256 balance = IERC20(USDC_BASE).balanceOf(account);
        assertGt(balance, 0, "USDC should be minted via restricted relay");
    }

    /// @notice E2E with prevHookAmount overriding the encoded amount
    function test_Fork_E2E_WithPrevHookAmount_EthToBase() public {
        uint256 encodedAmount = 1000e6;
        uint256 prevHookOutput = 2500e6;

        vm.selectFork(ethForkId);
        _dealUsdc(USDC_ETH, account, prevHookOutput);

        MockHook prevHook = new MockHook(ISuperHook.HookType.INFLOW, USDC_ETH);
        prevHook.setOutAmount(prevHookOutput, account);

        Execution[] memory executions = _buildHookExecutionsWithPrevHook(
            address(prevHook), encodedAmount, DOMAIN_BASE, bytes32(0), 0, 2000
        );

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        vm.selectFork(baseForkId);
        uint256 balanceBefore = IERC20(USDC_BASE).balanceOf(account);
        vm.selectFork(ethForkId);

        cctpHelper.help(DOMAIN_BASE, baseForkId, logs);

        vm.selectFork(baseForkId);
        uint256 minted = IERC20(USDC_BASE).balanceOf(account) - balanceBefore;
        // Should mint prevHookOutput (2500), not encodedAmount (1000)
        assertEq(minted, prevHookOutput, "Should mint prevHook amount, not encoded amount");
    }

    /// @notice E2E with large amount (1M USDC)
    function test_Fork_E2E_LargeAmount_EthToBase() public {
        uint256 amount = 1_000_000e6;

        vm.selectFork(ethForkId);
        _dealUsdc(USDC_ETH, account, amount);

        Execution[] memory executions = _buildHookExecutions(amount, DOMAIN_BASE, bytes32(0), 0, 2000, false, 0);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        cctpHelper.help(DOMAIN_BASE, baseForkId, logs);

        vm.selectFork(baseForkId);
        uint256 balance = IERC20(USDC_BASE).balanceOf(account);
        assertEq(balance, amount, "1M USDC should be minted on Base");
    }

    /// @notice E2E with fast finality threshold
    function test_Fork_E2E_FastFinality_EthToBase() public {
        uint256 amount = 500e6;

        vm.selectFork(ethForkId);
        _dealUsdc(USDC_ETH, account, amount);

        Execution[] memory executions = _buildHookExecutions(amount, DOMAIN_BASE, bytes32(0), 0, 1000, false, 0);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        cctpHelper.help(DOMAIN_BASE, baseForkId, logs);

        vm.selectFork(baseForkId);
        uint256 balance = IERC20(USDC_BASE).balanceOf(account);
        assertEq(balance, amount, "USDC should be minted with fast finality");
    }

    /// @notice Verify source chain USDC is burned AND destination chain USDC is minted in one flow
    function test_Fork_E2E_VerifyBothSides() public {
        uint256 amount = 1000e6;

        vm.selectFork(ethForkId);
        _dealUsdc(USDC_ETH, account, amount);
        uint256 srcBalanceBefore = IERC20(USDC_ETH).balanceOf(account);

        vm.selectFork(baseForkId);
        uint256 dstBalanceBefore = IERC20(USDC_BASE).balanceOf(account);
        vm.selectFork(ethForkId);

        Execution[] memory executions = _buildHookExecutions(amount, DOMAIN_BASE, bytes32(0), 0, 2000, false, 0);

        vm.recordLogs();
        _executePrank(executions);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Verify source burn
        uint256 srcBalanceAfter = IERC20(USDC_ETH).balanceOf(account);
        assertEq(srcBalanceAfter, srcBalanceBefore - amount, "Source USDC should be burned");

        // Relay and verify destination mint
        cctpHelper.help(DOMAIN_BASE, baseForkId, logs);

        vm.selectFork(baseForkId);
        uint256 dstBalanceAfter = IERC20(USDC_BASE).balanceOf(account);
        assertEq(dstBalanceAfter, dstBalanceBefore + amount, "Destination USDC should be minted");
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Sets USDC balance via vm.store (avoids deal breaking USDC proxy)
    function _dealUsdc(address token, address to, uint256 amount) internal {
        bytes32 slot = keccak256(abi.encode(to, USDC_BALANCE_SLOT));
        vm.store(token, slot, bytes32(amount));
    }

    function _buildHookExecutions(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bool usePrevHookAmount,
        uint256 /* prevHookOutput */
    )
        internal
        view
        returns (Execution[] memory)
    {
        bytes memory hookCallData = _createMockComposeMsg(account);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            amount,
            destinationDomain,
            bytes32(uint256(uint160(account))),
            destinationCaller,
            maxFee,
            minFinalityThreshold,
            usePrevHookAmount,
            hookCallData
        );

        return cctpHook.build(address(0), account, data);
    }

    function _buildHookExecutionsWithPrevHook(
        address prevHook,
        uint256 amount,
        uint32 destinationDomain,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    )
        internal
        view
        returns (Execution[] memory)
    {
        bytes memory hookCallData = _createMockComposeMsg(account);

        bytes memory data = _encodeCCTPData(
            USDC_ETH,
            amount,
            destinationDomain,
            bytes32(uint256(uint160(account))),
            destinationCaller,
            maxFee,
            minFinalityThreshold,
            true,
            hookCallData
        );

        return cctpHook.build(prevHook, account, data);
    }

    function _executePrank(Execution[] memory executions) internal {
        vm.startPrank(account);
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string.concat("Execution ", vm.toString(i), " failed"));
        }
        vm.stopPrank();
    }

    function _encodeCCTPData(
        address burnToken,
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bool usePrevHookAmount,
        bytes memory hookCallData
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            burnToken,
            amount,
            destinationDomain,
            mintRecipient,
            destinationCaller,
            maxFee,
            minFinalityThreshold,
            usePrevHookAmount,
            uint256(hookCallData.length),
            hookCallData
        );
    }

    function _createMockComposeMsg(address _account) internal pure returns (bytes memory) {
        bytes memory initData = abi.encode(bytes("init"));
        bytes memory executorCalldata = abi.encode(bytes("executor"));
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = 1000e6;

        return abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts);
    }
}
